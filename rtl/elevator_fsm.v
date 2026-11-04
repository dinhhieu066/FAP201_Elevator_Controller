// =============================================================================
// File: elevator_fsm.v
// Project: Elevator Controller (FAP201)
// Description:
//   Finite State Machine implementing the LOOK/SCAN elevator controller logic,
//   floor navigation, door control, safety obstacle detection, and emergency stop.
// =============================================================================

`timescale 1ns / 1ps

module elevator_fsm #(
    parameter NUM_FLOORS       = 4,
    parameter MOVE_TICKS       = 10,
    parameter DOOR_OPEN_TICKS  = 10,
    parameter DOOR_CLOSE_TICKS = 4
)(
    input  wire                  i_clk,
    input  wire                  i_rst_n,
    input  wire [NUM_FLOORS-1:0] i_req_btn,         // Raw floor button inputs
    input  wire                  i_door_sensor,     // Anti-pinch obstacle sensor
    input  wire                  i_emergency_btn,   // Emergency stop button
    input  wire [NUM_FLOORS-1:0] i_effective_req,   // Combined pending + incoming requests
    input  wire                  i_has_req_above,   // Requests above current floor
    input  wire                  i_has_req_below,   // Requests below current floor
    input  wire                  i_has_req_current, // Request at current floor
    output reg  [2:0]            o_state,           // Current FSM state
    output reg  [1:0]            o_direction,       // Current direction (0:IDLE, 1:UP, 2:DOWN)
    output reg  [1:0]            o_current_floor,   // Current cabin floor (0..3)
    output reg                   o_door_open,       // Door open indicator
    output reg  [NUM_FLOORS-1:0] o_clear_req_mask,  // Combinational mask of requests to clear
    output reg                   o_timer_rst,       // Reset hardware timer
    output reg                   o_timer_en         // Enable hardware timer
);

    // FSM State Encoding
    localparam S_IDLE         = 3'd0;
    localparam S_MOVING_UP    = 3'd1;
    localparam S_MOVING_DOWN  = 3'd2;
    localparam S_DOOR_OPEN    = 3'd3;
    localparam S_DOOR_CLOSING = 3'd4;
    localparam S_EMERGENCY    = 3'd5;

    // Direction Encoding
    localparam DIR_IDLE = 2'd0;
    localparam DIR_UP   = 2'd1;
    localparam DIR_DOWN = 2'd2;

    // Internal timer counter matching golden model cycle-accurate behavior
    reg [15:0] r_timer;

    // Helper signals for next floor candidate
    wire [1:0] w_next_up_floor   = o_current_floor + 1'b1;
    wire [1:0] w_next_down_floor = o_current_floor - 1'b1;

    // Requests above/below the next floor candidate
    reg r_above_next_up;
    reg r_below_next_up;
    reg r_above_next_down;
    reg r_below_next_down;

    always @(*) begin
        // Evaluate requests relative to next_up_floor
        case (w_next_up_floor)
            2'd0: begin
                r_above_next_up = |i_effective_req[3:1];
                r_below_next_up = 1'b0;
            end
            2'd1: begin
                r_above_next_up = |i_effective_req[3:2];
                r_below_next_up = i_effective_req[0];
            end
            2'd2: begin
                r_above_next_up = i_effective_req[3];
                r_below_next_up = |i_effective_req[1:0];
            end
            2'd3: begin
                r_above_next_up = 1'b0;
                r_below_next_up = |i_effective_req[2:0];
            end
            default: begin
                r_above_next_up = 1'b0;
                r_below_next_up = 1'b0;
            end
        endcase

        // Evaluate requests relative to next_down_floor
        case (w_next_down_floor)
            2'd0: begin
                r_above_next_down = |i_effective_req[3:1];
                r_below_next_down = 1'b0;
            end
            2'd1: begin
                r_above_next_down = |i_effective_req[3:2];
                r_below_next_down = i_effective_req[0];
            end
            2'd2: begin
                r_above_next_down = i_effective_req[3];
                r_below_next_down = |i_effective_req[1:0];
            end
            2'd3: begin
                r_above_next_down = 1'b0;
                r_below_next_down = |i_effective_req[2:0];
            end
            default: begin
                r_above_next_down = 1'b0;
                r_below_next_down = 1'b0;
            end
        endcase
    end

    // Combinational clear request mask (Cycle-accurate synchronous clear)
    always @(*) begin
        if (i_emergency_btn) begin
            o_clear_req_mask = {NUM_FLOORS{1'b1}};
        end else begin
            o_clear_req_mask = {NUM_FLOORS{1'b0}};
            case (o_state)
                S_IDLE: begin
                    if (i_has_req_current) begin
                        o_clear_req_mask[o_current_floor] = 1'b1;
                    end
                end
                S_MOVING_UP: begin
                    if ((r_timer == (MOVE_TICKS - 1)) && i_effective_req[w_next_up_floor]) begin
                        o_clear_req_mask[w_next_up_floor] = 1'b1;
                    end
                end
                S_MOVING_DOWN: begin
                    if ((r_timer == (MOVE_TICKS - 1)) && i_effective_req[w_next_down_floor]) begin
                        o_clear_req_mask[w_next_down_floor] = 1'b1;
                    end
                end
                S_DOOR_CLOSING: begin
                    if ((r_timer == (DOOR_CLOSE_TICKS - 1)) && !i_door_sensor && !i_req_btn[o_current_floor]) begin
                        if ((o_direction != DIR_UP) && (o_direction != DIR_DOWN)) begin
                            if (i_has_req_current) begin
                                o_clear_req_mask[o_current_floor] = 1'b1;
                            end
                        end
                    end
                end
                default: begin
                    o_clear_req_mask = {NUM_FLOORS{1'b0}};
                end
            endcase
        end
    end

    // Sequential State and Datapath Update
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_state         <= S_IDLE;
            o_direction     <= DIR_IDLE;
            o_current_floor <= 2'd0; // Floor 1
            o_door_open     <= 1'b0;
            r_timer         <= 16'd0;
            o_timer_rst     <= 1'b1;
            o_timer_en      <= 1'b0;
        end else if (i_emergency_btn) begin
            // Emergency stop takes top priority
            o_state     <= S_EMERGENCY;
            o_door_open <= 1'b1;
            o_direction <= DIR_IDLE;
            r_timer     <= 16'd0;
            o_timer_rst <= 1'b1;
            o_timer_en  <= 1'b0;
        end else begin
            // Default control assignments
            o_timer_rst <= 1'b0;
            o_timer_en  <= 1'b1;

            case (o_state)
                // -------------------------------------------------------------
                // EMERGENCY STATE
                // -------------------------------------------------------------
                S_EMERGENCY: begin
                    if (!i_emergency_btn) begin
                        o_state     <= S_IDLE;
                        o_door_open <= 1'b0;
                        r_timer     <= 16'd0;
                        o_timer_rst <= 1'b1;
                    end
                end

                // -------------------------------------------------------------
                // IDLE STATE
                // -------------------------------------------------------------
                S_IDLE: begin
                    o_door_open <= 1'b0;
                    r_timer     <= 16'd0;
                    o_timer_rst <= 1'b1;

                    if (i_has_req_current) begin
                        o_state     <= S_DOOR_OPEN;
                        o_direction <= DIR_IDLE;
                    end else if (i_has_req_above) begin
                        o_state     <= S_MOVING_UP;
                        o_direction <= DIR_UP;
                    end else if (i_has_req_below) begin
                        o_state     <= S_MOVING_DOWN;
                        o_direction <= DIR_DOWN;
                    end else begin
                        o_state     <= S_IDLE;
                        o_direction <= DIR_IDLE;
                    end
                end

                // -------------------------------------------------------------
                // MOVING UP STATE
                // -------------------------------------------------------------
                S_MOVING_UP: begin
                    o_door_open <= 1'b0;
                    o_direction <= DIR_UP;

                    if (r_timer < (MOVE_TICKS - 1)) begin
                        r_timer <= r_timer + 1'b1;
                    end else begin
                        // Arrived at next floor above
                        o_current_floor <= w_next_up_floor;
                        r_timer         <= 16'd0;
                        o_timer_rst     <= 1'b1;

                        if (i_effective_req[w_next_up_floor]) begin
                            o_state <= S_DOOR_OPEN;
                        end else if (!r_above_next_up) begin
                            // No further calls above
                            if (r_below_next_up) begin
                                o_state     <= S_MOVING_DOWN;
                                o_direction <= DIR_DOWN;
                            end else begin
                                o_state     <= S_IDLE;
                                o_direction <= DIR_IDLE;
                            end
                        end
                        // Else continues MOVING_UP
                    end
                end

                // -------------------------------------------------------------
                // MOVING DOWN STATE
                // -------------------------------------------------------------
                S_MOVING_DOWN: begin
                    o_door_open <= 1'b0;
                    o_direction <= DIR_DOWN;

                    if (r_timer < (MOVE_TICKS - 1)) begin
                        r_timer <= r_timer + 1'b1;
                    end else begin
                        // Arrived at next floor below
                        o_current_floor <= w_next_down_floor;
                        r_timer         <= 16'd0;
                        o_timer_rst     <= 1'b1;

                        if (i_effective_req[w_next_down_floor]) begin
                            o_state <= S_DOOR_OPEN;
                        end else if (!r_below_next_down) begin
                            // No further calls below
                            if (r_above_next_down) begin
                                o_state     <= S_MOVING_UP;
                                o_direction <= DIR_UP;
                            end else begin
                                o_state     <= S_IDLE;
                                o_direction <= DIR_IDLE;
                            end
                        end
                        // Else continues MOVING_DOWN
                    end
                end

                // -------------------------------------------------------------
                // DOOR OPEN STATE
                // -------------------------------------------------------------
                S_DOOR_OPEN: begin
                    o_door_open <= 1'b1;

                    // Re-pressing current floor button resets door timer
                    if (i_req_btn[o_current_floor]) begin
                        r_timer     <= 16'd0;
                        o_timer_rst <= 1'b1;
                    end else if (r_timer < (DOOR_OPEN_TICKS - 1)) begin
                        r_timer <= r_timer + 1'b1;
                    end else begin
                        o_state     <= S_DOOR_CLOSING;
                        r_timer     <= 16'd0;
                        o_timer_rst <= 1'b1;
                    end
                end

                // -------------------------------------------------------------
                // DOOR CLOSING STATE
                // -------------------------------------------------------------
                S_DOOR_CLOSING: begin
                    // Obstacle detected or current floor button re-pressed -> Reopen
                    if (i_door_sensor || i_req_btn[o_current_floor]) begin
                        o_state     <= S_DOOR_OPEN;
                        o_door_open <= 1'b1;
                        r_timer     <= 16'd0;
                        o_timer_rst <= 1'b1;
                    end else if (r_timer < (DOOR_CLOSE_TICKS - 1)) begin
                        r_timer <= r_timer + 1'b1;
                    end else begin
                        // Door finished closing
                        o_door_open <= 1'b0;
                        r_timer     <= 16'd0;
                        o_timer_rst <= 1'b1;

                        if (o_direction == DIR_UP) begin
                            if (i_has_req_above) begin
                                o_state <= S_MOVING_UP;
                            end else if (i_has_req_below) begin
                                o_state     <= S_MOVING_DOWN;
                                o_direction <= DIR_DOWN;
                            end else begin
                                o_state     <= S_IDLE;
                                o_direction <= DIR_IDLE;
                            end
                        end else if (o_direction == DIR_DOWN) begin
                            if (i_has_req_below) begin
                                o_state <= S_MOVING_DOWN;
                            end else if (i_has_req_above) begin
                                o_state     <= S_MOVING_UP;
                                o_direction <= DIR_UP;
                            end else begin
                                o_state     <= S_IDLE;
                                o_direction <= DIR_IDLE;
                            end
                        end else begin
                            if (i_has_req_current) begin
                                o_state <= S_DOOR_OPEN;
                            end else if (i_has_req_above) begin
                                o_state     <= S_MOVING_UP;
                                o_direction <= DIR_UP;
                            end else if (i_has_req_below) begin
                                o_state     <= S_MOVING_DOWN;
                                o_direction <= DIR_DOWN;
                            end else begin
                                o_state     <= S_IDLE;
                                o_direction <= DIR_IDLE;
                            end
                        end
                    end
                end

                default: begin
                    o_state     <= S_IDLE;
                    o_direction <= DIR_IDLE;
                end
            endcase
        end
    end

endmodule
