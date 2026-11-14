@echo off
setlocal
set "ROOT=%~dp0"
set "GODOT=%ROOT%Godot.exe"
if exist "%GODOT%" goto launch
set "GODOT=C:\Users\fukuy\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT%" goto launch
for /f "delims=" %%I in ('where godot 2^>nul') do (
  set "GODOT=%%I"
  goto launch
)
echo Downloading Godot 4.7.2...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%download_godot.ps1"
if exist "%ROOT%Godot.exe" (
  set "GODOT=%ROOT%Godot.exe"
  goto launch
)
echo The Godot download did not finish.
pause
exit /b 1
:launch
if exist "%ROOT%git\cmd\git.exe" goto startgame
where git >nul 2>&1
if not errorlevel 1 goto startgame
echo Downloading Git for Windows...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%download_git.ps1"
if not exist "%ROOT%git\cmd\git.exe" (
  echo The Git download did not finish.
  pause
  exit /b 1
)
:startgame
if exist "%ROOT%.godot\imported" goto ready
echo Preparing the launcher...
"%GODOT%" --headless --path "%ROOT%." --import --quit
if errorlevel 1 (
  echo The launcher could not be prepared.
  pause
  exit /b 1
)
:ready
start "" "%GODOT%" --path "%ROOT%."
