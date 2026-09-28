# scripts/07-IDEs-Editors.ps1
# Installs VS Code, Notepad++, Chrome, Postman, DBeaver, and configures dynamic VS Code extensions based on selected tools

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "$PSScriptRoot\..\config.json",

    [Parameter(Mandatory = $false)]
    [string[]]$SelectedTools = @()
)

$modulesPath = Join-Path -Path $PSScriptRoot -ChildPath "..\modules"
Import-Module (Join-Path -Path $modulesPath -ChildPath "Logging.psm1") -Force
Import-Module (Join-Path -Path $modulesPath -ChildPath "Environment.psm1") -Force
Import-Module (Join-Path -Path $modulesPath -ChildPath "WinGetHelper.psm1") -Force

Write-LogHeader "Phase 7: IDEs, Editors, Browsers & API Tools"

# Load Configuration
$config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json

function Should-InstallTool {
    param([string]$toolId)
    if ($SelectedTools.Count -eq 0) { return $true }
    return ($SelectedTools -contains $toolId)
}

# 1. Google Chrome
if (Should-InstallTool "chrome") {
    Write-Log -Level STEP -Message "Configuring Google Chrome..."
    Install-WinPackage -PackageId "Google.Chrome" -DisplayName "Google Chrome"
}

# 2. Notepad++
if (Should-InstallTool "notepadpp") {
    Write-Log -Level STEP -Message "Configuring Notepad++..."
    Install-WinPackage -PackageId "Notepad++.Notepad++" -DisplayName "Notepad++"
}

# 3. Postman API Client
if (Should-InstallTool "postman") {
    Write-Log -Level STEP -Message "Configuring Postman API Platform..."
    Install-WinPackage -PackageId "Postman.Postman" -DisplayName "Postman"
}

# 4. DBeaver Universal Database Tool
if (Should-InstallTool "dbeaver") {
    Write-Log -Level STEP -Message "Configuring DBeaver Community..."
    Install-WinPackage -PackageId "DBeaver.DBeaver" -DisplayName "DBeaver Community"
}

# 5. Visual Studio Code & Tailored Extensions
if (Should-InstallTool "vscode") {
    Write-Log -Level STEP -Message "Configuring Visual Studio Code..."
    Install-WinPackage -PackageId "Microsoft.VisualStudioCode" -DisplayName "Visual Studio Code"

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
                "editor.insertSpaces"                = $true
                "files.eol"                          = "`n"
                "files.trimTrailingWhitespace"       = $true
                "terminal.integrated.defaultProfile.windows" = "PowerShell"
                "git.autofetch"                      = $true
                "git.enableSmartCommit"              = $true
                "workbench.startupEditor"            = "none"
            }
            $initialSettings | ConvertTo-Json -Depth 5 | Set-Content -Path $settingsFile -Encoding UTF8
            Write-Log -Level SUCCESS -Message "Deployed optimized VS Code user settings."
        }
    } else {
        Write-Log -Level WARN -Message "code command not yet in current session. Extensions will be installed on first launch."
    }
} else {
    Write-Log -Level INFO -Message "VS Code was not selected. Skipping."
}

Refresh-SessionEnvironment
Write-Log -Level SUCCESS -Message "IDEs, editors, and tools phase completed."
