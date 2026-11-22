@echo off
rem Build and launch the Tiny Office Windows client (export templates required).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\dev.ps1" build -Run %*
if errorlevel 1 pause
