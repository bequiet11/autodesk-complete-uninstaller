@echo off
setlocal enabledelayedexpansion
chcp 437 >nul 2>&1
title Autodesk Universal Uninstaller v3.2
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
echo Autodesk Universal Uninstaller v3.2 Log - %date% %time% > "!LOGFILE!"

set PROD_COUNT=0

REM Detect Windows version for compatibility info
for /f "tokens=4-5 delims=. " %%i in ('ver') do set "WINVER=%%i.%%j"

:main_menu
cls
echo.
echo  ========================================================
echo    AUTODESK UNIVERSAL UNINSTALLER v3.2
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
if /i not "!RP_CONF!"=="Y" (
    goto :main_menu
)

echo.
REM Check if System Restore is enabled on C:
<nul set /p "=  Checking if System Restore is enabled..."
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v "RPSessionInterval" >nul 2>&1
set "SR_DISABLED=0"
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v "DisableSR" >nul 2>&1
if !errorlevel! equ 0 (
    for /f "tokens=3" %%v in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v "DisableSR" 2^>nul ^| findstr "DisableSR"') do (
        if "%%v"=="0x1" set "SR_DISABLED=1"
    )
)
if !SR_DISABLED! equ 1 (
    echo  DISABLED
    echo.
    echo  System Restore is disabled on this machine.
    echo  To enable it: System Properties - System Protection -
    echo  Configure - Turn on system protection.
    echo.
    set /p "SR_ENABLE=  Try to enable it now? [Y/N]: "
    if /i "!SR_ENABLE!"=="Y" (
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
    )
    if /i not "!SR_ENABLE!"=="Y" (
        pause
        goto :main_menu
    )
)
if !SR_DISABLED! equ 0 echo  OK

REM Bypass 24-hour limit temporarily
<nul set /p "=  Bypassing 24-hour creation limit..."
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /t REG_DWORD /d 0 /f >nul 2>&1
echo  OK

REM Create the restore point using wmic (works on Win10+Win11)
echo  Creating restore point...
<nul set /p "=  Method 1: WMIC..."
wmic.exe /Namespace:\\root\default Path SystemRestore Call CreateRestorePoint "Pre-Autodesk Uninstall %date% %time%", 100, 12 >nul 2>&1
set "RP_ERR=!errorlevel!"

if !RP_ERR! equ 0 (
    echo  SUCCESS
    echo  RESTORE POINT: Created %date% %time% >> "!LOGFILE!"
    echo.
    echo  Restore point created successfully.
    echo  Name: "Pre-Autodesk Uninstall %date%"
    echo.
    echo  To restore later: Start - type "Create a restore point"
    echo  - System Restore - choose this restore point.
    echo.
    pause
    goto :main_menu
)

REM Fallback to PowerShell if WMIC fails (newer Win11 builds)
echo  code:!RP_ERR!
<nul set /p "=  Method 2: PowerShell..."
powershell -ExecutionPolicy Bypass -Command "Checkpoint-Computer -Description 'Pre-Autodesk Uninstall' -RestorePointType 'MODIFY_SETTINGS'" >nul 2>&1
set "RP_ERR2=!errorlevel!"

if !RP_ERR2! equ 0 (
    echo  SUCCESS
    echo  RESTORE POINT: Created via PS %date% %time% >> "!LOGFILE!"
    echo.
    echo  Restore point created successfully.
    echo.
    pause
    goto :main_menu
)

echo  FAILED code:!RP_ERR2!
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
    echo  [%%i]  !P_TYPE_%%i!   [!DPRIO!]  !DNAME!  !DVER!
)
echo.
echo  Priority: [1]=addons first [3]=main products [4-5]=material
echo            libs [6]=desktop app [7]=SSO [8]=genuine svc last
echo  Type: MSI=Classic/Legacy, ODIS=New Installer 2020+
echo.
echo  SCAN: !PROD_COUNT! products >> "!LOGFILE!"
for /l %%i in (1,1,!PROD_COUNT!) do (
    echo   [%%i] P!P_PRIO_%%i! !P_TYPE_%%i! !P_NAME_%%i! >> "!LOGFILE!"
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
        if /i "!CONF!"=="Y" (
            echo  UNINSTALL: !PNAME! >> "!LOGFILE!"
            if not defined PUNINST (
                echo  [ERROR] No UninstallString. Try Control Panel.
                goto :sel_done_%%n
            )
            if "!PTYPE!"=="ODIS" goto :sel_odis_%%n
            goto :sel_msi_%%n
        )
        goto :sel_done_%%n

        :sel_odis_%%n
        <nul set /p "=  [ODIS] Running uninstaller"
        set "UCMD=!PUNINST!"
        echo "!UCMD!" | findstr /i "\-q" >nul 2>&1
        if !errorlevel! neq 0 set "UCMD=!UCMD! -q"
        <nul set /p "=..."
        start /wait "" cmd /c "!UCMD!" >nul 2>&1
        set "UERR=!errorlevel!"
        if !UERR! equ 0 echo  OK
        if !UERR! neq 0 echo  exit:!UERR!
        goto :sel_done_%%n

        :sel_msi_%%n
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
                goto :sel_done_%%n
            )
        )
        echo "!PUNINST!" | findstr /i "Setup.exe" >nul 2>&1
        if !errorlevel! equ 0 (
            <nul set /p "=  [LEGACY] Running Setup.exe..."
            start /wait "" cmd /c "!PUNINST!" /q >nul 2>&1
            echo  OK
            goto :sel_done_%%n
        )
        <nul set /p "=  [GENERIC] Running..."
        start /wait "" cmd /c "!PUNINST!" /S /silent /quiet >nul 2>&1
        echo  OK
        :sel_done_%%n
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
if /i "!RP_ASK!"=="Y" (
    <nul set /p "=      Creating restore point..."
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /t REG_DWORD /d 0 /f >nul 2>&1
    wmic.exe /Namespace:\\root\default Path SystemRestore Call CreateRestorePoint "Pre-Autodesk Full Clean %date%", 100, 12 >nul 2>&1
    set "RP_ERR=!errorlevel!"
    if !RP_ERR! equ 0 (
        echo  OK
    )
    if !RP_ERR! neq 0 (
        <nul set /p "= WMIC failed, trying PowerShell..."
        powershell -ExecutionPolicy Bypass -Command "Checkpoint-Computer -Description 'Pre-Autodesk Full Clean' -RestorePointType 'MODIFY_SETTINGS'" >nul 2>&1
        if !errorlevel! equ 0 (
            echo  OK
        )
        if !errorlevel! neq 0 (
            echo  FAILED - continuing anyway.
        )
    )
)
echo.

REM --- Phase B: Stop everything ---
<nul set /p "=  [B] Stopping services"
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
for %%p in (AdSSO.exe AdskLicensingService.exe AdskLicensingAgent.exe AdskIdentityManager.exe GenuineService.exe AdAppMgrSvc.exe AutodeskDesktopApp.exe RevitAccelerator.exe acad.exe lmgrd.exe adskflex.exe AdskAccessServiceHost.exe) do (
    taskkill /f /im "%%p" >nul 2>&1
    if !errorlevel! equ 0 <nul set /p "=."
)
echo  done.
echo.

REM --- Phase C: Uninstall in dependency order (multi-pass) ---
echo  [C] Uninstalling !PROD_COUNT! products in dependency order...
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
                <nul set /p "=      !PNAME:~0,50!"

                if not defined PUNINST (
                    echo  [SKIP:no uninstaller]
                    set /a UNINST_FAIL+=1
                    goto :fc_done_%%i
                )

                if "!PTYPE!"=="ODIS" (
                    set "UCMD=!PUNINST!"
                    echo "!UCMD!" | findstr /i "\-q" >nul 2>&1
                    if !errorlevel! neq 0 set "UCMD=!UCMD! -q"
                    <nul set /p "=..."
                    start /wait "" cmd /c "!UCMD!" >nul 2>&1
                    set "UERR=!errorlevel!"
                    if !UERR! equ 0 (
                        echo  OK
                        set /a UNINST_OK+=1
                    )
                    if !UERR! neq 0 (
                        echo  exit:!UERR!
                        set /a UNINST_FAIL+=1
                    )
                    goto :fc_done_%%i
                )

                echo "!PUNINST!" | findstr /i "MsiExec" >nul 2>&1
                if !errorlevel! equ 0 (
                    set "GUID="
                    for /f "delims={} tokens=2" %%g in ("!PUNINST!") do set "GUID=%%g"
                    if defined GUID (
                        <nul set /p "=..."
                        msiexec /x "{!GUID!}" /qn /norestart >nul 2>&1
                        set "UERR=!errorlevel!"
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
                        set /a UNINST_FAIL+=1
                    )
                    goto :fc_done_%%i
                )

                echo "!PUNINST!" | findstr /i "Setup.exe" >nul 2>&1
                if !errorlevel! equ 0 (
                    <nul set /p "=..."
                    start /wait "" cmd /c "!PUNINST!" /q >nul 2>&1
                    echo  OK
                    set /a UNINST_OK+=1
                    goto :fc_done_%%i
                )

                <nul set /p "=..."
                start /wait "" cmd /c "!PUNINST!" /S /silent /quiet >nul 2>&1
                echo  OK
                set /a UNINST_OK+=1
                :fc_done_%%i
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
                if defined R_US (
                    echo "!R_US!" | findstr /i "Installer.exe AdskUninstallHelper" >nul 2>&1
                    if !errorlevel! equ 0 (
                        set "R_CMD=!R_US!"
                        echo "!R_CMD!" | findstr /i "\-q" >nul 2>&1
                        if !errorlevel! neq 0 set "R_CMD=!R_CMD! -q"
                        <nul set /p "=..."
                        start /wait "" cmd /c "!R_CMD!" >nul 2>&1
                        if !errorlevel! equ 0 (
                            echo  OK
                            set /a RETRY_OK+=1
                        )
                        if !errorlevel! neq 0 echo  exit:!errorlevel!
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
                            start /wait "" cmd /c "!R_US!" /S /silent /quiet >nul 2>&1
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
                        start /wait "" cmd /c "!R_US!" /S /silent /quiet >nul 2>&1
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

REM --- Phase D: Shared components ---
echo  [D] Removing shared components...
if exist "C:\Program Files\Autodesk\AdskIdentityManager\uninstall.exe" (
    <nul set /p "=      Identity Manager..."
    start /wait "" "C:\Program Files\Autodesk\AdskIdentityManager\uninstall.exe"
    timeout /t 3 >nul
    echo  OK
)
if exist "C:\Program Files\Autodesk\AdODIS\V1\RemoveODIS.exe" (
    del /f "C:\ProgramData\Autodesk\ODIS\AdODISInstaller.run.lock" >nul 2>&1
    <nul set /p "=      RemoveODIS..."
    start /wait "" "C:\Program Files\Autodesk\AdODIS\V1\RemoveODIS.exe"
    timeout /t 3 >nul
    echo  OK
)
if exist "C:\Program Files (x86)\Common Files\Autodesk Shared\AdskLicensing\uninstall.exe" (
    <nul set /p "=      AdskLicensing..."
    start /wait "" "C:\Program Files (x86)\Common Files\Autodesk Shared\AdskLicensing\uninstall.exe"
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
echo.

REM --- Phase E: Delete folders ---
echo  [E] Deleting Autodesk folders...
set DOK=0
set DFL=0
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
        if not exist %%d (
            echo  deleted.
            set /a DOK+=1
        )
        if exist %%d (
            echo  LOCKED.
            set /a DFL+=1
        )
    )
)
for %%d in ("%APPDATA%\Autodesk" "%LOCALAPPDATA%\Autodesk" "%LOCALAPPDATA%\Programs\Autodesk") do (
    if exist "%%~d" (
        <nul set /p "=      %%~d..."
        rd /s /q "%%~d" 2>nul
        if not exist "%%~d" (
            echo  deleted.
            set /a DOK+=1
        )
        if exist "%%~d" (
            echo  LOCKED.
            set /a DFL+=1
        )
    )
)
echo      !DOK! deleted, !DFL! locked.
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
if /i "!DC_RP!"=="Y" (
    <nul set /p "=  Creating restore point..."
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /t REG_DWORD /d 0 /f >nul 2>&1
    wmic.exe /Namespace:\\root\default Path SystemRestore Call CreateRestorePoint "Pre-Autodesk Deep Clean %date%", 100, 12 >nul 2>&1
    if !errorlevel! equ 0 (
        echo  OK
    )
    if !errorlevel! neq 0 (
        powershell -ExecutionPolicy Bypass -Command "Checkpoint-Computer -Description 'Pre-Autodesk Deep Clean' -RestorePointType 'MODIFY_SETTINGS'" >nul 2>&1
        if !errorlevel! equ 0 (
            echo  OK via PowerShell
        )
        if !errorlevel! neq 0 echo  FAILED - continuing.
    )
)

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
for %%p in (AdSSO.exe AdskLicensingService.exe AdskLicensingAgent.exe AdskIdentityManager.exe GenuineService.exe AdAppMgrSvc.exe AutodeskDesktopApp.exe RevitAccelerator.exe acad.exe lmgrd.exe adskflex.exe AdskAccessServiceHost.exe) do (
    taskkill /f /im "%%p" >nul 2>&1
    if !errorlevel! equ 0 <nul set /p "=."
)
echo  done.

echo.
echo  Running component uninstallers...
if exist "C:\Program Files\Autodesk\AdskIdentityManager\uninstall.exe" (
    <nul set /p "=    Identity Manager..."
    start /wait "" "C:\Program Files\Autodesk\AdskIdentityManager\uninstall.exe"
    echo  OK
)
if exist "C:\Program Files\Autodesk\AdODIS\V1\RemoveODIS.exe" (
    del /f "C:\ProgramData\Autodesk\ODIS\AdODISInstaller.run.lock" >nul 2>&1
    <nul set /p "=    RemoveODIS..."
    start /wait "" "C:\Program Files\Autodesk\AdODIS\V1\RemoveODIS.exe"
    echo  OK
)
if exist "C:\Program Files (x86)\Common Files\Autodesk Shared\AdskLicensing\uninstall.exe" (
    <nul set /p "=    AdskLicensing..."
    start /wait "" "C:\Program Files (x86)\Common Files\Autodesk Shared\AdskLicensing\uninstall.exe"
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
        if not exist %%d echo  deleted.
        if exist %%d echo  LOCKED.
    )
)
for %%d in ("%APPDATA%\Autodesk" "%LOCALAPPDATA%\Autodesk" "%LOCALAPPDATA%\Programs\Autodesk") do (
    if exist "%%~d" (
        <nul set /p "=    %%~d..."
        rd /s /q "%%~d" 2>nul
        if not exist "%%~d" echo  deleted.
        if exist "%%~d" echo  LOCKED.
    )
)

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
REM ============================================================
:run_verify
cls
echo.
echo  ========================================================
echo   FINAL VERIFICATION
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
echo.
set /p "RET=  Return to main menu? [Y/N]: "
if /i "!RET!"=="Y" goto :main_menu
pause
exit /b 0
