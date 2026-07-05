# Changelog

## [v5.12] - 2026-07-05

### Added — Desktop Connector Coverage & 2027 Readiness
- **Desktop Connector remnant handling**: tray process (`DesktopConnector.Applications.Tray.exe`) and core service (`DesktopConnector.Core.Service.exe`) added to kill lists; `DesktopConnectorService` added to stop/delete lists across Full Clean Phase B, Deep Clean, remnant scan, audit, and verify
- **Opt-in workspace cleanup**: new menu option **[9]** plus in-flow prompts in Full Clean and Deep Clean to remove the local Desktop Connector workspace (`%USERPROFILE%\DC`, `%USERPROFILE%\ACCDocs`), guarded by an explicit data-loss warning — the standalone option requires typing `YES`; in-flow prompts default to N
- **2027 product line**: Revit / AutoCAD / Civil 3D / Inventor / Vault / InfraWorks / ReCap 2027 — detection is Publisher-based, verified against ODIS 2027 registration (no code change needed; banner and docs updated)
- **17-point verification** (was 16): added a Desktop Connector check — leftover binaries/service count as remnants, while workspace folders are reported as user data and never counted
- **Elapsed timing**: Deep Clean and Verify now print Started/Completed timestamps, captured after the prompts so operator think-time is excluded

### Fixed
- **Line endings (CRLF)**: the script now ships with CRLF endings so every menu option launches reliably — cmd.exe resolves `goto` by byte position and failed to reach labels deep in the previously LF-only file, which could prevent the remnant scan, audit, verification, and other deep-menu options from starting
- **Workspace deletion data-loss guard** (CRITICAL): `DTC_ANS` is cleared before every workspace prompt — previously a stale `Y`/`YES` plus a bare Enter on a later run could delete the workspace with no confirmation
- **Priority classification tokens**: addon and material-library detection converted to `/c:"exact phrase"` — bare words like "Service" / "Content" / "Library" no longer misclassify unrelated products
- **Menu input**: pressing Enter with no choice no longer repeats the previous action; invalid input now shows feedback
- **UAC relaunch quoting**: elevation passes the script path via an environment variable — no longer fails silently on paths containing apostrophes or ampersands
- **Full Clean Phase B**: `DesktopConnectorService` is now stopped alongside the other services

### Changed
- **Deep Clean is strictly remnant-only**: no longer executes `AdskUninstallHelper.exe` (which could open an interactive wizard and hang); the Uninstallers folder is removed as a remnant during folder deletion
- **Faster menu redraw**: the script SHA-256 is computed once per session instead of on every menu draw
- **Remnant scan**: the Desktop Connector workspace is listed for visibility but excluded from the remnant count, matching audit and verify semantics

## [v5.11] - 2026-04-05

### Added — UX, Safety, and Localization
- **MSI exit code intelligence**: Exit 1605 shows green "OK (already removed)", exits 1641/3010 show green "OK (reboot scheduled/suggested)" instead of red FAIL. Pass 1 summary includes reassurance message for users
- **ODIS exit display fix**: Fixed false "FAIL exit:0" display caused by trailing space in done-file — ODIS successes now correctly show green OK
- **Localized ACLs**: All `icacls Everyone:F` replaced with `*S-1-1-0:F` — works on non-English Windows (Spanish, French, German, etc.)
- **Firewall rule localization**: Replaced locale-dependent `netsh` + `findstr "Rule Name:"` with PowerShell `Get-NetFirewallRule` — works on all Windows languages
- **MuiCache PowerShell cleanup**: Replaced fragile `for /f "tokens=1,*"` registry parsing (truncated paths with spaces) with PowerShell `Get-ItemProperty` enumeration
- **wmic process kill fallback**: Added PowerShell `Get-Process | Stop-Process` fallback after every `wmic process where` call — ensures process termination on Windows 11 24H2+ where wmic is removed
- **PFRO pair-aware filtering**: PendingFileRenameOperations cleanup in Phase H and Deep Clean now iterates in Source/Target pairs (`$i+=2`), preventing array misalignment that could corrupt Windows Update pending renames
- **Restore point frequency cleanup**: `SystemRestorePointCreationFrequency` registry override is now deleted after restore point creation (success or failure), restoring Windows' default 24-hour policy
- **wmic restore point validation**: Checks `ReturnValue = 0` in wmic output instead of relying on errorlevel (which always returns 0 even on WMI-layer failures)
- **Backup error reporting**: xcopy operations in Option [12] and Full Clean backup now check errorlevel — partial copies show yellow warning instead of false green "done"
- **Preparing indicator**: Shows "Preparing..." after YES confirmation to bridge the gap before Phase B starts

### Fixed
- **findstr space delimiter** (CRITICAL): All multi-word product name patterns converted to `/c:"exact phrase"` syntax — prevents deletion of unrelated shortcuts (e.g., "Max Payne", "SteelSeries", "HBO Max") that matched individual words
- **Locked folder path quoting**: Paths with spaces appended to `LOCKED_LIST`/`DC_LOCKED` are now quoted, preventing `rd /s /q "C:\Program"` on split tokens
- **Hosts file echo redirect**: Moved redirection to front of line (`>>"file" echo(%%h`) — prevents `1>>` stream redirection consuming trailing digits from IP addresses
- **Hosts file indented comments**: Comment detection now handles leading whitespace (`    # comment`) via `for /f "tokens=*"` trimming, not just column-1 `#`
- **Remnant scan browser exclusions**: Audit browser/installer path classification uses `/c:"\Edge\User Data\"` instead of space-separated `\Edge\User Data\` (which matched `\Edge\User` OR `Data\` independently)
- **Remnant scan Downloads filter**: Exclusion now targets specific product names (`\Downloads\Autodesk`, `\Downloads\AutoCAD`, etc.) instead of broadly excluding any path containing "Downloads"

## [v5.9] - 2026-04-05

### Added — Competitive Analysis Features
- **MSI cleanup flags**: Added `REMOVE=ALL REBOOT=ReallySuppress` to all 6 `msiexec /x` calls for cleaner uninstallation
- **Installer\Products ghost cleanup**: Detects and removes orphaned `HKLM\SOFTWARE\Classes\Installer\Products` entries in Phase H, Deep Clean, Scan [11/15], Audit [13/17], and Verify [10/16]
- **System PATH cleanup**: Removes dead Autodesk/AdODIS entries from system PATH with automatic backup (PowerShell-based, handles all edge cases)
- **Environment variable cleanup**: Detects and removes `ADSKFLEX_LICENSE_FILE`, `ADSK_LICENSE_FILE`, `AUTODESK_LICENSE_FILE`, `FLEXLM_TIMEOUT` from system and user environment (Phase H, Deep Clean, Scan, Audit, Verify)
- **Multi-user cleanup**: Enumerates all user profiles via SID, loads offline NTUSER.DAT hives, cleans `Software\Autodesk` registry and AppData folders. Skips logged-in users (HKU hive check) and current user (USERPROFILE comparison)
- **Public folder cleanup**: Added `C:\Users\Public\Autodesk` to Phase E, Deep Clean, and Verify folder lists
- **Windows Temp cleanup**: Targeted removal of `C:\Windows\Temp\*Autodesk*` files and folders in Phase F and Deep Clean

### Fixed
- **PATH cleanup hang**: Replaced fragile CMD `for %%p in ("!SYSPATH:;=" "!")` string-splitting with PowerShell `[Environment]::GetEnvironmentVariable` — fixes infinite hang on machines with trailing backslashes in PATH entries
- **PendingFileRenameOperations**: Option [11] now deletes PFRO entirely (consistent with Key Decision #4: clear ALL reboot state), instead of filtering Autodesk entries only
- **wmic date fallback**: Backup date stamps now fall back to PowerShell `Get-Date` when wmic is unavailable (Windows 11 builds where wmic is removed)
- **Multi-user safety**: Profile identification uses `%USERPROFILE%` comparison instead of folder name (handles domain accounts, renamed accounts). AppData loop checks HKU hive before deletion (protects logged-in users)
- **Installer\Products backup**: Registry backup exported before deletion loop, not inside it (prevents overwrite when multiple products match)
- **ProfileImagePath expansion**: Added `call set` to expand `REG_EXPAND_SZ` values containing `%SystemDrive%` in multi-user profile paths

### Changed
- **Option [11] reboot messaging**: "A system reboot is recommended but not required" — users can proceed without rebooting
- **Removed winmgmt restart**: All `net stop/start winmgmt` calls removed (caused 4-minute hangs, msiserver flush is sufficient)

## v5.8 (2026-04-02)

### Added — Installation Readiness
- **IFEO debugger block cleanup (Phase H3):** Removes `Debugger=Blocked` on 15 Autodesk executables — fixes "Preparing for installation" failures from cracked software
- **PendingFileRenameOperations cleanup:** Removes Autodesk entries from pending reboot operations — fixes reboot loops
- **Hosts file detection (Error 103 [10/10]):** Detects entries blocking Autodesk license servers with guided repair
- **Pending reboot state cleanup:** Clears RebootRequired, Orchestrator/RebootRequired, UpdateExeVolatile + flushes msiserver — fixes "An operating system restart is pending"
- **Option [11] Fix Restart Pending:** 5-point reboot indicator diagnostic with repair
- **Option [12] Backup Templates:** Save custom templates, profiles, settings before cleanup

### Added — UX
- **ODIS progress dots** during long uninstalls instead of frozen screen
- **Time estimate** before Phase C based on product count
- **Progress counter [X/Y]** per product with ODIS patience messages
- **Timestamps on all** verification, scan, and audit lines
- **Console log** (console_log.txt) mirrors all key operations
- **Templates backup prompt** before Full Clean
- **Installer cleanup tip** and **restore point tip** with color-coded guidance

### Fixed
- **Process check performance:** Replaced tasklist (4-min hang after cleanup) with PowerShell Get-Process (~1 sec)
- **Error 103 ODIS status:** Shows "NOT INSTALLED" instead of false "DAMAGED" when no products exist
- **Timestamp bug:** All %time% converted to !time! for correct delayed expansion
- **Verify RM count:** RebootRequired flags now correctly counted in total

### Improved
- Error 103: 10-point diagnostic (was 9), IFEO check 15 executables (was 4)
- Verify: 15 checks, Scan: 14 steps, Audit: 16 steps
- HKCU\SOFTWARE\SOFTWARE\Autodesk duplicate path cleanup
- Locale-safe backup date via wmic localdatetime
- ODIS timeout: 10 minutes (was 5)
- Public Documents included in backup


## v5.7 (2026-03-29)

### Fixed
- **Locked folder retry (Phase E3):** After all phases complete, retries deletion of any folders that were locked during Phase E — kills all processes, stops msiserver + WSearch, restarts explorer, then retries with takeown/icacls and file-level delete fallback
- **Stop msiserver before folder deletion:** Windows Installer service holds handles on `C:\Autodesk\IM\BackUps\` staging area created by ODIS uninstaller. Now stopped in Phase B and Deep Clean main kill sequence, before first deletion attempt
- **Reboot cleanup gated:** `reboot_cleanup.bat` only generated if folders are STILL locked after Phase E3 retry (previously generated immediately on first failure)

### Improved
- Deep Clean now tracks locked folders (`DC_LOCKED`) and retries with same Phase E3 strategy
- File-level delete fallback: `del /f /s /q` + bottom-up `rd` removes files individually when `rd /s /q` fails on a tree

### Verified
- **Zero-remnant result without reboot** on G9-BOX — `C:\Autodesk` (previously always locked) now deletes on first attempt. 12/12 checks CLEAN.

## v5.6 (2026-03-29)

### Improved
- **Shared data definitions:** Process kill lists, service names, and class key lists consolidated into variables defined once at top of script — reduces duplication and file size
- **SHA-256 self-verification:** Script displays its own hash on startup via `certutil` for integrity checking against published hashes

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
