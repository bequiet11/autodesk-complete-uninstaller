using System.IO;

namespace AutodeskCleaner.Services;

/// <summary>
/// Central place for every path the app touches.
/// The engine writes its own logs to %USERPROFILE%\Desktop\Autodesk_Uninstaller,
/// so that path is intentionally built from UserProfile (not SpecialFolder.Desktop,
/// which may point to OneDrive).
/// </summary>
public static class AppPaths
{
    public static string DataDir { get; } = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "AutodeskCleaner");

    public static string EngineDir { get; } = Path.Combine(DataDir, "engine");

    public static string EnginePath { get; } = Path.Combine(EngineDir, "autodesk_complete_uninstaller.bat");

    public static string HistoryDir { get; } = Path.Combine(DataDir, "history");

    public static string CrashLog { get; } = Path.Combine(DataDir, "crash.log");

    public static string SettingsFile { get; } = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "AutodeskCleaner", "settings.json");

    /// <summary>Matches the hard-coded LOGDIR in autodesk_complete_uninstaller.bat.</summary>
    public static string EngineLogDir { get; } = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Desktop", "Autodesk_Uninstaller");

    public static void EnsureDataDirectories()
    {
        Directory.CreateDirectory(DataDir);
        Directory.CreateDirectory(EngineDir);
        Directory.CreateDirectory(HistoryDir);
    }

    public static string CreateHistoryFolder(string action)
    {
        EnsureDataDirectories();
        var safeAction = string.Concat(action.Select(c => char.IsLetterOrDigit(c) || c is '-' or '_' ? c : '_'));
        var dir = Path.Combine(HistoryDir, $"{DateTime.Now:yyyyMMdd_HHmmss}_{safeAction}");
        Directory.CreateDirectory(dir);
        return dir;
    }
}
