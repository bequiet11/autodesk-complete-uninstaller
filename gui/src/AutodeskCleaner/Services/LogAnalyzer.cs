using System.Globalization;
using System.IO;
using System.Text.RegularExpressions;
using AutodeskCleaner.Localization;

namespace AutodeskCleaner.Services;

public enum ReportSeverity
{
    Success,
    Warning,
    Error,
    Info,
}

public sealed record ReportContent(
    string Title,
    string Headline,
    IReadOnlyList<string> Details,
    bool OfferDeepClean,
    bool OfferVerify,
    string? LogFolder,
    ReportSeverity Severity);

public sealed class OperationReport
{
    public required EngineAction Action { get; init; }
    public required EngineRunResult Run { get; init; }
    public int? RemainingItems { get; init; }
    public bool FullyClean { get; init; }
    public int UninstalledOk { get; init; }
    public int ForceRemoved { get; init; }
    public int IssuesFound { get; init; }
    public int FixesApplied { get; init; }
    public int AuditTotal { get; init; }
    public int RemnantTotal { get; init; }
    public string? DiskUsage { get; init; }
    public bool DeepCleanCompleted { get; init; }
    public bool RestorePointCreated { get; init; }
    public bool BackupCompleted { get; init; }
    public bool RebootCleared { get; init; }
    public int DtcFoldersRemoved { get; init; }
    public bool DtcNothingFound { get; init; }

    public bool EngineFailed => !Run.Cancelled && !Run.TimedOut && Run.ExitCode != 0;

    public bool IsClean => FullyClean || RemainingItems == 0;

    public ReportContent ToContent()
    {
        var loc = Loc.Instance;
        var details = new List<string>();
        var logFolder = Run.ArchiveFolder ?? (Directory.Exists(AppPaths.EngineLogDir) ? AppPaths.EngineLogDir : null);

        if (Run.Cancelled)
        {
            details.Add(loc["Result_Stopped"]);
            return new ReportContent(
                loc["Result_Info_Title"], loc["Result_Stopped"], details,
                OfferDeepClean: false, OfferVerify: false, logFolder, ReportSeverity.Warning);
        }

        if (Run.TimedOut)
        {
            details.Add(loc["Result_TimedOut"]);
            return new ReportContent(
                loc["Result_Error_Title"], loc["Result_TimedOut"], details,
                OfferDeepClean: false, OfferVerify: true, logFolder, ReportSeverity.Error);
        }

        if (EngineFailed)
        {
            var message = loc.Format("Result_EngineFail", Run.ExitCode);
            details.Add(loc["Result_LogAt"]);
            return new ReportContent(
                loc["Result_Error_Title"], message, details,
                OfferDeepClean: false, OfferVerify: false, logFolder, ReportSeverity.Error);
        }

        switch (Action)
        {
            case EngineAction.Full:
            {
                if (UninstalledOk > 0)
                {
                    details.Add(loc.Format("Result_Uninstalled", UninstalledOk));
                }

                if (ForceRemoved > 0)
                {
                    details.Add(loc.Format("Result_ForceRemoved", ForceRemoved));
                }

                var remaining = RemainingItems ?? -1;
                if (remaining > 0)
                {
                    details.Add(loc.Format("Result_Remaining", remaining));
                    details.Add(loc["Result_NextVerify"]);
                }
                else
                {
                    details.Add(loc["Result_Clean"]);
                }

                return new ReportContent(
                    loc[remaining > 0 ? "Result_Warning_Title" : "Result_Success_Title"],
                    loc["Result_FullClean"],
                    details,
                    OfferDeepClean: remaining > 0,
                    OfferVerify: remaining > 0,
                    logFolder,
                    remaining > 0 ? ReportSeverity.Warning : ReportSeverity.Success);
            }

            case EngineAction.Deep:
            {
                var remaining = RemainingItems ?? -1;
                if (remaining > 0)
                {
                    details.Add(loc.Format("Result_Remaining", remaining));
                    details.Add(loc["Result_NextVerify"]);
                }
                else
                {
                    details.Add(loc["Result_Clean"]);
                }

                return new ReportContent(
                    loc[remaining > 0 ? "Result_Warning_Title" : "Result_Success_Title"],
                    loc["Result_DeepClean"],
                    details,
                    OfferDeepClean: remaining > 0,
                    OfferVerify: remaining > 0,
                    logFolder,
                    remaining > 0 ? ReportSeverity.Warning : ReportSeverity.Success);
            }

            case EngineAction.Verify:
            {
                var remaining = RemainingItems ?? 0;
                if (remaining > 0)
                {
                    details.Add(loc.Format("Result_Remaining", remaining));
                    details.Add(loc["Result_NextDeepClean"]);
                }
                else
                {
                    details.Add(loc["Result_Clean"]);
                }

                return new ReportContent(
                    loc[remaining > 0 ? "Result_Warning_Title" : "Result_Success_Title"],
                    loc["Result_Verify"],
                    details,
                    OfferDeepClean: remaining > 0,
                    OfferVerify: false,
                    logFolder,
                    remaining > 0 ? ReportSeverity.Warning : ReportSeverity.Success);
            }

            case EngineAction.Audit:
            {
                if (AuditTotal == 0)
                {
                    details.Add(loc["Result_AuditClean"]);
                }
                else
                {
                    details.Add(loc.Format("Result_AuditFound", AuditTotal, DiskUsage ?? "—"));
                }

                return new ReportContent(
                    loc["Result_Info_Title"],
                    loc["Result_Audit"],
                    details,
                    OfferDeepClean: AuditTotal > 0,
                    OfferVerify: false,
                    logFolder,
                    ReportSeverity.Info);
            }

            case EngineAction.Remnants:
            {
                if (RemnantTotal > 0)
                {
                    details.Add(loc.Format("Result_Remaining", RemnantTotal));
                    details.Add(loc["Result_NextDeepClean"]);
                }
                else
                {
                    details.Add(loc["Result_Clean"]);
                }

                return new ReportContent(
                    loc["Result_Info_Title"],
                    loc["Result_Remnants"],
                    details,
                    OfferDeepClean: RemnantTotal > 0,
                    OfferVerify: false,
                    logFolder,
                    ReportSeverity.Info);
            }

            case EngineAction.Restore:
            {
                if (RestorePointCreated)
                {
                    details.Add(loc["Result_RestoreOk"]);
                    return new ReportContent(
                        loc["Result_Success_Title"], loc["Result_Restore"], details,
                        OfferDeepClean: false, OfferVerify: false, logFolder, ReportSeverity.Success);
                }

                details.Add(loc["Result_RestoreFail"]);
                return new ReportContent(
                    loc["Result_Warning_Title"], loc["Result_Restore"], details,
                    OfferDeepClean: false, OfferVerify: false, logFolder, ReportSeverity.Warning);
            }

            case EngineAction.Error103:
            {
                if (IssuesFound == 0)
                {
                    details.Add(loc["Result_NoIssues"]);
                    return new ReportContent(
                        loc["Result_Info_Title"], loc["Result_Error103"], details,
                        OfferDeepClean: false, OfferVerify: false, logFolder, ReportSeverity.Info);
                }

                details.Add(loc.Format("Result_Issues", IssuesFound, FixesApplied));
                if (FixesApplied == 0)
                {
                    details.Add(loc["Result_NoIssues"]);
                }

                return new ReportContent(
                    loc[FixesApplied > 0 ? "Result_Success_Title" : "Result_Warning_Title"],
                    loc["Result_Error103"],
                    details,
                    OfferDeepClean: false,
                    OfferVerify: false,
                    logFolder,
                    FixesApplied > 0 ? ReportSeverity.Success : ReportSeverity.Warning);
            }

            case EngineAction.Reboot:
            {
                if (RebootCleared)
                {
                    details.Add(loc["Result_RebootOk"]);
                    return new ReportContent(
                        loc["Result_Success_Title"], loc["Result_Reboot"], details,
                        OfferDeepClean: false, OfferVerify: false, logFolder, ReportSeverity.Success);
                }

                details.Add(loc["Result_LogAt"]);
                return new ReportContent(
                    loc["Result_Info_Title"], loc["Result_Reboot"], details,
                    OfferDeepClean: false, OfferVerify: false, logFolder, ReportSeverity.Info);
            }

            case EngineAction.Backup:
            {
                if (BackupCompleted)
                {
                    details.Add(loc["Result_BackupOk"]);
                    return new ReportContent(
                        loc["Result_Success_Title"], loc["Result_Backup"], details,
                        OfferDeepClean: false, OfferVerify: false, logFolder, ReportSeverity.Success);
                }

                details.Add(loc["Result_LogAt"]);
                return new ReportContent(
                    loc["Result_Warning_Title"], loc["Result_Backup"], details,
                    OfferDeepClean: false, OfferVerify: false, logFolder, ReportSeverity.Warning);
            }

            case EngineAction.Dtc:
            {
                if (DtcNothingFound)
                {
                    details.Add(loc["Result_DtcNone"]);
                    return new ReportContent(
                        loc["Result_Info_Title"], loc["Result_Dtc"], details,
                        OfferDeepClean: false, OfferVerify: false, logFolder, ReportSeverity.Info);
                }

                if (DtcFoldersRemoved > 0)
                {
                    details.Add(loc.Format("Result_DtcFolders", DtcFoldersRemoved));
                    return new ReportContent(
                        loc["Result_Success_Title"], loc["Result_Dtc"], details,
                        OfferDeepClean: false, OfferVerify: false, logFolder, ReportSeverity.Success);
                }

                details.Add(loc["Result_LogAt"]);
                return new ReportContent(
                    loc["Result_Warning_Title"], loc["Result_Dtc"], details,
                    OfferDeepClean: false, OfferVerify: false, logFolder, ReportSeverity.Warning);
            }

            default:
            {
                details.Add(loc["Result_LogAt"]);
                return new ReportContent(
                    loc["Result_Info_Title"], loc["Result_Scan"], details,
                    OfferDeepClean: false, OfferVerify: false, logFolder, ReportSeverity.Info);
            }
        }
    }
}

public static partial class LogAnalyzer
{
    [GeneratedRegex(@"(?i)FULLY\s+CLEAN")]
    private static partial Regex FullyCleanRegex();

    [GeneratedRegex(@"(?i)(\d+)\s+ITEMS\s+STILL\s+REMAINING")]
    private static partial Regex RemainingItemsRegex();

    [GeneratedRegex(@"(?i)VERIFY:\s*(\d+)\s+remaining")]
    private static partial Regex VerifyRemainingRegex();

    [GeneratedRegex(@"(?i)PHASE\s+C\s+TOTAL:\s*(\d+)\s+ok")]
    private static partial Regex UninstalledRegex();

    [GeneratedRegex(@"(?i)Force-removed\s+(\d+)\s+stuck")]
    private static partial Regex ForceRemovedRegex();

    [GeneratedRegex(@"(?i)(\d+)\s+issue\(s\)\s+found")]
    private static partial Regex IssuesRegex();

    [GeneratedRegex(@"(?i)(\d+)\s+fix\(es\)\s+applied")]
    private static partial Regex FixesRegex();

    [GeneratedRegex(@"(?i)TOTAL:\s*(\d+)\s+Autodesk\s+items\s+found")]
    private static partial Regex AuditTotalRegex();

    [GeneratedRegex(@"(?i)Disk space used:\s*(.+?)\s*$", RegexOptions.Multiline)]
    private static partial Regex DiskUsageRegex();

    [GeneratedRegex(@"(?i)REMNANT SCAN COMPLETE[\s\S]{0,400}?TOTAL\s+(\d+)")]
    private static partial Regex RemnantTotalRegex();

    [GeneratedRegex(@"(?i)Deep clean complete")]
    private static partial Regex DeepCleanRegex();

    [GeneratedRegex(@"(?i)Restore point created successfully")]
    private static partial Regex RestoreRegex();

    [GeneratedRegex(@"(?i)Backup complete")]
    private static partial Regex BackupRegex();

    [GeneratedRegex(@"(?i)All pending reboot states cleared")]
    private static partial Regex RebootRegex();

    [GeneratedRegex(@"(?i)(\d+)\s+workspace\s+folder\(s\)\s+removed")]
    private static partial Regex DtcRegex();

    [GeneratedRegex(@"(?i)No Desktop Connector workspace found")]
    private static partial Regex DtcNoneRegex();

    public static OperationReport Analyze(EngineAction action, EngineRunResult run)
    {
        var output = run.Output ?? string.Empty;

        int? remaining = null;
        var fullyClean = FullyCleanRegex().IsMatch(output);

        var verifyMatches = VerifyRemainingRegex().Matches(output);
        if (verifyMatches.Count > 0)
        {
            remaining = ParseInt(verifyMatches[^1].Groups[1].Value);
        }

        if (remaining is null)
        {
            var itemMatches = RemainingItemsRegex().Matches(output);
            if (itemMatches.Count > 0)
            {
                remaining = ParseInt(itemMatches[^1].Groups[1].Value);
            }
        }

        if (fullyClean && remaining is null)
        {
            remaining = 0;
        }

        int? remnantTotal = null;
        var remnantMatch = RemnantTotalRegex().Match(output);
        if (remnantMatch.Success)
        {
            remnantTotal = ParseInt(remnantMatch.Groups[1].Value);
        }

        var diskMatch = DiskUsageRegex().Match(output);

        return new OperationReport
        {
            Action = action,
            Run = run,
            RemainingItems = remaining,
            FullyClean = fullyClean || remaining == 0,
            UninstalledOk = FirstInt(UninstalledRegex(), output),
            ForceRemoved = FirstInt(ForceRemovedRegex(), output),
            IssuesFound = FirstInt(IssuesRegex(), output),
            FixesApplied = FirstInt(FixesRegex(), output),
            AuditTotal = FirstInt(AuditTotalRegex(), output),
            RemnantTotal = remnantTotal ?? 0,
            DiskUsage = diskMatch.Success ? diskMatch.Groups[1].Value.Trim() : null,
            DeepCleanCompleted = DeepCleanRegex().IsMatch(output),
            RestorePointCreated = RestoreRegex().IsMatch(output),
            BackupCompleted = BackupRegex().IsMatch(output),
            RebootCleared = RebootRegex().IsMatch(output),
            DtcFoldersRemoved = FirstInt(DtcRegex(), output),
            DtcNothingFound = DtcNoneRegex().IsMatch(output),
        };
    }

    private static int FirstInt(Regex regex, string text)
    {
        var match = regex.Match(text);
        return match.Success ? ParseInt(match.Groups[1].Value) : 0;
    }

    private static int ParseInt(string value)
        => int.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsed) ? parsed : 0;
}
