#Requires -Version 5.1

$ErrorActionPreference = "Stop"

$startupFolder = [Environment]::GetFolderPath([Environment+SpecialFolder]::Startup)
if ([string]::IsNullOrWhiteSpace($startupFolder)) {
  throw "Cannot find the current user's Startup folder."
}

$shortcutPath = Join-Path $startupFolder "BiliClientMask.lnk"
if (Test-Path -LiteralPath $shortcutPath) {
  Remove-Item -LiteralPath $shortcutPath -Force
  Write-Host "Removed startup shortcut:"
  Write-Host $shortcutPath
} else {
  Write-Host "Startup shortcut is not installed:"
  Write-Host $shortcutPath
}
