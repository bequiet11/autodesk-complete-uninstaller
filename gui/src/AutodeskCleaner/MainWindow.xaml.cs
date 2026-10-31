using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.Linq;
using System.Windows;
using System.Windows.Data;
using System.Windows.Media;
using AutodeskCleaner.Localization;
using AutodeskCleaner.Models;
using AutodeskCleaner.Services;

namespace AutodeskCleaner;

public partial class MainWindow : Window
{
    private const int MaxLogCharacters = 250_000;

    private readonly SettingsService _settings;
    private readonly ObservableCollection<AutodeskProduct> _products = new();
    private readonly CollectionViewSource _viewSource = new();
    private CancellationTokenSource? _activeCancellation;
    private string _searchText = string.Empty;
    private bool _isBusy;
    private bool _showTools;

    public ICollectionView ProductsView => _viewSource.View;

    public MainWindow(SettingsService settings)
    {
        _settings = settings;
        InitializeComponent();
        DataContext = this;
        WindowState = settings.StartMaximized ? WindowState.Maximized : WindowState.Normal;

        _viewSource.Source = _products;
        _viewSource.Filter += OnFilterProducts;
        Loaded += MainWindow_Loaded;
        SearchBox.Text = string.Empty;
        UpdateLanguageButton();
        UpdateAdminStatus();
        UpdateSummary();
    }

    private async void MainWindow_Loaded(object sender, RoutedEventArgs e)
    {
        await RunEngineActionAsync(EngineAction.Scan, Loc.Instance["Activity_Scanning"]);
    }

    private async void Rescan_Click(object sender, RoutedEventArgs e)
    {
        await RunEngineActionAsync(EngineAction.Scan, Loc.Instance["Activity_Scanning"]);
    }

    private void SearchBox_TextChanged(object sender, System.Windows.Controls.TextChangedEventArgs e)
    {
        _searchText = SearchBox.Text ?? string.Empty;
        _viewSource.View.Refresh();
        UpdateProductListState();
    }

    private void OnFilterProducts(object sender, FilterEventArgs e)
    {
        var product = (AutodeskProduct)e.Item;
        var filter = FilterBox.SelectedIndex;
        if (filter == 1 && !product.IsOrphan
            || filter == 2 && product.Method != InstallMethod.Odis
            || filter == 3 && product.Method != InstallMethod.Msi)
        {
            e.Accepted = false;
            return;
        }

        if (string.IsNullOrWhiteSpace(_searchText))
        {
            e.Accepted = true;
            return;
        }

        var query = _searchText.Trim();
        e.Accepted = product.DisplayName.Contains(query, StringComparison.OrdinalIgnoreCase)
            || product.Version.Contains(query, StringComparison.OrdinalIgnoreCase)
            || product.TypeLabel.Contains(query, StringComparison.OrdinalIgnoreCase)
            || product.Publisher.Contains(query, StringComparison.OrdinalIgnoreCase);
    }

    private async Task RefreshProductsAsync()
    {
        var products = await Task.Run(() => new ProductScanner().Scan());
        _products.Clear();
        foreach (var product in products)
        {
            _products.Add(product);
        }

        UpdateSummary();
        _viewSource.View.Refresh();
    }

    private void UpdateSummary()
    {
        var count = _products.Count;
        var totalSize = _products.Sum(product => product.SizeBytes ?? 0);
        var orphanCount = _products.Count(product => product.IsOrphan);

        ProductsCountText.Text = count.ToString();
        TotalSizeText.Text = FormatSize(totalSize);
        RemnantsText.Text = orphanCount.ToString();
        LastScanText.Text = DateTime.Now.ToString("dd MMM yyyy");

        UpdateSelectionSummary();
        UpdateProductListState();
    }

    private void UpdateProductListState()
    {
        var visibleCount = _viewSource.View?.Cast<object>().Count() ?? 0;
        var noProducts = _products.Count == 0;
        EmptyState.Visibility = visibleCount == 0 ? Visibility.Visible : Visibility.Collapsed;
        ProductItems.Visibility = visibleCount == 0 ? Visibility.Collapsed : Visibility.Visible;
        EmptyTitleText.Text = Loc.Instance[noProducts ? "Empty_Title" : "Empty_Search_Title"];
        EmptyBodyText.Text = Loc.Instance[noProducts ? "Empty_Body" : "Empty_Search_Body"];
        FilteredCountText.Text = visibleCount.ToString();
    }

    private static string FormatSize(long bytes)
    {
        if (bytes <= 0)
        {
            return "0 MB";
        }

        var value = bytes / (1024d * 1024d);
        return value >= 1024 ? $"{value / 1024d:0.0} GB" : $"{value:0.0} MB";
    }

    private async void UninstallSelected_Click(object sender, RoutedEventArgs e)
    {
        var selected = _products.Where(product => product.IsSelected)
            .OrderBy(product => product.Priority)
            .ThenBy(product => product.DisplayName, StringComparer.CurrentCultureIgnoreCase)
            .ToList();
        if (selected.Count == 0)
        {
            MessageBox.Show(this, Loc.Instance["Uninstall_NoSelection"],
                Loc.Instance["AppName"], MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        var names = string.Join(Environment.NewLine, selected.Select(product => "• " + product.DisplayName));
        var answer = MessageBox.Show(this,
            $"{Loc.Instance["Confirm_Selected_Desc"]}{Environment.NewLine}{Environment.NewLine}{names}{Environment.NewLine}{Environment.NewLine}{Loc.Instance["Confirm_Selected_Warning"]}",
            Loc.Instance["Confirm_Selected_Title"], MessageBoxButton.YesNo, MessageBoxImage.Warning, MessageBoxResult.No);
        if (answer != MessageBoxResult.Yes)
        {
            return;
        }

        BeginAction(Loc.Instance["Progress_Preparing"]);
        var progress = CreateProgress();
        var uninstaller = new SelectedUninstaller();
        try
        {
            await uninstaller.PrepareAsync(progress, _activeCancellation!.Token);
            var results = await uninstaller.RunAsync(selected, progress, _activeCancellation.Token);
            var succeeded = results.Count(result => result.Success);
            var failed = results.Count(result => !result.Success && !result.Cancelled);
            AppendLog(Loc.Instance.Format("Result_SelectedSummary", succeeded, failed));
            if (!string.IsNullOrWhiteSpace(uninstaller.LastLogFolder))
            {
                AppendLog($"Run logs: {uninstaller.LastLogFolder}");
            }

            ActionStatusText.Text = failed == 0 ? "Uninstall complete" : "Completed with errors";
            await RefreshProductsAsync();
        }
        catch (OperationCanceledException)
        {
            ActionStatusText.Text = "Stopped";
            AppendLog("Uninstall stopped by user.");
        }
        catch (Exception ex)
        {
            ActionStatusText.Text = "Uninstall failed";
            AppendLog("Uninstall failed: " + ex.Message);
        }
        finally
        {
            EndAction();
        }
    }

    private async void FullClean_Click(object sender, RoutedEventArgs e)
    {
        var answer = MessageBox.Show(this,
            $"{Loc.Instance["Confirm_Full_Desc"]}{Environment.NewLine}{Environment.NewLine}{Loc.Instance["Confirm_Full_Warning"]}",
            Loc.Instance["Confirm_Full_Title"],
            MessageBoxButton.YesNo, MessageBoxImage.Warning, MessageBoxResult.No);
        if (answer == MessageBoxResult.Yes)
        {
            await RunEngineActionAsync(EngineAction.Full, Loc.Instance["Activity_Starting"]);
        }
    }

    private async void DeepClean_Click(object sender, RoutedEventArgs e)
    {
        var answer = MessageBox.Show(this,
            $"{Loc.Instance["Confirm_Deep_Desc"]}{Environment.NewLine}{Environment.NewLine}{Loc.Instance["Confirm_Deep_Warning"]}",
            Loc.Instance["Confirm_Deep_Title"],
            MessageBoxButton.YesNo, MessageBoxImage.Warning, MessageBoxResult.No);
        if (answer == MessageBoxResult.Yes)
        {
            await RunEngineActionAsync(EngineAction.Deep, Loc.Instance["Activity_Starting"]);
        }
    }

    private void ProductsNav_Click(object sender, RoutedEventArgs e) => ShowPage(tools: false);

    private void ToolsNav_Click(object sender, RoutedEventArgs e) => ShowPage(tools: true);

    private void ShowPage(bool tools)
    {
        _showTools = tools;
        ProductsPage.Visibility = tools ? Visibility.Collapsed : Visibility.Visible;
        ToolsPage.Visibility = tools ? Visibility.Visible : Visibility.Collapsed;
        PageTitleText.Text = Loc.Instance[tools ? "Tools_Title" : "Products_Title"];
        PageSubtitleText.Text = Loc.Instance[tools ? "Tools_Subtitle" : "Products_Subtitle"];

        ProductsNavButton.Background = FindResource(tools ? "SidebarBrush" : "SidebarActiveBrush") as Brush;
        ProductsNavButton.Foreground = FindResource("SidebarTextBrush") as Brush;
        ToolsNavButton.Background = FindResource(tools ? "SidebarActiveBrush" : "SidebarBrush") as Brush;
        ToolsNavButton.Foreground = FindResource("SidebarTextBrush") as Brush;

        RescanButton.Visibility = tools ? Visibility.Collapsed : Visibility.Visible;
        UninstallSelectedButton.Visibility = tools ? Visibility.Collapsed : Visibility.Visible;
    }

    private void ProductSelectionChanged(object sender, RoutedEventArgs e) => UpdateSelectionSummary();

    private void FilterBox_SelectionChanged(object sender, System.Windows.Controls.SelectionChangedEventArgs e)
    {
        if (_viewSource.Source is not null)
        {
            _viewSource.View.Refresh();
            UpdateProductListState();
        }
    }

    private void SelectAll_Click(object sender, RoutedEventArgs e)
    {
        var visibleProducts = _viewSource.View.Cast<AutodeskProduct>().ToList();
        var select = visibleProducts.Any(product => !product.IsSelected);
        foreach (var product in visibleProducts)
        {
            product.IsSelected = select;
        }

        UpdateSelectionSummary();
    }

    private void UpdateSelectionSummary()
    {
        if (SelectedCountText is null)
        {
            return;
        }

        var selected = _products.Count(product => product.IsSelected);
        SelectedCountText.Text = Loc.Instance.Format("SelectedCount", selected);
        var visibleProducts = _viewSource.View.Cast<AutodeskProduct>().ToList();
        SelectAllButton.Content = Loc.Instance[visibleProducts.Count > 0 && visibleProducts.All(product => product.IsSelected)
            ? "DeselectAll"
            : "SelectAll"];
        UninstallSelectedButton.IsEnabled = !_isBusy && selected > 0;
    }

    private void Language_Click(object sender, RoutedEventArgs e)
    {
        Loc.Instance.SetLanguage(Loc.Instance.IsEnglish ? "id" : "en");
        _settings.Language = Loc.Instance.Language;
        _settings.Save();
        UpdateLanguageButton();
        UpdateAdminStatus();
        UpdateSummary();
        ShowPage(_showTools);
    }

    private void UpdateLanguageButton()
    {
        LanguageButton.Content = Loc.Instance.IsEnglish ? "ID" : "EN";
        LanguageButton.ToolTip = Loc.Instance["Language_Switch_Tooltip"];
        Title = Loc.Instance["Window_Title"];
    }

    private void UpdateAdminStatus()
    {
        AdminStatusText.Text = AdminHelper.IsAdministrator
            ? Loc.Instance["Sidebar_Admin"]
            : Loc.Instance["Sidebar_AdminNo"];
    }

    private async void Audit_Click(object sender, RoutedEventArgs e)
        => await RunToolWithConfirmationAsync(EngineAction.Audit);

    private async void Verify_Click(object sender, RoutedEventArgs e)
        => await RunToolWithConfirmationAsync(EngineAction.Verify);

    private async void Remnants_Click(object sender, RoutedEventArgs e)
        => await RunToolWithConfirmationAsync(EngineAction.Remnants);

    private async void Restore_Click(object sender, RoutedEventArgs e)
        => await RunToolWithConfirmationAsync(EngineAction.Restore);

    private async void Error103_Click(object sender, RoutedEventArgs e)
        => await RunToolWithConfirmationAsync(EngineAction.Error103);

    private async void Reboot_Click(object sender, RoutedEventArgs e)
        => await RunToolWithConfirmationAsync(EngineAction.Reboot);

    private async void Backup_Click(object sender, RoutedEventArgs e)
        => await RunToolWithConfirmationAsync(EngineAction.Backup);

    private void OpenLogs_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = AppPaths.EngineLogDir,
                UseShellExecute = true,
            });
        }
        catch (Exception ex)
        {
            MessageBox.Show(this, Loc.Instance.Format("Error_OpenFolder", ex.Message),
                Loc.Instance["Error_Title"], MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private async Task RunToolWithConfirmationAsync(EngineAction action)
    {
        var (titleKey, descriptionKey, warningKey) = action switch
        {
            EngineAction.Audit => ("Confirm_Audit_Title", "Confirm_Audit_Desc", (string?)null),
            EngineAction.Verify => ("Confirm_Verify_Title", "Confirm_Verify_Desc", (string?)null),
            EngineAction.Remnants => ("Confirm_Remnants_Title", "Confirm_Remnants_Desc", (string?)null),
            EngineAction.Restore => ("Confirm_Restore_Title", "Confirm_Restore_Desc", (string?)null),
            EngineAction.Error103 => ("Confirm_Error103_Title", "Confirm_Error103_Desc", "Confirm_Error103_Warning"),
            EngineAction.Reboot => ("Confirm_Reboot_Title", "Confirm_Reboot_Desc", (string?)null),
            EngineAction.Backup => ("Confirm_Backup_Title", "Confirm_Backup_Desc", (string?)null),
            _ => throw new ArgumentOutOfRangeException(nameof(action), action, "Unsupported tool action."),
        };

        var message = Loc.Instance[descriptionKey];
        if (warningKey is not null)
        {
            message += Environment.NewLine + Environment.NewLine + Loc.Instance[warningKey];
        }

        if (MessageBox.Show(this, message, Loc.Instance[titleKey], MessageBoxButton.YesNo,
                action is EngineAction.Error103 or EngineAction.Reboot ? MessageBoxImage.Warning : MessageBoxImage.Information,
                MessageBoxResult.No) != MessageBoxResult.Yes)
        {
            return;
        }

        var statusKey = action switch
        {
            EngineAction.Audit => "Tool_Audit_Title",
            EngineAction.Verify => "Verify",
            EngineAction.Remnants => "Tool_Remnants_Title",
            EngineAction.Restore => "Tool_Restore_Title",
            EngineAction.Error103 => "Tool_Error103_Title",
            EngineAction.Reboot => "Tool_Reboot_Title",
            EngineAction.Backup => "Tool_Backup_Title",
            _ => "Activity_Starting",
        };

        await RunEngineActionAsync(action, Loc.Instance[statusKey]);
    }

    private async Task RunEngineActionAsync(EngineAction action, string status)
    {
        if (_isBusy)
        {
            return;
        }

        BeginAction(status);
        try
        {
            var environment = CreateActionEnvironment(action);
            var result = await new EngineService().RunAsync(
                action, environment, CreateProgress(), _activeCancellation!.Token);

            if (result.Cancelled)
            {
                ActionStatusText.Text = "Stopped";
                AppendLog(Loc.Instance["Result_Stopped"]);
            }
            else if (result.TimedOut)
            {
                ActionStatusText.Text = "Timed out";
                AppendLog(Loc.Instance["Result_TimedOut"]);
            }
            else if (result.ExitCode != 0)
            {
                ActionStatusText.Text = $"Failed (exit {result.ExitCode})";
                AppendLog(Loc.Instance.Format("Result_EngineFail", result.ExitCode));
            }
            else
            {
                ActionStatusText.Text = "Completed";
                var resultKey = action switch
                {
                    EngineAction.Full => "Result_FullClean",
                    EngineAction.Deep => "Result_DeepClean",
                    EngineAction.Verify => "Result_Verify",
                    EngineAction.Audit => "Result_Audit",
                    EngineAction.Remnants => "Result_Remnants",
                    EngineAction.Restore => "Result_Restore",
                    EngineAction.Error103 => "Result_Error103",
                    EngineAction.Reboot => "Result_Reboot",
                    EngineAction.Backup => "Result_Backup",
                    _ => "Result_Scan",
                };
                AppendLog($"{Loc.Instance[resultKey]} ({result.Elapsed:mm\\:ss})");
            }

            if (!string.IsNullOrWhiteSpace(result.ArchiveFolder))
            {
                AppendLog($"Run logs: {result.ArchiveFolder}");
            }

            if (action is EngineAction.Scan or EngineAction.Full or EngineAction.Deep)
            {
                await RefreshProductsAsync();
            }
        }
        catch (OperationCanceledException)
        {
            ActionStatusText.Text = "Stopped";
            AppendLog(Loc.Instance["Result_Stopped"]);
        }
        catch (Exception ex)
        {
            ActionStatusText.Text = "Action failed";
            AppendLog("Action failed: " + ex.Message);
        }
        finally
        {
            EndAction();
        }
    }

    private Dictionary<string, string> CreateActionEnvironment(EngineAction action)
    {
        var environment = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        var yes = "Y";
        var no = "N";

        switch (action)
        {
            case EngineAction.Full:
                environment["FC_CONF"] = "YES";
                environment["FC_INST"] = _settings.DefaultRemoveInstallers ? yes : no;
                environment["DTC_ANS"] = no;
                environment["RP_ASK"] = _settings.DefaultCreateRestorePoint ? yes : no;
                environment["BACKUP_CHOICE"] = _settings.DefaultBackupTemplates ? yes : no;
                environment["DEL_FLEX"] = no;
                break;
            case EngineAction.Deep:
                environment["DC_CONF"] = "YES";
                environment["DC_INST"] = _settings.DefaultRemoveInstallers ? yes : no;
                environment["DTC_ANS"] = no;
                environment["DC_RP"] = _settings.DefaultCreateRestorePoint ? yes : no;
                environment["DEL_FLEX"] = no;
                break;
            case EngineAction.Restore:
                environment["RP_CONF"] = yes;
                environment["SR_ENABLE"] = no;
                break;
            case EngineAction.Backup:
                environment["BK_GO"] = yes;
                break;
            case EngineAction.Error103:
                environment["E103_R1"] = no;
                environment["E103_R2"] = no;
                environment["E103_R3"] = no;
                environment["E103_R4"] = no;
                environment["E103_R5"] = no;
                environment["E103_R10"] = no;
                environment["E103_RBOOT"] = no;
                break;
        }

        return environment;
    }

    private IProgress<EngineEvent> CreateProgress()
        => new Progress<EngineEvent>(evt =>
        {
            if (evt.Kind == EngineEventKind.Status)
            {
                ActionStatusText.Text = evt.Text;
            }
            else
            {
                AppendLog(evt.Text);
            }
        });

    private void BeginAction(string status)
    {
        _isBusy = true;
        _activeCancellation = new CancellationTokenSource();
        LogTextBox.Text = string.Empty;
        ActionStatusText.Text = status;
        StopButton.Visibility = Visibility.Visible;
        RescanButton.IsEnabled = false;
        UninstallSelectedButton.IsEnabled = false;
        SelectAllButton.IsEnabled = false;
    }

    private void EndAction()
    {
        _activeCancellation?.Dispose();
        _activeCancellation = null;
        _isBusy = false;
        StopButton.Visibility = Visibility.Collapsed;
        RescanButton.IsEnabled = true;
        UninstallSelectedButton.IsEnabled = true;
        SelectAllButton.IsEnabled = true;
        UpdateSelectionSummary();
    }

    private void Stop_Click(object sender, RoutedEventArgs e)
    {
        _activeCancellation?.Cancel();
        ActionStatusText.Text = "Stopping...";
    }

    private void AppendLog(string line)
    {
        var text = string.IsNullOrEmpty(LogTextBox.Text)
            ? line
            : LogTextBox.Text + Environment.NewLine + line;
        if (text.Length > MaxLogCharacters)
        {
            text = text[^MaxLogCharacters..];
        }

        LogTextBox.Text = text;
        LogScrollViewer.ScrollToEnd();
    }
}
