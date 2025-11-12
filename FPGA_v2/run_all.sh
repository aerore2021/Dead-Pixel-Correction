#!/bin/bash
# Complete DPC FPGA Simulation Workflow
# This script automates the entire process from image conversion to simulation

set -e  # Exit on error

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "==========================================="
echo "  DPC FPGA Complete Workflow"
echo "==========================================="

# Step 1: Convert PNG images to TXT
echo ""
echo "Step 1/4: Converting PNG images to TXT format..."
echo "-------------------------------------------"
if [ -f "scripts/convert_all_images.sh" ]; then
    bash scripts/convert_all_images.sh
else
    echo "Converting images manually..."
    python3 scripts/png_to_txt.py -a image_inputs/dpc_test_1/
fi

# Step 2: Create Vivado project
echo ""
echo "Step 2/4: Creating Vivado project..."
echo "-------------------------------------------"
if [ ! -d "DPC_Detector_proj" ]; then
    vivado -mode batch -source make.tcl
else
    echo "Project already exists. Skipping project creation."
fi

# Step 3: Run simulation
echo ""
echo "Step 3/4: Running simulation..."
echo "-------------------------------------------"
vivado -mode batch -source sim.tcl

# Step 4: Convert output TXT to PNG
echo ""
echo "Step 4/4: Converting output TXT to PNG..."
echo "-------------------------------------------"
if [ -d "FPGA_outputs" ]; then
    mkdir -p FPGA_outputs/png
    for txtfile in FPGA_outputs/*.txt; do
        if [ -f "$txtfile" ]; then
            basename=$(basename "$txtfile" .txt)
            echo "Converting $basename.txt to PNG..."
            python3 scripts/txt_to_png.py "$txtfile" \
                -o "FPGA_outputs/png/${basename}.png" \
                -w 640 -H 512 -b 14
        fi
    done
else
    echo "Warning: FPGA_outputs directory not found"
fi

echo ""
echo "==========================================="
echo "  Workflow Complete!"
echo "==========================================="
echo "Results are available in:"
echo "  - TXT format: FPGA_outputs/"
echo "  - PNG format: FPGA_outputs/png/"
echo "==========================================="
