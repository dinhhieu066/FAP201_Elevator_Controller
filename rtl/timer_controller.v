// =============================================================================
// File: timer_controller.v
// Project: Elevator Controller (FAP201)
// Description:
//   Configurable hardware timer for elevator travel between floors
//   and door dwell times (open/close).
// =============================================================================

`timescale 1ns / 1ps

module timer_controller #(
    parameter MOVE_TICKS       = 10,
    parameter DOOR_OPEN_TICKS  = 10,
    parameter DOOR_CLOSE_TICKS = 4
)(
    input  wire        i_clk,
    input  wire        i_rst_n,
    input  wire        i_timer_rst,        // Synchronously reset timer to 0
    input  wire        i_timer_en,         // Enable timer increment
    output reg  [15:0] o_timer_cnt,        // Current timer count
    output wire        o_move_done,        // High when move interval reached
    output wire        o_door_open_done,   // High when door open dwell reached
    output wire        o_door_close_done   // High when door close interval reached
);

    assign o_move_done       = (o_timer_cnt >= (MOVE_TICKS - 1));
    assign o_door_open_done  = (o_timer_cnt >= (DOOR_OPEN_TICKS - 1));
    assign o_door_close_done = (o_timer_cnt >= (DOOR_CLOSE_TICKS - 1));

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_timer_cnt <= 16'd0;
        end else if (i_timer_rst) begin
            o_timer_cnt <= 16'd0;
        end else if (i_timer_en) begin
            o_timer_cnt <= o_timer_cnt + 1'b1;
        end
    end

endmodule
