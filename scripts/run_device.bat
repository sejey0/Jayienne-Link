@echo off
setlocal enabledelayedexpansion
title Jayienne Link - App Runner (Device / Web)

cd /d "%~dp0.."

if not exist "%JAVA_HOME%\bin\java.exe" (
    if exist "C:\Program Files\Java\jdk-22\bin\java.exe" (
        set "JAVA_HOME=C:\Program Files\Java\jdk-22"
    )
)

if not exist "pubspec.yaml" (
    echo [ERROR] pubspec.yaml not found in %cd%
    echo Please run this script from the Flutter project scripts folder.
    echo.
    pause
    exit /b 1
)

call :ensure_pub

set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
set "PACKAGE=com.jayiennelink.jayienne_link"
set "IP_FILE=%~dp0.device_ip"

echo ========================================
echo    Jayienne Link - App Runner
echo ========================================
echo.
echo -------- System Specs --------
powershell -NoProfile -Command ^
    "$os = Get-CimInstance Win32_OperatingSystem; " ^
    "$cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name; " ^
    "$gpu = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name; " ^
    "$ram = [math]::Round($os.TotalVisibleMemorySize/1MB,1); " ^
    "$drive = Get-PSDrive -Name $env:SystemDrive.TrimEnd(':'); " ^
    "$free = [math]::Round($drive.Free/1GB,1); " ^
    "$size = [math]::Round(($drive.Free + $drive.Used)/1GB,1); " ^
    "Write-Host \"OS: $($os.Caption) $($os.Version)\"; " ^
    "Write-Host \"CPU: $cpu\"; " ^
    "Write-Host \"RAM: $ram GB\"; " ^
    "Write-Host \"GPU: $gpu\"; " ^
    "Write-Host \"Disk ($($env:SystemDrive)): $free GB free / $size GB\""
echo -----------------------------
echo.

:connection_menu
set "IS_WEB=0"
set "DEVICE_ID="
set "SAVED_IP="
if exist "%IP_FILE%" (
    set /p SAVED_IP=<"%IP_FILE%"
)

echo Where do you want to run the app?
echo.
echo   STABLE WIRELESS ^& USB:
echo   [1] Physical Android Device (USB Cable)
echo   [2] Wireless: USB-to-WiFi Switch (Port 5555 - Most Stable, No Disconnects)
if not "%SAVED_IP%"=="" (
    echo   [3] Wireless: Quick Reconnect to Last Saved IP [%SAVED_IP%:5555]
) else (
    echo   [3] Wireless: Quick Reconnect by IP [Port 5555]
)
echo   [4] Wireless: Android 11+ Pairing Code (Pair ^& auto-switch to Port 5555)
echo   [5] Wireless: Direct IP:Port (Manual)
echo.
echo   STABILITY ^& FIXES:
echo   [6] Fix Wireless Disconnects ^& Phone Sleep (Anti-Sleep ADB Fix)
echo   [7] Restart ADB Server (Fix stuck / offline wireless connection)
echo.
echo   WEB:
echo   [8] Web - Google Chrome
echo   [9] Web - Microsoft Edge
echo.
echo   [0] Exit
echo.
set /p "CONN_TYPE=Enter choice (1-9, 0): "

if "%CONN_TYPE%"=="1" goto check_device_usb
if "%CONN_TYPE%"=="2" goto usb_to_wireless
if "%CONN_TYPE%"=="3" goto quick_reconnect
if "%CONN_TYPE%"=="4" goto wireless_connect
if "%CONN_TYPE%"=="5" goto wireless_manual_connect
if "%CONN_TYPE%"=="6" goto fix_disconnects
if "%CONN_TYPE%"=="7" goto restart_adb
if "%CONN_TYPE%"=="8" goto select_chrome
if "%CONN_TYPE%"=="9" goto select_edge
if "%CONN_TYPE%"=="0" exit /b 0
echo Invalid choice.
echo.
goto connection_menu

:select_chrome
set "DEVICE_ID=chrome"
set "IS_WEB=1"
echo.
echo Target set to Google Chrome (%DEVICE_ID%)
echo.
goto web_menu

:select_edge
set "DEVICE_ID=edge"
set "IS_WEB=1"
echo.
echo Target set to Microsoft Edge (%DEVICE_ID%)
echo.
goto web_menu

:usb_to_wireless
echo.
echo ====================================================
echo   USB-to-WiFi Switch (Ultra-Stable Static Port 5555)
echo ====================================================
echo.
echo 1. Plug in your phone via USB cable with USB Debugging enabled.
echo.
"%ADB%" get-state >nul 2>&1
if errorlevel 1 (
    echo [ERROR] No USB device detected by ADB.
    echo Please make sure:
    echo   - Phone is plugged into this PC via USB cable
    echo   - USB Debugging is enabled in Developer Options
    echo   - You accepted the Allow USB debugging prompt on phone
    echo.
    pause
    goto connection_menu
)

echo Device detected on USB!
echo Detecting phone Wi-Fi IP address...
set "PHONE_IP="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0get_device_ip.ps1" > "%~dp0.temp_ip" 2>nul
if exist "%~dp0.temp_ip" (
    set /p PHONE_IP=<"%~dp0.temp_ip"
    del "%~dp0.temp_ip" >nul 2>&1
)

if "%PHONE_IP%"=="" (
    echo.
    echo [NOTICE] Could not automatically detect Wi-Fi IP.
    set /p "PHONE_IP=Please enter your phone Wi-Fi IP e.g. 192.168.1.100: "
)

if "%PHONE_IP%"=="" (
    echo [ERROR] IP address cannot be empty.
    goto connection_menu
)

echo Phone IP detected: %PHONE_IP%
echo Enabling ADB TCP/IP on static port 5555...
"%ADB%" tcpip 5555
timeout /t 2 /nobreak >nul

echo Connecting wirelessly to %PHONE_IP%:5555...
"%ADB%" connect %PHONE_IP%:5555
timeout /t 1 /nobreak >nul

echo %PHONE_IP%>"%IP_FILE%"
set "DEVICE_ID=%PHONE_IP%:5555"

echo.
echo Applying Anti-Sleep and Wi-Fi stability settings to phone...
"%ADB%" -s %DEVICE_ID% shell settings put global stay_on_while_plugged_in 7 >nul 2>&1
"%ADB%" -s %DEVICE_ID% shell settings put global wifi_sleep_policy 2 >nul 2>&1
"%ADB%" -s %DEVICE_ID% shell dumpsys deviceidle whitelist +%PACKAGE% >nul 2>&1

echo.
echo ====================================================
echo   [SUCCESS] Connected to %DEVICE_ID%!
echo   You can now UNPLUG your USB cable.
echo ====================================================
echo.
goto check_device_ready

:quick_reconnect
if "%SAVED_IP%"=="" (
    echo.
    echo No saved IP found.
    set /p "SAVED_IP=Enter phone Wi-Fi IP address e.g. 192.168.1.100: "
)
if "%SAVED_IP%"=="" goto connection_menu

echo.
echo Connecting to %SAVED_IP%:5555...
"%ADB%" connect %SAVED_IP%:5555
timeout /t 1 /nobreak >nul
set "DEVICE_ID=%SAVED_IP%:5555"

"%ADB%" -s %DEVICE_ID% get-state >nul 2>&1
if errorlevel 1 (
    echo [WARNING] Direct connect failed. Restarting ADB server and retrying...
    "%ADB%" kill-server >nul 2>&1
    "%ADB%" start-server >nul 2>&1
    timeout /t 2 /nobreak >nul
    "%ADB%" connect %SAVED_IP%:5555
    "%ADB%" -s %DEVICE_ID% get-state >nul 2>&1
    if errorlevel 1 (
        echo.
        echo [ERROR] Could not connect to %SAVED_IP%:5555!
        echo Please ensure:
        echo   1. Phone is on the same Wi-Fi network.
        echo   2. Phone Wi-Fi is active and screen is unlocked.
        echo   3. If port 5555 was reset, use Option 2 or Option 4.
        echo.
        pause
        goto connection_menu
    )
)

echo %SAVED_IP%>"%IP_FILE%"
echo.
echo [SUCCESS] Connected to %DEVICE_ID%!
echo.
goto check_device_ready

:wireless_manual_connect
echo.
echo Enter device address e.g. 192.168.1.100:5555 or 192.168.1.100:43567:
set /p "CONNECT_ADDR="
if "%CONNECT_ADDR%"=="" (
    echo [ERROR] Address cannot be empty.
    goto connection_menu
)
echo Connecting to %CONNECT_ADDR%...
"%ADB%" connect %CONNECT_ADDR%
set "DEVICE_ID=%CONNECT_ADDR%"
echo.
goto check_device_ready

:wireless_connect
echo.
echo ========================================
echo   Android 11+ Wireless Debugging Pairing
echo ========================================
echo.
echo On your phone:
echo   1. Go to Settings ^> Developer options
echo   2. Tap 'Wireless debugging' and turn it ON
echo   3. Tap 'Pair device with pairing code'
echo.
echo Enter the PAIRING address e.g. 192.168.1.100:37215:
set /p "PAIR_ADDR="
if "%PAIR_ADDR%"=="" (
    echo [ERROR] Pairing address cannot be empty.
    goto connection_menu
)
echo Enter the 6-digit PAIRING code shown on phone:
set /p "PAIR_CODE="
if "%PAIR_CODE%"=="" (
    echo [ERROR] Pairing code cannot be empty.
    goto connection_menu
)
echo.
echo Pairing with %PAIR_ADDR%...
"%ADB%" pair %PAIR_ADDR% %PAIR_CODE%
if errorlevel 1 (
    echo.
    echo [ERROR] Pairing failed! Check the address and code and try again.
    echo.
    pause
    goto connection_menu
)
echo.
echo Pairing successful!
echo.
echo Now look at the main Wireless Debugging screen on your phone.
echo Enter the CONNECT address e.g. 192.168.1.100:43567:
set /p "CONNECT_ADDR="
if "%CONNECT_ADDR%"=="" (
    echo [ERROR] Connect address cannot be empty.
    goto connection_menu
)
echo.
echo Connecting to %CONNECT_ADDR%...
"%ADB%" connect %CONNECT_ADDR%
timeout /t 1 /nobreak >nul

REM Extract base IP from connect address
set "EXTRACTED_IP="
for /f "tokens=1 delims=:" %%a in ("%CONNECT_ADDR%") do set "EXTRACTED_IP=%%a"

if not "%EXTRACTED_IP%"=="" (
    echo Auto-upgrading connection to static port 5555 [Prevents future disconnects]...
    "%ADB%" -s %CONNECT_ADDR% tcpip 5555 >nul 2>&1
    timeout /t 2 /nobreak >nul
    "%ADB%" connect %EXTRACTED_IP%:5555 >nul 2>&1
    set "DEVICE_ID=%EXTRACTED_IP%:5555"
    echo %EXTRACTED_IP%>"%IP_FILE%"
) else (
    set "DEVICE_ID=%CONNECT_ADDR%"
)

echo.
echo Applying anti-disconnect optimizations...
"%ADB%" -s %DEVICE_ID% shell settings put global stay_on_while_plugged_in 7 >nul 2>&1
"%ADB%" -s %DEVICE_ID% shell settings put global wifi_sleep_policy 2 >nul 2>&1
"%ADB%" -s %DEVICE_ID% shell dumpsys deviceidle whitelist +%PACKAGE% >nul 2>&1

echo.
echo [SUCCESS] Connected to %DEVICE_ID%!
echo.
goto check_device_ready

:fix_disconnects
echo.
echo ====================================================
echo   Wireless Connection Stability ^& Anti-Sleep Setup
echo ====================================================
echo.
echo Applying ADB stability tweaks to all connected devices...
for /f "tokens=1" %%d in ('"%ADB%" devices ^| findstr /v "List of" ^| findstr "device"') do (
    echo Configuring device: %%d
    "%ADB%" -s %%d shell settings put global stay_on_while_plugged_in 7 >nul 2>&1
    "%ADB%" -s %%d shell settings put global wifi_sleep_policy 2 >nul 2>&1
    "%ADB%" -s %%d shell settings put global adb_wifi_enabled 1 >nul 2>&1
    "%ADB%" -s %%d shell dumpsys deviceidle whitelist +%PACKAGE% >nul 2>&1
)
echo.
echo ----------------------------------------------------
echo   CRITICAL PHONE SETTINGS (Xiaomi MIUI / Android):
echo ----------------------------------------------------
echo   1. Keep phone PLUGGED IN to a charger while debugging.
echo   2. Phone Settings ^> Developer options:
echo      - Turn ON "Stay awake"
echo      - Turn ON "Disable ADB authorization timeout"
echo      - Turn ON "USB debugging (Security settings)"
echo      - Turn OFF "MIUI optimization" / "System optimization" if present
echo   3. Phone Settings ^> Wi-Fi ^> Additional settings:
echo      - Turn OFF "Wi-Fi power saving" / "Wi-Fi assistant sleep mode"
echo   4. Phone Settings ^> Apps ^> Manage Apps ^> Jayienne Link:
echo      - Battery Saver: Set to "No restrictions"
echo      - Autostart: Turn ON
echo ----------------------------------------------------
echo.
pause
goto connection_menu

:restart_adb
echo.
echo Restarting ADB Server...
"%ADB%" kill-server >nul 2>&1
timeout /t 1 /nobreak >nul
"%ADB%" start-server >nul 2>&1
echo ADB Server restarted.
if not "%SAVED_IP%"=="" (
    echo Reconnecting to saved IP %SAVED_IP%:5555...
    "%ADB%" connect %SAVED_IP%:5555
)
echo.
pause
goto connection_menu

:check_device_usb
echo.
echo Checking for USB Android device...
set "DEVICE_ID="
for /f "tokens=1" %%d in ('"%ADB%" devices ^| findstr /v "List of" ^| findstr "device"') do (
    if "!DEVICE_ID!"=="" (
        echo %%d | findstr ":" >nul
        if errorlevel 1 set "DEVICE_ID=%%d"
    )
)
if "%DEVICE_ID%"=="" (
    for /f "tokens=1" %%d in ('"%ADB%" devices ^| findstr /v "List of" ^| findstr "device"') do (
        if "!DEVICE_ID!"=="" set "DEVICE_ID=%%d"
    )
)
if "%DEVICE_ID%"=="" (
    echo [ERROR] No Android device found!
    echo Please make sure your phone is plugged in via USB and USB Debugging is ON.
    echo.
    pause
    goto connection_menu
)
goto check_device_ready

:check_device_ready
if "%DEVICE_ID%"=="" (
    echo [ERROR] No device selected.
    goto connection_menu
)

echo ----------------------------------------
echo Active Target: %DEVICE_ID% (Android)
echo ----------------------------------------
echo.

REM Check if app is installed
"%ADB%" -s %DEVICE_ID% shell pm list packages | findstr /i "%PACKAGE%" >nul 2>&1
if errorlevel 1 (
    echo App is not yet installed on %DEVICE_ID%. Building and installing...
    echo.
    goto buildrun
)

:menu
echo ----------------------------------------
echo Target: %DEVICE_ID% (Android)
echo Select an option:
echo.
echo   QUICK ACTIONS:
echo   [1] Launch App
echo   [2] Restart App (force stop + launch)
echo.
echo   DEBUG MODE (Hot Reload):
echo   [3] Debug Run (r=hot reload, R=hot restart)
echo.
echo   RELEASE MODE ^& SHARE:
echo   [4] Release Build ^& Run (Clean / Build APK / Run)
echo.
echo   OTHER:
echo   [5] Uninstall App
echo   [6] Switch Target Device / Reconnect
echo   [0] Exit
echo ----------------------------------------
echo.
set /p "CHOICE=Enter choice (1-6, 0): "

if "%CHOICE%"=="1" goto launch
if "%CHOICE%"=="2" goto restart
if "%CHOICE%"=="3" goto debugrun
if "%CHOICE%"=="4" goto releasemenu
if "%CHOICE%"=="5" goto uninstall
if "%CHOICE%"=="6" goto disconnect
if "%CHOICE%"=="0" exit /b 0
echo Invalid choice. Please enter 1-6 or 0.
echo.
goto menu

:web_menu
echo ----------------------------------------
echo Target: %DEVICE_ID% (Web)
echo Select an option:
echo.
echo   RUN / DEBUG:
echo   [1] Debug Run (Hot Reload / Restart in Browser)
echo   [2] Release Build ^& Run in Browser
echo.
echo   BUILD / CLEAN:
echo   [3] Clean ^& Rebuild (Release)
echo   [4] Build Web Release ^& Open Folder
echo.
echo   OTHER:
echo   [5] Switch Target Device / Browser
echo   [0] Exit
echo ----------------------------------------
echo.
set /p "CHOICE=Enter choice (1-5, 0): "

if "%CHOICE%"=="1" goto debugrun
if "%CHOICE%"=="2" goto buildrun
if "%CHOICE%"=="3" goto cleanrebuild
if "%CHOICE%"=="4" goto buildweb
if "%CHOICE%"=="5" goto disconnect
if "%CHOICE%"=="0" exit /b 0
echo Invalid choice. Please enter 1-5 or 0.
echo.
goto web_menu

:launch
echo.
echo Launching app on %DEVICE_ID%...
"%ADB%" -s %DEVICE_ID% shell am start -n %PACKAGE%/.MainActivity
echo App launched!
echo.
goto menu

:restart
echo.
echo Restarting app on %DEVICE_ID%...
"%ADB%" -s %DEVICE_ID% shell am force-stop %PACKAGE%
timeout /t 1 /nobreak >nul
"%ADB%" -s %DEVICE_ID% shell am start -n %PACKAGE%/.MainActivity
echo App restarted!
echo.
goto menu

:debugrun
echo.
echo ========================================
echo   DEBUG MODE - Hot Reload Enabled
echo ========================================
echo.
echo   Target: %DEVICE_ID%
echo   While running, press:
echo     r = Hot Reload (update UI instantly)
echo     R = Hot Restart (restart app state)
echo     q = Quit
echo.
echo ========================================
echo.
call flutter run -d %DEVICE_ID%
goto handle_run_end

:releasemenu
echo.
echo ----------------------------------------
echo   RELEASE MODE ^& SHARE OPTIONS:
echo.
echo   [1] Release Build ^& Run (Quick)
echo   [2] Clean Release Build ^& Run
echo   [3] Build APK ^& Open Folder (share manually)
echo   [4] Full Release (Clean + Build APK + Open Folder + Run)
echo   [0] Back to Main Menu
echo ----------------------------------------
echo.
set /p "REL_CHOICE=Enter choice (1-4, 0): "

if "%REL_CHOICE%"=="1" goto buildrun
if "%REL_CHOICE%"=="2" goto cleanrebuild
if "%REL_CHOICE%"=="3" goto buildapk
if "%REL_CHOICE%"=="4" goto fullrelease
if "%REL_CHOICE%"=="0" goto menu
echo Invalid choice. Please enter 1-4 or 0.
echo.
goto releasemenu

:fullrelease
echo.
echo ========================================
echo   Full Release Build ^& Share
echo ========================================
echo.
echo Step 1/3: Cleaning project...
call flutter clean
call flutter pub get
echo.
echo Step 2/3: Building Release APK...
call flutter build apk --release
if errorlevel 1 (
    echo.
    echo [ERROR] Build failed!
    echo.
    goto menu
)
echo.
echo Opening APK folder...
if exist "build\app\outputs\flutter-apk" (
    explorer "build\app\outputs\flutter-apk"
)
echo.
echo Step 3/3: Running Release build on device...
call flutter run --release -d %DEVICE_ID%
goto handle_run_end

:buildrun
echo.
echo Building and running app (release)...
echo.
call flutter run --release -d %DEVICE_ID%
goto handle_run_end

:cleanrebuild
echo.
echo Cleaning and rebuilding app...
echo.
call flutter clean
call flutter pub get
call flutter run --release -d %DEVICE_ID%
goto handle_run_end

:handle_run_end
echo.
if "%IS_WEB%"=="1" goto web_menu

REM Verify if device is still reachable
"%ADB%" -s %DEVICE_ID% get-state >nul 2>&1
if errorlevel 1 (
    echo ====================================================
    echo   [ALERT] Connection to %DEVICE_ID% was lost!
    echo ====================================================
    echo.
    echo Options:
    echo   [1] Quick Reconnect ^& Re-run Debug
    echo   [2] Restart ADB Server, Reconnect ^& Re-run Debug
    echo   [3] Return to Main Menu
    echo.
    set /p "RECON_CHOICE=Enter choice 1-3: "
    if "!RECON_CHOICE!"=="1" (
        if not "%SAVED_IP%"=="" (
            "%ADB%" connect %SAVED_IP%:5555
            set "DEVICE_ID=%SAVED_IP%:5555"
            goto debugrun
        )
    )
    if "!RECON_CHOICE!"=="2" (
        "%ADB%" kill-server >nul 2>&1
        timeout /t 1 /nobreak >nul
        "%ADB%" start-server >nul 2>&1
        if not "%SAVED_IP%"=="" (
            "%ADB%" connect %SAVED_IP%:5555
            set "DEVICE_ID=%SAVED_IP%:5555"
            goto debugrun
        )
    )
    goto connection_menu
)

goto menu

:uninstall
echo.
echo Uninstalling app from %DEVICE_ID%...
"%ADB%" -s %DEVICE_ID% uninstall %PACKAGE%
echo App uninstalled!
echo.
goto menu

:buildapk
echo.
echo ========================================
echo   Build APK for Sharing
echo ========================================
echo.
echo Building release APK...
call flutter build apk --release
if errorlevel 1 (
    echo.
    echo [ERROR] Build failed!
    echo.
    goto menu
)
echo.
echo ========================================
echo   APK built successfully!
echo   Opening folder...
echo ========================================
echo.
explorer "build\app\outputs\flutter-apk"
echo.
echo Send "app-release.apk" to your partner via WhatsApp, Drive, etc.
echo.
goto menu

:buildweb
echo.
echo ========================================
echo   Build Web Release
echo ========================================
echo.
echo Building web release...
call flutter build web --release
if errorlevel 1 (
    echo.
    echo [ERROR] Build failed!
    echo.
    goto web_menu
)
echo.
echo ========================================
echo   Web bundle built successfully!
echo   Opening folder...
echo ========================================
echo.
if exist "build\web" (
    explorer "build\web"
) else (
    echo [ERROR] Web output directory not found.
)
echo.
goto web_menu

:disconnect
echo.
if "%IS_WEB%"=="0" (
    echo Disconnecting wireless devices...
    "%ADB%" disconnect
    echo.
)
echo Resetting target. Returning to selection menu...
echo.
set "DEVICE_ID="
set "IS_WEB=0"
goto connection_menu

:ensure_pub
if not exist ".dart_tool\package_config.json" (
    echo.
    echo [INFO] Running flutter pub get...
    call flutter pub get
    if errorlevel 1 (
        echo.
        echo [ERROR] flutter pub get failed.
        echo.
        pause
        exit /b 1
    )
)
exit /b 0
