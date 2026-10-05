# scripts/03-Runtimes.ps1
# Installs and configures Java (JDK 17), Node.js (via fnm), Python (via uv/python), and Gradle
# Supports selective execution based on -SelectedTools parameter

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "$PSScriptRoot\..\config.json",

    [Parameter(Mandatory = $false)]
    [string[]]$SelectedTools = @()
)

# Flatten comma-separated values
$SelectedTools = @(
    foreach ($item in $SelectedTools) {
        $item -split '[\s,]+' | Where-Object { $_ -ne "" }
    }
)

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

if (-not $ConfigPath -or -not (Test-Path $ConfigPath)) {
    $cand = Join-Path -Path $scriptDir -ChildPath "..\config.json"
    if (Test-Path $cand) {
        $ConfigPath = (Resolve-Path $cand).Path
    } elseif (Test-Path (Join-Path -Path (Get-Location).Path -ChildPath "config.json")) {
        $ConfigPath = (Resolve-Path "config.json").Path
    }
}

$modulesPath = Join-Path -Path $scriptDir -ChildPath "..\modules"
if (-not (Get-Command "Write-Log" -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path -Path $modulesPath -ChildPath "Logging.psm1") -Global -DisableNameChecking
}
Import-Module (Join-Path -Path $modulesPath -ChildPath "Environment.psm1") -DisableNameChecking
Import-Module (Join-Path -Path $modulesPath -ChildPath "WinGetHelper.psm1") -DisableNameChecking
Import-Module (Join-Path -Path $modulesPath -ChildPath "DownloadManager.psm1") -DisableNameChecking
if (Test-Path (Join-Path -Path $modulesPath -ChildPath "UIProgress.psm1")) {
    Import-Module (Join-Path -Path $modulesPath -ChildPath "UIProgress.psm1") -DisableNameChecking
}

Write-LogHeader "Phase 3: Development Runtimes (Java, Node.js, Python, Gradle)"

# Load Configuration
$config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json

function Should-InstallTool {
    param([string]$toolId)
    if ($SelectedTools.Count -eq 0) { return $true }
    return ($SelectedTools -contains $toolId)
}

# 1. Java JDK 17 Installation & JAVA_HOME Configuration
if (Should-InstallTool "java") {
    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "java" -Status "Running" -DisplayName "Java JDK 17 (Temurin)" -Detail "Configuring Eclipse Adoptium JDK 17 LTS"
    }

    Write-Log -Level STEP -Message "Configuring Java Development Kit (JDK 17 LTS)..."

    $jdkBaseDir = "C:\Program Files\Eclipse Adoptium"
    $jdkPath = $null

    if ($env:JAVA_HOME -and (Test-Path "$env:JAVA_HOME\bin\java.exe")) {
        $jdkPath = $env:JAVA_HOME
        Write-Log -Level INFO -Message "Java JDK 17 already detected via JAVA_HOME at: $jdkPath. Skipping download and install."
    } elseif (Test-Path $jdkBaseDir) {
        $found = Get-ChildItem -Path $jdkBaseDir -Directory -Filter "jdk-17*" | Select-Object -First 1
        if ($found) { $jdkPath = $found.FullName }
    }

    if (-not $jdkPath) {
        $installedJdk = Install-WinPackage -PackageId "EclipseAdoptium.Temurin.17.JDK" -DisplayName "Eclipse Temurin JDK 17"
        if (Test-Path $jdkBaseDir) {
            $found = Get-ChildItem -Path $jdkBaseDir -Directory -Filter "jdk-17*" | Select-Object -First 1
            if ($found) { $jdkPath = $found.FullName }
        }
    }

    if (-not $jdkPath) {
        $foundMsft = Get-ChildItem -Path "C:\Program Files\Microsoft" -Directory -Filter "jdk-17*" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($foundMsft) { $jdkPath = $foundMsft.FullName }
    }

    if ($jdkPath) {
        Write-Log -Level SUCCESS -Message "Discovered JDK 17 installation at: $jdkPath"
        Set-EnvironmentVariableSafe -Name "JAVA_HOME" -Value $jdkPath -Target "Machine"
        Add-PathSafe -PathToAdd "$jdkPath\bin" -Target "Machine"
        if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
            Write-LiveToolStatus -ToolId "java" -Status "Success" -DisplayName "Java JDK 17 (Temurin)" -Detail "JAVA_HOME configured at $jdkPath"
        }
    } else {
        Write-Log -Level WARN -Message "Could not automatically resolve JDK path under standard directories."
        if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
            Write-LiveToolStatus -ToolId "java" -Status "Failed" -DisplayName "Java JDK 17 (Temurin)" -Detail "JDK 17 directory unresolved"
        }
    }
} else {
    Write-Log -Level INFO -Message "Java JDK 17 was not selected. Skipping."
}

# 2. Node.js & Fast Node Manager (fnm)
if (Should-InstallTool "node") {
    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "node" -Status "Running" -DisplayName "Node.js LTS & npm" -Detail "Configuring fnm and active LTS Node runtime"
    }

    Write-Log -Level STEP -Message "Configuring Node.js Runtime (via Fast Node Manager - fnm)..."

    $nodeCmd = Get-Command "node.exe" -ErrorAction SilentlyContinue
    $npmCmd = Get-Command "npm.cmd" -ErrorAction SilentlyContinue
    if (-not $npmCmd) { $npmCmd = Get-Command "npm" -ErrorAction SilentlyContinue }

    if ($nodeCmd -and $npmCmd) {
        $nodeV = & $nodeCmd -v 2>$null
        $npmV = & $npmCmd -v 2>$null
        Write-Log -Level SUCCESS -Message "Node.js ($nodeV) and npm ($npmV) are already installed and found on PATH. Skipping download and install."
        if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
            Write-LiveToolStatus -ToolId "node" -Status "Success" -DisplayName "Node.js LTS & npm" -Detail "Node $nodeV, npm $npmV active"
        }
    } else {
        Install-WinPackage -PackageId "Schniz.fnm" -DisplayName "Fast Node Manager (fnm)"

        # Add fnm to PATH
        $fnmDir = Join-Path -Path ([Environment]::GetFolderPath("LocalApplicationData")) -ChildPath "Programs\fnm"
        if (Test-Path $fnmDir) {
            Add-PathSafe -PathToAdd $fnmDir -Target "User"
            Add-PathSafe -PathToAdd $fnmDir -Target "Machine"
        }
        Refresh-SessionEnvironment

        $fnmCmd = Get-Command "fnm.exe" -ErrorAction SilentlyContinue
        if (-not $fnmCmd -and (Test-Path "$fnmDir\fnm.exe")) {
            $fnmCmd = "$fnmDir\fnm.exe"
        }

        if ($fnmCmd) {
            Write-Log -Level INFO -Message "fnm detected. Installing and selecting latest LTS Node.js..."
            try {
                & $fnmCmd install --lts
                & $fnmCmd default lts
                & $fnmCmd use lts

                # CRITICAL FIX: Add fnm default alias directory directly to Machine & User PATH
                # This ensures node, npm, and npx are permanently and universally available in all shells & subprocesses
                $fnmDefaultAlias = Join-Path -Path $env:APPDATA -ChildPath "fnm\aliases\default"
                if (Test-Path $fnmDefaultAlias) {
                    Add-PathSafe -PathToAdd $fnmDefaultAlias -Target "Machine"
                    Add-PathSafe -PathToAdd $fnmDefaultAlias -Target "User"
                    Write-Log -Level SUCCESS -Message "Added fnm default Node alias to PATH: $fnmDefaultAlias"
                }

                # Prepare npm global packages directory
                $npmGlobal = Join-Path -Path $env:USERPROFILE -ChildPath ".npm-global"
                if (-not (Test-Path $npmGlobal)) {
                    New-Item -ItemType Directory -Path $npmGlobal -Force | Out-Null
                }
                Add-PathSafe -PathToAdd "$npmGlobal\bin" -Target "User"
                Add-PathSafe -PathToAdd $npmGlobal -Target "User"

                Refresh-SessionEnvironment

                $nodeV = & node -v 2>$null
                $npmV = & npm -v 2>$null
                Write-Log -Level SUCCESS -Message "Node.js $nodeV and npm $npmV configured and operational."

                if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
                    Write-LiveToolStatus -ToolId "node" -Status "Success" -DisplayName "Node.js LTS & npm" -Detail "Node $nodeV, npm $npmV ready on PATH"
                }
            } catch {
                Write-Log -Level WARN -Message "fnm setup encountered an issue: $_"
            }
        } else {
            Write-Log -Level WARN -Message "fnm.exe not yet found in current session."
        }
    }
} else {
    Write-Log -Level INFO -Message "Node.js was not selected. Skipping."
}

# 3. Python and uv Setup
if (Should-InstallTool "python") {
    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "python" -Status "Running" -DisplayName "Python 3.12 & uv" -Detail "Installing Python runtime and uv package manager"
    }

    Write-Log -Level STEP -Message "Configuring Python 3 & uv Package Manager..."

    $pyCmd = Get-Command "python.exe" -ErrorAction SilentlyContinue
    $uvCmd = Get-Command "uv.exe" -ErrorAction SilentlyContinue

    if ($pyCmd -and $uvCmd) {
        $pyV = & $pyCmd --version 2>$null
        Write-Log -Level SUCCESS -Message "Python ($pyV) and uv toolchain are already installed on PATH. Skipping download and install."
        if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
            Write-LiveToolStatus -ToolId "python" -Status "Success" -DisplayName "Python 3.12 & uv" -Detail "Python ($pyV) and uv active"
        }
    } else {
        Install-WinPackage -PackageId "astral-sh.uv" -DisplayName "uv Python Toolchain"
        Install-WinPackage -PackageId "Python.Python.3.12" -DisplayName "Python 3.12"

        # Detect Python installation
        $pySearchPaths = @(
            "C:\Program Files\Python312",
            "$env:LOCALAPPDATA\Programs\Python\Python312"
        )
        foreach ($pyPath in $pySearchPaths) {
            if (Test-Path $pyPath) {
                Add-PathSafe -PathToAdd $pyPath -Target "Machine"
                Add-PathSafe -PathToAdd "$pyPath\Scripts" -Target "Machine"
                break
            }
        }

        # Configure pip defaults
        Set-EnvironmentVariableSafe -Name "PIP_DISABLE_PIP_VERSION_CHECK" -Value "1" -Target "Machine"
        Write-Log -Level SUCCESS -Message "Python 3.12 and uv configured."

        if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
            Write-LiveToolStatus -ToolId "python" -Status "Success" -DisplayName "Python 3.12 & uv" -Detail "Python and uv toolchain active"
        }
    }
} else {
    Write-Log -Level INFO -Message "Python was not selected. Skipping."
}

# 4. Gradle Setup (CRITICAL FIX: Direct official binary distribution with parallel pre-download & smart cache skip)
if (Should-InstallTool "gradle") {
    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "gradle" -Status "Running" -DisplayName "Gradle Build Tool" -Detail "Deploying Gradle build tool distribution"
    }

    Write-Log -Level STEP -Message "Configuring Gradle Build Tool..."

    $toolsDir = if ($config.settings.toolsDirectory) { $config.settings.toolsDirectory } else { "C:\Tools" }
    $gradleBaseDir = Join-Path -Path $toolsDir -ChildPath "gradle"
    $gradleHome = $null

    # Check if already installed
    if (Test-Path $gradleBaseDir) {
        $sub = Get-ChildItem -Path $gradleBaseDir -Directory -Filter "gradle-*" | Select-Object -First 1
        if ($sub -and (Test-Path "$($sub.FullName)\bin\gradle.bat")) {
            $gradleHome = $sub.FullName
        } elseif (Test-Path "$gradleBaseDir\bin\gradle.bat") {
            $gradleHome = $gradleBaseDir
        }
    }

    if (-not $gradleHome) {
        $cmdGradle = Get-Command "gradle.bat" -ErrorAction SilentlyContinue
        if ($cmdGradle) {
            $gradleHome = Split-Path -Path (Split-Path -Path $cmdGradle.Source -Parent) -Parent
        }
    }

    if ($gradleHome) {
        Write-Log -Level SUCCESS -Message "Gradle is already installed and found at: $gradleHome. Skipping download and extraction."
    } else {
        # Download and extract official Gradle binary distribution
        $gradleZipUrl = "https://services.gradle.org/distributions/gradle-8.7-bin.zip"
        $cacheDir = Get-DownloadCacheDirectory
        $targetZip = Join-Path -Path $cacheDir -ChildPath "gradle-8.7-bin.zip"

        try {
            $downloadedFile = Get-CachedOrDownloadFile -ToolId "gradle" -Url $gradleZipUrl -DestinationPath $targetZip -DisplayName "Gradle 8.7 Distribution" -AlternativePatterns @("*gradle*8.7*.zip")

            if (-not (Test-Path $gradleBaseDir)) {
                New-Item -ItemType Directory -Path $gradleBaseDir -Force | Out-Null
            }

            Write-Log -Level INFO -Message "Extracting Gradle distribution archive to $gradleBaseDir..."

            # Use 7-Zip for fast extraction if available
            $sevenZip = "C:\Program Files\7-Zip\7z.exe"
            if (Test-Path $sevenZip) {
                & $sevenZip x -y -o"$gradleBaseDir" "$downloadedFile" | Out-Null
            } else {
                Expand-Archive -Path $downloadedFile -DestinationPath $gradleBaseDir -Force
            }

            # Locate extracted gradle-8.7 folder
            $sub = Get-ChildItem -Path $gradleBaseDir -Directory -Filter "gradle-*" | Select-Object -First 1
            if ($sub -and (Test-Path "$($sub.FullName)\bin\gradle.bat")) {
                $gradleHome = $sub.FullName
            } elseif (Test-Path "$gradleBaseDir\bin\gradle.bat") {
                $gradleHome = $gradleBaseDir
            }
        } catch {
            Write-Log -Level ERROR -Message "Failed to install Gradle from official distribution: $_"
        }
    }

    if ($gradleHome) {
        Write-Log -Level SUCCESS -Message "Resolved Gradle at: $gradleHome"
        Set-EnvironmentVariableSafe -Name "GRADLE_HOME" -Value $gradleHome -Target "Machine"
        Add-PathSafe -PathToAdd "$gradleHome\bin" -Target "Machine"
        Refresh-SessionEnvironment

        $gradleVersionStr = & "$gradleHome\bin\gradle.bat" -v 2>$null | Where-Object { $_ -match "^Gradle\s+\d+" } | Select-Object -First 1
        Write-Log -Level SUCCESS -Message "Gradle is active: $gradleVersionStr"

        if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
            Write-LiveToolStatus -ToolId "gradle" -Status "Success" -DisplayName "Gradle Build Tool" -Detail "$gradleVersionStr configured ($gradleHome)"
        }
    } else {
        Write-Log -Level WARN -Message "Gradle could not be configured."
        if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
            Write-LiveToolStatus -ToolId "gradle" -Status "Failed" -DisplayName "Gradle Build Tool" -Detail "Installation failed"
        }
    }
} else {
    Write-Log -Level INFO -Message "Gradle was not selected. Skipping."
}

Refresh-SessionEnvironment
Write-Log -Level SUCCESS -Message "Development runtimes phase completed."
