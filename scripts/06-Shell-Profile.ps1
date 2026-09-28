# scripts/06-Shell-Profile.ps1 (Compatibility Wrapper)
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$SelectedTools = @()
)

$targetScript = Join-Path -Path $PSScriptRoot -ChildPath "08-Shell-Profile.ps1"
& $targetScript -SelectedTools $SelectedTools
