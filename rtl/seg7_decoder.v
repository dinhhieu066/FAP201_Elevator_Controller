// =============================================================================
// File: seg7_decoder.v
// Project: Elevator Controller (FAP201)
// Description:
//   7-Segment Display Decoder (Active-Low) matching FAP201 Lab 06 standards.
//   Displays current floor (1, 2, 3, 4) and displays 'E' during Emergency.
// =============================================================================

`timescale 1ns / 1ps

module seg7_decoder (
    input  wire       i_clk,
    input  wire       i_rst_n,
    input  wire [1:0] i_current_floor, // 0: F1, 1: F2, 2: F3, 3: F4
    input  wire [2:0] i_state,         // FSM state (5: EMERGENCY)
    output reg  [6:0] o_segment_data,  // {g, f, e, d, c, b, a} (0 = ON, 1 = OFF)
    output wire       o_digit_select   // Active-low digit enable
);

    assign o_digit_select = 1'b0; // Enable single 7-segment digit

    // FSM Emergency state code
    localparam S_EMERGENCY = 3'd5;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_segment_data <= 7'b1111111; // All OFF
        end else if (i_state == S_EMERGENCY) begin
            o_segment_data <= 7'b0000110; // 'E' (Emergency)
        end else begin
            case (i_current_floor)
                2'd0: o_segment_data <= 7'b1111001; // Số 1 (b, c ON)
                2'd1: o_segment_data <= 7'b0100100; // Số 2 (a, b, d, e, g ON)
                2'd2: o_segment_data <= 7'b0110000; // Số 3 (a, b, c, d, g ON)
                2'd3: o_segment_data <= 7'b0011001; // Số 4 (b, c, f, g ON)
                default: o_segment_data <= 7'b1111111; // All OFF
            endcase
        end
    end

endmodule
