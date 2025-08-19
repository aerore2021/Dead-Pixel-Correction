# Corrector Project Creation Script
# Compatible with Vivado 2021.1 and above
# Usage: vivado -mode tcl -source make.tcl -tclargs [options]
# Options: -synthesis, -simulation, -all
# Author: Aero2021
# Date: July 18, 2025

# Parse command line arguments
set do_synthesis false
set do_simulation false

# Process arguments
foreach arg $argv {
    switch -exact -- $arg {
        "-synthesis" {
            set do_synthesis true
            puts "INFO: Synthesis will be run after project creation"
        }
        "-simulation" {
            set do_simulation true
            puts "INFO: Simulation will be run after project creation"
        }
        "-all" {
            set do_synthesis true
            set do_simulation true
            puts "INFO: Both synthesis and simulation will be run"
        }
        default {
            puts "WARNING: Unknown argument: $arg"
        }
    }
}

# Project configuration
set project_name "DPC_Corrector_proj"
set project_dir "."
set fpga_part "xc7a100tcsg324-1"

# Delete existing project
if {[file exists "$project_dir/$project_name"]} {
    file delete -force "$project_dir/$project_name"
}

# Create new project
create_project $project_name $project_dir/$project_name -part $fpga_part
puts "INFO: Project '$project_name' created successfully"

# Add design files
add_files -norecurse {
    src/DPC_Corrector.v
    src/DPC_Detector_test.v
    src/LineBuf_dpc.v
    src/Fast_Median_Calculator.v
    src/Manual_BadPixel_Checker.v
}

# Add simulation files
add_files -fileset sim_1 -norecurse {
    sim/tb_DPC_Corrector.sv
}

# Set file properties
set_property file_type SystemVerilog [get_files src/DPC_Corrector.v]
set_property file_type SystemVerilog [get_files src/DPC_Detector_test.v]
set_property file_type SystemVerilog [get_files src/LineBuf_dpc.v]
set_property file_type SystemVerilog [get_files src/Fast_Median_Calculator.v]
set_property file_type SystemVerilog [get_files src/Manual_BadPixel_Checker.v]
set_property file_type SystemVerilog [get_files sim/tb_DPC_Corrector.sv]

# Set top modules
set_property top DPC_Detector [get_filesets sources_1]
set_property top tb_DPC_Detector [get_filesets sim_1]
puts "INFO: Source files added successfully"

# Generate DPC_Detector dedicated BRAM IP
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name BRAM_32x1024
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name BRAM_BadPoint_Dual

# Configure BRAM parameters - Optimized for DPC_Detector
set_property -dict [list \
    CONFIG.Memory_Type {Simple_Dual_Port_RAM} \
    CONFIG.Write_Width_A {32} \
    CONFIG.Write_Depth_A {1024} \
    CONFIG.Read_Width_B {32} \
    CONFIG.Enable_A {Always_Enabled} \
    CONFIG.Enable_B {Use_ENB_Pin} \
    CONFIG.Register_PortB_Output_of_Memory_Primitives {false} \
    CONFIG.Use_Byte_Write_Enable {false} \
    CONFIG.Byte_Size {9} \
    CONFIG.Assume_Synchronous_Clk {true} \
] [get_ips BRAM_32x1024]

puts "INFO: BRAM IP 'BRAM_32x1024' configured successfully"

# Generate IP - Wait for completion
puts "INFO: Generating BRAM IP files..."
generate_target all [get_ips BRAM_32x1024]
create_ip_run [get_ips BRAM_32x1024]
launch_runs BRAM_32x1024_synth_1
wait_on_run BRAM_32x1024_synth_1

if {[get_property PROGRESS [get_runs BRAM_32x1024_synth_1]] == "100%"} {
    puts "INFO: BRAM IP generated successfully."
} else {
    puts "ERROR: BRAM IP generation failed. Please check the logs for details."
    exit 1
}

# Configure BRAM_BadPoint_Dual parameters
set_property -dict [list \
    CONFIG.Memory_Type {Simple_Dual_Port_RAM} \
    CONFIG.Write_Width_A {32} \
    CONFIG.Write_Depth_A {128} \
    CONFIG.Read_Width_B {32} \
    CONFIG.Enable_A {Always_Enabled} \
    CONFIG.Enable_B {Use_ENB_Pin} \
    CONFIG.Register_PortB_Output_of_Memory_Primitives {false} \
    CONFIG.Use_Byte_Write_Enable {false} \
    CONFIG.Byte_Size {9} \
    CONFIG.Assume_Synchronous_Clk {true} \
] [get_ips BRAM_BadPoint_Dual]

puts "INFO: BRAM IP 'BRAM_BadPoint_Dual' configured successfully"

# Generate IP - Wait for completion
puts "INFO: Generating BRAM IP files..."
generate_target all [get_ips BRAM_BadPoint_Dual]
create_ip_run [get_ips BRAM_BadPoint_Dual]
launch_runs BRAM_BadPoint_Dual_synth_1
wait_on_run BRAM_BadPoint_Dual_synth_1

if {[get_property PROGRESS [get_runs BRAM_BadPoint_Dual_synth_1]] == "100%"} {
    puts "INFO: BRAM IP generated successfully."
} else {
    puts "ERROR: BRAM IP generation failed. Please check the logs for details."
    exit 1
}

# Refresh the project to ensure IP files are recognized
update_compile_order -fileset sources_1
puts "INFO: IP generation and project refresh completed"

# Create constraints file
set constraints_content {# DPC_Detector Project Clock Constraints
create_clock -period 10.0 -name clk -waveform {0.000 5.000} [get_ports clk]

# Input/Output Delay Constraints
# Note: When using SystemVerilog interfaces, individual signals are not exposed as ports
# These constraints will be applied at the interface level during elaboration

# Clock Uncertainty
set_clock_uncertainty -setup 0.1 -hold 0.1 [get_clocks clk]

# False Path Constraints for Reset
set_false_path -from [get_ports rst_n] -to [all_registers]

# Multi-cycle path constraints for BRAM lookup (commented out - adjust path names as needed)
# set_multicycle_path -setup 2 -from [get_cells {*/bram_reg[*]}] -to [get_cells {*/m_axis_tdata_reg[*]}]
# set_multicycle_path -hold 1 -from [get_cells {*/bram_reg[*]}] -to [get_cells {*/m_axis_tdata_reg[*]}]

# Timing exceptions for real number calculations (synthesis time)
# These paths are pre-calculated and stored in BRAM, so no additional timing constraints needed
}

set constraints_file "$project_dir/$project_name/constraints.xdc"

set file [open $constraints_file "w"]
puts $file $constraints_content
close $file

add_files -fileset constrs_1 -norecurse $constraints_file
puts "INFO: Constraints file created successfully"

# Set synthesis strategy
set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
set_property strategy "Vivado Implementation Defaults" [get_runs impl_1]

# Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Verify IP files are present
set ip_files [get_files -filter {FILE_TYPE == IP}]
if {[llength $ip_files] > 0} {
    puts "INFO: Found IP files: $ip_files"
} else {
    puts "WARNING: No IP files found in project"
}

puts "INFO: Project setup completed"
puts "=========================================="
puts "DPC Corrector Project Created Successfully!"
puts "=========================================="
puts "Project is ready for synthesis and simulation."
puts "=========================================="

# Execute additional steps based on arguments
if {$do_synthesis && $do_simulation} {
    puts "INFO: Running synthesis and simulation..."
    source syn.tcl
    source sim.tcl
} elseif {$do_synthesis} {
    puts "INFO: Running synthesis..."
    source syn.tcl
} elseif {$do_simulation} {
    puts "INFO: Running simulation..."
    source sim.tcl
} else {
    puts "INFO: Project creation completed. No additional steps requested."
}

puts "INFO: All requested operations completed successfully!"