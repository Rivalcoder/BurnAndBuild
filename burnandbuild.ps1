<#
.SYNOPSIS
    BurnAndBuild - Master Root Entrypoint (Windows / PowerShell)
.DESCRIPTION
    Convenience wrapper that passes parameters directly to scripts/bootstrap.ps1.
    Usage:
      .\burnandbuild.ps1
      .\burnandbuild.ps1 -Preset ai
      .\burnandbuild.ps1 -Full -NoGui
      .\burnandbuild.ps1 -BaseOnly
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string[]]$Tools = @(),

    [Parameter(Mandatory = $false, Position = 1)]
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

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$bootstrapScript = Join-Path -Path $scriptDir -ChildPath "scripts\bootstrap.ps1"

if (-not (Test-Path $bootstrapScript)) {
    Write-Error "bootstrap.ps1 not found at $bootstrapScript"
    exit 1
}

& $bootstrapScript @PSBoundParameters
