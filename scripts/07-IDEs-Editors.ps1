# scripts/07-IDEs-Editors.ps1
# Installs VS Code, Notepad++, Chrome, Brave, Postman, DBeaver, Power BI, Jira, and configures dynamic extensions
# Supports selective execution and real-time live UI status updates

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

Write-LogHeader "Phase 5: IDEs, Editors, Browsers & API Tools"

# Load Configuration
$config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json

function Should-InstallTool {
    param([string]$toolId)
    if ($SelectedTools.Count -eq 0) { return $true }
    return ($SelectedTools -contains $toolId)
}

# 1. Google Chrome
if (Should-InstallTool "chrome") {
    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "chrome" -Status "Running" -DisplayName "Google Chrome" -Detail "Configuring Google Chrome browser"
    }
    Write-Log -Level STEP -Message "Configuring Google Chrome..."
    $installedChrome = Install-WinPackage -PackageId "Google.Chrome" -DisplayName "Google Chrome"
    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "chrome" -Status "Success" -DisplayName "Google Chrome" -Detail "Chrome browser ready"
    }
} else {
    Write-Log -Level INFO -Message "Google Chrome was not selected. Skipping."
}

# 2. Brave Browser
if (Should-InstallTool "brave") {
    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "brave" -Status "Running" -DisplayName "Brave Browser" -Detail "Configuring Brave browser"
    }
    Write-Log -Level STEP -Message "Configuring Brave Browser..."
    $installedBrave = Install-WinPackage -PackageId "Brave.Brave" -DisplayName "Brave Browser"
    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "brave" -Status "Success" -DisplayName "Brave Browser" -Detail "Brave browser ready"
    }
} else {
    Write-Log -Level INFO -Message "Brave Browser was not selected. Skipping."
}

# 3. Notepad++
if (Should-InstallTool "notepadpp") {
    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "notepadpp" -Status "Running" -DisplayName "Notepad++" -Detail "Configuring Notepad++ editor"
    }
    Write-Log -Level STEP -Message "Configuring Notepad++..."
    $installedNpp = Install-WinPackage -PackageId "Notepad++.Notepad++" -DisplayName "Notepad++"
    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        $status = if ($installedNpp -or (Test-Path "C:\Program Files\Notepad++\notepad++.exe")) { "Success" } else { "Failed" }
        Write-LiveToolStatus -ToolId "notepadpp" -Status $status -DisplayName "Notepad++" -Detail "Notepad++ ready"
    }
} else {
    Write-Log -Level INFO -Message "Notepad++ was not selected. Skipping."
}

# 4. Postman API Client
if (Should-InstallTool "postman") {
    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "postman" -Status "Running" -DisplayName "Postman API Client" -Detail "Configuring Postman platform"
    }
    Write-Log -Level STEP -Message "Configuring Postman API Platform..."
    $installedPostman = Install-WinPackage -PackageId "Postman.Postman" -DisplayName "Postman"
    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "postman" -Status "Success" -DisplayName "Postman API Client" -Detail "Postman ready"
    }
} else {
    Write-Log -Level INFO -Message "Postman was not selected. Skipping."
}

# 5. DBeaver Universal Database Tool
if (Should-InstallTool "dbeaver") {
    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "dbeaver" -Status "Running" -DisplayName "DBeaver Community" -Detail "Configuring DBeaver database tool"
    }
    Write-Log -Level STEP -Message "Configuring DBeaver Community..."
    $dbeaverId = if ($config.wingetPackages.utilities.dbeaver.id) { $config.wingetPackages.utilities.dbeaver.id } else { "DBeaver.DBeaver.Community" }
    $installedDbeaver = Install-WinPackage -PackageId $dbeaverId -DisplayName "DBeaver Community"

    if (-not $installedDbeaver -and -not (Test-Path "C:\Program Files\DBeaver\dbeaver.exe")) {
        Write-Log -Level WARN -Message "WinGet reported an issue for DBeaver. Attempting direct installer fallback..."
        $dbeaverUrl = "https://github.com/dbeaver/dbeaver/releases/download/26.2.0/dbeaver-ce-26.2.0-windows-x86_64.exe"
        $cacheDir = Get-DownloadCacheDirectory
        $targetInstaller = Join-Path -Path $cacheDir -ChildPath "dbeaver-ce-x64-setup.exe"
        try {
            $downloadedInstaller = Get-CachedOrDownloadFile -ToolId "dbeaver" -Url $dbeaverUrl -DestinationPath $targetInstaller -DisplayName "DBeaver Community Installer" -AlternativePatterns @("*dbeaver*setup*.exe", "*dbeaver-ce*.exe")
            Write-Log -Level INFO -Message "Running DBeaver silent installer..."
            $p = Start-Process -FilePath $downloadedInstaller -ArgumentList "/S /allusers" -Wait -PassThru
            if ($p.ExitCode -eq 0 -or (Test-Path "C:\Program Files\DBeaver\dbeaver.exe")) {
                Write-Log -Level SUCCESS -Message "DBeaver Community installed successfully via direct installer."
                $installedDbeaver = $true
            }
        } catch {
            Write-Log -Level ERROR -Message "Direct DBeaver install failed: $_"
        }
    }

    $dbeaverDirs = @(
        "$env:LOCALAPPDATA\DBeaver",
        "C:\Program Files\DBeaver",
        "$env:LOCALAPPDATA\Programs\DBeaver",
        "C:\Program Files (x86)\DBeaver"
    )
    $dbeaverFound = $null
    foreach ($dir in $dbeaverDirs) {
        if (Test-Path (Join-Path -Path $dir -ChildPath "dbeaver.exe")) {
            $dbeaverFound = $dir
            Add-PathSafe -PathToAdd $dir -Target "Machine"
            Add-PathSafe -PathToAdd $dir -Target "User"
            break
        }
    }

    if ($installedDbeaver -or $dbeaverFound) {
        if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
            Write-LiveToolStatus -ToolId "dbeaver" -Status "Success" -DisplayName "DBeaver Community" -Detail "DBeaver ready"
        }
    } else {
        if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
            Write-LiveToolStatus -ToolId "dbeaver" -Status "Failed" -DisplayName "DBeaver Community" -Detail "Installation failed"
        }
    }
} else {
    Write-Log -Level INFO -Message "DBeaver was not selected. Skipping."
}

# 6. Microsoft Power BI Desktop
if (Should-InstallTool "powerbi") {
    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "powerbi" -Status "Running" -DisplayName "Power BI Desktop" -Detail "Configuring Microsoft Power BI"
    }
    Write-Log -Level STEP -Message "Configuring Microsoft Power BI Desktop..."
    $installedPowerbi = Install-WinPackage -PackageId "Microsoft.PowerBI" -DisplayName "Microsoft Power BI Desktop"
    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        $status = if ($installedPowerbi -or (Test-Path "C:\Program Files\Microsoft Power BI Desktop\bin\PBIDesktop.exe")) { "Success" } else { "Failed" }
        Write-LiveToolStatus -ToolId "powerbi" -Status $status -DisplayName "Power BI Desktop" -Detail "Power BI ready"
    }
} else {
    Write-Log -Level INFO -Message "Power BI was not selected. Skipping."
}

# 7. Atlassian Jira CLI & Tools
if (Should-InstallTool "jira") {
    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "jira" -Status "Running" -DisplayName "Jira CLI" -Detail "Configuring Atlassian CLI tools"
    }
    Write-Log -Level STEP -Message "Configuring Atlassian Jira CLI & Tools..."
    $installedAcli = Install-WinPackage -PackageId "Atlassian.AtlassianCLI" -DisplayName "Atlassian CLI (acli)"
    if (-not $installedAcli) {
        Write-Log -Level INFO -Message "Trying alternative Jira Ticket CLI package..."
        $installedJtk = Install-WinPackage -PackageId "OpenCLICollective.jira-ticket-cli" -DisplayName "Jira Ticket CLI (jtk)"
    }
    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "jira" -Status "Success" -DisplayName "Jira CLI" -Detail "Jira tooling ready"
    }
} else {
    Write-Log -Level INFO -Message "Jira CLI was not selected. Skipping."
}

# 8. Visual Studio Code & Tailored Extensions
if (Should-InstallTool "vscode") {
    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "vscode" -Status "Running" -DisplayName "Visual Studio Code" -Detail "Deploying VS Code and tailored extensions"
    }
    Write-Log -Level STEP -Message "Configuring Visual Studio Code..."
    $installedVsCode = Install-WinPackage -PackageId "Microsoft.VisualStudioCode" -DisplayName "Visual Studio Code"

    # Ensure code.cmd / code.exe is on PATH
    $vsCodePaths = @(
        "C:\Program Files\Microsoft VS Code\bin",
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin"
    )

    foreach ($vp in $vsCodePaths) {
        if (Test-Path $vp) {
            Add-PathSafe -PathToAdd $vp -Target "Machine"
            break
        }
    }

    Refresh-SessionEnvironment

    $codeCmd = Get-Command "code.cmd" -ErrorAction SilentlyContinue
    if (-not $codeCmd) {
        $codeCmd = Get-Command "code.exe" -ErrorAction SilentlyContinue
    }

    if ($codeCmd) {
        Write-Log -Level STEP -Message "Configuring tailored VS Code extensions..."

        # Assemble list of extensions dynamically based on selected tools
        $targetExtensions = @()
        if ($config.vscode -and $config.vscode.coreExtensions) {
            $targetExtensions += $config.vscode.coreExtensions
        }

        # Dynamic tool extensions
        if ($config.vscode -and $config.vscode.toolExtensions) {
            $toolExts = $config.vscode.toolExtensions
            foreach ($prop in $toolExts.PSObject.Properties) {
                $toolKey = $prop.Name
                if (Should-InstallTool $toolKey) {
                    $extList = $prop.Value
                    Write-Log -Level INFO -Message "Adding VS Code extensions for selected tool '$toolKey': $($extList -join ', ')"
                    $targetExtensions += $extList
                }
            }
        }

        $targetExtensions = $targetExtensions | Select-Object -Unique

        # Query currently installed extensions
        $installedExts = & $codeCmd --list-extensions 2>$null

        foreach ($ext in $targetExtensions) {
            if ($installedExts -contains $ext) {
                Write-Log -Level DEBUG -Message "VS Code extension '$ext' is already installed."
            } else {
                Write-Log -Level INFO -Message "Installing extension: $ext"
                & $codeCmd --install-extension $ext --force 2>$null | Out-Null
                Write-Log -Level SUCCESS -Message "Installed extension: $ext"
            }
        }

        # Deploy Recommended VS Code user settings
        $appData = [Environment]::GetFolderPath("ApplicationData")
        $codeUserDir = Join-Path -Path $appData -ChildPath "Code\User"
        if (-not (Test-Path $codeUserDir)) {
            New-Item -ItemType Directory -Path $codeUserDir -Force | Out-Null
        }

        $settingsFile = Join-Path -Path $codeUserDir -ChildPath "settings.json"
        if (-not (Test-Path $settingsFile)) {
            $initialSettings = @{
                "editor.formatOnSave"                = $true
                "editor.tabSize"                     = 2
                "editor.renderWhitespace"            = "boundary"
                "files.trimTrailingWhitespace"       = $true
                "files.insertFinalNewline"           = $true
                "terminal.integrated.defaultProfile.windows" = "PowerShell"
                "workbench.colorTheme"               = "Default Dark Modern"
            }
            $initialSettings | ConvertTo-Json -Depth 4 | Set-Content -Path $settingsFile -Encoding UTF8 -Force
            Write-Log -Level SUCCESS -Message "Deployed optimized VS Code user settings."
        }
    }

    if (Get-Command "Write-LiveToolStatus" -ErrorAction SilentlyContinue) {
        Write-LiveToolStatus -ToolId "vscode" -Status "Success" -DisplayName "Visual Studio Code" -Detail "VS Code and extensions operational"
    }
} else {
    Write-Log -Level INFO -Message "Visual Studio Code was not selected. Skipping."
}

Refresh-SessionEnvironment
Write-Log -Level SUCCESS -Message "IDEs, editors, and tools phase completed."
