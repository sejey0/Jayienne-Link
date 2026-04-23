@echo off
setlocal enabledelayedexpansion
title Jayienne Link - Run on Physical Device

cd /d "%~dp0.."

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

echo ========================================
echo    Jayienne Link - Physical Device Run
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
echo How do you want to connect?
echo   [1] USB (device already connected)
echo   [2] Wireless Debugging (connect via WiFi)
echo   [3] Already connected wirelessly
echo.
set /p "CONN_TYPE=Enter choice (1-3): "

if "%CONN_TYPE%"=="2" goto wireless_connect
if "%CONN_TYPE%"=="3" goto check_device
if "%CONN_TYPE%"=="1" goto check_device
echo Invalid choice.
echo.
goto connection_menu

:wireless_connect
echo.
echo ========================================
echo   Wireless Debugging Setup
echo ========================================
echo.
echo How do you want to pair?
echo   [1] Guided Setup (recommended)
echo   [2] Quick Manual (enter IP and code directly)
echo   [3] Skip pairing (already paired before)
echo.
set /p "PAIR_METHOD=Enter choice (1-3): "

if "%PAIR_METHOD%"=="1" goto wireless_guided
if "%PAIR_METHOD%"=="2" goto wireless_manual
if "%PAIR_METHOD%"=="3" goto wireless_direct
echo Invalid choice.
goto wireless_connect

:wireless_guided
echo.
echo On your phone, tap "Pair device with pairing code"
echo.
echo Enter the PAIRING address (e.g., 192.168.1.100:37215):
set /p "PAIR_ADDR="
echo Enter the PAIRING code shown on device:
set /p "PAIR_CODE="
echo.
echo Pairing with device...
"%ADB%" pair %PAIR_ADDR% %PAIR_CODE%
if errorlevel 1 (
    echo.
    echo [ERROR] Pairing failed! Check the address and code.
    echo.
    goto connection_menu
)
echo.
echo Pairing successful!
echo.
goto wireless_direct

:wireless_manual
echo.
echo On your phone, tap "Pair device with pairing code"
echo.
echo Enter the PAIRING address (e.g., 192.168.1.100:37215):
set /p "PAIR_ADDR="
echo Enter the PAIRING code shown on device:
set /p "PAIR_CODE="
echo.
echo Pairing with device...
"%ADB%" pair %PAIR_ADDR% %PAIR_CODE%
if errorlevel 1 (
    echo.
    echo [ERROR] Pairing failed! Check the address and code.
    echo.
    goto connection_menu
)
echo.
echo Pairing successful!
echo.

:wireless_direct
echo.
echo Now enter the CONNECT address from Wireless debugging screen
echo (This is different from the pairing address, e.g., 192.168.1.100:43567):
set /p "CONNECT_ADDR="
echo.
echo Connecting to device...
"%ADB%" connect %CONNECT_ADDR%
if errorlevel 1 (
    echo.
    echo [ERROR] Connection failed!
    echo.
    goto connection_menu
)
echo.
timeout /t 2 /nobreak >nul

:check_device
echo.
echo Checking for Android device...
echo.

REM Extract device ID using PowerShell
for /f "usebackq delims=" %%i in (`powershell -Command "(flutter devices | Select-String 'mobile.*android' | ForEach-Object { ($_ -split '•')[1].Trim() } | Select-Object -First 1)"`) do set "DEVICE_ID=%%i"

if "%DEVICE_ID%"=="" (
    echo [ERROR] No physical Android device found!
    echo.
    echo Please make sure:
    echo   - For USB: Device connected and USB debugging enabled
    echo   - For Wireless: Device paired and connected via adb
    echo.
    echo Available devices:
    flutter devices
    echo.
    pause
    goto connection_menu
)

echo Found device: %DEVICE_ID%
echo.

REM Check if app is already installed
"%ADB%" -s %DEVICE_ID% shell pm list packages | findstr /i "%PACKAGE%" >nul 2>&1
if errorlevel 1 (
    echo App not installed. Building and installing...
    echo.
    goto buildrun
)

:menu
echo ----------------------------------------
echo Select an option:
echo.
echo   QUICK ACTIONS:
echo   [1] Launch App
echo   [2] Restart App (force stop + launch)
echo.
echo   DEBUG MODE (Hot Reload):
echo   [3] Debug Run (r=hot reload, R=hot restart)
echo.
echo   RELEASE MODE:
echo   [4] Release Build ^& Run
echo   [5] Clean Release Build
echo.
echo   SHARE:
echo   [6] Build APK ^& Open Folder (share manually)
echo.
echo   OTHER:
echo   [7] Uninstall App
echo   [8] Disconnect Wireless ^& Reconnect
echo   [0] Exit
echo ----------------------------------------
echo.
set /p "CHOICE=Enter choice (1-8, 0): "

if "%CHOICE%"=="1" goto launch
if "%CHOICE%"=="2" goto restart
if "%CHOICE%"=="3" goto debugrun
if "%CHOICE%"=="4" goto buildrun
if "%CHOICE%"=="5" goto cleanrebuild
if "%CHOICE%"=="6" goto buildapk
if "%CHOICE%"=="7" goto uninstall
if "%CHOICE%"=="8" goto disconnect
if "%CHOICE%"=="0" exit /b 0
echo Invalid choice. Please enter 1-8 or 0.
echo.
goto menu

:launch
echo.
echo Launching app...
"%ADB%" -s %DEVICE_ID% shell am start -n %PACKAGE%/.MainActivity
echo App launched!
echo.
goto menu

:restart
echo.
echo Restarting app...
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
echo   While running, press:
echo     r = Hot Reload (update UI instantly)
echo     R = Hot Restart (restart app state)
echo     q = Quit
echo.
echo ========================================
echo.
flutter run -d %DEVICE_ID%
echo.
goto menu

:buildrun
echo.
echo Building and running app (release)...
echo.
flutter run --release -d %DEVICE_ID%
echo.
goto menu

:cleanrebuild
echo.
echo Cleaning and rebuilding app...
echo.
flutter clean
flutter pub get
flutter run --release -d %DEVICE_ID%
echo.
goto menu

:uninstall
echo.
echo Uninstalling app...
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
flutter build apk --release
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

:disconnect
echo.
echo Disconnecting all wireless devices...
"%ADB%" disconnect
echo.
echo Disconnected. Returning to connection menu...
echo.
set "DEVICE_ID="
goto connection_menu

:ensure_pub
if not exist ".dart_tool\package_config.json" (
    echo.
    echo [INFO] Running flutter pub get...
    flutter pub get
    if errorlevel 1 (
        echo.
        echo [ERROR] flutter pub get failed.
        echo.
        pause
        exit /b 1
    )
)
exit /b 0
