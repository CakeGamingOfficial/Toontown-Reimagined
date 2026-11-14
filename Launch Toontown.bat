@echo off
setlocal
set "ROOT=%~dp0"
set "GODOT=%ROOT%launcher\Godot.exe"
if exist "%GODOT%" goto launch
set "GODOT=C:\Users\fukuy\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT%" goto launch
for /f "delims=" %%I in ('where godot 2^>nul') do (
  set "GODOT=%%I"
  goto launch
)
echo Put Godot 4.7.2 at launcher\Godot.exe
echo Copy Godot_v4.7.2-stable_win64.exe and rename it Godot.exe
pause
exit /b 1
:launch
start "" "%GODOT%" --path "%ROOT%launcher"
