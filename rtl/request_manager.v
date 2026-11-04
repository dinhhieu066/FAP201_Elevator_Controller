// =============================================================================
// File: request_manager.v
// Project: Elevator Controller (FAP201)
// Description:
//   Manages floor call requests from passengers.
//   Latches incoming button presses, clears requests when served,
//   and computes directional request flags for LOOK/SCAN algorithm.
// =============================================================================

`timescale 1ns / 1ps

module request_manager #(
    parameter NUM_FLOORS = 4
)(
    input  wire                  i_clk,
    input  wire                  i_rst_n,
    input  wire [NUM_FLOORS-1:0] i_req_btn,         // Button requests in current cycle
    input  wire [1:0]            i_current_floor,    // Current floor (0..3)
    input  wire [NUM_FLOORS-1:0] i_clear_req_mask,   // Bitmask of requests to clear
    input  wire                  i_emergency_btn,    // Emergency reset of all requests
    output reg  [NUM_FLOORS-1:0] o_pending_req,      // Registered pending requests
    output wire [NUM_FLOORS-1:0] o_effective_req,    // Registered + current button press
    output wire                  o_has_req_above,    // Pending request above current floor
    output wire                  o_has_req_below,    // Pending request below current floor
    output wire                  o_has_req_current   // Pending request at current floor
);

    // Combine current registered requests with incoming button presses
    assign o_effective_req = o_pending_req | i_req_btn;

    // Combinational evaluation of requests above and below current floor
    reg r_above;
    reg r_below;

    always @(*) begin
        case (i_current_floor)
            2'd0: begin // Floor 1
                r_above = |o_effective_req[3:1];
                r_below = 1'b0;
            end
            2'd1: begin // Floor 2
                r_above = |o_effective_req[3:2];
                r_below = o_effective_req[0];
            end
            2'd2: begin // Floor 3
                r_above = o_effective_req[3];
                r_below = |o_effective_req[1:0];
            end
            2'd3: begin // Floor 4
                r_above = 1'b0;
                r_below = |o_effective_req[2:0];
            end
            default: begin
                r_above = 1'b0;
                r_below = 1'b0;
            end
        endcase
    end

    assign o_has_req_above   = r_above;
    assign o_has_req_below   = r_below;
    assign o_has_req_current = o_effective_req[i_current_floor];

    // Synchronous update of pending requests register
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_pending_req <= {NUM_FLOORS{1'b0}};
        end else if (i_emergency_btn) begin
            o_pending_req <= {NUM_FLOORS{1'b0}};
        end else begin
            o_pending_req <= (o_effective_req & ~i_clear_req_mask);
        end
    end

endmodule
