@echo off
cd /d "G:\Toontown-Reimagined\Godot Project"
echo Updating the server at kai@192.168.4.60
echo You will be asked for kai's password twice.
echo.
ssh kai@192.168.4.60 "rm -rf ~/project-toontown"
if errorlevel 1 (
	echo Could not reach the server. Nothing was copied.
	pause
	exit /b 1
)
scp -r .\project-toontown kai@192.168.4.60:~/
if errorlevel 1 (
	echo The copy failed.
	pause
	exit /b 1
)
echo.
echo Copy finished. On the Ubuntu server, press Ctrl+C if it is still running, then start it again:
echo ./Godot_v4.7.2-stable_linux.x86_64 --headless --path "/home/kai/project-toontown"
pause
