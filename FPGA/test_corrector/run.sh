#!/bin/bash
# Median Filter Project Quick Start Script
# This script ensures clean project creation and build using separated TCL scripts
# Updated: 2025.7.16 - Using separated TCL scripts for better modularity

# Default options
DO_SYNTHESIS=false
DO_SIMULATION=false

# Function to display usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -s, --synthesis      Run synthesis after project creation"
    echo "  -sim, --simulation   Run simulation"
    echo "  -a, --all           Run all steps (synthesis + simulation)"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                  # Only create project"
    echo "  $0 -s               # Create project and run synthesis (incremental)"
    echo "  $0 -sim             # Create project and run simulation (incremental)"
    echo "  $0 -a               # Create project and run all steps (incremental)"
    echo "  $0 -f -s            # Force rebuild and run synthesis"
    choe "  s0 -f -a           # Force rebuild and run all steps (synthesis + simulation)"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--synthesis)
            DO_SYNTHESIS=true
            shift
            ;;
        -sim|--simulation)
            DO_SIMULATION=true
            DO_SYNTHESIS=false
            shift
            ;;
        -a|--all)
            DO_SYNTHESIS=true
            DO_SIMULATION=true
            shift
            ;;
        -f|--force)
            FORCE_REBUILD=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

echo "=========================================="
echo "   DPC Corrector Project Quick Start"
echo "=========================================="
echo "Options selected:"
echo "  - Synthesis: $DO_SYNTHESIS"
echo "  - Simulation: $DO_SIMULATION"
echo "  - Force rebuild: $FORCE_REBUILD"
echo "=========================================="

# Function to check if project exists
check_project_exists() {
    local project_dir="DPC_Corrector_proj"
    local project_file="$project_dir/DPC_Corrector_proj.xpr"

    if [ -f "$project_file" ]; then
        echo "Project already exists"
        return 0  # Project exists
    else
        echo "Project not found. Need to create project."
        return 1  # Project needs to be created
    fi
}

echo "Using separated TCL scripts for modular build process"

# Kill any existing Vivado processes
echo "Checking for existing Vivado processes..."
    tasklist | grep vivado > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Found existing Vivado processes. Attempting to terminate..."
        taskkill /f /im vivado.exe > /dev/null 2>&1
        sleep 2
fi

# Determine what needs to be done
NEED_PROJECT_REBUILD=false
NEED_SYNTHESIS=false
NEED_SIMULATION=false

# Check if we need to rebuild the project
if [ "$FORCE_REBUILD" = true ]; then
    echo "Force rebuild requested - will recreate project"
    NEED_PROJECT_REBUILD=true
    NEED_SYNTHESIS=$DO_SYNTHESIS
    NEED_SIMULATION=$DO_SIMULATION
else
    # Simple checking: if project exists, don't rebuild
    if check_project_exists; then
        echo "Project exists - using existing project"
        NEED_PROJECT_REBUILD=false
        NEED_SYNTHESIS=$DO_SYNTHESIS
        NEED_SIMULATION=$DO_SIMULATION
    else
        echo "Project doesn't exist - will create new project"
        NEED_PROJECT_REBUILD=true
        NEED_SYNTHESIS=$DO_SYNTHESIS
        NEED_SIMULATION=$DO_SIMULATION
    fi
fi

# Clean up and rebuild if necessary
if [ "$NEED_PROJECT_REBUILD" = true ]; then
    # Clean up any existing project directory
    if [ -d "DPC_Detector_proj" ]; then
        echo "Removing existing project directory..."
        rm -rf DPC_Detector_proj > /dev/null 2>&1
        sleep 1
    fi

    # Clean up log and journal files
    echo "Cleaning up previous log and journal files..."
    rm -f vivado*.log > /dev/null 2>&1
    rm -f vivado*.jou > /dev/null 2>&1
    rm -f *.log > /dev/null 2>&1
    rm -f *.jou > /dev/null 2>&1
    rm -f vivado_pid*.str > /dev/null 2>&1
    rm -f vivado_pid*.debug > /dev/null 2>&1
    rm -f .Xil > /dev/null 2>&1
    rm -rf .Xil/ > /dev/null 2>&1
    echo "Log and journal files cleaned."
fi

# Create and build project using separated TCL scripts
echo "=========================================="
if [ "$NEED_PROJECT_REBUILD" = true ]; then
    echo "Creating DPC Detector project..."
elif [ "$NEED_SYNTHESIS" = true ] || [ "$NEED_SIMULATION" = true ]; then
    echo "Running requested operations on existing project..."
else
    echo "Project is up-to-date, nothing to do"
fi
echo "=========================================="

# Execute operations if needed
if [ "$NEED_PROJECT_REBUILD" = true ] || [ "$NEED_SYNTHESIS" = true ] || [ "$NEED_SIMULATION" = true ]; then
    echo "Running project operations..."

# Prepare arguments for make.tcl
TCL_ARGS=""
    if [ "$NEED_SYNTHESIS" = true ] && [ "$NEED_SIMULATION" = true ]; then
    TCL_ARGS="-all"
    elif [ "$NEED_SYNTHESIS" = true ]; then
    TCL_ARGS="-synthesis"
    elif [ "$NEED_SIMULATION" = true ]; then
    TCL_ARGS="-simulation"
fi

# Run make.tcl with appropriate arguments
if [ -n "$TCL_ARGS" ]; then
    echo "Running: vivado -mode tcl -source make.tcl -tclargs $TCL_ARGS"
    vivado -mode tcl -source make.tcl -tclargs $TCL_ARGS
else
    echo "Running: vivado -mode tcl -source make.tcl"
    vivado -mode tcl -source make.tcl
fi

if [ $? -ne 0 ]; then
        echo "ERROR: Project operations failed!"
    exit 1
fi

    echo "Project operations completed successfully!"
else
    echo "No operations needed - project is up-to-date!"
fi

echo "=========================================="
echo "Build process completed successfully!"
echo "=========================================="

# Summary
echo "Summary:"
echo "  - Project: $([ "$NEED_PROJECT_REBUILD" = true ] && echo "rebuilt ✓" || echo "up-to-date ✓")"
if [ "$DO_SYNTHESIS" = true ]; then
    echo "  - Synthesis: $([ "$NEED_SYNTHESIS" = true ] && echo "completed ✓" || echo "already done ✓")"
fi
if [ "$DO_SIMULATION" = true ]; then
    echo "  - Simulation: $([ "$NEED_SIMULATION" = true ] && echo "completed ✓" || echo "already done ✓")"
fi

echo "=========================================="

