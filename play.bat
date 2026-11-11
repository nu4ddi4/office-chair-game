@echo off
rem Run the game straight from the source tree (downloads Godot 4.7.2 on first use if needed).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\dev.ps1" play %*
