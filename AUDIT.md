# Voice Changer Audit — bugs, performance, conversion quality

Full audit of the server (Python) and client (TypeScript) covering correctness,
performance/latency, and voice-conversion quality. Everything under **Fixed** is
implemented in this branch; **Not fixed** items are documented with exact
locations so they can be picked up later.

All paths below are relative to `voice changer/`.

---

## Fixed — critical

### 1. Default pitch detector (`rmvpe_onnx`) crashed on model load
`server/voice_changer/pitch_extractor/RMVPEOnnxPitchExtractor.py`

Commit 9c8bf08 accidentally inserted `set_threshold()` **in the middle of
`__init__`**, which orphaned the rest of the constructor (mel extractor + ONNX
session creation) into `set_threshold`, where it referenced `__init__` local
variables (`model`, `device_manager`). Result: selecting any model with the
default `rmvpe_onnx` detector raised `NameError` during pipeline init — the
voice changer could not start at all on the default configuration. The
constructor body is now back in `__init__` and `set_threshold` only updates the
threshold.

### 2. Inference ran on the asyncio event loop — blocked everything per chunk
`server/sio/MMVC_Namespace.py`, `server/restapi/MMVC_Rest_VoiceChanger.py`,
`server/voice_changer/VoiceChangerManager.py`

Every audio chunk ran the full torch/ONNX conversion synchronously inside the
uvicorn event loop. While a chunk was converting (tens to hundreds of ms):
websocket frames for the next chunk couldn't even be parsed (zero
receive/compute overlap → processing time added fully to round-trip latency),
all REST endpoints stalled, and engine.io PING/PONG stalled — a slow model
could cause spurious ping-timeout disconnects mid-stream. Conversion now runs
on a dedicated single-worker thread (`change_voice_async`), preserving strict
chunk ordering while keeping the loop free.

### 3. Server-audio stats emitted via `asyncio.run()` inside the PortAudio callback
`server/sio/MMVC_Namespace.py`

`emit_coroutine` created and tore down a brand-new event loop for every audio
block, inside the realtime audio callback thread, and touched
`AsyncServer` internals from a foreign loop (not thread-safe; intermittent
"attached to a different loop" failures and audio dropouts from network I/O in
the callback). Now uses `asyncio.run_coroutine_threadsafe` onto the server's
loop (captured on connect).

### 4. `POST /update_model_info` was completely broken
`server/voice_changer/VoiceChangerManager.py`

It called `ModelSlotManager.update_model_info(newData)` with one argument, but
the signature is `(slot_index, key, val)` — every call raised `TypeError`,
which the REST layer swallowed into HTTP 200 `null`. Editing model info from
the UI silently never worked. The JSON payload `{slot, key, val}` is now parsed
and forwarded correctly.

### 5. Path traversal in model upload handling (security)
`server/voice_changer/VoiceChangerManager.py` (`load_model`),
`server/voice_changer/ModelSlotManager.py` (`store_model_assets`)

`file.dir` / `file.name` / `params["file"]` / `params["name"]` came straight
from client JSON and were joined into filesystem paths unsanitized —
`dir="../.."` could move any readable file to any writable location, and
`name` allowed arbitrary attribute injection into slot metadata. Upload
sanitizes filenames, but these post-processing paths undid that. Now: path
components are validated (no absolute paths, no `..`), asset filenames reduced
to `basename`, and the settable asset attribute is allowlisted (`iconFile`).

### 6. NaN chunk permanently poisoned the SOLA crossfade buffer
`server/voice_changer/VoiceChangerV2.py`

A single non-finite chunk (e.g. fp16 overflow in the model) wrote NaNs into
`sola_buffer`; every subsequent chunk was cross-faded with NaNs, so output
stayed silent until a full restart (this exact failure was observed with the
old fp32-buffers experiment — see commit d8507f6). The CPU-side output is now
checked with `np.isfinite` (cheap — it's already a small numpy array); on a bad
chunk the crossfade state resets and one block of silence is emitted, then
conversion recovers automatically.

### 7. Server-audio start crashed before reporting device errors
`server/voice_changer/Local/ServerAudio.py`

`serverInputAudioDevice.maxInputChannels` was dereferenced *before* the
`is None` check, so starting with an unset/unplugged device raised
`AttributeError`, skipped the intended error event, and the UI silently did
nothing. The None check now runs first. Also fixed the ASIO copy-paste bug:
the **output** stream's ASIO settings were keyed off the **input** device, so
ASIO-out/non-ASIO-in setups never got the output channel selector (and
non-ASIO-out/ASIO-in setups got a bogus 1-channel forced output).

## Fixed — high

### 8. Settings changes raced in-flight inference
`server/voice_changer/VoiceChangerManager.py`

`update_settings` (REST threadpool) could resize the SOLA buffer / fade
windows / convert buffers while a chunk was mid-conversion on the audio path —
shape-mismatch exceptions or garbled audio when dragging sliders during
streaming. Model swaps and `vc.update_settings` now take the same lock
`change_voice` holds.

### 9. A corrupted pretrain download bricked startup forever
`server/downloader/Downloader.py`

On hash mismatch the bad file was kept, and `main.py` re-raised on every
launch — the server could never start again until the user manually deleted
the file. Corrupted files are now deleted before raising, so the next launch
re-downloads. Also fixed `int(None)` crash when a server omits
`content-length`.

### 10. Upload/model REST endpoints returned HTTP 200 `null` on failure
`server/restapi/MMVC_Rest_Fileuploader.py`

All nine handlers swallowed every exception (`logger.exception` + implicit
`None` → 200). Failed uploads/loads/merges looked like success to the client —
this is what hid bugs #4 and #7 from users. They now return HTTP 500 with the
error type/message. Also fixed a malformed logging call that printed a
"--- Logging error ---" on every model load.

### 11. Multi-client stats routing
`server/sio/MMVC_Namespace.py`

`on_disconnect` unconditionally cleared the tracked `sid`, so when *any*
client disconnected, server-audio stats/errors stopped flowing to the one
still connected. Now only the departing client is forgotten.

## Fixed — performance / quality

### 12. Per-chunk GPU allocation in the SOLA hot path
`server/voice_changer/VoiceChangerV2.py` — the `(1,1,crossfade)` ones-kernel
for the correlation denominator was allocated on the device on **every chunk**;
it's now built once in `_generate_strength()` alongside the fade windows.

### 13. Output compressor: amount slider didn't control compression
`server/voice_changer/common/OutputFX.py` — any non-zero `outputComp` applied
the **full** 3:1 ratio; the 0–100 amount only scaled makeup gain, so "5"
squashed dynamics as hard as "100" while adding almost no gain. The amount now
scales the downward compression too, making the control progressive.

### 14. recordIO lifecycle
`server/voice_changer/VoiceChangerV2.py`, `server/voice_changer/IORecorder.py`
— toggling recording off never closed the WAV files (handles held forever,
which on Windows can block downloading `/tmp/in.wav`/`out.wav` while running);
toggling on mid-session appended to a stale capture. Off now closes/flushes,
on starts a fresh capture, and writes tolerate the toggle race instead of
raising.

### 15. Heavy blocking work moved off the event loop
`server/voice_changer/VoiceChangerManager.py` — model checkpoint loading
(`torch.load` + safetensors conversion) and model merging now run in a thread
executor; previously they froze live audio streaming for seconds.

### 16. Misc
- `server/utils/hasher.py`: shared module-level hash buffer was not
  thread-safe (concurrent model load + download → wrong hashes / bogus cache
  keys). Buffer is per-call now.
- `server/downloader/SampleDownloader.py`: metadata pass crashed with
  `AttributeError` on slots skipped earlier (renamed/removed upstream sample
  ids), aborting metadata for all remaining slots. Skipped slots are skipped.
- `server/downloader/WeightDownloader.py`: `logger.exception` outside an
  except block logged `NoneType: None` instead of the real download error.
- `server/restapi/mods/trustedorigin.py`: latent `TypeError` when
  `allowed_origins=None` (the documented default).
- `server/voice_changer/RVC/RVCr2.py`: file-conversion path built a fresh
  `torchaudio` resampler (kernel design + device transfer) per file; cached
  per sample rate now.

---

## Not fixed — client (requires rebuilding `client/demo/dist`)

The demo UI is served from a prebuilt webpack bundle. This environment can't
produce a trustworthy rebuild (no node_modules, pinned old toolchain), so
these are documented for the next time the bundle is rebuilt. Paths relative
to `client/`.

1. **Socket recreation guard inverted** — `lib/src/client/VoiceChangerWorkletNode.ts:70-84`.
   `if (!this.outputNode)` is backwards vs. the comment's intent: the output
   node opens a redundant second socket.io connection on protocol/URL changes
   (double-firing perf stats in server-audio mode), while the input node never
   recreates its socket when `serverUrl` changes (stale socket for the library
   API). Suggested: only (re)create the socket on the node that talks to the
   server, i.e. guard with `this.outputNode` being set, and recreate on URL
   change.
2. **Worklet drops up to 127 trailing samples per response** —
   `lib/worklet/src/voice-changer-worklet-processor.ts:82-91` copies only
   `floor(len/128)*128` samples. Harmless while the server sends block-aligned
   chunks, but a click/drift risk otherwise; buffer the remainder instead.
3. **Audio-graph leak on input reconfiguration** — `lib/src/VoiceChangerClient.ts:166-186`.
   Every device/EC/NS change creates a new source + gain (and optionally a
   VoiceFocus chain) without disconnecting the old ones; old worklets keep
   running. Disconnect previous nodes in `setup()`, and stop the dummy
   oscillator from `util.ts` when replaced.
4. **`start()`/`stop()` can hang forever** — worklet only posts
   `start_ok`/`stop_ok` on state transitions; a double-click leaves an awaited
   promise pending (`VoiceChangerWorkletNode.ts:278-302`). Resolve
   unconditionally (or guard the UI button with `isConverting`).
5. **Gain 0 is rejected** — `VoiceChangerClient.ts:255-284` `if (!val) return;`
   makes programmatic mute a no-op (and input-gain state desyncs). Use
   `if (val == null) return;`.
6. **REST protocol chunk ordering** — `VoiceChangerWorkletNode.ts:224-267`:
   concurrent fetches complete out of order and post straight to the playback
   worklet → garbled audio under latency jitter; network errors are unhandled
   rejections (user hears silence, sees nothing). Serialize or sequence-tag
   responses; report errors via `notifyException`.
7. **Never-settling promises in `ServerRestClient`** (`ServerRestClient.ts:16-58`
   and siblings): a failed `fetch` leaves the promise pending forever; app init
   awaits `/info` first, so one failure silently skips applying cached settings.
8. **Main-thread realtime overhead** — one `postMessage` per 128-sample
   quantum transferring the engine-owned buffer
   (`voice-changer-worklet-processor.ts:94-111`), int16 conversion on the UI
   thread, and per-chunk React state updates. Accumulate + convert inside the
   worklet and post once per server chunk.
9. **Unthrottled `/update_settings` floods** from EQ knobs / sliders
   (`demo/src/components/demo/components2/102-7_Knob.tsx` and friends) — every
   pointermove posts and rebuilds server-side filters. Debounce ~50–100 ms.
10. **Device hot-plug polling dies on first `enumerateDevices` error**
    (`demo/src/components/demo/001_GuiStateProvider.tsx:196-241`) — reschedule
    in `catch`.
11. **Recorded WAV header hardcodes 48 kHz**
    (`102-3_DeviceArea.tsx:885-886`) — wrong pitch/speed when
    `?sample_rate=` is used.
12. **`autopitch.js` noise-cleanup vs. main UI**: the Extra Controls tray
    force-enables browser noise suppression through a `getUserMedia` wrapper
    (default ON, `localStorage vc_noise_cleanup`). This is an intentional
    feature of this fork, but note it silently overrides the main UI's "Sup1"
    (noiseSuppression) checkbox — if input ever sounds processed with Sup1
    off, check the tray toggle. It also mutates the caller's constraints
    object; cloning would be cleaner.

## Not fixed — server (lower priority, noted for later)

- **`get_info()` is very expensive and runs on every settings change**:
  reloads all 500 slot JSON files, re-parses sample JSON, enumerates PortAudio
  devices, and rewrites the settings file — per slider tick, contending with
  live inference for the GIL. Consider returning only the changed key from
  `/update_settings`, caching slot info, and debounced settings persistence.
- **Monitor queue**: unbounded `Queue` leaks if the monitor stream fails while
  the main stream keeps producing; blocking `get()` with no timeout can wedge
  the monitor callback on stop (`Local/ServerAudio.py:88-99`).
- **Protect-path double upscale** in `RVC/pipeline/Pipeline.py:254` is a known
  perf hit when `protect < 0.5` with index (FIXME already in code).
- `sio/MMVC_Namespace.py` still tracks a single `sid`; with two simultaneous
  clients, server-audio stats go only to the newest (niche).
- Runtime sample downloads hash multi-hundred-MB files synchronously on the
  event loop (`downloader/Downloader.py:42-43`); startup paths are fine, the
  runtime path could use an executor.

## Verification notes

- All edited server files pass `py_compile`; no runtime deps (torch, sounddevice)
  are available in this environment, so fixes were verified by tracing call
  sites (each fix references the exact caller/callee it repairs).
- The `rmvpe_onnx` fix restores the file to its pre-9c8bf08 structure with the
  two intentional changes from that commit preserved (`use_fp16_for_f0()`,
  configurable threshold).
