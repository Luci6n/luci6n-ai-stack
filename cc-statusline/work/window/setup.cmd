@echo off
rem Double-click launcher: runs setup.ps1 next to this file. Extra args pass through (e.g. -NoFont).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*
echo.
pause
