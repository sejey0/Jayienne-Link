@echo off
setlocal enabledelayedexpansion
title Jayienne Link - Run on Physical Device

cd /d "%~dp0.."

set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
set "PACKAGE=com.jayiennelink.jayienne_link"

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
echo   [1] Launch App
echo   [2] Restart App (force stop + launch)
echo   [3] Rebuild ^& Run (update code)
echo   [4] Clean Rebuild (flutter clean + build)
echo   [5] Uninstall App
echo   [6] Exit
echo ----------------------------------------
echo.
set /p "CHOICE=Enter choice (1-6): "

if "%CHOICE%"=="1" goto launch
if "%CHOICE%"=="2" goto restart
if "%CHOICE%"=="3" goto buildrun
if "%CHOICE%"=="4" goto cleanrebuild
if "%CHOICE%"=="5" goto uninstall
if "%CHOICE%"=="6" exit /b 0
echo Invalid choice. Please enter 1-6.
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

:buildrun
echo.
echo Building and running app...
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
