using System.Diagnostics;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using AutodeskCleaner.Localization;
using AutodeskCleaner.Models;

namespace AutodeskCleaner.Services;

public sealed record ProductUninstallResult(
    AutodeskProduct Product,
    bool Success,
    int ExitCode,
    string Message,
    bool Cancelled = false);

/// <summary>
/// Native port of the engine's "Uninstall Selected" menu path. Keeping this in
/// C# lets the GUI stream progress per product without starting the whole batch
/// engine, while still using the exact same ODIS / MSI / legacy commands.
/// </summary>
public sealed class SelectedUninstaller
{
    private const string OdisInstaller = @"C:\Program Files\Autodesk\AdODIS\V1\Installer.exe";

    private static readonly string[] KnownProcesses =
    {
        "AdSSO.exe", "AdskLicensingService.exe", "AdskLicensingAgent.exe", "AdskIdentityManager.exe",
        "GenuineService.exe", "AdAppMgrSvc.exe", "AutodeskDesktopApp.exe", "RevitAccelerator.exe",
        "acad.exe", "lmgrd.exe", "adskflex.exe", "AdskAccessServiceHost.exe", "AdskAccessService.exe",
        "AdskAccessCore.exe", "ADPClientService.exe", "AcEventSync.exe", "FNPLicensingService64.exe",
        "Installer.exe", "setup.exe", "AdODIS.exe", "DesktopConnector.Applications.Tray.exe",
        "DesktopConnector.Core.Service.exe", "AdskAccessUIHost.exe",
    };

    private static readonly string[] KnownServices =
    {
        "AdskLicensingService", "AdskAccessServiceHost", "AdAppMgrSvc", "AdskNLM",
        "DesktopConnectorService", "FlexNet Licensing Service 64", "Autodesk Genuine Service",
    };

    public string? LastLogFolder { get; private set; }

    public async Task PrepareAsync(IProgress<EngineEvent>? progress, CancellationToken cancellationToken)
    {
        progress?.Report(new EngineEvent(EngineEventKind.Line, "Stopping Autodesk services..."));
        foreach (var service in KnownServices)
        {
            cancellationToken.ThrowIfCancellationRequested();
            await RunQuietAsync("sc.exe", $"stop \"{service}\"", TimeSpan.FromSeconds(20), cancellationToken)
                .ConfigureAwait(false);
        }

        progress?.Report(new EngineEvent(EngineEventKind.Line, "Closing Autodesk applications..."));
        foreach (var process in KnownProcesses)
        {
            cancellationToken.ThrowIfCancellationRequested();
            await RunQuietAsync("taskkill.exe", $"/f /im \"{process}\"", TimeSpan.FromSeconds(10), cancellationToken)
                .ConfigureAwait(false);
        }

        try
        {
            await Task.Delay(TimeSpan.FromSeconds(2), cancellationToken).ConfigureAwait(false);
        }
        catch (OperationCanceledException)
        {
            // Cancellation is checked by the caller.
        }
    }

    public async Task<IReadOnlyList<ProductUninstallResult>> RunAsync(
        IReadOnlyList<AutodeskProduct> products,
        IProgress<EngineEvent>? progress,
        CancellationToken cancellationToken)
    {
        var results = new List<ProductUninstallResult>();
        var log = new StringBuilder();
        LastLogFolder = AppPaths.CreateHistoryFolder("selected");
        log.AppendLine($"Selected product uninstall - {DateTime.Now:yyyy-MM-dd HH:mm:ss}");
        log.AppendLine(new string('-', 70));

        for (var index = 0; index < products.Count; index++)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var product = products[index];
            var position = Loc.Instance.Format("Progress_Uninstalling", index + 1, products.Count, product.DisplayName);
            progress?.Report(new EngineEvent(EngineEventKind.Status, position));
            progress?.Report(new EngineEvent(EngineEventKind.Line, string.Empty));
            progress?.Report(new EngineEvent(EngineEventKind.Line, $"=== {product.DisplayName} ({product.TypeLabel}) ==="));

            log.AppendLine($"PRODUCT: {product.DisplayName}");
            log.AppendLine($"  Type: {product.TypeLabel}");
            log.AppendLine($"  Uninstall: {product.UninstallString}");

            ProductUninstallResult result;
            try
            {
                result = await UninstallOneAsync(product, progress, cancellationToken).ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
                result = new ProductUninstallResult(product, false, -1, "Cancelled by user", Cancelled: true);
                results.Add(result);
                log.AppendLine("  RESULT: CANCELLED");
                break;
            }
            catch (Exception ex)
            {
                result = new ProductUninstallResult(product, false, -1, ex.Message);
            }

            results.Add(result);
            log.AppendLine($"  RESULT: {(result.Success ? "OK" : "FAIL")} ({result.ExitCode}) {result.Message}");
            log.AppendLine();

            var status = result.Success ? "[OK]" : "[FAIL]";
            progress?.Report(new EngineEvent(EngineEventKind.Line, $"  {status} {result.Message}"));
        }

        log.AppendLine(new string('-', 70));
        log.AppendLine($"Removed: {results.Count(r => r.Success)}   Failed: {results.Count(r => !r.Success && !r.Cancelled)}");

        try
        {
            File.WriteAllText(Path.Combine(LastLogFolder, "selected_uninstall.txt"), log.ToString());
            File.WriteAllText(Path.Combine(LastLogFolder, "ui_run_info.txt"),
                $"Action: selected-products{Environment.NewLine}" +
                $"Started: {DateTime.Now:yyyy-MM-dd HH:mm:ss}{Environment.NewLine}" +
                $"Products: {products.Count}{Environment.NewLine}" +
                $"Removed: {results.Count(r => r.Success)}{Environment.NewLine}" +
                $"Failed: {results.Count(r => !r.Success && !r.Cancelled)}{Environment.NewLine}");
        }
        catch
        {
            // Logging must never break the uninstall flow.
        }

        return results;
    }

    private static async Task<ProductUninstallResult> UninstallOneAsync(
        AutodeskProduct product,
        IProgress<EngineEvent>? progress,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(product.UninstallString))
        {
            return new ProductUninstallResult(product, false, -1, "No UninstallString. Use Control Panel instead.");
        }

        try
        {
            return product.Method switch
            {
                InstallMethod.Odis => await UninstallOdisAsync(product, progress, cancellationToken).ConfigureAwait(false),
                InstallMethod.Msi => await UninstallMsiAsync(product, progress, cancellationToken).ConfigureAwait(false),
                InstallMethod.LegacySetup => await UninstallLegacyAsync(product, progress, cancellationToken).ConfigureAwait(false),
                _ => await UninstallGenericAsync(product, progress, cancellationToken).ConfigureAwait(false),
            };
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception ex)
        {
            return new ProductUninstallResult(product, false, -1, ex.Message);
        }
    }

    private static async Task<ProductUninstallResult> UninstallOdisAsync(
        AutodeskProduct product,
        IProgress<EngineEvent>? progress,
        CancellationToken cancellationToken)
    {
        var args = BuildOdisArguments(product.UninstallString);
        progress?.Report(new EngineEvent(EngineEventKind.Line, "  [ODIS] Running installer (this can take 1-2 minutes)..."));

        if (File.Exists(OdisInstaller))
        {
            var run = await RunProcessAsync(OdisInstaller, args, progress, TimeSpan.FromMinutes(20), cancellationToken)
                .ConfigureAwait(false);
            return Evaluate(product, run, run.ExitCode == 0);
        }

        progress?.Report(new EngineEvent(EngineEventKind.Line, "  [ODIS] AdODIS Installer.exe missing - trying the registered command."));
        var fallback = await RunCommandLineAsync(product.UninstallString, args, progress,
            TimeSpan.FromMinutes(20), cancellationToken).ConfigureAwait(false);
        return Evaluate(product, fallback, fallback.ExitCode == 0);
    }

    private static async Task<ProductUninstallResult> UninstallMsiAsync(
        AutodeskProduct product,
        IProgress<EngineEvent>? progress,
        CancellationToken cancellationToken)
    {
        var match = Regex.Match(product.UninstallString, @"\{[0-9A-Fa-f\-]{36}\}");
        if (!match.Success)
        {
            return new ProductUninstallResult(product, false, -1, "MSI product code was not found.");
        }

        var guid = match.Value;
        progress?.Report(new EngineEvent(EngineEventKind.Line, $"  [MSI] Removing {guid}..."));
        var args = $"/x {guid} /qn /norestart REMOVE=ALL REBOOT=ReallySuppress";
        var run = await RunProcessAsync("msiexec.exe", args, progress, TimeSpan.FromMinutes(15), cancellationToken)
            .ConfigureAwait(false);

        if (IsMsiSuccess(run.ExitCode))
        {
            return Evaluate(product, run, true);
        }

        progress?.Report(new EngineEvent(EngineEventKind.Line, $"  [MSI] Exit {run.ExitCode}. Retrying with a visible progress bar..."));
        var retryArgs = $"/x {guid} /qb /norestart REMOVE=ALL REBOOT=ReallySuppress";
        var retry = await RunProcessAsync("msiexec.exe", retryArgs, progress, TimeSpan.FromMinutes(15), cancellationToken)
            .ConfigureAwait(false);
        return Evaluate(product, retry, IsMsiSuccess(retry.ExitCode));
    }

    private static async Task<ProductUninstallResult> UninstallLegacyAsync(
        AutodeskProduct product,
        IProgress<EngineEvent>? progress,
        CancellationToken cancellationToken)
    {
        progress?.Report(new EngineEvent(EngineEventKind.Line, "  [LEGACY] Running setup.exe /q..."));
        var run = await RunCommandLineAsync(product.UninstallString, "/q", progress,
            TimeSpan.FromMinutes(15), cancellationToken).ConfigureAwait(false);
        return Evaluate(product, run, true);
    }

    private static async Task<ProductUninstallResult> UninstallGenericAsync(
        AutodeskProduct product,
        IProgress<EngineEvent>? progress,
        CancellationToken cancellationToken)
    {
        progress?.Report(new EngineEvent(EngineEventKind.Line, "  [GENERIC] Running unattended uninstaller..."));
        var run = await RunCommandLineAsync(product.UninstallString, "--mode unattended", progress,
            TimeSpan.FromMinutes(15), cancellationToken).ConfigureAwait(false);
        return Evaluate(product, run, true);
    }

    private static ProductUninstallResult Evaluate(AutodeskProduct product, ProcessRunResult run, bool success)
    {
        var message = run.TimedOut
            ? "Timed out and was stopped."
            : success
                ? "Uninstalled successfully."
                : $"Uninstaller exited with code {run.ExitCode}.";

        return new ProductUninstallResult(product, success && !run.TimedOut, run.ExitCode, message);
    }

    private static bool IsMsiSuccess(int exitCode)
        => exitCode is 0 or 1605 or 1641 or 3010;

    private static string BuildOdisArguments(string uninstallString)
    {
        const string marker = "Installer.exe";
        var index = uninstallString.IndexOf(marker, StringComparison.OrdinalIgnoreCase);
        var args = index >= 0
            ? uninstallString[(index + marker.Length)..].Trim()
            : uninstallString.Trim();

        if (!Regex.IsMatch(args, @"(^|\s)-q(\s|$)", RegexOptions.IgnoreCase))
        {
            args = (args + " -q").Trim();
        }

        return args;
    }

    private static async Task<ProcessRunResult> RunCommandLineAsync(
        string commandLine,
        string extraArguments,
        IProgress<EngineEvent>? progress,
        TimeSpan timeout,
        CancellationToken cancellationToken)
    {
        var (fileName, existingArgs) = SplitCommandLine(commandLine);
        if (string.IsNullOrWhiteSpace(fileName) || !File.Exists(fileName))
        {
            progress?.Report(new EngineEvent(EngineEventKind.Line, $"  Executable not found: {fileName}"));
            return new ProcessRunResult(-2, false);
        }

        var args = string.Join(' ', new[] { existingArgs, extraArguments }
            .Where(part => !string.IsNullOrWhiteSpace(part)));
        return await RunProcessAsync(fileName, args, progress, timeout, cancellationToken).ConfigureAwait(false);
    }

    private static (string FileName, string Arguments) SplitCommandLine(string commandLine)
    {
        var text = commandLine.Trim();
        if (text.StartsWith('"'))
        {
            var end = text.IndexOf('"', 1);
            if (end > 0)
            {
                return (text[1..end], text[(end + 1)..].Trim());
            }
        }

        var exeIndex = text.IndexOf(".exe", StringComparison.OrdinalIgnoreCase);
        if (exeIndex > 0)
        {
            var cut = exeIndex + 4;
            return (text[..cut].Trim().Trim('"'), text[cut..].Trim());
        }

        var space = text.IndexOf(' ');
        return space > 0
            ? (text[..space], text[(space + 1)..].Trim())
            : (text, string.Empty);
    }

    private static async Task<ProcessRunResult> RunProcessAsync(
        string fileName,
        string arguments,
        IProgress<EngineEvent>? progress,
        TimeSpan timeout,
        CancellationToken cancellationToken)
    {
        var psi = new ProcessStartInfo
        {
            FileName = fileName,
            Arguments = arguments,
            UseShellExecute = false,
            CreateNoWindow = true,
            WindowStyle = ProcessWindowStyle.Hidden,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            StandardOutputEncoding = Encoding.Latin1,
            StandardErrorEncoding = Encoding.Latin1,
        };

        using var process = new Process { StartInfo = psi };
        if (!process.Start())
        {
            return new ProcessRunResult(-1, false);
        }

        var stdout = PumpAsync(process.StandardOutput, progress, cancellationToken);
        var stderr = PumpAsync(process.StandardError, progress, cancellationToken);

        var timedOut = false;
        using var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeoutCts.CancelAfter(timeout);
        try
        {
            await process.WaitForExitAsync(timeoutCts.Token).ConfigureAwait(false);
        }
        catch (OperationCanceledException)
        {
            if (!cancellationToken.IsCancellationRequested)
            {
                timedOut = true;
            }

            try
            {
                if (!process.HasExited)
                {
                    process.Kill(entireProcessTree: true);
                }
            }
            catch
            {
                // Ignore.
            }

            if (cancellationToken.IsCancellationRequested)
            {
                throw;
            }
        }

        await Task.WhenAny(Task.WhenAll(stdout, stderr), Task.Delay(TimeSpan.FromSeconds(3), CancellationToken.None))
            .ConfigureAwait(false);

        int exitCode;
        try
        {
            exitCode = process.ExitCode;
        }
        catch
        {
            exitCode = -1;
        }

        return new ProcessRunResult(exitCode, timedOut);
    }

    private static async Task PumpAsync(StreamReader reader, IProgress<EngineEvent>? progress, CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            string? line;
            try
            {
                line = await reader.ReadLineAsync(cancellationToken).ConfigureAwait(false);
            }
            catch
            {
                break;
            }

            if (line is null)
            {
                break;
            }

            var clean = line.Trim();
            if (clean.Length > 0)
            {
                progress?.Report(new EngineEvent(EngineEventKind.Line, "    " + clean));
            }
        }
    }

    private static async Task RunQuietAsync(string fileName, string arguments, TimeSpan timeout, CancellationToken cancellationToken)
    {
        try
        {
            using var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = fileName,
                    Arguments = arguments,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    WindowStyle = ProcessWindowStyle.Hidden,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                },
            };

            if (!process.Start())
            {
                return;
            }

            using var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            timeoutCts.CancelAfter(timeout);
            try
            {
                await process.WaitForExitAsync(timeoutCts.Token).ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
                try
                {
                    if (!process.HasExited)
                    {
                        process.Kill(entireProcessTree: true);
                    }
                }
                catch
                {
                    // Ignore.
                }
            }
        }
        catch
        {
            // Service/process may not exist.
        }
    }

    private readonly record struct ProcessRunResult(int ExitCode, bool TimedOut);
}
