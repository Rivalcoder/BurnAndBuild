@echo off
:: Start-Setup.bat - Quick-launch script for Windows VM Dev Environment Provisioner
:: Automatically elevates to Administrator and runs interactive tool setup

title Windows Dev VM Provisioner
cd /d "%~dp0"

echo =======================================================================
echo           WINDOWS DISPOSABLE DEV ENVIRONMENT PROVISIONER
echo =======================================================================
echo Checking Administrator privileges...

net session >nul 2>&1
if %errorLevel% == 0 (
    echo Administrator verified. Launching Tool Provisioner...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0bootstrap.ps1"
) else (
    echo Requesting Administrator privileges...
    powershell.exe -NoProfile -Command "Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"\"%~dp0bootstrap.ps1\"\"' -Verb RunAs"
)

exit /b
