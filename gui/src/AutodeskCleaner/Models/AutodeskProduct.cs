using System.ComponentModel;
using System.Globalization;
using System.Runtime.CompilerServices;
using AutodeskCleaner.Localization;

namespace AutodeskCleaner.Models;

public enum InstallMethod
{
    Odis,
    Msi,
    LegacySetup,
    Generic,
}

public sealed class AutodeskProduct : INotifyPropertyChanged
{
    private bool _isSelected;

    public event PropertyChangedEventHandler? PropertyChanged;

    public required string DisplayName { get; init; }
    public string Version { get; init; } = string.Empty;
    public string Publisher { get; init; } = string.Empty;
    public string UninstallString { get; init; } = string.Empty;
    public string InstallLocation { get; init; } = string.Empty;
    public string RegistryKey { get; init; } = string.Empty;
    public bool Is64Bit { get; init; }
    public bool IsOrphan { get; init; }
    public int Priority { get; init; } = 3;
    public long? SizeBytes { get; init; }
    public InstallMethod Method { get; init; }

    public bool IsSelected
    {
        get => _isSelected;
        set
        {
            if (_isSelected == value)
            {
                return;
            }

            _isSelected = value;
            OnPropertyChanged();
        }
    }

    public string VersionDisplay => string.IsNullOrWhiteSpace(Version) ? "—" : Version;

    public string TypeLabel => Method switch
    {
        InstallMethod.Odis => "ODIS",
        InstallMethod.Msi => "MSI",
        InstallMethod.LegacySetup => "Legacy",
        _ => "Generic",
    };

    public string LocationDisplay
    {
        get
        {
            if (!string.IsNullOrWhiteSpace(InstallLocation))
            {
                return InstallLocation;
            }

            return string.IsNullOrWhiteSpace(Publisher) ? DisplayName : Publisher;
        }
    }

    public string CategoryText => Priority switch
    {
        1 => Loc.Instance["Cat_Addon"],
        4 or 5 => Loc.Instance["Cat_Library"],
        6 => Loc.Instance["Cat_DesktopApp"],
        7 => Loc.Instance["Cat_SSO"],
        8 => Loc.Instance["Cat_Genuine"],
        _ => Loc.Instance["Cat_Main"],
    };

    public string InfoText
    {
        get
        {
            if (IsOrphan)
            {
                return Loc.Instance["Info_Orphan"];
            }

            return CategoryText;
        }
    }

    public string SizeText
    {
        get
        {
            if (SizeBytes is not > 0)
            {
                return "—";
            }

            double value = SizeBytes.Value;
            if (value >= 1024d * 1024 * 1024)
            {
                return (value / (1024d * 1024 * 1024)).ToString("0.0", CultureInfo.CurrentCulture) + " GB";
            }

            if (value >= 1024d * 1024)
            {
                return (value / (1024d * 1024)).ToString("0", CultureInfo.CurrentCulture) + " MB";
            }

            return Math.Max(1, (int)(value / 1024d)) + " KB";
        }
    }

    public string Initial
    {
        get
        {
            var name = DisplayName.Trim();
            if (name.StartsWith("Autodesk ", StringComparison.OrdinalIgnoreCase))
            {
                name = name["Autodesk ".Length..].Trim();
            }

            var first = name.FirstOrDefault(char.IsLetterOrDigit);
            return first == default ? "A" : char.ToUpperInvariant(first).ToString();
        }
    }

    /// <summary>Hex colour used by the little product tile. WPF converts it to a Brush.</summary>
    public string AccentHex
    {
        get
        {
            var name = DisplayName.ToLowerInvariant();

            if (name.Contains("autocad") || name.Contains("civil 3d")) return "#C8102E";
            if (name.Contains("revit")) return "#1D6FB8";
            if (name.Contains("inventor")) return "#D97706";
            if (name.Contains("maya")) return "#0F9B8E";
            if (name.Contains("3ds max") || name.Contains("3dsmax")) return "#7C3AED";
            if (name.Contains("navisworks")) return "#16A34A";
            if (name.Contains("recap")) return "#4F46E5";
            if (name.Contains("fusion")) return "#EA580C";
            if (name.Contains("vault")) return "#475569";
            if (name.Contains("desktop connector")) return "#0891B2";
            if (name.Contains("genuine")) return "#DC2626";
            if (name.Contains("desktop app") || name.Contains("access")) return "#2563EB";
            if (name.Contains("material library")) return "#9333EA";
            if (name.Contains("licensing") || name.Contains("identity")) return "#0E7490";
            return "#2B6CB0";
        }
    }

    public void RefreshLocalized()
    {
        OnPropertyChanged(nameof(CategoryText));
        OnPropertyChanged(nameof(InfoText));
    }

    private void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
}
