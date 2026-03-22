# Autodesk Complete Uninstaller

A single-file Windows batch tool that fully detects, uninstalls, and deep-cleans **every** Autodesk product from a machine — all versions from 2015 through 2026+.

Built because Autodesk's own Uninstall Tool was [discontinued after 2020](https://resources.imaginit.com/support-blog/where-is-the-autodesk-uninstall-tool-with-autodesk-2022-products), and the standard Windows "Add/Remove Programs" method leaves behind gigabytes of orphaned files, registry keys, services, and licensing artifacts that block fresh installations and waste disk space.

---

## Features

- **Auto-detects all installed Autodesk products** by scanning both 64-bit and 32-bit Windows registry hives
- **Classifies each product's installer type** (ODIS for 2020+, MSI for legacy) and routes to the correct silent uninstall method automatically
- **Dependency-ordered uninstall** — removes products in the correct sequence:
  1. Add-ins, plugins, enablers, language/content packs
  2. Main applications (AutoCAD, Revit, Inventor, Maya, 3ds Max, etc.)
  3. Material Libraries (Medium Resolution → Base Resolution → Core — largest to smallest, per Autodesk docs)
  4. Desktop App, Single Sign-On
  5. Genuine Service (always last)
- **Multi-pass** uninstall — automatically retries failed products up to 4 times with registry rescans between passes, resolving ODIS dependency chains that block single-pass removal
- **Deep clean** removes all traces: folders, registry keys, Windows services, scheduled tasks, firewall rules, FLEXnet files, CLM/LGS license data, ADUT transition data, ODIS cache, environment variables
- **Registry backup** before deletion — `.reg` export files saved to Desktop
- **System Restore Point** creation (optional) with 24-hour limit bypass
- **Real-time progress feedback** on every operation — live dots, counters, per-item status, error codes
- **Final verification scan** confirms clean state
- **Single `.bat` file** — no dependencies, no installation, no PowerShell execution policy issues

<img width="663" height="451" alt="image" src="https://github.com/user-attachments/assets/fd820688-f77c-40fd-9403-0d4ee26f914b" />

<img width="1141" height="858" alt="image" src="https://github.com/user-attachments/assets/03544ac5-920f-4ba6-bcf3-97845a495ce1" />

<img width="601" height="494" alt="image" src="https://github.com/user-attachments/assets/fbbeb783-b0fa-49b2-b0e0-282488711c97" />




---

## Compatibility

| | Supported |
|---|---|
| **Windows 10** (all builds) | ✅ |
| **Windows 11** (all builds) | ✅ |
| **32-bit Windows** | ✅ |
| **64-bit Windows** | ✅ |
| **Autodesk 2015–2021** (Classic/MSI installer) | ✅ |
| **Autodesk 2020–2021** (mixed ODIS + MSI transition) | ✅ |
| **Autodesk 2022–2026+** (ODIS-only installer) | ✅ |
| **Windows Server** | ⚠️ Restore Point not available on Server editions |

---

## Quick Start

1. **Download** `autodesk_complete_uninstaller.bat`
2. **Right-click** → **Run as administrator**
3. Choose **[1] Scan** to see what's installed
4. Choose **[3] Full Uninstall + Deep Clean** to remove everything
5. **Reboot** when done

---

## Menu Options

### [1] Scan Installed Autodesk Software
Scans the Windows registry (both 64-bit and 32-bit hives) and displays all detected Autodesk products with:
- Product name and version
- Installer type (MSI = Classic/Legacy, ODIS = New Installer 2020+)
- Uninstall priority (determines removal order)
- Count of ODIS metadata bundles and AdskUninstallHelper runners
- Detection of legacy artifacts (CLM, FLEXnet, Macrovision)

**You must run Scan before using options [2] or [3].**

### [2] Uninstall Selected Products
Pick specific products by number to uninstall individually. Each product asks for Y/N confirmation. Useful when you want to keep some Autodesk software and remove others.

### [3] Full Uninstall + Deep Clean ALL Products
The main option. Performs a complete removal in 10 phases:

| Phase | What it does |
|-------|-------------|
| A | Creates a System Restore Point (optional, asks Y/N) |
| B | Stops all Autodesk services and kills running processes |
| C | Uninstalls all products in dependency order with multi-pass retry — rescans registry between passes, retries up to 4 times, stops when all removed or no progress |
| D | Runs shared component uninstallers (Identity Manager, ODIS, AdskLicensing, AdskUninstallHelper) |
| E | Deletes all Autodesk folders (10+ locations including the C:\Autodesk staging folder that can be 5–31+ GB) |
| F | Cleans FLEXnet license files, CLM/LGS data, ADUT, ODIS download cache, LoginState.xml, temp files |
| G | Removes orphaned services, scheduled tasks, and firewall rules |
| H | Backs up and deletes all Autodesk registry keys (HKLM, HKCU, WOW6432Node, FLEXlm, Macrovision) |
| I | Removes Autodesk Genuine Service (must be last) |
| J | Runs final verification scan |

### [4] Deep Clean Only
Skips product uninstallation and only removes leftover artifacts. Use this after you've already uninstalled products via Control Panel but still have remnants blocking a fresh install.

### [5] Final Verification
Re-checks everything: installed products, running processes, services, folders, registry keys, legacy licensing artifacts, and environment variables. Reports CLEAN or lists remaining items.

### [6] Create System Restore Point
Creates a Windows System Restore Point before you make any changes. The script:
- Checks if System Restore is enabled and offers to enable it if disabled
- Temporarily bypasses the Windows 24-hour creation limit
- Tries WMIC first, falls back to PowerShell if WMIC fails (newer Win11 builds)

### [7] Exit

---

## What Gets Removed

### Folders
```
C:\Program Files\Autodesk
C:\Program Files\Common Files\Autodesk Shared
C:\Program Files (x86)\Autodesk
C:\Program Files (x86)\Common Files\Autodesk Shared
C:\ProgramData\Autodesk
C:\Users\Public\Documents\Autodesk
C:\Autodesk                                    ← Installer staging, often 5-31+ GB
C:\Program Files\Common Files\Macrovision Shared  ← Legacy FLEXnet
%APPDATA%\Autodesk
%LOCALAPPDATA%\Autodesk
%LOCALAPPDATA%\Programs\Autodesk
%LOCALAPPDATA%\Temp\odis_download_dest         ← ODIS update cache
```

### Registry Keys (backed up before deletion)
```
HKLM\SOFTWARE\Autodesk
HKCU\SOFTWARE\Autodesk
HKLM\SOFTWARE\WOW6432Node\Autodesk
HKLM\SOFTWARE\FLEXlm License Manager
HKCU\SOFTWARE\FLEXlm License Manager
HKLM\SOFTWARE\WOW6432Node\FLEXlm License Manager
HKLM\SOFTWARE\Macrovision
```

### Services
- AdskLicensingService
- AdskAccessServiceHost
- AdAppMgrSvc
- AdskNLM
- Autodesk Genuine Service
- FlexNet Licensing Service 64 (**only if you confirm** — shared with Adobe)

### Other
- Scheduled tasks matching "Autodesk"
- Firewall rules for Autodesk/AutoCAD/Revit/Inventor/Maya/3dsMax/Navisworks
- `ADSKFLEX_LICENSE_FILE` environment variable
- FLEXnet `adsk*` license files in `C:\ProgramData\FLEXnet`
- CLM/LGS license data (`C:\ProgramData\Autodesk\CLM`)
- ADUT transition data (`%APPDATA%\Autodesk\ADUT`)
- `LoginState.xml` SSO token

---

## Important Notes

### Before Running
- **Back up custom templates, families, and profiles** — AutoCAD CUI files, Revit families, custom tool palettes, plot styles, etc. will be permanently deleted
- **Close all Autodesk applications** before running
- **Run as Administrator** — right-click the `.bat` file and select "Run as administrator"
- **Create a restore point first** — use option [6] or the prompt in option [3]
- **Antivirus software** may flag the script because it modifies registry keys and deletes services — this is expected behavior for an uninstaller; you can review the entire script (it's plain text)

### FlexNet / Adobe Warning
The FlexNet Licensing Service 64 is shared between Autodesk and Adobe products. If you use any Adobe software (Photoshop, Illustrator, Premiere, etc.), **do NOT delete this service** when prompted. The script will always ask before touching it.

### After Running
- **Reboot your computer** to finalize removal of services and release locked files
- If verification shows remaining items after reboot, run the script once more
- Registry backups (`.reg` files) are saved to `%USERPROFILE%\Desktop\Autodesk_Uninstaller\`
- To restore registry keys if needed, double-click the `.reg` backup files

### Known Limitations
- Some files locked by Windows Explorer or system processes may not delete until reboot
- ODIS-based products (2020+) that were installed via deployment packages may need the original deployment `Installer.exe` to uninstall cleanly — the script handles this when the metadata exists in `C:\ProgramData\Autodesk\ODIS\metadata\`
- Windows System Restore Points cannot be created more than once per 24 hours (the script bypasses this, but if another tool already created one that day, it may still fail)
- On Windows Server editions, System Restore is not available

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Script closes immediately | Right-click → Run as administrator |
| "Access denied" errors | Ensure no Autodesk apps are running; reboot and try again |
| Products remain after uninstall | Reboot, run Scan again, then use Deep Clean |
| MSI error 1605 (not installed) | Product was already removed; this is safe to ignore |
| MSI error 1603 (fatal error) | Reboot, try again; if persists, use Deep Clean to force-remove |
| ODIS uninstaller hangs | Kill `Installer.exe` in Task Manager, then use Deep Clean |
| Cannot create restore point | System Restore may be disabled; use option [6] to enable it |
| FlexNet service won't delete | Adobe may be using it; skip this step if you use Adobe software |
| Verification shows LOCKED folders | Reboot and run Deep Clean again |

---

## How It Works (Technical Details)

### Product Detection
The script queries both:
- `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall` (64-bit)
- `HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall` (32-bit)

It filters entries where `Publisher` contains "Autodesk" and reads `DisplayName`, `DisplayVersion`, and `UninstallString` for each match. Duplicates between hives are eliminated.

### Installer Type Classification
Each product's `UninstallString` is analyzed:
- Contains `Installer.exe` or `AdskUninstallHelper` → **ODIS** (uses `Installer.exe -i uninstall -q -m <bundleManifest>`)
- Contains `MsiExec` → **MSI** (uses `msiexec /x {GUID} /qn /norestart`)
- Contains `Setup.exe` → **Legacy** (uses `Setup.exe /P {ProductCode} /q`)
- Anything else → **Generic** (runs with `/S /silent /quiet` flags)

### Uninstall Priority System
Products are classified by name pattern matching:

| Priority | Category | Name contains |
|----------|----------|---------------|
| 1 (first) | Add-ins/plugins | Enabler, Plugin, Add-in, Content Pack, Language, Service Pack |
| 3 | Main products | Everything not matching other categories |
| 4 | Material Library Med | "Material Library Medium" |
| 5 | Material Library Base/Core | "Material Library" or "Base Resolution" |
| 6 | Desktop App | "Desktop App" |
| 7 | SSO | "Single Sign" |
| 8 (last) | Genuine Service | "Genuine" |

This follows Autodesk's official guidance: uninstall peripherals before main apps, material libraries from largest to smallest, and Genuine Service absolutely last.

---

## FAQ

**Q: Will this remove cracked/pirated Autodesk software?**
A: The script detects and removes any Autodesk product registered in the Windows Uninstall registry, regardless of how it was installed. However, this tool is provided for legitimate cleanup purposes only.

**Q: Can I use this to remove just one product and keep others?**
A: Yes — use option [2] (Uninstall Selected) to pick specific products. Do NOT use option [3] unless you want to remove everything.

**Q: Will this break other software?**
A: The only shared component is FlexNet Licensing Service 64 (used by Adobe). The script always asks before touching it. All other removals are Autodesk-specific.

**Q: Is it safe to run this on a production workstation?**
A: Create a restore point first (option [6]), back up your custom templates, and ensure you have your Autodesk account credentials for reinstallation. The script is non-destructive to non-Autodesk software.

**Q: The script found 0 products but I know Autodesk is installed.**
A: The product may have been partially uninstalled with its registry entry removed. Use option [4] (Deep Clean) to remove remaining folders, services, and registry keys.

**Q: How much disk space will this free up?**
A: Typically 5–50+ GB depending on how many products were installed and whether the `C:\Autodesk` staging folder was never cleaned up.

---

## Contributing

Issues and pull requests are welcome. If you encounter a product that isn't detected or an uninstall method that fails, please open an issue with:
1. The product name and version
2. The contents of the log file (`%USERPROFILE%\Desktop\Autodesk_Uninstaller\uninstall_log.txt`)
3. Your Windows version (10 or 11, build number)

---

## Disclaimer

This tool is provided as-is, without warranty. Always create a system restore point and back up important data before running. The authors are not affiliated with Autodesk, Inc. "Autodesk", "AutoCAD", "Revit", "Inventor", "Maya", "3ds Max", and "Navisworks" are trademarks of Autodesk, Inc.

---

## License

[MIT License](LICENSE) — free to use, modify, and distribute.
