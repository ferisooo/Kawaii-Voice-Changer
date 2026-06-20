@echo off
REM ============================================================
REM  Chrome launcher for the Voice Changer web client (run on PC1)
REM
REM  Fixes the "voice stutters unless the Chrome window is focused"
REM  problem. When Chrome's window is covered by OBS / TikTok Studio
REM  (or minimized), Chrome throttles the page's main thread, which
REM  is what ships each audio chunk to/from the voice-changer server.
REM  Throttled main thread -> chunks arrive late -> stutter.
REM
REM  This launches Chrome with that throttling turned OFF, in its own
REM  isolated profile so the flags actually take effect.
REM
REM  It also AUTO-DISCOVERS PC2 by computer name, so you never have to
REM  chase PC2's IP address when it changes after a shutdown.
REM ============================================================

setlocal EnableDelayedExpansion

REM ============================================================
REM  EDIT THIS: PC2's computer name (NOT its IP).
REM
REM  The name is stable -- it does not change when the IP changes.
REM  Find it on PC2 by opening a command prompt and typing:
REM       hostname
REM  (or Settings > System > About > "Device name").
REM ============================================================
set PC2_NAME=DESKTOP-PC2

REM  Port + scheme. PC2-host mode uses https (needed for the mic
REM  from another PC). If you run the voice changer on THIS PC, set
REM  SCHEME=http and PC2_NAME=localhost.
set PORT=18888
set SCHEME=https

REM  Optional manual override. If you fill this in, auto-discovery is
REM  skipped and this exact address is used, e.g.
REM       set SERVER_URL=https://192.168.1.50:18888
set SERVER_URL=

REM --- Auto-discover PC2 by name (resolve to its CURRENT IP) --
REM  Uses ping only to RESOLVE the name: it parses the [x.x.x.x] in
REM  ping's output. This uses the same OS resolver Chrome uses and is
REM  locale-independent (we key off the brackets, not the text). If
REM  the name cannot be resolved to an IP, we hand the name straight
REM  to Chrome and let it try.
if not defined SERVER_URL (
    echo Looking for "%PC2_NAME%" on the network...
    set "FOUND_IP="
    for /f "tokens=2 delims=[]" %%a in ('ping -4 -n 1 -w 1000 %PC2_NAME% 2^>nul ^| findstr /r /c:"\["') do set "FOUND_IP=%%a"
    if defined FOUND_IP (
        set SERVER_URL=%SCHEME%://!FOUND_IP!:%PORT%
        echo Found PC2 at !FOUND_IP!
    ) else (
        echo Could not resolve "%PC2_NAME%" to an IP -- letting Chrome try the name directly.
        set SERVER_URL=%SCHEME%://%PC2_NAME%:%PORT%
    )
)

REM --- The anti-throttling flags (the actual stutter fix) -----
REM  CalculateNativeWinOcclusion: on Windows, Chrome SEPARATELY decides its
REM    window is "covered" (by OBS / TikTok Studio / a maximized app) and
REM    freezes the renderer -- even with --disable-backgrounding-occluded-
REM    windows. Turning this feature off is what stops the periodic freezes
REM    when Chrome is not the top window.
REM  IntensiveWakeUpThrottling: clamps page timers hard after a few minutes
REM    hidden; disabling it keeps audio chunks flowing on time.
set FLAGS=--disable-backgrounding-occluded-windows --disable-renderer-backgrounding --disable-background-timer-throttling --disable-features=CalculateNativeWinOcclusion,IntensiveWakeUpThrottling

REM --- Isolated profile so the flags above actually apply -----
REM     (Chrome ignores flags when joining an already-running process.)
set PROFILE_DIR=%~dp0chrome-voicechanger-profile

REM --- Trust PC2's self-signed cert (https), so the mic works --
echo %SERVER_URL% | findstr /I /C:"https" >nul
if not errorlevel 1 set FLAGS=%FLAGS% --ignore-certificate-errors

REM --- Locate chrome.exe --------------------------------------
set "CHROME="
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not defined CHROME if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" set "CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if not defined CHROME if exist "%LocalAppData%\Google\Chrome\Application\chrome.exe" set "CHROME=%LocalAppData%\Google\Chrome\Application\chrome.exe"
if not defined CHROME goto :no_chrome

echo Launching Chrome for the voice changer...
echo   URL    : %SERVER_URL%
echo   Profile: %PROFILE_DIR%
echo.

start "" "%CHROME%" %FLAGS% --user-data-dir="%PROFILE_DIR%" --new-window "%SERVER_URL%"
goto :eof

:no_chrome
echo.
echo  ERROR: Could not find chrome.exe in the usual locations.
echo  If Chrome is installed elsewhere, open this .bat in a text
echo  editor and set CHROME to the full path of chrome.exe.
echo.
pause
goto :eof
