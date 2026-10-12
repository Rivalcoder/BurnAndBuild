<#
.SYNOPSIS
    BurnAndBuild - Master Orchestrator for Disposable Development VMs.

.DESCRIPTION
    Interactive & automated setup for Windows 10/11, Windows Server, and Linux.
    Prompts the user to select which tools to install (Antigravity CLI/IDE, Cursor,
    Codex, Flutter, Node.js, Python, Docker, Java JDK, Android SDK, VS Code, Git, etc.),
    and configures the selected tools, environment variables, PATH, and persistence.
    Features parallel background pre-downloading, real-time visual progress monitoring,
    and places heavy Mobile App SDKs in the final installation phase.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$Tools = @(),

    [Parameter(Mandatory = $false)]
    [string]$Preset = "",

    [Parameter(Mandatory = $false)]
    [switch]$Full,

    [Parameter(Mandatory = $false)]
    [switch]$NoGui,

    [Parameter(Mandatory = $false)]
    [switch]$ForceCli,

    [Parameter(Mandatory = $false)]
    [switch]$BaseOnly,

    [Parameter(Mandatory = $false)]
    [switch]$SkipAndroid,

    [Parameter(Mandatory = $false)]
    [switch]$SkipIDEs,

    [Parameter(Mandatory = $false)]
    [string]$GitName = "",

    [Parameter(Mandatory = $false)]
    [string]$GitEmail = "",

    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = ""
)

# Resolve Script Directory and Repository Root robustly
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

if (Test-Path (Join-Path -Path $scriptDir -ChildPath "config\config.json")) {
    $rootDir = $scriptDir
    $scriptsDir = Join-Path -Path $rootDir -ChildPath "scripts"
} elseif (Test-Path (Join-Path -Path $scriptDir -ChildPath "config.json")) {
    $rootDir = $scriptDir
    $scriptsDir = Join-Path -Path $rootDir -ChildPath "scripts"
} else {
    $rootDir = (Resolve-Path (Join-Path -Path $scriptDir -ChildPath "..")).Path
    $scriptsDir = $scriptDir
}

$defaultConfigPath = if (Test-Path (Join-Path -Path $rootDir -ChildPath "config\config.json")) {
    Join-Path -Path $rootDir -ChildPath "config\config.json"
} else {
    Join-Path -Path $rootDir -ChildPath "config.json"
}

if (-not $ConfigPath) { $ConfigPath = $defaultConfigPath }

# 1. Administrator Elevation Check & Self-Elevation
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Warning "Administrator rights required. Relaunching in an elevated PowerShell session..."
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($Tools.Count -gt 0) { $argList += " -Tools `"$($Tools -join ',')`"" }
    if ($Preset) { $argList += " -Preset `"$Preset`"" }
    if ($Full) { $argList += " -Full" }
    if ($NoGui) { $argList += " -NoGui" }
    if ($ForceCli) { $argList += " -ForceCli" }
    if ($BaseOnly) { $argList += " -BaseOnly" }
    if ($SkipAndroid) { $argList += " -SkipAndroid" }
    if ($SkipIDEs) { $argList += " -SkipIDEs" }
    if ($GitName) { $argList += " -GitName `"$GitName`"" }
    if ($GitEmail) { $argList += " -GitEmail `"$GitEmail`"" }
    if ($ConfigPath -ne $defaultConfigPath) { $argList += " -ConfigPath `"$ConfigPath`"" }

    Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $argList
    exit
}

# 2. Import Core Modules
$modulesPath = Join-Path -Path $rootDir -ChildPath "modules"
Import-Module (Join-Path -Path $modulesPath -ChildPath "Logging.psm1") -Global -DisableNameChecking
Import-Module (Join-Path -Path $modulesPath -ChildPath "Environment.psm1") -DisableNameChecking
Import-Module (Join-Path -Path $modulesPath -ChildPath "WinGetHelper.psm1") -DisableNameChecking
Import-Module (Join-Path -Path $modulesPath -ChildPath "DownloadManager.psm1") -DisableNameChecking
Import-Module (Join-Path -Path $modulesPath -ChildPath "UIProgress.psm1") -DisableNameChecking
Import-Module (Join-Path -Path $modulesPath -ChildPath "ToolSelector.psm1") -DisableNameChecking

# 3. Initialize Logger
$logDir = "C:\Logs\BurnAndBuild"
Initialize-Logger -LogDirectory $logDir -Prefix "burnandbuild"

# 4. Resolve Tools to Install (Interactive or Parameterized)
$selectedTools = @()

if ($BaseOnly) {
    $selectedTools = @("baseWindows", "gitCli")
} else {
    $selectorParams = @{
        ConfigPath     = $ConfigPath
        ExplicitTools  = $Tools
        Preset         = $Preset
        Full           = $Full
        NoGui          = ($NoGui -or $ForceCli)
    }

    $selectedTools = Get-SelectedTools @selectorParams

    # Legacy skip flags
    if ($SkipAndroid -and ($selectedTools -contains "android")) {
        $selectedTools = $selectedTools | Where-Object { $_ -ne "android" }
    }
    if ($SkipIDEs) {
        $selectedTools = $selectedTools | Where-Object { $_ -ne "vscode" -and $_ -ne "notepadpp" }
    }
}

if ($null -eq $selectedTools -or $selectedTools.Count -eq 0) {
    Write-Log -Level WARN -Message "No tools selected for installation. Exiting."
    exit 0
}

Write-Log -Level INFO -Message "Selected tools for installation: $($selectedTools -join ', ')"

# 5. Initialize Live UI Progress Dashboard (Console + optional WPF Live Monitor)
Initialize-ProgressUI -SelectedTools $selectedTools -NoGui:($NoGui -or $ForceCli) -ForceCli:$ForceCli

# 6. Start Background Parallel Pre-Download for heavy standalone assets (Gradle zip, Android cmdline tools, etc.)
Start-ParallelPreDownload -SelectedTools $selectedTools -ConfigPath $ConfigPath

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$totalPhases = 10

# 7. Pipeline Execution Based on Selected Tools (Optimized Sequencing: Mobile SDKs at Last)
try {
    # Phase 1: Base Windows OS Settings
    Write-LivePhase -PhaseNumber 1 -TotalPhases $totalPhases -Title "Base Windows Configuration" -Description "Long paths, Developer mode, power policy & file explorer tweaks"
    if ($selectedTools -contains "baseWindows") {
        $p1 = Join-Path -Path $scriptsDir -ChildPath "01-Base-Windows.ps1"
        & $p1 -ConfigPath $ConfigPath
        Write-LiveToolStatus -ToolId "baseWindows" -Status "Success" -DisplayName "Windows Dev Optimizations" -Detail "Long paths, Dev Mode, Power policy applied"
    } else {
        Write-Log -Level INFO -Message "Phase 1 (Base Windows) skipped per tool selection."
        Write-LiveToolStatus -ToolId "baseWindows" -Status "Skipped" -DisplayName "Windows Dev Optimizations" -Detail "Not selected"
    }

    # Phase 2: Core CLI Tools (Git, 7-Zip, jq, pwsh 7, gh)
    Write-LivePhase -PhaseNumber 2 -TotalPhases $totalPhases -Title "Core CLI Tools & Shell Utilities" -Description "Git for Windows, 7-Zip archiver, jq, ripgrep, fzf, PowerShell 7, GitHub CLI"
    if ($selectedTools -contains "gitCli") {
        $p2 = Join-Path -Path $scriptsDir -ChildPath "02-Common-CLI.ps1"
        & $p2 -ConfigPath $ConfigPath
        Write-LiveToolStatus -ToolId "gitCli" -Status "Success" -DisplayName "Git & Core CLI Suite" -Detail "Git, 7-Zip, jq, ripgrep, fzf, pwsh 7 configured"
    } else {
        Write-Log -Level INFO -Message "Phase 2 (Core CLI) skipped per tool selection."
        Write-LiveToolStatus -ToolId "gitCli" -Status "Skipped" -DisplayName "Git & Core CLI Suite" -Detail "Not selected"
    }

    # Phase 3: Development Runtimes (Java, Node.js, Python, Gradle)
    Write-LivePhase -PhaseNumber 3 -TotalPhases $totalPhases -Title "Development Runtimes" -Description "Eclipse Temurin JDK 17, Node.js LTS (fnm), Python 3.12, Gradle 8.7"
    $runtimeIds = @("java", "node", "python", "gradle")
    $hasRuntime = $false
    foreach ($r in $runtimeIds) {
        if ($selectedTools -contains $r) { $hasRuntime = $true; break }
    }

    if ($hasRuntime) {
        $p3 = Join-Path -Path $scriptsDir -ChildPath "03-Runtimes.ps1"
        & $p3 -ConfigPath $ConfigPath -SelectedTools $selectedTools
    } else {
        Write-Log -Level INFO -Message "Phase 3 (Runtimes) skipped: none selected."
    }

    # Phase 4: Docker Desktop & Container Toolchain Automation
    Write-LivePhase -PhaseNumber 4 -TotalPhases $totalPhases -Title "Containers & Cloud Toolchain" -Description "Docker Desktop, WSL2 virtualization prerequisites, Docker CLI"
    if ($selectedTools -contains "docker") {
        Write-LiveToolStatus -ToolId "docker" -Status "Running" -DisplayName "Docker Desktop" -Detail "Verifying WSL2 and container tools"
        $p4 = Join-Path -Path $scriptsDir -ChildPath "06-Docker.ps1"
        & $p4 -ConfigPath $ConfigPath
        Write-LiveToolStatus -ToolId "docker" -Status "Success" -DisplayName "Docker Desktop" -Detail "Docker engine & CLI operational"
    } else {
        Write-Log -Level INFO -Message "Phase 4 (Docker Desktop) skipped per tool selection."
        Write-LiveToolStatus -ToolId "docker" -Status "Skipped" -DisplayName "Docker Desktop" -Detail "Not selected"
    }

    # Phase 5: IDEs, Editors, Browsers, API, BI & Project Tools
    Write-LivePhase -PhaseNumber 5 -TotalPhases $totalPhases -Title "IDEs, Editors & Browsers" -Description "Visual Studio Code with dynamic extensions, Google Chrome, Brave, Postman, DBeaver"
    $ideIds = @("vscode", "notepadpp", "chrome", "brave", "postman", "dbeaver", "powerbi", "jira")
    $hasIde = $false
    foreach ($id in $ideIds) {
        if ($selectedTools -contains $id) { $hasIde = $true; break }
    }

    if ($hasIde) {
        $p5 = Join-Path -Path $scriptsDir -ChildPath "07-IDEs-Editors.ps1"
        & $p5 -ConfigPath $ConfigPath -SelectedTools $selectedTools
    } else {
        Write-Log -Level INFO -Message "Phase 5 (IDEs & Editors) skipped per tool selection."
    }

    # Phase 6: AI & Autonomous Agent Tools (Antigravity CLI/IDE, Cursor, Codex)
    Write-LivePhase -PhaseNumber 6 -TotalPhases $totalPhases -Title "AI & Autonomous Agent Tools" -Description "Google Antigravity CLI (agy), Antigravity IDE, Cursor AI Editor, OpenAI Codex CLI"
    $aiIds = @("antigravityCli", "antigravityIde", "cursor", "codex")
    $hasAi = $false
    foreach ($id in $aiIds) {
        if ($selectedTools -contains $id) { $hasAi = $true; break }
    }

    if ($hasAi) {
        $p6 = Join-Path -Path $scriptsDir -ChildPath "08-AI-Tools.ps1"
        & $p6 -ConfigPath $ConfigPath -SelectedTools $selectedTools
    } else {
        Write-Log -Level INFO -Message "Phase 6 (AI Tools) skipped per tool selection."
    }

    # Phase 7: PowerShell Environment & Shell Customization
    Write-LivePhase -PhaseNumber 7 -TotalPhases $totalPhases -Title "PowerShell Shell Customization" -Description "posh-git, PSReadLine predictive history, developer aliases, reload-env helper"
    $p7 = Join-Path -Path $scriptsDir -ChildPath "08-Shell-Profile.ps1"
    & $p7 -SelectedTools $selectedTools

    # Phase 8: Data Persistence, Cache Redirection, and Identity
    Write-LivePhase -PhaseNumber 8 -TotalPhases $totalPhases -Title "Persistence & Cache Redirection" -Description "Workspace setup, heavy cache redirection (.gradle, pip, uv, pub-cache), SSH keypair"
    $p8 = Join-Path -Path $scriptsDir -ChildPath "09-Persistence-Setup.ps1"
    & $p8 -ConfigPath $ConfigPath -GitUserName $GitName -GitUserEmail $GitEmail -SelectedTools $selectedTools

    # Phase 9: Mobile App Development SDKs (Android SDK & Flutter SDK) -> PLACED AT THE LAST!
    Write-LivePhase -PhaseNumber 9 -TotalPhases $totalPhases -Title "Mobile App Development SDKs (Final Phase)" -Description "Android SDK cmdline-tools, platform-tools, build-tools, Flutter SDK & engine precache"

    # Part A: Android SDK
    if ($selectedTools -contains "android") {
        $pAndroid = Join-Path -Path $scriptsDir -ChildPath "04-Android-SDK.ps1"
        & $pAndroid -ConfigPath $ConfigPath
    } else {
        Write-Log -Level INFO -Message "Phase 9A (Android SDK) skipped per tool selection."
        Write-LiveToolStatus -ToolId "android" -Status "Skipped" -DisplayName "Android SDK & Tools" -Detail "Not selected"
    }

    # Part B: Flutter SDK
    if ($selectedTools -contains "flutter") {
        $pFlutter = Join-Path -Path $scriptsDir -ChildPath "05-Flutter-SDK.ps1"
        & $pFlutter -ConfigPath $ConfigPath
    } else {
        Write-Log -Level INFO -Message "Phase 9B (Flutter SDK) skipped per tool selection."
        Write-LiveToolStatus -ToolId "flutter" -Status "Skipped" -DisplayName "Flutter SDK" -Detail "Not selected"
    }

    # Final environment sync before verification
    Refresh-SessionEnvironment
    $stopwatch.Stop()

    # Complete UI Progress
    Complete-ProgressUI -TotalMinutes $stopwatch.Elapsed.TotalMinutes

    # Phase 10: Environment Verification & Health Check Smoke Test
    Write-LivePhase -PhaseNumber 10 -TotalPhases $totalPhases -Title "Environment Verification & Health Check" -Description "Automated smoke tests for all installed components"
    $testScript = Join-Path -Path $rootDir -ChildPath "tests\Verify-Installation.ps1"
    if (Test-Path $testScript) {
        & $testScript -SelectedTools $selectedTools
    }

} catch {
    Write-Log -Level ERROR -Message "Bootstrap halted due to unhandled fatal error: $_"
    Write-Log -Level ERROR -Message "StackTrace: $($_.ScriptStackTrace)"
    exit 1
}
