# Lets Windows Security skip the game folder. -Query only reads the list.
# Adding a folder asks Windows once. A cancelled prompt exits 1.
param(
	[Parameter(Mandatory = $true)][string]$Folder,
	[switch]$Query
)
$ErrorActionPreference = "Stop"

function Test-Excluded([string]$path) {
	try {
		$prefs = Get-MpPreference
	} catch {
		return $false
	}
	$want = $path.TrimEnd([char]92)
	foreach ($entry in @($prefs.ExclusionPath)) {
		if (-not $entry) {
			continue
		}
		$have = $entry.TrimEnd([char]92)
		if ($have -ieq $want) {
			return $true
		}
		$child = $have + [char]92
		if ($want.StartsWith($child, [System.StringComparison]::OrdinalIgnoreCase)) {
			return $true
		}
	}
	return $false
}

if ($Query) {
	if (Test-Excluded $Folder) { exit 0 }
	exit 1
}
if (Test-Excluded $Folder) {
	exit 0
}

$arg = "Add-MpPreference -ExclusionPath '" + $Folder.Replace("'", "''") + "'"
try {
	$proc = Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Verb RunAs -Wait -PassThru -WindowStyle Hidden -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $arg)
} catch {
	exit 1
}
if ($null -eq $proc -or $proc.ExitCode -ne 0) {
	exit 1
}
if (-not (Test-Excluded $Folder)) {
	exit 1
}
exit 0
