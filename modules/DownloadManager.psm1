# modules/DownloadManager.psm1
# High-speed parallel pre-download, smart multi-location archive lookup, and caching manager
# Automatically detects and skips existing downloads/installations across cache and user folders

[CmdletBinding()]
param()

$modulesPath = $PSScriptRoot
if (-not (Get-Command "Write-Log" -ErrorAction SilentlyContinue)) {
    $logPath = Join-Path -Path $modulesPath -ChildPath "Logging.psm1"
    if (Test-Path $logPath) { Import-Module $logPath -Global -DisableNameChecking }
}

$global:BnBDownloadCacheDir = "C:\Tools\.cache"
$global:BnBActiveDownloadJobs = @{}

function Get-DownloadCacheDirectory {
    [CmdletBinding()]
    param()

    if (-not (Test-Path $global:BnBDownloadCacheDir)) {
        New-Item -ItemType Directory -Path $global:BnBDownloadCacheDir -Force | Out-Null
    }
    return $global:BnBDownloadCacheDir
}

function Find-PreDownloadedArchive {
    <#
    .SYNOPSIS
        Searches common download locations for an existing matching archive or installer.
    .DESCRIPTION
        Checks the dedicated cache directory, user Downloads folder, and TEMP directory
        to determine if an archive has already been downloaded, skipping redundant downloads.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FileName,

        [Parameter(Mandatory = $false)]
        [string[]]$AlternativePatterns = @(),

        [Parameter(Mandatory = $false)]
        [long]$MinSizeBytes = 1000000
    )

    $searchFolders = @(
        $global:BnBDownloadCacheDir,
        "$HOME\Downloads",
        "$env:USERPROFILE\Downloads",
        "C:\Users\azureuser\Downloads",
        $env:TEMP,
        "C:\Tools"
    ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

    # 1. Exact filename match
    foreach ($folder in $searchFolders) {
        $candidate = Join-Path -Path $folder -ChildPath $FileName
        if (Test-Path $candidate) {
            $item = Get-Item $candidate -ErrorAction SilentlyContinue
            if ($item -and $item.Length -ge $MinSizeBytes) {
                return $candidate
            }
        }
    }

    # 2. Pattern match (e.g. *gradle*8.7*.zip, *flutter*windows*.zip)
    foreach ($pat in $AlternativePatterns) {
        if (-not $pat) { continue }
        foreach ($folder in $searchFolders) {
            $matches = Get-ChildItem -Path $folder -Filter $pat -File -ErrorAction SilentlyContinue
            foreach ($m in $matches) {
                if ($m.Length -ge $MinSizeBytes) {
                    return $m.FullName
                }
            }
        }
    }

    return $null
}

function Start-ParallelPreDownload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$SelectedTools,

        [Parameter(Mandatory = $false)]
        [string]$ConfigPath = "$PSScriptRoot\..\config.json"
    )

    $cacheDir = Get-DownloadCacheDirectory
    $curlPath = Get-Command "curl.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1
    if (-not $curlPath) { $curlPath = "C:\Windows\System32\curl.exe" }

    $downloadsToStart = @()

    # 1. Gradle 8.7 binary distribution (~160MB)
    if ($SelectedTools -contains "gradle") {
        $gradleInstalled = (Test-Path "C:\Tools\gradle\bin\gradle.bat") -or (Get-Command "gradle.bat" -ErrorAction SilentlyContinue)
        if ($gradleInstalled) {
            Write-Log -Level INFO -Message "Gradle is already installed on system. Skipping download."
        } else {
            $existing = Find-PreDownloadedArchive -FileName "gradle-8.7-bin.zip" -AlternativePatterns @("*gradle*8.7*.zip") -MinSizeBytes 10000000
            if ($existing) {
                Write-Log -Level INFO -Message "Gradle binary distribution archive is already found locally at '$existing'. Skipping download."
            } else {
                $gradleZip = Join-Path -Path $cacheDir -ChildPath "gradle-8.7-bin.zip"
                $downloadsToStart += @{
                    Id          = "gradle"
                    Name        = "Gradle 8.7 Distribution"
                    Url         = "https://services.gradle.org/distributions/gradle-8.7-bin.zip"
                    Destination = $gradleZip
                }
            }
        }
    }

    # 2. Android Command-Line Tools (~150MB)
    if ($SelectedTools -contains "android") {
        $cmdlineToolsLatest = "C:\Android\android-sdk\cmdline-tools\latest\bin\sdkmanager.bat"
        if (Test-Path $cmdlineToolsLatest) {
            Write-Log -Level INFO -Message "Android SDK cmdline-tools already installed at: $cmdlineToolsLatest. Skipping download."
        } else {
            $existing = Find-PreDownloadedArchive -FileName "android-cmdline-tools.zip" -AlternativePatterns @("*commandlinetools*win*.zip", "*cmdline-tools*.zip") -MinSizeBytes 10000000
            if ($existing) {
                Write-Log -Level INFO -Message "Android cmdline-tools archive is already found locally at '$existing'. Skipping download."
            } else {
                $androidZip = Join-Path -Path $cacheDir -ChildPath "android-cmdline-tools.zip"
                $downloadsToStart += @{
                    Id          = "android"
                    Name        = "Android SDK Command-Line Tools"
                    Url         = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
                    Destination = $androidZip
                }
            }
        }
    }

    # 3. Flutter SDK (~800MB - 1GB)
    if ($SelectedTools -contains "flutter") {
        $flutterInstalled = (Test-Path "C:\Tools\flutter\bin\flutter.bat") -or (Get-Command "flutter.bat" -ErrorAction SilentlyContinue)
        if ($flutterInstalled) {
            Write-Log -Level INFO -Message "Flutter SDK is already installed on system. Skipping download."
        } else {
            $existing = Find-PreDownloadedArchive -FileName "flutter-sdk.zip" -AlternativePatterns @("*flutter*windows*.zip") -MinSizeBytes 50000000
            if ($existing) {
                Write-Log -Level INFO -Message "Flutter SDK archive is already found locally at '$existing'. Skipping download."
            }
        }
    }

    # 4. OpenAI Codex CLI
    if ($SelectedTools -contains "codex") {
        $codexInstalled = (Test-Path "C:\Tools\codex\codex.exe") -or (Get-Command "codex.exe" -ErrorAction SilentlyContinue)
        if ($codexInstalled) {
            Write-Log -Level INFO -Message "Codex CLI is already installed on system. Skipping download."
        } else {
            $existing = Find-PreDownloadedArchive -FileName "codex.zip" -AlternativePatterns @("*codex*windows*.zip") -MinSizeBytes 1000000
            if ($existing) {
                Write-Log -Level INFO -Message "Codex CLI archive is already found locally at '$existing'. Skipping download."
            }
        }
    }

    if ($downloadsToStart.Count -eq 0) {
        Write-Log -Level DEBUG -Message "All standalone package downloads already found or installed locally. Skipping download queue."
        return
    }

    Write-Log -Level STEP -Message "Starting background parallel pre-download for $($downloadsToStart.Count) missing package(s)..."

    foreach ($item in $downloadsToStart) {
        $tempDest = "$($item.Destination).downloading"
        if (Test-Path $tempDest) { Remove-Item -Path $tempDest -Force -ErrorAction SilentlyContinue }

        $scriptBlock = {
            param($curl, $url, $target, $finalTarget)
            try {
                if (Test-Path $curl) {
                    & $curl -L -s -S -o $target $url
                } else {
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                    $wc = New-Object System.Net.WebClient
                    $wc.DownloadFile($url, $target)
                }

                if ((Test-Path $target) -and ((Get-Item $target).Length -gt 1000000)) {
                    if (Test-Path $finalTarget) { Remove-Item -Path $finalTarget -Force -ErrorAction SilentlyContinue }
                    Move-Item -Path $target -Destination $finalTarget -Force
                    return $true
                }
                return $false
            } catch {
                return $false
            }
        }

        $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $curlPath, $item.Url, $tempDest, $item.Destination
        $global:BnBActiveDownloadJobs[$item.Id] = @{
            Job         = $job
            Destination = $item.Destination
            TempDest    = $tempDest
            Name        = $item.Name
            Url         = $item.Url
            StartTime   = [DateTime]::Now
        }

        Write-Log -Level INFO -Message "Background download dispatched: $($item.Name) -> $($item.Destination)"
    }
}

function Get-CachedOrDownloadFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ToolId,

        [Parameter(Mandatory = $true)]
        [string]$Url,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,

        [Parameter(Mandatory = $false)]
        [string]$DisplayName = "",

        [Parameter(Mandatory = $false)]
        [string[]]$AlternativePatterns = @()
    )

    $name = if ($DisplayName) { $DisplayName } else { $ToolId }

    # 1. Already fully present at direct destination
    if ((Test-Path $DestinationPath) -and ((Get-Item $DestinationPath).Length -gt 1000000)) {
        $sizeMb = [math]::Round((Get-Item $DestinationPath).Length / 1MB, 1)
        Write-Log -Level SUCCESS -Message "Already downloaded: Verified package found at '$DestinationPath' ($sizeMb MB). Skipping download."
        return $DestinationPath
    }

    # 2. Check if already found in alternative search folders (e.g. C:\Tools\.cache, Downloads, Temp)
    $fileName = Split-Path -Path $DestinationPath -Leaf
    $existing = Find-PreDownloadedArchive -FileName $fileName -AlternativePatterns $AlternativePatterns -MinSizeBytes 1000000
    if ($existing) {
        $sizeMb = [math]::Round((Get-Item $existing).Length / 1MB, 1)
        Write-Log -Level SUCCESS -Message "Already downloaded: Found existing archive at '$existing' ($sizeMb MB). Skipping download."
        if ($existing -ne $DestinationPath) {
            $destDir = Split-Path -Path $DestinationPath -Parent
            if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
            Copy-Item -Path $existing -Destination $DestinationPath -Force -ErrorAction SilentlyContinue
        }
        return $DestinationPath
    }

    # 3. Check if currently downloading in background job
    if ($global:BnBActiveDownloadJobs.ContainsKey($ToolId)) {
        $jobInfo = $global:BnBActiveDownloadJobs[$ToolId]
        $job = $jobInfo.Job
        Write-Log -Level STEP -Message "Awaiting background download completion for $name..."

        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        while ($job.State -eq 'Running') {
            Start-Sleep -Milliseconds 500
            $tempFile = $jobInfo.TempDest
            $currentSizeMb = 0
            if (Test-Path $tempFile) {
                $currentSizeMb = [math]::Round((Get-Item $tempFile).Length / 1MB, 1)
            }
            Write-Host -NoNewline "`r  [DOWNLOADING] $($name): $($currentSizeMb) MB received ($([math]::Round($stopwatch.Elapsed.TotalSeconds, 0))s)...   "
        }
        Write-Host ""

        $jobResult = Receive-Job $job -AutoRemoveJob -Wait
        if ((Test-Path $DestinationPath) -and ((Get-Item $DestinationPath).Length -gt 1000000)) {
            Write-Log -Level SUCCESS -Message "Background download completed for $name ($([math]::Round((Get-Item $DestinationPath).Length / 1MB, 1)) MB in $([math]::Round($stopwatch.Elapsed.TotalSeconds, 1))s)."
            $global:BnBActiveDownloadJobs.Remove($ToolId)
            return $DestinationPath
        } else {
            Write-Log -Level WARN -Message "Background download for $name did not produce valid file. Retrying direct download..."
            $global:BnBActiveDownloadJobs.Remove($ToolId)
        }
    }

    # 4. Direct high-speed download with curl or WebClient
    Write-Log -Level STEP -Message "Downloading $name from: $Url"
    $parent = Split-Path -Path $DestinationPath -Parent
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

    $curl = Get-Command "curl.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1
    if (-not $curl) { $curl = "C:\Windows\System32\curl.exe" }

    if (Test-Path $curl) {
        & $curl -L --progress-bar -o $DestinationPath $Url
    } else {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($Url, $DestinationPath)
    }

    if ((Test-Path $DestinationPath) -and ((Get-Item $DestinationPath).Length -gt 1000000)) {
        Write-Log -Level SUCCESS -Message "Successfully downloaded $name ($([math]::Round((Get-Item $DestinationPath).Length / 1MB, 1)) MB)."
        return $DestinationPath
    } else {
        throw "Failed to download $name from $Url. Destination file is missing or invalid."
    }
}

Export-ModuleMember -Function Start-ParallelPreDownload, Get-CachedOrDownloadFile, Get-DownloadCacheDirectory, Find-PreDownloadedArchive
