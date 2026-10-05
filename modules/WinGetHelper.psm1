# modules/WinGetHelper.psm1
# Robust, high-velocity winget package management and automated bootstrapper with fast caching

[CmdletBinding()]
param()

$modulesPath = $PSScriptRoot
if (-not (Get-Command "Write-Log" -ErrorAction SilentlyContinue)) {
    $logPath = Join-Path -Path $modulesPath -ChildPath "Logging.psm1"
    if (Test-Path $logPath) { Import-Module $logPath -Global -DisableNameChecking }
}
if (-not (Get-Command "Set-EnvironmentVariableSafe" -ErrorAction SilentlyContinue)) {
    $envPath = Join-Path -Path $modulesPath -ChildPath "Environment.psm1"
    if (Test-Path $envPath) { Import-Module $envPath -Global -DisableNameChecking }
}

$global:BnBInstalledPackagesCache = $null
$global:BnBLastCacheTime = $null

function Test-WinGet {
    [CmdletBinding()]
    param()

    try {
        $wingetCmd = Get-Command "winget.exe" -ErrorAction SilentlyContinue
        if ($wingetCmd) {
            $version = & winget --version 2>$null
            if ($version) {
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

# Fast in-memory cache of installed winget packages to avoid repeated 3-second winget list calls
function Get-WinGetInstalledCache {
    param([switch]$Refresh)

    if (-not $global:BnBInstalledPackagesCache -or $Refresh -or (-not $global:BnBLastCacheTime) -or ((Get-Date) - $global:BnBLastCacheTime).TotalMinutes -gt 5) {
        try {
            $rawList = & winget list --accept-source-agreements 2>$null | Out-String
            $global:BnBInstalledPackagesCache = $rawList
            $global:BnBLastCacheTime = Get-Date
        } catch {
            $global:BnBInstalledPackagesCache = ""
        }
    }
    return $global:BnBInstalledPackagesCache
}

# Check Windows Registry Uninstall keys directly in <10ms
function Test-RegistryInstalled {
    param([string]$PackageId, [string]$DisplayName)

    $regKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $searchTerms = @()
    if ($PackageId) {
        $parts = $PackageId -split '\.'
        $searchTerms += $PackageId
        if ($parts.Count -gt 1) { $searchTerms += $parts[-1] }
    }
    if ($DisplayName) {
        $searchTerms += $DisplayName
    }

    foreach ($rk in $regKeys) {
        try {
            $items = Get-ItemProperty -Path $rk -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                $pName = if ($item.DisplayName) { $item.DisplayName } else { "" }
                $pId = if ($item.PSChildName) { $item.PSChildName } else { "" }

                foreach ($term in $searchTerms) {
                    if ($pName -like "*$term*" -or $pId -like "*$term*") {
                        return $true
                    }
                }
            }
        } catch {}
    }
    return $false
}

function Test-WinPackageInstalled {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageId,

        [Parameter(Mandatory = $false)]
        [string]$DisplayName = ""
    )

    # 1. Fast Executable & Command Check (< 1ms)
    $knownBinaries = @{
        "Git.Git"                      = @("git.exe", "C:\Program Files\Git\cmd\git.exe")
        "7zip.7zip"                    = @("7z.exe", "C:\Program Files\7-Zip\7z.exe")
        "jqlang.jq"                    = @("jq.exe", "C:\ProgramData\chocolatey\bin\jq.exe")
        "BurntSushi.ripgrep.MSVC"      = @("rg.exe")
        "junegunn.fzf"                 = @("fzf.exe")
        "Microsoft.PowerShell"         = @("pwsh.exe", "C:\Program Files\PowerShell\7\pwsh.exe")
        "Microsoft.WindowsTerminal"    = @("wt.exe")
        "GitHub.cli"                   = @("gh.exe", "C:\Program Files\GitHub CLI\gh.exe")
        "EclipseAdoptium.Temurin.17.JDK"= @("java.exe", "C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot\bin\java.exe")
        "Schniz.fnm"                   = @("fnm.exe", "$env:APPDATA\fnm\fnm.exe", "$env:LOCALAPPDATA\fnm\fnm.exe")
        "astral-sh.uv"                 = @("uv.exe", "$HOME\.local\bin\uv.exe", "$HOME\.cargo\bin\uv.exe")
        "Python.Python.3.12"           = @("python.exe", "C:\Program Files\Python312\python.exe", "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe")
        "Docker.DockerDesktop"         = @("docker.exe", "C:\Program Files\Docker\Docker\Docker Desktop.exe")
        "Microsoft.VisualStudioCode"   = @("code.cmd", "code.exe", "C:\Program Files\Microsoft VS Code\Code.exe", "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe")
        "Notepad++.Notepad++"          = @("notepad++.exe", "C:\Program Files\Notepad++\notepad++.exe", "C:\Program Files (x86)\Notepad++\notepad++.exe")
        "Google.Chrome"                = @("chrome.exe", "C:\Program Files\Google\Chrome\Application\chrome.exe", "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe")
        "Brave.Brave"                  = @("brave.exe", "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\Application\brave.exe", "C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe")
        "Postman.Postman"              = @("postman.exe", "$env:LOCALAPPDATA\Postman\Postman.exe", "$env:LOCALAPPDATA\Programs\Postman\Postman.exe")
        "DBeaver.DBeaver"              = @("dbeaver.exe", "C:\Program Files\DBeaver\dbeaver.exe", "$env:LOCALAPPDATA\DBeaver\dbeaver.exe")
        "DBeaver.DBeaver.Community"    = @("dbeaver.exe", "C:\Program Files\DBeaver\dbeaver.exe", "$env:LOCALAPPDATA\DBeaver\dbeaver.exe")
        "Microsoft.PowerBI"            = @("PBIDesktop.exe", "C:\Program Files\Microsoft Power BI Desktop\bin\PBIDesktop.exe")
        "Atlassian.AtlassianCLI"       = @("acli.exe", "jira.exe")
        "Google.AntigravityCLI"        = @("agy.exe", "agy", "C:\Tools\antigravity-cli\agy.exe")
        "Google.AntigravityIDE"        = @("Antigravity IDE.exe", "$env:LOCALAPPDATA\Programs\Antigravity IDE\Antigravity IDE.exe", "C:\Program Files\Antigravity IDE\Antigravity IDE.exe")
        "Anysphere.Cursor"             = @("cursor.cmd", "cursor.exe", "$env:LOCALAPPDATA\Programs\cursor\Cursor.exe")
        "OpenAI.Codex"                 = @("codex.exe", "C:\Tools\codex\codex.exe")
    }

    if ($knownBinaries.ContainsKey($PackageId)) {
        foreach ($bin in $knownBinaries[$PackageId]) {
            if ($bin -like "*\*" -or $bin -like "*/*") {
                if (Test-Path $bin) { return $true }
            } else {
                if (Get-Command $bin -ErrorAction SilentlyContinue) { return $true }
            }
        }
    }

    # 2. Fast Registry Check (< 10ms)
    if (Test-RegistryInstalled -PackageId $PackageId -DisplayName $DisplayName) {
        return $true
    }

    # 3. Fast In-Memory WinGet Catalog Check
    $cache = Get-WinGetInstalledCache
    if ($cache -and ($cache -match [regex]::Escape($PackageId))) {
        return $true
    }

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

    if (-not $Force -and (Test-WinPackageInstalled -PackageId $PackageId -DisplayName $DisplayName)) {
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

    # Execute process and capture output for accurate error reporting
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "winget.exe"
    $psi.Arguments = ($wingetArgs -join " ")
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $process = [System.Diagnostics.Process]::Start($psi)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    # Invalidate installed cache on new install
    $global:BnBInstalledPackagesCache = $null

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
        $diagnosticMsg = ""
        if ($stdout -match "No package found") {
            $diagnosticMsg = "Package '$PackageId' was not found in configured winget sources."
        } elseif ($stdout -match "agreements") {
            $diagnosticMsg = "Package agreements were not accepted or requires interactive approval."
        } elseif ($stderr) {
            $diagnosticMsg = $stderr.Trim()
        } elseif ($stdout) {
            $diagnosticMsg = ($stdout -split "`r?`n" | Where-Object { $_ -match "error|fail|exit|not found" } | Select-Object -First 2) -join " "
        }

        Write-Log -Level ERROR -Message "Failed to install '$name'. Exit code: $($process.ExitCode). $diagnosticMsg"
        return $false
    }
}

Export-ModuleMember -Function Test-WinGet, Ensure-WinGetAvailable, Test-WinPackageInstalled, Install-WinPackage, Get-WinGetInstalledCache
