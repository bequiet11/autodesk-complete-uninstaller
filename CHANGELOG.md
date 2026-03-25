# Changelog

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
