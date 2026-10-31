using System.IO;
using System.Text.Encodings.Web;
using System.Text.Json;

namespace AutodeskCleaner.Services;

public sealed class SettingsService
{
    private static readonly object Sync = new();
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
        PropertyNameCaseInsensitive = true,
    };

    public string Language { get; set; } = "id";
    public bool StartMaximized { get; set; } = true;

    public bool DefaultCreateRestorePoint { get; set; } = true;
    public bool DefaultBackupTemplates { get; set; } = true;
    public bool DefaultRemoveInstallers { get; set; }
    public bool DefaultRemoveDesktopConnectorWorkspace { get; set; }

    public DateTimeOffset? LastScanUtc { get; set; }
    public int? LastVerifyRemaining { get; set; }
    public DateTimeOffset? LastVerifyUtc { get; set; }

    public static SettingsService Load()
    {
        lock (Sync)
        {
            try
            {
                if (File.Exists(AppPaths.SettingsFile))
                {
                    var json = File.ReadAllText(AppPaths.SettingsFile);
                    var loaded = JsonSerializer.Deserialize<SettingsService>(json, JsonOptions);
                    if (loaded is not null)
                    {
                        if (loaded.Language is not ("id" or "en"))
                        {
                            loaded.Language = "id";
                        }

                        return loaded;
                    }
                }
            }
            catch
            {
                // Corrupt or unreadable settings must never prevent the app from starting.
            }

            return new SettingsService();
        }
    }

    public bool Save()
    {
        lock (Sync)
        {
            try
            {
                var dir = Path.GetDirectoryName(AppPaths.SettingsFile);
                if (!string.IsNullOrEmpty(dir))
                {
                    Directory.CreateDirectory(dir);
                }

                File.WriteAllText(AppPaths.SettingsFile, JsonSerializer.Serialize(this, JsonOptions));
                return true;
            }
            catch
            {
                return false;
            }
        }
    }
}
