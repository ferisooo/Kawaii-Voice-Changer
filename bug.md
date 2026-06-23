# 🎤 Kawaii Mic Diagnostic

Records your mic with **zero processing** (no w-okada, no RVC) so you can
finally tell whether the garble is the **mic** or the **changer**.

## How to use
1. Double-click `KawaiiMicDiag.bat`
2. It lists every audio input device. Copy your headset mic name exactly.
3. It records 10 seconds raw, then auto-plays it back.
4. Talk for the first ~5s, stay silent the last ~5s.

## Reading the result
- **Clean voice + clean silence** → mic is fine. The garble is the changer / RVC chain.
- **Garbled here too** → it's the mic, driver, or hardware — not the changer.

This is the test that actually splits the problem instead of guessing.

## Note
Needs `ffmpeg.exe`. The script auto-finds it if it's in PATH, in `C:\ffmpeg\bin\`,
or sitting next to the .bat. You already have it from CyberSnatcher — just drop a
copy beside this file if it can't find it.
