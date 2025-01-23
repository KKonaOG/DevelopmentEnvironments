@echo off
setlocal enabledelayedexpansion

:: Get the batch file's directory and construct the path to the Devcontainers folder
set "SCRIPT_DIR=%~dp0"
set "ROOT_FOLDER=%SCRIPT_DIR%..\..\Devcontainers"

:: Initialize variables
set "USER_INPUT="
set "FORCE=false"
set "OPEN=false"

:: Loop through arguments and process them
:parse_args
if "%~1"=="" goto :check_user_input
if /i "%~1"=="--force" (
    set "FORCE=true"
    shift
    goto :parse_args
)
if /i "%~1"=="--open" (
    set "OPEN=true"
    shift
    goto :parse_args
)
if /i "%~1"=="--list" (
    call :list_devcontainers
    exit /b
)
:: Set the USER_INPUT if it's not set already
if not defined USER_INPUT (
    set "USER_INPUT=%~1"
    shift
    goto :parse_args
)

:check_user_input
if "%USER_INPUT%"=="" (
    if "!OPEN!"=="true" (
        :: If --open is specified and no Devcontainer is provided, check for existing .devcontainer
        if not exist ".devcontainer" (
            echo WARNING: .devcontainer folder does not exist in the current directory.
            exit /b
        )
        echo Opening existing devcontainer from .devcontainer folder...
        devcontainer open .
        exit /b
    )
    call :display_help
    exit /b
)

:: Loop through the directories containing devcontainer.json and extract the folder names
set "MATCH_FOUND=false"
for /f "delims=" %%A in ('dir "%ROOT_FOLDER%\devcontainer.json" /s /b') do (
    :: Get the path of the folder containing the devcontainer.json file
    set "FILE_PATH=%%~dpA"

    :: Remove everything before and including "DevelopmentEnvironments" and "Devcontainers"
    set "REL_PATH=!FILE_PATH:*DevelopmentEnvironments\=!"
    set "REL_PATH=!REL_PATH:Devcontainers\=!"

    :: Remove trailing backslash (if it exists)
    if "!REL_PATH:~-1!"=="\" set "REL_PATH=!REL_PATH:~0,-1!"

    :: Check if the folder matches the user input
    if /i "!REL_PATH!"=="%USER_INPUT%" (
        echo Match found: !REL_PATH!
        set "MATCH_FOUND=true"

        :: Create the .devcontainer folder if it doesn't exist
        if not exist ".devcontainer" (
            mkdir ".devcontainer"
            echo .devcontainer folder created.
        )

        :: If --force is specified and .devcontainer exists, backup the existing .devcontainer folder
        if "!FORCE!"=="true" (
            if exist ".devcontainer\*" (
                echo .devcontainer folder already exists. Backing up existing files to .devcontainer.bak...
                mkdir ".devcontainer.bak"
                xcopy ".devcontainer\*" ".devcontainer.bak\" /s /e /h /y
                echo Backup completed.
            )
        )

        :: Check if devcontainer.json already exists in .devcontainer
        if exist ".devcontainer\devcontainer.json" (
            if not "!FORCE!"=="true" (
                echo WARNING: devcontainer.json already exists in the .devcontainer folder.
                echo Use --force to overwrite.
                exit /b
            ) else (
                echo WARNING: Overwriting existing devcontainer.json.
            )
        )

        :: Copy all files from the matching Devcontainer to the .devcontainer folder
        echo Copying all files from the Devcontainer to .devcontainer...
        xcopy "%%~dpA*" ".devcontainer\" /s /e /h /y

        echo All files copied to the .devcontainer folder.

        :: If --open option is provided, run the `devcontainer open` command
        if "!OPEN!"=="true" (
            echo Opening the devcontainer using `devcontainer open` in the current directory...
            pushd "%cd%"
            devcontainer open .
            popd
        )

        break
    )
)

:: If no match is found, display a message
if not "!MATCH_FOUND!"=="true" (
    echo No matching Devcontainer found for "%USER_INPUT%".
)

endlocal
exit /b

:: Function to display help
:display_help
echo Usage:
echo   UseDC.bat [DevcontainerName] [options]
echo   UseDC.bat --list
echo   UseDC.bat [DevcontainerName] --force
echo   UseDC.bat [DevcontainerName] --open
echo   UseDC.bat --open
echo.
echo   [DevcontainerName] - The name of the Devcontainer to search for.
echo   --list              - List all available Devcontainers.
echo   --force             - Force overwrite of devcontainer.json if it already exists in .devcontainer, and backup existing .devcontainer folder.
echo   --open              - Open the devcontainer using `devcontainer open` command in the current working directory. If no DevcontainerName is provided, it will open the existing .devcontainer folder (if available).
exit /b

:: Function to list all available devcontainers
:list_devcontainers
echo Available Devcontainers:
for /f "delims=" %%A in ('dir "%ROOT_FOLDER%\devcontainer.json" /s /b') do (
    :: Get the path of the folder containing the devcontainer.json file
    set "FILE_PATH=%%~dpA"

    :: Remove everything before and including "DevelopmentEnvironments" and "Devcontainers"
    set "REL_PATH=!FILE_PATH:*DevelopmentEnvironments\=!"
    set "REL_PATH=!REL_PATH:Devcontainers\=!"

    :: Remove trailing backslash (if it exists)
    if "!REL_PATH:~-1!"=="\" set "REL_PATH=!REL_PATH:~0,-1!"

    :: Output the devcontainer folder name
    echo !REL_PATH!
)
exit /b
