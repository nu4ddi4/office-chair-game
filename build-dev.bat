@echo off
rem Build chaos-dev\OfficeChairChaos.exe (no export templates needed) and start it.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\dev.ps1" build -Run %*
if errorlevel 1 pause
