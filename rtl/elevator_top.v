// =============================================================================
// File: elevator_top.v
// Project: Elevator Controller (FAP201)
// Description:
//   Top-level hierarchical RTL module for the 4-floor Elevator Controller.
//   Integrates Request Manager, FSM, 7-Segment Decoder, Status LEDs,
//   and Debounce Filters.
// =============================================================================

`timescale 1ns / 1ps

module elevator_top #(
    parameter NUM_FLOORS       = 4,
    parameter MOVE_TICKS       = 10,
    parameter DOOR_OPEN_TICKS  = 10,
    parameter DOOR_CLOSE_TICKS = 4,
    parameter DEBOUNCE_LIMIT   = 1  // 1 for simulation bypass, 250000 for FPGA hardware
)(
    input  wire                  i_clk,
    input  wire                  i_rst_n,
    input  wire [NUM_FLOORS-1:0] i_req_btn,         // Passenger floor call buttons
    input  wire                  i_door_sensor,     // Anti-pinch obstacle sensor
    input  wire                  i_emergency_btn,   // Emergency stop button
    
    // Core Verification / Interface Ports
    output wire [1:0]            o_current_floor,   // Cabin floor (0:F1, 1:F2, 2:F3, 3:F4)
    output wire [2:0]            o_state,           // FSM state
    output wire                  o_door_open,       // Door open indicator
    output wire [1:0]            o_direction,       // Movement direction (0:IDLE, 1:UP, 2:DOWN)
    output wire [NUM_FLOORS-1:0] o_pending_req,     // Pending requests bitmask
    
    // Hardware Display & Indicator Ports (Gowin Kit)
    output wire [6:0]            o_segment_data,    // 7-segment display bus {g,f,e,d,c,b,a}
    output wire                  o_digit_select,    // 7-segment digit select
    output wire [NUM_FLOORS-1:0] o_led_floor,       // 1-hot LEDs for current floor
    output wire                  o_led_door,        // LED indicator for door state
    output wire                  o_led_emergency,   // LED indicator for emergency stop
    output wire                  o_led_dir_up,      // LED moving up
    output wire                  o_led_dir_down     // LED moving down
);

    // -------------------------------------------------------------------------
    // 1. Debounce Filters for Pushbuttons
    // -------------------------------------------------------------------------
    wire [NUM_FLOORS-1:0] w_clean_req_btn;
    wire                  w_clean_door_sensor;
    wire                  w_clean_emergency_btn;

    generate
        if (DEBOUNCE_LIMIT <= 1) begin : gen_sim_bypass
            // Bypass debounce filters for cycle-accurate simulation
            assign w_clean_req_btn       = i_req_btn;
            assign w_clean_door_sensor   = i_door_sensor;
            assign w_clean_emergency_btn = i_emergency_btn;
        end else begin : gen_hw_debounce
            // Synthesize debounce filters for physical FPGA board
            genvar i;
            for (i = 0; i < NUM_FLOORS; i = i + 1) begin : gen_btn_debouncers
                debounce_filter #(
                    .DEBOUNCE_LIMIT(DEBOUNCE_LIMIT)
                ) u_btn_debouncer (
                    .i_clk      (i_clk),
                    .i_rst_n    (i_rst_n),
                    .i_bouncy   (i_req_btn[i]),
                    .o_debounced(w_clean_req_btn[i])
                );
            end

            debounce_filter #(
                .DEBOUNCE_LIMIT(DEBOUNCE_LIMIT)
            ) u_door_sensor_debouncer (
                .i_clk      (i_clk),
                .i_rst_n    (i_rst_n),
                .i_bouncy   (i_door_sensor),
                .o_debounced(w_clean_door_sensor)
            );

            debounce_filter #(
                .DEBOUNCE_LIMIT(DEBOUNCE_LIMIT)
            ) u_emergency_debouncer (
                .i_clk      (i_clk),
                .i_rst_n    (i_rst_n),
                .i_bouncy   (i_emergency_btn),
                .o_debounced(w_clean_emergency_btn)
            );
        end
    endgenerate

    // -------------------------------------------------------------------------
    // 2. Request Manager Sub-Module
    // -------------------------------------------------------------------------
    wire [NUM_FLOORS-1:0] w_clear_req_mask;
    wire [NUM_FLOORS-1:0] w_effective_req;
    wire                  w_has_req_above;
    wire                  w_has_req_below;
    wire                  w_has_req_current;

    request_manager #(
        .NUM_FLOORS(NUM_FLOORS)
    ) u_request_manager (
        .i_clk            (i_clk),
        .i_rst_n          (i_rst_n),
        .i_req_btn        (w_clean_req_btn),
        .i_current_floor  (o_current_floor),
        .i_clear_req_mask (w_clear_req_mask),
        .i_emergency_btn  (w_clean_emergency_btn),
        .o_pending_req    (o_pending_req),
        .o_effective_req  (w_effective_req),
        .o_has_req_above  (w_has_req_above),
        .o_has_req_below  (w_has_req_below),
        .o_has_req_current(w_has_req_current)
    );

    // -------------------------------------------------------------------------
    // 3. Elevator FSM Controller
    // -------------------------------------------------------------------------
    wire w_timer_rst;
    wire w_timer_en;

    elevator_fsm #(
        .NUM_FLOORS      (NUM_FLOORS),
        .MOVE_TICKS      (MOVE_TICKS),
        .DOOR_OPEN_TICKS (DOOR_OPEN_TICKS),
        .DOOR_CLOSE_TICKS(DOOR_CLOSE_TICKS)
    ) u_elevator_fsm (
        .i_clk            (i_clk),
        .i_rst_n          (i_rst_n),
        .i_req_btn        (w_clean_req_btn),
        .i_door_sensor    (w_clean_door_sensor),
        .i_emergency_btn  (w_clean_emergency_btn),
        .i_effective_req  (w_effective_req),
        .i_has_req_above  (w_has_req_above),
        .i_has_req_below  (w_has_req_below),
        .i_has_req_current(w_has_req_current),
        .o_state          (o_state),
        .o_direction      (o_direction),
        .o_current_floor  (o_current_floor),
        .o_door_open      (o_door_open),
        .o_clear_req_mask (w_clear_req_mask),
        .o_timer_rst      (w_timer_rst),
        .o_timer_en       (w_timer_en)
    );

    // -------------------------------------------------------------------------
    // 4. 7-Segment Display Decoder
    // -------------------------------------------------------------------------
    seg7_decoder u_seg7_decoder (
        .i_clk          (i_clk),
        .i_rst_n        (i_rst_n),
        .i_current_floor(o_current_floor),
        .i_state        (o_state),
        .o_segment_data (o_segment_data),
        .o_digit_select (o_digit_select)
    );

    // -------------------------------------------------------------------------
    // 5. Status LEDs Logic
    // -------------------------------------------------------------------------
    assign o_led_floor[0]   = (o_current_floor == 2'd0);
    assign o_led_floor[1]   = (o_current_floor == 2'd1);
    assign o_led_floor[2]   = (o_current_floor == 2'd2);
    assign o_led_floor[3]   = (o_current_floor == 2'd3);
    assign o_led_door       = o_door_open;
    assign o_led_emergency  = (o_state == 3'd5);
    assign o_led_dir_up     = (o_direction == 2'd1);
    assign o_led_dir_down   = (o_direction == 2'd2);

endmodule
