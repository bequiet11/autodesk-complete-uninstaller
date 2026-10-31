using System.IO;
using System.Text.RegularExpressions;
using AutodeskCleaner.Models;
using Microsoft.Win32;

namespace AutodeskCleaner.Services;

/// <summary>
/// Registry-based product detection that mirrors the engine's own scan:
/// HKLM 64-bit + 32-bit Uninstall keys, Publisher contains "Autodesk",
/// deduplicated by DisplayName.
/// </summary>
public sealed class ProductScanner
{
    private static readonly Regex XmlPathRegex = new(@"(?i)([a-z]:\\[^""\r\n]*?\.xml)", RegexOptions.Compiled);

    public IReadOnlyList<AutodeskProduct> Scan()
    {
        var results = new List<AutodeskProduct>();
        var seenNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var view in new[] { RegistryView.Registry64, RegistryView.Registry32 })
        {
            try
            {
                ScanView(view, results, seenNames);
            }
            catch (Exception)
            {
                // A missing/redirected hive on unusual systems must not abort the scan.
            }
        }

        return results
            .OrderBy(p => p.DisplayName, StringComparer.CurrentCultureIgnoreCase)
            .ToList();
    }

    private static void ScanView(RegistryView view, List<AutodeskProduct> results, HashSet<string> seenNames)
    {
        using var baseKey = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, view);
        using var uninstall = baseKey.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall");
        if (uninstall is null)
        {
            return;
        }

        foreach (var subKeyName in uninstall.GetSubKeyNames())
        {
            using var key = uninstall.OpenSubKey(subKeyName);
            if (key is null)
            {
                continue;
            }

            var publisher = key.GetValue("Publisher") as string;
            if (string.IsNullOrWhiteSpace(publisher) ||
                !publisher.Contains("Autodesk", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            var displayName = (key.GetValue("DisplayName") as string)?.Trim();
            if (string.IsNullOrWhiteSpace(displayName) || !seenNames.Add(displayName))
            {
                continue;
            }

            var uninstallString = (key.GetValue("UninstallString") as string)?.Trim() ?? string.Empty;
            var version = (key.GetValue("DisplayVersion") as string)?.Trim() ?? string.Empty;
            var installLocation = (key.GetValue("InstallLocation") as string)?.Trim() ?? string.Empty;
            var method = ClassifyMethod(uninstallString);
            var isOrphan = method == InstallMethod.Odis && HasMissingMetadata(uninstallString);

            results.Add(new AutodeskProduct
            {
                DisplayName = displayName,
                Version = version,
                Publisher = publisher,
                UninstallString = uninstallString,
                InstallLocation = installLocation,
                RegistryKey = $@"HKLM\{(view == RegistryView.Registry32 ? @"SOFTWARE\WOW6432Node\" : @"SOFTWARE\")}Microsoft\Windows\CurrentVersion\Uninstall\{subKeyName}",
                Is64Bit = view == RegistryView.Registry64,
                IsOrphan = isOrphan,
                Priority = ClassifyPriority(displayName),
                SizeBytes = ReadEstimatedSize(key),
                Method = method,
            });
        }
    }

    private static InstallMethod ClassifyMethod(string uninstallString)
    {
        if (uninstallString.Contains("Installer.exe", StringComparison.OrdinalIgnoreCase) ||
            uninstallString.Contains("AdskUninstallHelper", StringComparison.OrdinalIgnoreCase))
        {
            return InstallMethod.Odis;
        }

        if (uninstallString.Contains("MsiExec", StringComparison.OrdinalIgnoreCase))
        {
            return InstallMethod.Msi;
        }

        if (uninstallString.Contains("Setup.exe", StringComparison.OrdinalIgnoreCase))
        {
            return InstallMethod.LegacySetup;
        }

        return InstallMethod.Generic;
    }

    private static bool HasMissingMetadata(string uninstallString)
    {
        foreach (Match match in XmlPathRegex.Matches(uninstallString))
        {
            var path = match.Groups[1].Value.Trim();
            if (!File.Exists(path))
            {
                return true;
            }
        }

        return false;
    }

    private static int ClassifyPriority(string displayName)
    {
        if (ContainsAny(displayName, "Enabler", "Plugin", "Add-in", "Addon", "Content Pack", "Language Pack", "Service Pack"))
        {
            return 1;
        }

        if (displayName.Contains("Material Library", StringComparison.OrdinalIgnoreCase))
        {
            return 5;
        }

        if (displayName.Contains("Medium Resolution", StringComparison.OrdinalIgnoreCase))
        {
            return 4;
        }

        if (displayName.Contains("Desktop App", StringComparison.OrdinalIgnoreCase))
        {
            return 6;
        }

        if (displayName.Contains("Single Sign", StringComparison.OrdinalIgnoreCase))
        {
            return 7;
        }

        if (displayName.Contains("Genuine", StringComparison.OrdinalIgnoreCase))
        {
            return 8;
        }

        return 3;
    }

    private static bool ContainsAny(string value, params string[] needles)
        => needles.Any(n => value.Contains(n, StringComparison.OrdinalIgnoreCase));

    private static long? ReadEstimatedSize(RegistryKey key)
    {
        var raw = key.GetValue("EstimatedSize");
        long kilobytes;
        switch (raw)
        {
            case int i:
                kilobytes = i;
                break;
            case long l:
                kilobytes = l;
                break;
            case string s when long.TryParse(s, out var parsed):
                kilobytes = parsed;
                break;
            default:
                return null;
        }

        return kilobytes > 0 ? kilobytes * 1024L : null;
    }
}
