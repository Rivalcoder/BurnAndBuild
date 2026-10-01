<#
.SYNOPSIS
    BurnAndBuild - Master CLI Entrypoint
.DESCRIPTION
    Direct wrapper to bootstrap.ps1 for running BurnAndBuild on Windows and PowerShell Core.
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

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$bootstrapScript = Join-Path -Path $scriptDir -ChildPath "bootstrap.ps1"

& $bootstrapScript @PSBoundParameters
