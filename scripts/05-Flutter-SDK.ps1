# scripts/05-Flutter-SDK.ps1
# Automates Flutter SDK installation, PATH configuration, Android linking, and flutter doctor verification

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "$PSScriptRoot\..\config.json",

    [Parameter(Mandatory = $false)]
    [switch]$SkipPrecache
)

$modulesPath = Join-Path -Path $PSScriptRoot -ChildPath "..\modules"
Import-Module (Join-Path -Path $modulesPath -ChildPath "Logging.psm1") -Force
Import-Module (Join-Path -Path $modulesPath -ChildPath "Environment.psm1") -Force

Write-LogHeader "Phase 5: Flutter Multiplatform SDK Automation"

# Load Configuration
$config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json
$flutterDir = if ($config.flutterSdk -and $config.flutterSdk.installDirectory) {
    $config.flutterSdk.installDirectory
} else {
    "C:\Tools\flutter"
}

$flutterBin = Join-Path -Path $flutterDir -ChildPath "bin"
$flutterBat = Join-Path -Path $flutterBin -ChildPath "flutter.bat"

# 1. Ensure Target Parent Directory Exists
$parentDir = Split-Path -Path $flutterDir -Parent
if (-not (Test-Path $parentDir)) {
    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
}

# 2. Check if Flutter is already installed
$isInstalled = $false
if (Test-Path $flutterBat) {
    Write-Log -Level INFO -Message "Flutter SDK already detected at: $flutterDir"
    $isInstalled = $true
} else {
    $cmdFlutter = Get-Command "flutter.bat" -ErrorAction SilentlyContinue
    if (-not $cmdFlutter) {
        $cmdFlutter = Get-Command "flutter" -ErrorAction SilentlyContinue
    }
    if ($cmdFlutter) {
        Write-Log -Level INFO -Message "Flutter found on PATH at: $($cmdFlutter.Source)"
        $flutterDir = Split-Path -Path (Split-Path -Path $cmdFlutter.Source -Parent) -Parent
        $flutterBin = Join-Path -Path $flutterDir -ChildPath "bin"
        $flutterBat = Join-Path -Path $flutterBin -ChildPath "flutter.bat"
        $isInstalled = $true
    }
}

if (-not $isInstalled) {
    Write-Log -Level STEP -Message "Installing Flutter SDK to $flutterDir..."

    $installedViaGit = $false
    # Method A: Git Clone (Fastest, cleanest, and officially recommended)
    $gitCmd = Get-Command "git.exe" -ErrorAction SilentlyContinue
    if (-not $gitCmd -and (Test-Path "C:\Program Files\Git\cmd\git.exe")) {
        $gitCmd = "C:\Program Files\Git\cmd\git.exe"
    }

    if ($gitCmd) {
        Write-Log -Level INFO -Message "Cloning Flutter stable branch via Git..."
        try {
            $branch = if ($config.flutterSdk.gitBranch) { $config.flutterSdk.gitBranch } else { "stable" }
            $repoUrl = if ($config.flutterSdk.gitRepoUrl) { $config.flutterSdk.gitRepoUrl } else { "https://github.com/flutter/flutter.git" }

            & $gitCmd clone --depth 1 -b $branch $repoUrl $flutterDir
            if (Test-Path $flutterBat) {
                Write-Log -Level SUCCESS -Message "Flutter successfully cloned from GitHub."
                $installedViaGit = $true
            }
        } catch {
            Write-Log -Level WARN -Message "Git clone failed: $_. Attempting archive download fallback..."
        }
    }

    # Method B: Official Archive Download Fallback
    if (-not $installedViaGit) {
        Write-Log -Level INFO -Message "Querying official Flutter releases manifest..."
        $releasesUrl = "https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json"
        $tempZip = Join-Path -Path $env:TEMP -ChildPath "flutter-sdk.zip"

        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $manifest = Invoke-RestMethod -Uri $releasesUrl -UseBasicParsing
            $stableHash = $manifest.current_release.stable
            $relEntry = $manifest.releases | Where-Object { $_.hash -eq $stableHash } | Select-Object -First 1

            if (-not $relEntry) {
                $relEntry = $manifest.releases | Where-Object { $_.channel -eq "stable" } | Select-Object -First 1
            }

            $downloadUrl = "https://storage.googleapis.com/flutter_infra_release/releases/$($relEntry.archive)"
            Write-Log -Level INFO -Message "Downloading Flutter $($relEntry.version) from: $downloadUrl"

            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -UseBasicParsing

            Write-Log -Level INFO -Message "Extracting Flutter SDK to $parentDir..."
            Expand-Archive -Path $tempZip -DestinationPath $parentDir -Force

            Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue
            Write-Log -Level SUCCESS -Message "Flutter archive extracted successfully."
        } catch {
            Write-Log -Level ERROR -Message "Failed to download/extract Flutter archive: $_"
            throw $_
        }
    }
}

# 3. Configure FLUTTER_HOME & Machine PATH
Write-Log -Level STEP -Message "Configuring FLUTTER_HOME and PATH..."
Set-EnvironmentVariableSafe -Name "FLUTTER_HOME" -Value $flutterDir -Target "Machine"
Add-PathSafe -PathToAdd $flutterBin -Target "Machine"
Refresh-SessionEnvironment

# 4. Configure Flutter Preferences and Integrations
if (Test-Path $flutterBat) {
    Write-Log -Level STEP -Message "Configuring Flutter settings and tool integration..."

    # Disable Google analytics/telemetry for CI and speed
    try {
        & "$flutterBat" config --no-analytics | Out-Null
        Write-Log -Level SUCCESS -Message "Disabled Flutter analytics."
    } catch {
        Write-Log -Level WARN -Message "Could not configure flutter analytics: $_"
    }

    # Link Android SDK if present
    $androidSdk = $env:ANDROID_HOME
    if (-not $androidSdk -and (Test-Path "C:\Android\android-sdk")) {
        $androidSdk = "C:\Android\android-sdk"
    }

    if ($androidSdk -and (Test-Path $androidSdk)) {
        Write-Log -Level INFO -Message "Linking Android SDK ($androidSdk) to Flutter..."
        try {
            & "$flutterBat" config --android-sdk "$androidSdk" | Out-Null
            Write-Log -Level SUCCESS -Message "Linked Android SDK with Flutter."
        } catch {
            Write-Log -Level WARN -Message "Failed linking Android SDK to Flutter: $_"
        }
    }

    # Link Java JDK if present
    $javaHome = $env:JAVA_HOME
    if ($javaHome -and (Test-Path $javaHome)) {
        Write-Log -Level INFO -Message "Linking Java JDK ($javaHome) to Flutter..."
        try {
            & "$flutterBat" config --jdk-dir "$javaHome" | Out-Null
            Write-Log -Level SUCCESS -Message "Linked Java JDK with Flutter."
        } catch {
            Write-Log -Level WARN -Message "Failed linking Java JDK to Flutter: $_"
        }
    }

    # Precache engine and platform artifacts
    if (-not $SkipPrecache) {
        Write-Log -Level INFO -Message "Pre-caching Flutter engine artifacts (Windows & Web)..."
        try {
            & "$flutterBat" precache --windows --web --no-ios | Out-Null
            Write-Log -Level SUCCESS -Message "Flutter precache completed."
        } catch {
            Write-Log -Level WARN -Message "Flutter precache warning: $_"
        }
    }

    # Run doctor to verify health
    Write-Log -Level INFO -Message "Executing flutter doctor summary..."
    try {
        $doc = & "$flutterBat" doctor -v 2>&1
        $summary = $doc | Select-Object -First 6
        Write-Log -Level INFO -Message ($summary -join "`n")
    } catch {
        Write-Log -Level WARN -Message "flutter doctor encountered an issue: $_"
    }
} else {
    Write-Log -Level ERROR -Message "flutter.bat was not found at expected path: $flutterBat"
}

Refresh-SessionEnvironment
Write-Log -Level SUCCESS -Message "Flutter SDK automation phase completed."
