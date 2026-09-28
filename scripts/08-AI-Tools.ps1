# scripts/08-AI-Tools.ps1
# Automates Antigravity CLI, Antigravity IDE, Cursor AI Editor, and OpenAI Codex CLI

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

Write-LogHeader "Phase 8: AI & Autonomous Agent Development Tools"

# Load Configuration
$config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json

function Should-InstallTool {
    param([string]$toolId)
    if ($SelectedTools.Count -eq 0) { return $true }
    return ($SelectedTools -contains $toolId)
}

# 1. Antigravity CLI (agy)
if (Should-InstallTool "antigravityCli") {
    Write-Log -Level STEP -Message "Configuring Google Antigravity CLI (agy)..."

    $agyCmd = Get-Command "agy.exe" -ErrorAction SilentlyContinue
    if (-not $agyCmd) { $agyCmd = Get-Command "agy" -ErrorAction SilentlyContinue }

    if ($agyCmd) {
        Write-Log -Level INFO -Message "Antigravity CLI is already installed at: $($agyCmd.Source)"
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
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Write-Log -Level INFO -Message "Downloading Antigravity CLI binary from official CDN..."
                Invoke-WebRequest -Uri $cliUrl -OutFile $targetExe -UseBasicParsing
                Add-PathSafe -PathToAdd $cliDir -Target "Machine"
                Write-Log -Level SUCCESS -Message "Antigravity CLI installed to $targetExe"
            } catch {
                Write-Log -Level ERROR -Message "Failed downloading Antigravity CLI: $_"
            }
        }
    }
} else {
    Write-Log -Level INFO -Message "Antigravity CLI was not selected. Skipping."
}

# 2. Antigravity IDE
if (Should-InstallTool "antigravityIde") {
    Write-Log -Level STEP -Message "Configuring Google Antigravity IDE..."

    # Check common install locations
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
        Write-Log -Level SUCCESS -Message "Antigravity IDE already present at: $ideFoundDir"
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
        } else {
            Write-Log -Level WARN -Message "WinGet install had a warning for Antigravity IDE."
        }
    }
} else {
    Write-Log -Level INFO -Message "Antigravity IDE was not selected. Skipping."
}

# 3. Cursor AI Editor
if (Should-InstallTool "cursor") {
    Write-Log -Level STEP -Message "Configuring Cursor AI Editor..."

    $cursorCmd = Get-Command "cursor.cmd" -ErrorAction SilentlyContinue
    if (-not $cursorCmd) { $cursorCmd = Get-Command "cursor" -ErrorAction SilentlyContinue }

    $cursorApp = "$env:LOCALAPPDATA\Programs\cursor\Cursor.exe"

    if ($cursorCmd -or (Test-Path $cursorApp)) {
        Write-Log -Level INFO -Message "Cursor AI Editor is already installed on this machine."
    } else {
        $installed = Install-WinPackage -PackageId "Anysphere.Cursor" -DisplayName "Cursor AI Editor"
        if ($installed) {
            Write-Log -Level SUCCESS -Message "Cursor AI Editor installed successfully."
        } else {
            Write-Log -Level WARN -Message "Cursor installation reported a warning."
        }
    }

    # Ensure cursor CLI path is added
    $cursorBin = "$env:LOCALAPPDATA\Programs\cursor\resources\app\bin"
    if (Test-Path $cursorBin) {
        Add-PathSafe -PathToAdd $cursorBin -Target "Machine"
    }
} else {
    Write-Log -Level INFO -Message "Cursor AI Editor was not selected. Skipping."
}

# 4. OpenAI Codex CLI
if (Should-InstallTool "codex") {
    Write-Log -Level STEP -Message "Configuring OpenAI Codex CLI..."

    $codexCmd = Get-Command "codex.exe" -ErrorAction SilentlyContinue
    if (-not $codexCmd) { $codexCmd = Get-Command "codex" -ErrorAction SilentlyContinue }

    if ($codexCmd) {
        Write-Log -Level INFO -Message "Codex CLI is already installed at: $($codexCmd.Source)"
    } else {
        $installed = Install-WinPackage -PackageId "OpenAI.Codex" -DisplayName "OpenAI Codex CLI"
        if (-not $installed) {
            Write-Log -Level WARN -Message "WinGet reported an issue. Using direct release archive fallback..."
            $codexDir = "C:\Tools\codex"
            if (-not (Test-Path $codexDir)) {
                New-Item -ItemType Directory -Path $codexDir -Force | Out-Null
            }
            $tempZip = Join-Path -Path $env:TEMP -ChildPath "codex.zip"
            $codexUrl = "https://github.com/openai/codex/releases/download/rust-v0.158.0/codex-x86_64-pc-windows-msvc.exe.zip"

            try {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Write-Log -Level INFO -Message "Downloading Codex CLI from official GitHub releases..."
                Invoke-WebRequest -Uri $codexUrl -OutFile $tempZip -UseBasicParsing
                Expand-Archive -Path $tempZip -DestinationPath $codexDir -Force
                Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue
                Add-PathSafe -PathToAdd $codexDir -Target "Machine"
                Write-Log -Level SUCCESS -Message "Codex CLI extracted and configured at $codexDir"
            } catch {
                Write-Log -Level ERROR -Message "Failed downloading Codex CLI: $_"
            }
        }
    }
} else {
    Write-Log -Level INFO -Message "Codex CLI was not selected. Skipping."
}

Refresh-SessionEnvironment
Write-Log -Level SUCCESS -Message "AI and autonomous agent toolchain phase completed."
