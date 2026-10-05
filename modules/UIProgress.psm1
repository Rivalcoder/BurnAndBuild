# modules/UIProgress.psm1
# Rich, Modern, Dynamic UI Progress Engine for BurnAndBuild
# Supports both High-Fidelity WPF Live Progress Window and Vibrant Terminal Dashboard

[CmdletBinding()]
param()

$modulesPath = $PSScriptRoot
if (-not (Get-Command "Write-Log" -ErrorAction SilentlyContinue)) {
    $logPath = Join-Path -Path $modulesPath -ChildPath "Logging.psm1"
    if (Test-Path $logPath) { Import-Module $logPath -Global -DisableNameChecking }
}

# Global synchronized state for cross-thread WPF UI communication
$global:BnBUIState = $null
$global:BnBUIRunspace = $null
$global:BnBUIPowerShell = $null
$global:BnBUIGuiEnabled = $false
$global:BnBSelectedToolsList = @()
$global:BnBCompletedToolsCount = 0
$global:BnBStopwatch = $null

function Initialize-ProgressUI {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$SelectedTools,

        [Parameter(Mandatory = $false)]
        [hashtable]$ToolCatalog = @{},

        [Parameter(Mandatory = $false)]
        [switch]$NoGui,

        [Parameter(Mandatory = $false)]
        [switch]$ForceCli
    )

    $global:BnBSelectedToolsList = @($SelectedTools)
    $global:BnBCompletedToolsCount = 0
    $global:BnBStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    $canUseGui = (-not $NoGui) -and (-not $ForceCli) -and [System.Environment]::UserInteractive

    if ($canUseGui) {
        try {
            Start-LiveProgressWindow -Tools $SelectedTools -Catalog $ToolCatalog
            $global:BnBUIGuiEnabled = $true
        } catch {
            Write-Log -Level WARN -Message "Live GUI Progress window could not be initialized ($($_)). Continuing with rich Terminal Dashboard."
            $global:BnBUIGuiEnabled = $false
        }
    } else {
        $global:BnBUIGuiEnabled = $false
    }

    # Print initial terminal header
    Write-TerminalBanner
}

function Write-TerminalBanner {
    $border = "=" * 80
    Write-Host ""
    Write-Host $border -ForegroundColor DarkCyan
    Write-Host "         BURNANDBUILD - HIGH VELOCITY ENVIRONMENT PROVISIONER" -ForegroundColor Cyan
    Write-Host "   Active Tools: $($global:BnBSelectedToolsList.Count) | Parallel Engine | Mobile SDKs At Last" -ForegroundColor DarkCyan
    Write-Host $border -ForegroundColor DarkCyan
    Write-Host ""
}

function Start-LiveProgressWindow {
    param(
        [string[]]$Tools,
        [hashtable]$Catalog
    )

    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase -ErrorAction Stop

    # Shared thread-safe state
    $toolStatusMap = [hashtable]::Synchronized(@{})
    foreach ($t in $Tools) {
        $toolStatusMap[$t] = "Pending"
    }

    $global:BnBUIState = [hashtable]::Synchronized(@{
        OverallPercent    = 0
        CurrentPhaseTitle = "Initializing Provisioner..."
        CurrentToolName   = "Preparing environment..."
        CurrentDetail     = "Configuring system state and background workers"
        Logs              = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
        ToolStatus        = $toolStatusMap
        ToolsList         = [string[]]$Tools
        Catalog           = $Catalog
        IsCompleted       = $false
        TotalMinutes      = 0.0
        CloseRequested    = $false
    })

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = [System.Threading.ApartmentState]::STA
    $rs.Open()
    $rs.SessionStateProxy.SetVariable("syncState", $global:BnBUIState)

    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    $null = $ps.AddScript({
        Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

        $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="BurnAndBuild - Live Provisioning Monitor"
        Height="720" Width="960" MinHeight="600" MinWidth="800"
        WindowStartupLocation="CenterScreen"
        Background="#0B0F19" Foreground="#F8FAFC"
        FontFamily="Segoe UI, Segoe UI Variable, sans-serif">
    <Window.Resources>
        <Style TargetType="ProgressBar">
            <Setter Property="Height" Value="14"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Background" Value="#1E293B"/>
            <Setter Property="Foreground" Value="#38BDF8"/>
        </Style>
    </Window.Resources>

    <Grid Margin="18">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/> <!-- Header -->
            <RowDefinition Height="Auto"/> <!-- Progress Bar -->
            <RowDefinition Height="*"/>    <!-- Body: Tools List & Logs -->
            <RowDefinition Height="Auto"/> <!-- Footer -->
        </Grid.RowDefinitions>

        <!-- Header -->
        <Border Grid.Row="0" Background="#111827" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="8" Padding="16,12" Margin="0,0,0,12">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0">
                    <TextBlock Text="BurnAndBuild Provisioning Monitor" FontSize="18" FontWeight="Bold" Foreground="#38BDF8"/>
                    <TextBlock Name="TxtActivePhase" Text="Phase 1: Initializing..." FontSize="13" Foreground="#94A3B8" Margin="0,3,0,0"/>
                </StackPanel>
                <StackPanel Grid.Column="1" VerticalAlignment="Center" HorizontalAlignment="Right">
                    <Border Background="#0B0F19" BorderBrush="#1E293B" BorderThickness="1" CornerRadius="6" Padding="12,5">
                        <TextBlock Name="TxtTimer" Text="Elapsed: 00:00" FontSize="12.5" FontWeight="Bold" Foreground="#34D399"/>
                    </Border>
                </StackPanel>
            </Grid>
        </Border>

        <!-- Overall Progress Bar Card -->
        <Border Grid.Row="1" Background="#111827" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="8" Padding="16,12" Margin="0,0,0,12">
            <StackPanel>
                <Grid Margin="0,0,0,6">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <TextBlock Name="TxtActiveTool" Text="Processing: Preparing..." FontSize="13.5" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                    <TextBlock Name="TxtPercent" Grid.Column="1" Text="0%" FontSize="13.5" FontWeight="Bold" Foreground="#38BDF8"/>
                </Grid>
                <ProgressBar Name="PrgOverall" Maximum="100" Value="0" Margin="0,0,0,6"/>
                <TextBlock Name="TxtDetail" Text="Initializing system environment..." FontSize="11.5" Foreground="#94A3B8" TextTrimming="CharacterEllipsis"/>
            </StackPanel>
        </Border>

        <!-- Main Body: Tools Checklist (Left) & Real-time Log Stream (Right) -->
        <Grid Grid.Row="2">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="340"/>
                <ColumnDefinition Width="12"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- Tools Checklist -->
            <Border Grid.Column="0" Background="#111827" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="8" Padding="10">
                <DockPanel>
                    <TextBlock DockPanel.Dock="Top" Text="Tool Pipeline Status" FontSize="13" FontWeight="Bold" Foreground="#CBD5E1" Margin="4,0,0,8"/>
                    <ScrollViewer VerticalScrollBarVisibility="Auto">
                        <StackPanel Name="PnlToolItems">
                            <!-- Populated dynamically -->
                        </StackPanel>
                    </ScrollViewer>
                </DockPanel>
            </Border>

            <!-- Log Stream Terminal -->
            <Border Grid.Column="2" Background="#050811" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="8" Padding="10">
                <DockPanel>
                    <TextBlock DockPanel.Dock="Top" Text="Live Execution Stream" FontSize="13" FontWeight="Bold" Foreground="#CBD5E1" Margin="4,0,0,8"/>
                    <ScrollViewer Name="ScrLogs" VerticalScrollBarVisibility="Auto">
                        <TextBox Name="TxtLogOutput" Background="Transparent" Foreground="#A7F3D0" BorderThickness="0"
                                 FontFamily="Cascadia Code, Consolas, Courier New, monospace" FontSize="11"
                                 IsReadOnly="True" TextWrapping="Wrap"/>
                    </ScrollViewer>
                </DockPanel>
            </Border>
        </Grid>

        <!-- Footer -->
        <Border Grid.Row="3" Background="#111827" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,12,0,0">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock Name="TxtFooterStatus" Text="Parallel Background Engine active. Mobile SDKs scheduled for final phase." FontSize="11" Foreground="#64748B" VerticalAlignment="Center"/>
                <Button Name="BtnFinish" Grid.Column="1" Content="Setup in progress..." Background="#1E293B" Foreground="#94A3B8"
                        BorderBrush="#334155" BorderThickness="1" Padding="16,5" FontWeight="SemiBold" FontSize="12" IsEnabled="False"/>
            </Grid>
        </Border>
    </Grid>
</Window>
'@

        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
        $window = [System.Windows.Markup.XamlReader]::Load($reader)

        $txtActivePhase = $window.FindName("TxtActivePhase")
        $txtActiveTool = $window.FindName("TxtActiveTool")
        $txtPercent = $window.FindName("TxtPercent")
        $prgOverall = $window.FindName("PrgOverall")
        $txtDetail = $window.FindName("TxtDetail")
        $txtTimer = $window.FindName("TxtTimer")
        $pnlToolItems = $window.FindName("PnlToolItems")
        $txtLogOutput = $window.FindName("TxtLogOutput")
        $scrLogs = $window.FindName("ScrLogs")
        $txtFooterStatus = $window.FindName("TxtFooterStatus")
        $btnFinish = $window.FindName("BtnFinish")

        # Create tool status card items
        $toolCardMap = @{}
        foreach ($tId in $syncState.ToolsList) {
            $card = New-Object System.Windows.Controls.Border
            $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0B0F19")
            $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E293B")
            $card.BorderThickness = New-Object System.Windows.Thickness(1)
            $card.CornerRadius = New-Object System.Windows.CornerRadius(4)
            $card.Padding = New-Object System.Windows.Thickness(8, 5, 8, 5)
            $card.Margin = New-Object System.Windows.Thickness(0, 0, 0, 4)

            $g = New-Object System.Windows.Controls.Grid
            $c0 = New-Object System.Windows.Controls.ColumnDefinition
            $c0.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
            $c1 = New-Object System.Windows.Controls.ColumnDefinition
            $c1.Width = [System.Windows.GridLength]::Auto
            $g.ColumnDefinitions.Add($c0)
            $g.ColumnDefinitions.Add($c1)

            $tText = New-Object System.Windows.Controls.TextBlock
            $tText.Text = $tId
            $tText.FontSize = 12
            $tText.FontWeight = [System.Windows.FontWeights]::SemiBold
            $tText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#E2E8F0")
            [System.Windows.Controls.Grid]::SetColumn($tText, 0)

            $sBadge = New-Object System.Windows.Controls.TextBlock
            $sBadge.Text = "WAIT"
            $sBadge.FontSize = 10.5
            $sBadge.FontWeight = [System.Windows.FontWeights]::Bold
            $sBadge.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#64748B")
            [System.Windows.Controls.Grid]::SetColumn($sBadge, 1)

            $g.Children.Add($tText) | Out-Null
            $g.Children.Add($sBadge) | Out-Null
            $card.Child = $g

            $pnlToolItems.Children.Add($card) | Out-Null
            $toolCardMap[$tId] = @{
                Card  = $card
                Badge = $sBadge
                Text  = $tText
            }
        }

        $startTime = [DateTime]::Now

        # Dispatcher Timer for smooth 100ms UI sync
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromMilliseconds(100)
        $timer.Add_Tick({
            $elapsed = [DateTime]::Now - $startTime
            $txtTimer.Text = "Elapsed: $($elapsed.ToString('mm\:ss'))"

            $txtActivePhase.Text = $syncState.CurrentPhaseTitle
            $txtActiveTool.Text = $syncState.CurrentToolName
            $txtDetail.Text = $syncState.CurrentDetail

            $pct = [int]$syncState.OverallPercent
            if ($pct -gt 100) { $pct = 100 }
            $prgOverall.Value = $pct
            $txtPercent.Text = "$pct%"

            # Update tool cards
            foreach ($key in $syncState.ToolStatus.Keys) {
                if ($toolCardMap.ContainsKey($key)) {
                    $st = $syncState.ToolStatus[$key]
                    $badge = $toolCardMap[$key].Badge
                    $card = $toolCardMap[$key].Card
                    switch ($st) {
                        "Running" {
                            $badge.Text = "RUNNING"
                            $badge.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#38BDF8")
                            $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0284C7")
                        }
                        "Success" {
                            $badge.Text = "DONE"
                            $badge.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#34D399")
                            $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#059669")
                        }
                        "Skipped" {
                            $badge.Text = "SKIPPED"
                            $badge.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FBBF24")
                            $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#475569")
                        }
                        "Failed" {
                            $badge.Text = "FAILED"
                            $badge.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F87171")
                            $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#DC2626")
                        }
                        Default {
                            $badge.Text = "WAIT"
                            $badge.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#64748B")
                        }
                    }
                }
            }

            # Update logs
            if ($syncState.Logs.Count -gt 0) {
                $lines = [string[]]$syncState.Logs.ToArray()
                $newText = ($lines -join "`r`n")
                if ($txtLogOutput.Text -ne $newText) {
                    $txtLogOutput.Text = $newText
                    $scrLogs.ScrollToEnd()
                }
            }

            # Completion state
            if ($syncState.IsCompleted) {
                $timer.Stop()
                $txtFooterStatus.Text = "SETUP COMPLETED SUCCESSFULLY IN $([math]::Round($syncState.TotalMinutes, 2)) MINUTES!"
                $txtFooterStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#34D399")
                $btnFinish.Content = "Close Monitor"
                $btnFinish.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#059669")
                $btnFinish.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#ECFDF5")
                $btnFinish.IsEnabled = $true
            }
        })

        $btnFinish.Add_Click({
            $window.Close()
        })

        $timer.Start()
        $window.ShowDialog() | Out-Null
    })

    $global:BnBUIRunspace = $rs
    $global:BnBUIPowerShell = $ps
    $ps.BeginInvoke() | Out-Null
}

function Write-LivePhase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$PhaseNumber,

        [Parameter(Mandatory = $true)]
        [int]$TotalPhases,

        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $false)]
        [string]$Description = ""
    )

    $phaseHeader = "[$PhaseNumber/$TotalPhases] $Title"

    # Update GUI
    if ($global:BnBUIGuiEnabled -and $global:BnBUIState) {
        $global:BnBUIState.CurrentPhaseTitle = "Phase $PhaseNumber of $($TotalPhases): $Title"
        $global:BnBUIState.CurrentDetail = if ($Description) { $Description } else { "Executing pipeline phase..." }
    }

    # Vibrant Console Banner
    $border = "=" * 80
    Write-Host ""
    Write-Host $border -ForegroundColor Cyan
    Write-Host " PHASE $PhaseNumber/$TotalPhases : $($Title.ToUpper())" -ForegroundColor Yellow
    if ($Description) {
        Write-Host "   $Description" -ForegroundColor DarkGray
    }
    Write-Host $border -ForegroundColor Cyan
    Write-Host ""

    Write-LiveLog -Level STEP -Message "Starting Phase $PhaseNumber of $($TotalPhases): $Title"
}

function Write-LiveToolStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ToolId,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Running", "Success", "Skipped", "Failed")]
        [string]$Status,

        [Parameter(Mandatory = $false)]
        [string]$DisplayName = "",

        [Parameter(Mandatory = $false)]
        [string]$Detail = ""
    )

    $name = if ($DisplayName) { $DisplayName } else { $ToolId }

    if ($global:BnBUIGuiEnabled -and $global:BnBUIState) {
        $global:BnBUIState.ToolStatus[$ToolId] = $Status
        if ($Status -eq "Running") {
            $global:BnBUIState.CurrentToolName = "Processing: $name"
            if ($Detail) { $global:BnBUIState.CurrentDetail = $Detail }
        } elseif ($Status -eq "Success" -or $Status -eq "Skipped") {
            $global:BnBCompletedToolsCount++
            $total = if ($global:BnBSelectedToolsList.Count -gt 0) { $global:BnBSelectedToolsList.Count } else { 1 }
            $pct = [math]::Round(($global:BnBCompletedToolsCount / $total) * 100)
            $global:BnBUIState.OverallPercent = $pct
        }
    }

    # Colorful Console Status Line
    $badge = switch ($Status) {
        "Running" { " [RUNNING] " }
        "Success" { " [  DONE ] " }
        "Skipped" { " [SKIPPED] " }
        "Failed"  { " [ FAILED ] " }
    }
    $badgeColor = switch ($Status) {
        "Running" { "Cyan" }
        "Success" { "Green" }
        "Skipped" { "DarkYellow" }
        "Failed"  { "Red" }
    }

    Write-Host "$badge" -NoNewline -ForegroundColor $badgeColor
    Write-Host " $name" -NoNewline -ForegroundColor White
    if ($Detail) {
        Write-Host " - $Detail" -ForegroundColor DarkGray
    } else {
        Write-Host ""
    }
}

function Write-LiveLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "STEP", "DEBUG")]
        [string]$Level = "INFO"
    )

    # Relay to standard logger
    Write-Log -Level $Level -Message $Message

    # Relay to GUI log viewer (max 100 lines kept in ring buffer)
    if ($global:BnBUIGuiEnabled -and $global:BnBUIState) {
        $timeStr = Get-Date -Format "HH:mm:ss"
        $line = "[$timeStr] [$Level] $Message"
        $logs = $global:BnBUIState.Logs
        if ($logs.Count -ge 120) {
            $logs.RemoveAt(0)
        }
        $logs.Add($line) | Out-Null
    }
}

function Complete-ProgressUI {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [double]$TotalMinutes
    )

    if ($global:BnBUIGuiEnabled -and $global:BnBUIState) {
        $global:BnBUIState.OverallPercent = 100
        $global:BnBUIState.TotalMinutes = $TotalMinutes
        $global:BnBUIState.CurrentToolName = "Provisioning Finished!"
        $global:BnBUIState.CurrentDetail = "All selected development runtimes and tools are active."
        $global:BnBUIState.IsCompleted = $true
    }

    $border = "=" * 80
    Write-Host ""
    Write-Host $border -ForegroundColor Green
    Write-Host "    BURNANDBUILD SETUP COMPLETED IN $([math]::Round($TotalMinutes, 2)) MINUTES!" -ForegroundColor Green
    Write-Host $border -ForegroundColor Green
    Write-Host ""
}

Export-ModuleMember -Function Initialize-ProgressUI, Write-LivePhase, Write-LiveToolStatus, Write-LiveLog, Complete-ProgressUI
