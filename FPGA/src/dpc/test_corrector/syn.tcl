# MedFilter Project Synthesis Script
# Compatible with Vivado 2021.1 and above
# Usage:
#   vivado -mode tcl -source syn.tcl                    # Default: batch synthesis
# Note: This script requires the project to be created first using make.tcl
# Author: Aero2021
# Date: July 18, 2025

# Project configuration
set project_name "DPC_Corrector_proj"
set project_dir "."

# Check if project exists
if {![file exists "$project_dir/$project_name/$project_name.xpr"]} {
    puts "ERROR: Project $project_name does not exist. Please create it first using make.tcl."
    exit 1
}

# Check if project is open
set current_project ""
if {[catch {current_project} current_project]} {
    puts "INFO: No project is currently open. Opening project $project_name."
    open_project "$project_dir/$project_name/$project_name.xpr"
} else {
    if {$current_project ne "$project_name"} {
        puts "INFO: Switching to project $project_name."
        close_project
        open_project "$project_dir/$project_name/$project_name.xpr"
    } else {
        puts "INFO: Project $project_name is already open."
    }
}

# Verify project state
set ip_files [get_files -filter {FILE_TYPE == "IP"}]
if {[llength $ip_files] == 0} {
    puts "WARNING: No IP files found in project $project_name. Please ensure the project is set up correctly."
}

# Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "=========================================="
puts "Starting ContrastAdjust Project Synthesis Process"
puts "=========================================="

# Auto-run synthesis
puts "Starting Synthesis..."

# check if synthesis run already exists and is complete
set synth_status [get_property STATUS [get_runs synth_1]]
set synth_progress [get_property PROGRESS [get_runs synth_1]]

if {$synth_status eq "synth_design Complete!" && $synth_progress == 100} {
    puts "INFO: Synthesis already completed successfully."
} else {
    puts "INFO: Running synthesis..."
    reset_run synth_1
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    set synth_status [get_property STATUS [get_runs synth_1]]
    
    if {$synth_status ne "synth_design Complete!"} {
        puts "ERROR: Synthesis failed. Please check the logs for details."
        exit 1
    } else {
        puts "INFO: Synthesis completed successfully."
    }
}

# Check synthesis results
if {[get_property PROGRESS [get_runs synth_1]] == "100%"} {
    puts "Success: Synthesis completed successfully."
    puts "Synthesis Status: [get_property STATUS [get_runs synth_1]]"

    # Open Synthesis run
    open_run synth_1 -name synth_1

    # Display synthesis report summary
    puts "\n=========================================="
    puts "Synthesis Report Summary:"
    puts "=========================================="

    # Get resource utilization
    if {[catch {report_utilization -return_string} util_report]} {
        puts "INFO: Utilization report not available"
    } else {
        puts "Resource Utilization:"
        puts $util_report
    }

    # Get timing summary
    if {[catch {report_timing_summary -return_string} timing_report]} {
        puts "INFO: Timing report not available"
    } else {
        puts "Timing Summary:"
        puts $timing_report
    }
    puts "=========================================="
    puts "Synthesis completed successfully!"
    puts "=========================================="
} else {
    puts "=========================================="
    puts "ERROR: Synthesis did not complete successfully. Please check the logs."
    puts "Synthesis Status: [get_property STATUS [get_runs synth_1]]"
    puts "Progress: [get_property PROGRESS [get_runs synth_1]]"
    
    # try to get error messages
    if {[catch {get_msg_config -rules} msg_rules]} {
        puts "INFO: No error messages available."
    } else {
        puts "\nError Messages:"
        if {[catch {get_messages -severity ERROR} error_msgs]} {
            puts "No error messages found."
        } else {
            foreach msg $error_msgs {
                puts "ERROR: $msg"
            }
        }
    }
    puts "=========================================="

    exit 1
}

puts "Synthesis Script Execution Completed."