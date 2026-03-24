@echo off
setlocal enabledelayedexpansion
chcp 437 >nul 2>&1
title Autodesk Universal Uninstaller v3.7
color 0F

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  ERROR: This script must be run as Administrator.
    echo  Right-click and select "Run as administrator".
    echo.
    pause
    exit /b 1
)

set "LOGDIR=%USERPROFILE%\Desktop\Autodesk_Uninstaller"
mkdir "!LOGDIR!" 2>nul
set "LOGFILE=!LOGDIR!\uninstall_log.txt"
set "DIAGFILE=!LOGDIR!\diagnostics.log"

REM Create log file with header
type nul > "!LOGFILE!"
echo Autodesk Universal Uninstaller v3.7 >> "!LOGFILE!"
echo Date: %date% %time% >> "!LOGFILE!"
echo ------------------------------------------------ >> "!LOGFILE!"

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
for %%s in (AdskLicensingService AdskAccessServiceHost AdAppMgrSvc AdskNLM) do (
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
echo  ========================================================
echo    AUTODESK UNIVERSAL UNINSTALLER v3.7
echo    Supports all versions: 2015-2026+
echo    Compatible with Windows 10 and Windows 11
echo  ========================================================
echo.
echo  [1]  Scan Installed Autodesk Software
echo  [2]  Uninstall Selected Products
echo  [3]  Full Uninstall + Deep Clean ALL Products
echo  [4]  Deep Clean Only (remnants, no product uninstall)
echo  [5]  Final Verification
echo  [6]  Create System Restore Point
echo  [7]  Exit
echo.
echo  Log: !LOGDIR!\uninstall_log.txt
echo  Diagnostics: !LOGDIR!\diagnostics.log
echo.
set /p "MC=  Enter choice [1-7]: "
if "!MC!"=="1" goto :scan_products
if "!MC!"=="2" goto :uninstall_selected
if "!MC!"=="3" goto :full_clean
if "!MC!"=="4" goto :deep_clean
if "!MC!"=="5" goto :run_verify
if "!MC!"=="6" goto :create_restore
if "!MC!"=="7" exit /b 0
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
    echo  OK
)
if !errorlevel! neq 0 (
    echo  FAILED - enable manually via System Properties.
    pause
    goto :main_menu
)

:cr_enabled
if !SR_DISABLED! equ 0 echo  OK

REM Bypass 24-hour limit temporarily
<nul set /p "=  Bypassing 24-hour creation limit..."
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /t REG_DWORD /d 0 /f >nul 2>&1
echo  OK

REM Create the restore point using wmic
echo  Creating restore point...
<nul set /p "=  Method 1: WMIC..."
wmic.exe /Namespace:\\root\default Path SystemRestore Call CreateRestorePoint "Pre-Autodesk Uninstall", 100, 12 >nul 2>&1
if !errorlevel! equ 0 goto :cr_wmic_ok

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
pause
goto :main_menu

:cr_wmic_ok
echo  SUCCESS
echo  RESTORE POINT: Created >> "!LOGFILE!"
echo.
echo  Restore point created successfully.
echo.
pause
goto :main_menu

:cr_ps_ok
echo  SUCCESS
echo  RESTORE POINT: Created via PowerShell >> "!LOGFILE!"
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
echo   SCANNING FOR INSTALLED AUTODESK PRODUCTS
echo  ========================================================
echo.
echo === SCAN START %date% %time% === >> "!LOGFILE!"
set PROD_COUNT=0

<nul set /p "=  [1/5] Scanning 64-bit registry"
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
                <nul set /p "= +!PROD_COUNT!"
            )
        )
    )
)
echo  done. [!REG64_SCAN! keys, !PROD_COUNT! found]

<nul set /p "=  [2/5] Scanning 32-bit registry"
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
                    <nul set /p "= +!PROD_COUNT!"
                )
            )
        )
    )
)
set /a NEW32=PROD_COUNT-BEFORE32
echo  done. [!REG32_SCAN! keys, !NEW32! new]

<nul set /p "=  [3/5] Classifying products"
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
    echo "!P_NAME_%%i!" | findstr /i "Enabler Plugin Add-in Addon Content Pack Language Service Pack Object" >nul 2>&1
    if !errorlevel! equ 0 set "P_PRIO_%%i=1"
    echo "!P_NAME_%%i!" | findstr /i "Material Library Medium Resolution Base Resolution" >nul 2>&1
    if !errorlevel! equ 0 set "P_PRIO_%%i=5"
    echo "!P_NAME_%%i!" | findstr /i "Material Library Medium" >nul 2>&1
    if !errorlevel! equ 0 set "P_PRIO_%%i=4"
    echo "!P_NAME_%%i!" | findstr /i "Desktop App" >nul 2>&1
    if !errorlevel! equ 0 set "P_PRIO_%%i=6"
    echo "!P_NAME_%%i!" | findstr /i "Single Sign" >nul 2>&1
    if !errorlevel! equ 0 set "P_PRIO_%%i=7"
    echo "!P_NAME_%%i!" | findstr /i "Genuine" >nul 2>&1
    if !errorlevel! equ 0 set "P_PRIO_%%i=8"
    <nul set /p "=."
)
echo  done.

<nul set /p "=  [4/5] Checking shared components"
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
echo  done.

<nul set /p "=  [5/5] Checking legacy artifacts"
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
echo  done.

echo.
echo  ========================================================
echo   SCAN COMPLETE: !PROD_COUNT! Autodesk products found
echo  ========================================================
echo.

if !PROD_COUNT! equ 0 (
    echo  No Autodesk products detected.
    echo.
    pause
    goto :main_menu
)

echo  No.  Type   Prio Product Name                           Version
echo  ---  -----  ---- ------------------------------------   ----------
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
                if not exist "%%~x" set "ORPHAN_TAG= [ORPHAN]"
            )
        )
    )
    echo  [%%i]  !P_TYPE_%%i!   [!DPRIO!]  !DNAME!  !DVER!!ORPHAN_TAG!
)
echo.
echo  Priority: [1]=addons first [3]=main products [4-5]=material
echo            libs [6]=desktop app [7]=SSO [8]=genuine svc last
echo  Type: MSI=Classic/Legacy, ODIS=New Installer 2020+
echo.
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
            start /wait "" cmd /c "!UCMD!" >nul 2>&1
            set "UERR=!errorlevel!"
            if !UERR! equ 0 echo  OK
            if !UERR! neq 0 echo  exit:!UERR!
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
                    msiexec /x "{!GUID!}" /qn /norestart
                    set "UERR=!errorlevel!"
                    if !UERR! equ 0 echo  OK
                    if !UERR! neq 0 (
                        echo  code:!UERR! retrying...
                        msiexec /x "{!GUID!}" /qb /norestart
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
                echo  OK
                set "_HANDLED=1"
            )
        )

        if !_HANDLED! equ 0 (
            <nul set /p "=  [GENERIC] Running..."
            start /wait "" cmd /c "!PUNINST!" --mode unattended >nul 2>&1
            echo  OK
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
echo   FULL UNINSTALL + DEEP CLEAN - ALL VERSIONS
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
echo  WARNING: IRREVERSIBLE. Back up custom templates first.
echo.
set /p "FC_CONF=  Type YES to proceed: "
if /i not "!FC_CONF!"=="YES" (
    echo  Aborted.
    pause
    goto :main_menu
)

echo.
echo  === FULL CLEAN START === >> "!LOGFILE!"

REM --- Phase A: Restore point ---
echo  [A] System Restore Point
set /p "RP_ASK=      Create restore point before proceeding? [Y/N]: "
if /i not "!RP_ASK!"=="Y" goto :fc_phase_b

<nul set /p "=      Creating restore point..."
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /t REG_DWORD /d 0 /f >nul 2>&1
wmic.exe /Namespace:\\root\default Path SystemRestore Call CreateRestorePoint "Pre-Autodesk Full Clean", 100, 12 >nul 2>&1
if !errorlevel! equ 0 (
    echo  OK
    goto :fc_phase_b
)
<nul set /p "= WMIC failed, trying PowerShell..."
powershell -ExecutionPolicy Bypass -Command "Checkpoint-Computer -Description 'Pre-Autodesk Full Clean' -RestorePointType 'MODIFY_SETTINGS'" >nul 2>&1
if !errorlevel! equ 0 (
    echo  OK
    goto :fc_phase_b
)
echo  FAILED - continuing anyway.

:fc_phase_b
echo.

REM --- Phase B: Stop everything ---
<nul set /p "=  [B] Stopping services"
echo  PHASE B START %time% >> "!DIAGFILE!"
for %%s in (AdAppMgrSvc AdskAccessServiceHost AdskLicensingService AdskNLM) do (
    sc query "%%s" >nul 2>&1
    if !errorlevel! equ 0 (
        net stop "%%s" >nul 2>&1
        sc config "%%s" start= disabled >nul 2>&1
        <nul set /p "=."
    )
)
net stop "FlexNet Licensing Service 64" >nul 2>&1
net stop "Autodesk Genuine Service" >nul 2>&1
echo  done.
<nul set /p "=      Killing processes"
for %%p in (AdSSO.exe AdskLicensingService.exe AdskLicensingAgent.exe AdskIdentityManager.exe GenuineService.exe AdAppMgrSvc.exe AutodeskDesktopApp.exe RevitAccelerator.exe acad.exe lmgrd.exe adskflex.exe AdskAccessServiceHost.exe AdskAccessCore.exe ADPClientService.exe AcEventSync.exe FNPLicensingService64.exe) do (
    taskkill /f /im "%%p" >nul 2>&1
    if !errorlevel! equ 0 <nul set /p "=."
)
echo  done.
echo.

REM --- Phase C: Uninstall in dependency order (multi-pass) ---
echo  [C] Uninstalling !PROD_COUNT! products in dependency order...
echo  PHASE C START %time% >> "!DIAGFILE!"
echo      Multi-pass: retries until all removed or stuck.
echo.
set UNINST_OK=0
set UNINST_FAIL=0

REM === PASS 1: Priority-ordered uninstall ===
echo      === Pass 1 of 4: Dependency-ordered removal ===
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
        echo      --- Priority %%P: !PASS_LABEL! ---
        for /l %%i in (1,1,!PROD_COUNT!) do (
            if "!P_PRIO_%%i!"=="%%P" (
                set "PNAME=!P_NAME_%%i!"
                set "PUNINST=!P_UNINST_%%i!"
                set "PTYPE=!P_TYPE_%%i!"
                set "_HANDLED=0"
                <nul set /p "=      !PNAME:~0,50!"
                echo  [%%i] !PTYPE! !PNAME! >> "!LOGFILE!"

                if not defined PUNINST (
                    echo  [SKIP:no uninstaller]
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
                        <nul set /p "=..."
                        del /f "!LOGDIR!\odis_out.tmp" >nul 2>&1
                        start /wait "" cmd /c "!UCMD!" >"!LOGDIR!\odis_out.tmp" 2>&1
                        set "UERR=!errorlevel!"
                        echo   EXIT: !UERR! >> "!LOGFILE!"
                        echo   DIAG: ODIS exit=!UERR! >> "!DIAGFILE!"
                        if !UERR! neq 0 (
                            echo   ODIS OUTPUT: >> "!DIAGFILE!"
                            type "!LOGDIR!\odis_out.tmp" >> "!DIAGFILE!" 2>nul
                        )
                        del /f "!LOGDIR!\odis_out.tmp" >nul 2>&1
                        if !UERR! equ 0 (
                            echo  OK
                            set /a UNINST_OK+=1
                        )
                        if !UERR! neq 0 (
                            echo  exit:!UERR!
                            set /a UNINST_FAIL+=1
                        )
                    )
                    if !ODIS_META_OK! equ 0 (
                        echo  [SKIP:metadata gone - will force-clean]
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
                            echo   CMD: msiexec /x {!GUID!} /qn /norestart >> "!LOGFILE!"
                            <nul set /p "=..."
                            msiexec /x "{!GUID!}" /qn /norestart >nul 2>&1
                            set "UERR=!errorlevel!"
                            echo   EXIT: !UERR! >> "!LOGFILE!"
                            if !UERR! equ 0 (
                                echo  OK
                                set /a UNINST_OK+=1
                            )
                            if !UERR! neq 0 (
                                echo  MSI:!UERR!
                                set /a UNINST_FAIL+=1
                            )
                        )
                        if not defined GUID (
                            echo  [SKIP:no GUID]
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
                        <nul set /p "=..."
                        start /wait "" cmd /c "!PUNINST!" /q >nul 2>&1
                        set "UERR=!errorlevel!"
                        echo   EXIT: !UERR! >> "!LOGFILE!"
                        echo  OK
                        set /a UNINST_OK+=1
                        set "_HANDLED=1"
                    )
                )

                if !_HANDLED! equ 0 (
                    echo   CMD: GENERIC !PUNINST! --mode unattended >> "!LOGFILE!"
                    <nul set /p "=..."
                    start /wait "" cmd /c "!PUNINST!" --mode unattended >nul 2>&1
                    set "UERR=!errorlevel!"
                    echo   EXIT: !UERR! >> "!LOGFILE!"
                    if !UERR! equ 0 (
                        echo  OK
                        set /a UNINST_OK+=1
                    )
                    if !UERR! neq 0 (
                        echo  exit:!UERR!
                        set /a UNINST_FAIL+=1
                    )
                )
            )
        )
    )
)
echo.
echo      Pass 1 result: !UNINST_OK! uninstalled, !UNINST_FAIL! failed.
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
                            start /wait "" cmd /c "!R_CMD!" >"!LOGDIR!\odis_out.tmp" 2>&1
                            set "RERR=!errorlevel!"
                            if !RERR! equ 0 (
                                echo  OK
                                set /a RETRY_OK+=1
                            )
                            if !RERR! neq 0 (
                                echo  exit:!RERR!
                                echo   RETRY ODIS OUTPUT: >> "!DIAGFILE!"
                                type "!LOGDIR!\odis_out.tmp" >> "!DIAGFILE!" 2>nul
                            )
                            del /f "!LOGDIR!\odis_out.tmp" >nul 2>&1
                        )
                        if !R_XML_OK! equ 0 (
                            echo  [SKIP:metadata gone]
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
                                msiexec /x "{!R_GUID!}" /qn /norestart >nul 2>&1
                                if !errorlevel! equ 0 (
                                    echo  OK
                                    set /a RETRY_OK+=1
                                )
                                if !errorlevel! neq 0 echo  MSI:!errorlevel!
                            )
                            if not defined R_GUID echo  [no GUID]
                        )
                        echo "!R_US!" | findstr /i "MsiExec" >nul 2>&1
                        if !errorlevel! neq 0 (
                            <nul set /p "=..."
                            start /wait "" cmd /c "!R_US!" --mode unattended >nul 2>&1
                            echo  OK
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
                            msiexec /x "{!R_GUID!}" /qn /norestart >nul 2>&1
                            if !errorlevel! equ 0 (
                                echo  OK
                                set /a RETRY_OK+=1
                            )
                            if !errorlevel! neq 0 echo  MSI:!errorlevel!
                        )
                    )
                    echo "!R_US!" | findstr /i "MsiExec" >nul 2>&1
                    if !errorlevel! neq 0 (
                        <nul set /p "=..."
                        start /wait "" cmd /c "!R_US!" --mode unattended >nul 2>&1
                        echo  OK
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
echo      TOTAL: !UNINST_OK! uninstalled across all passes.
echo  PHASE C TOTAL: !UNINST_OK! ok >> "!LOGFILE!"
echo.

REM --- Phase C2: Force-remove stuck registry entries ---
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
                <nul set /p "=      [FORCE] !O_DN:~0,40!..."
                echo  FORCE-DEL: !O_DN! >> "!LOGFILE!"
                echo  KEY: !O_KEY! >> "!LOGFILE!"
                reg delete "!O_KEY!" /f >nul 2>&1
                if !errorlevel! equ 0 (
                    echo  reg deleted.
                    set /a FORCE_DEL+=1
                )
                if !errorlevel! neq 0 echo  FAILED.
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
                <nul set /p "=      [FORCE] !O_DN:~0,40!..."
                echo  FORCE-DEL: !O_DN! >> "!LOGFILE!"
                reg delete "!O_KEY!" /f >nul 2>&1
                if !errorlevel! equ 0 (
                    echo  reg deleted.
                    set /a FORCE_DEL+=1
                )
                if !errorlevel! neq 0 echo  FAILED.
            )
        )
    )
)
if !FORCE_DEL! gtr 0 (
    echo      Force-removed !FORCE_DEL! stuck registry entries.
    echo  PHASE C2: !FORCE_DEL! force-removed >> "!LOGFILE!"
)
echo.

REM --- Phase D: Shared components ---
echo  [D] Removing shared components...
if exist "C:\Program Files (x86)\Autodesk\Autodesk Desktop App\removeAdAppMgr.exe" (
    <nul set /p "=      Desktop App..."
    rd /s /q "%ProgramData%\Autodesk\SDS" 2>nul
    start /wait "" "C:\Program Files (x86)\Autodesk\Autodesk Desktop App\removeAdAppMgr.exe" --mode unattended
    timeout /t 3 >nul
    echo  OK
)
if exist "C:\Program Files\Autodesk\AdskIdentityManager\uninstall.exe" (
    <nul set /p "=      Identity Manager..."
    start /wait "" "C:\Program Files\Autodesk\AdskIdentityManager\uninstall.exe" --mode unattended
    timeout /t 3 >nul
    echo  OK
)
if exist "C:\Program Files\Autodesk\AdODIS\V1\RemoveODIS.exe" (
    del /f "C:\ProgramData\Autodesk\ODIS\AdODISInstaller.run.lock" >nul 2>&1
    <nul set /p "=      RemoveODIS..."
    start /wait "" "C:\Program Files\Autodesk\AdODIS\V1\RemoveODIS.exe" --mode unattended
    timeout /t 3 >nul
    echo  OK
)
if exist "C:\Program Files (x86)\Common Files\Autodesk Shared\AdskLicensing\uninstall.exe" (
    <nul set /p "=      AdskLicensing..."
    start /wait "" "C:\Program Files (x86)\Common Files\Autodesk Shared\AdskLicensing\uninstall.exe" --mode unattended
    timeout /t 3 >nul
    echo  OK
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
            start /wait "" "%%h\AdskUninstallHelper.exe" >nul 2>&1
            <nul set /p "=."
        )
    )
    echo  done.
)
del /f "C:\ProgramData\Autodesk\Adlm\ProductInformation.pit" >nul 2>&1
del /f "%LOCALAPPDATA%\Autodesk\Genuine Autodesk Service\id.dat" >nul 2>&1
echo      Phase D complete.
echo  PHASE D END %time% >> "!DIAGFILE!"
echo.

REM --- Phase E: Delete folders ---
echo  [E] Deleting Autodesk folders...
echo  PHASE E START %time% >> "!DIAGFILE!"
set DOK=0
set DFL=0
set "LOCKED_LIST="
for %%d in (
    "C:\Program Files\Autodesk"
    "C:\Program Files\Common Files\Autodesk Shared"
    "C:\Program Files (x86)\Autodesk"
    "C:\Program Files (x86)\Common Files\Autodesk Shared"
    "C:\ProgramData\Autodesk"
    "C:\Users\Public\Documents\Autodesk"
    "C:\Autodesk"
    "C:\Program Files\Common Files\Macrovision Shared"
) do (
    if exist %%d (
        <nul set /p "=      %%~d..."
        rd /s /q %%d 2>nul
        if exist %%d (
            REM Try takeown + icacls then retry
            takeown /f %%d /r /d y >nul 2>&1
            icacls %%d /grant Everyone:F /t /c /q >nul 2>&1
            rd /s /q %%d 2>nul
        )
        if not exist %%d (
            echo  deleted.
            set /a DOK+=1
        )
        if exist %%d (
            echo  LOCKED.
            set /a DFL+=1
            set "LOCKED_LIST=!LOCKED_LIST! %%~d"
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
            icacls "%%~d" /grant Everyone:F /t /c /q >nul 2>&1
            rd /s /q "%%~d" 2>nul
        )
        if not exist "%%~d" (
            echo  deleted.
            set /a DOK+=1
        )
        if exist "%%~d" (
            echo  LOCKED.
            set /a DFL+=1
            set "LOCKED_LIST=!LOCKED_LIST! %%~d"
            echo   LOCKED: %%~d >> "!DIAGFILE!"
        )
    )
)
echo      !DOK! deleted, !DFL! locked.
REM If folders are locked, create a reboot cleanup script
if !DFL! gtr 0 (
    set "REBOOT_BAT=!LOGDIR!\reboot_cleanup.bat"
    echo @echo off > "!REBOOT_BAT!"
    echo timeout /t 10 /nobreak ^>nul >> "!REBOOT_BAT!"
    for %%d in (
        "C:\Program Files\Autodesk"
        "C:\Program Files\Common Files\Autodesk Shared"
        "C:\Program Files (x86)\Autodesk"
        "C:\Program Files (x86)\Common Files\Autodesk Shared"
        "C:\ProgramData\Autodesk"
        "C:\Users\Public\Documents\Autodesk"
        "C:\Autodesk"
        "C:\Program Files\Common Files\Macrovision Shared"
    ) do (
        echo if exist %%d rd /s /q %%d >> "!REBOOT_BAT!"
    )
    echo if exist "%APPDATA%\Autodesk" rd /s /q "%APPDATA%\Autodesk" >> "!REBOOT_BAT!"
    echo if exist "%LOCALAPPDATA%\Autodesk" rd /s /q "%LOCALAPPDATA%\Autodesk" >> "!REBOOT_BAT!"
    echo if exist "%LOCALAPPDATA%\Programs\Autodesk" rd /s /q "%LOCALAPPDATA%\Programs\Autodesk" >> "!REBOOT_BAT!"
    echo del /f "!REBOOT_BAT!" >> "!REBOOT_BAT!"
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v "AutodeskCleanup" /t REG_SZ /d "\"!REBOOT_BAT!\"" /f >nul 2>&1
    echo      Reboot cleanup script scheduled.
    echo   REBOOT CLEANUP SCHEDULED >> "!LOGFILE!"
)
echo.

REM --- Phase E2: Shortcut cleanup ---
echo  [E2] Removing Autodesk shortcuts...
set SC_DEL=0
REM Desktop shortcuts - current user and public
for %%L in ("%USERPROFILE%\Desktop" "C:\Users\Public\Desktop") do (
    if exist "%%~L" (
        for %%f in ("%%~L\*.lnk") do (
            echo "%%~nf" | findstr /i "Autodesk AutoCAD Revit Inventor Civil Maya Navisworks DWG Alias Moldflow Fusion Advance Steel Design Review 3ds Max" >nul 2>&1
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
            echo "%%~nf" | findstr /i "Autodesk AutoCAD Revit Inventor DWG Design Review" >nul 2>&1
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
            echo "%%~nf" | findstr /i "Autodesk AutoCAD Revit Inventor Maya Navisworks DWG Alias Design Review 3ds Max" >nul 2>&1
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

REM --- Phase F: Caches ---
echo  [F] Cleaning licensing and cache artifacts...
if exist "C:\ProgramData\FLEXnet" (
    <nul set /p "=      FLEXnet adsk files..."
    attrib -h -s -r "C:\ProgramData\FLEXnet\adsk*" >nul 2>&1
    del /f /q /a "C:\ProgramData\FLEXnet\adsk*" >nul 2>&1
    echo  done.
)
if exist "C:\ProgramData\Autodesk\CLM" (
    <nul set /p "=      CLM license data..."
    rd /s /q "C:\ProgramData\Autodesk\CLM" 2>nul
    echo  done.
)
if exist "%APPDATA%\Autodesk\ADUT" (
    <nul set /p "=      ADUT transition data..."
    rd /s /q "%APPDATA%\Autodesk\ADUT" 2>nul
    echo  done.
)
if exist "%LOCALAPPDATA%\Temp\odis_download_dest" (
    <nul set /p "=      ODIS download cache..."
    rd /s /q "%LOCALAPPDATA%\Temp\odis_download_dest" 2>nul
    echo  done.
)
if exist "%LOCALAPPDATA%\Autodesk\Web Services\LoginState.xml" (
    <nul set /p "=      LoginState.xml..."
    del /f "%LOCALAPPDATA%\Autodesk\Web Services\LoginState.xml" >nul 2>&1
    echo  done.
)
<nul set /p "=      Temp folder..."
del /q /f "%temp%\*" >nul 2>&1
for /d %%d in ("%temp%\*") do rd /s /q "%%d" 2>nul
echo  done.
echo.

REM --- Phase G: Services, tasks, firewall ---
echo  [G] Removing services, tasks, firewall rules...
<nul set /p "=      Services"
for %%s in (AdskLicensingService AdskAccessServiceHost AdAppMgrSvc AdskNLM) do (
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
for /f "tokens=2 delims=:" %%r in ('netsh advfirewall firewall show rule name^=all 2^>nul ^| findstr /i "Rule Name:" ^| findstr /i "Autodesk AutoCAD Revit Inventor Civil Maya 3dsMax Navisworks"') do (
    set "RN=%%r"
    set "RN=!RN:~1!"
    netsh advfirewall firewall delete rule name="!RN!" >nul 2>&1
    set /a FW_DEL+=1
    <nul set /p "=."
)
echo  !FW_DEL! removed.
echo.

REM --- Phase H: Registry ---
echo  [H] Backing up and removing registry keys...
echo  PHASE H START %time% >> "!DIAGFILE!"
set RDEL=0
for %%k in (
    "HKLM\SOFTWARE\Autodesk"
    "HKCU\SOFTWARE\Autodesk"
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
        echo  deleted.
        set /a RDEL+=1
    )
)
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v "ADSKFLEX_LICENSE_FILE" >nul 2>&1
if !errorlevel! equ 0 (
    reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v "ADSKFLEX_LICENSE_FILE" /f >nul 2>&1
    echo      ADSKFLEX_LICENSE_FILE env var... deleted.
    set /a RDEL+=1
)
echo      !RDEL! registry items removed. Backups in !LOGDIR!
echo.

REM --- Phase I: Genuine Service (LAST) ---
<nul set /p "=  [I] Removing Genuine Service..."
sc stop "Autodesk Genuine Service" >nul 2>&1
sc delete "Autodesk Genuine Service" >nul 2>&1
rd /s /q "C:\Program Files (x86)\Autodesk\Genuine Service" 2>nul
rd /s /q "%LOCALAPPDATA%\Programs\Autodesk\Genuine Service" 2>nul
echo  done.
echo.
echo  === FULL CLEAN COMPLETE === >> "!LOGFILE!"

echo  ========================================================
echo   ALL PHASES COMPLETE - RUNNING VERIFICATION...
echo  ========================================================
echo.
pause
goto :run_verify

REM ============================================================
REM DEEP CLEAN ONLY
REM ============================================================
:deep_clean
cls
echo.
echo  ========================================================
echo   DEEP CLEAN - Remove All Remnants
echo   Covers legacy pre-2020 and modern 2020+ artifacts
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

echo.
REM Offer restore point
set /p "DC_RP=  Create restore point first? [Y/N]: "
if /i not "!DC_RP!"=="Y" goto :dc_after_rp

<nul set /p "=  Creating restore point..."
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /t REG_DWORD /d 0 /f >nul 2>&1
wmic.exe /Namespace:\\root\default Path SystemRestore Call CreateRestorePoint "Pre-Autodesk Deep Clean", 100, 12 >nul 2>&1
if !errorlevel! equ 0 (
    echo  OK
    goto :dc_after_rp
)
powershell -ExecutionPolicy Bypass -Command "Checkpoint-Computer -Description 'Pre-Autodesk Deep Clean' -RestorePointType 'MODIFY_SETTINGS'" >nul 2>&1
if !errorlevel! equ 0 (
    echo  OK via PowerShell
    goto :dc_after_rp
)
echo  FAILED - continuing.

:dc_after_rp

echo.
<nul set /p "=  Stopping services"
for %%s in (AdAppMgrSvc AdskAccessServiceHost AdskLicensingService AdskNLM) do (
    sc query "%%s" >nul 2>&1
    if !errorlevel! equ 0 (
        net stop "%%s" >nul 2>&1
        sc config "%%s" start= disabled >nul 2>&1
        <nul set /p "=."
    )
)
net stop "FlexNet Licensing Service 64" >nul 2>&1
net stop "Autodesk Genuine Service" >nul 2>&1
echo  done.
<nul set /p "=  Killing processes"
for %%p in (AdSSO.exe AdskLicensingService.exe AdskLicensingAgent.exe AdskIdentityManager.exe GenuineService.exe AdAppMgrSvc.exe AutodeskDesktopApp.exe RevitAccelerator.exe acad.exe lmgrd.exe adskflex.exe AdskAccessServiceHost.exe AdskAccessCore.exe ADPClientService.exe AcEventSync.exe FNPLicensingService64.exe) do (
    taskkill /f /im "%%p" >nul 2>&1
    if !errorlevel! equ 0 <nul set /p "=."
)
echo  done.

echo.
echo  Running component uninstallers...
if exist "C:\Program Files (x86)\Autodesk\Autodesk Desktop App\removeAdAppMgr.exe" (
    <nul set /p "=    Desktop App..."
    rd /s /q "%ProgramData%\Autodesk\SDS" 2>nul
    start /wait "" "C:\Program Files (x86)\Autodesk\Autodesk Desktop App\removeAdAppMgr.exe" --mode unattended
    echo  OK
)
if exist "C:\Program Files\Autodesk\AdskIdentityManager\uninstall.exe" (
    <nul set /p "=    Identity Manager..."
    start /wait "" "C:\Program Files\Autodesk\AdskIdentityManager\uninstall.exe" --mode unattended
    echo  OK
)
if exist "C:\Program Files\Autodesk\AdODIS\V1\RemoveODIS.exe" (
    del /f "C:\ProgramData\Autodesk\ODIS\AdODISInstaller.run.lock" >nul 2>&1
    <nul set /p "=    RemoveODIS..."
    start /wait "" "C:\Program Files\Autodesk\AdODIS\V1\RemoveODIS.exe" --mode unattended
    echo  OK
)
if exist "C:\Program Files (x86)\Common Files\Autodesk Shared\AdskLicensing\uninstall.exe" (
    <nul set /p "=    AdskLicensing..."
    start /wait "" "C:\Program Files (x86)\Common Files\Autodesk Shared\AdskLicensing\uninstall.exe" --mode unattended
    echo  OK
)
if exist "C:\ProgramData\Autodesk\Uninstallers" (
    <nul set /p "=    AdskUninstallHelpers"
    for /d %%h in ("C:\ProgramData\Autodesk\Uninstallers\*") do (
        if exist "%%h\AdskUninstallHelper.exe" (
            start /wait "" "%%h\AdskUninstallHelper.exe" >nul 2>&1
            <nul set /p "=."
        )
    )
    echo  done.
)
del /f "C:\ProgramData\Autodesk\Adlm\ProductInformation.pit" >nul 2>&1
del /f "%LOCALAPPDATA%\Autodesk\Genuine Autodesk Service\id.dat" >nul 2>&1

echo.
echo  Cleaning licensing artifacts...
if exist "C:\ProgramData\FLEXnet" (
    <nul set /p "=    FLEXnet..."
    attrib -h -s -r "C:\ProgramData\FLEXnet\adsk*" >nul 2>&1
    del /f /q /a "C:\ProgramData\FLEXnet\adsk*" >nul 2>&1
    echo  done.
)
if exist "C:\ProgramData\Autodesk\CLM" (
    <nul set /p "=    CLM..."
    rd /s /q "C:\ProgramData\Autodesk\CLM" 2>nul
    echo  done.
)
if exist "%APPDATA%\Autodesk\ADUT" (
    <nul set /p "=    ADUT..."
    rd /s /q "%APPDATA%\Autodesk\ADUT" 2>nul
    echo  done.
)
rd /s /q "%LOCALAPPDATA%\Temp\odis_download_dest" 2>nul
del /f "%LOCALAPPDATA%\Autodesk\Web Services\LoginState.xml" >nul 2>&1
<nul set /p "=    Temp folder..."
del /q /f "%temp%\*" >nul 2>&1
for /d %%d in ("%temp%\*") do rd /s /q "%%d" 2>nul
echo  done.

echo.
echo  Deleting folders...
for %%d in (
    "C:\Program Files\Autodesk"
    "C:\Program Files\Common Files\Autodesk Shared"
    "C:\Program Files (x86)\Autodesk"
    "C:\Program Files (x86)\Common Files\Autodesk Shared"
    "C:\ProgramData\Autodesk"
    "C:\Users\Public\Documents\Autodesk"
    "C:\Autodesk"
    "C:\Program Files\Common Files\Macrovision Shared"
) do (
    if exist %%d (
        <nul set /p "=    %%~d..."
        rd /s /q %%d 2>nul
        if exist %%d (
            takeown /f %%d /r /d y >nul 2>&1
            icacls %%d /grant Everyone:F /t /c /q >nul 2>&1
            rd /s /q %%d 2>nul
        )
        if not exist %%d echo  deleted.
        if exist %%d echo  LOCKED.
    )
)
for %%d in ("%APPDATA%\Autodesk" "%LOCALAPPDATA%\Autodesk" "%LOCALAPPDATA%\Programs\Autodesk") do (
    if exist "%%~d" (
        <nul set /p "=    %%~d..."
        rd /s /q "%%~d" 2>nul
        if exist "%%~d" (
            takeown /f "%%~d" /r /d y >nul 2>&1
            icacls "%%~d" /grant Everyone:F /t /c /q >nul 2>&1
            rd /s /q "%%~d" 2>nul
        )
        if not exist "%%~d" echo  deleted.
        if exist "%%~d" echo  LOCKED.
    )
)

echo.
echo  Removing shortcuts...
set DC_SC=0
for %%L in ("%USERPROFILE%\Desktop" "C:\Users\Public\Desktop") do (
    if exist "%%~L" (
        for %%f in ("%%~L\*.lnk") do (
            echo "%%~nf" | findstr /i "Autodesk AutoCAD Revit Inventor Civil Maya Navisworks DWG Alias Moldflow Fusion Advance Steel Design Review 3ds Max" >nul 2>&1
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
            echo "%%~nf" | findstr /i "Autodesk AutoCAD Revit Inventor DWG Design Review" >nul 2>&1
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
            echo "%%~nf" | findstr /i "Autodesk AutoCAD Revit Inventor Maya Navisworks DWG Alias Design Review 3ds Max" >nul 2>&1
            if !errorlevel! equ 0 (
                del /f "%%f" >nul 2>&1
                set /a DC_SC+=1
            )
        )
    )
)
echo    !DC_SC! shortcuts removed.

echo.
<nul set /p "=  Deleting services"
for %%s in (AdskLicensingService AdskAccessServiceHost AdAppMgrSvc AdskNLM) do (
    sc query "%%s" >nul 2>&1
    if !errorlevel! equ 0 (
        sc delete "%%s" >nul 2>&1
        <nul set /p "= %%s"
    )
)
sc delete "Autodesk Genuine Service" >nul 2>&1
echo  done.

echo.
<nul set /p "=  Tasks and firewall"
for /f "tokens=1 delims=," %%n in ('schtasks /query /fo csv /nh 2^>nul ^| findstr /i "Autodesk"') do (
    schtasks /delete /tn "%%~n" /f >nul 2>&1
    <nul set /p "=."
)
for /f "tokens=2 delims=:" %%r in ('netsh advfirewall firewall show rule name^=all 2^>nul ^| findstr /i "Rule Name:" ^| findstr /i "Autodesk AutoCAD Revit Inventor Civil Maya 3dsMax Navisworks"') do (
    set "RN=%%r"
    set "RN=!RN:~1!"
    netsh advfirewall firewall delete rule name="!RN!" >nul 2>&1
    <nul set /p "=."
)
echo  done.

echo.
echo  Backing up and deleting registry...
for %%k in (
    "HKLM\SOFTWARE\Autodesk"
    "HKCU\SOFTWARE\Autodesk"
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
        echo  deleted.
    )
)
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v "ADSKFLEX_LICENSE_FILE" >nul 2>&1
if !errorlevel! equ 0 (
    reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v "ADSKFLEX_LICENSE_FILE" /f >nul 2>&1
    echo    ADSKFLEX_LICENSE_FILE... deleted.
)

echo.
<nul set /p "=  Removing Genuine Service..."
rd /s /q "C:\Program Files (x86)\Autodesk\Genuine Service" 2>nul
rd /s /q "%LOCALAPPDATA%\Programs\Autodesk\Genuine Service" 2>nul
echo  done.

echo.
echo  Deep clean complete.
echo  === DEEP CLEAN COMPLETE === >> "!LOGFILE!"
echo.
pause
goto :run_verify

REM ============================================================
REM FINAL VERIFICATION
echo  VERIFICATION START %time% >> "!DIAGFILE!"
REM ============================================================
:run_verify
cls
echo.
echo  ========================================================
echo   FINAL VERIFICATION
echo  VERIFICATION START %time% >> "!DIAGFILE!"
echo  ========================================================
echo.
set RM=0

<nul set /p "=  Installed products..."
set VP=0
for /f "tokens=2,*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s /v "Publisher" 2^>nul ^| findstr /i "Autodesk"') do set /a VP+=1
for /f "tokens=2,*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" /s /v "Publisher" 2^>nul ^| findstr /i "Autodesk"') do set /a VP+=1
if !VP! gtr 0 (
    echo  !VP! REMAINING
    set /a RM+=VP
)
if !VP! equ 0 echo  CLEAN

<nul set /p "=  Processes..."
set PR=0
for %%p in (AdSSO AdskLicensing GenuineService AdAppMgr AutodeskDesktopApp acad lmgrd adskflex) do (
    tasklist /fi "imagename eq %%p*" 2>nul | findstr /i "%%p" >nul 2>&1
    if !errorlevel! equ 0 set /a PR+=1
)
if !PR! gtr 0 (
    echo  !PR! REMAINING
    set /a RM+=PR
)
if !PR! equ 0 echo  CLEAN

<nul set /p "=  Services..."
set SR=0
for %%s in (AdskLicensingService AdskAccessServiceHost AdAppMgrSvc AdskNLM) do (
    sc query "%%s" >nul 2>&1
    if !errorlevel! equ 0 set /a SR+=1
)
if !SR! gtr 0 (
    echo  !SR! REMAINING
    set /a RM+=SR
)
if !SR! equ 0 echo  CLEAN

<nul set /p "=  Folders..."
set FR=0
for %%d in (
    "C:\Program Files\Autodesk"
    "C:\Program Files\Common Files\Autodesk Shared"
    "C:\Program Files (x86)\Autodesk"
    "C:\Program Files (x86)\Common Files\Autodesk Shared"
    "C:\ProgramData\Autodesk"
    "C:\Autodesk"
    "C:\Program Files\Common Files\Macrovision Shared"
) do (
    if exist %%d set /a FR+=1
)
if !FR! gtr 0 (
    echo  !FR! REMAINING
    set /a RM+=FR
)
if !FR! equ 0 echo  CLEAN

<nul set /p "=  Registry keys..."
set RR=0
for %%k in ("HKLM\SOFTWARE\Autodesk" "HKCU\SOFTWARE\Autodesk" "HKLM\SOFTWARE\WOW6432Node\Autodesk" "HKLM\SOFTWARE\Macrovision") do (
    reg query %%k >nul 2>&1
    if !errorlevel! equ 0 set /a RR+=1
)
if !RR! gtr 0 (
    echo  !RR! REMAINING
    set /a RM+=RR
)
if !RR! equ 0 echo  CLEAN

<nul set /p "=  Legacy licensing..."
set LL=0
if exist "C:\ProgramData\Autodesk\CLM" set /a LL+=1
if exist "C:\ProgramData\FLEXnet" (
    dir /b "C:\ProgramData\FLEXnet\adsk*" >nul 2>&1
    if !errorlevel! equ 0 set /a LL+=1
)
if !LL! gtr 0 (
    echo  !LL! REMAINING
    set /a RM+=LL
)
if !LL! equ 0 echo  CLEAN

<nul set /p "=  Env variables..."
set EV=0
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v "ADSKFLEX_LICENSE_FILE" >nul 2>&1
if !errorlevel! equ 0 set /a EV+=1
if !EV! gtr 0 (
    echo  ADSKFLEX SET
    set /a RM+=EV
)
if !EV! equ 0 echo  CLEAN

<nul set /p "=  Shortcuts..."
set SV=0
for %%L in ("%USERPROFILE%\Desktop" "C:\Users\Public\Desktop") do (
    if exist "%%~L" (
        for %%f in ("%%~L\*.lnk") do (
            echo "%%~nf" | findstr /i "Autodesk AutoCAD Revit Inventor Civil Maya Navisworks DWG Design Review 3ds Max" >nul 2>&1
            if !errorlevel! equ 0 set /a SV+=1
        )
    )
)
if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Autodesk" set /a SV+=1
if exist "%ProgramData%\Microsoft\Windows\Start Menu\Programs\Autodesk" set /a SV+=1
if !SV! gtr 0 (
    echo  !SV! REMAINING
    set /a RM+=SV
)
if !SV! equ 0 echo  CLEAN

echo.
echo  ========================================================
if !RM! equ 0 (
    echo   CLEAN - No Autodesk remnants detected.
    echo   A reboot is recommended to finalize.
)
if !RM! gtr 0 (
    echo   !RM! ITEMS STILL REMAINING
    echo   Try: reboot then run this script again.
)
echo  ========================================================
echo.
echo  Log and registry backups: !LOGDIR!
echo  VERIFY: !RM! remaining >> "!LOGFILE!"
echo  VERIFY: !RM! remaining >> "!DIAGFILE!"
echo  COMPLETED %date% %time% >> "!DIAGFILE!"
echo.
set /p "RET=  Return to main menu? [Y/N]: "
if /i "!RET!"=="Y" goto :main_menu
pause
exit /b 0
