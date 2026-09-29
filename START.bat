@echo off
setlocal EnableExtensions EnableDelayedExpansion
title KIOT Canteen - Start
cd /d "%~dp0"

set "ROOT=%~dp0"
set "BACKEND=%ROOT%backend"
set "JAR=%BACKEND%\target\kiot-canteen.jar"
set "PIDFILE=%ROOT%kiot-app.pid"
set "PROPS=%BACKEND%\src\main\resources\application.properties"
set "APPURL=http://localhost:8080"
set "WAITSEC=150"
set "CURL=%SystemRoot%\System32\curl.exe"
set "TF1=%TEMP%\kiot_tf1.txt"
set "TF2=%TEMP%\kiot_tf2.txt"
set "TF3=%TEMP%\kiot_tf3.txt"
set "TF4=%TEMP%\kiot_tf4.txt"

echo.
echo ==========================================
echo   KIOT CANTEEN - PRE-ORDER SYSTEM
echo   One-click start
echo ==========================================
echo.

REM ---------------------------------------------------------------
REM 0. Project structure
REM ---------------------------------------------------------------
if not exist "%BACKEND%\pom.xml" (
    echo [ERROR] Could not find "%BACKEND%\pom.xml"
    echo         Keep START.bat inside the kiot-canteen project folder.
    goto :fail
)

REM ---------------------------------------------------------------
REM 1. Java
REM ---------------------------------------------------------------
echo [1/5] Checking Java...
where java >nul 2>&1
if errorlevel 1 (
    echo.
    echo [ERROR] Java/JDK was not found.
    echo.
    echo         Install JDK 21 and reopen this window:
    echo         https://adoptium.net/temurin/releases/?version=21
    echo.
    goto :fail
)
set "JV="
for /f "delims=" %%v in ('java -version 2^>^&1 ^| findstr /i /c:"version"') do set "JV=%%v"
echo       %JV%

REM Read the major version (for example 21 or 25) without needing extra tools.
set "JAVAMAJOR=0"
set "JVX=%JV:"=%"
for /f "usebackq tokens=3" %%a in ('%JVX%') do for /f "usebackq tokens=1 delims=." %%b in ('%%a') do set "JAVAMAJOR=%%b"
if not defined JAVAMAJOR set "JAVAMAJOR=0"

if !JAVAMAJOR! LSS 21 (
    echo.
    echo [ERROR] Java 21 or newer is required. Found major version !JAVAMAJOR!.
    echo         Install JDK 21:
    echo         https://adoptium.net/temurin/releases/?version=21
    echo.
    goto :fail
)
echo       Java !JAVAMAJOR! is available. OK.
echo.

REM ---------------------------------------------------------------
REM 2. MySQL
REM ---------------------------------------------------------------
echo [2/5] Checking MySQL...
netstat -an | findstr /c:":3306 " | findstr "LISTENING" >nul 2>&1
if not errorlevel 1 (
    echo       MySQL is running on port 3306. OK.
    goto :mysqlok
)

echo       MySQL is not running. Trying to start the MySQL service...
set "MYSQLSVC="
for /f "tokens=2" %%s in ('sc query type^= service state^= all ^| findstr /i /c:"SERVICE_NAME:" ^| findstr /i /c:"mysql"') do set "MYSQLSVC=%%s"

if defined MYSQLSVC (
    echo       Found service "!MYSQLSVC!". Attempting to start it...
    sc start "!MYSQLSVC!" >nul 2>&1
    if errorlevel 1 (
        net start "!MYSQLSVC!" >nul 2>&1
    )
    echo       Waiting a few seconds for MySQL...
    ping -n 8 127.0.0.1 >nul
    netstat -an | findstr /c:":3306 " | findstr "LISTENING" >nul 2>&1
    if not errorlevel 1 (
        echo       MySQL is running. OK.
        goto :mysqlok
    )
)

echo.
echo [ERROR] MySQL is not running or cannot be reached.
echo.
echo         Do this:
echo           1. Press the Windows key, type "services", press Enter.
echo           2. Find the MySQL service (for example MySQL80).
echo           3. Right-click it and choose "Start".
echo           4. If it is stopped or disabled, start it as Administrator.
echo.
echo         Do NOT reset or change any MySQL password for this step.
echo.
goto :fail

:mysqlok
echo.

REM ---------------------------------------------------------------
REM 3. Port 8080
REM ---------------------------------------------------------------
echo [3/5] Checking port 8080...
netstat -an | findstr /c:":8080 " | findstr "LISTENING" >nul 2>&1
if errorlevel 1 (
    echo       Port 8080 is free. OK.
    goto :portfree
)

call :app_probe
if "!APPOK!"=="1" (
    echo       KIOT Canteen is ALREADY running on port 8080.
    echo       Not starting a second instance.
    echo.
    call :open_browser
    echo ==========================================
    echo   KIOT Canteen is ready:  %APPURL%
    echo ==========================================
    echo.
    pause
    exit /b 0
)

echo.
echo [ERROR] Port 8080 is already being used by another process.
echo.
echo         Something other than KIOT Canteen is listening on 8080.
echo         Close that program and run START.bat again.
echo.
echo         To see what is using the port, run:  netstat -ano ^| findstr :8080
echo.
goto :fail

:portfree

REM ---------------------------------------------------------------
REM 4. Make sure the runnable jar is present and current
REM ---------------------------------------------------------------
echo [4/5] Preparing the application...
set "NEEDBUILD=0"
if not exist "%JAR%" (
    set "NEEDBUILD=1"
    set "BUILDWHY=The runnable file was not found."
) else (
    set "JARSTATE=FRESH"
    powershell -NoProfile -Command "$jar = (Get-Item '%JAR%').LastWriteTime; $n = (Get-ChildItem -Path '%BACKEND%\src','%ROOT%frontend','%BACKEND%\pom.xml' -Recurse -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime; if ($n -gt $jar) { 'STALE' } else { 'FRESH' }" > "%TF2%" 2>nul
    for /f "usebackq delims=" %%s in ("%TF2%") do set "JARSTATE=%%s"
    if not defined JARSTATE set "JARSTATE=FRESH"
    if "!JARSTATE!"=="STALE" (
        set "NEEDBUILD=1"
        set "BUILDWHY=Source files are newer than the built application."
    )
)

if "!NEEDBUILD!"=="0" (
    echo       Application is up to date. OK.
    goto :buildok
)

echo       !BUILDWHY!
echo       Building the application, please wait...

set "MVNCMD="
if exist "%BACKEND%\mvnw.cmd" set "MVNCMD=%BACKEND%\mvnw.cmd"
REM Prefer the real mvn.cmd: on some installs PATH also holds an extension-less
REM "mvn" launcher, and a quoted call to that name fails with no output.
if not defined MVNCMD for /f "usebackq delims=" %%m in (`where mvn.cmd 2^>nul`) do if not defined MVNCMD set "MVNCMD=%%m"
if not defined MVNCMD for /f "usebackq delims=" %%m in (`where mvn 2^>nul`) do if not defined MVNCMD set "MVNCMD=%%m"
if not defined MVNCMD (
    call mvn -B -v >nul 2>&1
    if not errorlevel 1 set "MVNCMD=mvn.cmd"
)

if not defined MVNCMD (
    echo.
    echo [ERROR] Maven is required to start the project.
    echo.
    echo         Install Maven 3.9+ from https://maven.apache.org/download.cgi
    echo         Or open a terminal in the "backend" folder and run:
    echo.
    echo             mvn -DskipTests package
    echo.
    goto :fail
)

pushd "%BACKEND%"
call "%MVNCMD%" -B -DskipTests package
set "BUILDRC=%ERRORLEVEL%"
popd

if not "!BUILDRC!"=="0" (
    echo.
    echo [ERROR] The build failed. Read the messages above.
    echo         Fix the problem and run START.bat again.
    echo.
    goto :fail
)
if not exist "%JAR%" (
    echo.
    echo [ERROR] The build finished but the runnable file is missing.
    echo.
    goto :fail
)
echo       Build finished. OK.
echo.

:buildok

REM ---------------------------------------------------------------
REM 5. Start the server in its own visible window
REM ---------------------------------------------------------------
echo [5/5] Starting KIOT Canteen...
if not defined DB_PASSWORD (
    echo       Note: DB_PASSWORD is not set, so the server will try to
    echo       connect to MySQL with an empty password. If that fails,
    echo       set it once and run this file again:
    echo         setx DB_PASSWORD "your MySQL password"
    echo.
)
start "KIOT Canteen Server" /D "%BACKEND%" cmd /k "java -jar target\kiot-canteen.jar"
echo       A "KIOT Canteen Server" window has opened. Keep it open.
echo.
echo       Waiting for the application to be ready (up to %WAITSEC% seconds)...

set /a ELAPSED=0
:waitloop
call :app_probe
if "!APPOK!"=="1" goto :ready
if !ELAPSED! geq %WAITSEC% goto :timeout
ping -n 3 127.0.0.1 >nul
set /a ELAPSED+=2
<nul set /p "=."
goto :waitloop

:timeout
echo.
echo.
echo [ERROR] KIOT Canteen failed to start.
echo.
echo         The server did not answer within %WAITSEC% seconds.
echo         Look at the "KIOT Canteen Server" window for the real error.
echo         Common causes:
echo           - MySQL is not running or the password is wrong.
echo           - Port 8080 is blocked by another program.
echo           - The database is not reachable.
echo.
goto :fail

:ready
echo.
echo.
call :save_pid
echo ==========================================
echo   KIOT CANTEEN IS READY
echo ==========================================
echo.
echo   Open:  %APPURL%
echo   Login: student@kiot.edu / canteen123
echo   Stop:  run STOP.bat when you are finished.
echo.
echo   The server keeps running in the
echo   "KIOT Canteen Server" window. Close that
echo   window to stop the server.
echo.
call :open_browser
echo.
pause
exit /b 0

REM ===============================================================
REM Subroutines
REM ===============================================================

:app_probe
set "APPOK=0"
set "HTTPCODE="
if not exist "%CURL%" exit /b 0
"%CURL%" -s -o NUL -w "%%{http_code}" --max-time 3 "%APPURL%/api/foods" > "%TF4%" 2>nul
if exist "%TF4%" set /p HTTPCODE=< "%TF4%"
if not "!HTTPCODE!"=="200" exit /b 0
"%CURL%" -s --max-time 3 "%APPURL%/" > "%TF1%" 2>nul
findstr /i /c:"KIOT Canteen" "%TF1%" >nul 2>&1
if not errorlevel 1 set "APPOK=1"
exit /b 0

:save_pid
set "KOTPID="
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'java.exe' -and $_.CommandLine -like '*kiot-canteen*' } | Select-Object -ExpandProperty ProcessId" > "%TF3%" 2>nul
for /f "usebackq delims=" %%p in ("%TF3%") do set "KOTPID=%%p"
if defined KOTPID (
    >"%PIDFILE%" echo !KOTPID!
    echo       Server process id: !KOTPID!  ^(saved to kiot-app.pid^)
)
exit /b 0

:open_browser
start "" "%APPURL%" >nul 2>&1
exit /b 0

:fail
echo.
echo Press any key to close this window...
pause >nul
exit /b 1
