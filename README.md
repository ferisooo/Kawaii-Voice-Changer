# Kawaii Voice Changer

A friendly, real-time **voice changer** for Windows, Linux, and macOS — speak
into your microphone and come out the other side as a different voice, live, in
games, calls, and streams.

This is the **feris** version: an updated, easier-to-use build of an existing
open-source voice changer, with extra convenience and stability features bolted
on top. It is **free** and **open source**.

> **This is not my software.** I (**feris**) did not build the voice-conversion
> engine and I do not claim ownership of it. This build stands on the shoulders
> of the people credited at the bottom of this page. My part was the idea and
> the quality-of-life features.

- 🔒 **Privacy:** feris collects **nothing** from you. See [`PRIVACY.md`](./PRIVACY.md).
- 📜 **Terms of use:** see [`TERMS.md`](./TERMS.md).
- 📖 **Full technical manual** (hardware lists, troubleshooting, building from
  source): [`voice changer/README.md`](./voice%20changer/README.md).

---

## ✨ Why use *this* version

Everything here is about making real-time voice changing **easier to dial in**
and **more stable**. The underlying conversion engine is unchanged — these are
comfort and reliability features on top of it:

- **Auto Pitch** — automatically keeps your converted voice inside the model's
  comfortable pitch range, so it never drifts squeaky-high or too deep. No more
  hunting for the one "right" pitch number by hand.
- **Noise-robust Auto Pitch** — ignores chair squeaks, keyboard taps, and other
  non-voice sounds so they can't yank your pitch around mid-sentence.
- **Voice calibration** — talk for ~45 seconds **once** and it saves a tiny
  *pitch profile* (just a few numbers — **no audio recording is ever stored**).
  Auto Pitch then locks onto your real voice instantly and rejects sounds
  outside your personal range.
- **Pitch limits** — set the lowest and highest pitch Auto Pitch is allowed to
  use, so it can never jump too far.
- **Auto-smooth** — watches how hard your PC is working and adjusts the audio
  buffer on the fly to reduce stutter while keeping latency low.
- **Background noise cleanup** — one click turns on your browser's built-in
  microphone noise suppression.
- **Extra Controls panel** — one tidy on-screen grid (with hover tooltips) for
  all of the above plus quality tweaks: breath detail, de-ess, leveling,
  formant, word-tail, and input gate.
- **Two-PC convenience launcher** — a Windows `.bat` that opens the client in
  Chrome with background-throttling disabled (fixes audio stutter when the
  window is hidden behind OBS) and **auto-finds the host PC by name** on your
  local network.

> These are usability and stability improvements. They do **not** change how the
> underlying models actually convert your voice.

## 🆚 How this is different from other voice changers

- **It runs on *your* computer, not a cloud service.** Many popular voice
  changers send your microphone audio to a company's servers. This one does the
  conversion **locally** on your own machine. Nothing about you is uploaded — see
  [`PRIVACY.md`](./PRIVACY.md).
- **No account, no subscription, no paywall.** It's free and open source. You can
  read every line of code if you want to.
- **Tuned for real-time, low latency.** It is based on a fork that focuses on
  fast, RVC-based conversion that works well even on integrated and older GPUs.
- **It's beginner-friendly.** The features above exist specifically so that
  someone who isn't an audio engineer can get a good-sounding result quickly,
  instead of fiddling with sliders for an hour.
- **You bring your own voice models.** It works with Retrieval-based Voice
  Conversion (RVC) models, so you're not limited to a handful of preset voices.

> **Note:** this version works **only** with Retrieval-based Voice Conversion
> (RVC) models.

## 🚀 Setup — for someone who has never touched code

You do **not** need to know any programming to use this. The easiest path is to
download a ready-made package and double-click it.

### What you'll need first

- A **Windows 10 (or newer)** PC. (macOS and Linux also work — see the
  [full manual](./voice%20changer/README.md) — but Windows is the simplest.)
- About **6 GB of free disk space** and **6 GB of RAM**.
- A **microphone**.
- For changing your voice inside games/Discord/OBS, a free "virtual audio cable":
  [VAC Lite by Muzychenko](https://software.muzychenko.net/freeware/vac470lite.zip).
- A program to unzip files, like the free [7-Zip](https://www.7-zip.org/).

### Step-by-step (Windows)

1. **Find out what graphics you have.** Open **Task Manager** (press
   `Ctrl + Shift + Esc`) → **Performance** tab → click **GPU**. Note whether it
   says **Nvidia**, **AMD**, or **Intel**.
2. **Download the right package** from the
   [releases page](https://github.com/deiteris/voice-changer/releases):
   - **Nvidia graphics:** download the two files
     `voice-changer-windows-amd64-cuda.zip.001` and `...zip.002` into the same
     folder.
   - **AMD / Intel / no graphics card:** download
     `voice-changer-windows-amd64-dml.zip`.
3. **Unzip it.** Right-click the downloaded file → **7-Zip** → **Extract to…**.
   (For Nvidia, right-click the `.001` file — it unpacks both automatically.)
4. **Open the unzipped folder**, go into the `MMVCServerSIO` folder, and
   **double-click `MMVCServerSIO.exe`**.
5. **Wait on first run.** The first time, it downloads some files it needs. Leave
   the black window open until it's done — then it opens the voice changer in
   your web browser automatically.
6. **In the browser:** pick your **microphone** as the input, pick your speakers
   (or **Line 1 / VAC** if you set up the virtual cable) as the output, choose or
   load a **voice model**, and press **Start**.
7. **Turn on Auto Pitch** (and optionally run **Calibrate** once) from the Extra
   Controls panel, and you're done. 🎉

> 💡 If you ever hear your *normal* voice instead of the converted one, click the
> **passthru** button so it stops blinking red.

For other systems, the two-PC setup, building from source, hardware
requirements, and a detailed **troubleshooting** section, see the
**[full manual here](./voice%20changer/README.md)**.

## 🔐 Privacy & Terms (please read)

- **[`PRIVACY.md`](./PRIVACY.md)** — short version: **feris does not collect
  anything from you.** No accounts, no analytics, no telemetry, no tracking. Your
  voice and audio stay on your own device.
- **[`TERMS.md`](./TERMS.md)** — the software is provided "as is," and **you are
  responsible** for how you use it. Don't imitate someone's voice without their
  consent, and don't use it for anything illegal or deceptive.

## 🙏 Credits & attribution

This project would not exist without the work of others. All credit for the core
real-time voice-conversion engine goes to them:

- **Original project — [w-okada/voice-changer](https://github.com/w-okada/voice-changer)**
  by **Wataru Okada** and contributors. The original real-time voice changer this
  whole family of forks is built on. (MIT License — see
  [`voice changer/LICENSE`](./voice%20changer/LICENSE).)
- **Optimized real-time fork — [Deiteris/voice-changer](https://github.com/deiteris/voice-changer)**
  by **Deiteris**. The performance-focused, RVC-oriented fork that this build is
  based on.
- **feris** — the idea behind this version and the maintainer of this fork: the
  quality-of-life and stability features (Auto Pitch, calibration, pitch limits,
  auto-smooth, the Extra Controls panel, and the two-PC launcher).
- **Claude (Anthropic)** — the AI assistant that helped design and implement
  feris's quality-of-life features, this documentation, and the privacy/terms
  policies.

There is **no affiliation with, or endorsement by, w-okada or Deiteris.** All
trademarks and project names belong to their respective owners.
</content>
</invoke>
