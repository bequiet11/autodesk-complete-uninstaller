using System.ComponentModel;
using System.IO;
using System.Security.Principal;
using System.Threading;
using System.Windows;
using System.Windows.Threading;
using AutodeskCleaner.Localization;
using AutodeskCleaner.Services;

namespace AutodeskCleaner;

public partial class App : Application
{
    private Mutex? _singleInstanceMutex;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        DispatcherUnhandledException += OnDispatcherUnhandledException;
        AppDomain.CurrentDomain.UnhandledException += (_, args) =>
            WriteCrash(args.ExceptionObject as Exception, "AppDomain");
        TaskScheduler.UnobservedTaskException += (_, args) =>
        {
            WriteCrash(args.Exception, "TaskScheduler");
            args.SetObserved();
        };

        var args = e.Args;
        var isSelfTest = args.Any(a => string.Equals(a, "--self-test", StringComparison.OrdinalIgnoreCase));
        if (isSelfTest)
        {
            var ok = SelfTest.Run();
            Shutdown(ok ? 0 : 1);
            return;
        }

        var allowNonAdmin = args.Any(a => string.Equals(a, "--allow-nonadmin", StringComparison.OrdinalIgnoreCase));
        if (!AdminHelper.IsAdministrator)
        {
            if (!allowNonAdmin)
            {
                if (AdminHelper.TryRelaunchElevated(args))
                {
                    Shutdown();
                    return;
                }

                MessageBox.Show(
                    "Autodesk Cleaner membutuhkan hak Administrator untuk membersihkan Autodesk.\n\n" +
                    "Administrator privileges are required to remove Autodesk products and remnants.\n\n" +
                    "Klik OK, lalu setujui prompt UAC saat aplikasi dibuka kembali.\n" +
                    "Click OK, then approve the UAC prompt when the app reopens.",
                    "Autodesk Cleaner", MessageBoxButton.OK, MessageBoxImage.Warning);
                Shutdown(1);
                return;
            }
        }

        _singleInstanceMutex = new Mutex(true, @"Local\AutodeskCleaner.SingleInstance", out var createdNew);
        if (!createdNew)
        {
            MessageBox.Show(
                "Autodesk Cleaner sudah berjalan.\nAutodesk Cleaner is already running.",
                "Autodesk Cleaner", MessageBoxButton.OK, MessageBoxImage.Information);
            Shutdown();
            return;
        }

        var settings = SettingsService.Load();
        Loc.Instance.SetLanguage(settings.Language);

        var window = new MainWindow(settings);
        MainWindow = window;
        ShutdownMode = ShutdownMode.OnMainWindowClose;
        window.Show();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _singleInstanceMutex?.Dispose();
        base.OnExit(e);
    }

    private void OnDispatcherUnhandledException(object sender, DispatcherUnhandledExceptionEventArgs e)
    {
        WriteCrash(e.Exception, "Dispatcher");
        MessageBox.Show(
            "Terjadi kesalahan tak terduga / An unexpected error occurred:\n\n" + e.Exception.Message +
            "\n\nLog: " + AppPaths.CrashLog,
            "Autodesk Cleaner", MessageBoxButton.OK, MessageBoxImage.Error);
        e.Handled = true;
    }

    private static void WriteCrash(Exception? ex, string source)
    {
        try
        {
            Directory.CreateDirectory(AppPaths.DataDir);
            File.AppendAllText(AppPaths.CrashLog,
                $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {source}{Environment.NewLine}{ex}{Environment.NewLine}{new string('-', 70)}{Environment.NewLine}");
        }
        catch
        {
            // Never let crash logging mask the original failure.
        }
    }
}
