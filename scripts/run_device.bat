@echo off
title Jayienne Link - Run on Physical Device

cd /d "%~dp0.."

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
echo Running app on Android device...
echo.

flutter run --release -d %DEVICE_ID%

pause
