@echo off
:: burnandbuild.bat - Quick-launch script for BurnAndBuild Dev Environment Provisioner
:: Automatically elevates to Administrator and runs interactive tool setup

title BurnAndBuild - Dev Environment Provisioner
cd /d "%~dp0"

echo =======================================================================
echo           BURNANDBUILD - DISPOSABLE DEV ENVIRONMENT PROVISIONER
echo =======================================================================
echo Checking Administrator privileges...

net session >nul 2>&1
if %errorLevel% == 0 (
    echo Administrator verified. Launching BurnAndBuild Provisioner...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0bootstrap.ps1" %*
) else (
    echo Requesting Administrator privileges...
    powershell.exe -NoProfile -Command "Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"\"%~dp0bootstrap.ps1\"\" %*' -Verb RunAs"
)

exit /b
