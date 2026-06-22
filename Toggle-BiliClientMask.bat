@echo off
set "SCRIPT_DIR=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$flag = Join-Path '%SCRIPT_DIR%' 'BiliClientMask.disabled'; if (Test-Path -LiteralPath $flag) { Remove-Item -LiteralPath $flag -Force; Write-Host 'Bili client mask enabled.' } else { Set-Content -LiteralPath $flag -Value 'disabled' -Encoding ASCII; Write-Host 'Bili client mask disabled.' }"
