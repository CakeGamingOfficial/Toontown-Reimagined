@echo off
setlocal
set CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe
set ROOT=%~dp0
set OUT=%ROOT%bin
if not exist "%OUT%" mkdir "%OUT%"
"%CSC%" /nologo /target:winexe /optimize+ /out:"%OUT%\ToontownLauncher.exe" /win32icon:"%ROOT%..\assets\logo.ico" /win32manifest:"%ROOT%app.manifest" /r:System.dll /r:System.Core.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll /r:System.Net.Http.dll /r:System.Web.Extensions.dll /resource:"%ROOT%..\assets\sky.png",sky.png /resource:"%ROOT%..\assets\logo.png",logo.png /resource:"%ROOT%..\assets\logo.ico",logo.ico /resource:"%ROOT%..\assets\scroll.png",scroll.png /resource:"%ROOT%..\assets\button_up.png",button_up.png /resource:"%ROOT%..\assets\button_down.png",button_down.png /resource:"%ROOT%..\assets\button_hover.png",button_hover.png /resource:"%ROOT%..\assets\ImpressBT.ttf",ImpressBT.ttf "%ROOT%Program.cs" "%ROOT%Services.cs" "%ROOT%MainForm.cs"
if errorlevel 1 exit /b 1
echo Built %OUT%\ToontownLauncher.exe
