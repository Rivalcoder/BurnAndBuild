@echo off
:: Start-Windows.bat - Master launcher for BurnAndBuild Dev Environment Provisioner (Windows)
:: Automatically requests Administrator elevation and opens interactive GUI/CLI setup
title BurnAndBuild - Dev Environment Provisioner
cd /d "%~dp0"

echo =======================================================================
echo           BURNANDBUILD - DISPOSABLE DEV ENVIRONMENT PROVISIONER
echo =======================================================================
echo Checking Administrator privileges...

net session >nul 2>&1
if %errorLevel% == 0 (
    echo Administrator verified. Launching BurnAndBuild Provisioner...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\bootstrap.ps1" %*
) else (
    echo Requesting Administrator privileges...
    powershell.exe -NoProfile -Command "Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"\"%~dp0scripts\bootstrap.ps1\"\" %*' -Verb RunAs"
)

exit /b
