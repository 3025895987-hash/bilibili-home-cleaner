#Requires -Version 5.1

$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $PSScriptRoot "Start-BiliClientMask.ps1"
if (-not (Test-Path -LiteralPath $scriptPath)) {
  throw "Cannot find Start-BiliClientMask.ps1 in $PSScriptRoot"
}

$startupFolder = [Environment]::GetFolderPath([Environment+SpecialFolder]::Startup)
if ([string]::IsNullOrWhiteSpace($startupFolder)) {
  throw "Cannot find the current user's Startup folder."
}

$powershellPath = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
if (-not (Test-Path -LiteralPath $powershellPath)) {
  $powershellPath = "powershell.exe"
}

$shortcutPath = Join-Path $startupFolder "BiliClientMask.lnk"
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $powershellPath
$shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
$shortcut.WorkingDirectory = $PSScriptRoot
$shortcut.WindowStyle = 7
$shortcut.Description = "Start BiliClientMask when Windows signs in"
$shortcut.IconLocation = "$powershellPath,0"
$shortcut.Save()

Write-Host "Installed startup shortcut:"
Write-Host $shortcutPath

Start-Process -FilePath $powershellPath -ArgumentList @(
  "-NoProfile",
  "-ExecutionPolicy",
  "Bypass",
  "-WindowStyle",
  "Hidden",
  "-File",
  $scriptPath
) -WorkingDirectory $PSScriptRoot

Write-Host "BiliClientMask has been started for this session."
