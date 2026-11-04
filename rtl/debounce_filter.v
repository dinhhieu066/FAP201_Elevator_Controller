// =============================================================================
// File: debounce_filter.v
// Project: Elevator Controller (FAP201)
// Description:
//   Switch/pushbutton debounce filter matching FAP201 Lab 04 specifications.
//   Removes mechanical bounce transients before signal reaches the core FSM.
// =============================================================================

`timescale 1ns / 1ps

module debounce_filter #(
    parameter DEBOUNCE_LIMIT = 20 // Set small for simulation, 250000 for FPGA kit
)(
    input  wire i_clk,
    input  wire i_rst_n,
    input  wire i_bouncy,
    output wire o_debounced
);

    reg [$clog2(DEBOUNCE_LIMIT)-1:0] r_count = 0;
    reg r_state = 1'b0;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_count <= 0;
            r_state <= 1'b0;
        end else begin
            if (i_bouncy !== r_state && r_count < DEBOUNCE_LIMIT - 1) begin
                r_count <= r_count + 1'b1;
            end else if (r_count == DEBOUNCE_LIMIT - 1) begin
                r_state <= i_bouncy;
                r_count <= 0;
            end else begin
                r_count <= 0;
            end
        end
    end

    assign o_debounced = r_state;

endmodule
