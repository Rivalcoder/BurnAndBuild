# modules/ProcessHelper.psm1
# Process execution helper with logging, error capture, and timeouts

[CmdletBinding()]
param()

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "Logging.psm1") -Force

function Invoke-SafeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [string[]]$ArgumentList = @(),

        [Parameter(Mandatory = $false)]
        [string]$WorkingDirectory = (Get-Location).Path,

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 600,

        [Parameter(Mandatory = $false)]
        [switch]$IgnoreExitCode
    )

    Write-Log -Level DEBUG -Message "Executing: $FilePath $($ArgumentList -join ' ')"

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = ($ArgumentList -join ' ')
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi

    $stdoutBuilder = New-Object System.Text.StringBuilder
    $stderrBuilder = New-Object System.Text.StringBuilder

    $outHandler = {
        if (-not [string]::IsNullOrEmpty($EventArgs.Data)) {
            [void]$stdoutBuilder.AppendLine($EventArgs.Data)
        }
    }
    $errHandler = {
        if (-not [string]::IsNullOrEmpty($EventArgs.Data)) {
            [void]$stderrBuilder.AppendLine($EventArgs.Data)
        }
    }

    $outEvent = Register-ObjectEvent -InputObject $process -EventName 'OutputDataReceived' -Action $outHandler
    $errEvent = Register-ObjectEvent -InputObject $process -EventName 'ErrorDataReceived' -Action $errHandler

    try {
        [void]$process.Start()
        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()

        $exited = $process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $exited) {
            $process.Kill()
            throw "Process '$FilePath' timed out after $TimeoutSeconds seconds and was terminated."
        }

        # Ensure all async buffer is drained
        $process.WaitForExit()

        $stdout = $stdoutBuilder.ToString().Trim()
        $stderr = $stderrBuilder.ToString().Trim()
        $exitCode = $process.ExitCode

        if ($exitCode -ne 0 -and -not $IgnoreExitCode) {
            Write-Log -Level WARN -Message "Command '$FilePath' exited with code $exitCode."
            if ($stderr) {
                Write-Log -Level DEBUG -Message "Stderr: $stderr"
            }
        }

        return [PSCustomObject]@{
            ExitCode = $exitCode
            StandardOutput = $stdout
            StandardError = $stderr
            Success = ($exitCode -eq 0)
        }
    } finally {
        Unregister-Event -SourceIdentifier $outEvent.Name -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier $errEvent.Name -ErrorAction SilentlyContinue
        $process.Dispose()
    }
}

Export-ModuleMember -Function Invoke-SafeCommand
