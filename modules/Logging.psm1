# modules/Logging.psm1
# Enterprise-grade logging module with color output and persistent file logging

[CmdletBinding()]
param()

$global:VmSetupLogFile = $null

function Initialize-Logger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$LogDirectory = "C:\Logs\VM-Setup",
        [Parameter(Mandatory = $false)]
        [string]$Prefix = "vm-setup"
    )

    if (-not (Test-Path -Path $LogDirectory)) {
        New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $global:VmSetupLogFile = Join-Path -Path $LogDirectory -ChildPath "$Prefix-$timestamp.log"

    Write-Log -Level INFO -Message "Logging initialized. Log file: $global:VmSetupLogFile"
}

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "STEP", "DEBUG")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $formattedLog = "[$timestamp] [$Level] $Message"

    # Console Colors
    $color = switch ($Level) {
        "INFO"    { "Cyan" }
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
        "SUCCESS" { "Green" }
        "STEP"    { "Magenta" }
        "DEBUG"   { "DarkGray" }
        Default   { "White" }
    }

    Write-Host "[$timestamp] " -NoNewline -ForegroundColor DarkGray
    Write-Host "[$Level] " -NoNewline -ForegroundColor $color
    Write-Host "$Message" -ForegroundColor White

    # File Logging
    if ($global:VmSetupLogFile) {
        try {
            Add-Content -Path $global:VmSetupLogFile -Value $formattedLog -ErrorAction SilentlyContinue
        } catch {
            # Suppress log writing failure to avoid interrupting main flow
        }
    }
}

function Write-LogHeader {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Title)

    $border = "=" * 80
    Write-Host ""
    Write-Host $border -ForegroundColor DarkCyan
    Write-Log -Level STEP -Message $Title
    Write-Host $border -ForegroundColor DarkCyan
}

Export-ModuleMember -Function Initialize-Logger, Write-Log, Write-LogHeader
