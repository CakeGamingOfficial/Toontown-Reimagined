# Downloads portable Git for Windows next to this script.
$ErrorActionPreference = "Stop"
$dest = Join-Path $PSScriptRoot "git\cmd\git.exe"
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

$headers = @{ "User-Agent" = "ToontownLauncher" }
$release = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/git-for-windows/git/releases/latest"
$asset = $release.assets | Where-Object { $_.name -like "MinGit-*-64-bit.zip" -and $_.name -notlike "*busybox*" } | Select-Object -First 1
if ($null -eq $asset) {
	Write-Output "Git for Windows did not publish a 64-bit download."
	exit 1
}
$zip = Join-Path $env:TEMP $asset.name
Receive-File $asset.browser_download_url $zip "Downloading Git for Windows"
Write-ProgressLine "Unpacking Git for Windows..."
$unpack = Join-Path $PSScriptRoot "git"
if (Test-Path $unpack) {
	Remove-Item $unpack -Recurse -Force
}
Expand-Archive -Path $zip -DestinationPath $unpack
if (-not (Test-Path $dest)) {
	Write-Output "The Git download did not contain git.exe."
	exit 1
}
