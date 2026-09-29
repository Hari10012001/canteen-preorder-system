@echo off
setlocal EnableExtensions EnableDelayedExpansion
title KIOT Canteen - Stop
cd /d "%~dp0"

set "ROOT=%~dp0"
set "PIDFILE=%ROOT%kiot-app.pid"
set "APPURL=http://localhost:8080"
set "CURL=%SystemRoot%\System32\curl.exe"
set "TF1=%TEMP%\kiot_tf1.txt"
set "TF2=%TEMP%\kiot_tf2.txt"
set "TF3=%TEMP%\kiot_tf3.txt"

echo.
echo ==========================================
echo   KIOT CANTEEN - STOP
echo ==========================================
echo.

REM ---------------------------------------------------------------
REM 1. Is the application running?
REM ---------------------------------------------------------------
call :app_probe
if "!APPOK!"=="1" (
    echo Status: KIOT Canteen is running. Stopping it now...
) else (
    echo KIOT Canteen is not currently running.
    echo.
    goto :finish
)
echo.

REM ---------------------------------------------------------------
REM 2. Work out the process id.
REM    Only a java.exe process whose command line mentions
REM    kiot-canteen is ever targeted. MySQL and every other
REM    program are left alone.
REM ---------------------------------------------------------------
set "KOTPID="

REM Preferred: the id saved by START.bat, but only if it still
REM really is our java process.
if exist "%PIDFILE%" (
    set "SAVEDPID="
    for /f "usebackq delims=" %%p in ("%PIDFILE%") do set "SAVEDPID=%%p"
    if defined SAVEDPID (
        set "PIDMATCH="
        powershell -NoProfile -Command "try { $p = Get-CimInstance Win32_Process -Filter 'ProcessId=%SAVEDPID%'; if ($p -and $p.Name -eq 'java.exe' -and $p.CommandLine -like '*kiot-canteen*') { 'MATCH' } } catch { '' }" > "%TF1%" 2>nul
        for /f "usebackq delims=" %%n in ("%TF1%") do set "PIDMATCH=%%n"
        if "!PIDMATCH!"=="MATCH" set "KOTPID=!SAVEDPID!"
    )
)

REM Fallback: find it directly.
if not defined KOTPID (
    set "KOTPID="
    powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'java.exe' -and $_.CommandLine -like '*kiot-canteen*' } | Select-Object -ExpandProperty ProcessId" > "%TF2%" 2>nul
    for /f "usebackq delims=" %%p in ("%TF2%") do set "KOTPID=%%p"
)

if not defined KOTPID (
    echo [ERROR] The application answered on port 8080 but its process
    echo         could not be identified safely, so nothing was stopped.
    echo.
    goto :finish
)

echo Found KIOT Canteen process id: !KOTPID!
echo.

REM ---------------------------------------------------------------
REM 3. Stop it. Try a normal close first, then force.
REM ---------------------------------------------------------------
echo Sending a normal stop request...
taskkill /PID !KOTPID! /T >nul 2>&1
set /a WAITED=0
:gracefulwait
set "STILLTHERE=0"
tasklist /FI "PID eq !KOTPID!" /NH 2>nul | findstr /r /c:"^java" >nul 2>&1 && set "STILLTHERE=1"
if "!STILLTHERE!"=="0" goto :stopped
if !WAITED! geq 8 goto :force
ping -n 2 127.0.0.1 >nul
set /a WAITED+=1
goto :gracefulwait

:force
echo Still running, forcing it to stop...
taskkill /PID !KOTPID! /T /F >nul 2>&1
ping -n 3 127.0.0.1 >nul

:stopped
echo KIOT Canteen process stopped.
echo.

REM Close the "KIOT Canteen Server" console window if it is still open.
taskkill /FI "WINDOWTITLE eq KIOT Canteen Server" /T /F >nul 2>&1
ping -n 2 127.0.0.1 >nul

if exist "%PIDFILE%" del /q "%PIDFILE%" >nul 2>&1

REM ---------------------------------------------------------------
REM 4. Confirm the port is free again
REM ---------------------------------------------------------------
netstat -an | findstr /c:":8080 " | findstr "LISTENING" >nul 2>&1
if errorlevel 1 (
    echo Port 8080 is free again. OK.
) else (
    echo [WARNING] Something is still listening on port 8080.
)

:finish
echo.
echo --------------------------------------------------------------
echo MySQL and all other programs were NOT stopped.
echo --------------------------------------------------------------
echo.
echo KIOT Canteen application stopped.
echo.
echo Press any key to close this window...
pause >nul
for %%f in ("%TF1%" "%TF2%" "%TF3%") do del /q "%%f" >nul 2>&1
exit /b 0

REM ===============================================================
REM Subroutines
REM ===============================================================

:app_probe
set "APPOK=0"
set "HTTPCODE="
if not exist "%CURL%" exit /b 0
"%CURL%" -s -o NUL -w "%%{http_code}" --max-time 3 "%APPURL%/api/foods" > "%TF3%" 2>nul
if exist "%TF3%" set /p HTTPCODE=< "%TF3%"
if not "!HTTPCODE!"=="200" exit /b 0
"%CURL%" -s --max-time 3 "%APPURL%/" > "%TF1%" 2>nul
findstr /i /c:"KIOT Canteen" "%TF1%" >nul 2>&1
if not errorlevel 1 set "APPOK=1"
exit /b 0
