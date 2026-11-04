# =============================================================================
# ModelSim GUI Macro Script: run_gui.do
# Project: Elevator Controller (FAP201)
# Description:
#   Compiles RTL and Testbench, loads simulation with waveform visualization,
#   adds labeled and color-coded wave signals, executes simulation, and zooms to fit.
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

# 4. Load simulation into ModelSim GUI
puts "--> Starting Simulation with Waveforms..."
vsim -t 1ns -voptargs=+acc work.elevator_top_tb

# 5. Configure Waveform Window
delete wave *

add wave -divider "CLOCK & RESET"
add wave -color "Yellow" /elevator_top_tb/r_clk
add wave -color "Red"    /elevator_top_tb/r_rst_n

add wave -divider "INPUT STIMULUS"
add wave -color "Cyan"   -radix bin      /elevator_top_tb/r_req_btn
add wave -color "Orange" /elevator_top_tb/r_door_sensor
add wave -color "Magenta"/elevator_top_tb/r_emergency_btn

add wave -divider "ELEVATOR CORE STATUS"
add wave -color "Green"  -radix unsigned /elevator_top_tb/w_current_floor
add wave -color "White"  -radix unsigned /elevator_top_tb/w_state
add wave -color "Yellow" /elevator_top_tb/w_door_open
add wave -color "Cyan"   -radix unsigned /elevator_top_tb/w_direction
add wave -color "Pink"   -radix bin      /elevator_top_tb/w_pending_req

add wave -divider "FSM INTERNAL TIMERS"
add wave -color "Yellow" -radix unsigned /elevator_top_tb/uut/u_elevator_fsm/r_timer
add wave -color "Cyan"   -radix bin      /elevator_top_tb/uut/u_elevator_fsm/o_clear_req_mask

add wave -divider "7-SEGMENT & STATUS LEDS"
add wave -color "White"  -radix bin      /elevator_top_tb/w_segment_data
add wave -color "Green"  -radix bin      /elevator_top_tb/w_led_floor
add wave -color "Yellow" /elevator_top_tb/w_led_door
add wave -color "Red"    /elevator_top_tb/w_led_emergency
add wave -color "Cyan"   /elevator_top_tb/w_led_dir_up
add wave -color "Orange" /elevator_top_tb/w_led_dir_down

# 6. Run simulation across all test vectors
run -all

# 7. Zoom Waveform to Full View
wave zoom full

puts "========================================================================="
puts " [SUCCESS] ModelSim GUI Simulation Completed! You can inspect the Wave window."
puts "========================================================================="
