# scripts/07-Persistence-Setup.ps1 (Compatibility Wrapper)
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "$PSScriptRoot\..\config.json",

    [Parameter(Mandatory = $false)]
    [string]$GitUserName = "",

    [Parameter(Mandatory = $false)]
    [string]$GitUserEmail = "",

    [Parameter(Mandatory = $false)]
    [string]$PreferredDataDrive = "",

    [Parameter(Mandatory = $false)]
    [string[]]$SelectedTools = @()
)

$targetScript = Join-Path -Path $PSScriptRoot -ChildPath "09-Persistence-Setup.ps1"
& $targetScript -ConfigPath $ConfigPath -GitUserName $GitUserName -GitUserEmail $GitUserEmail -PreferredDataDrive $PreferredDataDrive -SelectedTools $SelectedTools
