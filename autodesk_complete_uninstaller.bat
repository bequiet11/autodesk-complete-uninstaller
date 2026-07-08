@echo off
setlocal enabledelayedexpansion
set "SELFDIR=%~dp0"
chcp 437 >nul 2>&1
title Autodesk Universal Uninstaller v5.12

REM === ANSI Color Setup ===
for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "R=!ESC![0m"
set "BOLD=!ESC![1m"
set "DIM=!ESC![90m"
set "CRED=!ESC![91m"
set "CGRN=!ESC![92m"
set "CYLW=!ESC![93m"
set "CBLU=!ESC![94m"
set "CMAG=!ESC![95m"
set "CCYN=!ESC![96m"
set "CWHT=!ESC![97m"
set "BG_GRN=!ESC![42m"
set "BG_RED=!ESC![41m"
set "BG_BLU=!ESC![44m"
set "BG_CYN=!ESC![46m"
set "OK=!CGRN![OK]!R!"
set "FAIL=!CRED![FAIL]!R!"
set "SKIP=!CYLW![SKIP]!R!"
set "WARN=!CYLW![WARN]!R!"
set "INFO=!CCYN![INFO]!R!"

REM === SHARED DATA LISTS ===
REM Process names to kill (used by Phase B, Phase E, Deep Clean)
set "KILL_PROCS=AdSSO.exe AdskLicensingService.exe AdskLicensingAgent.exe AdskIdentityManager.exe GenuineService.exe AdAppMgrSvc.exe AutodeskDesktopApp.exe RevitAccelerator.exe acad.exe lmgrd.exe adskflex.exe AdskAccessServiceHost.exe AdskAccessService.exe AdskAccessCore.exe ADPClientService.exe AcEventSync.exe FNPLicensingService64.exe Installer.exe setup.exe AdODIS.exe DesktopConnector.Applications.Tray.exe DesktopConnector.Core.Service.exe AdskAccessUIHost.exe"

REM Service names to stop/delete (used by Phase B, Phase G, Deep Clean)
set "SVC_NAMES=AdskLicensingService AdskAccessServiceHost AdAppMgrSvc AdskNLM DesktopConnectorService"

REM HKCU named class keys to clean (used by Phase H2, Deep Clean, remnant scan, audit, verify)
set "CLASS_KEYS=AutodeskDGN AutoLISPFile 3dsFile cdc_auto_file CompleteR16PlotConfigurationFile adsk.idmgr adskidmgr"

REM Process names for scan display (without .exe, for wmic/process detection)
set "KILL_PROCS_SCAN=AdSSO AdskLicensing AdskAccess GenuineService AdAppMgr AutodeskDesktopApp acad lmgrd adskflex AdODIS Installer RevitAccelerator DesktopConnector"

REM IFEO executables to check for debugger blocks (used by Error 103, Phase H3, Deep Clean, verify)
set "IFEO_EXES=ProcessManager.exe DownloadManager.exe InstallManager.exe install_manager.exe install_helper_tool.exe AdODIS-installer.exe GenuineService.exe AdskIdentityManager.exe Installer.exe AdskAccessServiceHost.exe AdskAccessService.exe AdskAccessCore.exe AdSSO.exe AdskLicensingService.exe LogAnalyzer.exe"

REM === ADMIN CHECK + SELF-ELEVATION ===
REM If not elevated, relaunch via UAC. The elevated copy re-runs from the
REM top, passes this check, and continues. If the user declines UAC, the
REM relaunch fails silently and this (non-elevated) instance has already
REM exited - no loop.
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  !CCYN!Requesting administrator privileges...!R!
    echo  !DIM!Please approve the User Account Control ^(UAC^) prompt.!R!
    echo  !DIM!If you decline, the tool cannot run.!R!
    echo.
    set "ELEV_PATH=%~f0"
    powershell -NoProfile -Command "Start-Process -FilePath $env:ELEV_PATH -Verb RunAs" >nul 2>&1
    exit /b
)

set "LOGDIR=%USERPROFILE%\Desktop\Autodesk_Uninstaller"
mkdir "!LOGDIR!" 2>nul
set "LOGFILE=!LOGDIR!\uninstall_log.txt"
set "DIAGFILE=!LOGDIR!\diagnostics.log"

REM Create log file with header
type nul > "!LOGFILE!"
echo Autodesk Universal Uninstaller v5.12 >> "!LOGFILE!"
echo Date: %date% %time% >> "!LOGFILE!"
echo ------------------------------------------------ >> "!LOGFILE!"

REM Create console log file
set "CLOG=!LOGDIR!\console_log.txt"
type nul > "!CLOG!"
echo ============================================================ >> "!CLOG!"
echo  CONSOLE OUTPUT LOG >> "!CLOG!"
echo  Autodesk Universal Uninstaller v5.12 >> "!CLOG!"
echo  Date: %date% %time% >> "!CLOG!"
echo  Computer: %COMPUTERNAME%  User: %USERNAME% >> "!CLOG!"
echo ============================================================ >> "!CLOG!"

REM Create diagnostics file
type nul > "!DIAGFILE!"
echo DIAGNOSTICS LOG >> "!DIAGFILE!"
echo Date: %date% %time% >> "!DIAGFILE!"
echo ------------------------------------------------ >> "!DIAGFILE!"
echo SYSTEM: >> "!DIAGFILE!"
ver >> "!DIAGFILE!" 2>&1
echo Host: %COMPUTERNAME%  User: %USERNAME%  Arch: %PROCESSOR_ARCHITECTURE% >> "!DIAGFILE!"
echo ------------------------------------------------ >> "!DIAGFILE!"
echo ODIS INFRASTRUCTURE: >> "!DIAGFILE!"
if exist "C:\Program Files\Autodesk\AdODIS\V1\Installer.exe" (
    echo  Installer.exe: EXISTS >> "!DIAGFILE!"
    for %%f in ("C:\Program Files\Autodesk\AdODIS\V1\Installer.exe") do (
        echo  Installer.exe size: %%~zf bytes >> "!DIAGFILE!"
    )
)
if not exist "C:\Program Files\Autodesk\AdODIS\V1\Installer.exe" (
    echo  Installer.exe: MISSING >> "!DIAGFILE!"
)
if exist "C:\ProgramData\Autodesk\ODIS\metadata" (
    echo  ODIS metadata dir: EXISTS >> "!DIAGFILE!"
    dir /b /ad "C:\ProgramData\Autodesk\ODIS\metadata" >> "!DIAGFILE!" 2>&1
)
if not exist "C:\ProgramData\Autodesk\ODIS\metadata" (
    echo  ODIS metadata dir: MISSING >> "!DIAGFILE!"
)
echo ------------------------------------------------ >> "!DIAGFILE!"
echo SERVICES: >> "!DIAGFILE!"
for %%s in (!SVC_NAMES!) do (
    sc query "%%s" >nul 2>&1
    if !errorlevel! equ 0 (
        echo  %%s: RUNNING >> "!DIAGFILE!"
    )
    if !errorlevel! neq 0 (
        echo  %%s: NOT FOUND >> "!DIAGFILE!"
    )
)
echo ------------------------------------------------ >> "!DIAGFILE!"
echo FOLDERS: >> "!DIAGFILE!"
for %%d in (
    "C:\Program Files\Autodesk"
    "C:\ProgramData\Autodesk"
    "C:\ProgramData\Autodesk\ODIS"
    "C:\Autodesk"
) do (
    if exist %%d (
        echo  %%~d: EXISTS >> "!DIAGFILE!"
    )
    if not exist %%d (
        echo  %%~d: MISSING >> "!DIAGFILE!"
    )
)
echo ------------------------------------------------ >> "!DIAGFILE!"

set PROD_COUNT=0

REM Detect Windows version for compatibility info
for /f "tokens=4-5 delims=. " %%i in ('ver') do set "WINVER=%%i.%%j"

:main_menu
cls
echo.
echo  !CCYN!============================================================!R!
echo  !CCYN!  !BOLD!!CWHT!  AUTODESK UNIVERSAL UNINSTALLER v5.12                    !R!
echo  !CCYN!  !DIM!  Supports all versions: 2015-2027+                       !R!
echo  !CCYN!  !DIM!  Compatible with Windows 10 and Windows 11               !R!
echo  !CCYN!============================================================!R!
REM === File Integrity Check ===
if not defined SCRIPT_HASH (
    for /f "skip=1 tokens=*" %%h in ('certutil -hashfile "%~f0" SHA256 2^>nul') do (
        if not defined SCRIPT_HASH set "SCRIPT_HASH=%%h"
    )
)
if defined SCRIPT_HASH (
    echo  !DIM!SHA-256: !SCRIPT_HASH!!R!
)
echo  !DIM!Started: %date% %time%!R!
echo.
echo   !CWHT![1]!R!  !CCYN!Scan!R! Installed Autodesk Software
echo   !CWHT![2]!R!  !CCYN!Uninstall!R! Selected Products
echo   !CRED![3]!R!  !CRED!Full Uninstall + Deep Clean!R! ALL Products
echo   !CYLW![4]!R!  !CYLW!Deep Clean Only!R! - remnants, no product uninstall
echo   !CGRN![5]!R!  !CGRN!Final Verification!R! - 17-point deep scan
echo   !CBLU![6]!R!  !CBLU!Create System Restore Point!R!
echo   !CMAG![7]!R!  !CMAG!Search!R! for ALL Autodesk remnants
echo   !CWHT![8]!R!  !CWHT!Full System Audit!R! - preview everything that will be removed
echo   !CYLW![9]!R!  !CYLW!Clean Desktop Connector Workspace!R! - local ACC sync data
echo.
echo   !CYLW![10]!R! !CYLW!Fix Error 103!R! - diagnose and repair ODIS installer issues
echo   !CYLW![11]!R! !CYLW!Fix Restart Pending!R! - clear pending reboot state
echo   !CWHT![12]!R! !CCYN!Backup Templates!R! - save custom templates and settings
echo.
echo   !DIM![0]!R!  Exit
echo.
echo  !DIM!Log: !LOGDIR!\uninstall_log.txt!R!
echo  !DIM!Diagnostics: !LOGDIR!\diagnostics.log!R!
echo  !DIM!Console log: !CLOG!!R!
echo.
set "MC="
set /p "MC=  !CWHT!Enter choice [0-12]:!R! "
echo [%date% %time%] Menu choice: !MC! >> "!CLOG!"
if "!MC!"=="1" goto :scan_products
if "!MC!"=="2" goto :uninstall_selected
if "!MC!"=="3" goto :full_clean
if "!MC!"=="4" goto :deep_clean
if "!MC!"=="5" goto :run_verify
if "!MC!"=="6" goto :create_restore
if "!MC!"=="7" goto :search_remnants
if "!MC!"=="8" goto :full_audit
if "!MC!"=="9" goto :dtc_workspace
if "!MC!"=="10" goto :fix_error103
if "!MC!"=="11" goto :fix_reboot_pending
if "!MC!"=="12" goto :backup_templates
if "!MC!"=="0" exit /b 0
echo.
echo  !CYLW!Invalid choice - please enter one of the numbers shown.!R!
timeout /t 2 /nobreak >nul
goto :main_menu

REM ============================================================
REM CREATE SYSTEM RESTORE POINT
REM ============================================================
:create_restore
cls
echo.
echo  ========================================================
echo   CREATE SYSTEM RESTORE POINT
echo  ========================================================
echo.
echo  This creates a Windows System Restore Point so you can
echo  roll back if anything goes wrong during uninstallation.
echo.
echo  NOTE: Windows limits restore points to one per 24 hours.
echo        This script will temporarily bypass that limit.
echo.
set /p "RP_CONF=  Create restore point now? [Y/N]: "
if /i not "!RP_CONF!"=="Y" goto :main_menu
echo. >> "!CLOG!"
echo ======================================================== >> "!CLOG!"
echo  CREATE SYSTEM RESTORE POINT >> "!CLOG!"
echo ======================================================== >> "!CLOG!"

echo.
REM Check if System Restore is enabled on C:
<nul set /p "=  Checking if System Restore is enabled..."
set "SR_DISABLED=0"
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v "DisableSR" >nul 2>&1
if !errorlevel! neq 0 goto :cr_enabled
for /f "tokens=3" %%v in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v "DisableSR" 2^>nul ^| findstr "DisableSR"') do (
    if "%%v"=="0x1" set "SR_DISABLED=1"
)
if !SR_DISABLED! equ 0 goto :cr_enabled

echo  DISABLED
echo.
echo  System Restore is disabled on this machine.
echo  To enable it: System Properties - System Protection -
echo  Configure - Turn on system protection.
echo.
set /p "SR_ENABLE=  Try to enable it now? [Y/N]: "
if /i not "!SR_ENABLE!"=="Y" (
    pause
    goto :main_menu
)
<nul set /p "=  Enabling System Restore on C:..."
powershell -Command "Enable-ComputerRestore -Drive 'C:\'" >nul 2>&1
if !errorlevel! equ 0 (
    echo  !CGRN!OK!R!
)
if !errorlevel! neq 0 (
    echo  FAILED - enable manually via System Properties.
    pause
    goto :main_menu
)

:cr_enabled
if !SR_DISABLED! equ 0 echo  !CGRN!OK!R!

REM Bypass 24-hour limit temporarily
<nul set /p "=  Bypassing 24-hour creation limit..."
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /t REG_DWORD /d 0 /f >nul 2>&1
echo  !CGRN!OK!R!

REM Create the restore point using wmic
echo  Creating restore point...
<nul set /p "=  Method 1: WMIC..."
set "WMIC_RP_OK=0"
for /f "tokens=*" %%w in ('wmic.exe /Namespace:\\root\default Path SystemRestore Call CreateRestorePoint "Pre-Autodesk Uninstall"^, 100^, 12 2^>nul') do (
    echo "%%w" | findstr /i "ReturnValue = 0" >nul 2>&1
    if !errorlevel! equ 0 set "WMIC_RP_OK=1"
)
if !WMIC_RP_OK! equ 1 goto :cr_wmic_ok

REM Fallback to PowerShell if WMIC fails
echo  failed.
<nul set /p "=  Method 2: PowerShell..."
powershell -ExecutionPolicy Bypass -Command "Checkpoint-Computer -Description 'Pre-Autodesk Uninstall' -RestorePointType 'MODIFY_SETTINGS'" >nul 2>&1
if !errorlevel! equ 0 goto :cr_ps_ok

echo  FAILED
echo.
echo  Could not create restore point. Possible causes:
echo  - System Restore is disabled
echo  - Not enough disk space
echo  - A restore point was created in the last 24 hours
echo  - Drive C: protection is off
echo.
echo  You can still continue with uninstallation.
echo.
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /f >nul 2>&1
pause
goto :main_menu

:cr_wmic_ok
echo  SUCCESS
echo  RESTORE POINT: Created >> "!LOGFILE!"
echo [!time:~0,8!] Restore point: created >> "!CLOG!"
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /f >nul 2>&1
echo.
echo  Restore point created successfully.
echo.
pause
goto :main_menu

:cr_ps_ok
echo  SUCCESS
echo  RESTORE POINT: Created via PowerShell >> "!LOGFILE!"
echo [!time:~0,8!] Restore point: created >> "!CLOG!"
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /f >nul 2>&1
echo.
echo  Restore point created successfully.
echo.
pause
goto :main_menu

REM ============================================================
REM SCAN
REM ============================================================
:scan_products
cls
echo.
echo  ========================================================
echo   !CCYN!!BOLD!SCANNING FOR INSTALLED AUTODESK PRODUCTS!R!
echo  ========================================================
echo.
echo === SCAN START %date% %time% === >> "!LOGFILE!"
echo. >> "!CLOG!"
echo ======================================================== >> "!CLOG!"
echo  SCANNING FOR INSTALLED AUTODESK PRODUCTS >> "!CLOG!"
echo ======================================================== >> "!CLOG!"
set PROD_COUNT=0

<nul set /p "=  !CWHT![1/5]!R! Scanning 64-bit registry"
set REG64_SCAN=0
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s /v "DisplayName" 2^>nul ^| findstr /i "HKEY_"') do (
    set "REGKEY=%%k"
    set "DN="
    set "US="
    set "PUB="
    set "VER="
    for /f "tokens=2,*" %%a in ('reg query "!REGKEY!" /v "DisplayName" 2^>nul ^| findstr /i "DisplayName"') do set "DN=%%b"
    for /f "tokens=2,*" %%a in ('reg query "!REGKEY!" /v "Publisher" 2^>nul ^| findstr /i "Publisher"') do set "PUB=%%b"
    set /a REG64_SCAN+=1
    set /a "DOT_CHECK=!REG64_SCAN! %% 20"
    if !DOT_CHECK! equ 0 <nul set /p "=."
    if defined PUB (
        echo "!PUB!" | findstr /i "Autodesk" >nul 2>&1
        if !errorlevel! equ 0 (
            if defined DN (
                for /f "tokens=2,*" %%a in ('reg query "!REGKEY!" /v "UninstallString" 2^>nul ^| findstr /i "UninstallString"') do set "US=%%b"
                for /f "tokens=2,*" %%a in ('reg query "!REGKEY!" /v "DisplayVersion" 2^>nul ^| findstr /i "DisplayVersion"') do set "VER=%%b"
                set /a PROD_COUNT+=1
                set "P_NAME_!PROD_COUNT!=!DN!"
                set "P_UNINST_!PROD_COUNT!=!US!"
                set "P_VER_!PROD_COUNT!=!VER!"
                set "P_KEY_!PROD_COUNT!=!REGKEY!"
                <nul set /p "=+"
            )
        )
    )
)
echo  !CGRN!done.!R! [!REG64_SCAN! keys, !PROD_COUNT! found]
echo [1/5] 64-bit registry: !REG64_SCAN! keys, !PROD_COUNT! found >> "!CLOG!"

<nul set /p "=  !CWHT![2/5]!R! Scanning 32-bit registry"
set REG32_SCAN=0
set BEFORE32=!PROD_COUNT!
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" /s /v "DisplayName" 2^>nul ^| findstr /i "HKEY_"') do (
    set "REGKEY=%%k"
    set "DN="
    set "US="
    set "PUB="
    set "VER="
    for /f "tokens=2,*" %%a in ('reg query "!REGKEY!" /v "DisplayName" 2^>nul ^| findstr /i "DisplayName"') do set "DN=%%b"
    for /f "tokens=2,*" %%a in ('reg query "!REGKEY!" /v "Publisher" 2^>nul ^| findstr /i "Publisher"') do set "PUB=%%b"
    set /a REG32_SCAN+=1
    set /a "DOT_CHECK=!REG32_SCAN! %% 20"
    if !DOT_CHECK! equ 0 <nul set /p "=."
    if defined PUB (
        echo "!PUB!" | findstr /i "Autodesk" >nul 2>&1
        if !errorlevel! equ 0 (
            if defined DN (
                set "DUPE=0"
                for /l %%i in (1,1,!PROD_COUNT!) do (
                    if "!P_NAME_%%i!"=="!DN!" set "DUPE=1"
                )
                if !DUPE! equ 0 (
                    for /f "tokens=2,*" %%a in ('reg query "!REGKEY!" /v "UninstallString" 2^>nul ^| findstr /i "UninstallString"') do set "US=%%b"
                    for /f "tokens=2,*" %%a in ('reg query "!REGKEY!" /v "DisplayVersion" 2^>nul ^| findstr /i "DisplayVersion"') do set "VER=%%b"
                    set /a PROD_COUNT+=1
                    set "P_NAME_!PROD_COUNT!=!DN!"
                    set "P_UNINST_!PROD_COUNT!=!US!"
                    set "P_VER_!PROD_COUNT!=!VER!"
                    set "P_KEY_!PROD_COUNT!=!REGKEY!"
                    <nul set /p "=+"
                )
            )
        )
    )
)
set /a NEW32=PROD_COUNT-BEFORE32
echo  !CGRN!done.!R! [!REG32_SCAN! keys, !NEW32! new]
echo [2/5] 32-bit registry: !REG32_SCAN! keys, !NEW32! new >> "!CLOG!"

<nul set /p "=  !CWHT![3/5]!R! Classifying products"
for /l %%i in (1,1,!PROD_COUNT!) do (
    set "UTYPE=MSI"
    set "PUNINST=!P_UNINST_%%i!"
    if defined PUNINST (
        echo "!PUNINST!" | findstr /i "Installer.exe" >nul 2>&1
        if !errorlevel! equ 0 set "UTYPE=ODIS"
        echo "!PUNINST!" | findstr /i "AdskUninstallHelper" >nul 2>&1
        if !errorlevel! equ 0 set "UTYPE=ODIS"
    )
    set "P_TYPE_%%i=!UTYPE!"
    REM Classify priority: 1=addon/plugin 2=material lib 3=main product
    set "P_PRIO_%%i=3"
    echo "!P_NAME_%%i!" | findstr /i /c:"Enabler" /c:"Plugin" /c:"Add-in" /c:"Addon" /c:"Content Pack" /c:"Language Pack" /c:"Service Pack" >nul 2>&1
    if !errorlevel! equ 0 set "P_PRIO_%%i=1"
    echo "!P_NAME_%%i!" | findstr /i /c:"Material Library" >nul 2>&1
    if !errorlevel! equ 0 set "P_PRIO_%%i=5"
    echo "!P_NAME_%%i!" | findstr /i /c:"Medium Resolution" >nul 2>&1
    if !errorlevel! equ 0 set "P_PRIO_%%i=4"
    echo "!P_NAME_%%i!" | findstr /i "Desktop App" >nul 2>&1
    if !errorlevel! equ 0 set "P_PRIO_%%i=6"
    echo "!P_NAME_%%i!" | findstr /i "Single Sign" >nul 2>&1
    if !errorlevel! equ 0 set "P_PRIO_%%i=7"
    echo "!P_NAME_%%i!" | findstr /i "Genuine" >nul 2>&1
    if !errorlevel! equ 0 set "P_PRIO_%%i=8"
    <nul set /p "=."
)
echo  !CGRN!done.!R!
echo [3/5] Products classified >> "!CLOG!"

<nul set /p "=  !CWHT![4/5]!R! Checking shared components"
set ODIS_BUNDLES=0
set UH_COUNT=0
if exist "C:\ProgramData\Autodesk\ODIS\metadata" (
    for /d %%b in ("C:\ProgramData\Autodesk\ODIS\metadata\*") do (
        if exist "%%b\bundleManifest.xml" set /a ODIS_BUNDLES+=1
    )
    if !ODIS_BUNDLES! gtr 0 <nul set /p "= ODIS:!ODIS_BUNDLES!"
)
if exist "C:\ProgramData\Autodesk\Uninstallers" (
    for /d %%h in ("C:\ProgramData\Autodesk\Uninstallers\*") do (
        if exist "%%h\AdskUninstallHelper.exe" set /a UH_COUNT+=1
    )
    if !UH_COUNT! gtr 0 <nul set /p "= Helpers:!UH_COUNT!"
)
echo  !CGRN!done.!R!

<nul set /p "=  !CWHT![5/5]!R! Checking legacy artifacts"
set LEG=0
if exist "C:\ProgramData\Autodesk\CLM" (
    set /a LEG+=1
    <nul set /p "= CLM"
)
if exist "C:\Program Files\Common Files\Macrovision Shared" (
    set /a LEG+=1
    <nul set /p "= Macrovision"
)
if exist "C:\ProgramData\FLEXnet" (
    dir /b "C:\ProgramData\FLEXnet\adsk*" >nul 2>&1
    if !errorlevel! equ 0 (
        set /a LEG+=1
        <nul set /p "= FLEXnet"
    )
)
echo  !CGRN!done.!R!

echo.
echo  ========================================================
echo   !CGRN!!BOLD!SCAN COMPLETE: !PROD_COUNT! Autodesk products found!R!
echo  ========================================================
echo.
echo [%date% %time%] Scan: !PROD_COUNT! products found >> "!CLOG!"
echo ======================================================== >> "!CLOG!"
echo  SCAN COMPLETE: !PROD_COUNT! products found >> "!CLOG!"
echo ======================================================== >> "!CLOG!"

if !PROD_COUNT! equ 0 (
    echo  !CYLW!No Autodesk products detected.!R!
    echo.
    pause
    goto :main_menu
)

echo  !CWHT!!BOLD!No.  Type   Prio Product Name                           Version!R!
echo  !DIM!---  -----  ---- ------------------------------------   ----------!R!
for /l %%i in (1,1,!PROD_COUNT!) do (
    set "DNAME=!P_NAME_%%i!                                      "
    set "DNAME=!DNAME:~0,38!"
    set "DVER=!P_VER_%%i!"
    if not defined DVER set "DVER=N/A"
    set "DPRIO=!P_PRIO_%%i!"
    REM Check if ODIS product has missing metadata XML
    set "ORPHAN_TAG="
    if "!P_TYPE_%%i!"=="ODIS" (
        for %%x in (!P_UNINST_%%i!) do (
            echo "%%x" | findstr /i "\.xml" >nul 2>&1
            if !errorlevel! equ 0 (
                if not exist "%%~x" set "ORPHAN_TAG= !CRED![ORPHAN]!R!"
            )
        )
    )
    echo  [%%i]  !P_TYPE_%%i!   [!DPRIO!]  !DNAME!  !DVER!!ORPHAN_TAG!
    echo  [%%i] !P_TYPE_%%i! [!DPRIO!] !P_NAME_%%i! !P_VER_%%i! >> "!CLOG!"
)
echo.
echo  Priority: [1]=addons first [3]=main products [4-5]=material
echo            libs [6]=desktop app [7]=SSO [8]=genuine svc last
echo  Type: MSI=Classic/Legacy, ODIS=New Installer 2020+
echo.
echo. >> "!CLOG!"
echo --- End of section --- >> "!CLOG!"
echo. >> "!CLOG!"
echo  SCAN: !PROD_COUNT! products >> "!LOGFILE!"
for /l %%i in (1,1,!PROD_COUNT!) do (
    echo   [%%i] P!P_PRIO_%%i! !P_TYPE_%%i! !P_NAME_%%i! >> "!LOGFILE!"
    echo   UNINST: !P_UNINST_%%i! >> "!LOGFILE!"
)
pause
goto :main_menu

REM ============================================================
REM UNINSTALL SELECTED
REM ============================================================
:uninstall_selected
cls
if !PROD_COUNT! equ 0 (
    echo.
    echo  No products scanned yet. Run option [1] first.
    echo.
    pause
    goto :main_menu
)
echo.
echo  ========================================================
echo   SELECT PRODUCTS TO UNINSTALL
echo  ========================================================
echo.
for /l %%i in (1,1,!PROD_COUNT!) do (
    echo  [%%i] !P_TYPE_%%i! - !P_NAME_%%i!
)
echo.
echo  Enter numbers separated by spaces, or 0 to go back.
echo.
set /p "SEL=  Selection: "
if "!SEL!"=="0" goto :main_menu

echo.
for %%n in (!SEL!) do (
    set "IDX=%%n"
    set "PNAME=!P_NAME_%%n!"
    set "PUNINST=!P_UNINST_%%n!"
    set "PTYPE=!P_TYPE_%%n!"
    if defined PNAME (
        echo  --------------------------------------------------------
        echo   [!PTYPE!] !PNAME!
        echo  --------------------------------------------------------
        set /p "CONF=  Proceed? [Y/N]: "
        set "_HANDLED=0"
        if /i not "!CONF!"=="Y" set "_HANDLED=1"

        if !_HANDLED! equ 0 if not defined PUNINST (
            echo  [ERROR] No UninstallString. Try Control Panel.
            set "_HANDLED=1"
        )

        if !_HANDLED! equ 0 if "!PTYPE!"=="ODIS" (
            echo  UNINSTALL: !PNAME! >> "!LOGFILE!"
            <nul set /p "=  [ODIS] Running uninstaller..."
            set "UCMD=!PUNINST!"
            echo "!UCMD!" | findstr /i "\-q" >nul 2>&1
            if !errorlevel! neq 0 set "UCMD=!UCMD! -q"
            set "ODIS_ARGS=!UCMD:*Installer.exe=!"
            "C:\Program Files\Autodesk\AdODIS\V1\Installer.exe"!ODIS_ARGS! >nul 2>&1
            set "UERR=!errorlevel!"
            if !UERR! equ 0 echo  !CGRN!OK!R!
            if !UERR! neq 0 echo  !CRED!FAIL exit:!UERR!!R!
            set "_HANDLED=1"
        )

        if !_HANDLED! equ 0 (
            echo  UNINSTALL: !PNAME! >> "!LOGFILE!"
            echo "!PUNINST!" | findstr /i "MsiExec" >nul 2>&1
            if !errorlevel! equ 0 (
                set "GUID="
                for /f "delims={} tokens=2" %%g in ("!PUNINST!") do set "GUID=%%g"
                if defined GUID (
                    <nul set /p "=  [MSI] msiexec /x..."
                    msiexec /x "{!GUID!}" /qn /norestart REMOVE=ALL REBOOT=ReallySuppress
                    set "UERR=!errorlevel!"
                    if !UERR! equ 0 echo  !CGRN!OK!R!
                    if !UERR! equ 1605 echo  !CGRN!OK !DIM!^(already removed^)!R!
                    if !UERR! equ 1641 echo  !CGRN!OK !DIM!^(reboot scheduled^)!R!
                    if !UERR! equ 3010 echo  !CGRN!OK !DIM!^(reboot suggested^)!R!
                    if !UERR! neq 0 if !UERR! neq 1605 if !UERR! neq 1641 if !UERR! neq 3010 (
                        echo  code:!UERR! retrying...
                        msiexec /x "{!GUID!}" /qb /norestart REMOVE=ALL REBOOT=ReallySuppress
                    )
                    set "_HANDLED=1"
                )
            )
        )

        if !_HANDLED! equ 0 (
            echo "!PUNINST!" | findstr /i "Setup.exe" >nul 2>&1
            if !errorlevel! equ 0 (
                <nul set /p "=  [LEGACY] Running Setup.exe..."
                start /wait "" cmd /c "!PUNINST!" /q >nul 2>&1
                echo  !CGRN!OK!R!
                set "_HANDLED=1"
            )
        )

        if !_HANDLED! equ 0 (
            <nul set /p "=  [GENERIC] Running..."
            start /wait "" cmd /c "!PUNINST!" --mode unattended >nul 2>&1
            echo  !CGRN!OK!R!
        )
        echo.
    )
)

echo  Done. Run [1] to rescan, or [4] for deep clean.
pause
goto :main_menu

REM ============================================================
REM FULL CLEAN: Uninstall all + deep clean
REM ============================================================
:full_clean
cls
if !PROD_COUNT! equ 0 (
    echo.
    echo  No products scanned yet. Run option [1] first.
    echo.
    pause
    goto :main_menu
)
echo.
echo  ========================================================
echo   !CRED!!BOLD!FULL UNINSTALL + DEEP CLEAN - ALL VERSIONS!R!
echo  ========================================================
echo.
echo  This performs a COMPLETE removal of all !PROD_COUNT!
echo  Autodesk products plus all traces from the system:
echo.
echo    Phase A: Create system restore point (optional)
echo    Phase B: Stop all services and kill processes
echo    Phase C: Uninstall products in dependency order
echo             1. Add-ins, plugins, enablers, packs
echo             2. Main applications
echo             3. Material Libraries (Med - Base - Core)
echo             4. Desktop App, SSO, shared utilities
echo    Phase D: Run shared component uninstallers
echo    Phase E: Delete ALL Autodesk folders
echo    Phase F: Clean FLEXnet, CLM, ADUT, ODIS cache
echo    Phase G: Remove orphan services, tasks, firewall
echo    Phase H: Registry cleanup with backup
echo    Phase I: Remove Genuine Service (last)
echo    Phase J: Final verification
echo.
echo  !CRED!!BOLD!WARNING: IRREVERSIBLE. Back up custom templates first.!R!
echo.
set /p "FC_CONF=  Type YES to proceed: "
if /i not "!FC_CONF!"=="YES" (
    echo  Aborted.
    pause
    goto :main_menu
)
echo.
<nul set /p "=  Preparing..."

REM Check for installer/download folders
set "CLEAN_INSTALLERS=0"
set "INSTALLER_FOUND=0"
for /f "tokens=*" %%p in ('dir /s /b /ad "C:\*Autodesk*" 2^>nul ^| findstr /i "\\Downloads\\"') do set "INSTALLER_FOUND=1"
if exist "%USERPROFILE%\Downloads\*Autodesk*" set "INSTALLER_FOUND=1"
if !INSTALLER_FOUND! equ 1 (
    echo.
    echo  !CYLW!============================================================!R!
    echo  !CYLW! Autodesk !CWHT!installer/download files!R!!CYLW! were found in your     !R!
    echo  !CYLW! Downloads folder. These are setup packages, not products.  !R!
    echo  !CYLW! They are !CWHT!NOT!R!!CYLW! removed by default.                          !R!
    echo  !CYLW!============================================================!R!
    echo      !CYLW!Tip: Most users choose N here - you will need these files!R!
    echo      !CYLW!if you plan to reinstall Autodesk products.!R!
    set /p "FC_INST=  Also remove installer files from Downloads? [Y/N]: "
    if /i "!FC_INST!"=="Y" set "CLEAN_INSTALLERS=1"
)

REM Check for Desktop Connector workspace (user project data - opt-in)
set "DTC_CLEAN_WS=0"
set "DTC_WS_FOUND=0"
if exist "%USERPROFILE%\DC\" set "DTC_WS_FOUND=1"
if exist "%USERPROFILE%\ACCDocs\" set "DTC_WS_FOUND=1"
if !DTC_WS_FOUND! equ 1 (
    echo.
    echo  !CYLW!============================================================!R!
    echo  !CYLW! A !CWHT!Desktop Connector workspace!R!!CYLW! was found on this machine.   !R!
    echo  !CYLW! It holds ACC / BIM 360 !CWHT!project files!R!!CYLW! synced to this PC.    !R!
    echo  !CYLW! It is !CWHT!NOT!R!!CYLW! removed by default.                              !R!
    echo  !CYLW!============================================================!R!
    echo      !CRED!WARNING: files not fully uploaded to the Autodesk cloud!R!
    echo      !CRED!will be PERMANENTLY LOST if you choose Y.!R!
    echo      !CYLW!Tip: Most users choose N here.!R!
    set "DTC_ANS="
    set /p "DTC_ANS=  Also delete Desktop Connector workspace folders? [Y/N]: "
    if /i "!DTC_ANS!"=="Y" set "DTC_CLEAN_WS=1"
)

echo.
set "FC_START=!time:~0,8!"
echo  === FULL CLEAN START === >> "!LOGFILE!"
echo. >> "!CLOG!"
echo ======================================================== >> "!CLOG!"
echo  FULL UNINSTALL + DEEP CLEAN >> "!CLOG!"
echo ======================================================== >> "!CLOG!"

REM --- Phase A: Restore point ---
echo  !DIM![!time:~0,8!]!R! !CCYN!!BOLD![A]!R! !CWHT!System Restore Point!R!
echo      !CCYN!Tip: A restore point is optional. The tool creates!R!
echo      !CCYN!registry backups automatically.!R!
set /p "RP_ASK=      Create restore point before proceeding? [Y/N]: "
if /i not "!RP_ASK!"=="Y" goto :fc_phase_b

<nul set /p "=      Creating restore point..."
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /t REG_DWORD /d 0 /f >nul 2>&1
set "WMIC_RP_OK=0"
for /f "tokens=*" %%w in ('wmic.exe /Namespace:\\root\default Path SystemRestore Call CreateRestorePoint "Pre-Autodesk Full Clean"^, 100^, 12 2^>nul') do (
    echo "%%w" | findstr /i "ReturnValue = 0" >nul 2>&1
    if !errorlevel! equ 0 set "WMIC_RP_OK=1"
)
if !WMIC_RP_OK! equ 1 (
    echo  !CGRN!OK!R!
    reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /f >nul 2>&1
    goto :fc_phase_b
)
<nul set /p "= WMIC failed, trying PowerShell..."
powershell -ExecutionPolicy Bypass -Command "Checkpoint-Computer -Description 'Pre-Autodesk Full Clean' -RestorePointType 'MODIFY_SETTINGS'" >nul 2>&1
if !errorlevel! equ 0 (
    echo  !CGRN!OK!R!
    reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /f >nul 2>&1
    goto :fc_phase_b
)
echo  FAILED - continuing anyway.
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /f >nul 2>&1

:fc_phase_b
echo.

REM --- Custom templates backup ---
echo.
echo  !CCYN!============================================================!R!
echo  !CCYN!  Autodesk stores custom templates, profiles, and settings!R!
echo  !CCYN!  in your AppData folder. These will be deleted during!R!
echo  !CCYN!  cleanup and cannot be recovered.!R!
echo  !CCYN!============================================================!R!
set "HAS_USERDATA=0"
if exist "%APPDATA%\Autodesk" set "HAS_USERDATA=1"
if exist "%LOCALAPPDATA%\Autodesk" set "HAS_USERDATA=1"
if exist "C:\Users\Public\Documents\Autodesk" set "HAS_USERDATA=1"
if !HAS_USERDATA! equ 1 (
    echo.
    echo  !CWHT!Custom data found in:!R!
    if exist "%APPDATA%\Autodesk" echo    !DIM!%APPDATA%\Autodesk!R!
    if exist "%LOCALAPPDATA%\Autodesk" echo    !DIM!%LOCALAPPDATA%\Autodesk!R!
    if exist "C:\Users\Public\Documents\Autodesk" echo    !DIM!C:\Users\Public\Documents\Autodesk!R!
    echo.
    <nul set /p "=  Back up custom templates and settings before cleanup? [Y/N]: "
    set /p "BACKUP_CHOICE="
)
if !HAS_USERDATA! equ 0 (
    echo.
    echo  !DIM!No custom Autodesk data found to back up.!R!
    set "BACKUP_CHOICE=N"
)

set "BK_DT="
for /f "tokens=2 delims==" %%d in ('wmic os get localdatetime /value 2^>nul') do set "BK_DT=%%d"
if not defined BK_DT (
    for /f "delims=" %%d in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMddHHmmss"') do set "BK_DT=%%d"
)
set "BK_DATESTAMP=!BK_DT:~0,8!"

if /i "!BACKUP_CHOICE!"=="Y" (
    set "BACKUP_DIR=!LOGDIR!\Autodesk_Backup_!BK_DATESTAMP!"
    mkdir "!BACKUP_DIR!" >nul 2>&1
    echo.
    <nul set /p "=  !DIM![!time:~0,8!]!R! Backing up Roaming\Autodesk..."
    if exist "%APPDATA%\Autodesk" (
        xcopy "%APPDATA%\Autodesk" "!BACKUP_DIR!\Roaming_Autodesk\" /e /h /q /y >nul 2>&1
        if !errorlevel! equ 0 echo  !CGRN!done.!R!
        if !errorlevel! neq 0 echo  !CYLW!partial - some files could not be copied.!R!
    )
    if not exist "%APPDATA%\Autodesk" echo  !DIM!not found.!R!
    <nul set /p "=  !DIM![!time:~0,8!]!R! Backing up Local\Autodesk..."
    if exist "%LOCALAPPDATA%\Autodesk" (
        xcopy "%LOCALAPPDATA%\Autodesk" "!BACKUP_DIR!\Local_Autodesk\" /e /h /q /y >nul 2>&1
        if !errorlevel! equ 0 echo  !CGRN!done.!R!
        if !errorlevel! neq 0 echo  !CYLW!partial - some files could not be copied.!R!
    )
    if not exist "%LOCALAPPDATA%\Autodesk" echo  !DIM!not found.!R!
    <nul set /p "=  !DIM![!time:~0,8!]!R! Backing up Public\Documents\Autodesk..."
    if exist "C:\Users\Public\Documents\Autodesk" (
        xcopy "C:\Users\Public\Documents\Autodesk" "!BACKUP_DIR!\Public_Autodesk\" /e /h /q /y >nul 2>&1
        if !errorlevel! equ 0 echo  !CGRN!done.!R!
        if !errorlevel! neq 0 echo  !CYLW!partial - some files could not be copied.!R!
    )
    if not exist "C:\Users\Public\Documents\Autodesk" echo  !DIM!not found.!R!
    echo.
    echo  !CGRN!Backup saved to:!R!
    echo  !CWHT!!BACKUP_DIR!!R!
    echo.
    echo  TEMPLATES BACKUP: !BACKUP_DIR! >> "!LOGFILE!"
)
if /i "!BACKUP_CHOICE!" neq "Y" (
    echo.
)

echo.
echo.
echo  !DIM![!time:~0,8!]!R! !CCYN!Progress: !CGRN!==!R!!DIM!==================!R! !CWHT!Phase B - 1 of 12!R!
REM --- Phase B: Stop everything ---
echo [!time:~0,8!] Phase B started >> "!CLOG!"
<nul set /p "=  !DIM![!time:~0,8!]!R! !CCYN!!BOLD![B]!R! Stopping services"
echo  PHASE B START %time% >> "!DIAGFILE!"
for %%s in (AdAppMgrSvc AdskAccessServiceHost AdskLicensingService AdskNLM DesktopConnectorService) do (
    sc query "%%s" >nul 2>&1
    if !errorlevel! equ 0 (
        net stop "%%s" >nul 2>&1
        sc config "%%s" start= disabled >nul 2>&1
        <nul set /p "=."
    )
)
net stop "FlexNet Licensing Service 64" >nul 2>&1
net stop "Autodesk Genuine Service" >nul 2>&1
echo  !CGRN!done.!R!
<nul set /p "=      !DIM!Killing processes!R!"
for %%p in (!KILL_PROCS!) do (
    taskkill /f /im "%%p" >nul 2>&1
    if !errorlevel! equ 0 <nul set /p "=."
)
REM Wildcard: kill ANY process running from Autodesk paths
wmic process where "ExecutablePath like '%%Autodesk%%'" call terminate >nul 2>&1
wmic process where "ExecutablePath like '%%AdODIS%%'" call terminate >nul 2>&1
powershell -NoProfile -Command "Get-Process | Where-Object { $_.Path -match 'Autodesk|AdODIS|Adsk' } | Stop-Process -Force -ErrorAction SilentlyContinue" >nul 2>&1
echo  !CGRN!done.!R!
echo [!time:~0,8!] Phase B: services stopped, processes killed >> "!CLOG!"
timeout /t 2 >nul
echo.

echo  !DIM![!time:~0,8!]!R! !CCYN!Progress: !CGRN!=====!R!!DIM!===============!R! !CWHT!Phase C - 3 of 12!R!
REM --- Phase C: Uninstall in dependency order (multi-pass) ---
echo [!time:~0,8!] Phase C started >> "!CLOG!"
echo  !DIM![!time:~0,8!]!R! !CCYN!!BOLD![C]!R! !CWHT!Uninstalling !PROD_COUNT! products in dependency order...!R!
echo  PHASE C START %time% >> "!DIAGFILE!"
echo      !DIM!Multi-pass: retries until all removed or stuck.!R!
echo.
set UNINST_OK=0
set UNINST_FAIL=0

REM --- Estimate uninstall time ---
set /a EST_MSI_COUNT=0
set /a EST_ODIS_COUNT=0
for /l %%i in (1,1,!PROD_COUNT!) do (
    if "!P_TYPE_%%i!"=="ODIS" set /a EST_ODIS_COUNT+=1
    if "!P_TYPE_%%i!"=="MSI" set /a EST_MSI_COUNT+=1
)
set /a EST_SECONDS=EST_ODIS_COUNT*75+EST_MSI_COUNT*5
set /a EST_MINUTES=EST_SECONDS/60
if !EST_MINUTES! lss 1 set "EST_MINUTES=1"
echo.
echo  !CCYN!Estimated time: ~!EST_MINUTES! minute^(s^) for !PROD_COUNT! products!R!
echo  !DIM!ODIS products: !EST_ODIS_COUNT! ^(~60-90 sec each^)  MSI products: !EST_MSI_COUNT! ^(~5 sec each^)!R!
echo [!time:~0,8!] Estimated: ~!EST_MINUTES! min for !PROD_COUNT! products >> "!CLOG!"
echo.

set /a UNINST_CURRENT=0

REM === PASS 1: Priority-ordered uninstall ===
echo      !CBLU!=== Pass 1 of 4: Dependency-ordered removal ===!R!
echo.
for %%P in (1 3 4 5 6 7 8) do (
    set "PASS_LABEL=Unknown"
    if %%P equ 1 set "PASS_LABEL=Add-ins, plugins, enablers"
    if %%P equ 3 set "PASS_LABEL=Main applications"
    if %%P equ 4 set "PASS_LABEL=Material Library - Medium Resolution"
    if %%P equ 5 set "PASS_LABEL=Material Library - Base and Core"
    if %%P equ 6 set "PASS_LABEL=Desktop App"
    if %%P equ 7 set "PASS_LABEL=Single Sign-On"
    if %%P equ 8 set "PASS_LABEL=Genuine Service"
    set PASS_HAS=0
    for /l %%i in (1,1,!PROD_COUNT!) do (
        if "!P_PRIO_%%i!"=="%%P" set PASS_HAS=1
    )
    if !PASS_HAS! equ 1 (
        echo      !CBLU!--- Priority %%P: !PASS_LABEL! ---!R!
        for /l %%i in (1,1,!PROD_COUNT!) do (
            if "!P_PRIO_%%i!"=="%%P" (
                set "PNAME=!P_NAME_%%i!"
                set "PUNINST=!P_UNINST_%%i!"
                set "PTYPE=!P_TYPE_%%i!"
                set "_HANDLED=0"
                set /a UNINST_CURRENT+=1
                if "!PTYPE!"=="ODIS" (
                    <nul set /p "=      !CWHT![!UNINST_CURRENT!/!PROD_COUNT!]!R! !CCYN!!PNAME:~0,45!!R! !DIM!^(ODIS - may take 1-2 min^)!R!"
                )
                if "!PTYPE!"=="MSI" (
                    <nul set /p "=      !CWHT![!UNINST_CURRENT!/!PROD_COUNT!]!R! !CCYN!!PNAME:~0,45!!R!"
                )
                if "!PTYPE!" neq "ODIS" if "!PTYPE!" neq "MSI" (
                    <nul set /p "=      !CWHT![!UNINST_CURRENT!/!PROD_COUNT!]!R! !CCYN!!PNAME:~0,45!!R!"
                )
                echo  [%%i] !PTYPE! !PNAME! >> "!LOGFILE!"

                if not defined PUNINST (
                    echo  !CYLW![SKIP:no uninstaller]!R!
                    echo   SKIP: no UninstallString >> "!LOGFILE!"
                    set /a UNINST_FAIL+=1
                    set "_HANDLED=1"
                )

                if !_HANDLED! equ 0 if "!PTYPE!"=="ODIS" (
                    set "UCMD=!PUNINST!"
                    echo "!UCMD!" | findstr /i "\-q" >nul 2>&1
                    if !errorlevel! neq 0 set "UCMD=!UCMD! -q"
                    echo   CMD: !UCMD! >> "!LOGFILE!"
                    REM ODIS pre-flight: check metadata XML referenced by -m flag
                    set "ODIS_META_OK=1"
                    set "ODIS_XML_PATH="
                    for /f "tokens=2 delims=-" %%t in ("!PUNINST:-m =_SPLIT_-m !") do (
                        set "_MTMP=%%t"
                    )
                    REM Extract XML path after -m flag
                    for %%x in (!PUNINST!) do (
                        echo "%%x" | findstr /i "\.xml" >nul 2>&1
                        if !errorlevel! equ 0 set "ODIS_XML_PATH=%%~x"
                    )
                    if defined ODIS_XML_PATH (
                        if not exist "!ODIS_XML_PATH!" (
                            set "ODIS_META_OK=0"
                            echo   DIAG: ODIS metadata MISSING: !ODIS_XML_PATH! >> "!DIAGFILE!"
                            echo   SKIP: metadata XML missing >> "!LOGFILE!"
                        )
                    )
                    if !ODIS_META_OK! equ 1 (
                        echo.
                        <nul set /p "=         !DIM!Uninstalling... please wait!R!"
                        set "ODIS_T1=!time:~0,8!"
                        del /f "!LOGDIR!\odis_out.tmp" >nul 2>&1
                        set "ODIS_ARGS=!UCMD:*Installer.exe=!"
                        del "!LOGDIR!\odis_done.tmp" >nul 2>&1
                        start "" /b cmd /c ""C:\Program Files\Autodesk\AdODIS\V1\Installer.exe"!ODIS_ARGS! >"!LOGDIR!\odis_out.tmp" 2>&1 && echo 0 > "!LOGDIR!\odis_done.tmp" || echo 1 > "!LOGDIR!\odis_done.tmp""
                        for /l %%t in (1,1,600) do (
                            if not exist "!LOGDIR!\odis_done.tmp" (
                                <nul set /p "=."
                                ping -n 2 127.0.0.1 >nul 2>&1
                            )
                        )
                        set "UERR=1"
                        if exist "!LOGDIR!\odis_done.tmp" (
                            set /p UERR=<"!LOGDIR!\odis_done.tmp"
                            set "UERR=!UERR: =!"
                        )
                        del "!LOGDIR!\odis_done.tmp" >nul 2>&1
                        echo [!time:~0,8!] [!UNINST_CURRENT!/!PROD_COUNT!] !PNAME! - EXIT:!UERR! >> "!CLOG!"
                        echo   EXIT: !UERR! >> "!LOGFILE!"
                        echo   DIAG: ODIS exit=!UERR! >> "!DIAGFILE!"
                        if !UERR! neq 0 (
                            echo   ODIS STDOUT+STDERR: >> "!DIAGFILE!"
                            type "!LOGDIR!\odis_out.tmp" >> "!DIAGFILE!" 2>nul
                            REM Copy ODIS own log files to diagnostics dir
                            if exist "C:\ProgramData\Autodesk\ODIS\Logs" (
                                echo   ODIS LOGS FOUND: >> "!DIAGFILE!"
                                dir /b /o-d "C:\ProgramData\Autodesk\ODIS\Logs\*.log" >> "!DIAGFILE!" 2>nul
                                xcopy "C:\ProgramData\Autodesk\ODIS\Logs\*.log" "!LOGDIR!\odis_logs\" /y /q >nul 2>&1
                            )
                        )
                        del /f "!LOGDIR!\odis_out.tmp" >nul 2>&1
                        if !UERR! equ 0 (
                            echo  !CGRN!OK!R!
                            echo          !DIM!completed at !time:~0,8!!R!
                            set /a UNINST_OK+=1
                        )
                        if !UERR! neq 0 (
                            echo  !CRED!FAIL exit:!UERR!!R!
                            echo          !DIM!completed at !time:~0,8!!R!
                            set /a UNINST_FAIL+=1
                        )
                    )
                    if !ODIS_META_OK! equ 0 (
                        echo  !CYLW![SKIP:metadata gone - will force-clean]!R!
                        set /a UNINST_FAIL+=1
                    )
                    set "_HANDLED=1"
                )

                if !_HANDLED! equ 0 (
                    echo "!PUNINST!" | findstr /i "MsiExec" >nul 2>&1
                    if !errorlevel! equ 0 (
                        set "GUID="
                        for /f "delims={} tokens=2" %%g in ("!PUNINST!") do set "GUID=%%g"
                        if defined GUID (
                            echo   CMD: msiexec /x {!GUID!} /qn /norestart REMOVE=ALL REBOOT=ReallySuppress >> "!LOGFILE!"
                            echo.
                            <nul set /p "=         !DIM!Uninstalling...!R!"
                            msiexec /x "{!GUID!}" /qn /norestart REMOVE=ALL REBOOT=ReallySuppress >nul 2>&1
                            set "UERR=!errorlevel!"
                            echo [!time:~0,8!] [!UNINST_CURRENT!/!PROD_COUNT!] !PNAME! - EXIT:!UERR! >> "!CLOG!"
                            echo   EXIT: !UERR! >> "!LOGFILE!"
                            if !UERR! equ 0 (
                                echo  !CGRN!OK!R!
                                set /a UNINST_OK+=1
                            )
                            if !UERR! equ 1605 (
                                echo  !CGRN!OK !DIM!^(already removed^)!R!
                                set /a UNINST_OK+=1
                            )
                            if !UERR! equ 1641 (
                                echo  !CGRN!OK !DIM!^(reboot scheduled^)!R!
                                set /a UNINST_OK+=1
                            )
                            if !UERR! equ 3010 (
                                echo  !CGRN!OK !DIM!^(reboot suggested^)!R!
                                set /a UNINST_OK+=1
                            )
                            if !UERR! neq 0 if !UERR! neq 1605 if !UERR! neq 1641 if !UERR! neq 3010 (
                                echo  !CRED!FAIL exit:!UERR!!R!
                                set /a UNINST_FAIL+=1
                            )
                        )
                        if not defined GUID (
                            echo  !CYLW![SKIP:no GUID]!R!
                            echo   SKIP: no GUID in UninstallString >> "!LOGFILE!"
                            set /a UNINST_FAIL+=1
                        )
                        set "_HANDLED=1"
                    )
                )

                if !_HANDLED! equ 0 (
                    echo "!PUNINST!" | findstr /i "Setup.exe" >nul 2>&1
                    if !errorlevel! equ 0 (
                        echo   CMD: LEGACY !PUNINST! /q >> "!LOGFILE!"
                        echo.
                        <nul set /p "=         !DIM!Uninstalling...!R!"
                        start /wait "" cmd /c "!PUNINST!" /q >nul 2>&1
                        set "UERR=!errorlevel!"
                        echo [!time:~0,8!] [!UNINST_CURRENT!/!PROD_COUNT!] !PNAME! - EXIT:!UERR! >> "!CLOG!"
                        echo   EXIT: !UERR! >> "!LOGFILE!"
                        echo  !CGRN!OK!R!
                        set /a UNINST_OK+=1
                        set "_HANDLED=1"
                    )
                )

                if !_HANDLED! equ 0 (
                    echo   CMD: GENERIC !PUNINST! --mode unattended >> "!LOGFILE!"
                    echo.
                    <nul set /p "=         !DIM!Uninstalling...!R!"
                    start /wait "" cmd /c "!PUNINST!" --mode unattended >nul 2>&1
                    set "UERR=!errorlevel!"
                    echo [!time:~0,8!] [!UNINST_CURRENT!/!PROD_COUNT!] !PNAME! - EXIT:!UERR! >> "!CLOG!"
                    echo   EXIT: !UERR! >> "!LOGFILE!"
                    if !UERR! equ 0 (
                        echo  !CGRN!OK!R!
                        set /a UNINST_OK+=1
                    )
                    if !UERR! equ 1605 (
                        echo  !CGRN!OK !DIM!^(already removed^)!R!
                        set /a UNINST_OK+=1
                    )
                    if !UERR! equ 1641 (
                        echo  !CGRN!OK !DIM!^(reboot scheduled^)!R!
                        set /a UNINST_OK+=1
                    )
                    if !UERR! equ 3010 (
                        echo  !CGRN!OK !DIM!^(reboot suggested^)!R!
                        set /a UNINST_OK+=1
                    )
                    if !UERR! neq 0 if !UERR! neq 1605 if !UERR! neq 1641 if !UERR! neq 3010 (
                        echo  !CRED!FAIL exit:!UERR!!R!
                        set /a UNINST_FAIL+=1
                    )
                )
            )
        )
    )
)
echo.
echo      !DIM!Pass 1 result:!R! !CGRN!!UNINST_OK! uninstalled!R!, !CRED!!UNINST_FAIL! failed!R!.
if !UNINST_FAIL! gtr 0 (
    echo      !DIM!Some failures are normal - components already removed by parent!R!
    echo      !DIM!uninstallers. The tool will retry remaining products automatically.!R!
)
echo  PHASE C PASS 1: !UNINST_OK! ok !UNINST_FAIL! fail >> "!LOGFILE!"

REM === MULTI-PASS RETRY: Rescan and retry up to 3 more times ===
set RETRY_NUM=1
set RETRY_MAX=3
set PREV_REMAIN=999999

:fc_retry_check
REM Quick-count remaining Autodesk products in registry
set REMAIN=0
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s /v "Publisher" 2^>nul ^| findstr /i "Autodesk"') do set /a REMAIN+=1
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" /s /v "Publisher" 2^>nul ^| findstr /i "Autodesk"') do set /a REMAIN+=1

REM Check if done
if !REMAIN! equ 0 (
    echo.
    echo      All Autodesk products removed after pass 1 + !RETRY_NUM! retries.
    goto :fc_multipass_done
)

REM Check if retries exhausted
if !RETRY_NUM! gtr !RETRY_MAX! (
    echo.
    echo      Max retries reached. !REMAIN! products still registered.
    echo      These may need a reboot or manual removal.
    goto :fc_multipass_done
)

REM Check if stuck (no progress since last pass)
if !REMAIN! geq !PREV_REMAIN! (
    if !RETRY_NUM! gtr 1 (
        echo.
        echo      No progress since last retry. !REMAIN! products stuck.
        echo      Reboot and run again, or use Deep Clean.
        goto :fc_multipass_done
    )
)
set PREV_REMAIN=!REMAIN!

echo.
echo      !REMAIN! products still registered. Waiting 5 seconds...
timeout /t 5 >nul
set /a PASS_NUM=RETRY_NUM+1
echo.
echo  !CYLW!Some products need a second attempt - this is normal.!R!
echo  !DIM!Retrying !REMAIN! product^(s^)...!R!
echo.
echo      === Pass !PASS_NUM! of 4: Retry uninstall ===
echo  PHASE C PASS !PASS_NUM!: !REMAIN! remaining >> "!LOGFILE!"

REM Rescan and attempt each remaining product
set RETRY_OK=0
set RETRY_IDX=0
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s /v "DisplayName" 2^>nul ^| findstr /i "HKEY_"') do (
    set "R_KEY=%%k"
    set "R_DN="
    set "R_US="
    set "R_PUB="
    for /f "tokens=2,*" %%a in ('reg query "!R_KEY!" /v "DisplayName" 2^>nul ^| findstr /i "DisplayName"') do set "R_DN=%%b"
    for /f "tokens=2,*" %%a in ('reg query "!R_KEY!" /v "Publisher" 2^>nul ^| findstr /i "Publisher"') do set "R_PUB=%%b"
    if defined R_PUB (
        echo "!R_PUB!" | findstr /i "Autodesk" >nul 2>&1
        if !errorlevel! equ 0 (
            if defined R_DN (
                for /f "tokens=2,*" %%a in ('reg query "!R_KEY!" /v "UninstallString" 2^>nul ^| findstr /i "UninstallString"') do set "R_US=%%b"
                set /a RETRY_IDX+=1
                <nul set /p "=      [!RETRY_IDX!] !R_DN:~0,45!"
                echo   RETRY [!RETRY_IDX!] !R_DN! >> "!LOGFILE!"
                echo   UNINST: !R_US! >> "!LOGFILE!"
                if defined R_US (
                    echo "!R_US!" | findstr /i "Installer.exe AdskUninstallHelper" >nul 2>&1
                    if !errorlevel! equ 0 (
                        REM Check if ODIS metadata XML exists before trying
                        set "R_XML_OK=1"
                        for %%x in (!R_US!) do (
                            echo "%%x" | findstr /i "\.xml" >nul 2>&1
                            if !errorlevel! equ 0 (
                                if not exist "%%~x" set "R_XML_OK=0"
                            )
                        )
                        if !R_XML_OK! equ 1 (
                            set "R_CMD=!R_US!"
                            echo "!R_CMD!" | findstr /i "\-q" >nul 2>&1
                            if !errorlevel! neq 0 set "R_CMD=!R_CMD! -q"
                            <nul set /p "=..."
                            del /f "!LOGDIR!\odis_out.tmp" >nul 2>&1
                            set "ODIS_ARGS=!R_CMD:*Installer.exe=!"
                            "C:\Program Files\Autodesk\AdODIS\V1\Installer.exe"!ODIS_ARGS! >"!LOGDIR!\odis_out.tmp" 2>&1
                            set "RERR=!errorlevel!"
                            if !RERR! equ 0 (
                                echo  !CGRN!OK!R!
                                set /a RETRY_OK+=1
                            )
                            if !RERR! neq 0 (
                                echo  !CRED!FAIL exit:!RERR!!R!
                                echo   RETRY ODIS OUTPUT: >> "!DIAGFILE!"
                                type "!LOGDIR!\odis_out.tmp" >> "!DIAGFILE!" 2>nul
                            )
                            del /f "!LOGDIR!\odis_out.tmp" >nul 2>&1
                        )
                        if !R_XML_OK! equ 0 (
                            echo  !CYLW![SKIP:metadata gone]!R!
                        )
                    )
                    echo "!R_US!" | findstr /i "Installer.exe AdskUninstallHelper" >nul 2>&1
                    if !errorlevel! neq 0 (
                        echo "!R_US!" | findstr /i "MsiExec" >nul 2>&1
                        if !errorlevel! equ 0 (
                            set "R_GUID="
                            for /f "delims={} tokens=2" %%g in ("!R_US!") do set "R_GUID=%%g"
                            if defined R_GUID (
                                <nul set /p "=..."
                                msiexec /x "{!R_GUID!}" /qn /norestart REMOVE=ALL REBOOT=ReallySuppress >nul 2>&1
                                set "RERR2=!errorlevel!"
                                if !RERR2! equ 0 (
                                    echo  !CGRN!OK!R!
                                    set /a RETRY_OK+=1
                                )
                                if !RERR2! equ 1605 (
                                    echo  !CGRN!OK !DIM!^(already removed^)!R!
                                    set /a RETRY_OK+=1
                                )
                                if !RERR2! equ 1641 (
                                    echo  !CGRN!OK !DIM!^(reboot scheduled^)!R!
                                    set /a RETRY_OK+=1
                                )
                                if !RERR2! equ 3010 (
                                    echo  !CGRN!OK !DIM!^(reboot suggested^)!R!
                                    set /a RETRY_OK+=1
                                )
                                if !RERR2! neq 0 if !RERR2! neq 1605 if !RERR2! neq 1641 if !RERR2! neq 3010 (
                                    echo  !CRED!FAIL exit:!RERR2!!R!
                                )
                            )
                            if not defined R_GUID echo  [no GUID]
                        )
                        echo "!R_US!" | findstr /i "MsiExec" >nul 2>&1
                        if !errorlevel! neq 0 (
                            <nul set /p "=..."
                            start /wait "" cmd /c "!R_US!" --mode unattended >nul 2>&1
                            echo  !CGRN!OK!R!
                            set /a RETRY_OK+=1
                        )
                    )
                )
                if not defined R_US echo  [no uninstaller]
            )
        )
    )
)
REM Also check WOW6432Node for 32-bit leftovers
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" /s /v "DisplayName" 2^>nul ^| findstr /i "HKEY_"') do (
    set "R_KEY=%%k"
    set "R_DN="
    set "R_US="
    set "R_PUB="
    for /f "tokens=2,*" %%a in ('reg query "!R_KEY!" /v "DisplayName" 2^>nul ^| findstr /i "DisplayName"') do set "R_DN=%%b"
    for /f "tokens=2,*" %%a in ('reg query "!R_KEY!" /v "Publisher" 2^>nul ^| findstr /i "Publisher"') do set "R_PUB=%%b"
    if defined R_PUB (
        echo "!R_PUB!" | findstr /i "Autodesk" >nul 2>&1
        if !errorlevel! equ 0 (
            if defined R_DN (
                for /f "tokens=2,*" %%a in ('reg query "!R_KEY!" /v "UninstallString" 2^>nul ^| findstr /i "UninstallString"') do set "R_US=%%b"
                set /a RETRY_IDX+=1
                <nul set /p "=      [!RETRY_IDX!] !R_DN:~0,45!"
                echo   RETRY-32 [!RETRY_IDX!] !R_DN! >> "!LOGFILE!"
                if defined R_US (
                    echo "!R_US!" | findstr /i "MsiExec" >nul 2>&1
                    if !errorlevel! equ 0 (
                        set "R_GUID="
                        for /f "delims={} tokens=2" %%g in ("!R_US!") do set "R_GUID=%%g"
                        if defined R_GUID (
                            <nul set /p "=..."
                            msiexec /x "{!R_GUID!}" /qn /norestart REMOVE=ALL REBOOT=ReallySuppress >nul 2>&1
                            set "RERR3=!errorlevel!"
                            if !RERR3! equ 0 (
                                echo  !CGRN!OK!R!
                                set /a RETRY_OK+=1
                            )
                            if !RERR3! equ 1605 (
                                echo  !CGRN!OK !DIM!^(already removed^)!R!
                                set /a RETRY_OK+=1
                            )
                            if !RERR3! equ 1641 (
                                echo  !CGRN!OK !DIM!^(reboot scheduled^)!R!
                                set /a RETRY_OK+=1
                            )
                            if !RERR3! equ 3010 (
                                echo  !CGRN!OK !DIM!^(reboot suggested^)!R!
                                set /a RETRY_OK+=1
                            )
                            if !RERR3! neq 0 if !RERR3! neq 1605 if !RERR3! neq 1641 if !RERR3! neq 3010 (
                                echo  !CRED!FAIL exit:!RERR3!!R!
                            )
                        )
                    )
                    echo "!R_US!" | findstr /i "MsiExec" >nul 2>&1
                    if !errorlevel! neq 0 (
                        <nul set /p "=..."
                        start /wait "" cmd /c "!R_US!" --mode unattended >nul 2>&1
                        echo  !CGRN!OK!R!
                        set /a RETRY_OK+=1
                    )
                )
                if not defined R_US echo  [no uninstaller]
            )
        )
    )
)
echo      Retry pass: !RETRY_OK! removed this round.
set /a UNINST_OK+=RETRY_OK
set /a RETRY_NUM+=1
goto :fc_retry_check

:fc_multipass_done
echo.
echo      !CWHT!TOTAL: !CGRN!!UNINST_OK! uninstalled!R! across all passes.
echo  PHASE C TOTAL: !UNINST_OK! ok >> "!LOGFILE!"
echo.

REM --- Phase C2: Force-remove stuck registry entries ---
REM Note: completion summary is printed after C2 below
REM In Full Clean mode, the user confirmed total removal.
REM Any Autodesk product still registered after all passes must be force-cleaned.
set FORCE_DEL=0
echo  PHASE C2: Force-cleaning stuck entries >> "!LOGFILE!"
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s /v "DisplayName" 2^>nul ^| findstr /i "HKEY_"') do (
    set "O_KEY=%%k"
    set "O_DN="
    set "O_PUB="
    for /f "tokens=2,*" %%a in ('reg query "!O_KEY!" /v "DisplayName" 2^>nul ^| findstr /i "DisplayName"') do set "O_DN=%%b"
    for /f "tokens=2,*" %%a in ('reg query "!O_KEY!" /v "Publisher" 2^>nul ^| findstr /i "Publisher"') do set "O_PUB=%%b"
    if defined O_PUB (
        echo "!O_PUB!" | findstr /i "Autodesk" >nul 2>&1
        if !errorlevel! equ 0 (
            if defined O_DN (
                <nul set /p "=      !CYLW![FORCE]!R! !O_DN:~0,40!..."
                echo  FORCE-DEL: !O_DN! >> "!LOGFILE!"
                echo  KEY: !O_KEY! >> "!LOGFILE!"
                reg delete "!O_KEY!" /f >nul 2>&1
                if !errorlevel! equ 0 (
                    echo  !CGRN!reg deleted.!R!
                    set /a FORCE_DEL+=1
                )
                if !errorlevel! neq 0 echo  !CRED!FAILED.!R!
            )
        )
    )
)
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" /s /v "DisplayName" 2^>nul ^| findstr /i "HKEY_"') do (
    set "O_KEY=%%k"
    set "O_DN="
    set "O_PUB="
    for /f "tokens=2,*" %%a in ('reg query "!O_KEY!" /v "DisplayName" 2^>nul ^| findstr /i "DisplayName"') do set "O_DN=%%b"
    for /f "tokens=2,*" %%a in ('reg query "!O_KEY!" /v "Publisher" 2^>nul ^| findstr /i "Publisher"') do set "O_PUB=%%b"
    if defined O_PUB (
        echo "!O_PUB!" | findstr /i "Autodesk" >nul 2>&1
        if !errorlevel! equ 0 (
            if defined O_DN (
                <nul set /p "=      !CYLW![FORCE]!R! !O_DN:~0,40!..."
                echo  FORCE-DEL: !O_DN! >> "!LOGFILE!"
                reg delete "!O_KEY!" /f >nul 2>&1
                if !errorlevel! equ 0 (
                    echo  !CGRN!reg deleted.!R!
                    set /a FORCE_DEL+=1
                )
                if !errorlevel! neq 0 echo  !CRED!FAILED.!R!
            )
        )
    )
)
if !FORCE_DEL! gtr 0 (
    echo      !CYLW!Force-removed !FORCE_DEL! stuck registry entries.!R!
    echo  PHASE C2: !FORCE_DEL! force-removed >> "!LOGFILE!"
)
echo.
echo  !CGRN!!BOLD!Product removal complete:!R! !CWHT!!UNINST_OK! succeeded!R!, !FORCE_DEL! force-cleaned
echo [!time:~0,8!] Phase C complete: !UNINST_OK! ok, !UNINST_FAIL! fail >> "!CLOG!"
echo  !DIM!Phase C completed at !time:~0,8!!R!
echo.

echo.
echo  !DIM![!time:~0,8!]!R! !CCYN!Progress: !CGRN!========!R!!DIM!============!R! !CWHT!Phase D - 5 of 12!R!
REM --- Phase D: Shared components ---
echo [!time:~0,8!] Phase D started >> "!CLOG!"
echo  !DIM![!time:~0,8!]!R! !CCYN!!BOLD![D]!R! !CWHT!Removing shared components...!R!
if exist "C:\Program Files (x86)\Autodesk\Autodesk Desktop App\removeAdAppMgr.exe" (
    <nul set /p "=      Desktop App... !DIM!^(please wait^)!R!"
    rd /s /q "%ProgramData%\Autodesk\SDS" 2>nul
    start /wait "" "C:\Program Files (x86)\Autodesk\Autodesk Desktop App\removeAdAppMgr.exe" --mode unattended
    timeout /t 3 >nul
    echo  !CGRN!OK!R!
)
if exist "C:\Program Files\Autodesk\AdskIdentityManager\uninstall.exe" (
    <nul set /p "=      Identity Manager... !DIM!^(please wait^)!R!"
    start /wait "" "C:\Program Files\Autodesk\AdskIdentityManager\uninstall.exe" --mode unattended
    timeout /t 3 >nul
    echo  !CGRN!OK!R!
)
if exist "C:\Program Files\Autodesk\AdODIS\V1\RemoveODIS.exe" (
    del /f "C:\ProgramData\Autodesk\ODIS\AdODISInstaller.run.lock" >nul 2>&1
    <nul set /p "=      RemoveODIS... !DIM!^(please wait^)!R!"
    start /wait "" "C:\Program Files\Autodesk\AdODIS\V1\RemoveODIS.exe" --mode unattended
    timeout /t 3 >nul
    echo  !CGRN!OK!R!
)
if exist "C:\Program Files (x86)\Common Files\Autodesk Shared\AdskLicensing\uninstall.exe" (
    <nul set /p "=      AdskLicensing... !DIM!^(please wait^)!R!"
    start /wait "" "C:\Program Files (x86)\Common Files\Autodesk Shared\AdskLicensing\uninstall.exe" --mode unattended
    timeout /t 3 >nul
    echo  !CGRN!OK!R!
)
if not exist "C:\Program Files (x86)\Common Files\Autodesk Shared\AdskLicensing\uninstall.exe" (
    sc query "AdskLicensingService" >nul 2>&1
    if !errorlevel! equ 0 (
        sc delete AdskLicensingService >nul 2>&1
        echo      AdskLicensing via sc delete... OK
    )
)
if exist "C:\ProgramData\Autodesk\Uninstallers" (
    <nul set /p "=      AdskUninstallHelpers"
    for /d %%h in ("C:\ProgramData\Autodesk\Uninstallers\*") do (
        if exist "%%h\AdskUninstallHelper.exe" (
            REM Run silently with -q. Without it the helper opens an interactive
            REM GUI wizard and blocks forever. The 5-min per-helper timeout is a
            REM safety net for an ODIS/BITS deadlock so one helper cannot hang
            REM the whole script.
            powershell -NoProfile -Command "try { $p = Start-Process -FilePath '%%h\AdskUninstallHelper.exe' -ArgumentList '-q' -WindowStyle Hidden -PassThru; if (-not $p.WaitForExit(300000)) { $p.Kill() } } catch {}" >nul 2>&1
            <nul set /p "=."
        )
    )
    echo  !CGRN!done.!R!
)
del /f "C:\ProgramData\Autodesk\Adlm\ProductInformation.pit" >nul 2>&1
del /f "%LOCALAPPDATA%\Autodesk\Genuine Autodesk Service\id.dat" >nul 2>&1
echo      Phase D complete.
echo  PHASE D END %time% >> "!DIAGFILE!"
echo [!time:~0,8!] Phase D complete >> "!CLOG!"
echo.

echo.
echo  !DIM![!time:~0,8!]!R! !CCYN!Progress: !CGRN!==========!R!!DIM!==========!R! !CWHT!Phase E - 6 of 12!R!
REM --- Phase E: Delete folders ---
echo [!time:~0,8!] Phase E started >> "!CLOG!"
REM Kill any processes that Phase C/D may have spawned
<nul set /p "=  !DIM![!time:~0,8!]!R! !CCYN!!BOLD![E]!R! Killing residual processes"
for %%p in (!KILL_PROCS!) do (
    taskkill /f /im "%%p" >nul 2>&1
    if !errorlevel! equ 0 <nul set /p "=."
)
wmic process where "ExecutablePath like '%%Autodesk%%'" call terminate >nul 2>&1
wmic process where "ExecutablePath like '%%AdODIS%%'" call terminate >nul 2>&1
powershell -NoProfile -Command "Get-Process | Where-Object { $_.Path -match 'Autodesk|AdODIS|Adsk' } | Stop-Process -Force -ErrorAction SilentlyContinue" >nul 2>&1
REM Stop Windows Search to release index handles on Autodesk folders
net stop msiserver >nul 2>&1
net stop WSearch >nul 2>&1
REM Unregister shell extensions that explorer.exe holds loaded
set "EXPLORER_KILLED=0"
for %%x in (
    "C:\Program Files\Common Files\Autodesk Shared\AcShellEx\AcShellExtension.dll"
    "C:\Program Files (x86)\Common Files\Autodesk Shared\AcShellEx\AcShellExtension.dll"
    "C:\Program Files\Common Files\Autodesk Shared\DwfShellEx\DwfShellExtension.dll"
    "C:\Program Files (x86)\Common Files\Autodesk Shared\DwfShellEx\DwfShellExtension.dll"
) do (
    if exist %%x (
        regsvr32 /u /s %%x >nul 2>&1
        <nul set /p "=."
        set "EXPLORER_KILLED=1"
    )
)
if !EXPLORER_KILLED! equ 1 (
    <nul set /p "= restarting explorer"
    taskkill /f /im explorer.exe >nul 2>&1
    timeout /t 2 >nul
    start "" explorer.exe
    timeout /t 2 >nul
)
echo  !CGRN!done.!R!
timeout /t 3 >nul
echo  !DIM![!time:~0,8!]!R! !CCYN!!BOLD![E]!R! !CWHT!Deleting Autodesk folders...!R!
echo  !DIM!Removing folders - large installations may take a moment...!R!
echo  PHASE E START %time% >> "!DIAGFILE!"
set DOK=0
set DFL=0
set "LOCKED_LIST="
for %%d in (
    "C:\Program Files\Autodesk"
    "C:\Program Files\Common Files\Autodesk Shared"
    "C:\Program Files\Common Files\Autodesk"
    "C:\Program Files (x86)\Autodesk"
    "C:\Program Files (x86)\Common Files\Autodesk Shared"
    "C:\Program Files (x86)\Common Files\Autodesk"
    "C:\ProgramData\Autodesk"
    "C:\Users\Public\Documents\Autodesk"
    "C:\Users\Public\Autodesk"
    "C:\Autodesk"
    "C:\Program Files\Common Files\Macrovision Shared"
) do (
    if exist %%d (
        <nul set /p "=      %%~d..."
        rd /s /q %%d 2>nul
        if exist %%d (
            REM Try takeown + icacls then retry
            takeown /f %%d /r /d y >nul 2>&1
            icacls %%d /grant *S-1-1-0:F /t /c /q >nul 2>&1
            rd /s /q %%d 2>nul
        )
        if not exist %%d (
            echo  !CGRN!deleted.!R!
            set /a DOK+=1
        )
        if exist %%d (
            echo  !CRED!LOCKED.!R!
            set /a DFL+=1
            set "LOCKED_LIST=!LOCKED_LIST! "%%~d""
            echo   LOCKED: %%~d >> "!DIAGFILE!"
        )
    )
)
for %%d in ("%APPDATA%\Autodesk" "%LOCALAPPDATA%\Autodesk" "%LOCALAPPDATA%\Programs\Autodesk") do (
    if exist "%%~d" (
        <nul set /p "=      %%~d..."
        rd /s /q "%%~d" 2>nul
        if exist "%%~d" (
            takeown /f "%%~d" /r /d y >nul 2>&1
            icacls "%%~d" /grant *S-1-1-0:F /t /c /q >nul 2>&1
            rd /s /q "%%~d" 2>nul
        )
        if not exist "%%~d" (
            echo  !CGRN!deleted.!R!
            set /a DOK+=1
        )
        if exist "%%~d" (
            echo  !CRED!LOCKED.!R!
            set /a DFL+=1
            set "LOCKED_LIST=!LOCKED_LIST! "%%~d""
            echo   LOCKED: %%~d >> "!DIAGFILE!"
        )
    )
)
if exist "%LOCALAPPDATA%\com.autodesk.cer-dialog" (
    <nul set /p "=      com.autodesk.cer-dialog..."
    rd /s /q "%LOCALAPPDATA%\com.autodesk.cer-dialog" 2>nul
    if not exist "%LOCALAPPDATA%\com.autodesk.cer-dialog" (
        echo  !CGRN!deleted.!R!
        set /a DOK+=1
    )
    if exist "%LOCALAPPDATA%\com.autodesk.cer-dialog" (
        echo  !CRED!LOCKED.!R!
        set /a DFL+=1
    )
)
REM Clean .NET NativeImages for Autodesk assemblies
for /d %%d in ("C:\Windows\assembly\NativeImages_v4.0.30319_64\Autodesk*") do (
    if exist "%%d" (
        <nul set /p "=      NativeImage: %%~nxd..."
        rd /s /q "%%d" 2>nul
        if not exist "%%d" (
            echo  !CGRN!deleted.!R!
            set /a DOK+=1
        )
        if exist "%%d" (
            echo  !CRED!LOCKED.!R!
            set /a DFL+=1
        )
    )
)
for /d %%d in ("C:\Windows\assembly\NativeImages_v4.0.30319_32\Autodesk*") do (
    if exist "%%d" (
        <nul set /p "=      NativeImage: %%~nxd..."
        rd /s /q "%%d" 2>nul
        if not exist "%%d" (
            echo  !CGRN!deleted.!R!
            set /a DOK+=1
        )
        if exist "%%d" (
            echo  !CRED!LOCKED.!R!
            set /a DFL+=1
        )
    )
)
REM SYSTEM profile and other user profiles
if exist "C:\Windows\System32\config\systemprofile\AppData\Local\Autodesk" (
    <nul set /p "=      SYSTEM profile Autodesk..."
    rd /s /q "C:\Windows\System32\config\systemprofile\AppData\Local\Autodesk" 2>nul
    if not exist "C:\Windows\System32\config\systemprofile\AppData\Local\Autodesk" (
        echo  !CGRN!deleted.!R!
        set /a DOK+=1
    )
    if exist "C:\Windows\System32\config\systemprofile\AppData\Local\Autodesk" (
        echo  !CRED!LOCKED.!R!
        set /a DFL+=1
    )
)
echo      !DOK! deleted, !DFL! locked.
echo.

REM --- Optional: Installer/Download files cleanup ---
if !CLEAN_INSTALLERS! equ 1 (
    echo  !DIM![!time:~0,8!]!R! !CYLW!!BOLD![OPT]!R! !CWHT!Removing installer/download files...!R!
    set INST_DEL=0
    for /d %%d in ("%USERPROFILE%\Downloads\*Autodesk*" "%USERPROFILE%\Downloads\*AutoCAD*" "%USERPROFILE%\Downloads\*Revit*" "%USERPROFILE%\Downloads\*Inventor*" "%USERPROFILE%\Downloads\*Maya*" "%USERPROFILE%\Downloads\*3dsMax*") do (
        if exist "%%d" (
            <nul set /p "=      %%~nxd..."
            rd /s /q "%%d" 2>nul
            if not exist "%%d" (
                echo  !CGRN!deleted.!R!
                set /a INST_DEL+=1
            )
            if exist "%%d" echo  !CRED!LOCKED.!R!
        )
    )
    REM Clean browser cache for autodesk.com
    for /d %%d in ("%LOCALAPPDATA%\Google\Chrome\User Data\Default\IndexedDB\*autodesk*") do (
        if exist "%%d" (
            <nul set /p "=      Chrome cache: %%~nxd..."
            rd /s /q "%%d" 2>nul
            if not exist "%%d" (
                echo  !CGRN!deleted.!R!
                set /a INST_DEL+=1
            )
            if exist "%%d" echo  !CRED!LOCKED.!R!
        )
    )
    echo      !INST_DEL! installer items removed.
    echo  OPTIONAL: !INST_DEL! installer/download items removed >> "!LOGFILE!"
)

REM --- Optional: Desktop Connector workspace cleanup ---
if !DTC_CLEAN_WS! equ 1 (
    echo  !DIM![!time:~0,8!]!R! !CYLW!!BOLD![OPT]!R! !CWHT!Removing Desktop Connector workspace...!R!
    taskkill /f /im "DesktopConnector.Applications.Tray.exe" >nul 2>&1
    taskkill /f /im "DesktopConnector.Core.Service.exe" >nul 2>&1
    net stop "DesktopConnectorService" >nul 2>&1
    set DTC_DEL=0
    for %%d in ("%USERPROFILE%\DC" "%USERPROFILE%\ACCDocs") do (
        if exist "%%~d\" (
            <nul set /p "=      %%~nxd..."
            rd /s /q "%%~d" 2>nul
            if not exist "%%~d\" (
                echo  !CGRN!deleted.!R!
                set /a DTC_DEL+=1
            )
            if exist "%%~d\" echo  !CRED!LOCKED.!R!
        )
    )
    echo      !DTC_DEL! workspace folder^(s^) removed.
    echo  OPTIONAL: !DTC_DEL! Desktop Connector workspace folders removed >> "!LOGFILE!"
)
echo.

REM --- Phase E2: Shortcut cleanup ---
echo  !DIM![!time:~0,8!]!R! !CCYN!!BOLD![E2]!R! !CWHT!Removing Autodesk shortcuts...!R!
set SC_DEL=0
REM Desktop shortcuts - current user and public
for %%L in ("%USERPROFILE%\Desktop" "C:\Users\Public\Desktop") do (
    if exist "%%~L" (
        for %%f in ("%%~L\*.lnk") do (
            echo "%%~nf" | findstr /i /c:"Autodesk" /c:"AutoCAD" /c:"Revit" /c:"Inventor" /c:"Civil 3D" /c:"Maya" /c:"Navisworks" /c:"DWG" /c:"Alias" /c:"Moldflow" /c:"Fusion" /c:"Advance Steel" /c:"Design Review" /c:"3ds Max" /c:"3dsMax" >nul 2>&1
            if !errorlevel! equ 0 (
                del /f "%%f" >nul 2>&1
                set /a SC_DEL+=1
                echo   SHORTCUT: %%~nxf >> "!LOGFILE!"
            )
        )
    )
)
REM Start Menu folders - current user and all users
for %%M in (
    "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Autodesk"
    "%ProgramData%\Microsoft\Windows\Start Menu\Programs\Autodesk"
) do (
    if exist "%%~M" (
        rd /s /q "%%~M" 2>nul
        set /a SC_DEL+=1
        echo   START MENU: %%~M >> "!LOGFILE!"
    )
)
REM Individual start menu shortcuts outside Autodesk folder
for %%M in (
    "%APPDATA%\Microsoft\Windows\Start Menu\Programs"
    "%ProgramData%\Microsoft\Windows\Start Menu\Programs"
) do (
    if exist "%%~M" (
        for %%f in ("%%~M\*.lnk") do (
            echo "%%~nf" | findstr /i /c:"Autodesk" /c:"AutoCAD" /c:"Revit" /c:"Inventor" /c:"DWG" /c:"Design Review" >nul 2>&1
            if !errorlevel! equ 0 (
                del /f "%%f" >nul 2>&1
                set /a SC_DEL+=1
            )
        )
    )
)
REM Taskbar pins
for %%T in ("%APPDATA%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar") do (
    if exist "%%~T" (
        for %%f in ("%%~T\*.lnk") do (
            echo "%%~nf" | findstr /i /c:"Autodesk" /c:"AutoCAD" /c:"Revit" /c:"Inventor" /c:"Maya" /c:"Navisworks" /c:"DWG" /c:"Alias" /c:"Design Review" /c:"3ds Max" /c:"3dsMax" >nul 2>&1
            if !errorlevel! equ 0 (
                del /f "%%f" >nul 2>&1
                set /a SC_DEL+=1
                echo   TASKBAR: %%~nxf >> "!LOGFILE!"
            )
        )
    )
)
echo      !SC_DEL! shortcuts removed.
if !SC_DEL! gtr 0 echo  PHASE E2: !SC_DEL! shortcuts >> "!LOGFILE!"
echo.

echo.
echo  !DIM![!time:~0,8!]!R! !CCYN!Progress: !CGRN!=============!R!!DIM!=======!R! !CWHT!Phase F - 8 of 12!R!
REM --- Phase F: Caches ---
echo [!time:~0,8!] Phase F started >> "!CLOG!"
echo  !DIM![!time:~0,8!]!R! !CCYN!!BOLD![F]!R! !CWHT!Cleaning licensing and cache artifacts...!R!
if exist "C:\ProgramData\FLEXnet" (
    <nul set /p "=      FLEXnet adsk files..."
    attrib -h -s -r "C:\ProgramData\FLEXnet\adsk*" >nul 2>&1
    del /f /q /a "C:\ProgramData\FLEXnet\adsk*" >nul 2>&1
    echo  !CGRN!done.!R!
)
if exist "C:\ProgramData\Autodesk\CLM" (
    <nul set /p "=      CLM license data..."
    rd /s /q "C:\ProgramData\Autodesk\CLM" 2>nul
    echo  !CGRN!done.!R!
)
if exist "%APPDATA%\Autodesk\ADUT" (
    <nul set /p "=      ADUT transition data..."
    rd /s /q "%APPDATA%\Autodesk\ADUT" 2>nul
    echo  !CGRN!done.!R!
)
if exist "%LOCALAPPDATA%\Temp\odis_download_dest" (
    <nul set /p "=      ODIS download cache..."
    rd /s /q "%LOCALAPPDATA%\Temp\odis_download_dest" 2>nul
    echo  !CGRN!done.!R!
)
if exist "%LOCALAPPDATA%\Autodesk\Web Services\LoginState.xml" (
    <nul set /p "=      LoginState.xml..."
    del /f "%LOCALAPPDATA%\Autodesk\Web Services\LoginState.xml" >nul 2>&1
    echo  !CGRN!done.!R!
)
<nul set /p "=      Temp folder..."
del /q /f "%temp%\*" >nul 2>&1
for /d %%d in ("%temp%\*") do rd /s /q "%%d" 2>nul
echo  !CGRN!done.!R!
REM --- System temp Autodesk cleanup ---
<nul set /p "=      System temp..."
for /f "tokens=*" %%f in ('dir /b /ad "C:\Windows\Temp\*Autodesk*" 2^>nul') do (
    rd /s /q "C:\Windows\Temp\%%f" 2>nul
)
for /f "tokens=*" %%f in ('dir /b "C:\Windows\Temp\*Autodesk*" 2^>nul') do (
    del /f /q "C:\Windows\Temp\%%f" 2>nul
)
echo  !CGRN!done.!R!
echo [!time:~0,8!] Phase F: caches cleaned >> "!CLOG!"
echo.

echo.
echo  !DIM![!time:~0,8!]!R! !CCYN!Progress: !CGRN!===============!R!!DIM!=====!R! !CWHT!Phase G - 9 of 12!R!
REM --- Phase G: Services, tasks, firewall ---
echo [!time:~0,8!] Phase G started >> "!CLOG!"
echo  !DIM![!time:~0,8!]!R! !CCYN!!BOLD![G]!R! !CWHT!Removing services, tasks, firewall rules...!R!
<nul set /p "=      Services"
for %%s in (!SVC_NAMES!) do (
    sc query "%%s" >nul 2>&1
    if !errorlevel! equ 0 (
        sc delete "%%s" >nul 2>&1
        <nul set /p "= %%s"
    )
)
echo .
sc query "FlexNet Licensing Service 64" >nul 2>&1
if !errorlevel! equ 0 (
    echo      [WARN] FlexNet Licensing Service 64 found.
    echo             Shared with Adobe. Type N if you use Adobe.
    set /p "DEL_FLEX=      Delete FlexNet service? [Y/N]: "
    if /i "!DEL_FLEX!"=="Y" (
        sc delete "FlexNet Licensing Service 64" >nul 2>&1
        echo      [DELETED] FlexNet Licensing Service 64
    )
)
<nul set /p "=      Scheduled tasks"
set TASK_DEL=0
for /f "tokens=1 delims=," %%n in ('schtasks /query /fo csv /nh 2^>nul ^| findstr /i "Autodesk"') do (
    set "TN=%%~n"
    schtasks /delete /tn "!TN!" /f >nul 2>&1
    set /a TASK_DEL+=1
    <nul set /p "=."
)
echo  !TASK_DEL! removed.
<nul set /p "=      Firewall rules"
set FW_DEL=0
for /f "delims=" %%r in ('powershell -NoProfile -Command "(Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'Autodesk|AutoCAD|Revit|Inventor|Civil|Maya|3ds.?Max|Navisworks' }).DisplayName" 2^>nul') do (
    netsh advfirewall firewall delete rule name="%%r" >nul 2>&1
    set /a FW_DEL+=1
    <nul set /p "=."
)
echo  !FW_DEL! removed.
echo [!time:~0,8!] Phase G: services/tasks/firewall cleaned >> "!CLOG!"
echo.

echo.
echo  !DIM![!time:~0,8!]!R! !CCYN!Progress: !CGRN!=================!R!!DIM!===!R! !CWHT!Phase H - 10 of 12!R!
REM --- Phase H: Registry ---
echo [!time:~0,8!] Phase H started >> "!CLOG!"
echo  !DIM![!time:~0,8!]!R! !CCYN!!BOLD![H]!R! !CWHT!Backing up and removing registry keys...!R!
echo  PHASE H START %time% >> "!DIAGFILE!"
set RDEL=0
for %%k in (
    "HKLM\SOFTWARE\Autodesk"
    "HKCU\SOFTWARE\Autodesk"
    "HKCU\SOFTWARE\SOFTWARE\Autodesk"
    "HKLM\SOFTWARE\WOW6432Node\Autodesk"
    "HKLM\SOFTWARE\FLEXlm License Manager"
    "HKCU\SOFTWARE\FLEXlm License Manager"
    "HKLM\SOFTWARE\WOW6432Node\FLEXlm License Manager"
    "HKLM\SOFTWARE\Macrovision"
) do (
    reg query %%k >nul 2>&1
    if !errorlevel! equ 0 (
        set "BN=%%~k"
        set "BN=!BN:\=_!"
        <nul set /p "=      %%~k..."
        reg export %%k "!LOGDIR!\!BN!.reg" /y >nul 2>&1
        reg delete %%k /f >nul 2>&1
        echo  !CGRN!deleted.!R!
        set /a RDEL+=1
    )
)
for %%v in (ADSKFLEX_LICENSE_FILE ADSK_LICENSE_FILE AUTODESK_LICENSE_FILE FLEXLM_TIMEOUT) do (
    reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v "%%v" >nul 2>&1
    if !errorlevel! equ 0 (
        reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v "%%v" /f >nul 2>&1
        echo      Removed env var: %%v
        set /a RDEL+=1
    )
    reg query "HKCU\Environment" /v "%%v" >nul 2>&1
    if !errorlevel! equ 0 (
        reg delete "HKCU\Environment" /v "%%v" /f >nul 2>&1
        echo      Removed user env var: %%v
        set /a RDEL+=1
    )
)
echo      !RDEL! registry items removed. Backups in !LOGDIR!
echo [!time:~0,8!] Phase H: registry cleaned >> "!CLOG!"
echo.

REM --- Phase H2: User class registry cleanup ---
echo [!time:~0,8!] Phase H2 started >> "!CLOG!"
echo  !DIM![!time:~0,8!]!R! !CCYN!!BOLD![H2]!R! !CWHT!Cleaning user file associations...!R!
set CDEL=0
REM Delete known Autodesk-named class keys from HKCU - multiple passes to catch subkeys
for /f "tokens=*" %%k in ('reg query "HKCU\SOFTWARE\Classes" /f "DWGTrueView" /k 2^>nul ^| findstr /i "HKEY_"') do (
    reg delete "%%k" /f >nul 2>&1
    set /a CDEL+=1
)
for /f "tokens=*" %%k in ('reg query "HKCU\SOFTWARE\Classes" /f "AutoCAD" /k 2^>nul ^| findstr /i "HKEY_"') do (
    reg delete "%%k" /f >nul 2>&1
    set /a CDEL+=1
)
for /f "tokens=*" %%k in ('reg query "HKCU\SOFTWARE\Classes" /f "acadlt" /k 2^>nul ^| findstr /i "HKEY_"') do (
    reg delete "%%k" /f >nul 2>&1
    set /a CDEL+=1
)
for /f "tokens=*" %%k in ('reg query "HKCU\SOFTWARE\Classes" /f "Autodesk" /k 2^>nul ^| findstr /i "HKEY_"') do (
    echo "%%k" | findstr /i "EncapsulatedPostscript ErrorLogFile ExportedToolPalettes Ghostscript WindowsMetafile MuiCache" >nul 2>&1
    if !errorlevel! neq 0 (
        reg delete "%%k" /f >nul 2>&1
        set /a CDEL+=1
    )
)
for %%n in (!CLASS_KEYS!) do (
    reg query "HKCU\SOFTWARE\Classes\%%n" >nul 2>&1
    if !errorlevel! equ 0 (
        reg delete "HKCU\SOFTWARE\Classes\%%n" /f >nul 2>&1
        set /a CDEL+=1
    )
)
reg delete "HKCU\SOFTWARE\Classes\dwgviewr.9128.409" /f >nul 2>&1
if !errorlevel! equ 0 set /a CDEL+=1
reg delete "HKCU\SOFTWARE\Classes\.dgn" /f >nul 2>&1
if !errorlevel! equ 0 set /a CDEL+=1
REM Delete CLSIDs that reference Autodesk paths
for /f "tokens=*" %%k in ('reg query "HKCU\SOFTWARE\Classes\CLSID" /s /f "Autodesk" /d 2^>nul ^| findstr /i "HKEY_.*CLSID.*{"') do (
    reg delete "%%k" /f >nul 2>&1
    set /a CDEL+=1
)
REM Delete CLSIDs that reference Autodesk in HKLM
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Classes\CLSID" /s /f "Autodesk" /d 2^>nul ^| findstr /i "HKEY_.*CLSID.*{"') do (
    reg delete "%%k" /f >nul 2>&1
    set /a CDEL+=1
)
REM Delete TypeLibs that reference Autodesk in HKLM
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Classes\TypeLib" /s /f "Autodesk" /d 2^>nul ^| findstr /i "HKEY_.*TypeLib.*{"') do (
    reg delete "%%k" /f >nul 2>&1
    set /a CDEL+=1
)
REM Clean MuiCache Autodesk entries
for /f "tokens=*" %%c in ('powershell -NoProfile -Command "$p='HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache'; $count=0; (Get-ItemProperty $p -ErrorAction SilentlyContinue).PSObject.Properties | Where-Object { $_.Name -match 'Autodesk' -or $_.Value -match 'Autodesk' } | ForEach-Object { Remove-ItemProperty $p -Name $_.Name -Force -ErrorAction SilentlyContinue; $count++ }; Write-Output $count" 2^>nul') do set /a CDEL+=%%c
REM Clean shell extensions from HKLM
for /f "tokens=1,*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Approved" /s 2^>nul ^| findstr /i "Autodesk"') do (
    reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Approved" /v "%%a" /f >nul 2>&1
    set /a CDEL+=1
)
REM Second pass: catch any remaining DWGTrueView/AutoCAD/acadlt keys
for /f "tokens=*" %%k in ('reg query "HKCU\SOFTWARE\Classes" /f "DWGTrueView" /k 2^>nul ^| findstr /i "HKEY_"') do (
    reg delete "%%k" /f >nul 2>&1
    set /a CDEL+=1
)
for /f "tokens=*" %%k in ('reg query "HKCU\SOFTWARE\Classes" /f "AutoCAD" /k 2^>nul ^| findstr /i "HKEY_"') do (
    reg delete "%%k" /f >nul 2>&1
    set /a CDEL+=1
)
for /f "tokens=*" %%k in ('reg query "HKCU\SOFTWARE\Classes" /f "acadlt" /k 2^>nul ^| findstr /i "HKEY_"') do (
    reg delete "%%k" /f >nul 2>&1
    set /a CDEL+=1
)
echo      !CDEL! user registry entries cleaned.
echo [!time:~0,8!] Phase H2: !CDEL! user-class entries cleaned >> "!CLOG!"
if !CDEL! gtr 0 echo  PHASE H2: !CDEL! user-class entries >> "!LOGFILE!"
echo.

REM --- Phase H3: IFEO debugger key cleanup ---
echo [!time:~0,8!] Phase H3 started >> "!CLOG!"
echo  !DIM![!time:~0,8!]!R! !CCYN!!BOLD![H3]!R! !CWHT!Checking IFEO debugger blocks...!R!
set IFEO_DEL=0
set "IFEO_ROOT=HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"
for %%x in (!IFEO_EXES!) do (
    reg query "!IFEO_ROOT!\%%x" /v Debugger >nul 2>&1
    if !errorlevel! equ 0 (
        reg delete "!IFEO_ROOT!\%%x" /v Debugger /f >nul 2>&1
        set /a IFEO_DEL+=1
    )
)
if !IFEO_DEL! gtr 0 (
    echo      !IFEO_DEL! IFEO debugger blocks removed.
    echo  PHASE H3: !IFEO_DEL! IFEO blocks removed >> "!LOGFILE!"
)
if !IFEO_DEL! equ 0 (
    echo      !CGRN!No IFEO blocks found.!R!
)
echo [!time:~0,8!] Phase H3: !IFEO_DEL! IFEO blocks removed >> "!CLOG!"
echo.

REM --- Installer\Products ghost cleanup ---
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT!Cleaning Installer\Products ghosts...!R!"
set IP_DEL=0
reg export "HKLM\SOFTWARE\Classes\Installer\Products" "!LOGDIR!\installer_products_backup.reg" /y >nul 2>&1
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Classes\Installer\Products" /s /v "ProductName" 2^>nul ^| findstr /i "HKEY_"') do (
    set "IP_KEY=%%k"
    set "IP_MATCH=0"
    for /f "tokens=2,*" %%a in ('reg query "%%k" /v "ProductName" 2^>nul ^| findstr /i "ProductName"') do (
        echo "%%b" | findstr /i "Autodesk" >nul 2>&1
        if !errorlevel! equ 0 set "IP_MATCH=1"
    )
    if !IP_MATCH! equ 1 (
        reg delete "%%k" /f >nul 2>&1
        set /a IP_DEL+=1
    )
)
if !IP_DEL! gtr 0 echo  !IP_DEL! ghost entries removed.
if !IP_DEL! equ 0 echo  !CGRN!clean.!R!
echo  INSTALLER-PRODUCTS: !IP_DEL! ghost entries removed >> "!LOGFILE!"
echo [!time:~0,8!] Installer\Products: !IP_DEL! ghosts removed >> "!CLOG!"
echo.

REM --- System PATH cleanup ---
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT!Cleaning system PATH...!R!"
reg export "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "!LOGDIR!\system_path_backup.reg" /y >nul 2>&1
set PATH_CLEANED=0
for /f "delims=" %%r in ('powershell -NoProfile -Command "$k=[Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment',$true); if($k){ $v=$k.GetValue('Path','', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames); if($v){ $e=$v -split ';'; $c=@(); $rm=0; foreach($x in $e){ if($x -and ($x -match 'Autodesk|AdODIS')){ $rm++ }elseif($x){ $c+=$x } }; if($rm -gt 0){ $k.SetValue('Path',($c -join ';'),[Microsoft.Win32.RegistryValueKind]::ExpandString) }; $k.Close(); Write-Output $rm }else{ Write-Output 0 } }else{ Write-Output 0 }"') do set "PATH_CLEANED=%%r"
if !PATH_CLEANED! gtr 0 echo  !PATH_CLEANED! dead entries removed.
if !PATH_CLEANED! equ 0 echo  !CGRN!clean.!R!
echo  SYSTEM-PATH: !PATH_CLEANED! dead entries removed >> "!LOGFILE!"
echo [!time:~0,8!] System PATH: !PATH_CLEANED! entries removed >> "!CLOG!"
echo.

REM --- PendingFileRenameOperations cleanup ---
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT!Checking PendingFileRenameOperations...!R!"
set PFRO_FOUND=0
for /f "tokens=*" %%v in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v PendingFileRenameOperations 2^>nul ^| findstr /i "Autodesk"') do (
    set "PFRO_FOUND=1"
)
if !PFRO_FOUND! equ 1 (
    echo  !CYLW!Autodesk entries found - cleaning...!R!
    REM Export current value, filter out Autodesk lines, reimport
    REM Since PendingFileRenameOperations is a REG_MULTI_SZ, the safest approach
    REM is to delete the entire value if it only contains Autodesk entries,
    REM or warn the user if it contains mixed entries
    REM For safety, just delete if present - Windows will recreate if needed
    powershell -NoProfile -Command "$rp='HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'; $v=(Get-ItemProperty $rp -Name PendingFileRenameOperations -EA SilentlyContinue).PendingFileRenameOperations; if($v){ $c=@(); $rm=0; for($i=0; $i -lt $v.Count; $i+=2){ $s=$v[$i]; $d=if($i+1 -lt $v.Count){$v[$i+1]}else{''}; if($s -match 'Autodesk|AdODIS|AdskLicensing|adsk' -or $d -match 'Autodesk|AdODIS|AdskLicensing|adsk'){ $rm++ }else{ $c+=$s; $c+=$d } }; if($rm -gt 0){ if($c.Count -eq 0){ Remove-ItemProperty $rp -Name PendingFileRenameOperations -Force -EA SilentlyContinue }else{ Set-ItemProperty $rp -Name PendingFileRenameOperations -Value ([string[]]$c) -Type MultiString -EA SilentlyContinue } } }" >nul 2>&1
    echo      PendingFileRenameOperations cleaned.
    echo  PFRO: Autodesk entries cleaned >> "!LOGFILE!"
)
if !PFRO_FOUND! equ 0 (
    echo  !CGRN!clean.!R!
)

REM Clear Windows Update RebootRequired flag
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" /f >nul 2>&1
REM Clear Windows Update Orchestrator reboot flag
reg delete "HKLM\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\RebootRequired" /f >nul 2>&1
REM Reset UpdateExeVolatile to 0
reg query "HKLM\SOFTWARE\Microsoft\Updates" /v UpdateExeVolatile >nul 2>&1
if !errorlevel! equ 0 (
    reg add "HKLM\SOFTWARE\Microsoft\Updates" /v UpdateExeVolatile /t REG_DWORD /d 0 /f >nul 2>&1
)

echo.
echo  !DIM![!time:~0,8!]!R! !CCYN!Progress: !CGRN!====================!R! !CWHT!Phase I - 12 of 12!R!
REM --- Phase I: Genuine Service (LAST) ---
echo [!time:~0,8!] Phase I started >> "!CLOG!"
<nul set /p "=  !DIM![!time:~0,8!]!R! !CCYN!!BOLD![I]!R! Removing Genuine Service..."
sc stop "Autodesk Genuine Service" >nul 2>&1
sc delete "Autodesk Genuine Service" >nul 2>&1
rd /s /q "C:\Program Files (x86)\Autodesk\Genuine Service" 2>nul
rd /s /q "%LOCALAPPDATA%\Programs\Autodesk\Genuine Service" 2>nul
echo  !CGRN!done.!R!
echo [!time:~0,8!] Phase I: Genuine Service removed >> "!CLOG!"
echo.
REM --- Phase E3: Retry locked folders ---
if defined LOCKED_LIST (
    echo.
    echo [!time:~0,8!] Phase E3 started >> "!CLOG!"
    echo  !DIM![!time:~0,8!]!R! !CCYN!!BOLD![E3]!R! !CWHT!Retrying locked folders...!R!
    for %%p in (!KILL_PROCS!) do (
        taskkill /f /im "%%p" >nul 2>&1
    )
    wmic process where "ExecutablePath like '%%Autodesk%%'" call terminate >nul 2>&1
    wmic process where "ExecutablePath like '%%AdODIS%%'" call terminate >nul 2>&1
    powershell -NoProfile -Command "Get-Process | Where-Object { $_.Path -match 'Autodesk|AdODIS|Adsk' } | Stop-Process -Force -ErrorAction SilentlyContinue" >nul 2>&1
    net stop WSearch >nul 2>&1
    net stop msiserver >nul 2>&1
    REM Kill explorer to release shell extension handles on backup files
    taskkill /f /im explorer.exe >nul 2>&1
    timeout /t 2 >nul
    start "" explorer.exe
    timeout /t 2 >nul
    timeout /t 2 >nul
    REM Delete files first, then remove empty dirs
    for %%d in (!LOCKED_LIST!) do (
        if exist "%%~d" (
            del /f /s /q "%%~d\*" >nul 2>&1
            for /f "delims=" %%x in ('dir /s /b /ad "%%~d" 2^>nul ^| sort /r') do rd "%%x" 2>nul
        )
    )
    for %%d in (!LOCKED_LIST!) do (
        if exist "%%~d" (
            <nul set /p "=      %%~d..."
            rd /s /q "%%~d" 2>nul
            if exist "%%~d" (
                takeown /f "%%~d" /r /d y >nul 2>&1
                icacls "%%~d" /grant *S-1-1-0:F /t /c /q >nul 2>&1
                rd /s /q "%%~d" 2>nul
            )
            if not exist "%%~d" (
                echo  !CGRN!deleted.!R!
            )
            if exist "%%~d" (
                echo  !CRED!still locked - will clean on reboot.!R!
            )
        )
        if not exist "%%~d" (
            echo      %%~d... !CGRN!already gone.!R!
        )
    )
)

REM Generate reboot cleanup only if folders still locked after retry
set "STILL_LOCKED=0"
if defined LOCKED_LIST (
    for %%d in (!LOCKED_LIST!) do (
        if exist "%%~d" set "STILL_LOCKED=1"
    )
)
if !STILL_LOCKED! equ 1 (
    set "REBOOT_BAT=!LOGDIR!\reboot_cleanup.bat"
    echo @echo off > "!REBOOT_BAT!"
    echo timeout /t 10 /nobreak ^>nul >> "!REBOOT_BAT!"
    for %%d in (!LOCKED_LIST!) do (
        if exist "%%~d" echo if exist "%%~d" rd /s /q "%%~d" >> "!REBOOT_BAT!"
    )
    echo del /f "!REBOOT_BAT!" >> "!REBOOT_BAT!"
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v "AutodeskCleanup" /t REG_SZ /d "\"!REBOOT_BAT!\"" /f >nul 2>&1
    echo      !CYLW!Reboot cleanup script scheduled for remaining locked folders.!R!
    echo   REBOOT CLEANUP SCHEDULED >> "!LOGFILE!"
)

REM --- Service flush: clear in-memory reboot state ---
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT!Flushing installer services...!R!"
net stop msiserver /y >nul 2>&1
net start msiserver >nul 2>&1
echo  !CGRN!done.!R!
echo  SERVICE FLUSH: msiserver restarted >> "!LOGFILE!"

echo  === FULL CLEAN COMPLETE === >> "!LOGFILE!"

echo  ========================================================
echo  !DIM!Started: !FC_START!  Completed: !time:~0,8!!R!
echo   !CGRN!!BOLD!ALL PHASES COMPLETE - RUNNING VERIFICATION...!R!
echo  ========================================================
echo.
echo [!time:~0,8!] Full Clean: Started !FC_START! Completed !time:~0,8! >> "!CLOG!"
echo. >> "!CLOG!"
echo --- End of section --- >> "!CLOG!"
echo. >> "!CLOG!"
pause
goto :run_verify

REM ============================================================
REM DEEP CLEAN ONLY
REM ============================================================
:deep_clean
cls
echo.
echo  ========================================================
echo   !CYLW!!BOLD!DEEP CLEAN - Remove All Remnants!R!
echo   !DIM!Covers legacy pre-2020 and modern 2020+ artifacts!R!
echo  ========================================================
echo.
echo  Skips product uninstallation, removes all remnants:
echo    Components, folders, caches, registry, services, etc.
echo.
set /p "DC_CONF=  Type YES to proceed: "
if /i not "!DC_CONF!"=="YES" (
    echo  Aborted.
    pause
    goto :main_menu
)
echo. >> "!CLOG!"
echo ======================================================== >> "!CLOG!"
echo  DEEP CLEAN >> "!CLOG!"
echo ======================================================== >> "!CLOG!"

REM Check for installer/download folders
set "CLEAN_INSTALLERS=0"
set "INSTALLER_FOUND=0"
for /f "tokens=*" %%p in ('dir /s /b /ad "C:\*Autodesk*" 2^>nul ^| findstr /i "\\Downloads\\"') do set "INSTALLER_FOUND=1"
if exist "%USERPROFILE%\Downloads\*Autodesk*" set "INSTALLER_FOUND=1"
if !INSTALLER_FOUND! equ 1 (
    echo.
    echo  !CYLW!============================================================!R!
    echo  !CYLW! Autodesk !CWHT!installer/download files!R!!CYLW! were found in your     !R!
    echo  !CYLW! Downloads folder. These are setup packages, not products.  !R!
    echo  !CYLW! They are !CWHT!NOT!R!!CYLW! removed by default.                          !R!
    echo  !CYLW!============================================================!R!
    echo      !CYLW!Tip: Most users choose N here - you will need these files!R!
    echo      !CYLW!if you plan to reinstall Autodesk products.!R!
    set /p "DC_INST=  Also remove installer files from Downloads? [Y/N]: "
    if /i "!DC_INST!"=="Y" set "CLEAN_INSTALLERS=1"
)

REM Check for Desktop Connector workspace (user project data - opt-in)
set "DTC_CLEAN_WS=0"
set "DTC_WS_FOUND=0"
if exist "%USERPROFILE%\DC\" set "DTC_WS_FOUND=1"
if exist "%USERPROFILE%\ACCDocs\" set "DTC_WS_FOUND=1"
if !DTC_WS_FOUND! equ 1 (
    echo.
    echo  !CYLW!============================================================!R!
    echo  !CYLW! A !CWHT!Desktop Connector workspace!R!!CYLW! was found on this machine.   !R!
    echo  !CYLW! It holds ACC / BIM 360 !CWHT!project files!R!!CYLW! synced to this PC.    !R!
    echo  !CYLW! It is !CWHT!NOT!R!!CYLW! removed by default.                              !R!
    echo  !CYLW!============================================================!R!
    echo      !CRED!WARNING: files not fully uploaded to the Autodesk cloud!R!
    echo      !CRED!will be PERMANENTLY LOST if you choose Y.!R!
    echo      !CYLW!Tip: Most users choose N here.!R!
    set "DTC_ANS="
    set /p "DTC_ANS=  Also delete Desktop Connector workspace folders? [Y/N]: "
    if /i "!DTC_ANS!"=="Y" set "DTC_CLEAN_WS=1"
)
set "DCL_START=!time:~0,8!"

echo.
REM Offer restore point
echo      !CCYN!Tip: A restore point is optional. The tool creates!R!
echo      !CCYN!registry backups automatically.!R!
set /p "DC_RP=  Create restore point first? [Y/N]: "
if /i not "!DC_RP!"=="Y" goto :dc_after_rp

<nul set /p "=  Creating restore point..."
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /t REG_DWORD /d 0 /f >nul 2>&1
set "WMIC_RP_OK=0"
for /f "tokens=*" %%w in ('wmic.exe /Namespace:\\root\default Path SystemRestore Call CreateRestorePoint "Pre-Autodesk Deep Clean"^, 100^, 12 2^>nul') do (
    echo "%%w" | findstr /i "ReturnValue = 0" >nul 2>&1
    if !errorlevel! equ 0 set "WMIC_RP_OK=1"
)
if !WMIC_RP_OK! equ 1 (
    echo  !CGRN!OK!R!
    reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /f >nul 2>&1
    goto :dc_after_rp
)
powershell -ExecutionPolicy Bypass -Command "Checkpoint-Computer -Description 'Pre-Autodesk Deep Clean' -RestorePointType 'MODIFY_SETTINGS'" >nul 2>&1
if !errorlevel! equ 0 (
    echo  OK via PowerShell
    reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /f >nul 2>&1
    goto :dc_after_rp
)
echo  FAILED - continuing.
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /f >nul 2>&1

:dc_after_rp

echo.
<nul set /p "=  Stopping services"
for %%s in (AdAppMgrSvc AdskAccessServiceHost AdskLicensingService AdskNLM DesktopConnectorService) do (
    sc query "%%s" >nul 2>&1
    if !errorlevel! equ 0 (
        net stop "%%s" >nul 2>&1
        sc config "%%s" start= disabled >nul 2>&1
        <nul set /p "=."
    )
)
net stop "FlexNet Licensing Service 64" >nul 2>&1
net stop "Autodesk Genuine Service" >nul 2>&1
echo  !CGRN!done.!R!
<nul set /p "=  Killing processes"
for %%p in (!KILL_PROCS!) do (
    taskkill /f /im "%%p" >nul 2>&1
    if !errorlevel! equ 0 <nul set /p "=."
)
wmic process where "ExecutablePath like '%%Autodesk%%'" call terminate >nul 2>&1
wmic process where "ExecutablePath like '%%AdODIS%%'" call terminate >nul 2>&1
powershell -NoProfile -Command "Get-Process | Where-Object { $_.Path -match 'Autodesk|AdODIS|Adsk' } | Stop-Process -Force -ErrorAction SilentlyContinue" >nul 2>&1
net stop WSearch >nul 2>&1
echo  !CGRN!done.!R!
timeout /t 2 >nul

echo.
echo  Running component uninstallers...
if exist "C:\Program Files (x86)\Autodesk\Autodesk Desktop App\removeAdAppMgr.exe" (
    <nul set /p "=    Desktop App..."
    rd /s /q "%ProgramData%\Autodesk\SDS" 2>nul
    start /wait "" "C:\Program Files (x86)\Autodesk\Autodesk Desktop App\removeAdAppMgr.exe" --mode unattended
    echo  !CGRN!OK!R!
)
if exist "C:\Program Files\Autodesk\AdskIdentityManager\uninstall.exe" (
    <nul set /p "=    Identity Manager..."
    start /wait "" "C:\Program Files\Autodesk\AdskIdentityManager\uninstall.exe" --mode unattended
    echo  !CGRN!OK!R!
)
if exist "C:\Program Files\Autodesk\AdODIS\V1\RemoveODIS.exe" (
    del /f "C:\ProgramData\Autodesk\ODIS\AdODISInstaller.run.lock" >nul 2>&1
    <nul set /p "=    RemoveODIS..."
    start /wait "" "C:\Program Files\Autodesk\AdODIS\V1\RemoveODIS.exe" --mode unattended
    echo  !CGRN!OK!R!
)
if exist "C:\Program Files (x86)\Common Files\Autodesk Shared\AdskLicensing\uninstall.exe" (
    <nul set /p "=    AdskLicensing..."
    start /wait "" "C:\Program Files (x86)\Common Files\Autodesk Shared\AdskLicensing\uninstall.exe" --mode unattended
    echo  !CGRN!OK!R!
)
REM Deep Clean is remnant-only ("no product uninstall"), so we do NOT execute
REM AdskUninstallHelper.exe here. Running it performs a full, sometimes
REM interactive, product uninstall (it would hang on its GUI wizard and is out
REM of scope for this option). The C:\ProgramData\Autodesk\Uninstallers folder
REM is removed later as a remnant during folder deletion.
if exist "C:\ProgramData\Autodesk\Uninstallers" (
    echo      AdskUninstallHelpers... !DIM!^(removed with remnant folders^)!R!
)
del /f "C:\ProgramData\Autodesk\Adlm\ProductInformation.pit" >nul 2>&1
del /f "%LOCALAPPDATA%\Autodesk\Genuine Autodesk Service\id.dat" >nul 2>&1

echo.
echo  Cleaning licensing artifacts...
if exist "C:\ProgramData\FLEXnet" (
    <nul set /p "=    FLEXnet..."
    attrib -h -s -r "C:\ProgramData\FLEXnet\adsk*" >nul 2>&1
    del /f /q /a "C:\ProgramData\FLEXnet\adsk*" >nul 2>&1
    echo  !CGRN!done.!R!
)
if exist "C:\ProgramData\Autodesk\CLM" (
    <nul set /p "=    CLM..."
    rd /s /q "C:\ProgramData\Autodesk\CLM" 2>nul
    echo  !CGRN!done.!R!
)
if exist "%APPDATA%\Autodesk\ADUT" (
    <nul set /p "=    ADUT..."
    rd /s /q "%APPDATA%\Autodesk\ADUT" 2>nul
    echo  !CGRN!done.!R!
)
rd /s /q "%LOCALAPPDATA%\Temp\odis_download_dest" 2>nul
del /f "%LOCALAPPDATA%\Autodesk\Web Services\LoginState.xml" >nul 2>&1
<nul set /p "=    Temp folder..."
del /q /f "%temp%\*" >nul 2>&1
for /d %%d in ("%temp%\*") do rd /s /q "%%d" 2>nul
echo  !CGRN!done.!R!
REM --- System temp Autodesk cleanup ---
<nul set /p "=    System temp..."
for /f "tokens=*" %%f in ('dir /b /ad "C:\Windows\Temp\*Autodesk*" 2^>nul') do (
    rd /s /q "C:\Windows\Temp\%%f" 2>nul
)
for /f "tokens=*" %%f in ('dir /b "C:\Windows\Temp\*Autodesk*" 2^>nul') do (
    del /f /q "C:\Windows\Temp\%%f" 2>nul
)
echo  !CGRN!done.!R!

echo.
REM Kill again before folder deletion - component uninstallers may have spawned processes
<nul set /p "=  Killing residual processes"
for %%p in (AdskAccessService.exe AdskAccessCore.exe AdskAccessServiceHost.exe Installer.exe AdODIS.exe DesktopConnector.Applications.Tray.exe DesktopConnector.Core.Service.exe) do (
    taskkill /f /im "%%p" >nul 2>&1
)
wmic process where "ExecutablePath like '%%Autodesk%%'" call terminate >nul 2>&1
powershell -NoProfile -Command "Get-Process | Where-Object { $_.Path -match 'Autodesk|AdODIS|Adsk' } | Stop-Process -Force -ErrorAction SilentlyContinue" >nul 2>&1
net stop msiserver >nul 2>&1
net stop WSearch >nul 2>&1
REM Unregister shell extensions loaded by explorer.exe
set "DC_EXPLORER=0"
for %%x in (
    "C:\Program Files\Common Files\Autodesk Shared\AcShellEx\AcShellExtension.dll"
    "C:\Program Files (x86)\Common Files\Autodesk Shared\AcShellEx\AcShellExtension.dll"
    "C:\Program Files\Common Files\Autodesk Shared\DwfShellEx\DwfShellExtension.dll"
    "C:\Program Files (x86)\Common Files\Autodesk Shared\DwfShellEx\DwfShellExtension.dll"
) do (
    if exist %%x (
        regsvr32 /u /s %%x >nul 2>&1
        set "DC_EXPLORER=1"
    )
)
if !DC_EXPLORER! equ 1 (
    <nul set /p "= restarting explorer"
    taskkill /f /im explorer.exe >nul 2>&1
    timeout /t 2 >nul
    start "" explorer.exe
    timeout /t 2 >nul
)
echo  !CGRN!done.!R!
timeout /t 3 >nul
set "DC_LOCKED="
echo [!time:~0,8!] Deep Clean: deleting folders >> "!CLOG!"
echo  !DIM![!time:~0,8!]!R! Deleting folders...
for %%d in (
    "C:\Program Files\Autodesk"
    "C:\Program Files\Common Files\Autodesk Shared"
    "C:\Program Files\Common Files\Autodesk"
    "C:\Program Files (x86)\Autodesk"
    "C:\Program Files (x86)\Common Files\Autodesk Shared"
    "C:\Program Files (x86)\Common Files\Autodesk"
    "C:\ProgramData\Autodesk"
    "C:\Users\Public\Documents\Autodesk"
    "C:\Users\Public\Autodesk"
    "C:\Autodesk"
    "C:\Program Files\Common Files\Macrovision Shared"
) do (
    if exist %%d (
        <nul set /p "=    %%~d..."
        rd /s /q %%d 2>nul
        if exist %%d (
            takeown /f %%d /r /d y >nul 2>&1
            icacls %%d /grant *S-1-1-0:F /t /c /q >nul 2>&1
            rd /s /q %%d 2>nul
        )
        if not exist %%d echo  !CGRN!deleted.!R!
        if exist %%d (
            echo  !CRED!LOCKED.!R!
            set "DC_LOCKED=!DC_LOCKED! "%%~d""
        )
    )
)
for %%d in ("%APPDATA%\Autodesk" "%LOCALAPPDATA%\Autodesk" "%LOCALAPPDATA%\Programs\Autodesk") do (
    if exist "%%~d" (
        <nul set /p "=    %%~d..."
        rd /s /q "%%~d" 2>nul
        if exist "%%~d" (
            takeown /f "%%~d" /r /d y >nul 2>&1
            icacls "%%~d" /grant *S-1-1-0:F /t /c /q >nul 2>&1
            rd /s /q "%%~d" 2>nul
        )
        if not exist "%%~d" echo  !CGRN!deleted.!R!
        if exist "%%~d" (
            echo  !CRED!LOCKED.!R!
            set "DC_LOCKED=!DC_LOCKED! "%%~d""
        )
    )
)
if exist "%LOCALAPPDATA%\com.autodesk.cer-dialog" (
    <nul set /p "=    com.autodesk.cer-dialog..."
    rd /s /q "%LOCALAPPDATA%\com.autodesk.cer-dialog" 2>nul
    if not exist "%LOCALAPPDATA%\com.autodesk.cer-dialog" echo  !CGRN!deleted.!R!
    if exist "%LOCALAPPDATA%\com.autodesk.cer-dialog" echo  !CRED!LOCKED.!R!
)
REM Clean .NET NativeImages for Autodesk assemblies
for /d %%d in ("C:\Windows\assembly\NativeImages_v4.0.30319_64\Autodesk*") do (
    if exist "%%d" (
        <nul set /p "=    NativeImage: %%~nxd..."
        rd /s /q "%%d" 2>nul
        if not exist "%%d" echo  !CGRN!deleted.!R!
        if exist "%%d" echo  !CRED!LOCKED.!R!
    )
)
for /d %%d in ("C:\Windows\assembly\NativeImages_v4.0.30319_32\Autodesk*") do (
    if exist "%%d" (
        <nul set /p "=    NativeImage: %%~nxd..."
        rd /s /q "%%d" 2>nul
        if not exist "%%d" echo  !CGRN!deleted.!R!
        if exist "%%d" echo  !CRED!LOCKED.!R!
    )
)
if exist "C:\Windows\System32\config\systemprofile\AppData\Local\Autodesk" (
    <nul set /p "=    SYSTEM profile Autodesk..."
    rd /s /q "C:\Windows\System32\config\systemprofile\AppData\Local\Autodesk" 2>nul
    if not exist "C:\Windows\System32\config\systemprofile\AppData\Local\Autodesk" echo  !CGRN!deleted.!R!
    if exist "C:\Windows\System32\config\systemprofile\AppData\Local\Autodesk" echo  !CRED!LOCKED.!R!
)

REM --- Optional: Installer/Download files cleanup ---
if !CLEAN_INSTALLERS! equ 1 (
    echo.
    echo  !CYLW!!BOLD!Removing installer/download files [optional]...!R!
    set DC_INST_DEL=0
    for /d %%d in ("%USERPROFILE%\Downloads\*Autodesk*" "%USERPROFILE%\Downloads\*AutoCAD*" "%USERPROFILE%\Downloads\*Revit*" "%USERPROFILE%\Downloads\*Inventor*" "%USERPROFILE%\Downloads\*Maya*" "%USERPROFILE%\Downloads\*3dsMax*") do (
        if exist "%%d" (
            <nul set /p "=    %%~nxd..."
            rd /s /q "%%d" 2>nul
            if not exist "%%d" (
                echo  !CGRN!deleted.!R!
                set /a DC_INST_DEL+=1
            )
            if exist "%%d" echo  !CRED!LOCKED.!R!
        )
    )
    for /d %%d in ("%LOCALAPPDATA%\Google\Chrome\User Data\Default\IndexedDB\*autodesk*") do (
        if exist "%%d" (
            <nul set /p "=    Chrome cache: %%~nxd..."
            rd /s /q "%%d" 2>nul
            if not exist "%%d" (
                echo  !CGRN!deleted.!R!
                set /a DC_INST_DEL+=1
            )
            if exist "%%d" echo  !CRED!LOCKED.!R!
        )
    )
    echo    !DC_INST_DEL! installer items removed.
)

REM --- Optional: Desktop Connector workspace cleanup ---
if !DTC_CLEAN_WS! equ 1 (
    echo.
    echo  !CYLW!!BOLD!Removing Desktop Connector workspace [optional]...!R!
    taskkill /f /im "DesktopConnector.Applications.Tray.exe" >nul 2>&1
    taskkill /f /im "DesktopConnector.Core.Service.exe" >nul 2>&1
    net stop "DesktopConnectorService" >nul 2>&1
    set DTC_DEL=0
    for %%d in ("%USERPROFILE%\DC" "%USERPROFILE%\ACCDocs") do (
        if exist "%%~d\" (
            <nul set /p "=    %%~nxd..."
            rd /s /q "%%~d" 2>nul
            if not exist "%%~d\" (
                echo  !CGRN!deleted.!R!
                set /a DTC_DEL+=1
            )
            if exist "%%~d\" echo  !CRED!LOCKED.!R!
        )
    )
    echo    !DTC_DEL! workspace folder^(s^) removed.
    echo [!time:~0,8!] Deep Clean: !DTC_DEL! DTC workspace folders removed >> "!CLOG!"
)

echo.
echo  !DIM![!time:~0,8!]!R! Removing shortcuts...
set DC_SC=0
for %%L in ("%USERPROFILE%\Desktop" "C:\Users\Public\Desktop") do (
    if exist "%%~L" (
        for %%f in ("%%~L\*.lnk") do (
            echo "%%~nf" | findstr /i /c:"Autodesk" /c:"AutoCAD" /c:"Revit" /c:"Inventor" /c:"Civil 3D" /c:"Maya" /c:"Navisworks" /c:"DWG" /c:"Alias" /c:"Moldflow" /c:"Fusion" /c:"Advance Steel" /c:"Design Review" /c:"3ds Max" /c:"3dsMax" >nul 2>&1
            if !errorlevel! equ 0 (
                del /f "%%f" >nul 2>&1
                set /a DC_SC+=1
            )
        )
    )
)
for %%M in (
    "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Autodesk"
    "%ProgramData%\Microsoft\Windows\Start Menu\Programs\Autodesk"
) do (
    if exist "%%~M" (
        rd /s /q "%%~M" 2>nul
        set /a DC_SC+=1
    )
)
for %%M in (
    "%APPDATA%\Microsoft\Windows\Start Menu\Programs"
    "%ProgramData%\Microsoft\Windows\Start Menu\Programs"
) do (
    if exist "%%~M" (
        for %%f in ("%%~M\*.lnk") do (
            echo "%%~nf" | findstr /i /c:"Autodesk" /c:"AutoCAD" /c:"Revit" /c:"Inventor" /c:"DWG" /c:"Design Review" >nul 2>&1
            if !errorlevel! equ 0 (
                del /f "%%f" >nul 2>&1
                set /a DC_SC+=1
            )
        )
    )
)
for %%T in ("%APPDATA%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar") do (
    if exist "%%~T" (
        for %%f in ("%%~T\*.lnk") do (
            echo "%%~nf" | findstr /i /c:"Autodesk" /c:"AutoCAD" /c:"Revit" /c:"Inventor" /c:"Maya" /c:"Navisworks" /c:"DWG" /c:"Alias" /c:"Design Review" /c:"3ds Max" /c:"3dsMax" >nul 2>&1
            if !errorlevel! equ 0 (
                del /f "%%f" >nul 2>&1
                set /a DC_SC+=1
            )
        )
    )
)
echo    !DC_SC! shortcuts removed.
echo [!time:~0,8!] Deep Clean: !DC_SC! shortcuts removed >> "!CLOG!"

echo.
echo [!time:~0,8!] Deep Clean: deleting services >> "!CLOG!"
<nul set /p "=  !DIM![!time:~0,8!]!R! Deleting services"
for %%s in (!SVC_NAMES!) do (
    sc query "%%s" >nul 2>&1
    if !errorlevel! equ 0 (
        sc delete "%%s" >nul 2>&1
        <nul set /p "= %%s"
    )
)
sc delete "Autodesk Genuine Service" >nul 2>&1
echo  !CGRN!done.!R!

echo.
<nul set /p "=  Tasks and firewall"
for /f "tokens=1 delims=," %%n in ('schtasks /query /fo csv /nh 2^>nul ^| findstr /i "Autodesk"') do (
    schtasks /delete /tn "%%~n" /f >nul 2>&1
    <nul set /p "=."
)
for /f "delims=" %%r in ('powershell -NoProfile -Command "(Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'Autodesk|AutoCAD|Revit|Inventor|Civil|Maya|3ds.?Max|Navisworks' }).DisplayName" 2^>nul') do (
    netsh advfirewall firewall delete rule name="%%r" >nul 2>&1
    <nul set /p "=."
)
echo  !CGRN!done.!R!

echo.
echo  Backing up and deleting registry...
for %%k in (
    "HKLM\SOFTWARE\Autodesk"
    "HKCU\SOFTWARE\Autodesk"
    "HKCU\SOFTWARE\SOFTWARE\Autodesk"
    "HKLM\SOFTWARE\WOW6432Node\Autodesk"
    "HKLM\SOFTWARE\FLEXlm License Manager"
    "HKCU\SOFTWARE\FLEXlm License Manager"
    "HKLM\SOFTWARE\WOW6432Node\FLEXlm License Manager"
    "HKLM\SOFTWARE\Macrovision"
) do (
    reg query %%k >nul 2>&1
    if !errorlevel! equ 0 (
        set "BN=%%~k"
        set "BN=!BN:\=_!"
        <nul set /p "=    %%~k..."
        reg export %%k "!LOGDIR!\!BN!.reg" /y >nul 2>&1
        reg delete %%k /f >nul 2>&1
        echo  !CGRN!deleted.!R!
    )
)
for %%v in (ADSKFLEX_LICENSE_FILE ADSK_LICENSE_FILE AUTODESK_LICENSE_FILE FLEXLM_TIMEOUT) do (
    reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v "%%v" >nul 2>&1
    if !errorlevel! equ 0 (
        reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v "%%v" /f >nul 2>&1
        echo    Removed env var: %%v
    )
    reg query "HKCU\Environment" /v "%%v" >nul 2>&1
    if !errorlevel! equ 0 (
        reg delete "HKCU\Environment" /v "%%v" /f >nul 2>&1
        echo    Removed user env var: %%v
    )
)

echo.
<nul set /p "=  Removing Genuine Service..."
rd /s /q "C:\Program Files (x86)\Autodesk\Genuine Service" 2>nul
rd /s /q "%LOCALAPPDATA%\Programs\Autodesk\Genuine Service" 2>nul
echo  !CGRN!done.!R!

echo.
echo  Cleaning user file associations...
set DC_CDEL=0
for /f "tokens=*" %%k in ('reg query "HKCU\SOFTWARE\Classes" /f "DWGTrueView" /k 2^>nul ^| findstr /i "HKEY_"') do (
    reg delete "%%k" /f >nul 2>&1
    set /a DC_CDEL+=1
)
for /f "tokens=*" %%k in ('reg query "HKCU\SOFTWARE\Classes" /f "AutoCAD" /k 2^>nul ^| findstr /i "HKEY_"') do (
    reg delete "%%k" /f >nul 2>&1
    set /a DC_CDEL+=1
)
for /f "tokens=*" %%k in ('reg query "HKCU\SOFTWARE\Classes" /f "acadlt" /k 2^>nul ^| findstr /i "HKEY_"') do (
    reg delete "%%k" /f >nul 2>&1
    set /a DC_CDEL+=1
)
for /f "tokens=*" %%k in ('reg query "HKCU\SOFTWARE\Classes" /f "Autodesk" /k 2^>nul ^| findstr /i "HKEY_"') do (
    echo "%%k" | findstr /i "EncapsulatedPostscript ErrorLogFile ExportedToolPalettes Ghostscript WindowsMetafile MuiCache" >nul 2>&1
    if !errorlevel! neq 0 (
        reg delete "%%k" /f >nul 2>&1
        set /a DC_CDEL+=1
    )
)
for %%n in (!CLASS_KEYS!) do (
    reg query "HKCU\SOFTWARE\Classes\%%n" >nul 2>&1
    if !errorlevel! equ 0 (
        reg delete "HKCU\SOFTWARE\Classes\%%n" /f >nul 2>&1
        set /a DC_CDEL+=1
    )
)
reg delete "HKCU\SOFTWARE\Classes\dwgviewr.9128.409" /f >nul 2>&1
if !errorlevel! equ 0 set /a DC_CDEL+=1
reg delete "HKCU\SOFTWARE\Classes\.dgn" /f >nul 2>&1
if !errorlevel! equ 0 set /a DC_CDEL+=1
for /f "tokens=*" %%k in ('reg query "HKCU\SOFTWARE\Classes\CLSID" /s /f "Autodesk" /d 2^>nul ^| findstr /i "HKEY_.*CLSID.*{"') do (
    reg delete "%%k" /f >nul 2>&1
    set /a DC_CDEL+=1
)
REM Delete CLSIDs that reference Autodesk in HKLM
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Classes\CLSID" /s /f "Autodesk" /d 2^>nul ^| findstr /i "HKEY_.*CLSID.*{"') do (
    reg delete "%%k" /f >nul 2>&1
    set /a DC_CDEL+=1
)
REM Delete TypeLibs that reference Autodesk in HKLM
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Classes\TypeLib" /s /f "Autodesk" /d 2^>nul ^| findstr /i "HKEY_.*TypeLib.*{"') do (
    reg delete "%%k" /f >nul 2>&1
    set /a DC_CDEL+=1
)
for /f "tokens=*" %%c in ('powershell -NoProfile -Command "$p='HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache'; $count=0; (Get-ItemProperty $p -ErrorAction SilentlyContinue).PSObject.Properties | Where-Object { $_.Name -match 'Autodesk' -or $_.Value -match 'Autodesk' } | ForEach-Object { Remove-ItemProperty $p -Name $_.Name -Force -ErrorAction SilentlyContinue; $count++ }; Write-Output $count" 2^>nul') do set /a DC_CDEL+=%%c
for /f "tokens=1,*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Approved" /s 2^>nul ^| findstr /i "Autodesk"') do (
    reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Approved" /v "%%a" /f >nul 2>&1
    set /a DC_CDEL+=1
)
REM Second pass
for /f "tokens=*" %%k in ('reg query "HKCU\SOFTWARE\Classes" /f "DWGTrueView" /k 2^>nul ^| findstr /i "HKEY_"') do (
    reg delete "%%k" /f >nul 2>&1
    set /a DC_CDEL+=1
)
for /f "tokens=*" %%k in ('reg query "HKCU\SOFTWARE\Classes" /f "AutoCAD" /k 2^>nul ^| findstr /i "HKEY_"') do (
    reg delete "%%k" /f >nul 2>&1
    set /a DC_CDEL+=1
)
for /f "tokens=*" %%k in ('reg query "HKCU\SOFTWARE\Classes" /f "acadlt" /k 2^>nul ^| findstr /i "HKEY_"') do (
    reg delete "%%k" /f >nul 2>&1
    set /a DC_CDEL+=1
)
echo    !DC_CDEL! user registry entries cleaned.
echo [!time:~0,8!] Deep Clean: !DC_CDEL! user registry entries cleaned >> "!CLOG!"

REM --- IFEO debugger key cleanup ---
echo [!time:~0,8!] Deep Clean: checking IFEO >> "!CLOG!"
echo  !DIM![!time:~0,8!]!R! Checking IFEO debugger blocks...
set DC_IFEO=0
set "IFEO_ROOT=HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"
for %%x in (!IFEO_EXES!) do (
    reg query "!IFEO_ROOT!\%%x" /v Debugger >nul 2>&1
    if !errorlevel! equ 0 (
        reg delete "!IFEO_ROOT!\%%x" /v Debugger /f >nul 2>&1
        set /a DC_IFEO+=1
    )
)
if !DC_IFEO! gtr 0 echo    !DC_IFEO! IFEO debugger blocks removed.
if !DC_IFEO! equ 0 echo    No IFEO blocks found.
echo [!time:~0,8!] Deep Clean: !DC_IFEO! IFEO blocks >> "!CLOG!"

REM --- Installer\Products ghost cleanup ---
<nul set /p "=  !DIM![!time:~0,8!]!R! Cleaning Installer\Products ghosts..."
set DC_IP=0
reg export "HKLM\SOFTWARE\Classes\Installer\Products" "!LOGDIR!\installer_products_backup.reg" /y >nul 2>&1
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Classes\Installer\Products" /s /v "ProductName" 2^>nul ^| findstr /i "HKEY_"') do (
    set "IP_KEY=%%k"
    set "IP_MATCH=0"
    for /f "tokens=2,*" %%a in ('reg query "%%k" /v "ProductName" 2^>nul ^| findstr /i "ProductName"') do (
        echo "%%b" | findstr /i "Autodesk" >nul 2>&1
        if !errorlevel! equ 0 set "IP_MATCH=1"
    )
    if !IP_MATCH! equ 1 (
        reg delete "%%k" /f >nul 2>&1
        set /a DC_IP+=1
    )
)
if !DC_IP! gtr 0 echo  !DC_IP! ghost entries removed.
if !DC_IP! equ 0 echo  clean.
echo [!time:~0,8!] Deep Clean: Installer\Products !DC_IP! ghosts >> "!CLOG!"

REM --- System PATH cleanup ---
<nul set /p "=  !DIM![!time:~0,8!]!R! Cleaning system PATH..."
reg export "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "!LOGDIR!\system_path_backup.reg" /y >nul 2>&1
set DC_PATH=0
for /f "delims=" %%r in ('powershell -NoProfile -Command "$k=[Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment',$true); if($k){ $v=$k.GetValue('Path','', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames); if($v){ $e=$v -split ';'; $c=@(); $rm=0; foreach($x in $e){ if($x -and ($x -match 'Autodesk|AdODIS')){ $rm++ }elseif($x){ $c+=$x } }; if($rm -gt 0){ $k.SetValue('Path',($c -join ';'),[Microsoft.Win32.RegistryValueKind]::ExpandString) }; $k.Close(); Write-Output $rm }else{ Write-Output 0 } }else{ Write-Output 0 }"') do set "DC_PATH=%%r"
if !DC_PATH! gtr 0 echo  !DC_PATH! dead entries removed.
if !DC_PATH! equ 0 echo  clean.
echo [!time:~0,8!] Deep Clean: PATH !DC_PATH! entries removed >> "!CLOG!"

REM --- PendingFileRenameOperations cleanup ---
echo [!time:~0,8!] Deep Clean: checking PFRO >> "!CLOG!"
<nul set /p "=  !DIM![!time:~0,8!]!R! Checking PendingFileRenameOperations..."
set DC_PFRO=0
for /f "tokens=*" %%v in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v PendingFileRenameOperations 2^>nul ^| findstr /i "Autodesk"') do (
    set "DC_PFRO=1"
)
if !DC_PFRO! equ 1 (
    echo  cleaning...
    powershell -NoProfile -Command "$rp='HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'; $v=(Get-ItemProperty $rp -Name PendingFileRenameOperations -EA SilentlyContinue).PendingFileRenameOperations; if($v){ $c=@(); $rm=0; for($i=0; $i -lt $v.Count; $i+=2){ $s=$v[$i]; $d=if($i+1 -lt $v.Count){$v[$i+1]}else{''}; if($s -match 'Autodesk|AdODIS|AdskLicensing|adsk' -or $d -match 'Autodesk|AdODIS|AdskLicensing|adsk'){ $rm++ }else{ $c+=$s; $c+=$d } }; if($rm -gt 0){ if($c.Count -eq 0){ Remove-ItemProperty $rp -Name PendingFileRenameOperations -Force -EA SilentlyContinue }else{ Set-ItemProperty $rp -Name PendingFileRenameOperations -Value ([string[]]$c) -Type MultiString -EA SilentlyContinue } } }" >nul 2>&1
    echo    PendingFileRenameOperations cleaned.
)
if !DC_PFRO! equ 0 echo  clean.

REM Clear Windows Update RebootRequired flag
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" /f >nul 2>&1
REM Clear Windows Update Orchestrator reboot flag
reg delete "HKLM\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\RebootRequired" /f >nul 2>&1
REM Reset UpdateExeVolatile to 0
reg query "HKLM\SOFTWARE\Microsoft\Updates" /v UpdateExeVolatile >nul 2>&1
if !errorlevel! equ 0 (
    reg add "HKLM\SOFTWARE\Microsoft\Updates" /v UpdateExeVolatile /t REG_DWORD /d 0 /f >nul 2>&1
)

REM --- Retry locked folders ---
if defined DC_LOCKED (
    echo.
    echo  Retrying locked folders...
    for %%p in (!KILL_PROCS!) do (
        taskkill /f /im "%%p" >nul 2>&1
    )
    wmic process where "ExecutablePath like '%%Autodesk%%'" call terminate >nul 2>&1
    powershell -NoProfile -Command "Get-Process | Where-Object { $_.Path -match 'Autodesk|AdODIS|Adsk' } | Stop-Process -Force -ErrorAction SilentlyContinue" >nul 2>&1
    net stop WSearch >nul 2>&1
    net stop msiserver >nul 2>&1
    REM Kill explorer to release shell extension handles on backup files
    taskkill /f /im explorer.exe >nul 2>&1
    timeout /t 2 >nul
    start "" explorer.exe
    timeout /t 2 >nul
    timeout /t 2 >nul
    REM Delete files first, then remove empty dirs
    for %%d in (!DC_LOCKED!) do (
        if exist "%%~d" (
            del /f /s /q "%%~d\*" >nul 2>&1
            for /f "delims=" %%x in ('dir /s /b /ad "%%~d" 2^>nul ^| sort /r') do rd "%%x" 2>nul
        )
    )
    for %%d in (!DC_LOCKED!) do (
        if exist "%%~d" (
            <nul set /p "=    %%~d..."
            rd /s /q "%%~d" 2>nul
            if exist "%%~d" (
                takeown /f "%%~d" /r /d y >nul 2>&1
                icacls "%%~d" /grant *S-1-1-0:F /t /c /q >nul 2>&1
                rd /s /q "%%~d" 2>nul
            )
            if not exist "%%~d" echo  !CGRN!deleted.!R!
            if exist "%%~d" echo  !CRED!still locked.!R!
        )
    )
)
echo.
REM --- Multi-user registry cleanup ---
echo  !DIM![!time:~0,8!]!R! !CWHT!Cleaning other user profiles...!R!
set MU_CLEANED=0
set MU_SKIPPED=0
for /f "tokens=*" %%s in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" 2^>nul ^| findstr "S-1-5-21"') do (
    set "MU_SID=%%~nxs"
    set "MU_PATH="
    for /f "tokens=2,*" %%a in ('reg query "%%s" /v ProfileImagePath 2^>nul ^| findstr /i "ProfileImagePath"') do set "MU_PATH=%%b"
    if defined MU_PATH call set "MU_PATH=!MU_PATH!"
    if defined MU_PATH (
        for %%n in ("!MU_PATH!") do set "MU_NAME=%%~nxn"
        if /i "!MU_PATH!" neq "!USERPROFILE!" (
            set "MU_DAT=!MU_PATH!\NTUSER.DAT"
            if exist "!MU_DAT!" (
                reg query "HKU\!MU_SID!" >nul 2>&1
                if !errorlevel! equ 0 (
                    set /a MU_SKIPPED+=1
                )
                if !errorlevel! neq 0 (
                    reg load "HKU\TEMP_!MU_NAME!" "!MU_DAT!" >nul 2>&1
                    if !errorlevel! equ 0 (
                        reg query "HKU\TEMP_!MU_NAME!\Software\Autodesk" >nul 2>&1
                        if !errorlevel! equ 0 (
                            reg delete "HKU\TEMP_!MU_NAME!\Software\Autodesk" /f >nul 2>&1
                            set /a MU_CLEANED+=1
                            echo      !MU_NAME!: Autodesk registry cleaned
                        )
                        ping -n 3 127.0.0.1 >nul 2>&1
                        reg unload "HKU\TEMP_!MU_NAME!" >nul 2>&1
                    )
                )
            )
        )
    )
)
if !MU_CLEANED! gtr 0 echo    !MU_CLEANED! other user profiles cleaned.
if !MU_SKIPPED! gtr 0 echo    !DIM!!MU_SKIPPED! profiles skipped ^(users logged in^).!R!
if !MU_CLEANED! equ 0 if !MU_SKIPPED! equ 0 echo    No other user profiles found.
echo  MULTI-USER: !MU_CLEANED! cleaned, !MU_SKIPPED! skipped >> "!LOGFILE!"
echo [!time:~0,8!] Multi-user: !MU_CLEANED! cleaned, !MU_SKIPPED! skipped >> "!CLOG!"

REM --- Multi-user AppData cleanup ---
for /f "tokens=*" %%s in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" 2^>nul ^| findstr "S-1-5-21"') do (
    set "MU_SID=%%~nxs"
    set "MU_PATH="
    for /f "tokens=2,*" %%a in ('reg query "%%s" /v ProfileImagePath 2^>nul ^| findstr /i "ProfileImagePath"') do set "MU_PATH=%%b"
    if defined MU_PATH call set "MU_PATH=!MU_PATH!"
    if defined MU_PATH (
        if /i "!MU_PATH!" neq "!USERPROFILE!" (
            set "MU_AD_SKIP=0"
            reg query "HKU\!MU_SID!" >nul 2>&1
            if !errorlevel! equ 0 set "MU_AD_SKIP=1"
            if !MU_AD_SKIP! equ 0 (
                if exist "!MU_PATH!\AppData\Roaming\Autodesk" (
                    rd /s /q "!MU_PATH!\AppData\Roaming\Autodesk" 2>nul
                )
                if exist "!MU_PATH!\AppData\Local\Autodesk" (
                    rd /s /q "!MU_PATH!\AppData\Local\Autodesk" 2>nul
                )
            )
        )
    )
)

echo.
REM --- Service flush: clear in-memory reboot state ---
echo [!time:~0,8!] Deep Clean: service flush >> "!CLOG!"
<nul set /p "=  Flushing installer services..."
net stop msiserver /y >nul 2>&1
net start msiserver >nul 2>&1
echo  done.

echo.
echo  !CGRN!!BOLD!Deep clean complete.!R!
echo [!time:~0,8!] Deep clean complete >> "!CLOG!"
echo  !DIM!Started: !DCL_START!  Completed: !time:~0,8!!R!
echo [!time:~0,8!] Deep Clean: Started !DCL_START! Completed !time:~0,8! >> "!CLOG!"
echo. >> "!CLOG!"
echo --- End of section --- >> "!CLOG!"
echo. >> "!CLOG!"
echo  === DEEP CLEAN COMPLETE === >> "!LOGFILE!"
echo.
echo  !CCYN!System is ready for fresh Autodesk installation.!R!
echo  !DIM!If the new installer shows "restart pending", reboot once first.!R!
echo  !DIM!This is a Windows requirement after system cleanup, not an incomplete uninstall.!R!
echo.
pause
goto :run_verify

REM ============================================================
REM SEARCH FOR ALL AUTODESK REMNANTS
REM ============================================================
:search_remnants
cls
echo.
echo  ========================================================
echo   !CMAG!!BOLD!SEARCHING FOR ALL AUTODESK REMNANTS!R!
echo  ========================================================
echo.
set "SCANFILE=!LOGDIR!\remnant_scan.txt"
echo. >> "!CLOG!"
echo ======================================================== >> "!CLOG!"
echo  REMNANT SCAN >> "!CLOG!"
echo ======================================================== >> "!CLOG!"
echo Autodesk Remnant Scan - %date% %time% > "!SCANFILE!"
echo ================================================ >> "!SCANFILE!"

echo  !DIM!Scanning 15 areas... progress shown below.!R!
echo.

REM === 1. REGISTERED PRODUCTS ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![ 1/15]!R! Registered products............ "
set RS_PROD=0
echo --- REGISTERED PRODUCTS --- >> "!SCANFILE!"
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s /v "Publisher" 2^>nul ^| findstr /i "Autodesk"') do (
    set /a RS_PROD+=1
    <nul set /p "=!ESC![50G!DIM!scanning: !RS_PROD!  !R!"
    echo  %%k >> "!SCANFILE!"
)
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" /s /v "Publisher" 2^>nul ^| findstr /i "Autodesk"') do (
    set /a RS_PROD+=1
    <nul set /p "=!ESC![50G!DIM!scanning: !RS_PROD!  !R!"
    echo  %%k >> "!SCANFILE!"
)
echo. >> "!SCANFILE!"
if !RS_PROD! gtr 0 (
    echo !ESC![50G!CRED!!RS_PROD! found                    !R!
)
if !RS_PROD! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
)
echo [!time:~0,8!] Scan [1/15] Products: !RS_PROD! >> "!CLOG!"

REM === 2. RUNNING PROCESSES ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![ 2/15]!R! Running processes.............. "
set RS_PROC=0
echo --- RUNNING PROCESSES --- >> "!SCANFILE!"
set "PROC_TMP=!LOGDIR!\proc_check.tmp"
type nul > "!PROC_TMP!"
start "" /b cmd /c "tasklist /nh > "!PROC_TMP!" 2>nul"
ping -n 6 127.0.0.1 >nul 2>&1
taskkill /f /im tasklist.exe >nul 2>&1
for %%p in (!KILL_PROCS_SCAN!) do (
    findstr /i "%%p" "!PROC_TMP!" >nul 2>&1
    if !errorlevel! equ 0 (
        set /a RS_PROC+=1
        <nul set /p "=!ESC![50G!DIM!scanning: !RS_PROC!  !R!"
        echo  %%p >> "!SCANFILE!"
    )
)
del "!PROC_TMP!" >nul 2>&1
echo. >> "!SCANFILE!"
if !RS_PROC! gtr 0 (
    echo !ESC![50G!CRED!!RS_PROC! found                    !R!
)
if !RS_PROC! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
)
echo [!time:~0,8!] Scan [2/15] Processes: !RS_PROC! >> "!CLOG!"

REM === 3. SERVICES ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![ 3/15]!R! Services....................... "
set RS_SVC=0
echo --- SERVICES --- >> "!SCANFILE!"
for %%s in (AdskLicensingService AdskAccessServiceHost AdAppMgrSvc AdskNLM DesktopConnectorService "FlexNet Licensing Service 64" "Autodesk Genuine Service") do (
    sc query %%s >nul 2>&1
    if !errorlevel! equ 0 (
        set /a RS_SVC+=1
        <nul set /p "=!ESC![50G!DIM!scanning: !RS_SVC!  !R!"
        echo  FOUND: %%s >> "!SCANFILE!"
    )
)
echo. >> "!SCANFILE!"
if !RS_SVC! gtr 0 (
    echo !ESC![50G!CRED!!RS_SVC! found                    !R!
)
if !RS_SVC! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
)
echo [!time:~0,8!] Scan [3/15] Services: !RS_SVC! >> "!CLOG!"

REM === 4. PROGRAM FILES FOLDERS ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![ 4/15]!R! Program Files folders.......... "
set RS_PF=0
echo --- FOLDERS IN PROGRAM FILES --- >> "!SCANFILE!"
for %%d in (
    "C:\Program Files\Autodesk"
    "C:\Program Files\Common Files\Autodesk Shared"
    "C:\Program Files\Common Files\Autodesk"
    "C:\Program Files (x86)\Autodesk"
    "C:\Program Files (x86)\Common Files\Autodesk Shared"
    "C:\Program Files (x86)\Common Files\Autodesk"
) do (
    if exist %%d (
        set /a RS_PF+=1
        <nul set /p "=!ESC![50G!DIM!scanning: !RS_PF!  !R!"
        echo  EXISTS: %%~d >> "!SCANFILE!"
        dir /s /b %%d >> "!SCANFILE!" 2>nul
        echo. >> "!SCANFILE!"
    )
)
echo. >> "!SCANFILE!"
if !RS_PF! gtr 0 (
    echo !ESC![50G!CRED!!RS_PF! found                    !R!
)
if !RS_PF! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
)
echo [!time:~0,8!] Scan [4/15] ProgramFiles: !RS_PF! >> "!CLOG!"

REM === 5. DATA FOLDERS ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![ 5/15]!R! Data folders................... "
set RS_DATA=0
echo --- DATA FOLDERS --- >> "!SCANFILE!"
for %%d in (
    "C:\ProgramData\Autodesk"
    "C:\Autodesk"
    "C:\Users\Public\Documents\Autodesk"
    "%APPDATA%\Autodesk"
    "%LOCALAPPDATA%\Autodesk"
    "%LOCALAPPDATA%\Programs\Autodesk"
    "%LOCALAPPDATA%\Temp\odis_download_dest"
    "C:\ProgramData\FLEXnet"
    "C:\Program Files\Common Files\Macrovision Shared"
) do (
    if exist "%%~d" (
        set /a RS_DATA+=1
        <nul set /p "=!ESC![50G!DIM!scanning: !RS_DATA!  !R!"
        echo  EXISTS: %%~d >> "!SCANFILE!"
        dir /b "%%~d" >> "!SCANFILE!" 2>nul
        echo. >> "!SCANFILE!"
    )
)
set RS_DTCWS=0
for %%d in ("%USERPROFILE%\DC" "%USERPROFILE%\ACCDocs") do (
    if exist "%%~d\" (
        set /a RS_DTCWS+=1
        echo  EXISTS ^(Desktop Connector workspace - user data, opt-in removal only^): %%~d >> "!SCANFILE!"
        dir /b "%%~d" >> "!SCANFILE!" 2>nul
        echo. >> "!SCANFILE!"
    )
)
echo. >> "!SCANFILE!"
if !RS_DATA! gtr 0 (
    echo !ESC![50G!CRED!!RS_DATA! found                    !R!
)
if !RS_DATA! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
)
echo [!time:~0,8!] Scan [5/15] DataFolders: !RS_DATA! >> "!CLOG!"
if !RS_DTCWS! gtr 0 (
    echo      !CYLW!Desktop Connector workspace present ^(user data - not counted^)!R!
    echo [!time:~0,8!] Scan [5/15] DTC workspace: !RS_DTCWS! ^(informational^) >> "!CLOG!"
)

REM === 6. FULL C: DRIVE SEARCH ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![ 6/15]!R! Full C: drive search........... "
set RS_CDRIVE=0
set RS_RECYCLE=0
echo --- AUTODESK FOLDERS ANYWHERE ON C: --- >> "!SCANFILE!"
echo  Searching C: drive for Autodesk folders... >> "!SCANFILE!"
dir /s /b /ad "C:\*Autodesk*" 2>nul | findstr /v /i /c:"Desktop\Autodesk_Uninstaller" /c:"\Downloads\Autodesk" /c:"\Downloads\AutoCAD" /c:"\Downloads\Revit" /c:"\Downloads\Maya" /c:"\Downloads\3ds" /c:"\Downloads\Inventor" /c:"\Downloads\Civil" /c:"\Downloads\Navisworks" /c:"\Downloads\DWG" /c:"%SELFDIR%" > "!LOGDIR!\remnant_cdrive_tmp.txt"
for /f "tokens=*" %%L in ('type "!LOGDIR!\remnant_cdrive_tmp.txt" 2^>nul') do (
    echo "%%L" | findstr /i /c:"$Recycle.Bin" >nul 2>&1
    if !errorlevel! equ 0 (
        set /a RS_RECYCLE+=1
        echo  RECYCLE-BIN ^(informational - already deleted, pending purge^): %%L >> "!SCANFILE!"
    ) else (
        set /a RS_CDRIVE+=1
        <nul set /p "=!ESC![50G!DIM!scanning: !RS_CDRIVE!  !R!"
        echo  %%L >> "!SCANFILE!"
    )
)
del "!LOGDIR!\remnant_cdrive_tmp.txt" 2>nul
echo. >> "!SCANFILE!"
if !RS_CDRIVE! gtr 0 (
    echo !ESC![50G!CRED!!RS_CDRIVE! found                    !R!
)
if !RS_CDRIVE! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
)
echo [!time:~0,8!] Scan [6/15] CDrive: !RS_CDRIVE! >> "!CLOG!"

REM === 7. REGISTRY HIVES ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![ 7/15]!R! Registry hives................. "
set RS_REG=0
echo --- REGISTRY HIVES --- >> "!SCANFILE!"
for %%k in (
    "HKLM\SOFTWARE\Autodesk"
    "HKCU\SOFTWARE\Autodesk"
    "HKCU\SOFTWARE\SOFTWARE\Autodesk"
    "HKLM\SOFTWARE\WOW6432Node\Autodesk"
    "HKLM\SOFTWARE\FLEXlm License Manager"
    "HKCU\SOFTWARE\FLEXlm License Manager"
    "HKLM\SOFTWARE\WOW6432Node\FLEXlm License Manager"
    "HKLM\SOFTWARE\Macrovision"
) do (
    reg query %%k >nul 2>&1
    if !errorlevel! equ 0 (
        set /a RS_REG+=1
        <nul set /p "=!ESC![50G!DIM!scanning: !RS_REG!  !R!"
        echo  EXISTS: %%~k >> "!SCANFILE!"
    )
)
echo. >> "!SCANFILE!"
if !RS_REG! gtr 0 (
    echo !ESC![50G!CRED!!RS_REG! found                    !R!
)
if !RS_REG! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
)
echo [!time:~0,8!] Scan [7/15] Registry: !RS_REG! >> "!CLOG!"

REM === 8. REGISTRY DEEP SCAN - COM ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![ 8/15]!R! Registry deep scan - COM....... "
set RS_COM=0
echo --- REGISTRY DEEP SCAN --- >> "!SCANFILE!"
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Classes\CLSID" /s /d /f "Autodesk" 2^>nul ^| findstr /i "HKEY_"') do (
    set /a RS_COM+=1
    <nul set /p "=!ESC![50G!DIM!scanning: !RS_COM!  !R!"
    echo  COM-CLSID: %%k >> "!SCANFILE!"
)
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Classes\TypeLib" /s /d /f "Autodesk" 2^>nul ^| findstr /i "HKEY_"') do (
    set /a RS_COM+=1
    <nul set /p "=!ESC![50G!DIM!scanning: !RS_COM!  !R!"
    echo  COM-TYPELIB: %%k >> "!SCANFILE!"
)
if !RS_COM! gtr 0 (
    echo !ESC![50G!CRED!!RS_COM! found                    !R!
)
if !RS_COM! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
)
echo [!time:~0,8!] Scan [8/15] COM: !RS_COM! >> "!CLOG!"

REM === 9. REGISTRY DEEP SCAN - CLASSES ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![ 9/15]!R! Registry deep scan - classes... "
set RS_CLASS=0
echo --- AUTODESK-SPECIFIC CLASS KEYS --- >> "!SCANFILE!"
for /f "tokens=*" %%k in ('reg query "HKCU\SOFTWARE\Classes" /f "DWGTrueView" /k 2^>nul ^| findstr /i "HKEY_"') do (
    set /a RS_CLASS+=1
    <nul set /p "=!ESC![50G!DIM!scanning: !RS_CLASS!  !R!"
    echo  ADSK-CLASS: %%k >> "!SCANFILE!"
)
for /f "tokens=*" %%k in ('reg query "HKCU\SOFTWARE\Classes" /f "AutoCAD" /k 2^>nul ^| findstr /i "HKEY_"') do (
    set /a RS_CLASS+=1
    <nul set /p "=!ESC![50G!DIM!scanning: !RS_CLASS!  !R!"
    echo  ADSK-CLASS: %%k >> "!SCANFILE!"
)
for %%n in (!CLASS_KEYS! dwgviewr) do (
    reg query "HKCU\SOFTWARE\Classes\%%n" >nul 2>&1
    if !errorlevel! equ 0 (
        set /a RS_CLASS+=1
        <nul set /p "=!ESC![50G!DIM!scanning: !RS_CLASS!  !R!"
        echo  ADSK-CLASS: HKCU\SOFTWARE\Classes\%%n >> "!SCANFILE!"
    )
)
reg query "HKCU\SOFTWARE\Classes\.dgn" >nul 2>&1
if !errorlevel! equ 0 (
    set /a RS_CLASS+=1
    echo  ADSK-CLASS: HKCU\SOFTWARE\Classes\.dgn >> "!SCANFILE!"
)
echo. >> "!SCANFILE!"
echo ================================================ >> "!SCANFILE!"
echo  *** SAFE TO IGNORE - NOT Autodesk keys *** >> "!SCANFILE!"
echo  These are generic Windows file types whose >> "!SCANFILE!"
echo  DefaultIcon points to a deleted Autodesk exe. >> "!SCANFILE!"
echo  Windows shows a generic icon. Completely harmless. >> "!SCANFILE!"
echo  Do NOT delete - they may be used by other apps. >> "!SCANFILE!"
echo ================================================ >> "!SCANFILE!"
set RS_GENERIC=0
for /f "tokens=*" %%k in ('reg query "HKCU\SOFTWARE\Classes" /f "Autodesk" /d /s 2^>nul ^| findstr /i "HKEY_"') do (
    echo "%%k" | findstr /i "DWGTrueView AutoCAD AutodeskDGN AutoLISP 3dsFile dwgviewr cdc_auto CompleteR16 CLSID acadlt adsk.idmgr adskidmgr" >nul 2>&1
    if !errorlevel! neq 0 (
        set /a RS_GENERIC+=1
        echo  GENERIC-ICON: %%k >> "!SCANFILE!"
    )
)
if !RS_CLASS! gtr 0 (
    echo !ESC![50G!CRED!!RS_CLASS! found                    !R!
)
if !RS_CLASS! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
)
echo [!time:~0,8!] Scan [9/15] Classes: !RS_CLASS! >> "!CLOG!"

REM === 10. SHELL EXTENSIONS + UNINSTALL REG ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![10/15]!R! Shell extensions + uninstall... "
set RS_SHELL=0
echo --- SHELL EXTENSIONS + UNINSTALL REG --- >> "!SCANFILE!"
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Approved" /s /f "Autodesk" /d 2^>nul ^| findstr /i "Autodesk"') do (
    set /a RS_SHELL+=1
    <nul set /p "=!ESC![50G!DIM!scanning: !RS_SHELL!  !R!"
    echo  SHELL-EXT: %%k >> "!SCANFILE!"
)
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s /v "Publisher" 2^>nul ^| findstr /i "Autodesk"') do (
    set /a RS_SHELL+=1
    <nul set /p "=!ESC![50G!DIM!scanning: !RS_SHELL!  !R!"
    echo  UNINSTALL-REG: %%k >> "!SCANFILE!"
)
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" /s /v "Publisher" 2^>nul ^| findstr /i "Autodesk"') do (
    set /a RS_SHELL+=1
    <nul set /p "=!ESC![50G!DIM!scanning: !RS_SHELL!  !R!"
    echo  UNINSTALL-REG-32: %%k >> "!SCANFILE!"
)
echo. >> "!SCANFILE!"
if !RS_SHELL! gtr 0 (
    echo !ESC![50G!CRED!!RS_SHELL! found                    !R!
)
if !RS_SHELL! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
)
echo [!time:~0,8!] Scan [10/15] Shell: !RS_SHELL! >> "!CLOG!"

REM === 11. INSTALLER\PRODUCTS GHOSTS ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![11/15]!R! Installer\Products ghosts..... "
set RS_IP=0
echo --- INSTALLER PRODUCTS --- >> "!SCANFILE!"
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Classes\Installer\Products" /s /v "ProductName" 2^>nul ^| findstr /i "HKEY_"') do (
    set "IP_MATCH=0"
    for /f "tokens=2,*" %%a in ('reg query "%%k" /v "ProductName" 2^>nul ^| findstr /i "ProductName"') do (
        echo "%%b" | findstr /i "Autodesk" >nul 2>&1
        if !errorlevel! equ 0 set "IP_MATCH=1"
    )
    if !IP_MATCH! equ 1 (
        set /a RS_IP+=1
        echo  INSTALLER-PRODUCT: %%k >> "!SCANFILE!"
    )
)
echo. >> "!SCANFILE!"
if !RS_IP! gtr 0 (
    echo !ESC![50G!CYLW!!RS_IP! ghost entries              !R!
)
if !RS_IP! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
)
echo [!time:~0,8!] Scan [11/15] InstallerProducts: !RS_IP! >> "!CLOG!"

REM === 12. SHORTCUTS, TASKS, ENV VARS ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![12/15]!R! Shortcuts, tasks, env vars.... "
set RS_OTHER=0
echo --- SYSTEM PROFILE --- >> "!SCANFILE!"
if exist "C:\Windows\System32\config\systemprofile\AppData\Local\Autodesk" (
    set /a RS_OTHER+=1
    echo  EXISTS: systemprofile\AppData\Local\Autodesk >> "!SCANFILE!"
    dir /s /b "C:\Windows\System32\config\systemprofile\AppData\Local\Autodesk" >> "!SCANFILE!" 2>nul
)
echo. >> "!SCANFILE!"

echo --- SCHEDULED TASKS --- >> "!SCANFILE!"
for /f "tokens=*" %%t in ('schtasks /query /fo csv /nh 2^>nul ^| findstr /i "Autodesk"') do (
    set /a RS_OTHER+=1
    echo  TASK: %%t >> "!SCANFILE!"
)
echo. >> "!SCANFILE!"

echo --- DESKTOP SHORTCUTS --- >> "!SCANFILE!"
for %%L in ("%USERPROFILE%\Desktop" "C:\Users\Public\Desktop") do (
    if exist "%%~L" (
        for %%f in ("%%~L\*.lnk") do (
            echo "%%~nf" | findstr /i /c:"Autodesk" /c:"AutoCAD" /c:"Revit" /c:"Inventor" /c:"DWG" /c:"Design Review" /c:"3ds Max" /c:"3dsMax" /c:"Maya" /c:"Navisworks" >nul 2>&1
            if !errorlevel! equ 0 (
                set /a RS_OTHER+=1
                echo  SHORTCUT: %%f >> "!SCANFILE!"
            )
        )
    )
)
echo. >> "!SCANFILE!"

echo --- START MENU --- >> "!SCANFILE!"
if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Autodesk" (
    set /a RS_OTHER+=1
    echo  EXISTS: User Start Menu\Autodesk >> "!SCANFILE!"
)
if exist "%ProgramData%\Microsoft\Windows\Start Menu\Programs\Autodesk" (
    set /a RS_OTHER+=1
    echo  EXISTS: All Users Start Menu\Autodesk >> "!SCANFILE!"
)
echo. >> "!SCANFILE!"

echo --- ENV VARIABLES --- >> "!SCANFILE!"
for %%v in (ADSKFLEX_LICENSE_FILE ADSK_LICENSE_FILE AUTODESK_LICENSE_FILE FLEXLM_TIMEOUT) do (
    reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v "%%v" >nul 2>&1
    if !errorlevel! equ 0 (
        set /a RS_OTHER+=1
        echo  SET: %%v >> "!SCANFILE!"
    )
    reg query "HKCU\Environment" /v "%%v" >nul 2>&1
    if !errorlevel! equ 0 (
        set /a RS_OTHER+=1
        echo  SET-USER: %%v >> "!SCANFILE!"
    )
)
echo. >> "!SCANFILE!"
if !RS_OTHER! gtr 0 (
    echo !ESC![50G!CRED!!RS_OTHER! found                    !R!
)
if !RS_OTHER! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
)
echo [!time:~0,8!] Scan [12/15] Other: !RS_OTHER! >> "!CLOG!"

REM === 12. IFEO DEBUGGER BLOCKS ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![13/15]!R! IFEO debugger blocks.......... "
set RS_IFEO=0
set "IFEO_ROOT=HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"
for %%x in (!IFEO_EXES!) do (
    reg query "!IFEO_ROOT!\%%x" /v Debugger >nul 2>&1
    if !errorlevel! equ 0 (
        set /a RS_IFEO+=1
        echo  IFEO-BLOCKED: %%x >> "!SCANFILE!"
    )
)
echo --- IFEO DEBUGGER BLOCKS --- >> "!SCANFILE!"
if !RS_IFEO! gtr 0 (
    echo !ESC![50G!CRED!!RS_IFEO! blocked                   !R!
)
if !RS_IFEO! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
)
echo [!time:~0,8!] Scan [13/15] IFEO: !RS_IFEO! >> "!CLOG!"

REM === 13. PENDING FILE RENAME OPERATIONS ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![14/15]!R! PendingFileRenameOps......... "
set RS_PFRO=0
echo --- PENDING FILE RENAME OPERATIONS --- >> "!SCANFILE!"
for /f "tokens=*" %%v in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v PendingFileRenameOperations 2^>nul ^| findstr /i "Autodesk"') do (
    set /a RS_PFRO+=1
    echo  PFRO: %%v >> "!SCANFILE!"
)
if !RS_PFRO! gtr 0 (
    echo !ESC![50G!CYLW!!RS_PFRO! Autodesk entries          !R!
)
if !RS_PFRO! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
)
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" >nul 2>&1
if !errorlevel! equ 0 (
    set /a RS_PFRO+=1
    echo  REBOOT-FLAG: WindowsUpdate RebootRequired >> "!SCANFILE!"
)
reg query "HKLM\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\RebootRequired" >nul 2>&1
if !errorlevel! equ 0 (
    set /a RS_PFRO+=1
    echo  REBOOT-FLAG: Orchestrator RebootRequired >> "!SCANFILE!"
)
echo [!time:~0,8!] Scan [14/15] PFRO: !RS_PFRO! >> "!CLOG!"

REM === 14. HOSTS FILE ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![15/15]!R! Hosts file................... "
set RS_HOSTS=0
echo --- HOSTS FILE --- >> "!SCANFILE!"
if exist "%WINDIR%\System32\drivers\etc\hosts" (
    for /f "tokens=*" %%h in ('findstr /i /v "^#" "%WINDIR%\System32\drivers\etc\hosts" 2^>nul ^| findstr /i "autodesk"') do (
        set /a RS_HOSTS+=1
        echo  HOSTS: %%h >> "!SCANFILE!"
    )
)
if !RS_HOSTS! gtr 0 (
    echo !ESC![50G!CYLW!!RS_HOSTS! Autodesk entries          !R!
)
if !RS_HOSTS! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
)
echo [!time:~0,8!] Scan [15/15] Hosts: !RS_HOSTS! >> "!CLOG!"

REM === SUMMARY TABLE ===
set /a RS_TOTAL=RS_PROD+RS_PROC+RS_SVC+RS_PF+RS_DATA+RS_CDRIVE+RS_REG+RS_COM+RS_CLASS+RS_SHELL+RS_IP+RS_OTHER+RS_IFEO+RS_PFRO+RS_HOSTS
echo.
echo  ============================================================
echo   !CWHT!!BOLD!REMNANT SCAN COMPLETE - Summary!R!
echo  ============================================================
echo.
echo   !CWHT!Category                          Found!R!
echo   !DIM!--------------------------------  --------!R!

if !RS_PROD! gtr 0 ( <nul set /p "=  Registered products              !CRED!!RS_PROD!!R!" )
if !RS_PROD! equ 0 ( <nul set /p "=  Registered products              !CGRN!0!R!" )
echo.
if !RS_PROC! gtr 0 ( <nul set /p "=  Running processes                !CRED!!RS_PROC!!R!" )
if !RS_PROC! equ 0 ( <nul set /p "=  Running processes                !CGRN!0!R!" )
echo.
if !RS_SVC! gtr 0 ( <nul set /p "=  Services                         !CRED!!RS_SVC!!R!" )
if !RS_SVC! equ 0 ( <nul set /p "=  Services                         !CGRN!0!R!" )
echo.
if !RS_PF! gtr 0 ( <nul set /p "=  Program Files folders             !CRED!!RS_PF!!R!" )
if !RS_PF! equ 0 ( <nul set /p "=  Program Files folders             !CGRN!0!R!" )
echo.
if !RS_DATA! gtr 0 ( <nul set /p "=  Data folders                     !CRED!!RS_DATA!!R!" )
if !RS_DATA! equ 0 ( <nul set /p "=  Data folders                     !CGRN!0!R!" )
echo.
if !RS_CDRIVE! gtr 0 ( <nul set /p "=  C: drive Autodesk folders        !CRED!!RS_CDRIVE!!R!" )
if !RS_CDRIVE! equ 0 ( <nul set /p "=  C: drive Autodesk folders        !CGRN!0!R!" )
echo.
if !RS_REG! gtr 0 ( <nul set /p "=  Registry hives                   !CRED!!RS_REG!!R!" )
if !RS_REG! equ 0 ( <nul set /p "=  Registry hives                   !CGRN!0!R!" )
echo.
if !RS_COM! gtr 0 ( <nul set /p "=  COM objects ^(CLSID + TypeLib^)    !CRED!!RS_COM!!R!" )
if !RS_COM! equ 0 ( <nul set /p "=  COM objects ^(CLSID + TypeLib^)    !CGRN!0!R!" )
echo.
if !RS_CLASS! gtr 0 ( <nul set /p "=  File association class keys      !CRED!!RS_CLASS!!R!" )
if !RS_CLASS! equ 0 ( <nul set /p "=  File association class keys      !CGRN!0!R!" )
echo.
if !RS_SHELL! gtr 0 ( <nul set /p "=  Shell extensions + uninstall reg !CRED!!RS_SHELL!!R!" )
if !RS_SHELL! equ 0 ( <nul set /p "=  Shell extensions + uninstall reg !CGRN!0!R!" )
echo.
if !RS_IP! gtr 0 ( <nul set /p "=  Installer\Products ghosts        !CRED!!RS_IP!!R!" )
if !RS_IP! equ 0 ( <nul set /p "=  Installer\Products ghosts        !CGRN!0!R!" )
echo.
if !RS_OTHER! gtr 0 ( <nul set /p "=  Shortcuts, tasks, env vars       !CRED!!RS_OTHER!!R!" )
if !RS_OTHER! equ 0 ( <nul set /p "=  Shortcuts, tasks, env vars       !CGRN!0!R!" )
echo.
if !RS_IFEO! gtr 0 ( <nul set /p "=  IFEO debugger blocks           !CRED!!RS_IFEO!!R!" )
if !RS_IFEO! equ 0 ( <nul set /p "=  IFEO debugger blocks           !CGRN!0!R!" )
echo.
if !RS_PFRO! gtr 0 ( <nul set /p "=  PendingFileRename entries      !CYLW!!RS_PFRO!!R!" )
if !RS_PFRO! equ 0 ( <nul set /p "=  PendingFileRename entries      !CGRN!0!R!" )
echo.
if !RS_HOSTS! gtr 0 ( <nul set /p "=  Hosts file entries             !CYLW!!RS_HOSTS!!R!" )
if !RS_HOSTS! equ 0 ( <nul set /p "=  Hosts file entries             !CGRN!0!R!" )
echo.
echo   !DIM!--------------------------------  --------!R!
if !RS_TOTAL! gtr 0 ( <nul set /p "=  !CWHT!!BOLD!TOTAL                             !CRED!!BOLD!!RS_TOTAL!!R!" )
if !RS_TOTAL! equ 0 ( <nul set /p "=  !CWHT!!BOLD!TOTAL                             !CGRN!!BOLD!0!R!" )
echo.
if !RS_GENERIC! gtr 0 (
    echo.
    echo   !DIM!+ !RS_GENERIC! GENERIC-ICON entries ^(informational only, not counted^)!R!
)
if !RS_RECYCLE! gtr 0 (
    echo   !DIM!+ !RS_RECYCLE! Recycle Bin folders ^(informational only, not counted or deleted^)!R!
    echo [!time:~0,8!] Scan: !RS_RECYCLE! Recycle Bin folders ^(informational^) >> "!CLOG!"
)
echo.
echo [!time:~0,8!] Remnant scan total: !RS_TOTAL! >> "!CLOG!"
echo  !CWHT!Full details saved to:!R!
echo  !DIM!!SCANFILE!!R!
echo.
echo  !CYLW!NOTE:!R! GENERIC-ICON entries in the log are !CWHT!NOT!R! Autodesk keys.
echo  !DIM!They are standard Windows file types whose icon path points!R!
echo  !DIM!to a deleted Autodesk exe. Completely harmless. Do NOT delete.!R!
echo  ============================================================
echo.
echo. >> "!CLOG!"
echo --- End of section --- >> "!CLOG!"
echo. >> "!CLOG!"
pause
goto :main_menu

REM ============================================================
REM FULL SYSTEM AUDIT - Preview everything that will be removed
REM ============================================================
:full_audit
cls
echo.
echo  !CCYN!============================================================!R!
echo  !CCYN!  !BOLD!!CWHT!  FULL SYSTEM AUDIT - Autodesk Footprint Analysis    !R!
echo  !CCYN!  !DIM!  Shows EVERYTHING that would be removed by a Full Clean !R!
echo  !CCYN!  !DIM!  Read-only - no changes are made to your system         !R!
echo  !CCYN!============================================================!R!
echo.
set "AUDITFILE=!LOGDIR!\system_audit.txt"
echo. >> "!CLOG!"
echo ======================================================== >> "!CLOG!"
echo  FULL SYSTEM AUDIT >> "!CLOG!"
echo ======================================================== >> "!CLOG!"
echo ============================================================ > "!AUDITFILE!"
echo  AUTODESK SYSTEM AUDIT - %date% %time% >> "!AUDITFILE!"
echo  Computer: %COMPUTERNAME%  User: %USERNAME% >> "!AUDITFILE!"
echo  This is a READ-ONLY scan. Nothing was modified. >> "!AUDITFILE!"
echo ============================================================ >> "!AUDITFILE!"
echo. >> "!AUDITFILE!"
set AUDIT_TOTAL=0
echo  !DIM!This scan checks 16 categories and may take 1-2 minutes.!R!
echo  !DIM!A live counter shows progress for each step.!R!
echo  !DIM!Please wait...!R!
echo.

REM === 1. INSTALLED PRODUCTS ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![ 1/17]!R! Installed products............... "
set AU_PROD=0
echo ------------------------------------------------------------ >> "!AUDITFILE!"
echo  1. INSTALLED AUTODESK PRODUCTS >> "!AUDITFILE!"
echo ------------------------------------------------------------ >> "!AUDITFILE!"
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s /v "DisplayName" 2^>nul ^| findstr /i "HKEY_"') do (
    set "AU_PUB="
    for /f "tokens=2,*" %%a in ('reg query "%%k" /v "Publisher" 2^>nul ^| findstr /i "Publisher"') do set "AU_PUB=%%b"
    if defined AU_PUB (
        echo "!AU_PUB!" | findstr /i "Autodesk" >nul 2>&1
        if !errorlevel! equ 0 (
            set /a AU_PROD+=1
            <nul set /p "=!ESC![50G!DIM!scanning: !AU_PROD!  !R!"
            for /f "tokens=2,*" %%a in ('reg query "%%k" /v "DisplayName" 2^>nul ^| findstr /i "DisplayName"') do echo   [!AU_PROD!] %%b >> "!AUDITFILE!"
            for /f "tokens=2,*" %%a in ('reg query "%%k" /v "UninstallString" 2^>nul ^| findstr /i "UninstallString"') do echo        Uninstall: %%b >> "!AUDITFILE!"
        )
    )
)
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" /s /v "DisplayName" 2^>nul ^| findstr /i "HKEY_"') do (
    set "AU_PUB="
    for /f "tokens=2,*" %%a in ('reg query "%%k" /v "Publisher" 2^>nul ^| findstr /i "Publisher"') do set "AU_PUB=%%b"
    if defined AU_PUB (
        echo "!AU_PUB!" | findstr /i "Autodesk" >nul 2>&1
        if !errorlevel! equ 0 (
            set /a AU_PROD+=1
            <nul set /p "=!ESC![50G!DIM!scanning: !AU_PROD!  !R!"
            for /f "tokens=2,*" %%a in ('reg query "%%k" /v "DisplayName" 2^>nul ^| findstr /i "DisplayName"') do echo   [!AU_PROD!] %%b ^(32-bit^) >> "!AUDITFILE!"
        )
    )
)
set /a AUDIT_TOTAL+=AU_PROD
echo [!time:~0,8!] Audit [1/17] Products: !AU_PROD! >> "!CLOG!"
if !AU_PROD! gtr 0 (
    echo !ESC![50G!CRED!!AU_PROD! found                    !R!
    echo  TOTAL: !AU_PROD! products >> "!AUDITFILE!"
)
if !AU_PROD! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
    echo  None found. >> "!AUDITFILE!"
)
echo. >> "!AUDITFILE!"

REM === 2. RUNNING PROCESSES ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![ 2/17]!R! Running processes................ "
set AU_PROC=0
echo ------------------------------------------------------------ >> "!AUDITFILE!"
echo  2. RUNNING AUTODESK PROCESSES >> "!AUDITFILE!"
echo ------------------------------------------------------------ >> "!AUDITFILE!"
set "PROC_TMP=!LOGDIR!\proc_check.tmp"
type nul > "!PROC_TMP!"
start "" /b cmd /c "tasklist /nh > "!PROC_TMP!" 2>nul"
ping -n 6 127.0.0.1 >nul 2>&1
taskkill /f /im tasklist.exe >nul 2>&1
for %%p in (!KILL_PROCS_SCAN!) do (
    findstr /i "%%p" "!PROC_TMP!" >nul 2>&1
    if !errorlevel! equ 0 (
        set /a AU_PROC+=1
        <nul set /p "=!ESC![50G!DIM!scanning: !AU_PROC!  !R!"
        echo   %%p >> "!AUDITFILE!"
    )
)
del "!PROC_TMP!" >nul 2>&1
set /a AUDIT_TOTAL+=AU_PROC
echo [!time:~0,8!] Audit [2/17] Processes: !AU_PROC! >> "!CLOG!"
if !AU_PROC! gtr 0 (
    echo !ESC![50G!CRED!!AU_PROC! found                    !R!
    echo  TOTAL: !AU_PROC! processes >> "!AUDITFILE!"
)
if !AU_PROC! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
    echo  None running. >> "!AUDITFILE!"
)
echo. >> "!AUDITFILE!"

REM === 3. SERVICES ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![ 3/17]!R! Services......................... "
set AU_SVC=0
echo ------------------------------------------------------------ >> "!AUDITFILE!"
echo  3. AUTODESK SERVICES >> "!AUDITFILE!"
echo ------------------------------------------------------------ >> "!AUDITFILE!"
for %%s in (AdskLicensingService AdskAccessServiceHost AdAppMgrSvc AdskNLM DesktopConnectorService "FlexNet Licensing Service 64" "Autodesk Genuine Service") do (
    sc query %%s >nul 2>&1
    if !errorlevel! equ 0 (
        set /a AU_SVC+=1
        for /f "tokens=3,4" %%a in ('sc query %%s 2^>nul ^| findstr /i "STATE"') do echo   %%s  [%%a %%b] >> "!AUDITFILE!"
    )
)
set /a AUDIT_TOTAL+=AU_SVC
echo [!time:~0,8!] Audit [3/17] Services: !AU_SVC! >> "!CLOG!"
if !AU_SVC! gtr 0 (
    echo !ESC![50G!CRED!!AU_SVC! found                    !R!
    echo  TOTAL: !AU_SVC! services >> "!AUDITFILE!"
)
if !AU_SVC! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
    echo  None found. >> "!AUDITFILE!"
)
echo. >> "!AUDITFILE!"

REM === 4. FOLDERS WITH FILE COUNTS ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![ 4/17]!R! Folders and files................ "
set AU_FOLD=0
set AU_FILES=0
set "AU_SIZE_PATHS="
echo ------------------------------------------------------------ >> "!AUDITFILE!"
echo  4. AUTODESK FOLDERS AND FILES >> "!AUDITFILE!"
echo ------------------------------------------------------------ >> "!AUDITFILE!"
for %%d in (
    "C:\Program Files\Autodesk"
    "C:\Program Files\Common Files\Autodesk Shared"
    "C:\Program Files\Common Files\Autodesk"
    "C:\Program Files (x86)\Autodesk"
    "C:\Program Files (x86)\Common Files\Autodesk Shared"
    "C:\Program Files (x86)\Common Files\Autodesk"
    "C:\ProgramData\Autodesk"
    "C:\Users\Public\Documents\Autodesk"
    "C:\Autodesk"
    "C:\Program Files\Common Files\Macrovision Shared"
    "%APPDATA%\Autodesk"
    "%LOCALAPPDATA%\Autodesk"
    "%LOCALAPPDATA%\Programs\Autodesk"
    "%LOCALAPPDATA%\Temp\odis_download_dest"
    "C:\Windows\System32\config\systemprofile\AppData\Local\Autodesk"
) do (
    if exist "%%~d" (
        set /a AU_FOLD+=1
        <nul set /p "=!ESC![50G!DIM!scanning: !AU_FOLD!  !R!"
        set FC=0
        set "FSIZE_LINE="
        for /f %%n in ('dir /s /b "%%~d" 2^>nul ^| find /c /v ""') do set FC=%%n
        for /f "tokens=3,4" %%a in ('dir /s /-c "%%~d" 2^>nul ^| findstr /c:"File(s)"') do set "FSIZE_LINE=%%a bytes"
        set /a AU_FILES+=FC
        echo   EXISTS: %%~d  [!FC! files, !FSIZE_LINE!] >> "!AUDITFILE!"
        set "AU_SIZE_PATHS=!AU_SIZE_PATHS!'%%~d',"
    )
)
REM Calculate total disk space using PowerShell (handles large numbers)
set "AU_TOTAL_SIZE=calculating..."
if !AU_FOLD! gtr 0 (
    for /f "tokens=*" %%s in ('powershell -NoProfile -Command "$p=@(!AU_SIZE_PATHS!$null); $t=0; foreach($d in $p){if($d -and (Test-Path $d)){try{$t+=(Get-ChildItem $d -Recurse -Force -ErrorAction SilentlyContinue|Measure-Object Length -Sum).Sum}catch{}}}; if($t -gt 1073741824){'{0:N2} GB' -f ($t/1GB)}elseif($t -gt 1048576){'{0:N0} MB' -f ($t/1MB)}else{'{0:N0} KB' -f ($t/1KB)}" 2^>nul') do set "AU_TOTAL_SIZE=%%s"
)
set /a AUDIT_TOTAL+=AU_FOLD
echo [!time:~0,8!] Audit [4/17] Folders: !AU_FOLD! >> "!CLOG!"
if !AU_FOLD! gtr 0 (
    echo !ESC![50G!CRED!!AU_FOLD! folders, !AU_FILES! files       !R!
)
if !AU_FOLD! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
    echo  None found. >> "!AUDITFILE!"
)
echo. >> "!AUDITFILE!"

REM --- Desktop Connector workspace (opt-in removal only - user project data) ---
set AU_DTC=0
for %%d in ("%USERPROFILE%\DC" "%USERPROFILE%\ACCDocs") do (
    if exist "%%~d\" (
        set /a AU_DTC+=1
        set DTC_FC=0
        for /f %%n in ('dir /s /b "%%~d" 2^>nul ^| find /c /v ""') do set DTC_FC=%%n
        echo  OPT-IN: %%~d  [!DTC_FC! files] - Desktop Connector workspace >> "!AUDITFILE!"
        echo          User project data - removed ONLY if you opt in during cleanup. >> "!AUDITFILE!"
    )
)
if !AU_DTC! gtr 0 (
    echo  !CYLW!Desktop Connector workspace present - opt-in removal only ^(see report^)!R!
)
echo [!time:~0,8!] Audit: DTC workspace folders: !AU_DTC! >> "!CLOG!"

REM === 5. C: DRIVE SEARCH ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![ 5/17]!R! Other Autodesk folders on C:..... "
set AU_OTHER=0
set AU_INSTALLER=0
echo ------------------------------------------------------------ >> "!AUDITFILE!"
echo  5. OTHER AUTODESK FOLDERS ON C: DRIVE >> "!AUDITFILE!"
echo ------------------------------------------------------------ >> "!AUDITFILE!"
echo  5a. Product remnants: >> "!AUDITFILE!"
for /f "tokens=*" %%p in ('dir /s /b /ad "C:\*Autodesk*" 2^>nul ^| findstr /v /i "Desktop\\Autodesk_Uninstaller"') do (
    set "AU_IS_INSTALLER=0"
    echo "%%p" | findstr /i /c:"\Downloads\" >nul 2>&1
    if !errorlevel! equ 0 set "AU_IS_INSTALLER=1"
    echo "%%p" | findstr /i /c:"\Google\Chrome\" >nul 2>&1
    if !errorlevel! equ 0 set "AU_IS_INSTALLER=1"
    echo "%%p" | findstr /i /c:"\Edge\User Data\" >nul 2>&1
    if !errorlevel! equ 0 set "AU_IS_INSTALLER=1"
    echo "%%p" | findstr /i /c:"\Firefox\Profiles\" >nul 2>&1
    if !errorlevel! equ 0 set "AU_IS_INSTALLER=1"
    if !AU_IS_INSTALLER! equ 0 (
        set /a AU_OTHER+=1
        <nul set /p "=!ESC![50G!DIM!scanning: !AU_OTHER!  !R!"
        echo   %%p >> "!AUDITFILE!"
    )
    if !AU_IS_INSTALLER! equ 1 (
        set /a AU_INSTALLER+=1
    )
)
if !AU_OTHER! equ 0 echo  None found. >> "!AUDITFILE!"
echo. >> "!AUDITFILE!"
REM --- 5b. Installer files (for/f with pipe must be outside if blocks) ---
set "AU_WROTE_5B=0"
set "AU_SKIP_5B=0"
if !AU_INSTALLER! equ 0 set "AU_SKIP_5B=1"
for /f "tokens=*" %%p in ('dir /s /b /ad "C:\*Autodesk*" 2^>nul ^| findstr /i /c:"\Downloads\" /c:"\Google\Chrome\" /c:"\Edge\User Data\" /c:"\Firefox\Profiles\"') do (
    if !AU_SKIP_5B! equ 0 (
        if !AU_WROTE_5B! equ 0 echo  5b. Installation files and browser cache [OPTIONAL]: >> "!AUDITFILE!"
        set "AU_WROTE_5B=1"
        echo   %%p >> "!AUDITFILE!"
    )
)
if !AU_WROTE_5B! equ 1 (
    echo  NOTE: These are downloaded installers and browser >> "!AUDITFILE!"
    echo  cache - NOT installed product files. They are only >> "!AUDITFILE!"
    echo  cleaned if you choose to include them. >> "!AUDITFILE!"
    echo. >> "!AUDITFILE!"
)
REM --- Display result (flattened: no nested ifs) ---
set "AU_STEP5_SHOWN=0"
set "AU_BOTH=0"
if !AU_OTHER! gtr 0 set "AU_BOTH=1"
if !AU_BOTH! equ 1 if !AU_INSTALLER! gtr 0 (
    echo !ESC![50G!CYLW!!AU_OTHER! remnants + !AU_INSTALLER! installer    !R!
    set "AU_STEP5_SHOWN=1"
)
if !AU_OTHER! gtr 0 if !AU_STEP5_SHOWN! equ 0 (
    echo !ESC![50G!CYLW!!AU_OTHER! found                    !R!
    set "AU_STEP5_SHOWN=1"
)
if !AU_OTHER! gtr 0 (
    echo  TOTAL: !AU_OTHER! remnant folders, !AU_INSTALLER! installer/browser folders >> "!AUDITFILE!"
)
if !AU_OTHER! equ 0 if !AU_INSTALLER! gtr 0 (
    echo !ESC![50G!CGRN!no remnants !DIM!^(!AU_INSTALLER! installer^)   !R!
    set "AU_STEP5_SHOWN=1"
)
if !AU_STEP5_SHOWN! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
    echo  None found. >> "!AUDITFILE!"
)
echo. >> "!AUDITFILE!"
echo [!time:~0,8!] Audit [5/17] CDrive: !AU_OTHER! >> "!CLOG!"

REM === 6. REGISTRY HIVES ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![ 6/17]!R! Registry hives................... "
set AU_REG=0
echo ------------------------------------------------------------ >> "!AUDITFILE!"
echo  6. AUTODESK REGISTRY HIVES >> "!AUDITFILE!"
echo ------------------------------------------------------------ >> "!AUDITFILE!"
for %%k in (
    "HKLM\SOFTWARE\Autodesk"
    "HKCU\SOFTWARE\Autodesk"
    "HKCU\SOFTWARE\SOFTWARE\Autodesk"
    "HKLM\SOFTWARE\WOW6432Node\Autodesk"
    "HKLM\SOFTWARE\FLEXlm License Manager"
    "HKCU\SOFTWARE\FLEXlm License Manager"
    "HKLM\SOFTWARE\WOW6432Node\FLEXlm License Manager"
    "HKLM\SOFTWARE\Macrovision"
) do (
    reg query %%k >nul 2>&1
    if !errorlevel! equ 0 (
        set /a AU_REG+=1
        <nul set /p "=!ESC![50G!DIM!scanning: !AU_REG!  !R!"
        set SUBKEYS=0
        for /f %%n in ('reg query %%k /s 2^>nul ^| find /c "HKEY_"') do set SUBKEYS=%%n
        echo   EXISTS: %%~k  [!SUBKEYS! subkeys] >> "!AUDITFILE!"
    )
)
set /a AUDIT_TOTAL+=AU_REG
echo [!time:~0,8!] Audit [6/17] Registry: !AU_REG! >> "!CLOG!"
if !AU_REG! gtr 0 (
    echo !ESC![50G!CRED!!AU_REG! hives                    !R!
)
if !AU_REG! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
    echo  None found. >> "!AUDITFILE!"
)
echo. >> "!AUDITFILE!"

REM === 7. USER FILE ASSOCIATIONS ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![ 7/17]!R! User file associations........... "
set AU_ASSOC=0
echo ------------------------------------------------------------ >> "!AUDITFILE!"
echo  7. USER FILE ASSOCIATIONS (HKCU\Classes) >> "!AUDITFILE!"
echo ------------------------------------------------------------ >> "!AUDITFILE!"
for /f "tokens=*" %%k in ('reg query "HKCU\SOFTWARE\Classes" /f "DWGTrueView" /k 2^>nul ^| findstr /i "HKEY_"') do (
    set /a AU_ASSOC+=1
    <nul set /p "=!ESC![50G!DIM!scanning: !AU_ASSOC!  !R!"
    echo   %%k >> "!AUDITFILE!"
)
for /f "tokens=*" %%k in ('reg query "HKCU\SOFTWARE\Classes" /f "AutoCAD" /k 2^>nul ^| findstr /i "HKEY_"') do (
    set /a AU_ASSOC+=1
    <nul set /p "=!ESC![50G!DIM!scanning: !AU_ASSOC!  !R!"
    echo   %%k >> "!AUDITFILE!"
)
for %%n in (!CLASS_KEYS! .dgn) do (
    reg query "HKCU\SOFTWARE\Classes\%%n" >nul 2>&1
    if !errorlevel! equ 0 (
        set /a AU_ASSOC+=1
        echo   HKCU\SOFTWARE\Classes\%%n >> "!AUDITFILE!"
    )
)
reg query "HKCU\SOFTWARE\Classes\dwgviewr.9128.409" >nul 2>&1
if !errorlevel! equ 0 (
    set /a AU_ASSOC+=1
    echo   HKCU\SOFTWARE\Classes\dwgviewr.9128.409 >> "!AUDITFILE!"
)
set /a AUDIT_TOTAL+=AU_ASSOC
echo [!time:~0,8!] Audit [7/17] Assoc: !AU_ASSOC! >> "!CLOG!"
if !AU_ASSOC! gtr 0 (
    echo !ESC![50G!CYLW!!AU_ASSOC! entries                  !R!
    echo  TOTAL: !AU_ASSOC! class entries >> "!AUDITFILE!"
)
if !AU_ASSOC! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
    echo  None found. >> "!AUDITFILE!"
)
echo. >> "!AUDITFILE!"

REM === 8. COM OBJECTS AND CLSID ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![ 8/17]!R! COM objects and CLSIDs........... "
set AU_COM=0
echo ------------------------------------------------------------ >> "!AUDITFILE!"
echo  8. COM OBJECTS AND CLSIDs >> "!AUDITFILE!"
echo ------------------------------------------------------------ >> "!AUDITFILE!"
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Classes\CLSID" /s /d /f "Autodesk" 2^>nul ^| findstr /i "HKEY_"') do (
    set /a AU_COM+=1
    <nul set /p "=!ESC![50G!DIM!scanning: !AU_COM!  !R!"
    echo   CLSID: %%k >> "!AUDITFILE!"
)
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Classes\TypeLib" /s /d /f "Autodesk" 2^>nul ^| findstr /i "HKEY_"') do (
    set /a AU_COM+=1
    <nul set /p "=!ESC![50G!DIM!scanning: !AU_COM!  !R!"
    echo   TypeLib: %%k >> "!AUDITFILE!"
)
for /f "tokens=*" %%k in ('reg query "HKCU\SOFTWARE\Classes\CLSID" /s /f "Autodesk" /d 2^>nul ^| findstr /i "HKEY_.*CLSID.*{"') do (
    set /a AU_COM+=1
    <nul set /p "=!ESC![50G!DIM!scanning: !AU_COM!  !R!"
    echo   User CLSID: %%k >> "!AUDITFILE!"
)
set /a AUDIT_TOTAL+=AU_COM
echo [!time:~0,8!] Audit [8/17] COM: !AU_COM! >> "!CLOG!"
if !AU_COM! gtr 0 (
    echo !ESC![50G!CYLW!!AU_COM! entries                  !R!
    echo  TOTAL: !AU_COM! COM entries >> "!AUDITFILE!"
)
if !AU_COM! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
    echo  None found. >> "!AUDITFILE!"
)
echo. >> "!AUDITFILE!"

REM === 9. SCHEDULED TASKS ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![ 9/17]!R! Scheduled tasks.................. "
set AU_TASK=0
echo ------------------------------------------------------------ >> "!AUDITFILE!"
echo  9. SCHEDULED TASKS >> "!AUDITFILE!"
echo ------------------------------------------------------------ >> "!AUDITFILE!"
for /f "tokens=1 delims=," %%n in ('schtasks /query /fo csv /nh 2^>nul ^| findstr /i "Autodesk"') do (
    set /a AU_TASK+=1
    echo   %%~n >> "!AUDITFILE!"
)
set /a AUDIT_TOTAL+=AU_TASK
echo [!time:~0,8!] Audit [9/17] Tasks: !AU_TASK! >> "!CLOG!"
if !AU_TASK! gtr 0 (
    echo !ESC![50G!CYLW!!AU_TASK! found                    !R!
)
if !AU_TASK! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
    echo  None found. >> "!AUDITFILE!"
)
echo. >> "!AUDITFILE!"

REM === 10. FIREWALL RULES ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![10/17]!R! Firewall rules................... "
set AU_FW=0
echo ------------------------------------------------------------ >> "!AUDITFILE!"
echo  10. FIREWALL RULES >> "!AUDITFILE!"
echo ------------------------------------------------------------ >> "!AUDITFILE!"
for /f "delims=" %%r in ('powershell -NoProfile -Command "(Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'Autodesk|AutoCAD|Revit|Inventor|Civil|Maya|3ds.?Max|Navisworks' }).DisplayName" 2^>nul') do (
    set /a AU_FW+=1
    echo   %%r >> "!AUDITFILE!"
)
set /a AUDIT_TOTAL+=AU_FW
echo [!time:~0,8!] Audit [10/17] Firewall: !AU_FW! >> "!CLOG!"
if !AU_FW! gtr 0 (
    echo !ESC![50G!CYLW!!AU_FW! rules                     !R!
)
if !AU_FW! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
    echo  None found. >> "!AUDITFILE!"
)
echo. >> "!AUDITFILE!"

REM === 11. SHORTCUTS ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![11/17]!R! Shortcuts........................ "
set AU_SC=0
echo ------------------------------------------------------------ >> "!AUDITFILE!"
echo  11. SHORTCUTS (Desktop, Start Menu, Taskbar) >> "!AUDITFILE!"
echo ------------------------------------------------------------ >> "!AUDITFILE!"
for %%L in ("%USERPROFILE%\Desktop" "C:\Users\Public\Desktop") do (
    if exist "%%~L" (
        for %%f in ("%%~L\*.lnk") do (
            echo "%%~nf" | findstr /i /c:"Autodesk" /c:"AutoCAD" /c:"Revit" /c:"Inventor" /c:"DWG" /c:"Design Review" /c:"3ds Max" /c:"3dsMax" /c:"Maya" /c:"Navisworks" >nul 2>&1
            if !errorlevel! equ 0 (
                set /a AU_SC+=1
                echo   Desktop: %%~nf >> "!AUDITFILE!"
            )
        )
    )
)
if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Autodesk" (
    set /a AU_SC+=1
    echo   Start Menu: User\Autodesk folder >> "!AUDITFILE!"
)
if exist "%ProgramData%\Microsoft\Windows\Start Menu\Programs\Autodesk" (
    set /a AU_SC+=1
    echo   Start Menu: All Users\Autodesk folder >> "!AUDITFILE!"
)
for %%T in ("%APPDATA%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar") do (
    if exist "%%~T" (
        for %%f in ("%%~T\*.lnk") do (
            echo "%%~nf" | findstr /i /c:"Autodesk" /c:"AutoCAD" /c:"Revit" /c:"Inventor" /c:"DWG" /c:"3ds Max" /c:"3dsMax" >nul 2>&1
            if !errorlevel! equ 0 (
                set /a AU_SC+=1
                echo   Taskbar: %%~nf >> "!AUDITFILE!"
            )
        )
    )
)
set /a AUDIT_TOTAL+=AU_SC
echo [!time:~0,8!] Audit [11/17] Shortcuts: !AU_SC! >> "!CLOG!"
if !AU_SC! gtr 0 (
    echo !ESC![50G!CYLW!!AU_SC! found                    !R!
)
if !AU_SC! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
    echo  None found. >> "!AUDITFILE!"
)
echo. >> "!AUDITFILE!"

REM === 12. ENVIRONMENT VARIABLES ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![12/17]!R! Environment variables............ "
set AU_ENV=0
echo ------------------------------------------------------------ >> "!AUDITFILE!"
echo  12. ENVIRONMENT VARIABLES >> "!AUDITFILE!"
echo ------------------------------------------------------------ >> "!AUDITFILE!"
for %%v in (ADSKFLEX_LICENSE_FILE ADSK_LICENSE_FILE AUTODESK_LICENSE_FILE FLEXLM_TIMEOUT) do (
    reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v "%%v" >nul 2>&1
    if !errorlevel! equ 0 (
        set /a AU_ENV+=1
        echo   %%v = SET >> "!AUDITFILE!"
    )
    reg query "HKCU\Environment" /v "%%v" >nul 2>&1
    if !errorlevel! equ 0 (
        set /a AU_ENV+=1
        echo   %%v = SET ^(user^) >> "!AUDITFILE!"
    )
)
set /a AUDIT_TOTAL+=AU_ENV
echo [!time:~0,8!] Audit [12/17] EnvVars: !AU_ENV! >> "!CLOG!"
if !AU_ENV! gtr 0 (
    echo !ESC![50G!CYLW!!AU_ENV! set                      !R!
)
if !AU_ENV! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
    echo  None found. >> "!AUDITFILE!"
)
echo. >> "!AUDITFILE!"

REM === 13. INSTALLER\PRODUCTS GHOSTS ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![13/17]!R! Installer\Products ghosts........ "
set AU_IP=0
echo ------------------------------------------------------------ >> "!AUDITFILE!"
echo  13. INSTALLER\PRODUCTS GHOSTS >> "!AUDITFILE!"
echo ------------------------------------------------------------ >> "!AUDITFILE!"
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Classes\Installer\Products" /s /v "ProductName" 2^>nul ^| findstr /i "HKEY_"') do (
    set "IP_MATCH=0"
    for /f "tokens=2,*" %%a in ('reg query "%%k" /v "ProductName" 2^>nul ^| findstr /i "ProductName"') do (
        echo "%%b" | findstr /i "Autodesk" >nul 2>&1
        if !errorlevel! equ 0 set "IP_MATCH=1"
    )
    if !IP_MATCH! equ 1 (
        set /a AU_IP+=1
        echo   %%k >> "!AUDITFILE!"
    )
)
if !AU_IP! equ 0 echo  None found. >> "!AUDITFILE!"
set /a AUDIT_TOTAL+=AU_IP
echo [!time:~0,8!] Audit [13/17] InstallerProducts: !AU_IP! >> "!CLOG!"
if !AU_IP! gtr 0 (
    echo !ESC![50G!CYLW!!AU_IP! ghost entries              !R!
)
if !AU_IP! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
)
echo. >> "!AUDITFILE!"

REM === 14. SHELL EXTENSIONS ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![14/17]!R! Shell extensions.................. "
set AU_SHELL=0
echo ------------------------------------------------------------ >> "!AUDITFILE!"
echo  14. SHELL EXTENSIONS >> "!AUDITFILE!"
echo ------------------------------------------------------------ >> "!AUDITFILE!"
for %%x in (
    "C:\Program Files\Common Files\Autodesk Shared\AcShellEx\AcShellExtension.dll"
    "C:\Program Files (x86)\Common Files\Autodesk Shared\AcShellEx\AcShellExtension.dll"
    "C:\Program Files\Common Files\Autodesk Shared\DwfShellEx\DwfShellExtension.dll"
    "C:\Program Files (x86)\Common Files\Autodesk Shared\DwfShellEx\DwfShellExtension.dll"
) do (
    if exist %%x (
        set /a AU_SHELL+=1
        echo   EXISTS: %%~x >> "!AUDITFILE!"
    )
)
for /f "tokens=1,*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Approved" /s 2^>nul ^| findstr /i "Autodesk"') do (
    set /a AU_SHELL+=1
    echo   Approved: %%b >> "!AUDITFILE!"
)
set /a AUDIT_TOTAL+=AU_SHELL
echo [!time:~0,8!] Audit [14/17] ShellExt: !AU_SHELL! >> "!CLOG!"
if !AU_SHELL! gtr 0 (
    echo !ESC![50G!CYLW!!AU_SHELL! found                    !R!
)
if !AU_SHELL! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
    echo  None found. >> "!AUDITFILE!"
)
echo. >> "!AUDITFILE!"

REM === 15. IFEO DEBUGGER BLOCKS ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![15/17]!R! IFEO debugger blocks......... "
set AU_IFEO=0
echo ------------------------------------------------------------ >> "!AUDITFILE!"
echo  15. IFEO DEBUGGER BLOCKS >> "!AUDITFILE!"
echo ------------------------------------------------------------ >> "!AUDITFILE!"
set "IFEO_ROOT=HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"
for %%x in (!IFEO_EXES!) do (
    reg query "!IFEO_ROOT!\%%x" /v Debugger >nul 2>&1
    if !errorlevel! equ 0 (
        set /a AU_IFEO+=1
        for /f "tokens=2,*" %%a in ('reg query "!IFEO_ROOT!\%%x" /v Debugger 2^>nul ^| findstr /i "Debugger"') do echo   %%x: Debugger = %%b >> "!AUDITFILE!"
    )
)
if !AU_IFEO! equ 0 echo  None found. >> "!AUDITFILE!"
if !AU_IFEO! gtr 0 (
    echo !ESC![50G!CRED!!AU_IFEO! blocked                   !R!
    set /a AUDIT_TOTAL+=AU_IFEO
)
if !AU_IFEO! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
)
echo [!time:~0,8!] Audit [15/17] IFEO: !AU_IFEO! >> "!CLOG!"

REM === 16. PENDING FILE RENAME OPERATIONS ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![16/17]!R! PendingFileRenameOps......... "
set AU_PFRO=0
echo ------------------------------------------------------------ >> "!AUDITFILE!"
echo  16. PENDING FILE RENAME OPERATIONS >> "!AUDITFILE!"
echo ------------------------------------------------------------ >> "!AUDITFILE!"
for /f "tokens=*" %%v in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v PendingFileRenameOperations 2^>nul ^| findstr /i "Autodesk"') do (
    set /a AU_PFRO+=1
    echo   %%v >> "!AUDITFILE!"
)
if !AU_PFRO! equ 0 echo  None found. >> "!AUDITFILE!"
if !AU_PFRO! gtr 0 (
    echo !ESC![50G!CYLW!!AU_PFRO! Autodesk entries          !R!
    set /a AUDIT_TOTAL+=1
)
if !AU_PFRO! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
)
echo [!time:~0,8!] Audit [16/17] PFRO >> "!CLOG!"
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" >nul 2>&1
if !errorlevel! equ 0 (
    set /a AU_PFRO+=1
    echo   RebootRequired: WindowsUpdate Auto Update >> "!AUDITFILE!"
)
reg query "HKLM\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\RebootRequired" >nul 2>&1
if !errorlevel! equ 0 (
    set /a AU_PFRO+=1
    echo   RebootRequired: WindowsUpdate Orchestrator >> "!AUDITFILE!"
)

REM === 17. HOSTS FILE ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![17/17]!R! Hosts file................... "
set AU_HOSTS=0
echo ------------------------------------------------------------ >> "!AUDITFILE!"
echo  17. HOSTS FILE >> "!AUDITFILE!"
echo ------------------------------------------------------------ >> "!AUDITFILE!"
if exist "%WINDIR%\System32\drivers\etc\hosts" (
    for /f "tokens=*" %%h in ('findstr /i /v "^#" "%WINDIR%\System32\drivers\etc\hosts" 2^>nul ^| findstr /i "autodesk"') do (
        set /a AU_HOSTS+=1
        echo   %%h >> "!AUDITFILE!"
    )
)
if !AU_HOSTS! equ 0 echo  None found. >> "!AUDITFILE!"
if !AU_HOSTS! gtr 0 (
    echo !ESC![50G!CYLW!!AU_HOSTS! entries                  !R!
    set /a AUDIT_TOTAL+=1
)
if !AU_HOSTS! equ 0 (
    echo !ESC![50G!CGRN!none                       !R!
)
echo [!time:~0,8!] Audit [17/17] Hosts >> "!CLOG!"

REM === SUMMARY ===
echo.
echo  !CCYN!============================================================!R!
echo ============================================================ >> "!AUDITFILE!"
if !AUDIT_TOTAL! equ 0 (
    echo  !CGRN!!BOLD!  SYSTEM IS CLEAN - No Autodesk footprint detected.    !R!
    echo   SYSTEM IS CLEAN - No Autodesk footprint detected. >> "!AUDITFILE!"
)
if !AUDIT_TOTAL! gtr 0 (
    echo  !CWHT!!BOLD!  TOTAL: !AUDIT_TOTAL! Autodesk items found on this system.    !R!
    echo   TOTAL: !AUDIT_TOTAL! Autodesk items found on this system. >> "!AUDITFILE!"
    if !AU_FOLD! gtr 0 (
        echo  !CYLW!!BOLD!  Disk space used: !AU_TOTAL_SIZE!                            !R!
        echo   Disk space used: !AU_TOTAL_SIZE! >> "!AUDITFILE!"
    )
    echo.
    echo  !DIM!  Use option [3] Full Uninstall + Deep Clean to remove all.!R!
    echo  !DIM!  Use option [4] Deep Clean Only for remnant-only removal. !R!
    echo   Use [3] Full Uninstall or [4] Deep Clean to remove. >> "!AUDITFILE!"
)
echo  !CCYN!============================================================!R!
echo ============================================================ >> "!AUDITFILE!"
if !AU_INSTALLER! gtr 0 (
    echo.
    echo  !CYLW!============================================================!R!
    echo  !CYLW! !BOLD!!CWHT!NOTE:!R!!CYLW! !AU_INSTALLER! Autodesk installer/download folders found.    !R!
    echo  !CYLW! These are !CWHT!installation packages!R!!CYLW!, not installed products. !R!
    echo  !CYLW! Examples: downloaded setup files, browser cache.          !R!
    echo  !CYLW! They are !CWHT!NOT!R!!CYLW! included in automatic cleanup.                !R!
    echo  !CYLW! Options [3] and [4] will ask if you want to remove them. !R!
    echo  !CYLW!============================================================!R!
)
echo.
echo [!time:~0,8!] Audit total: !AUDIT_TOTAL! >> "!CLOG!"
echo  !CWHT!Full report saved to:!R! !DIM!!AUDITFILE!!R!
echo.
echo. >> "!CLOG!"
echo --- End of section --- >> "!CLOG!"
echo. >> "!CLOG!"
pause
goto :main_menu

REM ============================================================
REM CLEAN DESKTOP CONNECTOR WORKSPACE (OPT-IN)
REM ============================================================
:dtc_workspace
cls
echo.
echo  ========================================================
echo   !CYLW!!BOLD!CLEAN DESKTOP CONNECTOR WORKSPACE!R!
echo  ========================================================
echo.
echo  Desktop Connector syncs ACC / BIM 360 project files to
echo  this PC. Its local workspace can survive uninstalls.
echo  This option removes ONLY the local workspace folders:
echo    %USERPROFILE%\DC
echo    %USERPROFILE%\ACCDocs
echo.
echo  For full Desktop Connector removal use option 3 or 4.
echo.
echo. >> "!CLOG!"
echo ======================================================== >> "!CLOG!"
echo  CLEAN DESKTOP CONNECTOR WORKSPACE >> "!CLOG!"
echo ======================================================== >> "!CLOG!"
set DTC_WS_FOUND=0
set DTC_FC=0
for %%d in ("%USERPROFILE%\DC" "%USERPROFILE%\ACCDocs") do (
    if exist "%%~d\" (
        set DTC_WS_FOUND=1
        set FC=0
        for /f %%n in ('dir /s /b "%%~d" 2^>nul ^| find /c /v ""') do set FC=%%n
        set /a DTC_FC+=FC
        echo   FOUND: %%~d  [!FC! files]
        echo   FOUND: %%~d  [!FC! files] >> "!CLOG!"
    )
)
if !DTC_WS_FOUND! equ 0 (
    echo  !CGRN!No Desktop Connector workspace found - nothing to clean.!R!
    echo [!time:~0,8!] DTC workspace: none found >> "!CLOG!"
    echo.
    pause
    goto :main_menu
)
echo.
echo  !CRED!WARNING: these folders hold your project files. Anything not!R!
echo  !CRED!fully uploaded to the Autodesk cloud is PERMANENTLY LOST.!R!
echo.
set "DTC_ANS="
set /p "DTC_ANS=  Type YES to delete !DTC_FC! files in the folders above: "
if /i not "!DTC_ANS!"=="YES" (
    echo  Aborted - nothing deleted.
    echo [!time:~0,8!] DTC workspace: aborted by user >> "!CLOG!"
    pause
    goto :main_menu
)
taskkill /f /im "DesktopConnector.Applications.Tray.exe" >nul 2>&1
taskkill /f /im "DesktopConnector.Core.Service.exe" >nul 2>&1
net stop "DesktopConnectorService" >nul 2>&1
set DTC_DEL=0
for %%d in ("%USERPROFILE%\DC" "%USERPROFILE%\ACCDocs") do (
    if exist "%%~d\" (
        <nul set /p "=  %%~nxd..."
        rd /s /q "%%~d" 2>nul
        if not exist "%%~d\" (
            echo  !CGRN!deleted.!R!
            set /a DTC_DEL+=1
        )
        if exist "%%~d\" echo  !CRED!LOCKED - close File Explorer windows and retry.!R!
    )
)
echo.
echo  !CGRN!!DTC_DEL! workspace folder^(s^) removed.!R!
echo [!time:~0,8!] DTC workspace: !DTC_DEL! folders removed >> "!CLOG!"
echo  DTC WORKSPACE: !DTC_DEL! folders removed >> "!LOGFILE!"
echo.
pause
goto :main_menu

REM ============================================================
REM FIX ERROR 103 - ODIS INSTALLER DIAGNOSTICS AND REPAIR
REM ============================================================
:fix_error103
cls
echo.
echo  !CCYN!============================================================!R!
echo  !CCYN!  !BOLD!!CWHT!  FIX ERROR 103 - ODIS INSTALLER REPAIR             !R!
echo  !CCYN!============================================================!R!
echo.
echo  !DIM!Autodesk "Error 103" occurs when ODIS installer components!R!
echo  !DIM!are corrupted, blocked, or misconfigured.!R!
echo.
echo  !CWHT!Phase 1: Diagnosis!R! - scanning for known issues...
echo.
echo. >> "!CLOG!"
echo ======================================================== >> "!CLOG!"
echo  FIX ERROR 103 >> "!CLOG!"
echo ======================================================== >> "!CLOG!"
set "E103_ISSUES=0"
set "E103_FIXES=0"
set "E103LOG=!LOGDIR!\error103_log.txt"
type nul > "!E103LOG!"
echo ERROR 103 DIAGNOSTIC LOG >> "!E103LOG!"
echo Date: %date% %time% >> "!E103LOG!"
echo ================================================ >> "!E103LOG!"

REM --- Check 1: ODIS lock file ---
set "E103_T=!time:~0,8!"
<nul set /p "=  !DIM![!E103_T!]!R! !CWHT![1/10]!R! ODIS lock file................ "
set "E103_LOCK=0"
set "E103_LOCKFILE=C:\ProgramData\Autodesk\ODIS\AdODISInstaller.run.lock"
if exist "!E103_LOCKFILE!" (
    set "E103_LOCK=1"
    set /a E103_ISSUES+=1
    echo !CRED!FOUND!R! - installer may be stuck
    echo  [1] ODIS lock file: FOUND at !E103_LOCKFILE! >> "!E103LOG!"
)
if not exist "!E103_LOCKFILE!" (
    echo !CGRN!OK!R! - no lock file
    echo  [1] ODIS lock file: CLEAN >> "!E103LOG!"
)

REM --- Check 2: Debugger keys in IFEO ---
set "E103_T=!time:~0,8!"
<nul set /p "=  !DIM![!E103_T!]!R! !CWHT![2/10]!R! Debugger keys ^(IFEO^)......... "
set "E103_IFEO=0"
set "E103_IFEO_LIST="
set "IFEO_ROOT=HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"
for %%x in (!IFEO_EXES!) do (
    reg query "!IFEO_ROOT!\%%x" /v Debugger >nul 2>&1
    if !errorlevel! equ 0 (
        set /a E103_IFEO+=1
        set "E103_IFEO_LIST=!E103_IFEO_LIST! %%x"
        echo  [2] Debugger key FOUND: %%x >> "!E103LOG!"
    )
)
if !E103_IFEO! gtr 0 (
    set /a E103_ISSUES+=1
    echo !CRED!!E103_IFEO! BLOCKED!R! -!E103_IFEO_LIST!
)
if !E103_IFEO! equ 0 (
    echo !CGRN!OK!R! - no debugger redirects
    echo  [2] Debugger keys ^(IFEO^): CLEAN >> "!E103LOG!"
)

REM --- Check 3: Autodesk Access and ODIS version ---
set "E103_T=!time:~0,8!"
<nul set /p "=  !DIM![!E103_T!]!R! !CWHT![3/10]!R! Autodesk Access version...... "
set "E103_AA_VER=NOT INSTALLED"
set "E103_ODIS_VER=NOT INSTALLED"
REM Query Autodesk Access version via PowerShell (file version)
set "E103_AA_EXE=C:\Program Files\Autodesk\AdODIS\V1\Setup\AdskAccessServiceHost.exe"
for /f "tokens=*" %%v in ('powershell -NoProfile -Command "if(Test-Path '!E103_AA_EXE!'){(Get-Item '!E103_AA_EXE!').VersionInfo.ProductVersion}" 2^>nul') do set "E103_AA_VER=%%v"
REM Query ODIS Installer version
set "E103_ODIS_EXE=C:\Program Files\Autodesk\AdODIS\V1\Installer.exe"
for /f "tokens=*" %%v in ('powershell -NoProfile -Command "if(Test-Path '!E103_ODIS_EXE!'){(Get-Item '!E103_ODIS_EXE!').VersionInfo.ProductVersion}" 2^>nul') do set "E103_ODIS_VER=%%v"
set "E103_VER_OK=1"
if "!E103_AA_VER!"=="NOT INSTALLED" set "E103_VER_OK=0"
if !E103_VER_OK! equ 1 (
    echo !CGRN!!E103_AA_VER!!R!
    echo  [3] Autodesk Access: !E103_AA_VER! >> "!E103LOG!"
)
if !E103_VER_OK! equ 0 (
    echo !CYLW!NOT INSTALLED!R!
    echo  [3] Autodesk Access: NOT INSTALLED >> "!E103LOG!"
)
echo       !DIM!ODIS Installer version....... !E103_ODIS_VER!!R!
echo  [3] ODIS Installer: !E103_ODIS_VER! >> "!E103LOG!"

REM --- Check 4: AdskAccessServiceHost service ---
set "E103_T=!time:~0,8!"
<nul set /p "=  !DIM![!E103_T!]!R! !CWHT![4/10]!R! AdskAccessServiceHost........ "
set "E103_SVC=0"
set "E103_SVC_STATE=UNKNOWN"
sc query AdskAccessServiceHost >nul 2>&1
set "E103_SC_ERR=!errorlevel!"
if !E103_SC_ERR! neq 0 (
    set "E103_SVC=2"
    echo !CYLW!NOT INSTALLED!R!
    echo  [4] AdskAccessServiceHost: NOT INSTALLED >> "!E103LOG!"
)
if !E103_SC_ERR! equ 0 (
    set "E103_SVC=1"
)
REM for/f with pipe must be outside if blocks - use flag to gate output
for /f "tokens=3" %%s in ('sc query AdskAccessServiceHost ^| findstr "STATE"') do set "E103_SVC_STATE=%%s"
if !E103_SVC! equ 1 if "!E103_SVC_STATE!"=="4" (
    set "E103_SVC=0"
    echo !CGRN!RUNNING!R!
    echo  [4] AdskAccessServiceHost: RUNNING >> "!E103LOG!"
)
if !E103_SVC! equ 1 if "!E103_SVC_STATE!" neq "4" (
    set /a E103_ISSUES+=1
    echo !CRED!STOPPED!R! - service not running
    echo  [4] AdskAccessServiceHost: STOPPED ^(state=!E103_SVC_STATE!^) >> "!E103LOG!"
)

REM --- Pre-check: are any Autodesk products installed? ---
set "E103_HAS_PRODUCTS=0"
for /f "tokens=*" %%p in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s /v "Publisher" 2^>nul ^| findstr /i "Autodesk"') do set "E103_HAS_PRODUCTS=1"

REM --- Check 5: ODIS infrastructure ---
set "E103_T=!time:~0,8!"
<nul set /p "=  !DIM![!E103_T!]!R! !CWHT![5/10]!R! ODIS infrastructure.......... "
set "E103_ODIS=0"
set "E103_ODIS_MSG="
set "E103_ODIS_NOTINSTALLED=0"
if not exist "C:\Program Files\Autodesk\AdODIS\V1\Installer.exe" (
    set "E103_ODIS=1"
    set "E103_ODIS_MSG=Installer.exe MISSING"
    echo  [5] ODIS Installer.exe: MISSING >> "!E103LOG!"
)
if exist "C:\Program Files\Autodesk\AdODIS\V1\Installer.exe" (
    echo  [5] ODIS Installer.exe: EXISTS >> "!E103LOG!"
)
if not exist "C:\ProgramData\Autodesk\ODIS" (
    set "E103_ODIS=1"
    set "E103_ODIS_MSG=!E103_ODIS_MSG! ODIS folder MISSING"
    echo  [5] ODIS data folder: MISSING >> "!E103LOG!"
)
if exist "C:\ProgramData\Autodesk\ODIS" (
    echo  [5] ODIS data folder: EXISTS >> "!E103LOG!"
)
REM If ODIS missing but no products installed, this is expected (clean system)
if !E103_ODIS! gtr 0 if "!E103_HAS_PRODUCTS!"=="0" set "E103_ODIS_NOTINSTALLED=1"
if !E103_ODIS_NOTINSTALLED! equ 1 (
    echo !DIM!NOT INSTALLED!R! - no Autodesk products found
    echo  [5] ODIS: NOT INSTALLED ^(no products present, expected^) >> "!E103LOG!"
)
if !E103_ODIS! gtr 0 if !E103_ODIS_NOTINSTALLED! equ 0 (
    set /a E103_ISSUES+=1
    echo !CRED!DAMAGED!R! - !E103_ODIS_MSG!
)
if !E103_ODIS! equ 0 (
    echo !CGRN!OK!R! - ODIS files present
)

REM --- Check 6: ProductInformation.pit ---
set "E103_T=!time:~0,8!"
<nul set /p "=  !DIM![!E103_T!]!R! !CWHT![6/10]!R! ProductInformation.pit....... "
set "E103_PIT=0"
set "E103_PITFILE=%LOCALAPPDATA%\Autodesk\Web Services\ProductInformation.pit"
if exist "!E103_PITFILE!" (
    set "E103_PIT=1"
    set /a E103_ISSUES+=1
    for %%f in ("!E103_PITFILE!") do set "E103_PIT_SIZE=%%~zf"
    echo !CYLW!EXISTS!R! !DIM!^(!E103_PIT_SIZE! bytes - may be corrupted^)!R!
    echo  [6] ProductInformation.pit: EXISTS ^(!E103_PIT_SIZE! bytes^) >> "!E103LOG!"
)
if not exist "!E103_PITFILE!" (
    echo !CGRN!OK!R! - not present ^(will regenerate^)
    echo  [6] ProductInformation.pit: NOT PRESENT >> "!E103LOG!"
)

REM --- Check 7: TMP/TEMP paths ---
set "E103_T=!time:~0,8!"
<nul set /p "=  !DIM![!E103_T!]!R! !CWHT![7/10]!R! TMP/TEMP paths............... "
set "E103_TEMP=0"
set "E103_TEMP_OK=1"
echo "!TEMP!" | findstr /i "\\AppData\\Local\\Temp" >nul 2>&1
if !errorlevel! neq 0 (
    set "E103_TEMP=1"
    set "E103_TEMP_OK=0"
    set /a E103_ISSUES+=1
)
if !E103_TEMP_OK! equ 1 (
    echo !CGRN!OK!R! - !DIM!!TEMP!!R!
    echo  [7] TEMP path: OK ^(!TEMP!^) >> "!E103LOG!"
)
if !E103_TEMP_OK! equ 0 (
    echo !CRED!NON-DEFAULT!R! - !TEMP!
    echo  [7] TEMP path: NON-DEFAULT ^(!TEMP!^) >> "!E103LOG!"
)

REM --- Check 8: Visual C++ Redistributables ---
set "E103_T=!time:~0,8!"
<nul set /p "=  !DIM![!E103_T!]!R! !CWHT![8/10]!R! Visual C++ Redistributables.. "
set "E103_VC=0"
set "E103_VC_COUNT=0"
for /f "tokens=*" %%r in ('reg query "HKLM\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" /v Major 2^>nul') do (
    set /a E103_VC_COUNT+=1
)
if !E103_VC_COUNT! equ 0 (
    set "E103_VC=1"
    set /a E103_ISSUES+=1
    echo !CRED!NOT FOUND!R! - VC++ 2015-2022 x64 missing
    echo  [8] VC++ Redistributable x64: NOT FOUND >> "!E103LOG!"
)
if !E103_VC_COUNT! gtr 0 (
    echo !CGRN!OK!R! - VC++ 2015-2022 x64 installed
    echo  [8] VC++ Redistributable x64: INSTALLED >> "!E103LOG!"
)

REM --- Check 9: Windows Event Viewer ---
set "E103_T=!time:~0,8!"
<nul set /p "=  !DIM![!E103_T!]!R! !CWHT![9/10]!R! Windows Event Viewer......... "
set "E103_EVT=0"
set "E103_EVTTMP=!LOGDIR!\e103_evt_tmp.txt"
type nul > "!E103_EVTTMP!"
powershell -NoProfile -Command "Get-WinEvent -FilterHashtable @{LogName='Application'; Level=2; StartTime=(Get-Date).AddDays(-7)} -ErrorAction SilentlyContinue | Where-Object {$_.Message -match 'Autodesk|ODIS|AdskAccess|AdODIS|MsiInstaller.*Autodesk'} | Select-Object -First 10 TimeCreated, Id, Message | ForEach-Object { '{0} EventID={1} {2}' -f $_.TimeCreated.ToString('yyyy-MM-dd HH:mm'), $_.Id, ($_.Message -split '`n')[0].Substring(0,[Math]::Min(120,($_.Message -split '`n')[0].Length)) }" > "!E103_EVTTMP!" 2>nul
for /f "tokens=*" %%e in ('type "!E103_EVTTMP!" 2^>nul') do set /a E103_EVT+=1
if !E103_EVT! gtr 0 (
    set /a E103_ISSUES+=1
    echo !CYLW!!E103_EVT! Autodesk errors in last 7 days!R!
    echo  [9] Event Viewer: !E103_EVT! Autodesk errors in last 7 days >> "!E103LOG!"
    echo  [9] Recent errors: >> "!E103LOG!"
    set "E103_EVT_SHOWN=0"
    for /f "tokens=*" %%e in ('type "!E103_EVTTMP!" 2^>nul') do (
        if !E103_EVT_SHOWN! lss 5 echo       %%e >> "!E103LOG!"
        set /a E103_EVT_SHOWN+=1
    )
)
if !E103_EVT! equ 0 (
    echo !CGRN!OK!R! - no Autodesk errors in last 7 days
    echo  [9] Event Viewer: CLEAN ^(no Autodesk errors in 7 days^) >> "!E103LOG!"
)

REM --- Check 10: Hosts file Autodesk entries ---
set "E103_T=!time:~0,8!"
<nul set /p "=  !DIM![!E103_T!]!R! !CWHT![10/10]!R! Hosts file................. "
set "E103_HOSTS=0"
set "HOSTS_FILE=%WINDIR%\System32\drivers\etc\hosts"
if exist "!HOSTS_FILE!" (
    for /f "tokens=*" %%h in ('findstr /i /v "^#" "!HOSTS_FILE!" 2^>nul ^| findstr /i "autodesk"') do (
        set /a E103_HOSTS+=1
    )
)
if !E103_HOSTS! gtr 0 (
    echo !CYLW!!E103_HOSTS! Autodesk entries!R!
    echo  [10] Hosts file: !E103_HOSTS! Autodesk entries found >> "!E103LOG!"
    for /f "tokens=*" %%h in ('findstr /i /v "^#" "!HOSTS_FILE!" 2^>nul ^| findstr /i "autodesk"') do (
        echo      !DIM!%%h!R!
        echo       %%h >> "!E103LOG!"
    )
    echo      !CYLW!These entries block Autodesk license servers.!R!
    echo      !CYLW!Legitimate installations will fail to activate.!R!
    set /a E103_ISSUES+=1
)
if !E103_HOSTS! equ 0 (
    echo !CGRN!CLEAN!R!
    echo  [10] Hosts file: CLEAN >> "!E103LOG!"
)

REM --- Diagnosis Summary ---
echo.
echo  !CCYN!------------------------------------------------------------!R!
echo  DIAGNOSIS COMPLETE: >> "!E103LOG!"
if !E103_ISSUES! equ 0 (
    echo  !CGRN!!BOLD!  No issues found!!R! Error 103 may have another cause.
    echo  No issues found. >> "!E103LOG!"
    echo.
    echo  !DIM!Suggestions:!R!
    echo    - Reboot and try the installation again
    echo    - Run Event Viewer ^> Application log, filter by "Autodesk"
    echo.
    echo  !CWHT!Log saved to:!R! !DIM!!E103LOG!!R!
    del /f "!E103_EVTTMP!" >nul 2>&1
    echo.
    pause
    goto :main_menu
)
echo [!time:~0,8!] Error 103: !E103_ISSUES! issues >> "!CLOG!"
echo  !CYLW!!BOLD!  !E103_ISSUES! issue^(s^) found.!R!
echo  !E103_ISSUES! issue^(s^) found. >> "!E103LOG!"
echo.
echo  !CWHT!Phase 2: Repair!R! - fix each issue individually
echo  !DIM!You will be asked to confirm each repair.!R!
echo.
echo ================================================ >> "!E103LOG!"
echo REPAIRS: >> "!E103LOG!"

REM === Repair 1: ODIS lock file ===
if !E103_LOCK! equ 1 (
    echo  !CCYN![Fix 1]!R! !CWHT!Delete ODIS lock file!R!
    echo    !DIM!!E103_LOCKFILE!!R!
    set /p "E103_R1=  Apply fix? [Y/N]: "
    if /i "!E103_R1!"=="Y" del /f "!E103_LOCKFILE!" >nul 2>&1
    if /i "!E103_R1!"=="Y" set /a E103_FIXES+=1
    if /i "!E103_R1!"=="Y" echo    !CGRN!Deleted.!R!
    if /i "!E103_R1!"=="Y" echo  [Fix 1] Lock file: DELETED >> "!E103LOG!"
    if /i "!E103_R1!" neq "Y" echo    !CYLW!Skipped.!R!
    if /i "!E103_R1!" neq "Y" echo  [Fix 1] Lock file: SKIPPED >> "!E103LOG!"
    echo.
)

REM === Repair 2: Debugger keys ===
if !E103_IFEO! gtr 0 (
    echo  !CCYN![Fix 2]!R! !CWHT!Remove !E103_IFEO! debugger key^(s^)!R!
    echo    !DIM!Keys blocking:!E103_IFEO_LIST!!R!
    set /p "E103_R2=  Apply fix? [Y/N]: "
)
set "E103_R2_APPLIED=0"
if !E103_IFEO! gtr 0 if /i "!E103_R2!"=="Y" set "E103_R2_APPLIED=1"
if !E103_R2_APPLIED! equ 1 (
    for %%x in (!IFEO_EXES!) do (
        reg query "!IFEO_ROOT!\%%x" /v Debugger >nul 2>&1
        if !errorlevel! equ 0 reg delete "!IFEO_ROOT!\%%x" /v Debugger /f >nul 2>&1
    )
    set /a E103_FIXES+=1
    echo    !CGRN!Debugger keys removed.!R!
    echo  [Fix 2] Debugger keys: REMOVED >> "!E103LOG!"
    echo.
)
if !E103_IFEO! gtr 0 if /i "!E103_R2!" neq "Y" (
    echo    !CYLW!Skipped.!R!
    echo  [Fix 2] Debugger keys: SKIPPED >> "!E103LOG!"
    echo.
)

REM === Repair 3: Restart AdskAccessServiceHost ===
set "E103_DO_R3=0"
if !E103_SVC! equ 1 set "E103_DO_R3=1"
if "!E103_SVC_STATE!" neq "4" if !E103_SVC! neq 2 set "E103_DO_R3=1"
if !E103_DO_R3! equ 1 (
    echo  !CCYN![Fix 3]!R! !CWHT!Restart AdskAccessServiceHost service!R!
    echo    !DIM!Service is installed but not running properly.!R!
    set /p "E103_R3=  Apply fix? [Y/N]: "
)
if !E103_DO_R3! equ 1 if /i "!E103_R3!"=="Y" (
    net stop AdskAccessServiceHost >nul 2>&1
    timeout /t 2 /nobreak >nul
    net start AdskAccessServiceHost >nul 2>&1
    if !errorlevel! equ 0 echo    !CGRN!Service restarted.!R!
    if !errorlevel! neq 0 echo    !CRED!Failed to start service. May need ODIS reinstall.!R!
    set /a E103_FIXES+=1
    echo  [Fix 3] Service restart: ATTEMPTED >> "!E103LOG!"
    echo.
)
if !E103_DO_R3! equ 1 if /i "!E103_R3!" neq "Y" (
    echo    !CYLW!Skipped.!R!
    echo  [Fix 3] Service restart: SKIPPED >> "!E103LOG!"
    echo.
)

REM === Repair 4: ODIS infrastructure ===
if !E103_ODIS! gtr 0 (
    echo  !CCYN![Fix 4]!R! !CWHT!Reset ODIS infrastructure!R!
    echo    !DIM!This will remove ODIS folders and run RemoveODIS.exe.!R!
    echo    !DIM!You will need to re-download Autodesk Access afterwards.!R!
    set /p "E103_R4=  Apply fix? [Y/N]: "
)
if !E103_ODIS! gtr 0 if /i "!E103_R4!"=="Y" (
    echo    Stopping ODIS services...
    net stop AdskAccessServiceHost >nul 2>&1
    if exist "C:\Program Files\Autodesk\AdODIS\V1\RemoveODIS.exe" (
        echo    Running RemoveODIS.exe...
        "C:\Program Files\Autodesk\AdODIS\V1\RemoveODIS.exe" --mode unattended >nul 2>&1
    )
    if exist "C:\ProgramData\Autodesk\ODIS" (
        echo    Removing ODIS data folder...
        rmdir /s /q "C:\ProgramData\Autodesk\ODIS" >nul 2>&1
    )
    if exist "C:\Program Files\Autodesk\AdODIS" (
        echo    Removing AdODIS program folder...
        rmdir /s /q "C:\Program Files\Autodesk\AdODIS" >nul 2>&1
    )
    set /a E103_FIXES+=1
    echo    !CGRN!ODIS infrastructure removed.!R!
    echo    !CWHT!Next step:!R! Download Autodesk Access from autodesk.com
    echo  [Fix 4] ODIS reset: COMPLETED >> "!E103LOG!"
    echo.
)
if !E103_ODIS! gtr 0 if /i "!E103_R4!" neq "Y" (
    echo    !CYLW!Skipped.!R!
    echo  [Fix 4] ODIS reset: SKIPPED >> "!E103LOG!"
    echo.
)

REM === Repair 5: ProductInformation.pit ===
if !E103_PIT! equ 1 (
    echo  !CCYN![Fix 5]!R! !CWHT!Delete ProductInformation.pit!R!
    echo    !DIM!!E103_PITFILE!!R!
    set /p "E103_R5=  Apply fix? [Y/N]: "
    if /i "!E103_R5!"=="Y" del /f "!E103_PITFILE!" >nul 2>&1
    if /i "!E103_R5!"=="Y" set /a E103_FIXES+=1
    if /i "!E103_R5!"=="Y" echo    !CGRN!Deleted. Will regenerate on next launch.!R!
    if /i "!E103_R5!"=="Y" echo  [Fix 5] PIT file: DELETED >> "!E103LOG!"
    if /i "!E103_R5!" neq "Y" echo    !CYLW!Skipped.!R!
    if /i "!E103_R5!" neq "Y" echo  [Fix 5] PIT file: SKIPPED >> "!E103LOG!"
    echo.
)

REM === Repair 7: TEMP path (info only) ===
if !E103_TEMP! equ 1 (
    echo  !CCYN![Fix 7]!R! !CWHT!TMP/TEMP path is non-default!R!
    echo    !DIM!Current: !TEMP!!R!
    echo    !DIM!Expected: C:\Users\%USERNAME%\AppData\Local\Temp!R!
    echo    !CYLW!This must be fixed manually in System Environment Variables.!R!
    echo    !DIM!Control Panel ^> System ^> Advanced ^> Environment Variables!R!
    echo  [Fix 7] TEMP path: NON-DEFAULT ^(manual fix required^) >> "!E103LOG!"
    echo.
)

REM === Repair 8: VC++ Redistributable (info only) ===
if !E103_VC! equ 1 (
    echo  !CCYN![Fix 8]!R! !CWHT!Visual C++ 2015-2022 x64 not found!R!
    echo    !CYLW!Download and install from Microsoft:!R!
    echo    !DIM!https://aka.ms/vs/17/release/vc_redist.x64.exe!R!
    echo  [Fix 8] VC++ Redist: NOT FOUND ^(manual install required^) >> "!E103LOG!"
    echo.
)

REM === Repair 9: Event Viewer findings (info only) ===
if !E103_EVT! gtr 0 (
    echo  !CCYN![Fix 9]!R! !CWHT!!E103_EVT! Autodesk errors found in Event Viewer!R!
    echo    !DIM!Recent errors from Application log ^(last 7 days^):!R!
    echo  [Fix 9] Event Viewer errors: >> "!E103LOG!"
)
set "E103_EVT_DISP=0"
for /f "tokens=*" %%e in ('type "!LOGDIR!\e103_evt_tmp.txt" 2^>nul') do (
    if !E103_EVT_DISP! lss 3 echo    !DIM!  %%e!R!
    set /a E103_EVT_DISP+=1
)
if !E103_EVT! gtr 0 (
    echo    !CYLW!Open Event Viewer ^> Application log and filter by "Autodesk"!R!
    echo.
)

REM === Repair 10: Hosts file entries ===
if !E103_HOSTS! gtr 0 (
    echo  !CCYN![Fix 10]!R! !CWHT!Remove !E103_HOSTS! Autodesk entries from hosts file!R!
    echo    !DIM!This removes lines blocking Autodesk license servers.!R!
    echo    !DIM!Your other hosts entries will NOT be touched.!R!
    <nul set /p "=  Apply fix? [Y/N]: "
    set /p "E103_R10="
)
if !E103_HOSTS! gtr 0 if /i "!E103_R10!"=="Y" (
    REM Create temp hosts without Autodesk lines (preserve comments and non-Autodesk entries)
    set "HOSTS_TMP=!LOGDIR!\hosts_tmp"
    type nul > "!HOSTS_TMP!"
    for /f "usebackq tokens=* delims=" %%h in ("!HOSTS_FILE!") do (
        set "HLINE=%%h"
        set "HSKIP=0"
        echo "%%h" | findstr /i "autodesk" >nul 2>&1
        if !errorlevel! equ 0 (
            set "HIS_COMMENT=0"
            echo "!HLINE!" | findstr /b /c:"#" >nul 2>&1
            if !errorlevel! equ 0 set "HIS_COMMENT=1"
            for /f "tokens=*" %%t in ("!HLINE!") do (
                echo "%%t" | findstr /b /c:"#" >nul 2>&1
                if !errorlevel! equ 0 set "HIS_COMMENT=1"
            )
            if !HIS_COMMENT! equ 0 set "HSKIP=1"
        )
        if !HSKIP! equ 0 >>"!HOSTS_TMP!" echo(%%h
    )
    copy /y "!HOSTS_TMP!" "!HOSTS_FILE!" >nul 2>&1
    del "!HOSTS_TMP!" >nul 2>&1
    echo      !CGRN!Hosts file cleaned.!R!
    echo  [Fix 10] Hosts file cleaned >> "!E103LOG!"
)

REM === Repair: Clear pending reboot flags ===
set "E103_REBOOT_FLAGS=0"
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" >nul 2>&1
if !errorlevel! equ 0 set "E103_REBOOT_FLAGS=1"
reg query "HKLM\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\RebootRequired" >nul 2>&1
if !errorlevel! equ 0 set "E103_REBOOT_FLAGS=1"

if !E103_REBOOT_FLAGS! equ 1 (
    echo  !CCYN![Fix]!R! !CWHT!Clear pending reboot flags!R!
    echo    !DIM!Windows Update left reboot flags that block Autodesk installers.!R!
    <nul set /p "=  Apply fix? [Y/N]: "
    set /p "E103_RBOOT="
)
if !E103_REBOOT_FLAGS! equ 1 if /i "!E103_RBOOT!"=="Y" (
    reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" /f >nul 2>&1
    reg delete "HKLM\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\RebootRequired" /f >nul 2>&1
    echo      !CGRN!Reboot flags cleared.!R!
)

REM --- Repair Summary ---
echo  !CCYN!============================================================!R!
echo ================================================ >> "!E103LOG!"
echo SUMMARY: >> "!E103LOG!"
if !E103_FIXES! gtr 0 (
    echo  !CGRN!!BOLD!  !E103_FIXES! fix^(es^) applied.!R!
    echo  !E103_FIXES! fix^(es^) applied. >> "!E103LOG!"
)
if !E103_FIXES! equ 0 (
    echo  !CYLW!  No fixes applied.!R!
    echo  No fixes applied. >> "!E103LOG!"
)
echo [!time:~0,8!] Error 103: !E103_FIXES! fixes applied >> "!CLOG!"
echo.
echo  !CWHT!Recommended next steps:!R!
echo    1. Reboot your computer
set "E103_AA_TIP=Download Autodesk Access from autodesk.com/products/autodesk-access"
if "!E103_AA_VER!" neq "NOT INSTALLED" set "E103_AA_TIP=Your Autodesk Access is !E103_AA_VER! - visit autodesk.com/products/autodesk-access for updates"
echo    2. !E103_AA_TIP!
echo    3. Try the Autodesk product installation again
echo.
echo  !CWHT!Log saved to:!R! !DIM!!E103LOG!!R!
echo  Completed: %date% %time% >> "!E103LOG!"
del /f "!E103_EVTTMP!" >nul 2>&1
echo.
echo. >> "!CLOG!"
echo --- End of section --- >> "!CLOG!"
echo. >> "!CLOG!"
pause
goto :main_menu

REM ============================================================
REM FIX "RESTART PENDING"
REM ============================================================
:fix_reboot_pending
cls
echo.
echo  !CCYN!============================================================!R!
echo  !CCYN!  !BOLD!!CWHT!  FIX "RESTART PENDING" - Installation Readiness     !R!
echo  !CCYN!============================================================!R!
echo.
echo  !CWHT!This fixes the "An operating system restart is pending"!R!
echo  !CWHT!message that blocks Autodesk product installation.!R!
echo.
echo  !DIM!Common after running cleanup tools, Windows Updates, or!R!
echo  !DIM!uninstalling software. Usually does NOT require an actual reboot.!R!
echo.
echo  Phase 1: Checking pending reboot indicators...
echo.
echo. >> "!CLOG!"
echo ======================================================== >> "!CLOG!"
echo  FIX RESTART PENDING >> "!CLOG!"
echo ======================================================== >> "!CLOG!"

REM Check all known reboot flags
set "RB_ISSUES=0"
<nul set /p "=  !DIM![!time:~0,8!]!R! [1/5] PendingFileRenameOperations... "
set "RB_PFRO=0"
for /f "tokens=*" %%v in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v PendingFileRenameOperations 2^>nul ^| findstr /i "Pending"') do set "RB_PFRO=1"
if !RB_PFRO! equ 1 (
    echo !CYLW!FOUND!R!
    set /a RB_ISSUES+=1
)
if !RB_PFRO! equ 0 echo !CGRN!CLEAN!R!
echo [!time:~0,8!] [1/5] PFRO: !RB_PFRO! >> "!CLOG!"

<nul set /p "=  !DIM![!time:~0,8!]!R! [2/5] WindowsUpdate RebootRequired.. "
set "RB_WU=0"
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" >nul 2>&1
if !errorlevel! equ 0 (
    set "RB_WU=1"
    set /a RB_ISSUES+=1
    echo !CYLW!FOUND!R!
)
if !RB_WU! equ 0 echo !CGRN!CLEAN!R!
echo [!time:~0,8!] [2/5] WinUpdate: !RB_WU! >> "!CLOG!"

<nul set /p "=  !DIM![!time:~0,8!]!R! [3/5] Orchestrator RebootRequired... "
set "RB_ORCH=0"
reg query "HKLM\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\RebootRequired" >nul 2>&1
if !errorlevel! equ 0 (
    set "RB_ORCH=1"
    set /a RB_ISSUES+=1
    echo !CYLW!FOUND!R!
)
if !RB_ORCH! equ 0 echo !CGRN!CLEAN!R!
echo [!time:~0,8!] [3/5] Orchestrator: !RB_ORCH! >> "!CLOG!"

<nul set /p "=  !DIM![!time:~0,8!]!R! [4/5] UpdateExeVolatile............ "
set "RB_UEV=0"
for /f "tokens=2,*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Updates" /v UpdateExeVolatile 2^>nul ^| findstr /i "UpdateExeVolatile"') do (
    if "%%b" neq "0x0" (
        set "RB_UEV=1"
        set /a RB_ISSUES+=1
    )
)
if !RB_UEV! equ 1 echo !CYLW!FOUND - non-zero!R!
if !RB_UEV! equ 0 echo !CGRN!CLEAN!R!
echo [!time:~0,8!] [4/5] UpdateExeVolatile: !RB_UEV! >> "!CLOG!"

<nul set /p "=  !DIM![!time:~0,8!]!R! [5/5] CBS RebootPending............ "
set "RB_CBS=0"
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" >nul 2>&1
if !errorlevel! equ 0 (
    set "RB_CBS=1"
    set /a RB_ISSUES+=1
    echo !CYLW!FOUND!R!
)
if !RB_CBS! equ 0 echo !CGRN!CLEAN!R!
echo [!time:~0,8!] [5/5] CBS: !RB_CBS! >> "!CLOG!"

echo.
if !RB_ISSUES! gtr 0 (
    echo  !CYLW!!RB_ISSUES! pending reboot indicator^(s^) found.!R!
)
if !RB_ISSUES! equ 0 (
    echo  !CGRN!No registry-level reboot flags found.!R!
)
echo.
echo  Phase 2: Clearing all pending reboot state...
echo.
<nul set /p "=  Clearing registry flags..."
if !RB_PFRO! equ 1 (
    reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v PendingFileRenameOperations /f >nul 2>&1
)
if !RB_WU! equ 1 reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" /f >nul 2>&1
if !RB_ORCH! equ 1 reg delete "HKLM\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\RebootRequired" /f >nul 2>&1
if !RB_UEV! equ 1 reg add "HKLM\SOFTWARE\Microsoft\Updates" /v UpdateExeVolatile /t REG_DWORD /d 0 /f >nul 2>&1
if !RB_CBS! equ 1 reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" /f >nul 2>&1
echo  !CGRN!done.!R!

echo.
<nul set /p "=  Flushing Windows Installer service..."
net stop msiserver /y >nul 2>&1
net start msiserver >nul 2>&1
echo  !CGRN!done.!R!

echo.
echo [!time:~0,8!] Fix Reboot Pending: !RB_ISSUES! flags cleared >> "!CLOG!"
echo  !CGRN!!BOLD!All pending reboot states cleared.!R!
echo.
echo  !CWHT!A system reboot is recommended but not required.!R!
echo  !DIM!You can proceed with Autodesk installation without rebooting.!R!
echo  !DIM!If you encounter issues, restart using Start Menu - Restart.!R!
echo.
echo. >> "!CLOG!"
echo --- End of section --- >> "!CLOG!"
echo. >> "!CLOG!"
pause
goto :main_menu

REM ============================================================
REM BACKUP AUTODESK TEMPLATES AND SETTINGS
REM ============================================================
:backup_templates
cls
echo.
echo  !CCYN!============================================================!R!
echo  !CCYN!  !BOLD!!CWHT!  BACKUP AUTODESK TEMPLATES AND SETTINGS          !R!
echo  !CCYN!============================================================!R!
echo.
echo  !CWHT!This tool backs up your custom Autodesk templates,!R!
echo  !CWHT!profiles, workspace settings, and user configurations.!R!
echo.
echo  !DIM!Scanning for Autodesk user data...!R!
echo.
echo. >> "!CLOG!"
echo ======================================================== >> "!CLOG!"
echo  BACKUP TEMPLATES AND SETTINGS >> "!CLOG!"
echo ======================================================== >> "!CLOG!"

set "BK_FOUND=0"
set "BK_COUNT=0"

if exist "%APPDATA%\Autodesk" (
    set "BK_FOUND=1"
    for /f "tokens=*" %%d in ('dir /b /ad "%APPDATA%\Autodesk" 2^>nul') do (
        set /a BK_COUNT+=1
        echo    !CWHT!%%d!R! !DIM!^(%APPDATA%\Autodesk\%%d^)!R!
    )
)
if exist "%LOCALAPPDATA%\Autodesk" (
    set "BK_FOUND=1"
    for /f "tokens=*" %%d in ('dir /b /ad "%LOCALAPPDATA%\Autodesk" 2^>nul') do (
        set /a BK_COUNT+=1
        echo    !CWHT!%%d!R! !DIM!^(%LOCALAPPDATA%\Autodesk\%%d^)!R!
    )
)
if exist "C:\Users\Public\Documents\Autodesk" (
    set "BK_FOUND=1"
    for /f "tokens=*" %%d in ('dir /b /ad "C:\Users\Public\Documents\Autodesk" 2^>nul') do (
        set /a BK_COUNT+=1
        echo    !CWHT!%%d!R! !DIM!^(Public Documents^)!R!
    )
)

echo.
if !BK_FOUND! equ 0 (
    echo  !CYLW!No Autodesk user data found to back up.!R!
    echo.
    pause
    goto :main_menu
)

echo  !CWHT!!BK_COUNT! Autodesk data folders found.!R!
echo [!time:~0,8!] Backup: !BK_COUNT! data folders found >> "!CLOG!"
echo.
set "BK_DT="
for /f "tokens=2 delims==" %%d in ('wmic os get localdatetime /value 2^>nul') do set "BK_DT=%%d"
if not defined BK_DT (
    for /f "delims=" %%d in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMddHHmmss"') do set "BK_DT=%%d"
)
set "BK_DATESTAMP=!BK_DT:~0,8!"
echo  !DIM!Backup will be saved to:!R!
set "BK_DIR=!LOGDIR!\Autodesk_Backup_!BK_DATESTAMP!"
echo  !CWHT!!BK_DIR!!R!
echo.
<nul set /p "=  Proceed with backup? [Y/N]: "
set /p "BK_GO="

if /i "!BK_GO!" neq "Y" (
    echo.
    echo  !DIM!Backup cancelled.!R!
    echo.
    pause
    goto :main_menu
)

echo.
mkdir "!BK_DIR!" >nul 2>&1

if exist "%APPDATA%\Autodesk" (
    <nul set /p "=  !DIM![!time:~0,8!]!R! Backing up Roaming\Autodesk..."
    xcopy "%APPDATA%\Autodesk" "!BK_DIR!\Roaming_Autodesk\" /e /h /q /y >nul 2>&1
    if !errorlevel! equ 0 echo  !CGRN!done.!R!
    if !errorlevel! neq 0 echo  !CYLW!partial - some files could not be copied.!R!
)
if exist "%LOCALAPPDATA%\Autodesk" (
    <nul set /p "=  !DIM![!time:~0,8!]!R! Backing up Local\Autodesk..."
    xcopy "%LOCALAPPDATA%\Autodesk" "!BK_DIR!\Local_Autodesk\" /e /h /q /y >nul 2>&1
    if !errorlevel! equ 0 echo  !CGRN!done.!R!
    if !errorlevel! neq 0 echo  !CYLW!partial - some files could not be copied.!R!
)
if exist "C:\Users\Public\Documents\Autodesk" (
    <nul set /p "=  !DIM![!time:~0,8!]!R! Backing up Public\Documents\Autodesk..."
    xcopy "C:\Users\Public\Documents\Autodesk" "!BK_DIR!\Public_Autodesk\" /e /h /q /y >nul 2>&1
    if !errorlevel! equ 0 echo  !CGRN!done.!R!
    if !errorlevel! neq 0 echo  !CYLW!partial - some files could not be copied.!R!
)

REM Calculate backup size
set "BK_SIZE=0"
for /f "tokens=3" %%s in ('dir /s "!BK_DIR!" 2^>nul ^| findstr /i "File"') do set "BK_SIZE=%%s"

echo.
echo  !CGRN!!BOLD!Backup complete.!R!
echo [!time:~0,8!] Backup saved to: !BK_DIR! >> "!CLOG!"
echo.
echo  !CWHT!Location:!R! !BK_DIR!
echo  !CWHT!Contents:!R! Roaming + Local + Public Autodesk user data
echo.
echo  !DIM!To restore after reinstallation, copy these folders back!R!
echo  !DIM!to their original locations.!R!
echo.
echo. >> "!CLOG!"
echo --- End of section --- >> "!CLOG!"
echo. >> "!CLOG!"
pause
goto :main_menu

REM ============================================================
REM FINAL VERIFICATION
REM ============================================================
:run_verify
cls
echo.
echo  ========================================================
echo   !CCYN!!BOLD!FINAL VERIFICATION - DEEP SCAN!R!
echo  VERIFICATION START %time% >> "!DIAGFILE!"
echo  ========================================================
echo. >> "!CLOG!"
echo ======================================================== >> "!CLOG!"
echo  FINAL VERIFICATION >> "!CLOG!"
echo ======================================================== >> "!CLOG!"
echo  !DIM!Performing thorough remnant analysis...!R!
echo.
set RM=0
set "VLOG=!LOGDIR!\verify_details.txt"
type nul > "!VLOG!"
echo VERIFICATION DETAILS - %date% %time% >> "!VLOG!"
echo ================================================ >> "!VLOG!"
set "VF_START=!time:~0,8!"

REM === 1. REGISTERED PRODUCTS ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![1/17]!R! Installed products..."
set VP=0
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s /v "DisplayName" 2^>nul ^| findstr /i "HKEY_"') do (
    set "V_PUB="
    for /f "tokens=2,*" %%a in ('reg query "%%k" /v "Publisher" 2^>nul ^| findstr /i "Publisher"') do set "V_PUB=%%b"
    if defined V_PUB (
        echo "!V_PUB!" | findstr /i "Autodesk" >nul 2>&1
        if !errorlevel! equ 0 (
            set /a VP+=1
            for /f "tokens=2,*" %%a in ('reg query "%%k" /v "DisplayName" 2^>nul ^| findstr /i "DisplayName"') do echo   PRODUCT: %%b >> "!VLOG!"
        )
    )
)
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" /s /v "DisplayName" 2^>nul ^| findstr /i "HKEY_"') do (
    set "V_PUB="
    for /f "tokens=2,*" %%a in ('reg query "%%k" /v "Publisher" 2^>nul ^| findstr /i "Publisher"') do set "V_PUB=%%b"
    if defined V_PUB (
        echo "!V_PUB!" | findstr /i "Autodesk" >nul 2>&1
        if !errorlevel! equ 0 (
            set /a VP+=1
            for /f "tokens=2,*" %%a in ('reg query "%%k" /v "DisplayName" 2^>nul ^| findstr /i "DisplayName"') do echo   PRODUCT-32: %%b >> "!VLOG!"
        )
    )
)
if !VP! gtr 0 (
    echo  !CRED!!VP! REMAINING!R!
    set /a RM+=VP
)
if !VP! equ 0 echo  !CGRN!CLEAN!R!
echo [!time:~0,8!] Verify [1/17] Products: !VP! >> "!CLOG!"

REM === 2. RUNNING PROCESSES ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![2/17]!R! Processes..."
set PR=0
set "PROC_TMP=!LOGDIR!\proc_check.tmp"
type nul > "!PROC_TMP!"
start "" /b cmd /c "tasklist /nh > "!PROC_TMP!" 2>nul"
ping -n 6 127.0.0.1 >nul 2>&1
taskkill /f /im tasklist.exe >nul 2>&1
for %%p in (!KILL_PROCS_SCAN!) do (
    findstr /i "%%p" "!PROC_TMP!" >nul 2>&1
    if !errorlevel! equ 0 (
        set /a PR+=1
        echo   PROCESS: %%p >> "!VLOG!"
    )
)
del "!PROC_TMP!" >nul 2>&1
if !PR! gtr 0 (
    echo  !CRED!!PR! REMAINING!R!
    set /a RM+=PR
)
if !PR! equ 0 echo  !CGRN!CLEAN!R!
echo [!time:~0,8!] Verify [2/17] Processes: !PR! >> "!CLOG!"

REM === 3. SERVICES ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![3/17]!R! Services..."
set SR=0
for %%s in (AdskLicensingService AdskAccessServiceHost AdAppMgrSvc AdskNLM DesktopConnectorService "FlexNet Licensing Service 64" "Autodesk Genuine Service") do (
    sc query %%s >nul 2>&1
    if !errorlevel! equ 0 (
        set /a SR+=1
        echo   SERVICE: %%s >> "!VLOG!"
    )
)
if !SR! gtr 0 (
    echo  !CRED!!SR! REMAINING!R!
    set /a RM+=SR
)
if !SR! equ 0 echo  !CGRN!CLEAN!R!
echo [!time:~0,8!] Verify [3/17] Services: !SR! >> "!CLOG!"

REM === 4. PROGRAM FOLDERS ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![4/17]!R! Program folders..."
set FR=0
for %%d in (
    "C:\Program Files\Autodesk"
    "C:\Program Files\Common Files\Autodesk Shared"
    "C:\Program Files\Common Files\Autodesk"
    "C:\Program Files (x86)\Autodesk"
    "C:\Program Files (x86)\Common Files\Autodesk Shared"
    "C:\Program Files (x86)\Common Files\Autodesk"
    "C:\ProgramData\Autodesk"
    "C:\Autodesk"
    "C:\Program Files\Common Files\Macrovision Shared"
    "C:\Users\Public\Documents\Autodesk"
    "C:\Users\Public\Autodesk"
) do (
    if exist %%d (
        set /a FR+=1
        echo   FOLDER: %%~d >> "!VLOG!"
    )
)
if !FR! gtr 0 (
    echo  !CRED!!FR! REMAINING!R!
    set /a RM+=FR
)
if !FR! equ 0 echo  !CGRN!CLEAN!R!
echo [!time:~0,8!] Verify [4/17] Folders: !FR! >> "!CLOG!"

REM === 5. USER DATA FOLDERS ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![5/17]!R! User data folders..."
set UF=0
for %%d in ("%APPDATA%\Autodesk" "%LOCALAPPDATA%\Autodesk" "%LOCALAPPDATA%\Programs\Autodesk" "%LOCALAPPDATA%\Temp\odis_download_dest") do (
    if exist "%%~d" (
        set /a UF+=1
        echo   USER-FOLDER: %%~d >> "!VLOG!"
    )
)
REM Check SYSTEM profile
if exist "C:\Windows\System32\config\systemprofile\AppData\Local\Autodesk" (
    set /a UF+=1
    echo   SYSTEM-FOLDER: systemprofile\Autodesk >> "!VLOG!"
)
if !UF! gtr 0 (
    echo  !CRED!!UF! REMAINING!R!
    set /a RM+=UF
)
if !UF! equ 0 echo  !CGRN!CLEAN!R!
echo [!time:~0,8!] Verify [5/17] UserData: !UF! >> "!CLOG!"

REM === 6. AUTODESK REGISTRY HIVES ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![6/17]!R! Registry hives..."
set RR=0
for %%k in (
    "HKLM\SOFTWARE\Autodesk"
    "HKCU\SOFTWARE\Autodesk"
    "HKCU\SOFTWARE\SOFTWARE\Autodesk"
    "HKLM\SOFTWARE\WOW6432Node\Autodesk"
    "HKLM\SOFTWARE\FLEXlm License Manager"
    "HKCU\SOFTWARE\FLEXlm License Manager"
    "HKLM\SOFTWARE\WOW6432Node\FLEXlm License Manager"
    "HKLM\SOFTWARE\Macrovision"
) do (
    reg query %%k >nul 2>&1
    if !errorlevel! equ 0 (
        set /a RR+=1
        echo   REG-HIVE: %%~k >> "!VLOG!"
    )
)
if !RR! gtr 0 (
    echo  !CRED!!RR! REMAINING!R!
    set /a RM+=RR
)
if !RR! equ 0 echo  !CGRN!CLEAN!R!
echo [!time:~0,8!] Verify [6/17] RegHives: !RR! >> "!CLOG!"

REM === 7. REGISTRY DEEP SCAN - Autodesk-specific only ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![7/17]!R! Registry deep scan..."
set RD=0
REM Check for Autodesk-specific HKCU class keys
for /f "tokens=*" %%k in ('reg query "HKCU\SOFTWARE\Classes" /f "DWGTrueView" /k 2^>nul ^| findstr /i "HKEY_"') do (
    set /a RD+=1
    echo   HKCU-CLASS: %%k >> "!VLOG!"
)
for /f "tokens=*" %%k in ('reg query "HKCU\SOFTWARE\Classes" /f "AutoCAD" /k 2^>nul ^| findstr /i "HKEY_"') do (
    set /a RD+=1
    echo   HKCU-CLASS: %%k >> "!VLOG!"
)
for %%n in (!CLASS_KEYS!) do (
    reg query "HKCU\SOFTWARE\Classes\%%n" >nul 2>&1
    if !errorlevel! equ 0 (
        set /a RD+=1
        echo   HKCU-NAMED: %%n >> "!VLOG!"
    )
)
reg query "HKCU\SOFTWARE\Classes\dwgviewr.9128.409" >nul 2>&1
if !errorlevel! equ 0 (
    set /a RD+=1
    echo   HKCU-NAMED: dwgviewr.9128.409 >> "!VLOG!"
)
reg query "HKCU\SOFTWARE\Classes\.dgn" >nul 2>&1
if !errorlevel! equ 0 (
    set /a RD+=1
    echo   HKCU-EXT: .dgn >> "!VLOG!"
)
REM Check for Autodesk CLSIDs in HKCU
for /f "tokens=*" %%k in ('reg query "HKCU\SOFTWARE\Classes\CLSID" /s /f "Autodesk" /d 2^>nul ^| findstr /i "HKEY_.*CLSID.*{"') do (
    set /a RD+=1
    echo   HKCU-CLSID: %%k >> "!VLOG!"
)
REM Check for Autodesk COM in HKLM
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Classes\CLSID" /s /d /f "Autodesk" 2^>nul ^| findstr /i "HKEY_"') do (
    set /a RD+=1
    echo   COM-CLSID: %%k >> "!VLOG!"
)
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Classes\TypeLib" /s /d /f "Autodesk" 2^>nul ^| findstr /i "HKEY_"') do (
    set /a RD+=1
    echo   COM-TYPELIB: %%k >> "!VLOG!"
)
REM Check for shell extensions
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Approved" /s /f "Autodesk" /d 2^>nul ^| findstr /i "Autodesk"') do (
    set /a RD+=1
    echo   SHELL-EXT: %%k >> "!VLOG!"
)
if !RD! gtr 0 (
    echo  !CYLW!!RD! Autodesk class entries!R!
    set /a RM+=RD
)
if !RD! equ 0 echo  !CGRN!CLEAN!R!
echo [!time:~0,8!] Verify [7/17] RegDeep: !RD! >> "!CLOG!"

REM === 8. LEGACY LICENSING ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![8/17]!R! Legacy licensing..."
set LL=0
if exist "C:\ProgramData\Autodesk\CLM" (
    set /a LL+=1
    echo   LEGACY: CLM >> "!VLOG!"
)
if exist "C:\ProgramData\FLEXnet" (
    dir /b "C:\ProgramData\FLEXnet\adsk*" >nul 2>&1
    if !errorlevel! equ 0 (
        set /a LL+=1
        echo   LEGACY: FLEXnet adsk files >> "!VLOG!"
    )
)
if exist "%APPDATA%\Autodesk\ADUT" (
    set /a LL+=1
    echo   LEGACY: ADUT >> "!VLOG!"
)
if !LL! gtr 0 (
    echo  !CRED!!LL! REMAINING!R!
    set /a RM+=LL
)
if !LL! equ 0 echo  !CGRN!CLEAN!R!
echo [!time:~0,8!] Verify [8/17] Licensing: !LL! >> "!CLOG!"

REM === 9. ENV VARIABLES ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![9/17]!R! Env variables..."
set EV=0
for %%v in (ADSKFLEX_LICENSE_FILE ADSK_LICENSE_FILE AUTODESK_LICENSE_FILE FLEXLM_TIMEOUT) do (
    reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v "%%v" >nul 2>&1
    if !errorlevel! equ 0 (
        set /a EV+=1
        echo   ENV: %%v >> "!VLOG!"
    )
    reg query "HKCU\Environment" /v "%%v" >nul 2>&1
    if !errorlevel! equ 0 (
        set /a EV+=1
        echo   ENV-USER: %%v >> "!VLOG!"
    )
)
if !EV! gtr 0 (
    echo  !CRED!!EV! env vars SET!R!
    set /a RM+=EV
)
if !EV! equ 0 echo  !CGRN!CLEAN!R!
echo [!time:~0,8!] Verify [9/17] EnvVars: !EV! >> "!CLOG!"

REM === 10. INSTALLER\PRODUCTS GHOSTS ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![10/17]!R! Installer\Products..."
set IPV=0
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Classes\Installer\Products" /s /v "ProductName" 2^>nul ^| findstr /i "HKEY_"') do (
    set "IP_MATCH=0"
    for /f "tokens=2,*" %%a in ('reg query "%%k" /v "ProductName" 2^>nul ^| findstr /i "ProductName"') do (
        echo "%%b" | findstr /i "Autodesk" >nul 2>&1
        if !errorlevel! equ 0 set "IP_MATCH=1"
    )
    if !IP_MATCH! equ 1 (
        set /a IPV+=1
        echo   INSTALLER-PRODUCT: %%k >> "!VLOG!"
    )
)
if !IPV! gtr 0 (
    echo  !CYLW!!IPV! ghost entries!R!
    set /a RM+=IPV
)
if !IPV! equ 0 echo  !CGRN!CLEAN!R!
echo [!time:~0,8!] Verify [10/17] InstallerProducts: !IPV! >> "!CLOG!"

REM === 11. SHORTCUTS ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![11/17]!R! Shortcuts..."
set SV=0
for %%L in ("%USERPROFILE%\Desktop" "C:\Users\Public\Desktop") do (
    if exist "%%~L" (
        for %%f in ("%%~L\*.lnk") do (
            echo "%%~nf" | findstr /i /c:"Autodesk" /c:"AutoCAD" /c:"Revit" /c:"Inventor" /c:"Civil 3D" /c:"Maya" /c:"Navisworks" /c:"DWG" /c:"Design Review" /c:"3ds Max" /c:"3dsMax" >nul 2>&1
            if !errorlevel! equ 0 (
                set /a SV+=1
                echo   SHORTCUT: %%f >> "!VLOG!"
            )
        )
    )
)
if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Autodesk" (
    set /a SV+=1
    echo   START-MENU: User\Autodesk >> "!VLOG!"
)
if exist "%ProgramData%\Microsoft\Windows\Start Menu\Programs\Autodesk" (
    set /a SV+=1
    echo   START-MENU: AllUsers\Autodesk >> "!VLOG!"
)
for %%T in ("%APPDATA%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar") do (
    if exist "%%~T" (
        for %%f in ("%%~T\*.lnk") do (
            echo "%%~nf" | findstr /i /c:"Autodesk" /c:"AutoCAD" /c:"Revit" /c:"Inventor" /c:"DWG" /c:"Design Review" /c:"3ds Max" /c:"3dsMax" >nul 2>&1
            if !errorlevel! equ 0 (
                set /a SV+=1
                echo   TASKBAR: %%f >> "!VLOG!"
            )
        )
    )
)
if !SV! gtr 0 (
    echo  !CRED!!SV! REMAINING!R!
    set /a RM+=SV
)
if !SV! equ 0 echo  !CGRN!CLEAN!R!
echo [!time:~0,8!] Verify [11/17] Shortcuts: !SV! >> "!CLOG!"

REM === 12. SCHEDULED TASKS ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![12/17]!R! Scheduled tasks..."
set TK=0
for /f "tokens=1 delims=," %%n in ('schtasks /query /fo csv /nh 2^>nul ^| findstr /i "Autodesk"') do (
    set /a TK+=1
    echo   TASK: %%~n >> "!VLOG!"
)
if !TK! gtr 0 (
    echo  !CRED!!TK! REMAINING!R!
    set /a RM+=TK
)
if !TK! equ 0 echo  !CGRN!CLEAN!R!
echo [!time:~0,8!] Verify [12/17] Tasks: !TK! >> "!CLOG!"

REM === 13. FIREWALL RULES ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![13/17]!R! Firewall rules..."
set FW=0
for /f "delims=" %%r in ('powershell -NoProfile -Command "(Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'Autodesk|AutoCAD|Revit|Inventor|Civil|Maya|3ds.?Max|Navisworks' }).DisplayName" 2^>nul') do (
    set /a FW+=1
    echo   FIREWALL: %%r >> "!VLOG!"
)
if !FW! gtr 0 (
    echo  !CRED!!FW! REMAINING!R!
    set /a RM+=FW
)
if !FW! equ 0 echo  !CGRN!CLEAN!R!
echo [!time:~0,8!] Verify [13/17] Firewall: !FW! >> "!CLOG!"

REM === 14. IFEO DEBUGGER BLOCKS ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![14/17]!R! IFEO debugger blocks..."
set IF=0
set "IFEO_ROOT=HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"
for %%x in (!IFEO_EXES!) do (
    reg query "!IFEO_ROOT!\%%x" /v Debugger >nul 2>&1
    if !errorlevel! equ 0 (
        set /a IF+=1
        echo   IFEO-BLOCKED: %%x >> "!VLOG!"
    )
)
if !IF! gtr 0 (
    echo  !CRED!!IF! BLOCKED!R!
    set /a RM+=IF
)
if !IF! equ 0 echo  !CGRN!CLEAN!R!
echo [!time:~0,8!] Verify [14/17] IFEO: !IF! >> "!CLOG!"

REM === 15. PENDING FILE RENAME OPERATIONS ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![15/17]!R! PendingFileRename..."
set PF=0
for /f "tokens=*" %%v in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v PendingFileRenameOperations 2^>nul ^| findstr /i "Autodesk"') do (
    set /a PF+=1
)
if !PF! gtr 0 (
    echo  !CYLW!!PF! Autodesk entries!R!
    echo   PFRO: Autodesk entries in PendingFileRenameOperations >> "!VLOG!"
)
if !PF! equ 0 echo  !CGRN!CLEAN!R!
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" >nul 2>&1
if !errorlevel! equ 0 (
    set /a PF+=1
    echo   REBOOT-FLAG: WindowsUpdate RebootRequired key exists >> "!VLOG!"
)
reg query "HKLM\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\RebootRequired" >nul 2>&1
if !errorlevel! equ 0 (
    set /a PF+=1
    echo   REBOOT-FLAG: WindowsUpdate Orchestrator RebootRequired key exists >> "!VLOG!"
)
if !PF! gtr 0 set /a RM+=PF
echo [!time:~0,8!] Verify [15/17] PFRO: !PF! >> "!CLOG!"

REM === 16. HOSTS FILE ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![16/17]!R! Hosts file..."
set HF=0
if exist "%WINDIR%\System32\drivers\etc\hosts" (
    for /f "tokens=*" %%h in ('findstr /i /v "^#" "%WINDIR%\System32\drivers\etc\hosts" 2^>nul ^| findstr /i "autodesk"') do (
        set /a HF+=1
        echo   HOSTS: %%h >> "!VLOG!"
    )
)
if !HF! gtr 0 (
    echo  !CYLW!!HF! Autodesk entries!R!
    set /a RM+=1
)
if !HF! equ 0 echo  !CGRN!CLEAN!R!
echo [!time:~0,8!] Verify [16/17] Hosts: !HF! >> "!CLOG!"

REM === 17. DESKTOP CONNECTOR ===
<nul set /p "=  !DIM![!time:~0,8!]!R! !CWHT![17/17]!R! Desktop Connector..."
set DTC=0
if exist "C:\Program Files\Autodesk\Desktop Connector" (
    set /a DTC+=1
    echo   DTC-FOLDER: C:\Program Files\Autodesk\Desktop Connector >> "!VLOG!"
)
sc query "DesktopConnectorService" >nul 2>&1
if !errorlevel! equ 0 (
    set /a DTC+=1
    echo   DTC-SERVICE: DesktopConnectorService >> "!VLOG!"
)
if !DTC! gtr 0 (
    echo  !CRED!!DTC! REMAINING!R!
    set /a RM+=DTC
)
if !DTC! equ 0 echo  !CGRN!CLEAN!R!
set DTC_WS=0
if exist "%USERPROFILE%\DC\" set /a DTC_WS+=1
if exist "%USERPROFILE%\ACCDocs\" set /a DTC_WS+=1
if !DTC_WS! gtr 0 (
    echo      !CYLW!Workspace folders present - user project data, not counted as remnants.!R!
    echo   DTC-WORKSPACE: !DTC_WS! folder^(s^) present - user data, informational >> "!VLOG!"
)
echo [!time:~0,8!] Verify [17/17] DesktopConnector: !DTC! remnants, !DTC_WS! workspace >> "!CLOG!"

REM === SUMMARY ===
echo.
echo  ========================================================
if !RM! equ 0 (
    if !RD! equ 0 (
        echo   !CGRN!!BOLD!FULLY CLEAN - Zero Autodesk remnants detected.!R!
        echo.
        echo  !CCYN!System is ready for fresh Autodesk installation.!R!
        echo  !DIM!If the new installer shows "restart pending", reboot once first.!R!
        echo  !DIM!This is a Windows requirement after system cleanup, not an incomplete uninstall.!R!
    )
    if !RD! gtr 0 (
        echo   CLEAN - !RD! registry artifacts found.
        echo   These are COM/file associations and are harmless.
        echo   They will be cleaned up by Windows over time.
    )
)
if !RM! gtr 0 (
    echo   !CRED!!BOLD!!RM! ITEMS STILL REMAINING!R!
    echo   Try: reboot then run this script again.
    echo   Details: !VLOG!
)
echo  ========================================================
echo.
echo  !DIM!Started: !VF_START!  Completed: !time:~0,8!!R!
echo [!time:~0,8!] Verify: Started !VF_START! Completed !time:~0,8! >> "!CLOG!"
echo  Log and registry backups: !LOGDIR!
echo [!time:~0,8!] Verify total: !RM! remaining >> "!CLOG!"
echo. >> "!CLOG!"
echo --- End of section --- >> "!CLOG!"
echo. >> "!CLOG!"
echo  VERIFY: !RM! remaining >> "!LOGFILE!"
echo  VERIFY: !RM! remaining >> "!DIAGFILE!"
echo  COMPLETED %date% %time% >> "!DIAGFILE!"
echo.
set /p "RET=  Return to main menu? [Y/N]: "
if /i "!RET!"=="Y" goto :main_menu
pause
exit /b 0
