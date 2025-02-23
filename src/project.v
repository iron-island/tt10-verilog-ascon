/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// TODO: Put inside .f file instead
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

    // All output pins must be assigned. If not used, assign to 0.
    assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
    assign uio_out = 0;
    assign uio_oe  = 0;

    // List all unused inputs to prevent warnings
    wire _unused = &{ena, clk, rst_n, 1'b0};

    // State registers
    wire [63:0] S_0_reg;
    wire [63:0] S_1_reg;
    wire [63:0] S_2_reg;
    wire [63:0] S_3_reg;
    wire [63:0] S_4_reg;

    // Instantiate permutations
    asconp #(
        .NUM_ROUNDS(12)
    ) u_asconp(
        .clk      (clk),
        .rst_n    (rst_n),

        .S_0_reg  (S_0_reg),
        .S_1_reg  (S_1_reg),
        .S_2_reg  (S_2_reg),
        .S_3_reg  (S_3_reg),
        .S_4_reg  (S_4_reg)
    );

endmodule
