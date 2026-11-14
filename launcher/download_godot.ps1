# Downloads the official Godot 4.7.2 Windows build next to this script.
$ErrorActionPreference = "Stop"
$dest = Join-Path $PSScriptRoot "Godot.exe"
if (Test-Path $dest) {
	exit 0
}
$url = "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_win64.exe.zip"
$zip = Join-Path $env:TEMP "Godot_v4.7.2-stable_win64.exe.zip"
$unpack = Join-Path $env:TEMP "godot-4.7.2-unpack"
Write-Host "Downloading Godot 4.7.2..."
Invoke-WebRequest -Uri $url -OutFile $zip
if (Test-Path $unpack) {
	Remove-Item $unpack -Recurse -Force
}
Expand-Archive -Path $zip -DestinationPath $unpack
$exe = Get-ChildItem $unpack -Filter "Godot_v4.7.2-stable_win64.exe" -Recurse |
	Where-Object { $_.Name -notlike "*console*" } |
	Select-Object -First 1
if ($null -eq $exe) {
	Write-Host "The Godot download did not contain the Windows exe."
	exit 1
}
Copy-Item $exe.FullName $dest
Write-Host "Saved Godot to $dest"
