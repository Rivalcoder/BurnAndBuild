# scripts/09-Persistence-Setup.ps1
# Configures external workspace data persistence, cache redirection, Git identity, and SSH keys

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

$modulesPath = Join-Path -Path $PSScriptRoot -ChildPath "..\modules"
Import-Module (Join-Path -Path $modulesPath -ChildPath "Logging.psm1") -Force
Import-Module (Join-Path -Path $modulesPath -ChildPath "Environment.psm1") -Force

Write-LogHeader "Phase 9: Data Persistence, Cache Redirection, and Identity"

# Load Configuration
$config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json

# 1. Detect or Configure Workspace Storage
$workspaceDir = $config.settings.workspaceRoot

# Check if a secondary detached data volume is attached (e.g. D:\ or E:\)
if ($PreferredDataDrive -and (Test-Path "$($PreferredDataDrive):\")) {
    $workspaceDir = "$($PreferredDataDrive):\Workspace"
    Write-Log -Level SUCCESS -Message "Using specified secondary data drive: $workspaceDir"
} else {
    # Scan for secondary attached data volumes
    $secondaryVolumes = Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveLetter -ne 'C' -and $_.DriveType -eq 'Fixed' }
    if ($secondaryVolumes) {
        $firstSecondary = ($secondaryVolumes | Select-Object -First 1).DriveLetter
        Write-Log -Level INFO -Message "Detected attached secondary persistent volume at drive $($firstSecondary):\"
        $candidateWorkspace = "$($firstSecondary):\Workspace"
        if (-not (Test-Path $candidateWorkspace)) {
            New-Item -ItemType Directory -Path $candidateWorkspace -Force | Out-Null
        }
        $workspaceDir = $candidateWorkspace
    }
}

if (-not (Test-Path $workspaceDir)) {
    New-Item -ItemType Directory -Path $workspaceDir -Force | Out-Null
}
Write-Log -Level SUCCESS -Message "Primary workspace location established at: $workspaceDir"

# 2. Redirect Heavy Caches to Workspace/Dedicated Disk (Prevents C: bloat & preserves build artifacts)
$cacheRootDir = Join-Path -Path $workspaceDir -ChildPath ".cache"
if (-not (Test-Path $cacheRootDir)) {
    New-Item -ItemType Directory -Path $cacheRootDir -Force | Out-Null
}

$gradleCache = Join-Path -Path $cacheRootDir -ChildPath ".gradle"
if (-not (Test-Path $gradleCache)) {
    New-Item -ItemType Directory -Path $gradleCache -Force | Out-Null
}
Set-EnvironmentVariableSafe -Name "GRADLE_USER_HOME" -Value $gradleCache -Target "Machine"

$pipCache = Join-Path -Path $cacheRootDir -ChildPath "pip"
if (-not (Test-Path $pipCache)) {
    New-Item -ItemType Directory -Path $pipCache -Force | Out-Null
}
Set-EnvironmentVariableSafe -Name "PIP_CACHE_DIR" -Value $pipCache -Target "Machine"

$uvCache = Join-Path -Path $cacheRootDir -ChildPath "uv"
if (-not (Test-Path $uvCache)) {
    New-Item -ItemType Directory -Path $uvCache -Force | Out-Null
}
Set-EnvironmentVariableSafe -Name "UV_CACHE_DIR" -Value $uvCache -Target "Machine"

# Flutter cache redirection
$flutterCache = Join-Path -Path $cacheRootDir -ChildPath "flutter"
if (-not (Test-Path $flutterCache)) {
    New-Item -ItemType Directory -Path $flutterCache -Force | Out-Null
}
Set-EnvironmentVariableSafe -Name "PUB_CACHE" -Value (Join-Path -Path $flutterCache -ChildPath ".pub-cache") -Target "Machine"

Refresh-SessionEnvironment
Write-Log -Level SUCCESS -Message "Redirected build caches (.gradle, pip, uv, pub-cache) to: $cacheRootDir"

# 3. Configure Git Identity (if provided)
if ($GitUserName -and $GitUserEmail) {
    if (Get-Command "git.exe" -ErrorAction SilentlyContinue) {
        Write-Log -Level INFO -Message "Applying provided Git identity..."
        & git config --global user.name "$GitUserName"
        & git config --global user.email "$GitUserEmail"
        Write-Log -Level SUCCESS -Message "Git identity configured: $GitUserName <$GitUserEmail>"
    }
}

# 4. Generate SSH Key Pair (if none exists)
$sshDir = Join-Path -Path $env:USERPROFILE -ChildPath ".ssh"
$ed25519Key = Join-Path -Path $sshDir -ChildPath "id_ed25519"

if (-not (Test-Path $ed25519Key)) {
    if (Get-Command "ssh-keygen.exe" -ErrorAction SilentlyContinue) {
        if (-not (Test-Path $sshDir)) {
            New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
        }
        $comment = if ($GitUserEmail) { $GitUserEmail } else { "vm-dev-key" }
        Write-Log -Level INFO -Message "Generating fresh ed25519 SSH keypair..."
        & ssh-keygen -t ed25519 -C $comment -f $ed25519Key -N "" -q
        Write-Log -Level SUCCESS -Message "Generated SSH key at: $ed25519Key"
        if (Test-Path "$ed25519Key.pub") {
            $pub = Get-Content -Path "$ed25519Key.pub" -Raw
            Write-Log -Level INFO -Message "Public Key: $($pub.Trim())"
        }
    }
} else {
    Write-Log -Level INFO -Message "SSH keypair already present at: $ed25519Key"
}

Write-Log -Level SUCCESS -Message "Data persistence and workspace configuration completed."
