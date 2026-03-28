# Changelog

## v5.5 (2026-03-28)

### Fixed
- **ODIS path quoting (critical):** All ODIS uninstalls silently failed with `'C:\Program' is not recognized` — `cmd /c "!UCMD!"` stripped outer quotes, breaking paths with spaces in "Program Files". Fixed at 3 execution points using delayed-expansion wildcard substitution to separate exe path from arguments. ODIS's own cleanup routines (license state, shared component ref-counting) now execute properly.
- **HKLM COM registry cleanup:** CLSID and TypeLib entries in `HKLM\SOFTWARE\Classes` were detected by scans but never cleaned by any phase — added cleanup to both Full Clean Phase H2 and Deep Clean
- **Orphan HKCU class keys:** `acadlt.*` (AutoCAD LT 2025/2026), `adsk.idmgr`, `adskidmgr` (Identity Manager URL handlers) survived cleanup due to missing search patterns — added to Phase H2, Deep Clean, and scan classification

### Added
- Cleanup for `%LOCALAPPDATA%\com.autodesk.cer-dialog` (CER error dialog data at non-standard path outside `%LOCALAPPDATA%\Autodesk`)
- Cleanup for .NET NativeImages cache (`C:\Windows\assembly\NativeImages_v4.0.30319_*\Autodesk*`) — both 32-bit and 64-bit directories

### Verified
- **Zero-remnant result** on G9-BOX after Full Clean + Deep Clean of 38 products (AutoCAD LT 2025 + 2026, Maya 2025, Revit 2025, DWG TrueView 2026, Design Review, Autodesk Access, and 31 shared components). `verify_details.txt` empty, 12/12 checks CLEAN.

## v5.4 (2026-03-28)

### Fixed
- **Option [7] terminal flood:** Replaced raw `type` dump of `remnant_scan.txt` with summary-only display — 11 categories with counters, color-coded, TOTAL row. Full details remain in file only.
- **Crash bug:** Unescaped parentheses in `if ( )` blocks — `(CLSID + TypeLib)`, `(informational only, not counted)`, `(32-bit)`, `(PID: %%b)` — all fixed with `^(` `^)` escaping

### Added
- Live counters on all 11 scan steps at column 50

## v5.3 (2026-03-28)

### Improved
- **Audit UX polish:** "Please wait" patience message, all 13 steps aligned to column 50
- **Error 103 enhanced:** Windows Event Viewer analysis [9/9] via PowerShell `Get-WinEvent`, Autodesk Access version detection from file properties, ODIS Installer version detection
- Renumbered Error 103 diagnostic checks from [X/7] to [X/9]

## v5.2 (2026-03-28)

### Fixed
- **Audit crash:** `for /f` with pipe inside `if ( )` block + nested ifs — moved outside blocks, flattened with flags

### Added
- **[10] Fix Error 103** — 9-point diagnostic for ODIS installer issues: lock file, debugger keys (IFEO), Autodesk Access + ODIS Installer version, service state, ODIS infrastructure, ProductInformation.pit, TEMP paths, VC++ redistributables, Windows Event Viewer analysis
- Menu reorganized: Exit moved to [0], choice range [0-10]

## v5.1 (2026-03-28)

### Added
- **[8] Full System Audit** — 13-point read-only scan showing everything that would be removed, with disk space calculation
- Live counters replacing dots (ANSI cursor positioning `ESC[48G]`)
- Disk space calculation via PowerShell (handles >4GB)
- Installer/download folder detection — separates Downloads/Chrome cache from product remnants
- Optional installer/download cleanup prompt in Full Clean [3] and Deep Clean [4]

## v5.0 (2026-03-25)
- Major UX overhaul with full ANSI color support and visual enhancements
- NEW: Color-coded console output using ANSI escape sequences (16 foreground + 4 background colors)
- NEW: Real-time progress bar with 12-phase tracking and percentage display
- NEW: Timestamped operations — every action logged with [HH:MM:SS] prefix
- NEW: Color-coded main menu with distinct colors per option (scan, uninstall, deep clean, verify, etc.)
- NEW: Live progress counters during product scanning and uninstallation
- NEW: Phase-by-phase status indicators with OK/FAIL/SKIP/WARN/INFO badges
- NEW: Remnant search with animated scanning indicator and categorized results
- NEW: Summary dashboard after uninstall showing products removed, time elapsed, and pass/fail counts
- NEW: Enhanced verification output with color-coded pass/fail for each of 12 check categories
- Improved log file headers with version and timestamp
- **Result: Complete visual transformation — professional CLI experience with zero functional regression**

## v4.4 (2026-03-24)
- NEW: Phase H2 — cleans ~90 user file association registry keys (DWGTrueView*, AutoCAD*, AutodeskDGN, AutoLISPFile, 3dsFile, dwgviewr, etc.)
- NEW: Broad `HKCU\SOFTWARE\Classes` search for any Autodesk-named keys with exclusion filter to protect non-Autodesk keys (EncapsulatedPostscript, Ghostscript, WindowsMetafile, etc.)
- NEW: Remnant scan now separates ADSK-CLASS (safe to delete) from GENERIC-ICON (not Autodesk, leave alone)
- NEW: Verification check 7 now only counts Autodesk-specific entries, with full logging to verify_details.txt
- Two-pass registry cleanup to catch parent-child key hierarchies
- **Result: FULLY CLEAN — Zero Autodesk remnants on real machine, no reboot**

## v4.1 (2026-03-24)
- NEW: 12-point deep verification scan (products, processes, services, program folders, user data folders, registry hives, COM/CLSID deep scan, legacy licensing, env variables, shortcuts, scheduled tasks, firewall rules)
- NEW: Generates verify_details.txt with exact path of every finding
- NEW: Cleans SYSTEM account profile folder (C:\Windows\System32\config\systemprofile\AppData\Local\Autodesk)
- Remnant scan enhanced with deep registry search: COM CLSIDs, TypeLibs, file associations, shell extensions, uninstall registry

## v4.0 (2026-03-24)
- FIX: AcShellExtension.dll (DWG thumbnail handler) locked by explorer.exe — now unregistered via regsvr32 /u before folder deletion
- Also handles DwfShellExtension.dll
- Explorer briefly killed and restarted to release DLL handles
- **Result: C:\Program Files\Common Files\Autodesk Shared finally deletes**

## v3.9 (2026-03-24)
- FIX: AdskAccessService.exe was holding locks on all Autodesk folders — added to all kill lists
- NEW: WMIC wildcard process kill — terminates ANY process running from Autodesk paths
- NEW: `net stop WSearch` before folder deletion to release Windows Search index handles
- NEW: Menu option [7] Search for ALL Autodesk remnants — generates remnant_scan.txt with full system scan
- NEW: C:\Program Files\Common Files\Autodesk added to all cleanup locations
- Second process kill pass before Deep Clean folder deletion
- **Result: 4 locked folders → 1 on real machine**

## v3.8 (2026-03-24)
- FIX: ODIS output capture empty — changed from `start /wait "" cmd /c` to direct `cmd /c` for proper stdout/stderr capture
- NEW: Copies ODIS internal log files to odis_logs\ subfolder for diagnosis
- NEW: Second process kill pass before Phase E folder deletion (kills Installer.exe, AdODIS.exe, etc.)
- 3-second delay after process kill for file handle release
- C:\Program Files\Common Files\Autodesk added to Phase E, reboot_cleanup, Deep Clean, and Verification

## v3.7 (2026-03-24)
- FIX: reboot_cleanup.bat was deleting the main tool instead of itself — %~f0 expanded to wrong path
- FIX: ODIS output capture — captures both stdout and stderr to diagnostics.log
- ODIS internal log files copied to Autodesk_Uninstaller\odis_logs\ for diagnosis
- Installer.exe file size logged in startup diagnostics

## v3.6 (2026-03-23)
- NEW: Phase E2 — shortcut cleanup (desktop, Start Menu, taskbar pins)
- NEW: Retry pass ODIS metadata pre-flight check — skips ODIS if XML manifest is gone
- NEW: Locked folder force-delete with takeown + icacls before rd /s /q
- NEW: Reboot cleanup script via HKLM\RunOnce for folders that survive
- NEW: Scan shows [ORPHAN] tag for ODIS products with missing metadata
- Verification now checks for remaining shortcuts
- Deep Clean gets all improvements (takeown/icacls, shortcut cleanup)
- Version bump to v3.6

## v3.5 (2026-03-23)
- FIX: Replaced /S /silent /quiet with --mode unattended in all generic fallbacks
  (BitRock-based Autodesk uninstallers showed GUI error popup when passed /S flag)
- NEW: Comprehensive diagnostics file (diagnostics.log)
- NEW: Phase C2 — force-cleans stuck registry entries after all multi-pass retries
- NEW: ODIS pre-flight check — verifies metadata XML exists before attempting ODIS uninstall
- Enhanced logging: every product logs type, exact command, exit code, and UninstallString

## v3.4 (2026-03-23)
- All Autodesk component uninstallers now use --mode unattended flag (BitRock framework)
  RemoveODIS.exe, AdskIdentityManager\uninstall.exe, AdskLicensing\uninstall.exe, removeAdAppMgr.exe
- Added extra processes to kill lists: AdskAccessCore.exe, ADPClientService.exe, AcEventSync.exe, FNPLicensingService64.exe

## v3.3 (2026-03-23)
- FIX: Phase A crash — nested if blocks with WMIC commands containing %date%. Flattened to goto-based flow
- FIX: Phase C crash — goto inside nested for loops corrupts CMD loop state. Replaced with _HANDLED flag pattern
- Applied _HANDLED pattern to both Phase C Pass 1 and Uninstall Selected section

## v3.2 (2026-03-23)
- NEW: Multi-pass retry system for Phase C — rescans registry after Pass 1, retries up to 3 more times
- 5-second pause between passes for MSI/ODIS transaction finalization
- Stuck detection: stops if no progress after retry 2+

## v3.1 (2026-03-22)
- Initial public release
- 7-option menu: Scan, Uninstall Selected, Full Uninstall + Deep Clean, Deep Clean Only, Verification, Restore Point, Exit
- 10-phase full clean (A through J)
- Priority-ordered uninstall (8 priority levels)
- ODIS/MSI/Legacy/Generic installer detection
- Registry backup before deletion
- System Restore Point with 24-hour bypass
- Supports Autodesk 2015–2026+ on Windows 10/11
