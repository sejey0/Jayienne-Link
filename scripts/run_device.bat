@echo off
title Jayienne Link - Run on Physical Device

cd /d "%~dp0.."

echo ========================================
echo    Jayienne Link - Physical Device Run
echo ========================================
echo.

echo Checking connected devices...
flutter devices

echo.
echo Running app on connected device...
echo.

flutter run --release

pause
