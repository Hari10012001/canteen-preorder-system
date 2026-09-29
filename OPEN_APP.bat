@echo off
setlocal EnableExtensions EnableDelayedExpansion
title KIOT Canteen - Open
cd /d "%~dp0"

set "APPURL=http://localhost:8080"
set "CURL=%SystemRoot%\System32\curl.exe"
set "TF1=%TEMP%\kiot_tf1.txt"

echo.
echo Checking whether KIOT Canteen is running...

set "HTTPCODE="
if exist "%CURL%" (
    "%CURL%" -s -o NUL -w "%%{http_code}" --max-time 3 "%APPURL%/api/foods" > "%TF1%" 2>nul
    if exist "%TF1%" set /p HTTPCODE=< "%TF1%"
)

if "!HTTPCODE!"=="200" goto :openit

if "!HTTPCODE!"=="000" (
    echo.
    echo KIOT Canteen is not running.
) else (
    echo.
    echo Something is answering on port 8080, but it does not look like
    echo the KIOT Canteen application.
)
echo.
echo To start it, double-click:  START.bat
echo.
pause
exit /b 0

:openit
echo Running. Opening %APPURL%
start "" "%APPURL%" >nul 2>&1
exit /b 0
