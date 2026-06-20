@echo off
REM ============================================================
REM  Update Voice Changer from GitHub (branch: main)
REM
REM  Double-click this to download the latest version. Your voice
REM  models, settings and Python environment (venv) are KEPT --
REM  only the program files are refreshed.
REM
REM  FIRST TIME: a GitHub login may open in your browser. Log in
REM  once and it is remembered afterwards.
REM
REM  REQUIREMENT: Git for Windows must be installed (see the
REM  message this script shows if it is missing).
REM ============================================================

setlocal
cd /d "%~dp0"

set "REPO=https://github.com/ferisooo/voice-changer.git"
set "TMP=%TEMP%\vc_update_repo"

REM --- 1. Make sure Git is installed -------------------------
git --version >nul 2>&1
if errorlevel 1 goto :no_git

echo ============================================================
echo  Updating Voice Changer from GitHub...
echo  Please CLOSE the voice changer first if it is running.
echo ============================================================
echo.

REM --- 2. Download the latest repo (just the small zip) ------
if exist "%TMP%" rmdir /s /q "%TMP%"
echo Downloading latest version...
git clone --depth 1 "%REPO%" "%TMP%"
if errorlevel 1 goto :clone_failed

if not exist "%TMP%\voice changer.zip" goto :missing_zip

REM --- 3. Extract over this folder (keeps venv/models) -------
REM    --exclude keeps THIS running updater from overwriting itself.
echo.
echo Applying update...
tar -xf "%TMP%\voice changer.zip" -C "%~dp0.." --exclude="voice changer/update_from_main.bat"
if errorlevel 1 goto :extract_failed

rmdir /s /q "%TMP%"

echo.
echo ============================================================
echo  Update complete! Your models and settings were kept.
echo  You can now start the voice changer as usual.
echo ============================================================
pause
goto :end

REM ===================== error messages =======================
:no_git
echo ============================================================
echo  Git is not installed, which is needed to update.
echo.
echo  Please install "Git for Windows" once:
echo    1. Open: https://git-scm.com/download/win
echo    2. Download and run the installer.
echo    3. Click Next through the installer (defaults are fine).
echo    4. When it finishes, double-click this file again.
echo.
echo  The first update will open a GitHub login in your browser;
echo  log in once and it is remembered after that.
echo ============================================================
pause
goto :end

:clone_failed
echo.
echo [ERROR] Could not download the update.
echo   * If a GitHub login appeared, make sure you completed it.
echo   * Check your internet connection, then try again.
if exist "%TMP%" rmdir /s /q "%TMP%"
pause
goto :end

:missing_zip
echo.
echo [ERROR] The download did not contain the expected files.
if exist "%TMP%" rmdir /s /q "%TMP%"
pause
goto :end

:extract_failed
echo.
echo [ERROR] Could not unpack the update.
echo   This needs the built-in 'tar' command (Windows 10/11).
echo   Make sure Windows is up to date, then try again.
if exist "%TMP%" rmdir /s /q "%TMP%"
pause
goto :end

:end
endlocal
