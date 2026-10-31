using System.IO;
using System.Text;
using System.Text.RegularExpressions;

namespace AutodeskCleaner.Services;

public enum EngineAction
{
    Scan,
    Full,
    Deep,
    Verify,
    Audit,
    Remnants,
    Restore,
    Error103,
    Reboot,
    Backup,
    Dtc,
}

public static class EngineActionExtensions
{
    public static string ToCliValue(this EngineAction action) => action switch
    {
        EngineAction.Scan => "scan",
        EngineAction.Full => "full",
        EngineAction.Deep => "deep",
        EngineAction.Verify => "verify",
        EngineAction.Audit => "audit",
        EngineAction.Remnants => "remnants",
        EngineAction.Restore => "restore",
        EngineAction.Error103 => "error103",
        EngineAction.Reboot => "reboot",
        EngineAction.Backup => "backup",
        EngineAction.Dtc => "dtc",
        _ => "scan",
    };

    public static TimeSpan GetTimeout(this EngineAction action) => action switch
    {
        EngineAction.Full => TimeSpan.FromMinutes(90),
        EngineAction.Deep => TimeSpan.FromMinutes(60),
        EngineAction.Verify => TimeSpan.FromMinutes(30),
        EngineAction.Audit => TimeSpan.FromMinutes(45),
        EngineAction.Remnants => TimeSpan.FromMinutes(45),
        EngineAction.Restore => TimeSpan.FromMinutes(5),
        EngineAction.Error103 => TimeSpan.FromMinutes(20),
        EngineAction.Reboot => TimeSpan.FromMinutes(5),
        EngineAction.Backup => TimeSpan.FromMinutes(30),
        EngineAction.Dtc => TimeSpan.FromMinutes(10),
        _ => TimeSpan.FromMinutes(5),
    };
}

public enum EngineEventKind
{
    Line,
    Status,
}

public sealed record EngineEvent(EngineEventKind Kind, string Text);

public sealed class EngineRunResult
{
    public required int ExitCode { get; init; }
    public required string Output { get; init; }
    public required TimeSpan Elapsed { get; init; }
    public bool Cancelled { get; init; }
    public bool TimedOut { get; init; }
    public string? ArchiveFolder { get; init; }
}

public sealed class EngineService
{
    private const string ResourceName = "AutodeskCleaner.Engine.autodesk_complete_uninstaller.bat";
    private static readonly Regex AnsiRegex = new(@"\x1B\[[0-9;?]*[ -/]*[@-~]", RegexOptions.Compiled);
    private static readonly Regex ProgressNoiseRegex = new(@"^[.+\s]+$", RegexOptions.Compiled);

    public static string EnsureEngineExtracted()
    {
        var assembly = typeof(EngineService).Assembly;
        using var stream = assembly.GetManifestResourceStream(ResourceName)
            ?? throw new FileNotFoundException("Embedded engine resource not found.", ResourceName);

        AppPaths.EnsureDataDirectories();

        var desiredHash = ComputeHash(stream);
        stream.Position = 0;

        if (File.Exists(AppPaths.EnginePath))
        {
            using var existing = File.OpenRead(AppPaths.EnginePath);
            if (string.Equals(ComputeHash(existing), desiredHash, StringComparison.OrdinalIgnoreCase))
            {
                return AppPaths.EnginePath;
            }
        }

        var tempPath = AppPaths.EnginePath + ".tmp";
        using (var output = File.Create(tempPath))
        {
            stream.CopyTo(output);
        }

        File.Move(tempPath, AppPaths.EnginePath, overwrite: true);
        return AppPaths.EnginePath;
    }

    public async Task<EngineRunResult> RunAsync(
        EngineAction action,
        IReadOnlyDictionary<string, string>? extraEnvironment,
        IProgress<EngineEvent>? progress,
        CancellationToken cancellationToken)
    {
        var enginePath = EnsureEngineExtracted();
        var started = DateTime.UtcNow;

        var psi = new System.Diagnostics.ProcessStartInfo
        {
            FileName = Path.Combine(Environment.SystemDirectory, "cmd.exe"),
            Arguments = "/d /s /c \"\"" + enginePath + "\"\"",
            WorkingDirectory = Path.GetDirectoryName(enginePath) ?? AppPaths.EngineDir,
            UseShellExecute = false,
            CreateNoWindow = true,
            WindowStyle = System.Diagnostics.ProcessWindowStyle.Hidden,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            RedirectStandardInput = true,
            StandardOutputEncoding = Encoding.Latin1,
            StandardErrorEncoding = Encoding.Latin1,
        };

        psi.Environment["ADSK_GUI_MODE"] = "1";
        psi.Environment["ADSK_GUI_ACTION"] = action.ToCliValue();
        psi.Environment["ADSK_GUI_PID"] = Environment.ProcessId.ToString();

        // Safety defaults: every interactive prompt must resolve without a console.
        psi.Environment["RET"] = "N";

        if (extraEnvironment is not null)
        {
            foreach (var pair in extraEnvironment)
            {
                psi.Environment[pair.Key] = pair.Value;
            }
        }

        using var process = new System.Diagnostics.Process { StartInfo = psi, EnableRaisingEvents = true };
        var output = new StringBuilder();
        using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        linkedCts.CancelAfter(action.GetTimeout());
        var userCancelled = false;
        var timedOut = false;

        using var registration = linkedCts.Token.Register(() =>
        {
            userCancelled = cancellationToken.IsCancellationRequested;
            timedOut = !userCancelled;
            TryKill(process);
        });

        if (!process.Start())
        {
            throw new InvalidOperationException("Could not start the cleanup engine.");
        }

        // A missed prompt must read EOF instead of hanging forever.
        try
        {
            process.StandardInput.Close();
        }
        catch
        {
            // Ignore.
        }

        var gate = new object();
        var stdoutTask = PumpAsync(process.StandardOutput, output, gate, progress, linkedCts.Token);
        var stderrTask = PumpAsync(process.StandardError, output, gate, progress, linkedCts.Token);

        try
        {
            await process.WaitForExitAsync(linkedCts.Token).ConfigureAwait(false);
        }
        catch (OperationCanceledException)
        {
            TryKill(process);
            try
            {
                await process.WaitForExitAsync(CancellationToken.None).ConfigureAwait(false);
            }
            catch
            {
                // Ignore.
            }
        }

        // Give readers a moment to drain, then stop waiting on a stuck pipe.
        await Task.WhenAny(Task.WhenAll(stdoutTask, stderrTask), Task.Delay(TimeSpan.FromSeconds(5)))
            .ConfigureAwait(false);

        string finalOutput;
        lock (gate)
        {
            finalOutput = output.ToString();
        }

        var elapsed = DateTime.UtcNow - started;
        string? archive = null;
        try
        {
            archive = ArchiveLogs(action, finalOutput, process.ExitCode, elapsed);
        }
        catch
        {
            // Archiving is best-effort; the engine logs still exist on the Desktop.
        }

        return new EngineRunResult
        {
            ExitCode = SafeExitCode(process),
            Output = finalOutput,
            Elapsed = elapsed,
            Cancelled = userCancelled,
            TimedOut = timedOut,
            ArchiveFolder = archive,
        };
    }

    private static int SafeExitCode(System.Diagnostics.Process process)
    {
        try
        {
            return process.ExitCode;
        }
        catch
        {
            return -1;
        }
    }

    private static void TryKill(System.Diagnostics.Process process)
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
            // Process may already be gone.
        }
    }

    private static async Task PumpAsync(
        StreamReader reader,
        StringBuilder all,
        object gate,
        IProgress<EngineEvent>? progress,
        CancellationToken cancellationToken)
    {
        var line = new StringBuilder();
        var chunk = new char[4096];
        var previousWasCr = false;
        var lastPartialAt = DateTime.MinValue;
        var lastPartial = string.Empty;

        void EmitLine()
        {
            var clean = CleanText(line.ToString());
            line.Clear();
            if (clean.Length == 0 || ProgressNoiseRegex.IsMatch(clean))
            {
                return;
            }

            lock (gate)
            {
                all.AppendLine(clean);
            }

            progress?.Report(new EngineEvent(EngineEventKind.Line, clean));
        }

        while (!cancellationToken.IsCancellationRequested)
        {
            int read;
            try
            {
                read = await reader.ReadAsync(chunk.AsMemory(0, chunk.Length), cancellationToken).ConfigureAwait(false);
            }
            catch
            {
                break;
            }

            if (read <= 0)
            {
                break;
            }

            for (var i = 0; i < read; i++)
            {
                var c = chunk[i];
                switch (c)
                {
                    case '\r':
                        EmitLine();
                        previousWasCr = true;
                        continue;
                    case '\n':
                        if (!previousWasCr)
                        {
                            EmitLine();
                        }

                        previousWasCr = false;
                        continue;
                    case '\f':
                        line.Clear();
                        previousWasCr = false;
                        continue;
                    case '\b':
                        if (line.Length > 0)
                        {
                            line.Length--;
                        }

                        previousWasCr = false;
                        continue;
                    case '\0':
                        continue;
                    default:
                        previousWasCr = false;
                        line.Append(c);
                        break;
                }
            }

            var now = DateTime.UtcNow;
            if (line.Length > 2 && (now - lastPartialAt).TotalMilliseconds >= 200)
            {
                var partial = CleanText(line.ToString());
                if (partial.Length > 0 && partial != lastPartial && !ProgressNoiseRegex.IsMatch(partial))
                {
                    lastPartial = partial;
                    lastPartialAt = now;
                    progress?.Report(new EngineEvent(EngineEventKind.Status, partial));
                }
            }
        }

        EmitLine();
    }

    private static string CleanText(string text)
    {
        var cleaned = AnsiRegex.Replace(text, string.Empty)
            .Replace("\uFEFF", string.Empty)
            .Replace("\u00A0", " ")
            .TrimEnd();
        return cleaned.Trim();
    }

    public static string? ArchiveLogs(EngineAction action, string output, int exitCode, TimeSpan elapsed)
    {
        var source = AppPaths.EngineLogDir;
        if (!Directory.Exists(source))
        {
            return null;
        }

        var destination = AppPaths.CreateHistoryFolder(action.ToCliValue());
        var files = new[]
        {
            "uninstall_log.txt", "console_log.txt", "diagnostics.log", "verify_details.txt",
            "remnant_scan.txt", "system_audit.txt", "error103_log.txt", "reboot_cleanup.bat",
        };

        foreach (var name in files)
        {
            var path = Path.Combine(source, name);
            if (File.Exists(path))
            {
                try
                {
                    File.Copy(path, Path.Combine(destination, name), overwrite: true);
                }
                catch
                {
                    // Keep archiving the rest.
                }
            }
        }

        try
        {
            foreach (var reg in Directory.EnumerateFiles(source, "*.reg"))
            {
                File.Copy(reg, Path.Combine(destination, Path.GetFileName(reg)), overwrite: true);
            }
        }
        catch
        {
            // Optional.
        }

        try
        {
            File.WriteAllText(Path.Combine(destination, "ui_run_info.txt"),
                $"Action: {action}{Environment.NewLine}" +
                $"Started: {DateTime.Now:yyyy-MM-dd HH:mm:ss}{Environment.NewLine}" +
                $"Elapsed: {elapsed}{Environment.NewLine}" +
                $"Exit code: {exitCode}{Environment.NewLine}{Environment.NewLine}" +
                output);
        }
        catch
        {
            // Optional.
        }

        PruneHistory();
        return destination;
    }

    private static void PruneHistory()
    {
        try
        {
            if (!Directory.Exists(AppPaths.HistoryDir))
            {
                return;
            }

            foreach (var old in Directory.GetDirectories(AppPaths.HistoryDir)
                         .OrderByDescending(Directory.GetLastWriteTimeUtc)
                         .Skip(25))
            {
                Directory.Delete(old, recursive: true);
            }
        }
        catch
        {
            // Never block cleanup because of history pruning.
        }
    }

    private static string ComputeHash(Stream stream)
    {
        using var sha = System.Security.Cryptography.SHA256.Create();
        return Convert.ToHexString(sha.ComputeHash(stream));
    }
}
