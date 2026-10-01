# scripts/01-Base-Windows.ps1
# Configures base Windows OS settings: Long Paths, Developer Mode, Power, Explorer, ExecutionPolicy

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "$PSScriptRoot\..\config.json"
)

$modulesPath = Join-Path -Path $PSScriptRoot -ChildPath "..\modules"
if (-not (Get-Command "Write-Log" -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path -Path $modulesPath -ChildPath "Logging.psm1") -Global -DisableNameChecking
}
Import-Module (Join-Path -Path $modulesPath -ChildPath "Environment.psm1") -DisableNameChecking

Write-LogHeader "Phase 1: Base Windows Configuration"

# Load Configuration
$config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json

# 1. Administrator Elevation Check
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Log -Level ERROR -Message "Base Windows configuration requires Administrative privileges. Please run as Administrator."
    throw "ElevationRequired"
}

# 2. Execution Policy
Write-Log -Level INFO -Message "Setting PowerShell ExecutionPolicy to RemoteSigned..."
try {
    # Set directly in registry to bypass PowerShell ExecutionPolicyOverride warning/error when Process policy is Bypass
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell",
        "HKCU:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell"
    )
    foreach ($reg in $regPaths) {
        if (-not (Test-Path $reg)) {
            New-Item -Path $reg -Force -ErrorAction SilentlyContinue | Out-Null
        }
        Set-ItemProperty -Path $reg -Name "ExecutionPolicy" -Value "RemoteSigned" -Force -ErrorAction SilentlyContinue
    }
} catch {
    Write-Log -Level DEBUG -Message "Registry ExecutionPolicy update notice: $_"
}

try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
} catch {
    Write-Log -Level DEBUG -Message "LocalMachine ExecutionPolicy notice: $_"
}

try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
} catch {
    Write-Log -Level DEBUG -Message "CurrentUser ExecutionPolicy notice: $_"
}

Write-Log -Level SUCCESS -Message "PowerShell ExecutionPolicy configured (RemoteSigned)."

# 3. Create Standard Directories
$standardDirs = @(
    $config.settings.workspaceRoot,
    $config.settings.toolsDirectory,
    $config.settings.logDirectory
)

foreach ($dir in $standardDirs) {
    if (-not (Test-Path -Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Log -Level SUCCESS -Message "Created directory: $dir"
    } else {
        Write-Log -Level DEBUG -Message "Directory already exists: $dir"
    }
}

# 4. Enable NTFS Long Paths (> 260 characters)
if ($config.settings.enableLongPaths) {
    Write-Log -Level INFO -Message "Enabling Win32 Long Path support in registry..."
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
    Set-ItemProperty -Path $regPath -Name "LongPathsEnabled" -Value 1 -Type DWord -Force
    Write-Log -Level SUCCESS -Message "Long Paths enabled."
}

# 5. Enable Windows Developer Mode
if ($config.settings.enableDeveloperMode) {
    Write-Log -Level INFO -Message "Enabling Windows Developer Mode (sideloading & symlink permissions)..."
    $devPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
    if (-not (Test-Path $devPath)) {
        New-Item -Path $devPath -Force | Out-Null
    }
    Set-ItemProperty -Path $devPath -Name "AllowDevelopmentWithoutDevLicense" -Value 1 -Type DWord -Force
    Write-Log -Level SUCCESS -Message "Developer Mode enabled."
}

# 6. Prevent VM Sleep / Hibernation
if ($config.settings.preventSleep) {
    Write-Log -Level INFO -Message "Configuring Power Policy to prevent sleep and display timeouts..."
    powercfg -change -standby-timeout-ac 0 2>$null
    powercfg -change -monitor-timeout-ac 0 2>$null
    powercfg -change -disk-timeout-ac 0 2>$null
    powercfg -hibernate off 2>$null
    Write-Log -Level SUCCESS -Message "Power policy set to High Performance / Never Sleep."
}

# 7. File Explorer Tweaks: Show extensions and hidden files
if ($config.settings.showFileExtensions -or $config.settings.showHiddenFiles) {
    Write-Log -Level INFO -Message "Tweaking File Explorer options..."
    $advancedPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (Test-Path $advancedPath) {
        if ($config.settings.showFileExtensions) {
            Set-ItemProperty -Path $advancedPath -Name "HideFileExt" -Value 0 -Type DWord -Force
        }
        if ($config.settings.showHiddenFiles) {
            Set-ItemProperty -Path $advancedPath -Name "Hidden" -Value 1 -Type DWord -Force
        }
        Write-Log -Level SUCCESS -Message "File extensions and hidden files set to visible."
    }
}

Write-Log -Level SUCCESS -Message "Base Windows configuration completed successfully."
