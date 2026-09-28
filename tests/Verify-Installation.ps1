# tests/Verify-Installation.ps1
# Automated validation smoke test for disposable Windows dev environment
# Dynamically verifies only the components selected by the user

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, ValueFromRemainingArguments = $true)]
    [string[]]$SelectedTools = @()
)

# Flatten comma-separated values
$SelectedTools = @(
    foreach ($item in $SelectedTools) {
        $item -split '[\s,]+' | Where-Object { $_ -ne "" }
    }
)

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $scriptDir) { $scriptDir = Join-Path (Get-Location).Path "tests" }
$rootDir = Split-Path -Path $scriptDir -Parent
$modulesPath = Join-Path -Path $rootDir -ChildPath "modules"
Import-Module (Join-Path -Path $modulesPath -ChildPath "Logging.psm1") -Global -DisableNameChecking
Import-Module (Join-Path -Path $modulesPath -ChildPath "Environment.psm1") -DisableNameChecking

Refresh-SessionEnvironment

Write-LogHeader "BurnAndBuild - Environment Verification & Health Check"

$results = @()

function Test-Component {
    param(
        [string]$Name,
        [scriptblock]$CheckBlock
    )

    try {
        $detail = & $CheckBlock
        return [PSCustomObject]@{
            Component = $Name
            Status    = "PASS"
            Details   = $detail
        }
    } catch {
        return [PSCustomObject]@{
            Component = $Name
            Status    = "FAIL"
            Details   = $_.Exception.Message
        }
    }
}

function Should-Verify {
    param([string]$toolId)
    if ($SelectedTools.Count -eq 0) { return $true }
    return ($SelectedTools -contains $toolId)
}

# 1. Base OS Settings
if (Should-Verify "baseWindows") {
    $results += Test-Component "Win32 Long Paths" {
        $val = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -ErrorAction SilentlyContinue).LongPathsEnabled
        if ($val -eq 1) { "Enabled (1)" } else { throw "Disabled ($val)" }
    }

    $results += Test-Component "Developer Mode" {
        $val = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense
        if ($val -eq 1) { "Enabled (1)" } else { throw "Disabled ($val)" }
    }
}

# 2. CLI Tools & Git
if (Should-Verify "gitCli") {
    $results += Test-Component "Git" {
        $v = & git --version 2>$null
        if ($v) { $v.Trim() } else { throw "git.exe not found on PATH" }
    }

    $results += Test-Component "7-Zip" {
        $cmd = Get-Command "7z.exe" -ErrorAction SilentlyContinue
        if ($cmd) { "Found at $($cmd.Source)" } else { throw "7z.exe not found on PATH" }
    }

    $results += Test-Component "PowerShell 7" {
        $cmd = Get-Command "pwsh.exe" -ErrorAction SilentlyContinue
        if ($cmd) {
            $v = & pwsh -v 2>$null
            $v.Trim()
        } else {
            throw "pwsh.exe not found on PATH"
        }
    }
}

# 3. Runtimes: Java JDK 17
if (Should-Verify "java") {
    $results += Test-Component "Java (JDK 17)" {
        if (-not $env:JAVA_HOME) { throw "JAVA_HOME is not set" }
        if (-not (Test-Path "$env:JAVA_HOME\bin\java.exe")) { throw "java.exe not found in JAVA_HOME" }
        $v = & "$env:JAVA_HOME\bin\java.exe" -version 2>&1 | Select-Object -First 1
        "$($v.ToString().Trim()) (JAVA_HOME=$env:JAVA_HOME)"
    }
}

# 4. Runtimes: Node.js & npm
if (Should-Verify "node") {
    $results += Test-Component "Node.js" {
        $v = & node -v 2>$null
        if ($v) { $v.Trim() } else { throw "node.exe not found on PATH" }
    }

    $results += Test-Component "npm" {
        $v = & npm -v 2>$null
        if ($v) { "v$($v.Trim())" } else { throw "npm not found on PATH" }
    }
}

# 5. Runtimes: Python & uv
if (Should-Verify "python") {
    $results += Test-Component "Python" {
        $v = & python --version 2>$null
        if ($v) { $v.Trim() } else { throw "python.exe not found on PATH" }
    }

    $results += Test-Component "uv Toolchain" {
        $v = & uv --version 2>$null
        if ($v) { $v.Trim() } else { throw "uv not found on PATH" }
    }
}

# 6. Runtimes: Gradle
if (Should-Verify "gradle") {
    $results += Test-Component "Gradle" {
        if (-not $env:GRADLE_HOME -and -not (Get-Command "gradle.bat" -ErrorAction SilentlyContinue)) {
            throw "Gradle or GRADLE_HOME not found"
        }
        $v = & gradle -v 2>$null | Where-Object { $_ -match "^Gradle\s+\d+" } | Select-Object -First 1
        if ($v) { $v.Trim() } else { "Gradle detected in GRADLE_HOME: $env:GRADLE_HOME" }
    }
}

# 7. Mobile: Android SDK
if (Should-Verify "android") {
    $results += Test-Component "Android SDK" {
        if (-not $env:ANDROID_HOME) { throw "ANDROID_HOME is not set" }
        $adb = Join-Path -Path $env:ANDROID_HOME -ChildPath "platform-tools\adb.exe"
        if (Test-Path $adb) {
            $v = & $adb version 2>$null | Select-Object -First 1
            "$v (Root=$env:ANDROID_HOME)"
        } else {
            throw "adb.exe not found under $env:ANDROID_HOME\platform-tools"
        }
    }
}

# 8. Mobile: Flutter SDK
if (Should-Verify "flutter") {
    $results += Test-Component "Flutter SDK" {
        $flutter = Get-Command "flutter.bat" -ErrorAction SilentlyContinue
        if (-not $flutter) { $flutter = Get-Command "flutter" -ErrorAction SilentlyContinue }
        if (-not $flutter -and (Test-Path "C:\Tools\flutter\bin\flutter.bat")) {
            $flutter = "C:\Tools\flutter\bin\flutter.bat"
        }
        if ($flutter) {
            $v = & flutter --version 2>$null | Select-Object -First 1
            if ($v) { $v.Trim() } else { "Flutter detected at C:\Tools\flutter" }
        } else {
            throw "flutter.bat not found on PATH or C:\Tools\flutter"
        }
    }
}

# 9. Containers: Docker Desktop
if (Should-Verify "docker") {
    $results += Test-Component "Docker" {
        $docker = Get-Command "docker.exe" -ErrorAction SilentlyContinue
        if (-not $docker -and (Test-Path "C:\Program Files\Docker\Docker\resources\bin\docker.exe")) {
            $docker = "C:\Program Files\Docker\Docker\resources\bin\docker.exe"
        }
        if ($docker) {
            $v = & docker --version 2>$null
            if ($v) { $v.Trim() } else { "Docker CLI found on PATH" }
        } elseif (Test-Path "C:\Program Files\Docker\Docker\Docker Desktop.exe") {
            "Docker Desktop installed (Reboot or start app to run daemon)"
        } else {
            throw "Docker executable not found on PATH or Program Files"
        }
    }
}

# 10. IDEs & Editors: VS Code
if (Should-Verify "vscode") {
    $results += Test-Component "VS Code" {
        $code = Get-Command "code.cmd" -ErrorAction SilentlyContinue
        if (-not $code) { $code = Get-Command "code.exe" -ErrorAction SilentlyContinue }
        if ($code) {
            $v = & $code --version 2>$null | Select-Object -First 1
            "v$v"
        } else {
            throw "VS Code CLI (code) not found on PATH"
        }
    }
}

# 11. IDEs & Editors: Notepad++
if (Should-Verify "notepadpp") {
    $results += Test-Component "Notepad++" {
        $nppPaths = @("C:\Program Files\Notepad++\notepad++.exe", "C:\Program Files (x86)\Notepad++\notepad++.exe")
        $found = $nppPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($found) {
            "Installed at: $found"
        } else {
            throw "Notepad++ executable not found in Program Files"
        }
    }
}

# 12. Browsers: Google Chrome
if (Should-Verify "chrome") {
    $results += Test-Component "Google Chrome" {
        $chromePaths = @("C:\Program Files\Google\Chrome\Application\chrome.exe", "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe")
        $found = $chromePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($found) {
            "Installed at: $found"
        } else {
            throw "chrome.exe not found in standard directories"
        }
    }
}

# 13. API: Postman
if (Should-Verify "postman") {
    $results += Test-Component "Postman" {
        $postmanPath = Join-Path -Path $env:LOCALAPPDATA -ChildPath "Postman\app-*\Postman.exe"
        $found = Get-Item -Path $postmanPath -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            "Installed at: $($found.FullName)"
        } else {
            throw "Postman app not found in LocalAppData"
        }
    }
}

# 14. Database: DBeaver
if (Should-Verify "dbeaver") {
    $results += Test-Component "DBeaver" {
        $dbeaver = "C:\Program Files\DBeaver\dbeaver.exe"
        if (Test-Path $dbeaver) {
            "Installed at: $dbeaver"
        } else {
            throw "DBeaver executable not found at $dbeaver"
        }
    }
}

# 15. AI: Antigravity CLI
if (Should-Verify "antigravityCli") {
    $results += Test-Component "Antigravity CLI" {
        $cmd = Get-Command "agy.exe" -ErrorAction SilentlyContinue
        if (-not $cmd) { $cmd = Get-Command "agy" -ErrorAction SilentlyContinue }
        if (-not $cmd -and (Test-Path "C:\Tools\antigravity-cli\agy.exe")) {
            $cmd = "C:\Tools\antigravity-cli\agy.exe"
        }
        if ($cmd) {
            $v = & agy --version 2>$null | Select-Object -First 1
            if ($v) { $v.Trim() } else { "Antigravity CLI detected on PATH" }
        } else {
            throw "agy command not found on PATH or C:\Tools\antigravity-cli"
        }
    }
}

# 16. AI: Antigravity IDE
if (Should-Verify "antigravityIde") {
    $results += Test-Component "Antigravity IDE" {
        $ideCmd = Get-Command "antigravity-ide.cmd" -ErrorAction SilentlyContinue
        if (-not $ideCmd) { $ideCmd = Get-Command "antigravity-ide" -ErrorAction SilentlyContinue }
        $candidates = @(
            "$env:LOCALAPPDATA\Programs\Antigravity IDE\Antigravity IDE.exe",
            "C:\Program Files\Antigravity IDE\Antigravity IDE.exe"
        )
        $found = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($found) {
            "Installed at: $found"
        } elseif ($ideCmd) {
            "Detected CLI at: $($ideCmd.Source)"
        } else {
            throw "Antigravity IDE executable not found in Program Files or LocalAppData"
        }
    }
}

# 17. AI: Cursor AI Editor
if (Should-Verify "cursor") {
    $results += Test-Component "Cursor Editor" {
        $cursorCmd = Get-Command "cursor.cmd" -ErrorAction SilentlyContinue
        if (-not $cursorCmd) { $cursorCmd = Get-Command "cursor" -ErrorAction SilentlyContinue }
        $cursorExe = "$env:LOCALAPPDATA\Programs\cursor\Cursor.exe"
        if (Test-Path $cursorExe) {
            "Installed at: $cursorExe"
        } elseif ($cursorCmd) {
            "Found CLI on PATH: $($cursorCmd.Source)"
        } else {
            throw "Cursor executable not found on PATH or LocalAppData"
        }
    }
}

# 18. AI: OpenAI Codex CLI
if (Should-Verify "codex") {
    $results += Test-Component "Codex CLI" {
        $codexCmd = Get-Command "codex.exe" -ErrorAction SilentlyContinue
        if (-not $codexCmd) { $codexCmd = Get-Command "codex" -ErrorAction SilentlyContinue }
        if (-not $codexCmd -and (Test-Path "C:\Tools\codex\codex.exe")) {
            $codexCmd = "C:\Tools\codex\codex.exe"
        }
        if ($codexCmd) {
            $v = & codex --version 2>$null | Select-Object -First 1
            if ($v) { $v.Trim() } else { "Codex CLI found on PATH" }
        } else {
            throw "codex.exe not found on PATH or C:\Tools\codex"
        }
    }
}

# 19. Browsers: Brave Browser
if (Should-Verify "brave") {
    $results += Test-Component "Brave Browser" {
        $bravePaths = @(
            "C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe",
            "C:\Program Files (x86)\BraveSoftware\Brave-Browser\Application\brave.exe",
            "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\Application\brave.exe"
        )
        $found = $bravePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($found) {
            "Installed at: $found"
        } else {
            throw "brave.exe not found in standard directories"
        }
    }
}

# 20. Analytics: Microsoft Power BI Desktop
if (Should-Verify "powerbi") {
    $results += Test-Component "Power BI Desktop" {
        $pbiPaths = @(
            "C:\Program Files\Microsoft Power BI Desktop\bin\PBIDesktop.exe",
            "C:\Program Files (x86)\Microsoft Power BI Desktop\bin\PBIDesktop.exe"
        )
        $found = $pbiPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($found) {
            "Installed at: $found"
        } else {
            $pbiCmd = Get-Command "PBIDesktop.exe" -ErrorAction SilentlyContinue
            if ($pbiCmd) { "Detected at: $($pbiCmd.Source)" } else { throw "PBIDesktop.exe not found in Program Files" }
        }
    }
}

# 21. Project Management: Atlassian Jira CLI & Tools
if (Should-Verify "jira") {
    $results += Test-Component "Jira CLI / Tools" {
        $cmd = Get-Command "acli.exe" -ErrorAction SilentlyContinue
        if (-not $cmd) { $cmd = Get-Command "acli" -ErrorAction SilentlyContinue }
        if (-not $cmd) { $cmd = Get-Command "jtk.exe" -ErrorAction SilentlyContinue }
        if (-not $cmd) { $cmd = Get-Command "jira.exe" -ErrorAction SilentlyContinue }
        if ($cmd) {
            "Detected CLI: $($cmd.Name) at $($cmd.Source)"
        } else {
            $codeCmd = Get-Command "code.cmd" -ErrorAction SilentlyContinue
            if (-not $codeCmd) { $codeCmd = Get-Command "code.exe" -ErrorAction SilentlyContinue }
            if ($codeCmd) {
                $exts = & $codeCmd --list-extensions 2>$null
                if ($exts -contains "Atlassian.atlascode") {
                    "Atlassian VS Code extension installed (Atlassian.atlascode)"
                } else {
                    throw "acli/jira CLI or Atlassian VS Code extension not found"
                }
            } else {
                throw "acli/jira CLI not found on PATH"
            }
        }
    }
}

# Print Summary Table
Write-Host ""
Write-Host "========================= VALIDATION SUMMARY =========================" -ForegroundColor Cyan
foreach ($r in $results) {
    $color = if ($r.Status -eq "PASS") { "Green" } else { "Red" }
    $comp = $r.Component.PadRight(22)
    $stat = "[$($r.Status)]".PadRight(8)
    Write-Host "$comp " -NoNewline -ForegroundColor White
    Write-Host "$stat " -NoNewline -ForegroundColor $color
    Write-Host "$($r.Details)" -ForegroundColor DarkGray
}
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

$failed = $results | Where-Object { $_.Status -eq "FAIL" }
if ($failed.Count -gt 0) {
    Write-Log -Level WARN -Message "$($failed.Count) component checks failed or require a shell reload."
} else {
    Write-Log -Level SUCCESS -Message "All ($($results.Count)) selected component checks PASSED successfully!"
}
