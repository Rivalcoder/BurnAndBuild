# modules/Environment.psm1
# Idempotent Environment Variable and PATH Management

[CmdletBinding()]
param()

if (-not (Get-Command "Write-Log" -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "Logging.psm1") -Global
}

function Set-EnvironmentVariableSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Value,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Machine", "User", "Process")]
        [string]$Target = "Machine"
    )

    try {
        $existing = [System.Environment]::GetEnvironmentVariable($Name, $Target)
        if ($existing -ne $Value) {
            [System.Environment]::SetEnvironmentVariable($Name, $Value, $Target)
            Write-Log -Level SUCCESS -Message "Set $Target environment variable '$Name' = '$Value'"
        } else {
            Write-Log -Level DEBUG -Message "Environment variable '$Name' already matches target value."
        }

        # Also update current process session immediately
        [System.Environment]::SetEnvironmentVariable($Name, $Value, "Process")
    } catch {
        Write-Log -Level ERROR -Message "Failed to set environment variable '$Name': $_"
        throw $_
    }
}

function Add-PathSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathToAdd,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Machine", "User")]
        [string]$Target = "Machine"
    )

    try {
        # Normalize path
        $cleanPath = $PathToAdd.TrimEnd('\')
        if (-not (Test-Path -Path $cleanPath)) {
            Write-Log -Level WARN -Message "Path to add does not exist yet: '$cleanPath'. Adding to PATH anyway."
        }

        # Retrieve current PATH from Registry
        $currentPath = [System.Environment]::GetEnvironmentVariable("Path", $Target)
        $pathList = if ([string]::IsNullOrWhiteSpace($currentPath)) { @() } else { $currentPath -split ';' | Where-Object { $_ -ne '' } }

        # Case-insensitive comparison
        $alreadyPresent = $pathList | Where-Object { $_.TrimEnd('\') -like $cleanPath }

        if (-not $alreadyPresent) {
            $newPath = ($pathList + $cleanPath) -join ';'
            [System.Environment]::SetEnvironmentVariable("Path", $newPath, $Target)
            Write-Log -Level SUCCESS -Message "Added '$cleanPath' to $Target PATH."
        } else {
            Write-Log -Level DEBUG -Message "'$cleanPath' is already present in $Target PATH."
        }

        # Update current process PATH
        $processPaths = ($env:Path -split ';' | Where-Object { $_ -ne '' })
        if (-not ($processPaths | Where-Object { $_.TrimEnd('\') -like $cleanPath })) {
            $env:Path = "$env:Path;$cleanPath"
            Write-Log -Level DEBUG -Message "Appended '$cleanPath' to current process PATH."
        }
    } catch {
        Write-Log -Level ERROR -Message "Failed to add '$PathToAdd' to $Target PATH: $_"
        throw $_
    }
}

function Refresh-SessionEnvironment {
    [CmdletBinding()]
    param()

    Write-Log -Level INFO -Message "Refreshing environment variables for the current PowerShell session..."

    # Refresh Machine and User vars
    foreach ($level in "Machine", "User") {
        [System.Environment]::GetEnvironmentVariables($level).GetEnumerator() | ForEach-Object {
            if ($_.Key -notmatch "^(?i:Path)$") {
                [System.Environment]::SetEnvironmentVariable($_.Key, $_.Value, "Process")
            }
        }
    }

    # Reconstruct PATH: Machine + User
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $parts = @()
    if ($machinePath) { $parts += ($machinePath -split ';') }
    if ($userPath) { $parts += ($userPath -split ';') }
    $combined = $parts | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
    $env:Path = $combined -join ';'

    Write-Log -Level SUCCESS -Message "Current session environment and PATH refreshed successfully."
}

Export-ModuleMember -Function Set-EnvironmentVariableSafe, Add-PathSafe, Refresh-SessionEnvironment
