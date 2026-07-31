@echo off
setlocal
set SCRIPT_DIR=%~dp0
where pwsh >nul 2>&1
if %ERRORLEVEL%==0 (
    pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Install-Zpwsh.ps1" %*
) else (
    powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Install-Zpwsh.ps1" %*
)
exit /b %ERRORLEVEL%
