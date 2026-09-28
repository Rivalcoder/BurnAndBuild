# modules/WinGetHelper.psm1
# Robust winget package management and automated bootstrapper

[CmdletBinding()]
param()

if (-not (Get-Command "Write-Log" -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "Logging.psm1") -Global
}
if (-not (Get-Command "Set-EnvironmentVariableSafe" -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "Environment.psm1") -Global
}

function Test-WinGet {
    [CmdletBinding()]
    param()

    try {
        $wingetCmd = Get-Command "winget.exe" -ErrorAction SilentlyContinue
        if ($wingetCmd) {
            $version = & winget --version 2>$null
            if ($version) {
                Write-Log -Level INFO -Message "Found winget version: $version"
                return $true
            }
        }
    } catch {}

    return $false
}

function Install-WinGetPrerequisites {
    [CmdletBinding()]
    param()

    Write-Log -Level STEP -Message "WinGet not detected. Installing WinGet (App Installer) and dependencies..."

    $tempDir = Join-Path -Path $env:TEMP -ChildPath "winget-install"
    if (-not (Test-Path -Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    }

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # 1. Download and install Microsoft VCLibs
        $vclibsUrl = "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx"
        $vclibsPath = Join-Path -Path $tempDir -ChildPath "Microsoft.VCLibs.appx"
        Write-Log -Level INFO -Message "Downloading VCLibs dependency..."
        Invoke-WebRequest -Uri $vclibsUrl -OutFile $vclibsPath -UseBasicParsing
        Add-AppxPackage -Path $vclibsPath -ErrorAction SilentlyContinue

        # 2. Download and install UI.Xaml
        $uiXamlUrl = "https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx"
        $uiXamlPath = Join-Path -Path $tempDir -ChildPath "Microsoft.UI.Xaml.appx"
        Write-Log -Level INFO -Message "Downloading UI.Xaml dependency..."
        Invoke-WebRequest -Uri $uiXamlUrl -OutFile $uiXamlPath -UseBasicParsing
        Add-AppxPackage -Path $uiXamlPath -ErrorAction SilentlyContinue

        # 3. Download and install DesktopAppInstaller (WinGet)
        $wingetUrl = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        $wingetPath = Join-Path -Path $tempDir -ChildPath "Microsoft.DesktopAppInstaller.msixbundle"
        Write-Log -Level INFO -Message "Downloading latest WinGet msixbundle..."
        Invoke-WebRequest -Uri $wingetUrl -OutFile $wingetPath -UseBasicParsing
        Add-AppxPackage -Path $wingetPath -ErrorAction Stop

        Write-Log -Level SUCCESS -Message "WinGet installed successfully."

        # Add WindowsApps to PATH if needed
        $localAppData = [Environment]::GetFolderPath("LocalApplicationData")
        $windowsAppsPath = Join-Path -Path $localAppData -ChildPath "Microsoft\WindowsApps"
        Add-PathSafe -PathToAdd $windowsAppsPath -Target "User"

        Refresh-SessionEnvironment
    } catch {
        Write-Log -Level ERROR -Message "Failed to install WinGet automatically: $_"
        throw $_
    } finally {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Ensure-WinGetAvailable {
    [CmdletBinding()]
    param()

    if (-not (Test-WinGet)) {
        Install-WinGetPrerequisites
        if (-not (Test-WinGet)) {
            throw "WinGet installation completed but winget.exe command is still unavailable in current session."
        }
    }
}

function Test-WinPackageInstalled {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageId
    )

    try {
        $result = & winget list --id $PackageId --exact --accept-source-agreements 2>$null | Out-String
        if ($result -match [regex]::Escape($PackageId)) {
            return $true
        }
    } catch {}

    return $false
}

function Install-WinPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageId,

        [Parameter(Mandatory = $false)]
        [string]$DisplayName = "",

        [Parameter(Mandatory = $false)]
        [string]$CustomArguments = "",

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    $name = if ($DisplayName) { "$DisplayName ($PackageId)" } else { $PackageId }

    if (-not $Force -and (Test-WinPackageInstalled -PackageId $PackageId)) {
        Write-Log -Level INFO -Message "Package '$name' is already installed. Skipping."
        return $true
    }

    Write-Log -Level STEP -Message "Installing '$name' via winget..."

    $wingetArgs = @(
        "install",
        "--id", $PackageId,
        "--exact",
        "--silent",
        "--accept-package-agreements",
        "--accept-source-agreements",
        "--force"
    )

    if ($CustomArguments) {
        $wingetArgs += "--override"
        $wingetArgs += "`"$CustomArguments`""
    }

    $process = Start-Process -FilePath "winget.exe" -ArgumentList $wingetArgs -NoNewWindow -Wait -PassThru

    # Common exit codes: 0 = Success, -1978335189 = Already installed, 3010 = Reboot required
    if ($process.ExitCode -eq 0 -or $process.ExitCode -eq -1978335189) {
        Write-Log -Level SUCCESS -Message "Package '$name' installed successfully."
        Refresh-SessionEnvironment
        return $true
    } elseif ($process.ExitCode -eq 3010) {
        Write-Log -Level WARN -Message "Package '$name' installed, but system requires a reboot."
        Refresh-SessionEnvironment
        return $true
    } else {
        Write-Log -Level ERROR -Message "Failed to install '$name'. Exit code: $($process.ExitCode)"
        return $false
    }
}

Export-ModuleMember -Function Test-WinGet, Ensure-WinGetAvailable, Test-WinPackageInstalled, Install-WinPackage
