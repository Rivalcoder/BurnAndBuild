# scripts/08-AI-Tools.ps1
# Automates Antigravity CLI, Antigravity IDE, Cursor AI Editor, and OpenAI Codex CLI
# Optimized with fast caching, live UI status updates, and resilient fallbacks

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

Write-LogHeader "Phase 6: AI & Autonomous Agent Development Tools"

# Load Configuration
$config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json

function Should-InstallTool {
    param([string]$toolId)
    if ($SelectedTools.Count -eq 0) { return $true }
    return ($SelectedTools -contains $toolId)
}

# 1. Antigravity CLI (agy)
if (Should-InstallTool "antigravityCli") {
    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "antigravityCli" -Status "Running" -DisplayName "Antigravity CLI (agy)" -Detail "Configuring Google Antigravity TUI assistant"
    }

    Write-Log -Level STEP -Message "Configuring Google Antigravity CLI (agy)..."

    $agyCmd = Get-Command "agy.exe" -ErrorAction SilentlyContinue
    if (-not $agyCmd) { $agyCmd = Get-Command "agy" -ErrorAction SilentlyContinue }

    if ($agyCmd) {
        Write-Log -Level SUCCESS -Message "Antigravity CLI is already installed at: $($agyCmd.Source). Skipping download and installation."
    } else {
        $installed = Install-WinPackage -PackageId "Google.AntigravityCLI" -DisplayName "Google Antigravity CLI"
        if (-not $installed) {
            Write-Log -Level WARN -Message "WinGet installation had issues. Using direct portable binary fallback..."
            $cliDir = "C:\Tools\antigravity-cli"
            if (-not (Test-Path $cliDir)) {
                New-Item -ItemType Directory -Path $cliDir -Force | Out-Null
            }
            $targetExe = Join-Path -Path $cliDir -ChildPath "agy.exe"
            $cliUrl = "https://storage.googleapis.com/antigravity-public/antigravity-cli/1.2.12-5784551402897408/windows-x64/cli_windows_x64.exe"

            try {
                $downloaded = Get-CachedOrDownloadFile -ToolId "antigravityCli" -Url $cliUrl -DestinationPath $targetExe -DisplayName "Antigravity CLI Binary"
                Add-PathSafe -PathToAdd $cliDir -Target "Machine"
                Write-Log -Level SUCCESS -Message "Antigravity CLI installed to $targetExe"
            } catch {
                Write-Log -Level ERROR -Message "Failed downloading Antigravity CLI: $_"
            }
        }
    }

    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "antigravityCli" -Status "Success" -DisplayName "Antigravity CLI (agy)" -Detail "agy CLI operational"
    }
} else {
    Write-Log -Level INFO -Message "Antigravity CLI was not selected. Skipping."
}

# 2. Antigravity IDE
if (Should-InstallTool "antigravityIde") {
    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "antigravityIde" -Status "Running" -DisplayName "Antigravity IDE" -Detail "Configuring Google Antigravity standalone environment"
    }

    Write-Log -Level STEP -Message "Configuring Google Antigravity IDE..."

    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Antigravity IDE",
        "C:\Program Files\Antigravity IDE",
        "$env:ProgramFiles\Antigravity IDE"
    )

    $ideFoundDir = $null
    foreach ($cand in $candidates) {
        if (Test-Path (Join-Path -Path $cand -ChildPath "Antigravity IDE.exe")) {
            $ideFoundDir = $cand
            break
        }
    }

    if ($ideFoundDir) {
        Write-Log -Level SUCCESS -Message "Antigravity IDE already present at: $ideFoundDir. Skipping download and installation."
        $binDir = Join-Path -Path $ideFoundDir -ChildPath "bin"
        if (Test-Path $binDir) {
            Add-PathSafe -PathToAdd $binDir -Target "Machine"
        }
        Set-EnvironmentVariableSafe -Name "ANTIGRAVITY_HOME" -Value $ideFoundDir -Target "Machine"
    } else {
        $installed = Install-WinPackage -PackageId "Google.AntigravityIDE" -DisplayName "Google Antigravity IDE"
        if ($installed) {
            Write-Log -Level SUCCESS -Message "Antigravity IDE package installed."
            foreach ($cand in $candidates) {
                if (Test-Path $cand) {
                    $binDir = Join-Path -Path $cand -ChildPath "bin"
                    if (Test-Path $binDir) {
                        Add-PathSafe -PathToAdd $binDir -Target "Machine"
                    }
                    Set-EnvironmentVariableSafe -Name "ANTIGRAVITY_HOME" -Value $cand -Target "Machine"
                    break
                }
            }
        }
    }

    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "antigravityIde" -Status "Success" -DisplayName "Antigravity IDE" -Detail "Antigravity IDE active"
    }
} else {
    Write-Log -Level INFO -Message "Antigravity IDE was not selected. Skipping."
}

# 3. Cursor AI Editor
if (Should-InstallTool "cursor") {
    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "cursor" -Status "Running" -DisplayName "Cursor AI Editor" -Detail "Configuring Anysphere Cursor editor"
    }

    Write-Log -Level STEP -Message "Configuring Cursor AI Editor..."

    $cursorCmd = Get-Command "cursor.cmd" -ErrorAction SilentlyContinue
    if (-not $cursorCmd) { $cursorCmd = Get-Command "cursor" -ErrorAction SilentlyContinue }

    $cursorApp = "$env:LOCALAPPDATA\Programs\cursor\Cursor.exe"

    if ($cursorCmd -or (Test-Path $cursorApp)) {
        Write-Log -Level SUCCESS -Message "Cursor AI Editor is already installed on this machine. Skipping download and installation."
    } else {
        $installed = Install-WinPackage -PackageId "Anysphere.Cursor" -DisplayName "Cursor AI Editor"
        if ($installed) {
            Write-Log -Level SUCCESS -Message "Cursor AI Editor installed successfully."
        }
    }

    $cursorBin = "$env:LOCALAPPDATA\Programs\cursor\resources\app\bin"
    if (Test-Path $cursorBin) {
        Add-PathSafe -PathToAdd $cursorBin -Target "Machine"
    }

    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "cursor" -Status "Success" -DisplayName "Cursor AI Editor" -Detail "Cursor Editor configured"
    }
} else {
    Write-Log -Level INFO -Message "Cursor AI Editor was not selected. Skipping."
}

# 4. OpenAI Codex CLI
if (Should-InstallTool "codex") {
    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "codex" -Status "Running" -DisplayName "OpenAI Codex CLI" -Detail "Configuring OpenAI Codex CLI"
    }

    Write-Log -Level STEP -Message "Configuring OpenAI Codex CLI..."

    $codexCmd = Get-Command "codex.exe" -ErrorAction SilentlyContinue
    if (-not $codexCmd) { $codexCmd = Get-Command "codex" -ErrorAction SilentlyContinue }

    if ($codexCmd -or (Test-Path "C:\Tools\codex\codex.exe")) {
        $loc = if ($codexCmd) { $codexCmd.Source } else { "C:\Tools\codex\codex.exe" }
        Write-Log -Level SUCCESS -Message "Codex CLI is already installed at: $loc. Skipping download and installation."
    } else {
        $installed = Install-WinPackage -PackageId "OpenAI.Codex" -DisplayName "OpenAI Codex CLI"
        if (-not $installed) {
            Write-Log -Level WARN -Message "WinGet reported an issue. Using direct release archive fallback..."
            $codexDir = "C:\Tools\codex"
            if (-not (Test-Path $codexDir)) {
                New-Item -ItemType Directory -Path $codexDir -Force | Out-Null
            }
            $cacheDir = Get-DownloadCacheDirectory
            $targetZip = Join-Path -Path $cacheDir -ChildPath "codex.zip"
            $codexUrl = "https://github.com/openai/codex/releases/download/rust-v0.158.0/codex-x86_64-pc-windows-msvc.exe.zip"

            try {
                $downloaded = Get-CachedOrDownloadFile -ToolId "codex" -Url $codexUrl -DestinationPath $targetZip -DisplayName "Codex CLI Release" -AlternativePatterns @("*codex*windows*.zip")
                $sevenZip = "C:\Program Files\7-Zip\7z.exe"
                if (Test-Path $sevenZip) {
                    & $sevenZip x -y -o"$codexDir" "$downloaded" | Out-Null
                } else {
                    Expand-Archive -Path $downloaded -DestinationPath $codexDir -Force
                }
                Add-PathSafe -PathToAdd $codexDir -Target "Machine"
                Write-Log -Level SUCCESS -Message "Codex CLI extracted and configured at $codexDir"
            } catch {
                Write-Log -Level ERROR -Message "Failed downloading Codex CLI: $_"
            }
        }
    }

    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "codex" -Status "Success" -DisplayName "OpenAI Codex CLI" -Detail "Codex CLI operational"
    }
} else {
    Write-Log -Level INFO -Message "Codex CLI was not selected. Skipping."
}

Refresh-SessionEnvironment
Write-Log -Level SUCCESS -Message "AI and autonomous agent toolchain phase completed."
