@echo off
setlocal
cd /d "%~dp0"
where python >nul 2>nul
if errorlevel 1 (
  echo Python 3 was not found on PATH. Install Python 3 and retry.
  pause
  exit /b 1
)
python build_sms_core.py --all
if errorlevel 1 (
  echo.
  echo BUILD FAILED. See build\gowin-build.log
  pause
  exit /b 1
)
echo.
echo Build complete. Confirm the .fs path printed above.
pause
