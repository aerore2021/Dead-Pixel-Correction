# MedFilter Project - CLI Simulation Script
# Compatible with Vivado 2021.1 and above
# Usage: vivado -mode tcl -source sim.tcl
# Note: This script requires the project to be created first

# Author: Aero2021
# Date: July 18, 2025

# Project configuration
set project_name "DPC_Detector_proj"
set project_dir "."

# Check if project exists
if {![file exists "$project_dir/$project_name/$project_name.xpr"]} {
    puts "ERROR: Project '$project_name' not found!"
    puts "Please run 'make.tcl' first to create the project."
    exit 1
} else {
    puts "INFO: Project '$project_name' found"
    # Open the project
    open_project "$project_dir/$project_name/$project_name.xpr"
}

puts "=========================================="
puts "ContrastAdjust CLI Simulation"
puts "=========================================="

# Configure simulation settings
set run_time 100ms
set_property -name {xsim.simulate.runtime} -value {$run_time} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.saif} -value {} -objects [get_filesets sim_1]

# start simulation in batch mode
puts "INFO: Starting simulation in batch mode..."
if {[catch {
    launch_simulation
    
    # Configure VCD output
    set vcd_file "tb_DPC_Detector_simulation.vcd"
    puts "INFO: Configuring VCD output to: $vcd_file"
    
    # Restart simulation to ensure clean state and proper VCD recording
    restart
    
    # Open VCD file for writing
    open_vcd $vcd_file

    # Log specific signals to VCD with explicit hierarchy paths
    # Log testbench signals individually for better control
    puts "INFO: Logging signals to VCD..."
    log_vcd /

    puts "INFO: Running simulation for $run_time..."
    run $run_time

    # Flush VCD before closing
    flush_vcd

    # Close VCD file
    close_vcd
    puts "INFO: VCD output written to $vcd_file"

    # Close simulation
    close_sim
    puts "INFO: Simulation successfully completed"
} result]} {
    puts "ERROR: Simulation failed: $result"
    exit 1
} else {
    puts "INFO: Simulation completed successfully"
}


puts "=========================================="
puts "CLI Simulation Finished"
puts "=========================================="
