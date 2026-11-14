# Downloads the official Godot 4.7.2 Windows build next to this script.
$ErrorActionPreference = "Stop"
$dest = Join-Path $PSScriptRoot "Godot.exe"
if (Test-Path $dest) {
	exit 0
}

function Write-ProgressLine($text) {
	[Console]::Out.WriteLine($text)
	[Console]::Out.Flush()
}

function Format-Remaining($seconds) {
	if ($seconds -le 1) { return "about a second left" }
	if ($seconds -lt 60) { return "about $seconds seconds left" }
	$minutes = [int][Math]::Round($seconds / 60.0)
	if ($minutes -le 1) { return "about a minute left" }
	if ($minutes -lt 60) { return "about $minutes minutes left" }
	$hours = [int][Math]::Round($minutes / 60.0)
	if ($hours -le 1) { return "about an hour left" }
	return "about $hours hours left"
}

function Receive-File($url, $destPath, $label) {
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	$request = [System.Net.HttpWebRequest]::Create($url)
	$request.UserAgent = "ToontownLauncher"
	$request.AllowAutoRedirect = $true
	$response = $request.GetResponse()
	$total = $response.ContentLength
	$stream = $response.GetResponseStream()
	$out = [System.IO.File]::Open($destPath, [System.IO.FileMode]::Create)
	$buffer = New-Object byte[] 65536
	$sofar = [int64]0
	$started = Get-Date
	$lastReport = [datetime]::MinValue
	try {
		while ($true) {
			$read = $stream.Read($buffer, 0, $buffer.Length)
			if ($read -le 0) { break }
			$out.Write($buffer, 0, $read)
			$sofar += $read
			$now = Get-Date
			if ($total -le 0 -or ($now - $lastReport).TotalMilliseconds -lt 400) { continue }
			$lastReport = $now
			$pct = [int][Math]::Floor(100.0 * $sofar / $total)
			if ($pct -gt 99 -and $sofar -lt $total) { $pct = 99 }
			$tail = ""
			$elapsed = ($now - $started).TotalSeconds
			if ($pct -gt 0 -and $elapsed -ge 1) {
				$remain = [int][Math]::Round($elapsed * (100 - $pct) / $pct)
				$tail = ", " + (Format-Remaining $remain)
			}
			Write-ProgressLine ("{0}... {1}%{2}" -f $label, $pct, $tail)
		}
	} finally {
		$out.Close()
		$stream.Close()
		$response.Close()
	}
	if ($total -gt 0) {
		Write-ProgressLine ("{0}... 100%" -f $label)
	}
}

$url = "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_win64.exe.zip"
$zip = Join-Path $env:TEMP "Godot_v4.7.2-stable_win64.exe.zip"
$unpack = Join-Path $env:TEMP "godot-4.7.2-unpack"
Receive-File $url $zip "Downloading Godot 4.7.2"
Write-ProgressLine "Unpacking Godot 4.7.2..."
if (Test-Path $unpack) {
	Remove-Item $unpack -Recurse -Force
}
Expand-Archive -Path $zip -DestinationPath $unpack
$exe = Get-ChildItem $unpack -Filter "Godot_v4.7.2-stable_win64.exe" -Recurse |
	Where-Object { $_.Name -notlike "*console*" } |
	Select-Object -First 1
if ($null -eq $exe) {
	Write-Output "The Godot download did not contain the Windows exe."
	exit 1
}
Copy-Item $exe.FullName $dest
Write-Host "Saved Godot to $dest"
