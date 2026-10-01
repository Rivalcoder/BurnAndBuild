<#
.SYNOPSIS
    BurnAndBuild - Master Orchestrator for Disposable Development VMs.

.DESCRIPTION
    Interactive & automated setup for Windows 10/11, Windows Server, and Linux.
    Prompts the user to select which tools to install (Antigravity CLI/IDE, Cursor,
    Codex, Flutter, Node.js, Python, Docker, Java JDK, Android SDK, VS Code, Git, etc.),
    and configures the selected tools, environment variables, PATH, and persistence.

.PARAMETER Tools
    Comma or space separated list of tools to install (e.g. -Tools "antigravity, cursor, codex, flutter, node, docker").
    When specified, runs unattended without interactive prompting.

.PARAMETER Preset
    Preconfigured tool profile: "ai" (Antigravity/Cursor/Codex), "mobile" (Flutter/Android),
    "web" (Node/Python/Docker), "devops" (Docker/Python), "minimal" (Git/VSCode), or "all".

.PARAMETER Full
    Installs all available tools in the catalog without prompting.

.PARAMETER NoGui
    Forces interactive console menu instead of modern graphical checklist.

.PARAMETER ForceCli
    Alias for -NoGui.

.PARAMETER BaseOnly
    Runs only Base Windows configuration and core CLI tools.

.PARAMETER SkipAndroid
    Skips Android SDK installation even if part of a preset.

.PARAMETER SkipIDEs
    Skips Visual Studio Code and editor installations.

.PARAMETER GitName
    Optional Git user name to configure.

.PARAMETER GitEmail
    Optional Git email to configure.

.PARAMETER ConfigPath
    Custom path to config.json. Defaults to config.json in repo root.

.EXAMPLE
    # Default: Launches interactive GUI checklist to choose tools
    .\Start-Windows.bat

.EXAMPLE
    # Unattended: Install specific tools
    .\scripts\bootstrap.ps1 -Tools "antigravity, cursor, codex, flutter, node, python, docker"

.EXAMPLE
    # Unattended: Install AI & Agents preset
    .\scripts\bootstrap.ps1 -Preset "ai"
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

if (Test-Path (Join-Path -Path $scriptDir -ChildPath "config.json")) {
    $rootDir = $scriptDir
    $scriptsDir = Join-Path -Path $rootDir -ChildPath "scripts"
} else {
    $rootDir = (Resolve-Path (Join-Path -Path $scriptDir -ChildPath "..")).Path
    $scriptsDir = $scriptDir
}

if (-not $ConfigPath) { $ConfigPath = Join-Path -Path $rootDir -ChildPath "config.json" }

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
    if ($ConfigPath -ne (Join-Path -Path $rootDir -ChildPath "config.json")) { $argList += " -ConfigPath `"$ConfigPath`"" }

    Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $argList
    exit
}

# 2. Import Core Modules
$modulesPath = Join-Path -Path $rootDir -ChildPath "modules"
Import-Module (Join-Path -Path $modulesPath -ChildPath "Logging.psm1") -Global -DisableNameChecking
Import-Module (Join-Path -Path $modulesPath -ChildPath "Environment.psm1") -DisableNameChecking
Import-Module (Join-Path -Path $modulesPath -ChildPath "WinGetHelper.psm1") -DisableNameChecking
Import-Module (Join-Path -Path $modulesPath -ChildPath "ToolSelector.psm1") -DisableNameChecking

# 3. Initialize Logger
$logDir = "C:\Logs\BurnAndBuild"
Initialize-Logger -LogDirectory $logDir -Prefix "burnandbuild"

Write-Host @"
================================================================================
          BURNANDBUILD - DISPOSABLE DEV ENVIRONMENT ORCHESTRATOR
================================================================================
  Target OS       : $([System.Environment]::OSVersion.VersionString)
  Architecture    : $([System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE"))
  PowerShell      : $($PSVersionTable.PSVersion.ToString())
  Log Directory   : $logDir
================================================================================
"@ -ForegroundColor Cyan

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

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# 5. Pipeline Execution Based on Selected Tools
try {
    # Phase 1: Base Windows OS Settings
    if ($selectedTools -contains "baseWindows") {
        $p1 = Join-Path -Path $scriptsDir -ChildPath "01-Base-Windows.ps1"
        & $p1 -ConfigPath $ConfigPath
    } else {
        Write-Log -Level INFO -Message "Phase 1 (Base Windows) skipped per tool selection."
    }

    # Phase 2: Core CLI Tools (Git, 7-Zip, jq, pwsh 7, gh)
    if ($selectedTools -contains "gitCli") {
        $p2 = Join-Path -Path $scriptsDir -ChildPath "02-Common-CLI.ps1"
        & $p2 -ConfigPath $ConfigPath
    } else {
        Write-Log -Level INFO -Message "Phase 2 (Core CLI) skipped per tool selection."
    }

    # Phase 3: Runtimes (Java, Node.js, Python, Gradle)
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

    # Phase 4: Android SDK
    if ($selectedTools -contains "android") {
        $p4 = Join-Path -Path $scriptsDir -ChildPath "04-Android-SDK.ps1"
        & $p4 -ConfigPath $ConfigPath
    } else {
        Write-Log -Level INFO -Message "Phase 4 (Android SDK) skipped per tool selection."
    }

    # Phase 5: Flutter SDK
    if ($selectedTools -contains "flutter") {
        $p5 = Join-Path -Path $scriptsDir -ChildPath "05-Flutter-SDK.ps1"
        & $p5 -ConfigPath $ConfigPath
    } else {
        Write-Log -Level INFO -Message "Phase 5 (Flutter SDK) skipped per tool selection."
    }

    # Phase 6: Docker Desktop
    if ($selectedTools -contains "docker") {
        $p6 = Join-Path -Path $scriptsDir -ChildPath "06-Docker.ps1"
        & $p6 -ConfigPath $ConfigPath
    } else {
        Write-Log -Level INFO -Message "Phase 6 (Docker Desktop) skipped per tool selection."
    }

    # Phase 7: IDEs, Editors, Browsers, API, BI & Project Tools
    $ideIds = @("vscode", "notepadpp", "chrome", "brave", "postman", "dbeaver", "powerbi", "jira")
    $hasIde = $false
    foreach ($id in $ideIds) {
        if ($selectedTools -contains $id) { $hasIde = $true; break }
    }

    if ($hasIde) {
        $p7 = Join-Path -Path $scriptsDir -ChildPath "07-IDEs-Editors.ps1"
        & $p7 -ConfigPath $ConfigPath -SelectedTools $selectedTools
    } else {
        Write-Log -Level INFO -Message "Phase 7 (IDEs & Editors) skipped per tool selection."
    }

    # Phase 8: AI & Autonomous Agent Tools (Antigravity CLI/IDE, Cursor, Codex)
    $aiIds = @("antigravityCli", "antigravityIde", "cursor", "codex")
    $hasAi = $false
    foreach ($id in $aiIds) {
        if ($selectedTools -contains $id) { $hasAi = $true; break }
    }

    if ($hasAi) {
        $p8 = Join-Path -Path $scriptsDir -ChildPath "08-AI-Tools.ps1"
        & $p8 -ConfigPath $ConfigPath -SelectedTools $selectedTools
    } else {
        Write-Log -Level INFO -Message "Phase 8 (AI Tools) skipped per tool selection."
    }

    # Phase 9: Shell Profile & Developer Aliases
    $p9 = Join-Path -Path $scriptsDir -ChildPath "08-Shell-Profile.ps1"
    & $p9 -SelectedTools $selectedTools

    # Phase 10: Persistence Setup & Caches
    $p10 = Join-Path -Path $scriptsDir -ChildPath "09-Persistence-Setup.ps1"
    & $p10 -ConfigPath $ConfigPath -GitUserName $GitName -GitUserEmail $GitEmail -SelectedTools $selectedTools

    # Final environment sync
    Refresh-SessionEnvironment
    $stopwatch.Stop()

    Write-Host ""
    Write-Host "================================================================================" -ForegroundColor Green
    Write-Log -Level SUCCESS -Message "BURNANDBUILD DEV ENVIRONMENT SETUP COMPLETED IN $([math]::Round($stopwatch.Elapsed.TotalMinutes, 2)) MINUTES!"
    Write-Host "================================================================================" -ForegroundColor Green
    Write-Host ""

    # Verification Smoke Test for Selected Tools
    $testScript = Join-Path -Path $rootDir -ChildPath "tests\Verify-Installation.ps1"
    if (Test-Path $testScript) {
        & $testScript -SelectedTools $selectedTools
    }

} catch {
    Write-Log -Level ERROR -Message "Bootstrap halted due to unhandled fatal error: $_"
    Write-Log -Level ERROR -Message "StackTrace: $($_.ScriptStackTrace)"
    exit 1
}
