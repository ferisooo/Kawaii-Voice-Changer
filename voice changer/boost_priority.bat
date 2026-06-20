@echo off
REM ============================================================
REM  Boost priority for smoother audio
REM
REM  Sets the voice changer (python), the Windows audio engine
REM  (audiodg), and your browser to HIGH process priority so they
REM  get more CPU time. Run this AFTER the voice changer and your
REM  browser are already open.
REM
REM  Needs admin (for audiodg) -- it will ask for permission.
REM  Effect lasts until those programs are closed; re-run as needed.
REM
REM  NOTE: Per-browser-TAB priority cannot be set from outside the
REM  browser; this raises the whole browser instead. We do NOT use
REM  "Realtime" priority because it can freeze Windows.
REM ============================================================

REM --- Self-elevate to admin if needed ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator permission...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo Setting HIGH priority for: python, audiodg, chrome, msedge, firefox ...
echo.
powershell -NoProfile -Command ^
  "$names='python','pythonw','audiodg','chrome','msedge','firefox';" ^
  "foreach($n in $names){" ^
  "  $p=Get-Process -Name $n -ErrorAction SilentlyContinue;" ^
  "  if($p){ foreach($proc in $p){ try{ $proc.PriorityClass='High'; Write-Host ('  [OK]   '+$proc.ProcessName+' ('+$proc.Id+')') }catch{ Write-Host ('  [skip] '+$n+' - '+$_.Exception.Message) } } }" ^
  "  else { Write-Host ('  [--]   '+$n+' not running') }" ^
  "}"

echo.
echo Done. (Run again after restarting the voice changer or browser.)
pause
