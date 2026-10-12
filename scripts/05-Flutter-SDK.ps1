# scripts/05-Flutter-SDK.ps1
# Automates Flutter SDK installation, PATH configuration, Android linking, precaching, and flutter doctor verification
# Optimized with live progress streaming, 7-Zip acceleration, and non-blocking precache monitoring

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "",

    [Parameter(Mandatory = $false)]
    [switch]$SkipPrecache
)

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

if (-not $ConfigPath -or -not (Test-Path $ConfigPath)) {
    $candidates = @(
        (Join-Path -Path $scriptDir -ChildPath "..\config\config.json"),
        (Join-Path -Path $scriptDir -ChildPath "..\config.json"),
        (Join-Path -Path (Get-Location).Path -ChildPath "config\config.json"),
        (Join-Path -Path (Get-Location).Path -ChildPath "config.json")
    )
    foreach ($cand in $candidates) {
        if (Test-Path $cand) {
            $ConfigPath = (Resolve-Path $cand).Path
            break
        }
    }
}

$modulesPath = Join-Path -Path $scriptDir -ChildPath "..\modules"
if (-not (Get-Command "Write-Log" -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path -Path $modulesPath -ChildPath "Logging.psm1") -Global -DisableNameChecking
}
Import-Module (Join-Path -Path $modulesPath -ChildPath "Environment.psm1") -DisableNameChecking
Import-Module (Join-Path -Path $modulesPath -ChildPath "DownloadManager.psm1") -DisableNameChecking
if (Test-Path (Join-Path -Path $modulesPath -ChildPath "UIProgress.psm1")) {
    Import-Module (Join-Path -Path $modulesPath -ChildPath "UIProgress.psm1") -DisableNameChecking
}

Write-LogHeader "Mobile SDK: Flutter Multiplatform Framework"

if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
    Write-LiveToolStatus -ToolId "flutter" -Status "Running" -DisplayName "Flutter SDK" -Detail "Configuring Flutter engine and SDK tooling"
}

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
    $gitCmd = Get-Command "git.exe" -ErrorAction SilentlyContinue
    if (-not $gitCmd -and (Test-Path "C:\Program Files\Git\cmd\git.exe")) {
        $gitCmd = "C:\Program Files\Git\cmd\git.exe"
    }

    # Method A: Git Clone with Live Progress Streaming
    if ($gitCmd) {
        Write-Log -Level INFO -Message "Cloning Flutter stable branch via Git with live progress..."
        try {
            $branch = if ($config.flutterSdk.gitBranch) { $config.flutterSdk.gitBranch } else { "stable" }
            $repoUrl = if ($config.flutterSdk.gitRepoUrl) { $config.flutterSdk.gitRepoUrl } else { "https://github.com/flutter/flutter.git" }

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $gitCmd
            $psi.Arguments = "clone --depth 1 -b $branch --progress $repoUrl `"$flutterDir`""
            $psi.UseShellExecute = $false
            $psi.RedirectStandardError = $true
            $psi.CreateNoWindow = $true

            $proc = [System.Diagnostics.Process]::Start($psi)
            while (-not $proc.StandardError.EndOfStream) {
                $errLine = $proc.StandardError.ReadLine()
                if ($errLine -match "Receiving objects:\s+(\d+)%") {
                    Write-Host -NoNewline "`r  [CLONING FLUTTER] $($Matches[1])% received...   "
                } elseif ($errLine -match "Resolving deltas:\s+(\d+)%") {
                    Write-Host -NoNewline "`r  [RESOLVING DELTAS] $($Matches[1])% completed...   "
                }
            }
            $proc.WaitForExit()
            Write-Host ""

            if (Test-Path $flutterBat) {
                Write-Log -Level SUCCESS -Message "Flutter successfully cloned from GitHub."
                $installedViaGit = $true
            }
        } catch {
            Write-Log -Level WARN -Message "Git clone failed: $_. Attempting archive fallback..."
        }
    }

    # Method B: Official Archive Download Fallback with 7-Zip & Smart Cache Search
    if (-not $installedViaGit) {
        $cacheDir = Get-DownloadCacheDirectory
        $targetZip = Join-Path -Path $cacheDir -ChildPath "flutter-sdk.zip"

        # Check if pre-downloaded archive already exists in cache or Downloads
        $existingZip = Find-PreDownloadedArchive -FileName "flutter-sdk.zip" -AlternativePatterns @("*flutter*windows*.zip") -MinSizeBytes 50000000

        if ($existingZip) {
            Write-Log -Level SUCCESS -Message "Found existing Flutter archive at '$existingZip'. Skipping download!"
            $downloadedFile = $existingZip
        } else {
            Write-Log -Level INFO -Message "Querying official Flutter releases manifest..."
            $releasesUrl = "https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json"

            try {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                $manifest = Invoke-RestMethod -Uri $releasesUrl -UseBasicParsing
                $stableHash = $manifest.current_release.stable
                $relEntry = $manifest.releases | Where-Object { $_.hash -eq $stableHash } | Select-Object -First 1

                if (-not $relEntry) {
                    $relEntry = $manifest.releases | Where-Object { $_.channel -eq "stable" } | Select-Object -First 1
                }

                $downloadUrl = "https://storage.googleapis.com/flutter_infra_release/releases/$($relEntry.archive)"
                $downloadedFile = Get-CachedOrDownloadFile -ToolId "flutter" -Url $downloadUrl -DestinationPath $targetZip -DisplayName "Flutter SDK ($($relEntry.version))" -AlternativePatterns @("*flutter*windows*.zip")
            } catch {
                Write-Log -Level ERROR -Message "Failed to acquire Flutter archive: $_"
                throw $_
            }
        }

        try {
            Write-Log -Level INFO -Message "Extracting Flutter SDK to $parentDir..."
            $sevenZip = "C:\Program Files\7-Zip\7z.exe"
            if (Test-Path $sevenZip) {
                & $sevenZip x -y -o"$parentDir" "$downloadedFile" | Out-Null
            } else {
                Expand-Archive -Path $downloadedFile -DestinationPath $parentDir -Force
            }

            Write-Log -Level SUCCESS -Message "Flutter archive extracted successfully."
        } catch {
            Write-Log -Level ERROR -Message "Failed to extract Flutter archive: $_"
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

    # Disable analytics immediately
    try {
        & "$flutterBat" config --no-analytics | Out-Null
        Write-Log -Level SUCCESS -Message "Disabled Flutter analytics."
    } catch {}

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
        } catch {}
    }

    # Link Java JDK if present
    $javaHome = $env:JAVA_HOME
    if ($javaHome -and (Test-Path $javaHome)) {
        Write-Log -Level INFO -Message "Linking Java JDK ($javaHome) to Flutter..."
        try {
            & "$flutterBat" config --jdk-dir "$javaHome" | Out-Null
            Write-Log -Level SUCCESS -Message "Linked Java JDK with Flutter."
        } catch {}
    }

    # Precache engine and platform artifacts (With Live Streaming, No Out-Null Blocking!)
    if (-not $SkipPrecache) {
        $engineArtifactsDir = Join-Path -Path $flutterDir -ChildPath "bin\cache\artifacts\engine"
        $isPrecached = (Test-Path $engineArtifactsDir) -and ((Get-ChildItem -Path $engineArtifactsDir -Recurse -File -ErrorAction SilentlyContinue).Count -gt 5)

        if ($isPrecached) {
            Write-Log -Level SUCCESS -Message "Flutter engine cache artifacts already found on disk. Skipping precache download."
        } else {
            Write-Log -Level INFO -Message "Pre-caching Flutter engine artifacts (Windows & Web) with live updates..."
            try {
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = "cmd.exe"
                $psi.Arguments = "/c `"$flutterBat`" precache --windows --web --no-ios"
                $psi.UseShellExecute = $false
                $psi.RedirectStandardOutput = $true
                $psi.CreateNoWindow = $true

                $proc = [System.Diagnostics.Process]::Start($psi)
                while (-not $proc.StandardOutput.EndOfStream) {
                    $line = $proc.StandardOutput.ReadLine()
                    if ($line) {
                        Write-Host "  [FLUTTER] $line" -ForegroundColor DarkCyan
                    }
                }
                $proc.WaitForExit()
                Write-Log -Level SUCCESS -Message "Flutter precache completed."
            } catch {
                Write-Log -Level WARN -Message "Flutter precache warning: $_"
            }
        }
    }

    # Run doctor summary
    Write-Log -Level INFO -Message "Executing flutter doctor summary..."
    try {
        $doc = & "$flutterBat" doctor 2>&1
        $summary = $doc | Select-Object -First 5
        Write-Log -Level INFO -Message ($summary -join "`n")
    } catch {}

    $flutterVer = & "$flutterBat" --version 2>$null | Select-Object -First 1
    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "flutter" -Status "Success" -DisplayName "Flutter SDK" -Detail "$flutterVer ($flutterDir)"
    }
} else {
    Write-Log -Level ERROR -Message "flutter.bat was not found at expected path: $flutterBat"
    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "flutter" -Status "Failed" -DisplayName "Flutter SDK" -Detail "flutter.bat not found"
    }
}

Refresh-SessionEnvironment
Write-Log -Level SUCCESS -Message "Flutter SDK automation phase completed."
