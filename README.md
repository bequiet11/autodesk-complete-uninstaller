Autodesk Complete Uninstaller

https://github.com/user-attachments/assets/bd4bd647-320c-4940-92b7-65eae7f133db

[![GitHub release](https://img.shields.io/github/v/release/bequiet11/autodesk-complete-uninstaller?color=blue&label=Latest%20Release)](https://github.com/bequiet11/autodesk-complete-uninstaller/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/bequiet11/autodesk-complete-uninstaller/blob/main/LICENSE)
[![Windows](https://img.shields.io/badge/Platform-Windows%2010%2F11-0078D6?logo=windows&logoColor=white)](https://github.com/bequiet11/autodesk-complete-uninstaller)
[![VirusTotal](https://img.shields.io/badge/VirusTotal-0%2F60_Clean-brightgreen?logo=virustotal&logoColor=white)](https://www.virustotal.com/gui/file/0399943b0d8e6f29578b03055184a1d0975d30a2f3319f109e23284df5f80b7c)
[![GitHub downloads](https://img.shields.io/github/downloads/bequiet11/autodesk-complete-uninstaller/total?color=brightgreen&label=Downloads)](https://github.com/bequiet11/autodesk-complete-uninstaller/releases)

A single-file Windows batch tool that fully detects, uninstalls, and deep-cleans **every** Autodesk product from a machine — all versions from 2015 through 2026+. **Achieves a verified zero-remnant clean on real machines without requiring a reboot.**

Built because Autodesk's own Uninstall Tool was [discontinued after 2020](https://resources.imaginit.com/support-blog/where-is-the-autodesk-uninstall-tool-with-autodesk-2022-products), and the standard Windows "Add/Remove Programs" method leaves behind gigabytes of orphaned files, registry keys, services, and licensing artifacts that block fresh installations and waste disk space.

---

<img width="774" height="488" alt="image" src="https://github.com/user-attachments/assets/080939d3-21cf-4de4-9885-50046f2d0082" />

<img width="726" height="539" alt="image" src="https://github.com/user-attachments/assets/2fcf6d7b-65d7-40e4-8d58-c621333f9b6e" />

<img width="774" height="488" alt="image" src="https://github.com/user-attachments/assets/04fbe67a-6b9d-4fd6-8758-1b406ff72e10" />

<img width="777" height="485" alt="image" src="https://github.com/user-attachments/assets/d21c9989-d37e-4daf-9092-3c03cc7c58ee" />

<img width="972" height="1272" alt="image" src="https://github.com/user-attachments/assets/720a4f14-6299-42fa-8196-47ab34ba959f" />



## Features

- **Auto-detects all installed Autodesk products** by scanning both 64-bit and 32-bit Windows registry hives
- **Classifies each product's installer type** (ODIS for 2020+, MSI for legacy, BitRock) and routes to the correct silent uninstall method automatically
- **Dependency-ordered uninstall** — removes products in the correct sequence:
  1. Add-ins, plugins, enablers, language/content packs
  2. Main applications (AutoCAD, Revit, Inventor, Maya, 3ds Max, etc.)
  3. Material Libraries (Medium Resolution → Base Resolution → Core)
  4. Desktop App, Single Sign-On
  5. Genuine Service (always last)
- **Multi-pass retry system** — rescans registry after each pass, retries failed products up to 4 times
- **ODIS orphan detection** — identifies products whose metadata XML is missing and force-cleans their registry entries
- **Deep clean** removes all traces: folders, registry keys, user file associations, COM objects, Windows services, scheduled tasks, firewall rules, shortcuts, shell extensions, FLEXnet files, CLM/LGS license data, ADUT transition data, ODIS cache, environment variables
- **Shell extension unregistration** — unregisters `AcShellExtension.dll` (DWG thumbnail handler) and restarts Explorer to release file locks
- **WMIC wildcard process kill** — terminates ANY process running from Autodesk paths, not just hardcoded names
- **Shortcut cleanup** — removes desktop shortcuts, Start Menu folders, and taskbar pins
- **Registry backup** before deletion — `.reg` export files saved to Desktop
- **System Restore Point** creation (optional) with 24-hour limit bypass
- **Comprehensive diagnostics** — generates `diagnostics.log`, `uninstall_log.txt`, and `verify_details.txt` for troubleshooting
- **12-point deep verification scan** — checks products, processes, services, folders, user data, registry hives, COM/CLSID deep scan, legacy licensing, env variables, shortcuts, tasks, and firewall rules
- **Remnant search tool** — scans entire C: drive for any Autodesk folders, deep-searches registry for file associations and COM objects
- **No reboot required** — achieves full clean in a single run on real machines
- **Single `.bat` file** — no dependencies, no installation, no PowerShell execution policy issues

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

1. **Download** `autodesk_complete_uninstaller.bat` from [Releases](https://github.com/bequiet11/autodesk-complete-uninstaller/releases)
2. **Right-click** → **Run as administrator**
3. Choose **[1] Scan** to see what's installed
4. Choose **[3] Full Uninstall + Deep Clean** to remove everything
5. Run **[5] Final Verification** to confirm zero remnants

---

## Menu Options

| Option | Description |
|--------|-------------|
| **[1] Scan** | Detect all installed Autodesk products with type, priority, and version info |
| **[2] Uninstall Selected** | Pick specific products to remove individually |
| **[3] Full Uninstall + Deep Clean** | Complete removal: uninstall all products + remove all traces |
| **[4] Deep Clean Only** | Remove remnants without product uninstall (for post-Control Panel cleanup) |
| **[5] Final Verification** | 12-point deep scan to confirm zero remnants |
| **[6] Create System Restore Point** | Create a restore point before making changes |
| **[7] Search for ALL Autodesk Remnants** | Full system scan — folders, registry deep search, processes, services |
| **[8] Exit** | Exit the tool |

---

## How [3] Full Uninstall + Deep Clean Works

| Phase | What it does |
|-------|-------------|
| **A** | Creates a System Restore Point (optional) |
| **B** | Stops all services, kills all Autodesk processes (named + WMIC wildcard path kill) |
| **C** | Uninstalls products in dependency order with multi-pass retry (up to 4 passes) |
| **C2** | Force-deletes registry entries for any products that survived all passes |
| **D** | Runs shared component uninstallers (Identity Manager, ODIS, AdskLicensing, Desktop App) |
| **E** | Kills residual processes, unregisters shell extensions, restarts Explorer, stops Windows Search, deletes all folders with takeown/icacls fallback |
| **E2** | Removes all shortcuts (desktop, Start Menu, taskbar) |
| **F** | Cleans FLEXnet, CLM, ADUT, ODIS cache, LoginState.xml, temp files |
| **G** | Removes orphaned services, scheduled tasks, firewall rules |
| **H** | Backs up and deletes all Autodesk registry keys |
| **H2** | Cleans user file associations (DWGTrueView, AutoCAD class keys, COM CLSIDs, MuiCache) |
| **I** | Removes Autodesk Genuine Service (always last) |
| **J** | Runs 12-point final verification |

---

## What Gets Removed

### Folders
```
C:\Program Files\Autodesk
C:\Program Files\Common Files\Autodesk Shared
C:\Program Files\Common Files\Autodesk
C:\Program Files (x86)\Autodesk
C:\Program Files (x86)\Common Files\Autodesk Shared
C:\Program Files (x86)\Common Files\Autodesk
C:\ProgramData\Autodesk
C:\Users\Public\Documents\Autodesk
C:\Autodesk                                        ← Installer staging, often 5-31+ GB
C:\Program Files\Common Files\Macrovision Shared
%APPDATA%\Autodesk
%LOCALAPPDATA%\Autodesk
%LOCALAPPDATA%\Programs\Autodesk
%LOCALAPPDATA%\Temp\odis_download_dest
C:\Windows\System32\config\systemprofile\...\Autodesk  ← SYSTEM account
```

### Registry (backed up before deletion)
```
HKLM\SOFTWARE\Autodesk
HKCU\SOFTWARE\Autodesk
HKLM\SOFTWARE\WOW6432Node\Autodesk
HKLM\SOFTWARE\FLEXlm License Manager (+ HKCU + WOW6432Node)
HKLM\SOFTWARE\Macrovision
HKCU\SOFTWARE\Classes\DWGTrueView*     ← ~90 file association keys
HKCU\SOFTWARE\Classes\AutoCAD*
HKCU\SOFTWARE\Classes\AutodeskDGN, AutoLISPFile, 3dsFile, dwgviewr, etc.
HKCU\SOFTWARE\Classes\CLSID\{Autodesk CLSIDs}
Shell extension approvals, MuiCache entries
ADSKFLEX_LICENSE_FILE environment variable
```

### Services
- AdskLicensingService, AdskAccessServiceHost, AdAppMgrSvc, AdskNLM
- Autodesk Genuine Service
- FlexNet Licensing Service 64 (**only if you confirm** — shared with Adobe)

### Other
- Scheduled tasks, firewall rules, desktop/Start Menu/taskbar shortcuts
- FLEXnet adsk* files, CLM/LGS data, ADUT, LoginState.xml, ODIS cache

---

## Output Files

The tool creates a folder on your Desktop: `Autodesk_Uninstaller\`

| File | Purpose |
|------|---------|
| `uninstall_log.txt` | Product-level log with commands executed and exit codes |
| `diagnostics.log` | System info, ODIS state, phase timestamps, error output |
| `verify_details.txt` | Detailed list of any items found during verification |
| `remnant_scan.txt` | Full system scan results (option [7]) |
| `*.reg` | Registry backups (can double-click to restore) |
| `reboot_cleanup.bat` | Auto-scheduled cleanup for locked folders (if needed) |

---

## Important Notes

### Before Running
- **Back up custom templates, families, and profiles** — AutoCAD CUI files, Revit families, plot styles, etc. will be permanently deleted
- **Close all Autodesk applications** before running
- **Run as Administrator** — right-click the `.bat` file and select "Run as administrator"

### FlexNet / Adobe Warning
The FlexNet Licensing Service 64 is shared between Autodesk and Adobe. If you use Adobe software, **do NOT delete this service** when prompted.

### After Running
- Run **[5] Final Verification** to confirm clean state
- Registry backups (`.reg` files) are saved to `Desktop\Autodesk_Uninstaller\`
- The tool briefly restarts Windows Explorer during cleanup (taskbar disappears for ~2 seconds) — this is normal

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Script closes immediately | Right-click → Run as administrator |
| "Access denied" errors | Ensure no Autodesk apps are running; try again |
| Products remain after uninstall | Run [4] Deep Clean to force-remove |
| ODIS uninstaller fails (exit:1) | Phase C2 automatically force-cleans these |
| Folders show as LOCKED | Tool uses takeown/icacls + Explorer restart; run Deep Clean again |
| Verification shows items in [7/12] | Run [4] Deep Clean to remove file associations |
| Antivirus blocks or quarantines the script | Add an exclusion for the `.bat` file or temporarily disable real-time protection; this is a false positive |
| Windows SmartScreen blocks the file | Click **More info** > **Run anyway** — the script is unsigned but open source |

---

## FAQ

**Q: Will this break other software?**
A: The only shared component is FlexNet Licensing Service 64 (used by Adobe). The script always asks before touching it. Generic file type associations (EPS, WMF, Ghostscript) are intentionally left alone.

**Q: Can I remove just one product?**
A: Yes — use option [2] to pick specific products.

**Q: Does it require a reboot?**
A: No. The tool achieves a verified zero-remnant clean on real machines in a single run.

**Q: How much disk space will this free?**
A: Typically 5–50+ GB depending on installed products and the `C:\Autodesk` staging folder.

**Q: My antivirus flagged the script. Is it safe?**
A: Yes. The script is a plain-text `.bat` file — you can read every line in Notepad before running it. Antivirus software sometimes flags unsigned batch scripts that modify the registry. Add an exclusion or temporarily disable real-time protection to run it.

---

## Contributing

Issues and pull requests are welcome. If you encounter a product that isn't detected or an uninstall method that fails, please open an issue with:
1. The product name and version
2. The log files from `Desktop\Autodesk_Uninstaller\`
3. Your Windows version (10 or 11, build number)

---

## Disclaimer

This tool is provided as-is, without warranty. Always create a system restore point and back up important data before running. The authors are not affiliated with Autodesk, Inc. "Autodesk", "AutoCAD", "Revit", "Inventor", "Maya", "3ds Max", and "Navisworks" are trademarks of Autodesk, Inc.

---

## License

[MIT License](LICENSE) — free to use, modify, and distribute.
