@echo off
REM ============================================================
REM  Voice Changer launcher -- "PC2 (host over LAN)" mode
REM
REM  Run this on PC2 (the powerful PC with the NVIDIA GPU).
REM  PC1 then just opens PC2's address in a web browser -- it
REM  sends your microphone over the LAN, PC2 converts it, and
REM  sends it straight back. Nothing needs to be installed on PC1.
REM
REM  Differences from the normal launcher:
REM    * Listens on the whole network (not just this PC).
REM    * Accepts connections from PC1 (origin check relaxed).
REM    * Serves over HTTPS, which browsers REQUIRE to use a
REM      microphone from another PC.
REM
REM  REQUIREMENT: Python must be installed first (see the message
REM  this script shows if it is missing).
REM ============================================================

setlocal

REM --- LAN host settings (read by the server at startup) ------
REM Listen on all network interfaces so PC1 can reach this PC.
set HOST=0.0.0.0
REM Accept connections from other PCs on the LAN.
set ALLOWED_ORIGINS=["*"]

cd /d "%~dp0server"

REM --- 1. Make sure Python is installed -----------------------
python --version >nul 2>&1
if errorlevel 1 goto :no_python

REM --- 2. Choose the Python environment -----------------------
if exist "venv\Scripts\activate.bat" (
    call "venv\Scripts\activate.bat"
    goto :have_env
)
REM No venv. If your system Python already has the packages, just use it.
python -c "import torch" >nul 2>&1
if not errorlevel 1 (
    echo Using your system Python ^(packages already installed^).
    goto :have_env
)
REM Otherwise, set up a fresh environment.
echo First-time setup: creating the Python environment...
python -m venv venv
if errorlevel 1 goto :venv_failed
call "venv\Scripts\activate.bat"

:have_env
REM --- 3. Install the required packages if they are missing ----
python -c "import torch" >nul 2>&1
if not errorlevel 1 goto :deps_ready
echo.
echo ============================================================
echo  First-time setup: installing packages for NVIDIA ^(CUDA^).
echo  This downloads several gigabytes and can take 10-30 minutes.
echo  Please keep this window open and wait until it finishes.
echo ============================================================
echo.
python -m pip install --upgrade pip
pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu124
if errorlevel 1 goto :deps_failed
pip install -r requirements-common.txt -r requirements-cuda.txt
if errorlevel 1 goto :deps_failed
echo.
echo Setup complete!
echo.

:deps_ready
REM --- 3b. Self-heal: make sure PyTorch can see the NVIDIA GPU ---
python -c "import torch,sys; sys.exit(0 if torch.cuda.is_available() else 1)" 2>nul
if errorlevel 1 (
    echo.
    echo ============================================================
    echo  Your NVIDIA GPU was NOT detected by PyTorch.
    echo  Installing the CUDA build of PyTorch ^(about 2-3 GB^)...
    echo  This is a one-time fix. Please wait.
    echo ============================================================
    echo.
    pip uninstall -y torch torchaudio
    pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu124
)

REM --- 5. Show this PC's LAN address(es) for PC1 --------------
echo.
echo ============================================================
echo  This PC's network address(es) are listed below.
echo  On PC1, open a browser and go to:
echo.
echo        https://YOUR-IP-HERE:18888
echo.
echo  ...using the address that starts with 192.168 (or 10.).
echo ============================================================
ipconfig | findstr /i "IPv4"
echo ============================================================
echo  NOTE on PC1: the browser will warn the page is "not secure"
echo  (because of the self-signed certificate). Click "Advanced"
echo  then "Proceed / Continue" -- this is expected and safe on
echo  your own network, and is required for the microphone to work.
echo.
echo  If Windows asks to allow Python through the firewall, click
echo  "Allow access" (tick Private networks).
echo ============================================================
echo.

REM --- 6. Start the voice changer (HTTPS, no browser on PC2) ---
echo Starting Voice Changer in LAN host mode...
echo Keep THIS window open while you use the voice changer.
echo Close this window ^(or press Ctrl+C^) to stop it.
echo.
python client.py --https true --launch-browser false %*

echo.
echo The voice changer has stopped.
pause
goto :end

REM ===================== error messages =======================
:no_python
echo ============================================================
echo  Python was not found on this PC (the "Python was not found"
echo  message means only a Windows Store placeholder is present).
echo.
echo  Please install Python 3.10 first:
echo    1. Open: https://www.python.org/downloads/release/python-31011/
echo    2. Scroll down and download "Windows installer (64-bit)".
echo    3. Run the installer and TICK the box
echo       "Add python.exe to PATH" before clicking Install.
echo    4. When it finishes, double-click this file again.
echo ============================================================
pause
goto :end

:venv_failed
echo [ERROR] Could not create the Python environment.
echo         Make sure Python 3.10 is installed correctly, then retry.
pause
goto :end

:deps_failed
echo [ERROR] Failed to install the required packages.
echo         Check the messages above (often an internet issue).
echo         You can simply double-click this file again to retry.
pause
goto :end

:end
endlocal
