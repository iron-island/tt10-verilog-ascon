/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// TODO: Put inside .f file instead
`include "./sync_2ff.v"
`include "./spi_subnode.v"
`include "./asconp.v"
`include "./ascon.v"

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

    // Input/output registers
    wire [127:0] reg0_128b;
    wire [127:0] reg1_128b;
    wire [127:0] reg2_128b;

    // State registers
    wire [63:0] S_0_reg;
    wire [63:0] S_1_reg;
    wire [63:0] S_2_reg;
    wire [63:0] S_3_reg;
    wire [63:0] S_4_reg;

    // Control signals
    wire [2:0] operation_mode;
    wire       operation_ready;

    wire       state_shift_en;
    wire [2:0] state_shift_sel;
    wire       state_shift_lsb;

    // SPI
    wire csb;
    wire mosi;
    wire miso;
    wire sck;

    assign csb  = uio_in[0];
    assign mosi = uio_in[1];
    assign sck  = uio_in[3];

    // Synchronized SPI signals
    wire csb_sync;
    wire mosi_sync;
    wire sck_sync;

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

    // Instantiate Ascon hardware accelerator
    ascon u_ascon(
        .clk      (clk),
        .rst_n    (rst_n),

        .reg0_128b(reg0_128b),
        .reg1_128b(reg1_128b),
        .reg2_128b(reg2_128b),

        .operation_mode (operation_mode),
        .operation_ready(operation_ready),

        .state_shift_en  (state_shift_en),
        .state_shift_sel (state_shift_sel),
        .state_shift_lsb (state_shift_lsb),

        .S_0_reg  (S_0_reg),
        .S_1_reg  (S_1_reg),
        .S_2_reg  (S_2_reg),
        .S_3_reg  (S_3_reg),
        .S_4_reg  (S_4_reg)
    );

    // Instantiate synchronizers, so that SPI subnode runs on clk domain
    //   so that both the SPI subnode and the Ascon HW accelerator can
    //   read/write freely to the general purpose 128-bit registers reg*_128b
    // Ref: https://github.com/mattvenn/tt10-spi-test/blob/main/src/tt_um_mattvenn_spi_test.v
    sync_2ff u_sck_sync_2ff(
        .data_in  (sck),
        .clk_sync (clk),
        .rst_n    (rst_n),

        .data_sync_out (sck_sync)
    );

    sync_2ff #(
        .RESET_VAL (1'b1)  
    ) u_csb_sync_2ff(
        .data_in  (csb),
        .clk_sync (clk),
        .rst_n    (rst_n),

        .data_sync_out (csb_sync)
    );

    sync_2ff u_mosi_sync_2ff(
        .data_in  (mosi),
        .clk_sync (clk),
        .rst_n    (rst_n),

        .data_sync_out (mosi_sync)
    );

    // Instantiate SPI subnode
    spi_subnode u_spi(
        .clk      (clk),
        .rst_n    (rst_n),

        .sck      (sck_sync),
        .csb      (csb_sync),
        .mosi     (mosi_sync),

        .miso     (miso),

        .reg0_128b(reg0_128b),
        .reg1_128b(reg1_128b),
        .reg2_128b(reg2_128b),

        .operation_mode (operation_mode),
        .operation_ready(operation_ready),

        .state_shift_en  (state_shift_en),
        .state_shift_sel (state_shift_sel),
        .state_shift_lsb (state_shift_lsb),

        .S_0_reg  (S_0_reg),
        .S_1_reg  (S_1_reg),
        .S_2_reg  (S_2_reg),
        .S_3_reg  (S_3_reg),
        .S_4_reg  (S_4_reg)
    );

endmodule
