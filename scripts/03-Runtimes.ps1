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

$modulesPath = Join-Path -Path $PSScriptRoot -ChildPath "..\modules"
if (-not (Get-Command "Write-Log" -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path -Path $modulesPath -ChildPath "Logging.psm1") -Global -DisableNameChecking
}
Import-Module (Join-Path -Path $modulesPath -ChildPath "Environment.psm1") -DisableNameChecking
Import-Module (Join-Path -Path $modulesPath -ChildPath "WinGetHelper.psm1") -DisableNameChecking

Write-LogHeader "Phase 3: Development Runtimes (Java, Node.js, Python, Gradle)"

# Load Configuration
$config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json

# Helper to check if a component is selected
function Should-InstallTool {
    param([string]$toolId)
    if ($SelectedTools.Count -eq 0) { return $true }
    return ($SelectedTools -contains $toolId)
}

# 1. Java JDK 17 Installation & JAVA_HOME Configuration
if (Should-InstallTool "java") {
    Write-Log -Level STEP -Message "Configuring Java Development Kit (JDK 17 LTS)..."
    $installedJdk = Install-WinPackage -PackageId "EclipseAdoptium.Temurin.17.JDK" -DisplayName "Eclipse Temurin JDK 17"

    # Auto-detect JDK directory
    $jdkBaseDir = "C:\Program Files\Eclipse Adoptium"
    $jdkPath = $null
    if (Test-Path $jdkBaseDir) {
        $found = Get-ChildItem -Path $jdkBaseDir -Directory -Filter "jdk-17*" | Select-Object -First 1
        if ($found) {
            $jdkPath = $found.FullName
        }
    }

    if (-not $jdkPath) {
        # Check alternate Microsoft OpenJDK path
        $foundMsft = Get-ChildItem -Path "C:\Program Files\Microsoft" -Directory -Filter "jdk-17*" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($foundMsft) {
            $jdkPath = $foundMsft.FullName
        }
    }

    if ($jdkPath) {
        Write-Log -Level SUCCESS -Message "Discovered JDK 17 installation at: $jdkPath"
        Set-EnvironmentVariableSafe -Name "JAVA_HOME" -Value $jdkPath -Target "Machine"
        Add-PathSafe -PathToAdd "$jdkPath\bin" -Target "Machine"
    } else {
        Write-Log -Level WARN -Message "Could not automatically resolve JDK path under standard directories. Please check winget installation status."
    }
} else {
    Write-Log -Level INFO -Message "Java JDK 17 was not selected. Skipping."
}

# 2. Node.js & Fast Node Manager (fnm)
if (Should-InstallTool "node") {
    Write-Log -Level STEP -Message "Configuring Node.js Runtime (via Fast Node Manager - fnm)..."
    Install-WinPackage -PackageId "Schniz.fnm" -DisplayName "Fast Node Manager (fnm)"

    # Add fnm to PATH if needed
    $fnmDir = Join-Path -Path ([Environment]::GetFolderPath("LocalApplicationData")) -ChildPath "Programs\fnm"
    if (Test-Path $fnmDir) {
        Add-PathSafe -PathToAdd $fnmDir -Target "User"
    }
    Refresh-SessionEnvironment

    if (Get-Command "fnm.exe" -ErrorAction SilentlyContinue) {
        Write-Log -Level INFO -Message "fnm detected. Installing and selecting latest LTS Node.js..."
        try {
            & fnm install --lts
            & fnm default lts
            & fnm use lts

            # Prepare npm global packages directory
            $npmGlobal = Join-Path -Path $env:USERPROFILE -ChildPath ".npm-global"
            if (-not (Test-Path $npmGlobal)) {
                New-Item -ItemType Directory -Path $npmGlobal -Force | Out-Null
            }
            Add-PathSafe -PathToAdd "$npmGlobal\bin" -Target "User"
            Add-PathSafe -PathToAdd $npmGlobal -Target "User"

            Write-Log -Level SUCCESS -Message "Node.js LTS configured with fnm."
        } catch {
            Write-Log -Level WARN -Message "fnm setup encountered an issue: $_"
        }
    } else {
        Write-Log -Level WARN -Message "fnm.exe not yet found in current session. WinGet may require terminal reload."
    }
} else {
    Write-Log -Level INFO -Message "Node.js was not selected. Skipping."
}

# 3. Python and uv Setup
if (Should-InstallTool "python") {
    Write-Log -Level STEP -Message "Configuring Python 3 & uv Package Manager..."
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
} else {
    Write-Log -Level INFO -Message "Python was not selected. Skipping."
}

# 4. Gradle Setup
if (Should-InstallTool "gradle") {
    Write-Log -Level STEP -Message "Configuring Gradle Build Tool..."
    Install-WinPackage -PackageId "Gradle.Gradle" -DisplayName "Gradle"

    $gradleCandidates = @(
        "C:\Gradle",
        "C:\Program Files\Gradle",
        "C:\Tools\gradle"
    )

    $gradleFound = $null
    foreach ($cand in $gradleCandidates) {
        if (Test-Path $cand) {
            $binDir = Join-Path -Path $cand -ChildPath "bin"
            if (Test-Path $binDir) {
                $gradleFound = $cand
                break
            }
            # Check subfolders (gradle-8.x.x)
            $sub = Get-ChildItem -Path $cand -Directory -Filter "gradle-*" | Select-Object -First 1
            if ($sub -and (Test-Path "$($sub.FullName)\bin")) {
                $gradleFound = $sub.FullName
                break
            }
        }
    }

    if (-not $gradleFound) {
        $wingetGradle = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Directory -Filter "*Gradle*" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($wingetGradle) {
            $gradleFound = $wingetGradle.FullName
        }
    }

    if ($gradleFound) {
        Write-Log -Level SUCCESS -Message "Resolved Gradle at: $gradleFound"
        Set-EnvironmentVariableSafe -Name "GRADLE_HOME" -Value $gradleFound -Target "Machine"
        Add-PathSafe -PathToAdd "$gradleFound\bin" -Target "Machine"
    }
} else {
    Write-Log -Level INFO -Message "Gradle was not selected. Skipping."
}

Refresh-SessionEnvironment
Write-Log -Level SUCCESS -Message "Development runtimes phase completed."
