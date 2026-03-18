@echo off
setlocal enabledelayedexpansion
title Jayienne Link - Run on Physical Device

cd /d "%~dp0.."

echo ========================================
echo    Jayienne Link - Physical Device Run
echo ========================================
echo.

echo Detecting physical device...
echo.

set "DEVICE_ID="

for /f "tokens=2 delims=•" %%a in ('flutter devices 2^>nul ^| findstr /i "android"') do (
    for /f "tokens=1" %%b in ("%%a") do (
        set "DEVICE_ID=%%b"
    )
)

if "!DEVICE_ID!"=="" (
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

echo Found device: !DEVICE_ID!
echo.
echo Running app on physical device...
echo.

flutter run --release -d !DEVICE_ID!

pause
