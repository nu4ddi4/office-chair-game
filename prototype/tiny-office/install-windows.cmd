@echo off
setlocal DisableDelayedExpansion
set "GAME_DIR=%LOCALAPPDATA%\Programs\TinyOffice"
set "GAME_EXE=%GAME_DIR%\TinyOffice.exe"
if not exist "%~dp0TinyOffice.exe" (
    echo Extract all files from TinyOffice-Windows.zip before running this installer.
    pause
    exit /b 1
)
if not exist "%~dp0LICENSES.txt" (
    echo Extract all files from TinyOffice-Windows.zip before running this installer.
    pause
    exit /b 1
)
if not exist "%GAME_DIR%\." (
    mkdir "%GAME_DIR%" || goto failed
)
copy /y "%~dp0TinyOffice.exe" "%GAME_EXE%" >nul || goto failed
copy /y "%~dp0LICENSES.txt" "%GAME_DIR%\LICENSES.txt" >nul || goto failed
powershell.exe -NoProfile -Command "$ErrorActionPreference = 'Stop'; $shortcutPath = Join-Path ([Environment]::GetFolderPath('Programs')) 'Tiny Office.lnk'; $shell = New-Object -ComObject WScript.Shell; $shortcut = $shell.CreateShortcut($shortcutPath); $shortcut.TargetPath = $env:GAME_EXE; $shortcut.WorkingDirectory = $env:GAME_DIR; $shortcut.Save()" || goto failed
echo Installed. Open Tiny Office from the Start menu.
pause
exit /b 0

:failed
echo Installation failed.
pause
exit /b 1
