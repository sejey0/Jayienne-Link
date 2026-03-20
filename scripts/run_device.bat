@echo off
setlocal enabledelayedexpansion
title Jayienne Link - Run on Physical Device

cd /d "%~dp0.."

set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
set "PACKAGE=com.jayiennelink.jayienne_link"
set "FIREBASE_APP_ID=1:503326859385:android:982bf6582d7b56174274a8"
set "TESTER_GROUP=lovelove"

echo ========================================
echo    Jayienne Link - Physical Device Run
echo ========================================
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
echo On your Android device:
echo   1. Go to Settings ^> Developer options
echo   2. Enable "Wireless debugging"
echo   3. Tap "Wireless debugging" to enter settings
echo.
echo ----------------------------------------
echo How do you want to pair?
echo   [1] QR Code (take screenshot, we'll decode it)
echo   [2] Manual (enter IP and pairing code)
echo   [3] Skip pairing (already paired before)
echo.
set /p "PAIR_METHOD=Enter choice (1-3): "

if "%PAIR_METHOD%"=="1" goto wireless_qr
if "%PAIR_METHOD%"=="2" goto wireless_manual
if "%PAIR_METHOD%"=="3" goto wireless_direct
echo Invalid choice.
goto wireless_connect

:wireless_qr
echo.
echo ========================================
echo   QR Code Pairing
echo ========================================
echo.
echo On your phone:
echo   1. Tap "Pair device with QR code"
echo   2. Take a SCREENSHOT of the QR code
echo   3. Transfer the screenshot to this PC
echo.
set /p "QR_PATH=Enter full path to QR screenshot: "
echo.
echo Decoding QR code...

REM Decode QR using PowerShell and ZXing
for /f "usebackq delims=" %%i in (`powershell -Command "$ErrorActionPreference='Stop'; try { Add-Type -Path '%LOCALAPPDATA%\QRDecoder\zxing.dll' 2>$null } catch { $null }; if (-not ([System.Management.Automation.PSTypeName]'ZXing.BarcodeReader').Type) { Write-Host 'NEED_INSTALL'; exit }; $reader = New-Object ZXing.BarcodeReader; $bitmap = [System.Drawing.Bitmap]::FromFile('%QR_PATH%'); $result = $reader.Decode($bitmap); if ($result) { $result.Text } else { Write-Host 'DECODE_FAILED' }"`) do set "QR_RESULT=%%i"

if "%QR_RESULT%"=="NEED_INSTALL" goto install_qr_decoder
if "%QR_RESULT%"=="DECODE_FAILED" (
    echo [ERROR] Could not decode QR code from image.
    echo Make sure the screenshot is clear and contains only the QR code.
    echo.
    goto wireless_connect
)
if "%QR_RESULT%"=="" (
    echo [ERROR] Could not decode QR code.
    echo.
    goto wireless_connect
)

echo QR decoded successfully!
echo.

REM Parse WIFI:T:ADB;S:studio-...;P:password;; format
for /f "tokens=2 delims=;" %%a in ("%QR_RESULT%") do set "QR_SERVICE=%%a"
for /f "tokens=3 delims=;" %%a in ("%QR_RESULT%") do set "QR_PASS=%%a"

REM Extract values after S: and P:
set "QR_SERVICE=%QR_SERVICE:~2%"
set "QR_PASS=%QR_PASS:~2%"

REM The QR contains service name, need to find the IP:port via mDNS or manual entry
echo The QR code contains pairing credentials.
echo.
echo You still need the pairing IP:Port from your phone screen.
echo (It's shown below the QR code on your device)
echo.
set /p "PAIR_ADDR=Enter pairing IP:Port (e.g., 192.168.1.100:37215): "
echo.
echo Pairing with device...
"%ADB%" pair %PAIR_ADDR% %QR_PASS%
if errorlevel 1 (
    echo.
    echo [ERROR] Pairing failed!
    echo.
    goto connection_menu
)
echo.
echo Pairing successful!
echo.
goto wireless_direct

:install_qr_decoder
echo.
echo QR decoder not installed. Installing...
echo.
powershell -Command "New-Item -ItemType Directory -Force -Path '%LOCALAPPDATA%\QRDecoder' | Out-Null; Invoke-WebRequest -Uri 'https://www.nuget.org/api/v2/package/ZXing.Net/0.16.9' -OutFile '%TEMP%\zxing.zip'; Expand-Archive -Path '%TEMP%\zxing.zip' -DestinationPath '%TEMP%\zxing' -Force; Copy-Item '%TEMP%\zxing\lib\net45\zxing.dll' '%LOCALAPPDATA%\QRDecoder\'; Remove-Item '%TEMP%\zxing.zip'; Remove-Item -Recurse '%TEMP%\zxing'"
if errorlevel 1 (
    echo.
    echo [ERROR] Failed to install QR decoder.
    echo Falling back to manual pairing...
    echo.
    goto wireless_manual
)
echo QR decoder installed! Please try again.
echo.
goto wireless_qr

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
echo   DISTRIBUTE:
echo   [6] Build ^& Send to Testers (Firebase)
echo   [7] Build APK ^& Open Folder (share manually)
echo.
echo   OTHER:
echo   [8] Uninstall App
echo   [9] Disconnect Wireless ^& Reconnect
echo   [0] Exit
echo ----------------------------------------
echo.
set /p "CHOICE=Enter choice (1-9, 0): "

if "%CHOICE%"=="1" goto launch
if "%CHOICE%"=="2" goto restart
if "%CHOICE%"=="3" goto debugrun
if "%CHOICE%"=="4" goto buildrun
if "%CHOICE%"=="5" goto cleanrebuild
if "%CHOICE%"=="6" goto distribute
if "%CHOICE%"=="7" goto buildapk
if "%CHOICE%"=="8" goto uninstall
if "%CHOICE%"=="9" goto disconnect
if "%CHOICE%"=="0" exit /b 0
echo Invalid choice. Please enter 1-9 or 0.
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

:distribute
echo.
echo ========================================
echo   Build ^& Distribute to Testers
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
set /p "RELEASE_NOTES=Enter release notes (or press Enter to skip): "
echo.
echo Uploading to Firebase App Distribution...
echo.
if "%RELEASE_NOTES%"=="" (
    firebase appdistribution:distribute build\app\outputs\flutter-apk\app-release.apk --app %FIREBASE_APP_ID% --groups "%TESTER_GROUP%"
) else (
    firebase appdistribution:distribute build\app\outputs\flutter-apk\app-release.apk --app %FIREBASE_APP_ID% --groups "%TESTER_GROUP%" --release-notes "%RELEASE_NOTES%"
)
echo.
if errorlevel 1 (
    echo [ERROR] Distribution failed! Make sure you're logged in: firebase login
) else (
    echo ========================================
    echo   APK sent to testers successfully!
    echo   Testers will receive a notification.
    echo ========================================
)
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
