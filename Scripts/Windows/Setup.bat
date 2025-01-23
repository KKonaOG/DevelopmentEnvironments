@echo off
setlocal

:: Get the directory where the script is located
set SCRIPT_DIR=%~dp0

:: Check if it's already in the PATH
echo %PATH% | findstr /i "%SCRIPT_DIR%" >nul
if %errorlevel% equ 0 (
    echo The script directory is already in the PATH.
) else (
    echo Adding the script directory to PATH: %SCRIPT_DIR%
    :: Add the script directory to the user's PATH permanently
    setx PATH "%SCRIPT_DIR%;%PATH%"
    echo Script directory added to PATH permanently.
)

endlocal
