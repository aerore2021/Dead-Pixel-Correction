#!/bin/bash
# DPC Project Management Script
# Usage: ./project.sh [command]

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  $1${NC}"
    echo -e "${GREEN}========================================${NC}"
}

print_error() {
    echo -e "${RED}ERROR: $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Command functions
cmd_help() {
    cat << EOF
DPC Project Management Script

Usage: ./project.sh [command]

Commands:
    help            Show this help message
    setup           Install Python dependencies
    test            Test image conversion tools
    convert         Convert all PNG images to TXT
    clean           Clean generated files
    create          Create Vivado project
    sim             Run simulation
    syn             Run synthesis
    all             Run complete workflow (convert + create + sim)
    results         Convert output TXT to PNG
    status          Show project status

Examples:
    ./project.sh setup          # First-time setup
    ./project.sh all            # Run everything
    ./project.sh sim            # Just run simulation
    ./project.sh results        # Convert outputs to PNG

EOF
}

cmd_setup() {
    print_header "Setting Up Python Environment"
    
    if command -v python3 &> /dev/null; then
        echo "Python3 found: $(python3 --version)"
    else
        print_error "Python3 not found. Please install Python 3.x"
        exit 1
    fi
    
    echo "Installing Python dependencies..."
    pip3 install -r requirements.txt
    
    print_success "Setup complete"
}

cmd_test() {
    print_header "Testing Image Conversion"
    
    python3 scripts/test_conversion.py
}

cmd_convert() {
    print_header "Converting PNG Images to TXT"
    
    bash scripts/convert_all_images.sh
}

cmd_clean() {
    print_header "Cleaning Generated Files"
    
    echo "Removing Vivado project..."
    rm -rf DPC_Detector_proj
    
    echo "Removing converted TXT files..."
    find image_inputs -name "*.txt" -delete
    
    echo "Removing output files..."
    rm -f FPGA_outputs/*.txt
    rm -rf FPGA_outputs/png
    
    echo "Removing Vivado logs..."
    rm -f *.log *.jou
    
    print_success "Clean complete"
}

cmd_create() {
    print_header "Creating Vivado Project"
    
    if [ -d "DPC_Detector_proj" ]; then
        print_warning "Project already exists"
        read -p "Remove and recreate? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf DPC_Detector_proj
        else
            echo "Skipping project creation"
            return 0
        fi
    fi
    
    vivado -mode batch -source make.tcl
    
    print_success "Project created"
}

cmd_sim() {
    print_header "Running Simulation"
    
    if [ ! -d "DPC_Detector_proj" ]; then
        print_error "Project not found. Run './project.sh create' first"
        exit 1
    fi
    
    vivado -mode batch -source sim.tcl
    
    print_success "Simulation complete"
}

cmd_syn() {
    print_header "Running Synthesis"
    
    if [ ! -d "DPC_Detector_proj" ]; then
        print_error "Project not found. Run './project.sh create' first"
        exit 1
    fi
    
    vivado -mode batch -source syn.tcl
    
    print_success "Synthesis complete"
}

cmd_all() {
    cmd_convert
    cmd_create
    cmd_sim
    cmd_results
    
    print_header "All Done!"
    echo "Results are available in FPGA_outputs/png/"
}

cmd_results() {
    print_header "Converting Output TXT to PNG"
    
    if [ ! -d "FPGA_outputs" ]; then
        print_error "FPGA_outputs directory not found"
        exit 1
    fi
    
    mkdir -p FPGA_outputs/png
    
    for txtfile in FPGA_outputs/*.txt; do
        if [ -f "$txtfile" ]; then
            basename=$(basename "$txtfile" .txt)
            echo "Converting $basename.txt..."
            python3 scripts/txt_to_png.py "$txtfile" \
                -o "FPGA_outputs/png/${basename}.png" \
                -w 640 -H 512 -b 14
        fi
    done
    
    print_success "Conversion complete"
}

cmd_status() {
    print_header "Project Status"
    
    echo "Python Environment:"
    if command -v python3 &> /dev/null; then
        echo "  ✓ Python3: $(python3 --version)"
    else
        echo "  ✗ Python3: Not found"
    fi
    
    echo ""
    echo "Vivado:"
    if command -v vivado &> /dev/null; then
        echo "  ✓ Vivado: Available"
    else
        echo "  ✗ Vivado: Not found in PATH"
    fi
    
    echo ""
    echo "Project:"
    if [ -d "DPC_Detector_proj" ]; then
        echo "  ✓ Vivado project exists"
    else
        echo "  ✗ Vivado project not created"
    fi
    
    echo ""
    echo "Input Images:"
    png_count=$(find image_inputs -name "*.png" | wc -l)
    txt_count=$(find image_inputs -name "*.txt" | wc -l)
    echo "  PNG files: $png_count"
    echo "  TXT files: $txt_count"
    
    echo ""
    echo "Output Files:"
    if [ -d "FPGA_outputs" ]; then
        out_txt_count=$(find FPGA_outputs -maxdepth 1 -name "*.txt" | wc -l)
        out_png_count=$(find FPGA_outputs/png -name "*.png" 2>/dev/null | wc -l || echo "0")
        echo "  TXT outputs: $out_txt_count"
        echo "  PNG outputs: $out_png_count"
    else
        echo "  No outputs yet"
    fi
}

# Main script
case "${1:-help}" in
    help)
        cmd_help
        ;;
    setup)
        cmd_setup
        ;;
    test)
        cmd_test
        ;;
    convert)
        cmd_convert
        ;;
    clean)
        cmd_clean
        ;;
    create)
        cmd_create
        ;;
    sim)
        cmd_sim
        ;;
    syn)
        cmd_syn
        ;;
    all)
        cmd_all
        ;;
    results)
        cmd_results
        ;;
    status)
        cmd_status
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        cmd_help
        exit 1
        ;;
esac
