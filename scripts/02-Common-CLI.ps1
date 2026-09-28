# scripts/02-Common-CLI.ps1
# Installs core CLI tools (Git, 7-Zip, jq, ripgrep, fzf, pwsh 7, gh) and sets Git defaults

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "$PSScriptRoot\..\config.json"
)

$modulesPath = Join-Path -Path $PSScriptRoot -ChildPath "..\modules"
Import-Module (Join-Path -Path $modulesPath -ChildPath "Logging.psm1") -Force
Import-Module (Join-Path -Path $modulesPath -ChildPath "Environment.psm1") -Force
Import-Module (Join-Path -Path $modulesPath -ChildPath "WinGetHelper.psm1") -Force

Write-LogHeader "Phase 2: Core CLI Tools and Shell Utilities"

# Load Configuration
$config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json

# 1. Ensure WinGet package manager is operational
Ensure-WinGetAvailable

# 2. Install Core CLI Packages
foreach ($pkg in $config.wingetPackages.coreCli) {
    Install-WinPackage -PackageId $pkg.id -DisplayName $pkg.name
}

# 3. Ensure 7-Zip and Git are on Machine PATH
$sevenZipDir = "C:\Program Files\7-Zip"
if (Test-Path $sevenZipDir) {
    Add-PathSafe -PathToAdd $sevenZipDir -Target "Machine"
}

$gitCmdDir = "C:\Program Files\Git\cmd"
if (Test-Path $gitCmdDir) {
    Add-PathSafe -PathToAdd $gitCmdDir -Target "Machine"
}

$gitUsrBinDir = "C:\Program Files\Git\usr\bin"
if (Test-Path $gitUsrBinDir) {
    Add-PathSafe -PathToAdd $gitUsrBinDir -Target "Machine"
}

$pwshDir = "C:\Program Files\PowerShell\7"
if (Test-Path $pwshDir) {
    Add-PathSafe -PathToAdd $pwshDir -Target "Machine"
}

Refresh-SessionEnvironment

# 4. Configure Git Defaults
if (Get-Command "git.exe" -ErrorAction SilentlyContinue) {
    Write-Log -Level INFO -Message "Configuring recommended Git global defaults..."
    & git config --system core.autocrlf true
    & git config --system core.longpaths true
    & git config --system init.defaultBranch main
    & git config --system credential.helper manager
    & git config --system pull.rebase false
    Write-Log -Level SUCCESS -Message "Git defaults configured (core.autocrlf=true, core.longpaths=true, branch=main)."
} else {
    Write-Log -Level WARN -Message "git.exe was not yet found in current session path. Please restart shell to reload PATH."
}

Write-Log -Level SUCCESS -Message "Core CLI tools setup completed successfully."
