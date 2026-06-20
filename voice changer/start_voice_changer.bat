@echo off
REM ============================================================
REM  Voice Changer launcher (NVIDIA / CUDA build)
REM
REM  Just double-click this file.
REM   * First run: it sets everything up automatically
REM     (creates the Python environment and downloads the
REM      required packages -- this takes a while, one time only).
REM   * Every run after that: it just starts the voice changer
REM     and opens your web browser.
REM
REM  REQUIREMENT: Python must be installed first (see the message
REM  this script shows if it is missing).
REM ============================================================

setlocal
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
REM Install the CUDA build of PyTorch FIRST, from NVIDIA's index, so the GPU
REM is actually used. (The plain requirements file can pull a CPU-only build.)
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

REM --- 5. Start the voice changer -----------------------------
echo Starting Voice Changer...
echo A browser window will open when the server is ready.
echo Keep THIS window open while you use the voice changer.
echo Close this window ^(or press Ctrl+C^) to stop it.
echo.
python client.py %*

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
echo.
echo  If it still says "not found" afterwards:
echo    Settings ^> Apps ^> Advanced app settings ^>
echo    App execution aliases ^> turn OFF the two "python" aliases.
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
