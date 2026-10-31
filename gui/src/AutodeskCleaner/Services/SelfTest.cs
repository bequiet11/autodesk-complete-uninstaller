using System.IO;
using System.Text;
using System.Windows;
using AutodeskCleaner;
using AutodeskCleaner.Localization;
using AutodeskCleaner.Models;

namespace AutodeskCleaner.Services;

/// <summary>
/// Headless smoke test used by --self-test. It never needs UAC and never touches
/// Autodesk products; it only proves that the embedded engine, localization,
/// theme resources, and registry scanner are wired correctly.
/// </summary>
public static class SelfTest
{
    public static bool Run()
    {
        var lines = new List<string>();
        var failures = 0;

        void Check(string name, Func<bool> test)
        {
            try
            {
                if (test())
                {
                    lines.Add($"PASS  {name}");
                }
                else
                {
                    failures++;
                    lines.Add($"FAIL  {name}");
                }
            }
            catch (Exception ex)
            {
                failures++;
                lines.Add($"FAIL  {name} -> {ex.GetType().Name}: {ex.Message}");
            }
        }

        lines.Add("Autodesk Cleaner self-test");
        lines.Add($"Time: {DateTime.Now:yyyy-MM-dd HH:mm:ss}");
        lines.Add($"Base: {AppContext.BaseDirectory}");
        lines.Add($"OS:   {Environment.OSVersion}");
        lines.Add(new string('-', 78));

        var originalLanguage = Loc.Instance.Language;

        Check("Embedded cleanup engine is present", () =>
        {
            var path = EngineService.EnsureEngineExtracted();
            return File.Exists(path) && new FileInfo(path).Length > 100_000;
        });

        Check("Engine exposes the GUI headless dispatcher", () =>
        {
            var text = File.ReadAllText(AppPaths.EnginePath);
            return text.Contains(":gui_bootstrap", StringComparison.Ordinal)
                && text.Contains("ADSK_GUI_ACTION", StringComparison.Ordinal)
                && text.Contains("ADSK_GUI_PID", StringComparison.Ordinal)
                && text.Contains("ProcessId <>", StringComparison.Ordinal)
                && text.Contains(":GUI_PAUSE", StringComparison.Ordinal)
                && text.Contains(":GUI_WAIT", StringComparison.Ordinal);
        });

        Check("Localization dictionaries have identical keys", () =>
        {
            var missingInEn = Loc.Id.Keys.Except(Loc.En.Keys).ToList();
            var missingInId = Loc.En.Keys.Except(Loc.Id.Keys).ToList();
            return missingInEn.Count == 0 && missingInId.Count == 0;
        });

        Check("Language switch updates strings", () =>
        {
            Loc.Instance.SetLanguage("en");
            var english = Loc.Instance["Settings_Title"];
            Loc.Instance.SetLanguage("id");
            var indonesian = Loc.Instance["Settings_Title"];
            return english == "Settings" && indonesian == "Pengaturan";
        });

        Check("Theme resources are loaded", () =>
            Application.Current?.TryFindResource("PrimaryButton") is not null
            && Application.Current?.TryFindResource("CardBorder") is not null
            && Application.Current?.TryFindResource("SidebarNavRadio") is not null);

        Check("Product dashboard can be constructed", () =>
        {
            var window = new MainWindow(new SettingsService());
            var productTemplate = (DataTemplate)window.FindResource("ProductItemTemplate");
            _ = productTemplate.LoadContent();
            return true;
        });

        Check("App icon resources are embedded", () =>
            Application.GetResourceStream(new Uri("pack://application:,,,/Assets/app.png")) is not null
            && Application.GetResourceStream(new Uri("pack://application:,,,/Assets/app.ico")) is not null
            && Application.GetResourceStream(new Uri("pack://application:,,,/Assets/Autodesk.ico")) is not null);

        Check("Product scanner can enumerate the registry", () =>
        {
            var products = new ProductScanner().Scan();
            lines.Add($"      Detected {products.Count} Autodesk product(s):");
            foreach (var product in products.Take(10))
            {
                lines.Add($"        - {product.DisplayName} [{product.TypeLabel}]");
            }

            return products.All(p => !string.IsNullOrWhiteSpace(p.DisplayName));
        });

        Check("Product model formats paths and sizes", () =>
        {
            var product = new AutodeskProduct
            {
                DisplayName = "Autodesk AutoCAD 2026",
                Version = "R25.0",
                Publisher = "Autodesk",
                UninstallString = "MsiExec.exe /X{00000000-0000-0000-0000-000000000000}",
                Method = InstallMethod.Msi,
                SizeBytes = 1024L * 1024 * 512,
                Priority = 3,
            };

            return product.Initial == "A"
                && product.TypeLabel == "MSI"
                && product.SizeText.Contains("MB", StringComparison.Ordinal);
        });

        Check("Engine log folder path matches the batch script", () =>
            AppPaths.EngineLogDir.EndsWith(Path.Combine("Desktop", "Autodesk_Uninstaller"), StringComparison.OrdinalIgnoreCase));

        Loc.Instance.SetLanguage(originalLanguage);

        lines.Add(new string('-', 78));
        lines.Add(failures == 0 ? "RESULT: PASS" : $"RESULT: FAIL ({failures} check(s) failed)");

        try
        {
            var target = Path.Combine(Path.GetTempPath(), "autodesk_cleaner_selftest.txt");
            File.WriteAllText(target, string.Join(Environment.NewLine, lines), Encoding.UTF8);
            Console.WriteLine(string.Join(Environment.NewLine, lines));
        }
        catch
        {
            // The exit code still communicates the result.
        }

        return failures == 0;
    }
}
