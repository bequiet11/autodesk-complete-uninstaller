# Changelog

## v3.1 (2026-03-22)
- Added System Restore Point creation (WMIC + PowerShell fallback)
- Added 24-hour restore point bypass
- Dependency-ordered uninstall (add-ins first, Genuine Service last)
- Material Libraries removed in correct order (Medium → Base → Core)
- Priority classification shown in scan results
- Restructured menu: merged "Uninstall All" into "Full Clean" as single option
- Real-time progress feedback on all operations (dots, counters, per-item status)
- Error codes reported for every failed operation
- Windows 10 and Windows 11 compatibility verified
- 32-bit and 64-bit Windows support

## v3.0 (2026-03-22)
- Added live progress indicators to all operations
- Scanning shows dot-per-20-keys and +N per product found
- Uninstall shows per-product status with error codes
- Folder deletion shows per-path result (deleted/LOCKED)
- Registry shows per-key backup and deletion status

## v2.0 (2026-03-22)
- Added legacy version support (2015-2021)
- Three uninstall methods: ODIS, MSI, Legacy Setup.exe
- Added CLM/LGS cleanup (2017-2019 licensing)
- Added Macrovision Shared folder cleanup
- Added ADUT transition data cleanup
- Added AdskUninstallHelper runner detection (2022+)
- Added legacy Autodesk Uninstall Tool detection

## v1.0 (2026-03-22)
- Initial release
- Auto-detection of installed Autodesk products
- Selective or bulk uninstall
- Deep clean (folders, registry, services, tasks, firewall)
- Registry backup before deletion
- Final verification scan
