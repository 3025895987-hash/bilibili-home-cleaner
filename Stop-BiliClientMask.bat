@echo off
set "SCRIPT_DIR=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$script = Join-Path '%SCRIPT_DIR%' 'Start-BiliClientMask.ps1'; $current = $PID; Get-CimInstance Win32_Process | Where-Object { $_.Name -in @('powershell.exe','pwsh.exe') -and $_.ProcessId -ne $current -and $_.CommandLine -like ('*-File*' + $script + '*') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force; Write-Host ('Stopped process ' + $_.ProcessId) }"
