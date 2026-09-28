# scripts/04-Android-SDK.ps1
# Automates Android Command-Line Tools, Platform-Tools (adb), Build-Tools, and License Acceptance

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

Write-LogHeader "Phase 4: Android & Mobile SDK Automation"

# Load Configuration
$config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json

$sdkRoot = $config.androidSdk.installDirectory
$cmdlineZipUrl = $config.androidSdk.cmdlineToolsZipUrl
$cmdlineLatestDir = Join-Path -Path $sdkRoot -ChildPath "cmdline-tools\latest"
$sdkManagerBat = Join-Path -Path $cmdlineLatestDir -ChildPath "bin\sdkmanager.bat"

# 1. Check JAVA_HOME dependency
if (-not $env:JAVA_HOME -or -not (Test-Path $env:JAVA_HOME)) {
    Write-Log -Level WARN -Message "JAVA_HOME is not set or directory not found. Android SDK tools require Java 17."
    Refresh-SessionEnvironment
}

# 2. Download and Scaffold Command-Line Tools
if (-not (Test-Path $sdkManagerBat)) {
    Write-Log -Level STEP -Message "Android SDK cmdline-tools not found. Downloading from Google repository..."
    
    $tempZip = Join-Path -Path $env:TEMP -ChildPath "android-cmdline-tools.zip"
    $tempExtract = Join-Path -Path $env:TEMP -ChildPath "android-cmdline-extract"
    
    if (-not (Test-Path $sdkRoot)) {
        New-Item -ItemType Directory -Path $sdkRoot -Force | Out-Null
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Write-Log -Level INFO -Message "Downloading: $cmdlineZipUrl"
    Invoke-WebRequest -Uri $cmdlineZipUrl -OutFile $tempZip -UseBasicParsing

    Write-Log -Level INFO -Message "Extracting cmdline-tools archive..."
    if (Test-Path $tempExtract) { Remove-Item -Path $tempExtract -Recurse -Force }
    Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

    # Proper directory structure expected by sdkmanager: <ANDROID_HOME>/cmdline-tools/latest/...
    if (-not (Test-Path $cmdlineLatestDir)) {
        New-Item -ItemType Directory -Path $cmdlineLatestDir -Force | Out-Null
    }

    # The archive contains a root folder named 'cmdline-tools'
    $extractedRoot = Join-Path -Path $tempExtract -ChildPath "cmdline-tools"
    Get-ChildItem -Path $extractedRoot | Move-Item -Destination $cmdlineLatestDir -Force

    # Clean up temp files
    Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

    Write-Log -Level SUCCESS -Message "Extracted cmdline-tools into: $cmdlineLatestDir"
} else {
    Write-Log -Level INFO -Message "Android cmdline-tools already present at: $cmdlineLatestDir"
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
Write-Log -Level STEP -Message "Accepting Android SDK licenses automatically..."
$licensesDir = Join-Path -Path $sdkRoot -ChildPath "licenses"
if (-not (Test-Path $licensesDir)) {
    New-Item -ItemType Directory -Path $licensesDir -Force | Out-Null
}

# Pre-seed standard Google license hashes
$licenseHashes = @{
    "android-sdk-license" = @(
        "24333f8a63b1d7f28fe163c7264e9a0f3d20d34d",
        "8933bad161af4178b1185d1a37fbf41ea5269c55",
        "d56f5187479451eabf01fb78af6dfcb131a6481e"
    );
    "android-sdk-preview-license" = @(
        "84831b9409646a918e30573bab4c9c91346d8abd"
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

# 5. Install Essential Android Components via sdkmanager
if (Test-Path $sdkManagerBat) {
    Write-Log -Level STEP -Message "Installing core Android SDK packages via sdkmanager..."
    
    $packages = $config.androidSdk.packagesToInstall
    foreach ($pkg in $packages) {
        Write-Log -Level INFO -Message "Checking / installing Android package: $pkg"
        
        # Run sdkmanager with piped 'y' input to guarantee headless non-blocking execution
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "cmd.exe"
        $psi.Arguments = "/c echo y | `"$sdkManagerBat`" --install `"$pkg`""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true

        $proc = [System.Diagnostics.Process]::Start($psi)
        $output = $proc.StandardOutput.ReadToEnd()
        $proc.WaitForExit(300000) # 5 min timeout

        if ($proc.ExitCode -eq 0) {
            Write-Log -Level SUCCESS -Message "Successfully installed: $pkg"
        } else {
            Write-Log -Level WARN -Message "sdkmanager finished with exit code $($proc.ExitCode) for package $pkg."
            Write-Log -Level DEBUG -Message "Output: $output"
        }
    }
}

Refresh-SessionEnvironment

Write-Log -Level SUCCESS -Message "Android & Mobile SDK setup completed successfully."
