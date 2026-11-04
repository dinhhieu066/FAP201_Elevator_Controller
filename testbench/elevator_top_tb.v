// =============================================================================
// File: elevator_top_tb.v
// Project: Elevator Controller (FAP201)
// Description:
//   Self-Checking Testbench for Elevator Controller Top Module.
//   Reads stimulus from stimulus.txt, applies inputs to RTL,
//   logs actual outputs to rtl_output.txt, and displays simulation stats.
// =============================================================================

`timescale 1ns / 1ps

module elevator_top_tb;

    // Simulation Parameters (matching Golden Model)
    parameter NUM_FLOORS       = 4;
    parameter MOVE_TICKS       = 10;
    parameter DOOR_OPEN_TICKS  = 10;
    parameter DOOR_CLOSE_TICKS = 4;
    parameter DEBOUNCE_LIMIT   = 1;  // Simulation bypass

    // Clock and Control Signals
    reg                   r_clk;
    reg                   r_rst_n;
    reg  [NUM_FLOORS-1:0] r_req_btn;
    reg                   r_door_sensor;
    reg                   r_emergency_btn;

    // Monitored Output Signals
    wire [1:0]            w_current_floor;
    wire [2:0]            w_state;
    wire                  w_door_open;
    wire [1:0]            w_direction;
    wire [NUM_FLOORS-1:0] w_pending_req;

    wire [6:0]            w_segment_data;
    wire                  w_digit_select;
    wire [NUM_FLOORS-1:0] w_led_floor;
    wire                  w_led_door;
    wire                  w_led_emergency;
    wire                  w_led_dir_up;
    wire                  w_led_dir_down;

    // Instantiate Unit Under Test (UUT)
    elevator_top #(
        .NUM_FLOORS      (NUM_FLOORS),
        .MOVE_TICKS      (MOVE_TICKS),
        .DOOR_OPEN_TICKS (DOOR_OPEN_TICKS),
        .DOOR_CLOSE_TICKS(DOOR_CLOSE_TICKS),
        .DEBOUNCE_LIMIT  (DEBOUNCE_LIMIT)
    ) uut (
        .i_clk          (r_clk),
        .i_rst_n        (r_rst_n),
        .i_req_btn      (r_req_btn),
        .i_door_sensor  (r_door_sensor),
        .i_emergency_btn(r_emergency_btn),

        .o_current_floor(w_current_floor),
        .o_state        (w_state),
        .o_door_open    (w_door_open),
        .o_direction    (w_direction),
        .o_pending_req  (w_pending_req),

        .o_segment_data (w_segment_data),
        .o_digit_select (w_digit_select),
        .o_led_floor    (w_led_floor),
        .o_led_door     (w_led_door),
        .o_led_emergency(w_led_emergency),
        .o_led_dir_up   (w_led_dir_up),
        .o_led_dir_down (w_led_dir_down)
    );

    // Clock Generation (100MHz -> Period = 10ns)
    initial begin
        r_clk = 1'b0;
        forever #5 r_clk = ~r_clk;
    end

    // File I/O Variables
    integer stim_file;
    integer out_file;
    integer status;
    integer sscanf_cnt;
    integer cycle_count;

    reg [1023:0] line_buf;
    integer in_rst_n;
    integer in_req_btn;
    integer in_door_sensor;
    integer in_emergency_btn;

    // Main Test Sequence
    initial begin
        // Setup Waveform dump (usable in GTKWave or ModelSim)
        $dumpfile("elevator_sim.vcd");
        $dumpvars(0, elevator_top_tb);

        // Open input stimulus and output trace files
        stim_file = $fopen("../testbench/stimulus.txt", "r");
        if (stim_file == 0) begin
            // Try current working directory as fallback
            stim_file = $fopen("testbench/stimulus.txt", "r");
        end
        if (stim_file == 0) begin
            stim_file = $fopen("stimulus.txt", "r");
        end

        if (stim_file == 0) begin
            $display("[FATAL ERROR] Could not open 'stimulus.txt'! Check file path.");
            $finish;
        end

        out_file = $fopen("../testbench/rtl_output.txt", "w");
        if (out_file == 0) begin
            out_file = $fopen("testbench/rtl_output.txt", "w");
        end
        if (out_file == 0) begin
            out_file = $fopen("rtl_output.txt", "w");
        end

        $fwrite(out_file, "# Format: <current_floor[1:0]> <state[2:0]> <door_open> <direction[1:0]> <pending_req[3:0]>\n");

        $display("=========================================================================");
        $display("         FAP201 - ELEVATOR CONTROLLER RTL SIMULATION STARTED             ");
        $display("=========================================================================");

        // Initial input conditions
        r_rst_n         = 1'b0;
        r_req_btn       = {NUM_FLOORS{1'b0}};
        r_door_sensor   = 1'b0;
        r_emergency_btn = 1'b0;
        cycle_count     = 0;

        // Process stimulus file cycle-by-cycle
        while (!$feof(stim_file)) begin
            status = $fgets(line_buf, stim_file);
            if (status != 0) begin
                // Check if line is a comment or blank
                if (line_buf[1023:1016] != 8'h23 && line_buf[0] != "#" && line_buf[0] != "\n" && line_buf[0] != "\r") begin
                    sscanf_cnt = $sscanf(line_buf, "%d %d %d %d", in_rst_n, in_req_btn, in_door_sensor, in_emergency_btn);
                    if (sscanf_cnt == 4) begin
                        // Apply inputs at negative clock edge to meet setup time
                        @(negedge r_clk);
                        r_rst_n         = in_rst_n[0];
                        r_req_btn       = in_req_btn[NUM_FLOORS-1:0];
                        r_door_sensor   = in_door_sensor[0];
                        r_emergency_btn = in_emergency_btn[0];

                        // Sample registered outputs shortly after positive clock edge
                        @(posedge r_clk);
                        #1; // Output stabilization delay

                        // Write actual outputs to trace file
                        $fwrite(out_file, "%d %d %d %d %d\n",
                                w_current_floor,
                                w_state,
                                w_door_open,
                                w_direction,
                                w_pending_req);

                        cycle_count = cycle_count + 1;

                        if (cycle_count % 100 == 0) begin
                            $display("[SIM PROGRESS] Completed %0d cycles...", cycle_count);
                        end
                    end
                end
            end
        end

        $fclose(stim_file);
        $fclose(out_file);

        $display("=========================================================================");
        $display("[SIM COMPLETE] Successfully simulated %0d cycles.", cycle_count);
        $display("Results recorded to 'rtl_output.txt'.");
        $display("=========================================================================");

        $finish;
    end

endmodule
