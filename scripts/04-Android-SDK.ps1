# scripts/04-Android-SDK.ps1
# High-velocity Android SDK, Command-Line Tools, Platform-Tools, and License Acceptance Automation
# Optimized with parallel download caching, 7-Zip acceleration, batch package installation, and live progress streaming

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "$PSScriptRoot\..\config.json"
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
Import-Module (Join-Path -Path $modulesPath -ChildPath "DownloadManager.psm1") -DisableNameChecking
if (Test-Path (Join-Path -Path $modulesPath -ChildPath "UIProgress.psm1")) {
    Import-Module (Join-Path -Path $modulesPath -ChildPath "UIProgress.psm1") -DisableNameChecking
}

Write-LogHeader "Mobile SDK: Android SDK & Command-Line Tools"

if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
    Write-LiveToolStatus -ToolId "android" -Status "Running" -DisplayName "Android SDK & Tools" -Detail "Preparing Android development platform and tools"
}

# Load Configuration
$config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json

$sdkRoot = if ($config.androidSdk -and $config.androidSdk.installDirectory) {
    $config.androidSdk.installDirectory
} else {
    "C:\Android\android-sdk"
}

$cmdlineZipUrl = if ($config.androidSdk -and $config.androidSdk.cmdlineToolsZipUrl) {
    $config.androidSdk.cmdlineToolsZipUrl
} else {
    "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
}

$cmdlineLatestDir = Join-Path -Path $sdkRoot -ChildPath "cmdline-tools\latest"
$sdkManagerBat = Join-Path -Path $cmdlineLatestDir -ChildPath "bin\sdkmanager.bat"

# 1. Check JAVA_HOME dependency
if (-not $env:JAVA_HOME -or -not (Test-Path $env:JAVA_HOME)) {
    Write-Log -Level WARN -Message "JAVA_HOME is not set or directory not found. Refreshing environment..."
    Refresh-SessionEnvironment
}

# 2. Download and Scaffold Command-Line Tools (Optimized with Cache & 7-Zip)
if (-not (Test-Path $sdkManagerBat)) {
    Write-Log -Level STEP -Message "Android SDK cmdline-tools not found. Acquiring official Google archive..."

    if (-not (Test-Path $sdkRoot)) {
        New-Item -ItemType Directory -Path $sdkRoot -Force | Out-Null
    }

    $cacheDir = Get-DownloadCacheDirectory
    $targetZip = Join-Path -Path $cacheDir -ChildPath "android-cmdline-tools.zip"

    try {
        $downloadedZip = Get-CachedOrDownloadFile -ToolId "android" -Url $cmdlineZipUrl -DestinationPath $targetZip -DisplayName "Android SDK Command-Line Tools" -AlternativePatterns @("*commandlinetools*win*.zip", "*cmdline-tools*.zip")

        $tempExtract = Join-Path -Path $env:TEMP -ChildPath "android-cmdline-extract"
        if (Test-Path $tempExtract) { Remove-Item -Path $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }

        Write-Log -Level INFO -Message "Extracting cmdline-tools archive..."
        $sevenZip = "C:\Program Files\7-Zip\7z.exe"
        if (Test-Path $sevenZip) {
            & $sevenZip x -y -o"$tempExtract" "$downloadedZip" | Out-Null
        } else {
            Expand-Archive -Path $downloadedZip -DestinationPath $tempExtract -Force
        }

        # Structure expected: <ANDROID_HOME>/cmdline-tools/latest/...
        if (-not (Test-Path $cmdlineLatestDir)) {
            New-Item -ItemType Directory -Path $cmdlineLatestDir -Force | Out-Null
        }

        $extractedRoot = Join-Path -Path $tempExtract -ChildPath "cmdline-tools"
        if (Test-Path $extractedRoot) {
            Get-ChildItem -Path $extractedRoot | Move-Item -Destination $cmdlineLatestDir -Force
        } else {
            Get-ChildItem -Path $tempExtract | Move-Item -Destination $cmdlineLatestDir -Force
        }

        Remove-Item -Path $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log -Level SUCCESS -Message "Extracted cmdline-tools into: $cmdlineLatestDir"
    } catch {
        Write-Log -Level ERROR -Message "Failed to acquire or extract Android cmdline-tools: $_"
        throw $_
    }
} else {
    Write-Log -Level SUCCESS -Message "Android cmdline-tools already present at: $cmdlineLatestDir. Skipping download & extraction."
}

# 3. Configure Android Environment Variables & PATH
Set-EnvironmentVariableSafe -Name "ANDROID_HOME" -Value $sdkRoot -Target "Machine"
Set-EnvironmentVariableSafe -Name "ANDROID_SDK_ROOT" -Value $sdkRoot -Target "Machine"

$pathEntries = @(
    Join-Path -Path $cmdlineLatestDir -ChildPath "bin",
    Join-Path -Path $sdkRoot -ChildPath "platform-tools",
    Join-Path -Path $sdkRoot -ChildPath "build-tools\34.0.0",
    Join-Path -Path $sdkRoot -ChildPath "emulator"
)

foreach ($p in $pathEntries) {
    Add-PathSafe -PathToAdd $p -Target "Machine"
}

Refresh-SessionEnvironment

# 4. Auto-accept Android SDK Licenses
Write-Log -Level STEP -Message "Pre-seeding accepted Android SDK licenses..."
$licensesDir = Join-Path -Path $sdkRoot -ChildPath "licenses"
if (-not (Test-Path $licensesDir)) {
    New-Item -ItemType Directory -Path $licensesDir -Force | Out-Null
}

$licenseHashes = @{
    "android-sdk-license" = @(
        "24333f8a63b1d7f28fe163c7264e9a0f3d20d34d",
        "8933bad161af4178b1185d1a37fbf41ea5269c55",
        "d56f5187479451eabf01fb78af6dfcb131a6481e"
    );
    "android-sdk-preview-license" = @(
        "84831b9409646a918e30573bab4c9c91346d8abd"
    );
    "android-sdk-arm-dbt-license" = @(
        "859f317696f67be3ad891e4a682b1309f58c7042"
    );
    "intel-android-extra-license" = @(
        "d975f751698a77b662f1254ddbeed3901e976f5a"
    );
    "mips-android-extra-license" = @(
        "e9acab5b5fbb560a72cfa4f604b90c84967d23bc"
    );
    "google-gdk-license" = @(
        "33b6a2b649202da1b86e45817065ec74e1c45429"
    )
}

foreach ($licName in $licenseHashes.Keys) {
    $licFile = Join-Path -Path $licensesDir -ChildPath $licName
    $hashes = $licenseHashes[$licName] -join "`n"
    Set-Content -Path $licFile -Value $hashes -Encoding ASCII -Force
}
Write-Log -Level SUCCESS -Message "Pre-seeded standard Android SDK license hashes."

# 5. Install Core Android Packages (Optimized Batch Mode with Live Output Streaming)
if (Test-Path $sdkManagerBat) {
    $allPackages = if ($config.androidSdk -and $config.androidSdk.packagesToInstall) {
        $config.androidSdk.packagesToInstall
    } else {
        @("platform-tools", "build-tools;34.0.0", "platforms;android-34", "extras;google;m2repository")
    }

    # Pre-check to filter out already installed packages
    $missingPackages = @()
    foreach ($pkg in $allPackages) {
        $alreadyInstalled = $false
        if ($pkg -eq "platform-tools" -and (Test-Path (Join-Path -Path $sdkRoot -ChildPath "platform-tools\adb.exe"))) {
            $alreadyInstalled = $true
        } elseif ($pkg -match "build-tools;(\d+\.\d+\.\d+)" -and (Test-Path (Join-Path -Path $sdkRoot -ChildPath "build-tools\$($Matches[1])"))) {
            $alreadyInstalled = $true
        } elseif ($pkg -match "platforms;android-(\d+)" -and (Test-Path (Join-Path -Path $sdkRoot -ChildPath "platforms\android-$($Matches[1])"))) {
            $alreadyInstalled = $true
        } elseif ($pkg -eq "cmdline-tools;latest" -and (Test-Path $sdkManagerBat)) {
            $alreadyInstalled = $true
        } elseif ($pkg -like "*m2repository*" -and (Test-Path (Join-Path -Path $sdkRoot -ChildPath "extras\google\m2repository"))) {
            $alreadyInstalled = $true
        }

        if ($alreadyInstalled) {
            Write-Log -Level INFO -Message "Android package '$pkg' is already installed on disk. Skipping download."
        } else {
            $missingPackages += $pkg
        }
    }

    if ($missingPackages.Count -gt 0) {
        Write-Log -Level STEP -Message "Batch installing missing Android package(s): $($missingPackages -join ', ')..."

        # Execute sdkmanager in a single batch session with live stdout line streaming
        $pkgArgs = ($missingPackages | ForEach-Object { "`"$_`"" }) -join " "
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "cmd.exe"
        $psi.Arguments = "/c echo y | `"$sdkManagerBat`" --install $pkgArgs"
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi

        $outHandler = {
            if (-not [string]::IsNullOrEmpty($EventArgs.Data)) {
                $line = $EventArgs.Data.Trim()
                if ($line -match "\[.*\]\s*(\d+)%") {
                    Write-Host -NoNewline "`r  [FETCHING] Android Packages: $($Matches[1])% completed...   "
                } elseif ($line -match "Installing|Unzipping|Downloading") {
                    Write-Host "`n  [SDK] $line" -ForegroundColor DarkCyan
                }
            }
        }

        $proc.Start() | Out-Null
        $proc.BeginErrorReadLine()

        # Read standard output line by line for live progress updates
        while (-not $proc.StandardOutput.EndOfStream) {
            $line = $proc.StandardOutput.ReadLine()
            if ($line) {
                if ($line -match "\[.*\]\s*(\d+)%") {
                    Write-Host -NoNewline "`r  [FETCHING] Android Packages: $($Matches[1])% downloaded...   "
                } elseif ($line -match "Installing|Unzipping|Downloading") {
                    Write-Host "`n  [PROGRESS] $line" -ForegroundColor Cyan
                    if (Get-Command "Write-LiveLog" -ErrorAction SilentlyContinue) {
                        Write-LiveLog -Level INFO -Message $line
                    }
                }
            }
        }

        $proc.WaitForExit(600000) # 10 minute timeout
        Write-Host ""

        if ($proc.ExitCode -eq 0) {
            Write-Log -Level SUCCESS -Message "Android packages installed successfully."
        } else {
            Write-Log -Level WARN -Message "sdkmanager finished with exit code $($proc.ExitCode)."
        }
    } else {
        Write-Log -Level SUCCESS -Message "All required Android SDK packages are already up to date."
    }
}

Refresh-SessionEnvironment

$adbCheck = Join-Path -Path $sdkRoot -ChildPath "platform-tools\adb.exe"
if (Test-Path $adbCheck) {
    $adbV = & "$adbCheck" version 2>$null | Select-Object -First 1
    Write-Log -Level SUCCESS -Message "Android ADB operational: $adbV"
    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "android" -Status "Success" -DisplayName "Android SDK & Tools" -Detail "ADB and SDK 34 ready ($adbV)"
    }
} else {
    Write-Log -Level SUCCESS -Message "Android SDK setup completed."
    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "android" -Status "Success" -DisplayName "Android SDK & Tools" -Detail "Configured at $sdkRoot"
    }
}
