@echo off
REM Batch file to move test protocol files from IIS temp to archive
REM On error, send email notification

setlocal enabledelayedexpansion

set SOURCE=C:\IISPP
set DEST=Y:\Archive\Pruefprotokolle
set ERROR_LOG=%TEMP%\move_pruefprotokolle_error.log
set EMAIL_TO=amos.engelking@engelking.de
set ERROR_OCCURRED=0

REM Check if source directory exists
if not exist "%SOURCE%" (
    echo ERROR: Source directory %SOURCE% does not exist > "%ERROR_LOG%"
    set ERROR_OCCURRED=1
    goto SEND_EMAIL
)

REM Check if destination directory exists
if not exist "%DEST%" (
    echo ERROR: Destination directory %DEST% does not exist > "%ERROR_LOG%"
    set ERROR_OCCURRED=1
    goto SEND_EMAIL
)

REM Move all files from source to destination
echo Moving files from %SOURCE% to %DEST%...
for %%F in ("%SOURCE%\*.*") do (
    echo Moving %%~nxF...
    move "%%F" "%DEST%\" >> "%ERROR_LOG%" 2>&1
    if !errorlevel! neq 0 (
        echo ERROR: Failed to move %%~nxF >> "%ERROR_LOG%"
        set ERROR_OCCURRED=1
    )
)

:SEND_EMAIL
if %ERROR_OCCURRED% equ 1 (
    echo Errors occurred during file move operation.
    echo Sending error notification email...
    
    REM Using blat to send email (assuming it's installed and configured)
    REM Adjust the blat parameters according to your SMTP configuration
    blat "%ERROR_LOG%" -to "%EMAIL_TO%" -subject "ERROR: Pruefprotokolle File Move Failed" -body "See attached log for details."
    
    if !errorlevel! neq 0 (
        echo WARNING: Failed to send error notification email
    ) else (
        echo Error notification sent to %EMAIL_TO%
    )
) else (
    echo All files moved successfully.
    if exist "%ERROR_LOG%" del "%ERROR_LOG%"
)

endlocal
exit /b %ERROR_OCCURRED%
