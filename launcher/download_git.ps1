# Downloads portable Git for Windows next to this script.
$ErrorActionPreference = "Stop"
$dest = Join-Path $PSScriptRoot "git\cmd\git.exe"
if (Test-Path $dest) {
	exit 0
}
$headers = @{ "User-Agent" = "ToontownLauncher" }
$release = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/git-for-windows/git/releases/latest"
$asset = $release.assets | Where-Object { $_.name -like "MinGit-*-64-bit.zip" -and $_.name -notlike "*busybox*" } | Select-Object -First 1
if ($null -eq $asset) {
	Write-Host "Git for Windows did not publish a 64-bit download."
	exit 1
}
Write-Host "Downloading $($asset.name)..."
$zip = Join-Path $env:TEMP $asset.name
Invoke-WebRequest -Headers $headers -Uri $asset.browser_download_url -OutFile $zip
$unpack = Join-Path $PSScriptRoot "git"
if (Test-Path $unpack) {
	Remove-Item $unpack -Recurse -Force
}
Expand-Archive -Path $zip -DestinationPath $unpack
if (-not (Test-Path $dest)) {
	Write-Host "The Git download did not contain git.exe."
	exit 1
}
Write-Host "Saved Git to $dest"
