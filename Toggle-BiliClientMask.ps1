#Requires -Version 5.1

$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $PSScriptRoot "Start-BiliClientMask.ps1"
if (-not (Test-Path -LiteralPath $scriptPath)) {
  throw "Cannot find Start-BiliClientMask.ps1 in $PSScriptRoot"
}

$powershellPath = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
if (-not (Test-Path -LiteralPath $powershellPath)) {
  $powershellPath = "powershell.exe"
}

function Test-MaskProcessRunning {
  $scriptPathLower = $scriptPath.ToLowerInvariant()

  $processes = Get-CimInstance Win32_Process -Filter "name = 'powershell.exe' or name = 'pwsh.exe'"
  foreach ($process in $processes) {
    $commandLine = ([string]$process.CommandLine).ToLowerInvariant()
    if ($commandLine.Contains("-file") -and $commandLine.Contains($scriptPathLower)) {
      return $true
    }
  }

  return $false
}

if (-not (Test-MaskProcessRunning)) {
  Start-Process -FilePath $powershellPath -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-WindowStyle",
    "Hidden",
    "-File",
    $scriptPath
  ) -WorkingDirectory $PSScriptRoot

  Write-Host "Bili client mask started."
  return
}

$createdNew = $false
$toggleEvent = [System.Threading.EventWaitHandle]::new(
  $false,
  [System.Threading.EventResetMode]::AutoReset,
  "Local\BiliClientMaskToggle",
  [ref]$createdNew
)

try {
  [void]$toggleEvent.Set()
} finally {
  $toggleEvent.Dispose()
}

Write-Host "Bili client mask toggled."
