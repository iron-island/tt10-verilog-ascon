/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// TODO: Put inside .f file instead
`include "./asconp.v"
`include "./spi_subnode.v"

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

    // Control signals
    wire       rounds_done;
    wire [2:0] operation_mode;

    // SPI
    wire csb;
    wire mosi;
    wire miso;
    wire sck;

    assign csb  = uio_in[0];
    assign mosi = uio_in[1];
    assign sck  = uio_in[3];

    // TODO
    // All output pins must be assigned. If not used, assign to 0.
    assign uo_out  = 8'd0;

    assign uio_out[1:0] = 2'd0;
    assign uio_out[2]   = miso;
    assign uio_out[7:3] = 5'd0;

    assign uio_oe[1:0] = 2'd0;
    assign uio_oe[2]   = 1'b1; // always used for MISO, which always drives a 1 even if not being read from
    assign uio_oe[7:3] = 5'd0;

    // List all unused inputs to prevent warnings
    wire _unused = &{ena, ui_in[7:0], uio_in[7:4], uio_in[2]};

    // Instantiate permutations
    // TODO: Make num_rounds an input instead of a parameter
    asconp #(
        .NUM_ROUNDS(12)
    ) u_asconp(
        .clk      (clk),
        .rst_n    (rst_n),

        .S_0_reg  (S_0_reg),
        .S_1_reg  (S_1_reg),
        .S_2_reg  (S_2_reg),
        .S_3_reg  (S_3_reg),
        .S_4_reg  (S_4_reg),

        .rounds_done(rounds_done)
    );

    // Instantiate SPI subnode
    spi_subnode u_spi(
        .rst_n    (rst_n),

        .sck      (sck),
        .csb      (csb),
        .mosi     (mosi),

        .miso     (miso),

        .operation_mode (operation_mode),

        .S_0_reg  (S_0_reg),
        .S_1_reg  (S_1_reg),
        .S_2_reg  (S_2_reg),
        .S_3_reg  (S_3_reg),
        .S_4_reg  (S_4_reg)
    );

endmodule
