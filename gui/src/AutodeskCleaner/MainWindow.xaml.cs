using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Windows;
using System.Windows.Data;
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
    }

    private void OnFilterProducts(object sender, FilterEventArgs e)
    {
        var product = (AutodeskProduct)e.Item;
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

        EmptyState.Visibility = count == 0 ? Visibility.Visible : Visibility.Collapsed;
        ProductList.Visibility = count == 0 ? Visibility.Collapsed : Visibility.Visible;
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
        var selected = ProductList.SelectedItems.Cast<AutodeskProduct>()
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
        FullCleanButton.IsEnabled = false;
        DeepCleanButton.IsEnabled = false;
    }

    private void EndAction()
    {
        _activeCancellation?.Dispose();
        _activeCancellation = null;
        _isBusy = false;
        StopButton.Visibility = Visibility.Collapsed;
        RescanButton.IsEnabled = true;
        UninstallSelectedButton.IsEnabled = true;
        FullCleanButton.IsEnabled = true;
        DeepCleanButton.IsEnabled = true;
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
