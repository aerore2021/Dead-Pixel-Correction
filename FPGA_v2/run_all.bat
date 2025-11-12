@echo off
REM Complete DPC FPGA Simulation Workflow
REM This script automates the entire process from image conversion to simulation

setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
cd /d "%SCRIPT_DIR%"

echo ===========================================
echo   DPC FPGA Complete Workflow
echo ===========================================

REM Step 1: Convert PNG images to TXT
echo.
echo Step 1/4: Converting PNG images to TXT format...
echo -------------------------------------------
if exist "scripts\convert_all_images.bat" (
    call scripts\convert_all_images.bat
) else (
    echo Converting images manually...
    python scripts\png_to_txt.py -a image_inputs\dpc_test_1\
)

REM Step 2: Create Vivado project
echo.
echo Step 2/4: Creating Vivado project...
echo -------------------------------------------
if not exist "DPC_Detector_proj" (
    vivado -mode batch -source make.tcl
) else (
    echo Project already exists. Skipping project creation.
)

REM Step 3: Run simulation
echo.
echo Step 3/4: Running simulation...
echo -------------------------------------------
vivado -mode batch -source sim.tcl

REM Step 4: Convert output TXT to PNG
echo.
echo Step 4/4: Converting output TXT to PNG...
echo -------------------------------------------
if exist "FPGA_outputs" (
    if not exist "FPGA_outputs\png" mkdir "FPGA_outputs\png"
    for %%f in (FPGA_outputs\*.txt) do (
        echo Converting %%~nf.txt to PNG...
        python scripts\txt_to_png.py "%%f" ^
            -o "FPGA_outputs\png\%%~nf.png" ^
            -w 640 -H 512 -b 14
    )
) else (
    echo Warning: FPGA_outputs directory not found
)

echo.
echo ===========================================
echo   Workflow Complete!
echo ===========================================
echo Results are available in:
echo   - TXT format: FPGA_outputs\
echo   - PNG format: FPGA_outputs\png\
echo ===========================================

pause
