@echo off
REM Batch convert all test images from PNG to TXT format

set SCRIPT_DIR=%~dp0
set IMAGE_DIR=%SCRIPT_DIR%..\image_inputs
set CONVERTER=%SCRIPT_DIR%png_to_txt.py

echo ===========================================
echo   Converting PNG Images to TXT Format
echo ===========================================

REM Check if converter exists
if not exist "%CONVERTER%" (
    echo ERROR: Converter script not found: %CONVERTER%
    exit /b 1
)

REM Process each test directory
for /d %%D in ("%IMAGE_DIR%\dpc_test_*") do (
    echo.
    echo Processing: %%~nxD
    echo -------------------------------------------
    
    python "%CONVERTER%" -a "%%D"
    
    if !errorlevel! equ 0 (
        echo √ Successfully converted images in %%~nxD
    ) else (
        echo × Failed to convert images in %%~nxD
    )
)

echo.
echo ===========================================
echo   Conversion Complete
echo ===========================================

pause
