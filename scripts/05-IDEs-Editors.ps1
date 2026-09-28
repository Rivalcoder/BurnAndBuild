# scripts/05-IDEs-Editors.ps1 (Compatibility Wrapper)
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "$PSScriptRoot\..\config.json",

    [Parameter(Mandatory = $false)]
    [string[]]$SelectedTools = @()
)

$targetScript = Join-Path -Path $PSScriptRoot -ChildPath "07-IDEs-Editors.ps1"
& $targetScript -ConfigPath $ConfigPath -SelectedTools $SelectedTools
