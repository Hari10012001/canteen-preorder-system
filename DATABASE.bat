@echo off
setlocal EnableExtensions EnableDelayedExpansion
title KIOT Canteen - Database
cd /d "%~dp0"

set "ROOT=%~dp0"
set "BACKEND=%ROOT%backend"
set "PROPS=%BACKEND%\src\main\resources\application.properties"
set "SQLFILE=%TEMP%\kiot_db_query.sql"
set "TFOUT=%TEMP%\kiot_db_out.txt"
set "TF1=%TEMP%\kiot_tf1.txt"

set "MYSQLBIN="
set "WORKBENCH="

echo.
echo ==========================================
echo   KIOT CANTEEN - DATABASE VIEWER
echo   Read only. Nothing will be changed.
echo ==========================================
echo.

REM ---------------------------------------------------------------
REM 1. Is MySQL running?
REM ---------------------------------------------------------------
netstat -an | findstr /c:":3306 " | findstr "LISTENING" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] MySQL is not running or cannot be reached.
    echo.
    echo         Do this:
    echo           1. Press the Windows key, type "services", press Enter.
    echo           2. Find the MySQL service ^(for example MySQL80^).
    echo           3. Right-click it and choose "Start".
    echo.
    echo         Then run DATABASE.bat again.
    echo.
    pause
    exit /b 1
)
echo [OK] MySQL is running on port 3306.

REM ---------------------------------------------------------------
REM 2. Find the mysql command line program
REM ---------------------------------------------------------------
call :find_mysql
if not defined MYSQLBIN (
    echo.
    echo [ERROR] The MySQL command line program ^(mysql.exe^) was not found.
    echo.
    echo         Install MySQL 8.x, or add its bin folder to PATH:
    echo         C:\Program Files\MySQL\MySQL Server 8.0\bin
    echo.
    pause
    exit /b 1
)
echo [OK] Found the MySQL command line program.

REM ---------------------------------------------------------------
REM 3. Read the connection details from application.properties
REM    The password is used automatically and never printed.
REM ---------------------------------------------------------------
call :read_db_conf
echo [OK] Using database "!DBNAME!" with user "!DBUSER!"
echo.

REM ---------------------------------------------------------------
REM 4. Does the database exist?
REM ---------------------------------------------------------------
set "DBFOUND="
"%MYSQLBIN%" -u "%DBUSER%" -N -B -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '!DBNAME!';" > "%TFOUT%" 2>nul
for /f "usebackq delims=" %%d in ("%TFOUT%") do if not "%%d"=="" set "DBFOUND=%%d"

if not defined DBFOUND (
    echo [INFO] The database "!DBNAME!" does not exist yet.
    echo.
    echo        That is normal if you have not started the app yet.
    echo        Run START.bat once and the app will create it.
    echo.
    pause
    exit /b 0
)
echo [OK] Database "!DBFOUND!" exists.
echo.

REM ---------------------------------------------------------------
REM 5. Does it have the tables?
REM ---------------------------------------------------------------
set "TABLECOUNT=0"
"%MYSQLBIN%" -u "%DBUSER%" -N -B -e "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = '!DBNAME!';" > "%TFOUT%" 2>nul
for /f "usebackq delims=" %%t in ("%TFOUT%") do set "TABLECOUNT=%%t"

if not "!TABLECOUNT!"=="0" goto :have_tables

echo [INFO] Database "!DBNAME!" is empty.
echo.
echo        The app creates its tables by itself on first start.
echo        Run START.bat once, then run DATABASE.bat again.
echo.
pause
exit /b 0

:have_tables
echo [OK] Found !TABLECOUNT! tables in "!DBNAME!".
echo.
call :runq "TABLES IN !DBNAME!" "SHOW TABLES;"
call :summary

REM ---------------------------------------------------------------
REM 6. Menu
REM ---------------------------------------------------------------
echo ==========================================
echo   WHAT WOULD YOU LIKE TO SEE?
echo ==========================================
echo.
echo    1  Users          (no password shown)
echo    2  Food items     (the canteen menu)
echo    3  Orders
echo    4  Order items    (what was in each order)
echo    5  Payments
echo    6  Order overview (orders joined with student and payment)
echo    7  Row counts     (how much data is stored)
echo    8  TABLES syntax  (DESCRIBE each table)
echo    9  Open MySQL Workbench
echo    0  Quit
echo.

set /a MENUHITS=0
:menu
set /p "CH=Type the number and press Enter: "
if not defined CH set "CH=0"
set /a MENUHITS+=1
if !MENUHITS! GEQ 200 goto :done
echo.

if "!CH!"=="1" call :runq "USERS" "SELECT id, name, email, student_id, phone, role, created_at FROM users ORDER BY id;"
if "!CH!"=="2" call :runq "FOOD ITEMS" "SELECT id, name, category, price, is_veg, available, prep_time_mins FROM food_items ORDER BY category, id;"
if "!CH!"=="3" call :runq "ORDERS" "SELECT o.id, o.order_code, u.name AS student, u.student_id, o.total_amount, o.pickup_date, o.pickup_slot, o.payment_method, o.payment_status, o.order_status, o.created_at FROM orders o JOIN users u ON u.id = o.user_id ORDER BY o.id;"
if "!CH!"=="4" call :runq "ORDER ITEMS" "SELECT oi.id, o.order_code, oi.item_name, oi.quantity, oi.unit_price, oi.line_total FROM order_items oi JOIN orders o ON o.id = oi.order_id ORDER BY oi.order_id, oi.id;"
if "!CH!"=="5" call :runq "PAYMENTS" "SELECT p.id, o.order_code, p.method, p.status, p.amount, p.reference, p.created_at FROM payments p JOIN orders o ON o.id = p.order_id ORDER BY p.id;"
if "!CH!"=="6" call :overview
if "!CH!"=="7" call :summary
if "!CH!"=="8" call :describe
if "!CH!"=="9" call :workbench
if "!CH!"=="0" goto :done

echo.
goto :menu

:done
echo ==========================================
echo   Thank you. Nothing was modified.
echo ==========================================
echo.
echo   This tool only runs SELECT / SHOW / DESCRIBE statements.
echo   It never runs DELETE, DROP, TRUNCATE or UPDATE.
echo.
if exist "%SQLFILE%" del /q "%SQLFILE%" >nul 2>&1
pause
exit /b 0

REM ===============================================================
REM Subroutines
REM ===============================================================

REM %1 = heading, %2 = SQL
:runq
echo.
echo ---------------------------------------------
echo   %~1
echo ---------------------------------------------
> "%SQLFILE%" echo %~2
"%MYSQLBIN%" -u "%DBUSER%" --default-character-set=utf8mb4 --table "!DBNAME!" < "%SQLFILE%" 2>nul
if errorlevel 1 (
    echo The query could not be read. Check that the table exists.
)
echo.
exit /b 0

:summary
echo ---------------------------------------------
echo   ROW COUNTS
echo ---------------------------------------------
> "%SQLFILE%" echo SELECT 'users' AS table_name, COUNT(1) AS rows_stored FROM users UNION ALL SELECT 'food_items', COUNT(1) FROM food_items UNION ALL SELECT 'orders', COUNT(1) FROM orders UNION ALL SELECT 'order_items', COUNT(1) FROM order_items UNION ALL SELECT 'payments', COUNT(1) FROM payments;
"%MYSQLBIN%" -u "%DBUSER%" --default-character-set=utf8mb4 --table "!DBNAME!" < "%SQLFILE%" 2>nul
echo.
exit /b 0

:overview
echo.
echo ---------------------------------------------
echo   ORDER OVERVIEW
echo ---------------------------------------------
> "%SQLFILE%" echo SELECT o.order_code, o.order_status, o.total_amount, o.pickup_date, o.pickup_slot, u.name AS student, u.student_id, p.method AS pay_method, p.status AS pay_status, COUNT(oi.id) AS item_lines FROM orders o JOIN users u ON u.id = o.user_id LEFT JOIN payments p ON p.order_id = o.id LEFT JOIN order_items oi ON oi.order_id = o.id GROUP BY o.id, o.order_code, o.order_status, o.total_amount, o.pickup_date, o.pickup_slot, u.name, u.student_id, p.method, p.status ORDER BY o.id;
"%MYSQLBIN%" -u "%DBUSER%" --default-character-set=utf8mb4 --table "!DBNAME!" < "%SQLFILE%" 2>nul
echo.
exit /b 0

:describe
echo.
echo ---------------------------------------------
echo   TABLE STRUCTURE
echo ---------------------------------------------
for %%t in (users food_items orders order_items payments) do (
    echo.
    echo -- %%t --
    > "%SQLFILE%" echo DESCRIBE %%t;
    "%MYSQLBIN%" -u "%DBUSER%" --default-character-set=utf8mb4 --table "!DBNAME!" < "%SQLFILE%" 2>nul
)
echo.
exit /b 0

:workbench
if not defined WORKBENCH (
    echo.
    echo MySQL Workbench is not installed on this computer.
    echo.
    echo You can still use the number menu here, or install Workbench
    echo from https://dev.mysql.com/downloads/workbench/
    echo.
    exit /b 0
)
echo.
echo Opening MySQL Workbench...
echo.
echo   Connection details:
echo     Host     : localhost
echo     Port     : 3306
echo     Database : !DBNAME!
echo     User     : !DBUSER!
echo     Password : the one already in application.properties
echo.
start "" "!WORKBENCH!"
echo Workbench has been opened. Create a new connection with the
echo details above if it does not connect by itself.
echo.
exit /b 0

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
if not defined WORKBENCH (
    if exist "%ProgramFiles%\MySQL\MySQLWorkbench.exe" set "WORKBENCH=%ProgramFiles%\MySQL\MySQLWorkbench.exe"
)
for /d %%d in (
    "%ProgramFiles%\MySQL\MySQL Workbench *"
    "C:\Program Files\MySQL\MySQL Workbench *"
) do (
    if not defined WORKBENCH (
        if exist "%%d\MySQLWorkbench.exe" set "WORKBENCH=%%d\MySQLWorkbench.exe"
    )
)
if not defined WORKBENCH (
    for /d %%d in ("%ProgramFiles%\MySQL") do (
        if not defined WORKBENCH (
            if exist "%%d\MySQLWorkbench.exe" set "WORKBENCH=%%d\MySQLWorkbench.exe"
        )
    )
)
exit /b 0

REM Reads the connection details from application.properties.
REM The password is used but never displayed.
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
if not defined DBUSER set "DBUSER=root"
set "MYSQL_PWD=%DBPASS%"
exit /b 0
