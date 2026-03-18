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

echo Checking for Android device...
echo.

REM Extract device ID using PowerShell
for /f "usebackq delims=" %%i in (`powershell -Command "(flutter devices | Select-String 'mobile.*android' | ForEach-Object { ($_ -split '•')[1].Trim() } | Select-Object -First 1)"`) do set "DEVICE_ID=%%i"

if "%DEVICE_ID%"=="" (
    echo [ERROR] No physical Android device found!
    echo.
    echo Please make sure:
    echo   1. Your device is connected via USB
    echo   2. USB debugging is enabled
    echo   3. You accepted the authorization prompt on your device
    echo.
    echo Available devices:
    flutter devices
    echo.
    pause
    exit /b 1
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
echo   [9] Exit
echo ----------------------------------------
echo.
set /p "CHOICE=Enter choice (1-9): "

if "%CHOICE%"=="1" goto launch
if "%CHOICE%"=="2" goto restart
if "%CHOICE%"=="3" goto debugrun
if "%CHOICE%"=="4" goto buildrun
if "%CHOICE%"=="5" goto cleanrebuild
if "%CHOICE%"=="6" goto distribute
if "%CHOICE%"=="7" goto buildapk
if "%CHOICE%"=="8" goto uninstall
if "%CHOICE%"=="9" exit /b 0
echo Invalid choice. Please enter 1-9.
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
