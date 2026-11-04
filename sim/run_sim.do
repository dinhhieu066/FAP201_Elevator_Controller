# =============================================================================
# ModelSim Macro Script: run_sim.do
# Project: Elevator Controller (FAP201)
# =============================================================================

# 1. Create and map working library
if ![file exists work] {
    vlib work
}
vmap work work

# 2. Compile RTL design modules
puts "--> Compiling RTL design modules..."
vlog -work work ../rtl/debounce_filter.v
vlog -work work ../rtl/seg7_decoder.v
vlog -work work ../rtl/timer_controller.v
vlog -work work ../rtl/request_manager.v
vlog -work work ../rtl/elevator_fsm.v
vlog -work work ../rtl/elevator_top.v

# 3. Compile Testbench
puts "--> Compiling Testbench..."
vlog -work work ../testbench/elevator_top_tb.v

# 4. Load simulation
puts "--> Starting Simulation..."
vsim -c -t 1ns -voptargs=+acc work.elevator_top_tb

# 5. Execute simulation
run -all

# 6. Exit
quit -f
