@echo off
setlocal EnableExtensions EnableDelayedExpansion
title KIOT Canteen - Status
cd /d "%~dp0"

set "ROOT=%~dp0"
set "BACKEND=%ROOT%backend"
set "PROPS=%BACKEND%\src\main\resources\application.properties"
set "APPURL=http://localhost:8080"
set "CURL=%SystemRoot%\System32\curl.exe"

set "TF1=%TEMP%\kiot_tf1.txt"
set "TF2=%TEMP%\kiot_tf2.txt"
set "TF3=%TEMP%\kiot_tf3.txt"
set "TF4=%TEMP%\kiot_tf4.txt"
set "MYSQLBIN="

echo.
echo ----------------------------------
echo   KIOT CANTEEN STATUS
echo ----------------------------------
echo.

REM ================= Java =================
set "JAVA_TXT=NOT FOUND"
where java > "%TF1%" 2>nul
if not errorlevel 1 (
    java -version > "%TF2%" 2>&1
    findstr /i /c:"version" "%TF2%" > "%TF1%" 2>nul
    set "JV="
    for /f "usebackq delims=" %%v in ("%TF1%") do set "JV=%%v"
    if defined JV (
        set "JAVA_TXT=AVAILABLE"
        for /f "usebackq delims=" %%v in ('!JV!') do set "JAVA_TXT=AVAILABLE  -  %%v"
    ) else (
        set "JAVA_TXT=AVAILABLE  -  (version not reported)"
    )
)
echo Java:
echo    !JAVA_TXT!
echo.

REM ================= MySQL =================
set "MYSQL_TXT=NOT RUNNING"
netstat -an | findstr /c:":3306 " | findstr "LISTENING" >nul 2>&1
if not errorlevel 1 set "MYSQL_TXT=RUNNING  -  listening on port 3306"
echo MySQL:
echo    !MYSQL_TXT!
echo.

REM ================= Database =================
set "DB_TXT=NOT REACHABLE  -  set the DB_PASSWORD environment variable"
call :find_mysql
if defined MYSQLBIN (
    call :read_db_conf
    set "MYSQL_PWD=!DBPASS!"
    "!MYSQLBIN!" -u "!DBUSER!" -N -B -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '!DBNAME!';" > "%TF3%" 2>nul
    set "DBFOUND="
    for /f "usebackq delims=" %%d in ("%TF3%") do if not "%%d"=="" set "DBFOUND=%%d"
    if defined DBFOUND set "DB_TXT=AVAILABLE  -  !DBFOUND!"
    set "MYSQL_PWD="
)
echo Database:
echo    kiot_canteen !DB_TXT!
echo.

REM ================= Port 8080 =================
set "PORT_TXT=NOT RUNNING"
netstat -an | findstr /c:":8080 " | findstr "LISTENING" >nul 2>&1
if not errorlevel 1 set "PORT_TXT=RUNNING  -  something is listening on 8080"
echo Port 8080:
echo    !PORT_TXT!
echo.

REM ================= Application =================
set "APP_TXT=NOT RUNNING"
set "HTTPCODE="
set "APPOK=0"
if exist "%CURL%" (
    "%CURL%" -s -o NUL -w "%%{http_code}" --max-time 3 "%APPURL%/api/foods" > "%TF4%" 2>nul
    if exist "%TF4%" set /p HTTPCODE=< "%TF4%"
    if "!HTTPCODE!"=="200" (
        "%CURL%" -s --max-time 3 "%APPURL%/" > "%TF1%" 2>nul
        findstr /i /c:"KIOT Canteen" "%TF1%" >nul 2>&1
        if not errorlevel 1 (
            set "APPOK=1"
            set "APP_TXT=RUNNING  -  the server answered correctly"
        )
    )
)
if "!HTTPCODE!"=="000" set "HTTPCODE="
if "!APPOK!"=="0" if not defined HTTPCODE set "APP_TXT=NOT RUNNING  -  nothing answered on port 8080"
if "!APPOK!"=="0" if defined HTTPCODE if not "!HTTPCODE!"=="200" set "APP_TXT=NOT RUNNING  -  port 8080 answered with HTTP !HTTPCODE!"
echo Application:
echo    !APP_TXT!
echo.

echo URL:
echo    %APPURL%
echo.

if "!APPOK!"=="1" (
    echo Result: everything looks good. You can use the app now.
) else (
    echo Result: KIOT Canteen is not running.
    echo         Run START.bat to start it.
)
echo.
echo Press any key to close this window...
pause >nul
for %%f in ("%TF1%" "%TF2%" "%TF3%" "%TF4%") do del /q "%%f" >nul 2>&1
exit /b 0

REM ===============================================================
REM Subroutines
REM ===============================================================

:find_mysql
where mysql > "%TF1%" 2>nul
for /f "usebackq delims=" %%m in ("%TF1%") do (
    if not defined MYSQLBIN set "MYSQLBIN=%%m"
    goto :mysqlfound
)
if defined MYSQLBIN goto :mysqlfound
for /d %%d in (
    "%ProgramFiles%\MySQL\MySQL Server *\bin"
    "C:\Program Files\MySQL\MySQL Server *\bin"
    "C:\xampp\mysql\bin"
    "C:\laragon\bin\mysql"
    "C:\wamp64\bin\mysql"
    "C:\wamp\bin\mysql"
) do (
    if not defined MYSQLBIN (
        if exist "%%d\mysql.exe" set "MYSQLBIN=%%d\mysql.exe"
    )
)
:mysqlfound
exit /b 0

REM Reads the connection details from application.properties.
REM The password is used but never printed.
:read_db_conf
set "DBNAME=kiot_canteen"
set "DBUSER="
set "DBPASS="
if not exist "%PROPS%" goto :confdone
for /f "usebackq tokens=1,* delims==" %%a in ("%PROPS%") do (
    if "%%a"=="spring.datasource.username" set "DBUSER=%%b"
    if "%%a"=="spring.datasource.password" set "DBPASS=%%b"
)
:confdone
REM A value such as ${DB_USERNAME:root} means: take it from the
REM environment variable of that name, or use the default shown
REM after the colon. This keeps the password out of this file.
if /i "!DBUSER:~0,2!"=="${" set "DBUSER=!DB_USERNAME!"
if /i "!DBPASS:~0,2!"=="${" set "DBPASS=!DB_PASSWORD!"
if not defined DBUSER set "DBUSER=root"
exit /b 0
