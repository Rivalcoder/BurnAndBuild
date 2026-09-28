# scripts/06-Docker.ps1
# Automates Docker Desktop installation, WSL 2 / Virtualization pre-requisites, and CLI PATH setup

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
Import-Module (Join-Path -Path $modulesPath -ChildPath "WinGetHelper.psm1") -DisableNameChecking

Write-LogHeader "Phase 6: Docker Desktop & Container Toolchain Automation"

# Load Configuration
$config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json
$dockerPkgId = if ($config.wingetPackages.docker -and $config.wingetPackages.docker.id) {
    $config.wingetPackages.docker.id
} else {
    "Docker.DockerDesktop"
}

# 1. Check if Docker is already installed
$dockerCmd = Get-Command "docker.exe" -ErrorAction SilentlyContinue
$dockerApp = "C:\Program Files\Docker\Docker\Docker Desktop.exe"

if ($dockerCmd -or (Test-Path $dockerApp)) {
    Write-Log -Level INFO -Message "Docker Desktop is already installed on this machine."
} else {
    # 2. Check / Enable WSL & Virtualization Features
    Write-Log -Level STEP -Message "Verifying Windows Subsystem for Linux (WSL) prerequisites..."
    try {
        Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -NoRestart -ErrorAction SilentlyContinue | Out-Null
        Enable-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -NoRestart -ErrorAction SilentlyContinue | Out-Null
        Write-Log -Level SUCCESS -Message "Virtualization & WSL feature flags configured."
    } catch {
        Write-Log -Level WARN -Message "Notice while configuring Windows Optional Features: $_"
    }

    # 3. Ensure WinGet is available & install Docker Desktop
    Ensure-WinGetAvailable
    Write-Log -Level STEP -Message "Installing Docker Desktop via WinGet ($dockerPkgId)..."

    $installed = Install-WinPackage -PackageId $dockerPkgId -DisplayName "Docker Desktop"
    if ($installed) {
        Write-Log -Level SUCCESS -Message "Docker Desktop package installation completed."
    } else {
        Write-Log -Level WARN -Message "WinGet reported an issue installing Docker Desktop. Trying direct download fallback..."

        # Fallback to direct official installer
        $installerUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
        $tempInstaller = Join-Path -Path $env:TEMP -ChildPath "DockerDesktopInstaller.exe"
        try {
            Write-Log -Level INFO -Message "Downloading Docker Desktop directly from official CDN: $installerUrl"
            Invoke-WebRequest -Uri $installerUrl -OutFile $tempInstaller -UseBasicParsing

            Write-Log -Level INFO -Message "Running Docker installer in silent mode..."
            $p = Start-Process -FilePath $tempInstaller -ArgumentList "install --quiet --accept-license" -Wait -PassThru
            if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010) {
                Write-Log -Level SUCCESS -Message "Docker Desktop direct install succeeded."
            } else {
                Write-Log -Level WARN -Message "Docker direct installer finished with exit code $($p.ExitCode)."
            }
        } catch {
            Write-Log -Level ERROR -Message "Direct Docker install encountered error: $_"
        } finally {
            Remove-Item -Path $tempInstaller -Force -ErrorAction SilentlyContinue
        }
    }
}

# 4. Configure PATH for Docker CLI and Tools
$dockerBinDirs = @(
    "C:\Program Files\Docker\Docker\resources\bin",
    "C:\ProgramData\DockerDesktop\version-bin"
)

foreach ($dir in $dockerBinDirs) {
    if (Test-Path $dir) {
        Add-PathSafe -PathToAdd $dir -Target "Machine"
    }
}

Refresh-SessionEnvironment

# 5. Check Docker CLI
$finalDockerCmd = Get-Command "docker.exe" -ErrorAction SilentlyContinue
if ($finalDockerCmd) {
    try {
        $v = & docker --version 2>$null
        Write-Log -Level SUCCESS -Message "Docker CLI operational: $v"
    } catch {
        Write-Log -Level INFO -Message "Docker CLI found on PATH."
    }
} else {
    Write-Log -Level INFO -Message "Docker installed. A system reboot or shell refresh may be needed to start the Docker Desktop service."
}

Write-Log -Level SUCCESS -Message "Docker Desktop setup completed."
