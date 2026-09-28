# modules/ToolSelector.psm1
# Interactive Tool Selector for Disposable Windows Dev VM Setup
# Supports both Modern WPF Graphical Checklist & Interactive Console Fallback

[CmdletBinding()]
param()

$modulesPath = $PSScriptRoot
if (-not (Get-Command "Write-Log" -ErrorAction SilentlyContinue)) {
    $logPath = Join-Path -Path $modulesPath -ChildPath "Logging.psm1"
    if (Test-Path $logPath) {
        Import-Module $logPath -Global -DisableNameChecking
    }
}

function Get-ToolCatalog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath = ""
    )

    if (-not $ConfigPath) {
        $parent = if ($PSScriptRoot) { Split-Path -Path $PSScriptRoot -Parent } else { (Get-Location).Path }
        $ConfigPath = Join-Path -Path $parent -ChildPath "config.json"
    }

    if (-not (Test-Path $ConfigPath)) {
        if (Test-Path "config.json") {
            $ConfigPath = (Resolve-Path "config.json").Path
        } else {
            throw "Configuration file not found at: $ConfigPath"
        }
    }

    $raw = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json
    return $raw
}

function Show-ToolSelectionGui {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Config
    )

    try {
        Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase -ErrorAction Stop
    } catch {
        Write-Log -Level WARN -Message "WPF assembly not available. Falling back to Console selector."
        return $null
    }

    $tools = $Config.selectableTools
    $presets = $Config.presets

    # Clean, robust XAML without mojibake-prone multi-byte emojis
    $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="BurnAndBuild - Dev Environment Provisioner"
        Height="820" Width="860" MinHeight="680" MinWidth="740"
        WindowStartupLocation="CenterScreen"
        Background="#0F172A" Foreground="#F8FAFC"
        FontFamily="Segoe UI, Segoe UI Variable, sans-serif">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Padding" Value="12,6"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Cursor" Value="Hand"/>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="FontSize" Value="13.5"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Margin" Value="0,2,0,2"/>
        </Style>
    </Window.Resources>

    <Grid Margin="18">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/> <!-- Header -->
            <RowDefinition Height="Auto"/> <!-- Presets -->
            <RowDefinition Height="*"/>    <!-- Scrollable Checklist -->
            <RowDefinition Height="Auto"/> <!-- Footer / Actions -->
        </Grid.RowDefinitions>

        <!-- Header -->
        <Border Grid.Row="0" Background="#1E293B" CornerRadius="8" Padding="16,12" Margin="0,0,0,12" BorderBrush="#334155" BorderThickness="1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0">
                    <TextBlock Text="BurnAndBuild Provisioner" FontSize="19" FontWeight="Bold" Foreground="#38BDF8"/>
                    <TextBlock Text="Select developer tools, runtimes, and frameworks to build on this VM:"
                               FontSize="12.5" Foreground="#CBD5E1" Margin="0,3,0,0" TextWrapping="Wrap"/>
                </StackPanel>
                <Border Grid.Column="1" Background="#0F172A" BorderBrush="#334155" BorderThickness="1" CornerRadius="6" Padding="12,6" VerticalAlignment="Center">
                    <TextBlock Name="TxtSummaryCount" Text="Selected: 0 tools" FontSize="12.5" FontWeight="Bold" Foreground="#4ADE80"/>
                </Border>
            </Grid>
        </Border>

        <!-- Presets Bar -->
        <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,10">
            <TextBlock Text="Presets:" VerticalAlignment="Center" Foreground="#94A3B8" FontWeight="Bold" FontSize="12" Margin="0,0,8,0"/>
            <Button Name="BtnPresetAi" Content="AI &amp; Agents" Background="#1E293B" Foreground="#C084FC" BorderBrush="#A855F7" Margin="0,0,6,0"/>
            <Button Name="BtnPresetMobile" Content="Mobile / Flutter" Background="#1E293B" Foreground="#FBBF24" BorderBrush="#F59E0B" Margin="0,0,6,0"/>
            <Button Name="BtnPresetWeb" Content="Full-Stack Web" Background="#1E293B" Foreground="#60A5FA" BorderBrush="#3B82F6" Margin="0,0,6,0"/>
            <Button Name="BtnPresetDevops" Content="Docker &amp; DevOps" Background="#1E293B" Foreground="#2DD4BF" BorderBrush="#0D9488" Margin="0,0,6,0"/>
            <Button Name="BtnSelectAll" Content="Select All" Background="#1E293B" Foreground="#4ADE80" BorderBrush="#22C55E" Margin="0,0,6,0"/>
            <Button Name="BtnClearAll" Content="Clear All" Background="#1E293B" Foreground="#94A3B8" BorderBrush="#64748B"/>
        </StackPanel>

        <!-- Checklist Scroll Area -->
        <Border Grid.Row="2" Background="#0F172A" CornerRadius="8" BorderBrush="#334155" BorderThickness="1" Padding="10">
            <ScrollViewer VerticalScrollBarVisibility="Auto">
                <StackPanel Name="PnlCategories" Margin="0,0,6,0">
                    <!-- Tool Cards populated dynamically in code -->
                </StackPanel>
            </ScrollViewer>
        </Border>

        <!-- Footer / Start Button -->
        <Border Grid.Row="3" Background="#1E293B" CornerRadius="8" Padding="14,10" Margin="0,10,0,0" BorderBrush="#334155" BorderThickness="1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                    <TextBlock Text="Idempotent: Already installed tools will be verified and safely preserved." FontSize="11" Foreground="#94A3B8"/>
                </StackPanel>

                <Button Name="BtnCancel" Grid.Column="1" Content="Cancel" Background="#1E293B" Foreground="#F87171"
                        BorderBrush="#EF4444" Margin="0,0,8,0" Width="90"/>
                <Button Name="BtnStart" Grid.Column="2" Content="Start Installation" Background="#22C55E" Foreground="#022C22"
                        BorderBrush="#16A34A" FontWeight="Bold" FontSize="13.5" Padding="20,7"/>
            </Grid>
        </Border>
    </Grid>
</Window>
'@

    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    $window = [System.Windows.Markup.XamlReader]::Load($reader)

    $pnlCategories = $window.FindName("PnlCategories")
    $txtSummaryCount = $window.FindName("TxtSummaryCount")
    $btnPresetAi = $window.FindName("BtnPresetAi")
    $btnPresetMobile = $window.FindName("BtnPresetMobile")
    $btnPresetWeb = $window.FindName("BtnPresetWeb")
    $btnPresetDevops = $window.FindName("BtnPresetDevops")
    $btnSelectAll = $window.FindName("BtnSelectAll")
    $btnClearAll = $window.FindName("BtnClearAll")
    $btnStart = $window.FindName("BtnStart")
    $btnCancel = $window.FindName("BtnCancel")

    $checkBoxMap = @{}
    $categories = $tools | Group-Object -Property category

    foreach ($cat in $categories) {
        # Category Banner
        $catHeader = New-Object System.Windows.Controls.Border
        $catHeader.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E293B")
        $catHeader.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#38BDF8")
        $catHeader.BorderThickness = New-Object System.Windows.Thickness(2, 0, 0, 0)
        $catHeader.CornerRadius = New-Object System.Windows.CornerRadius(4)
        $catHeader.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
        $catHeader.Margin = New-Object System.Windows.Thickness(0, 10, 0, 6)

        $catText = New-Object System.Windows.Controls.TextBlock
        $catText.Text = $cat.Name
        $catText.FontSize = 13
        $catText.FontWeight = [System.Windows.FontWeights]::Bold
        $catText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#38BDF8")
        $catHeader.Child = $catText

        $pnlCategories.Children.Add($catHeader) | Out-Null

        foreach ($tool in $cat.Group) {
            # Tool Card
            $card = New-Object System.Windows.Controls.Border
            $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E293B")
            $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#334155")
            $card.BorderThickness = New-Object System.Windows.Thickness(1)
            $card.CornerRadius = New-Object System.Windows.CornerRadius(6)
            $card.Padding = New-Object System.Windows.Thickness(12, 8, 12, 8)
            $card.Margin = New-Object System.Windows.Thickness(0, 0, 0, 5)

            $cardGrid = New-Object System.Windows.Controls.Grid
            $col0 = New-Object System.Windows.Controls.ColumnDefinition
            $col0.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
            $col1 = New-Object System.Windows.Controls.ColumnDefinition
            $col1.Width = [System.Windows.GridLength]::Auto
            $cardGrid.ColumnDefinitions.Add($col0)
            $cardGrid.ColumnDefinitions.Add($col1)

            $toolStack = New-Object System.Windows.Controls.StackPanel
            [System.Windows.Controls.Grid]::SetColumn($toolStack, 0)

            $cb = New-Object System.Windows.Controls.CheckBox
            $cb.Content = $tool.name
            $cb.IsChecked = [bool]$tool.defaultChecked
            $cb.Tag = $tool.id
            $cb.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FFFFFF")
            $cb.FontWeight = [System.Windows.FontWeights]::Bold
            $cb.FontSize = 13.5

            $desc = New-Object System.Windows.Controls.TextBlock
            $desc.Text = $tool.description
            $desc.FontSize = 11.5
            $desc.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#E2E8F0")
            $desc.Margin = New-Object System.Windows.Thickness(24, 2, 0, 0)
            $desc.TextWrapping = [System.Windows.TextWrapping]::Wrap

            $toolStack.Children.Add($cb) | Out-Null
            $toolStack.Children.Add($desc) | Out-Null

            # Tag Badge
            $badgeBorder = New-Object System.Windows.Controls.Border
            $badgeBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0F172A")
            $badgeBorder.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0284C7")
            $badgeBorder.BorderThickness = New-Object System.Windows.Thickness(1)
            $badgeBorder.CornerRadius = New-Object System.Windows.CornerRadius(4)
            $badgeBorder.Padding = New-Object System.Windows.Thickness(8, 3, 8, 3)
            $badgeBorder.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            [System.Windows.Controls.Grid]::SetColumn($badgeBorder, 1)

            $badgeText = New-Object System.Windows.Controls.TextBlock
            $badgeText.Text = if ($tool.tag) { $tool.tag } else { "Tool" }
            $badgeText.FontSize = 10.5
            $badgeText.FontWeight = [System.Windows.FontWeights]::SemiBold
            $badgeText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#38BDF8")
            $badgeBorder.Child = $badgeText

            $cardGrid.Children.Add($toolStack) | Out-Null
            $cardGrid.Children.Add($badgeBorder) | Out-Null
            $card.Child = $cardGrid

            $pnlCategories.Children.Add($card) | Out-Null

            $checkBoxMap[$tool.id] = $cb
        }
    }

    # Helper function to update count
    $updateCount = {
        $selectedCount = 0
        foreach ($key in $checkBoxMap.Keys) {
            if ($checkBoxMap[$key].IsChecked -eq $true) {
                $selectedCount++
            }
        }
        $txtSummaryCount.Text = "Selected: $selectedCount of $($checkBoxMap.Count) tools"
    }

    # Dependency auto-check handler
    $handleDependency = {
        if ($checkBoxMap.ContainsKey("flutter") -and $checkBoxMap["flutter"].IsChecked -eq $true) {
            if ($checkBoxMap.ContainsKey("gitCli") -and $checkBoxMap["gitCli"].IsChecked -ne $true) {
                $checkBoxMap["gitCli"].IsChecked = $true
            }
        }
        if ($checkBoxMap.ContainsKey("android") -and $checkBoxMap["android"].IsChecked -eq $true) {
            if ($checkBoxMap.ContainsKey("java") -and $checkBoxMap["java"].IsChecked -ne $true) {
                $checkBoxMap["java"].IsChecked = $true
            }
        }
        if ($checkBoxMap.ContainsKey("gradle") -and $checkBoxMap["gradle"].IsChecked -eq $true) {
            if ($checkBoxMap.ContainsKey("java") -and $checkBoxMap["java"].IsChecked -ne $true) {
                $checkBoxMap["java"].IsChecked = $true
            }
        }
        & $updateCount
    }

    foreach ($k in $checkBoxMap.Keys) {
        $checkBoxMap[$k].Add_Checked({ & $handleDependency })
        $checkBoxMap[$k].Add_Unchecked({ & $updateCount })
    }

    & $updateCount

    # Preset handlers
    $applyPreset = {
        param([string[]]$toolIds)
        foreach ($k in $checkBoxMap.Keys) {
            $checkBoxMap[$k].IsChecked = ($toolIds -contains $k)
        }
        & $updateCount
    }

    if ($btnPresetAi) {
        $btnPresetAi.Add_Click({
            & $applyPreset $presets.ai
        })
    }

    $btnPresetMobile.Add_Click({
        & $applyPreset $presets.mobile
    })

    $btnPresetWeb.Add_Click({
        & $applyPreset $presets.web
    })

    $btnPresetDevops.Add_Click({
        & $applyPreset $presets.devops
    })

    $btnSelectAll.Add_Click({
        foreach ($k in $checkBoxMap.Keys) {
            $checkBoxMap[$k].IsChecked = $true
        }
        & $updateCount
    })

    $btnClearAll.Add_Click({
        foreach ($k in $checkBoxMap.Keys) {
            $checkBoxMap[$k].IsChecked = $false
        }
        & $updateCount
    })

    $script:guiResult = $null

    $btnStart.Add_Click({
        $selected = @()
        foreach ($k in $checkBoxMap.Keys) {
            if ($checkBoxMap[$k].IsChecked -eq $true) {
                $selected += $k
            }
        }

        if ($selected.Count -eq 0) {
            [System.Windows.MessageBox]::Show(
                "Please select at least one tool to install before starting.",
                "No Tools Selected",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning
            ) | Out-Null
            return
        }

        $script:guiResult = $selected
        $window.Close()
    })

    $btnCancel.Add_Click({
        $script:guiResult = $null
        $window.Close()
    })

    # Show Modal Dialog
    $window.ShowDialog() | Out-Null

    return $script:guiResult
}

function Show-ToolSelectionCli {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Config
    )

    $tools = $Config.selectableTools
    $presets = $Config.presets

    $selectedMap = [ordered]@{}
    for ($i = 0; $i -lt $tools.Count; $i++) {
        $t = $tools[$i]
        $selectedMap[$t.id] = [bool]$t.defaultChecked
    }

    while ($true) {
        Clear-Host
        Write-Host "================================================================================" -ForegroundColor Cyan
        Write-Host "         BURNANDBUILD - DEV ENVIRONMENT TOOL SELECTION MENU" -ForegroundColor Cyan
        Write-Host "================================================================================" -ForegroundColor Cyan
        Write-Host " Toggle any tool number to check/uncheck. Press [ENTER] to start installation.`n" -ForegroundColor DarkGray

        for ($i = 0; $i -lt $tools.Count; $i++) {
            $t = $tools[$i]
            $num = ($i + 1).ToString().PadLeft(2)
            $isSelected = $selectedMap[$t.id]
            $box = if ($isSelected) { "[X]" } else { "[ ]" }
            $boxColor = if ($isSelected) { "Green" } else { "DarkGray" }
            $nameColor = if ($isSelected) { "White" } else { "Gray" }

            Write-Host "  [$num] " -NoNewline -ForegroundColor Cyan
            Write-Host "$box " -NoNewline -ForegroundColor $boxColor
            Write-Host "$($t.name.PadRight(30)) " -NoNewline -ForegroundColor $nameColor
            Write-Host "($($t.category))" -ForegroundColor DarkCyan
            Write-Host "       $($t.description)" -ForegroundColor DarkGray
        }

        $selectedCount = ($selectedMap.Values | Where-Object { $_ -eq $true }).Count
        Write-Host "`n--------------------------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host " Selected: $selectedCount of $($tools.Count) tools" -ForegroundColor Yellow
        Write-Host " Presets : [AI] AI & Agents  [M] Mobile  [W] Web  [D] DevOps  [A] All  [C] Clear" -ForegroundColor DarkYellow
        Write-Host " Actions : [Enter] START INSTALLATION   [Q] Quit / Cancel" -ForegroundColor Green
        Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host -NoNewline "Command / Numbers to toggle (e.g. '1,4,7' or 'AI'): "

        $input = Read-Host
        if ($null -eq $input) { $input = "" }
        $input = $input.Trim()

        if ($input -eq "" -or $input.ToLower() -eq "start") {
            $chosen = @()
            foreach ($k in $selectedMap.Keys) {
                if ($selectedMap[$k]) { $chosen += $k }
            }
            if ($chosen.Count -eq 0) {
                Write-Host "`nPlease select at least one tool to continue!" -ForegroundColor Red
                Start-Sleep -Seconds 2
                continue
            }
            return $chosen
        }

        if ($input.ToLower() -eq "q" -or $input.ToLower() -eq "exit") {
            Write-Host "`nSetup cancelled by user." -ForegroundColor Yellow
            return $null
        }

        if ($input.ToLower() -eq "a" -or $input.ToLower() -eq "all") {
            foreach ($k in $selectedMap.Keys) { $selectedMap[$k] = $true }
            continue
        }

        if ($input.ToLower() -eq "c" -or $input.ToLower() -eq "clear") {
            foreach ($k in $selectedMap.Keys) { $selectedMap[$k] = $false }
            continue
        }

        if ($input.ToLower() -eq "ai") {
            foreach ($k in $selectedMap.Keys) {
                $selectedMap[$k] = ($presets.ai -contains $k)
            }
            continue
        }

        if ($input.ToLower() -eq "m" -or $input.ToLower() -eq "mobile") {
            foreach ($k in $selectedMap.Keys) {
                $selectedMap[$k] = ($presets.mobile -contains $k)
            }
            continue
        }

        if ($input.ToLower() -eq "w" -or $input.ToLower() -eq "web") {
            foreach ($k in $selectedMap.Keys) {
                $selectedMap[$k] = ($presets.web -contains $k)
            }
            continue
        }

        if ($input.ToLower() -eq "d" -or $input.ToLower() -eq "devops") {
            foreach ($k in $selectedMap.Keys) {
                $selectedMap[$k] = ($presets.devops -contains $k)
            }
            continue
        }

        $tokens = $input -split '[\s,]+'
        foreach ($tok in $tokens) {
            $numVal = 0
            if ([int]::TryParse($tok, [ref]$numVal)) {
                $idx = $numVal - 1
                if ($idx -ge 0 -and $idx -lt $tools.Count) {
                    $toolId = $tools[$idx].id
                    $selectedMap[$toolId] = -not $selectedMap[$toolId]

                    if ($toolId -eq "flutter" -and $selectedMap["flutter"]) {
                        $selectedMap["gitCli"] = $true
                    }
                    if ($toolId -eq "android" -and $selectedMap["android"]) {
                        $selectedMap["java"] = $true
                    }
                    if ($toolId -eq "gradle" -and $selectedMap["gradle"]) {
                        $selectedMap["java"] = $true
                    }
                }
            }
        }
    }
}

function Get-SelectedTools {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath = "$PSScriptRoot\..\config.json",

        [Parameter(Mandatory = $false)]
        [string[]]$ExplicitTools = @(),

        [Parameter(Mandatory = $false)]
        [string]$Preset = "",

        [Parameter(Mandatory = $false)]
        [switch]$Full,

        [Parameter(Mandatory = $false)]
        [switch]$NoGui,

        [Parameter(Mandatory = $false)]
        [switch]$ForceCli
    )

    $config = Get-ToolCatalog -ConfigPath $ConfigPath
    $validIds = $config.selectableTools | ForEach-Object { $_.id }

    # 1. If -Full specified: return all tools
    if ($Full) {
        Write-Log -Level INFO -Message "Running with -Full switch: Selecting all tools."
        return $validIds
    }

    # 2. If -Preset specified: return preset tools
    if ($Preset) {
        $presetKey = $Preset.ToLower()
        if ($config.presets.PSObject.Properties[$presetKey]) {
            Write-Log -Level INFO -Message "Applying preset: $presetKey"
            return $config.presets.$presetKey
        } else {
            Write-Log -Level WARN -Message "Preset '$Preset' not found. Available presets: $($config.presets.PSObject.Properties.Name -join ', ')"
        }
    }

    # 3. If -Tools specified on command-line
    if ($ExplicitTools -and $ExplicitTools.Count -gt 0) {
        $resolved = @()
        $aliasMap = @{
            "antigravity"   = "antigravityCli"
            "antigravitycli"= "antigravityCli"
            "agy"           = "antigravityCli"
            "antigravityide"= "antigravityIde"
            "cursor"        = "cursor"
            "codex"         = "codex"
            "dart"          = "flutter"
            "flutter"       = "flutter"
            "node"          = "node"
            "nodejs"        = "node"
            "python"        = "python"
            "pythin"        = "python"
            "py"            = "python"
            "docker"        = "docker"
            "containers"    = "docker"
            "java"          = "java"
            "jdk"           = "java"
            "android"       = "android"
            "gradle"        = "gradle"
            "git"           = "gitCli"
            "cli"           = "gitCli"
            "gitcli"        = "gitCli"
            "vscode"        = "vscode"
            "code"          = "vscode"
            "notepad"       = "notepadpp"
            "notepadpp"     = "notepadpp"
            "chrome"        = "chrome"
            "brave"         = "brave"
            "bravebrowser"  = "brave"
            "postman"       = "postman"
            "dbeaver"       = "dbeaver"
            "powerbi"       = "powerbi"
            "powerbidesktop" = "powerbi"
            "pbi"           = "powerbi"
            "jira"          = "jira"
            "jiracli"       = "jira"
            "atlassian"     = "jira"
            "base"          = "baseWindows"
            "windows"       = "baseWindows"
            "basewindows"   = "baseWindows"
        }

        $flatList = foreach ($item in $ExplicitTools) {
            $item -split '[\s,]+' | Where-Object { $_ -ne "" }
        }

        foreach ($item in $flatList) {
            $cleaned = $item.Trim().ToLower()
            if ($aliasMap.ContainsKey($cleaned)) {
                $targetId = $aliasMap[$cleaned]
                if ($validIds -contains $targetId -and $resolved -notcontains $targetId) {
                    $resolved += $targetId
                }
            } elseif ($validIds -contains $cleaned -and $resolved -notcontains $cleaned) {
                $resolved += $cleaned
            } else {
                Write-Log -Level WARN -Message "Unknown tool specified: '$item'. Skipping."
            }
        }

        if ($resolved.Count -gt 0) {
            if ($resolved -contains "flutter" -and $resolved -notcontains "gitCli") {
                Write-Log -Level INFO -Message "Flutter requires Git. Automatically adding 'gitCli'."
                $resolved += "gitCli"
            }
            if ($resolved -contains "android" -and $resolved -notcontains "java") {
                Write-Log -Level INFO -Message "Android SDK requires Java 17. Automatically adding 'java'."
                $resolved += "java"
            }
            return $resolved
        }
    }

    # 4. Interactive Mode: Check if GUI Desktop is available
    $canUseGui = (-not $NoGui) -and (-not $ForceCli) -and [System.Environment]::UserInteractive

    if ($canUseGui) {
        Write-Log -Level INFO -Message "Opening interactive tool selection window..."
        try {
            $guiSelection = Show-ToolSelectionGui -Config $config
            if ($null -ne $guiSelection) {
                if ($guiSelection -contains "flutter" -and $guiSelection -notcontains "gitCli") {
                    $guiSelection += "gitCli"
                }
                if ($guiSelection -contains "android" -and $guiSelection -notcontains "java") {
                    $guiSelection += "java"
                }
                return $guiSelection
            } else {
                Write-Log -Level WARN -Message "Tool selection was cancelled by user."
                return $null
            }
        } catch {
            Write-Log -Level WARN -Message "GUI window failed to open ($($_)). Falling back to interactive Console..."
        }
    }

    # 5. Interactive Console Mode (Fallback or explicitly requested)
    Write-Log -Level INFO -Message "Launching interactive Console selector..."
    $cliSelection = Show-ToolSelectionCli -Config $config
    if ($cliSelection) {
        if ($cliSelection -contains "flutter" -and $cliSelection -notcontains "gitCli") {
            $cliSelection += "gitCli"
        }
        if ($cliSelection -contains "android" -and $cliSelection -notcontains "java") {
            $cliSelection += "java"
        }
    }
    return $cliSelection
}

Export-ModuleMember -Function Get-ToolCatalog, Show-ToolSelectionGui, Show-ToolSelectionCli, Get-SelectedTools
