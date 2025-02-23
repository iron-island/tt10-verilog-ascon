/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Output states
`define OUT_DOUBLE_BYTES_00 5'd00
`define OUT_DOUBLE_BYTES_01 5'd01
`define OUT_DOUBLE_BYTES_02 5'd02
`define OUT_DOUBLE_BYTES_03 5'd03
`define OUT_DOUBLE_BYTES_04 5'd04
`define OUT_DOUBLE_BYTES_05 5'd05
`define OUT_DOUBLE_BYTES_06 5'd06
`define OUT_DOUBLE_BYTES_07 5'd07
`define OUT_DOUBLE_BYTES_08 5'd08
`define OUT_DOUBLE_BYTES_09 5'd09
`define OUT_DOUBLE_BYTES_10 5'd10
`define OUT_DOUBLE_BYTES_11 5'd11
`define OUT_DOUBLE_BYTES_12 5'd12
`define OUT_DOUBLE_BYTES_13 5'd13
`define OUT_DOUBLE_BYTES_14 5'd14
`define OUT_DOUBLE_BYTES_15 5'd15

// TODO: Put inside .f file instead
`include "./state_controller.v"
`include "./asconp.v"

module tt_um_ascon_ironisland_top (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
    // State registers
    wire [63:0] S_0_reg;
    wire [63:0] S_1_reg;
    wire [63:0] S_2_reg;
    wire [63:0] S_3_reg;
    wire [63:0] S_4_reg;

    // TODO: Remove once extended registers back to 64 bits
    assign S_0_reg[63:48] = 16'd0;
    assign S_1_reg[63:48] = 16'd0;
    assign S_2_reg[63:48] = 16'd0;
    assign S_3_reg[63:48] = 16'd0;
    assign S_4_reg[63:48] = 16'd0;

    // Control signals
    wire rounds_done;
    wire output_enable;

    // I/O drivers
    wire [15:0] double_byte_output;

    // All output pins must be assigned. If not used, assign to 0.
    assign uo_out  = double_byte_output[ 7:0];
    assign uio_out = double_byte_output[15:8];
    assign uio_oe  = {8{output_enable}};

    // List all unused inputs to prevent warnings
    wire _unused = &{ena, ui_in[7:0], uio_in[7:0]};

    // Instantiate state controller
    state_controller u_ctrl(
        .clk      (clk),
        .rst_n    (rst_n),

        .S_0_reg  (S_0_reg),
        .S_1_reg  (S_1_reg),
        .S_2_reg  (S_2_reg),
        .S_3_reg  (S_3_reg),
        .S_4_reg  (S_4_reg),

        .rounds_done(rounds_done),

        .output_enable(output_enable),
        .double_byte_output(double_byte_output)
    );

    // Instantiate permutations
    asconp #(
        .NUM_ROUNDS(12)
    ) u_asconp(
        .clk      (clk),
        .rst_n    (rst_n),

        .S_0_reg  (S_0_reg[47:0]),
        .S_1_reg  (S_1_reg[47:0]),
        .S_2_reg  (S_2_reg[47:0]),
        .S_3_reg  (S_3_reg[47:0]),
        .S_4_reg  (S_4_reg[47:0]),

        .rounds_done(rounds_done)
    );

endmodule
