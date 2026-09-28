# modules/ToolSelector.psm1
# Interactive Tool Selector for Disposable Windows Dev VM Setup
# Supports both Modern WPF Graphical Checklist & Interactive Console Fallback

[CmdletBinding()]
param()

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "Logging.psm1") -Force

function Get-ToolCatalog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath = "$PSScriptRoot\..\config.json"
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found at: $ConfigPath"
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

    # Generate XAML dynamically
    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Windows Dev VM Provisioner - Tool Selection"
        Height="760" Width="820" MinHeight="620" MinWidth="720"
        WindowStartupLocation="CenterScreen"
        Background="#181825" Foreground="#CDD6F4"
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
            <Setter Property="Foreground" Value="#CDD6F4"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Margin" Value="0,2,0,2"/>
        </Style>
    </Window.Resources>

    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/> <!-- Header -->
            <RowDefinition Height="Auto"/> <!-- Presets -->
            <RowDefinition Height="*"/>    <!-- Scrollable Checklist -->
            <RowDefinition Height="Auto"/> <!-- Footer / Actions -->
        </Grid.RowDefinitions>

        <!-- Header -->
        <Border Grid.Row="0" Background="#1E1E2E" CornerRadius="10" Padding="18,14" Margin="0,0,0,12" BorderBrush="#313244" BorderThickness="1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0">
                    <TextBlock Text="🚀 Windows Dev Environment Provisioner" FontSize="20" FontWeight="Bold" Foreground="#89B4FA"/>
                    <TextBlock Text="Select the developer tools, runtimes, and frameworks you want to install on this VM:"
                               FontSize="13" Foreground="#BAC2DE" Margin="0,4,0,0" TextWrapping="Wrap"/>
                </StackPanel>
                <Border Grid.Column="1" Background="#313244" CornerRadius="6" Padding="10,6" VerticalAlignment="Center">
                    <TextBlock Name="TxtSummaryCount" Text="Selected: 0 tools" FontSize="12" FontWeight="Bold" Foreground="#A6E3A1"/>
                </Border>
            </Grid>
        </Border>

        <!-- Presets Bar -->
        <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,12">
            <TextBlock Text="Quick Presets:" VerticalAlignment="Center" Foreground="#A6ADC8" FontWeight="SemiBold" FontSize="12" Margin="0,0,10,0"/>
            <Button Name="BtnPresetMobile" Content="📱 Flutter &amp; Mobile" Background="#2A2B3D" Foreground="#F9E2AF" BorderBrush="#F9E2AF" Margin="0,0,8,0"/>
            <Button Name="BtnPresetWeb" Content="🌐 Full-Stack Web" Background="#2A2B3D" Foreground="#89B4FA" BorderBrush="#89B4FA" Margin="0,0,8,0"/>
            <Button Name="BtnPresetDevops" Content="🐳 Docker &amp; DevOps" Background="#2A2B3D" Foreground="#94E2D5" BorderBrush="#94E2D5" Margin="0,0,8,0"/>
            <Button Name="BtnSelectAll" Content="✨ Select All" Background="#313244" Foreground="#CDD6F4" BorderBrush="#45475A" Margin="0,0,8,0"/>
            <Button Name="BtnClearAll" Content="🧹 Clear All" Background="#313244" Foreground="#BAC2DE" BorderBrush="#45475A"/>
        </StackPanel>

        <!-- Checklist Scroll Area -->
        <Border Grid.Row="2" Background="#1E1E2E" CornerRadius="10" BorderBrush="#313244" BorderThickness="1" Padding="12">
            <ScrollViewer VerticalScrollBarVisibility="Auto">
                <StackPanel Name="PnlCategories" Margin="0,0,8,0">
                    <!-- Tool Cards populated dynamically in code -->
                </StackPanel>
            </ScrollViewer>
        </Border>

        <!-- Footer / Start Button -->
        <Border Grid.Row="3" Background="#1E1E2E" CornerRadius="10" Padding="16,12" Margin="0,12,0,0" BorderBrush="#313244" BorderThickness="1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                    <TextBlock Text="Idempotent: Already installed tools will be verified and skipped safely." FontSize="11" Foreground="#6C7086"/>
                </StackPanel>

                <Button Name="BtnCancel" Grid.Column="1" Content="✕ Cancel" Background="#313244" Foreground="#F38BA8"
                        BorderBrush="#F38BA8" Margin="0,0,10,0" Width="100"/>
                <Button Name="BtnStart" Grid.Column="2" Content="▶  Start Installation" Background="#A6E3A1" Foreground="#11111B"
                        BorderBrush="#A6E3A1" FontWeight="Bold" FontSize="13" Padding="20,8"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    $window = [System.Windows.Markup.XamlReader]::Load($reader)

    $pnlCategories = $window.FindName("PnlCategories")
    $txtSummaryCount = $window.FindName("TxtSummaryCount")
    $btnPresetMobile = $window.FindName("BtnPresetMobile")
    $btnPresetWeb = $window.FindName("BtnPresetWeb")
    $btnPresetDevops = $window.FindName("BtnPresetDevops")
    $btnSelectAll = $window.FindName("BtnSelectAll")
    $btnClearAll = $window.FindName("BtnClearAll")
    $btnStart = $window.FindName("BtnStart")
    $btnCancel = $window.FindName("BtnCancel")

    # Store mapping of toolId -> CheckBox control
    $checkBoxMap = @{}

    # Group tools by category
    $categories = $tools | Group-Object -Property category

    foreach ($cat in $categories) {
        # Category Header
        $catHeader = New-Object System.Windows.Controls.Border
        $catHeader.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#252538")
        $catHeader.CornerRadius = New-Object System.Windows.CornerRadius(6)
        $catHeader.Padding = New-Object System.Windows.Thickness(10, 6, 10, 6)
        $catHeader.Margin = New-Object System.Windows.Thickness(0, 10, 0, 8)

        $catText = New-Object System.Windows.Controls.TextBlock
        $catText.Text = $cat.Name
        $catText.FontSize = 13
        $catText.FontWeight = [System.Windows.FontWeights]::Bold
        $catText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#CBA6F7")
        $catHeader.Child = $catText

        $pnlCategories.Children.Add($catHeader) | Out-Null

        foreach ($tool in $cat.Group) {
            # Tool Card
            $card = New-Object System.Windows.Controls.Border
            $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#181825")
            $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#313244")
            $card.BorderThickness = New-Object System.Windows.Thickness(1)
            $card.CornerRadius = New-Object System.Windows.CornerRadius(6)
            $card.Padding = New-Object System.Windows.Thickness(12, 8, 12, 8)
            $card.Margin = New-Object System.Windows.Thickness(0, 0, 0, 6)

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

            $desc = New-Object System.Windows.Controls.TextBlock
            $desc.Text = $tool.description
            $desc.FontSize = 11
            $desc.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#A6ADC8")
            $desc.Margin = New-Object System.Windows.Thickness(24, 2, 0, 0)
            $desc.TextWrapping = [System.Windows.TextWrapping]::Wrap

            $toolStack.Children.Add($cb) | Out-Null
            $toolStack.Children.Add($desc) | Out-Null

            # Tag badge
            $badgeBorder = New-Object System.Windows.Controls.Border
            $badgeBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2E2E3E")
            $badgeBorder.CornerRadius = New-Object System.Windows.CornerRadius(4)
            $badgeBorder.Padding = New-Object System.Windows.Thickness(8, 3, 8, 3)
            $badgeBorder.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            [System.Windows.Controls.Grid]::SetColumn($badgeBorder, 1)

            $badgeText = New-Object System.Windows.Controls.TextBlock
            $badgeText.Text = if ($tool.tag) { $tool.tag } else { "Tool" }
            $badgeText.FontSize = 10
            $badgeText.FontWeight = [System.Windows.FontWeights]::SemiBold
            $badgeText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#89DCEB")
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
        # If Flutter checked -> check gitCli
        if ($checkBoxMap.ContainsKey("flutter") -and $checkBoxMap["flutter"].IsChecked -eq $true) {
            if ($checkBoxMap.ContainsKey("gitCli") -and $checkBoxMap["gitCli"].IsChecked -ne $true) {
                $checkBoxMap["gitCli"].IsChecked = $true
            }
        }
        # If Android checked -> check Java
        if ($checkBoxMap.ContainsKey("android") -and $checkBoxMap["android"].IsChecked -eq $true) {
            if ($checkBoxMap.ContainsKey("java") -and $checkBoxMap["java"].IsChecked -ne $true) {
                $checkBoxMap["java"].IsChecked = $true
            }
        }
        # If Gradle checked -> check Java
        if ($checkBoxMap.ContainsKey("gradle") -and $checkBoxMap["gradle"].IsChecked -eq $true) {
            if ($checkBoxMap.ContainsKey("java") -and $checkBoxMap["java"].IsChecked -ne $true) {
                $checkBoxMap["java"].IsChecked = $true
            }
        }
        & $updateCount
    }

    # Attach event listeners to checkboxes
    foreach ($k in $checkBoxMap.Keys) {
        $checkBoxMap[$k].Add_Checked({ & $handleDependency })
        $checkBoxMap[$k].Add_Unchecked({ & $updateCount })
    }

    # Initial count update
    & $updateCount

    # Preset handlers
    $applyPreset = {
        param([string[]]$toolIds)
        foreach ($k in $checkBoxMap.Keys) {
            $checkBoxMap[$k].IsChecked = ($toolIds -contains $k)
        }
        & $updateCount
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

    # Initialize selection state map
    $selectedMap = [ordered]@{}
    for ($i = 0; $i -lt $tools.Count; $i++) {
        $t = $tools[$i]
        $selectedMap[$t.id] = [bool]$t.defaultChecked
    }

    while ($true) {
        Clear-Host
        Write-Host "================================================================================" -ForegroundColor Cyan
        Write-Host "       WINDOWS DEV ENVIRONMENT PROVISIONER - TOOL SELECTION MENU" -ForegroundColor Cyan
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
        Write-Host " Presets : [M] Mobile/Flutter  [W] Full-Stack Web  [D] DevOps  [A] All  [C] Clear" -ForegroundColor DarkYellow
        Write-Host " Actions : [Enter] START INSTALLATION   [Q] Quit / Cancel" -ForegroundColor Green
        Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host -NoNewline "Command / Numbers to toggle (e.g. '1,4,7' or 'M'): "

        $input = Read-Host
        if ($null -eq $input) { $input = "" }
        $input = $input.Trim()

        if ($input -eq "" -or $input.ToLower() -eq "start") {
            # Start if at least one selected
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

        # Handle comma or space separated numbers
        $tokens = $input -split '[\s,]+'
        foreach ($tok in $tokens) {
            $numVal = 0
            if ([int]::TryParse($tok, [ref]$numVal)) {
                $idx = $numVal - 1
                if ($idx -ge 0 -and $idx -lt $tools.Count) {
                    $toolId = $tools[$idx].id
                    $selectedMap[$toolId] = -not $selectedMap[$toolId]

                    # Auto-check dependencies
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
            "dart"       = "flutter"
            "flutter"    = "flutter"
            "node"       = "node"
            "nodejs"     = "node"
            "python"     = "python"
            "pythin"     = "python"
            "py"         = "python"
            "docker"     = "docker"
            "containers" = "docker"
            "java"       = "java"
            "jdk"        = "java"
            "android"    = "android"
            "gradle"     = "gradle"
            "git"        = "gitCli"
            "cli"        = "gitCli"
            "gitcli"     = "gitCli"
            "vscode"     = "vscode"
            "code"       = "vscode"
            "notepad"    = "notepadpp"
            "notepadpp"  = "notepadpp"
            "chrome"     = "chrome"
            "postman"    = "postman"
            "dbeaver"    = "dbeaver"
            "base"       = "baseWindows"
            "windows"    = "baseWindows"
            "basewindows"= "baseWindows"
        }

        # Flatten any comma-separated strings inside array
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
            # Auto-resolve critical dependencies
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
                # Ensure critical dependencies
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
