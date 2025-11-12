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
puts "DPC CLI Simulation"
puts "=========================================="

# Configure simulation settings
set run_time 10ms
set_property -name {xsim.simulate.runtime} -value $run_time -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.saif} -value {} -objects [get_filesets sim_1]

# start simulation in batch mode
puts "INFO: Starting simulation in batch mode..."
if {[catch {
    launch_simulation

    puts "INFO: Running simulation for $run_time..."
    run $run_time

    puts "INFO: Simulation run completed"

} result]} {
    puts "ERROR: Simulation failed: $result"
    exit 1
} else {
    puts "INFO: Simulation completed successfully"
}


puts "=========================================="
puts "CLI Simulation Finished"
puts "=========================================="
exit 0