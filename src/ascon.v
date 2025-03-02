
// Operation modes
`define IDLE_MODE    3'b000
`define ENCRYPT_MODE 3'b001
`define DECRYPT_MODE 3'b010
`define HASH_MODE    3'b011
`define XOF_MODE     3'b100
`define CXOF_MODE    3'b101

// Ascon states
`define IDLE_STATE      3'b000
`define INIT_STATE      3'b001
`define DATA_PROC_STATE 3'b010
`define TEXT_PROC_STATE 3'b011
`define FINAL_STATE     3'b100
`define CUSTOM_STATE    3'b101
`define ABSORB_STATE    3'b110
`define SQUEEZE_STATE   3'b111

module ascon(
    input wire clk,
    input wire rst_n,

    input wire [127:0] reg0_128b,
    input wire [127:0] reg1_128b,
    input wire [127:0] reg2_128b,

    input wire [2:0] operation_mode,
    input wire       operation_ready,

    output reg [63:0] S_0_reg,
    output reg [63:0] S_1_reg,
    output reg [63:0] S_2_reg,
    output reg [63:0] S_3_reg,
    output reg [63:0] S_4_reg
);

    // State machine controller for each algorithm
    reg [2:0] ascon_state;
    reg [2:0] next_ascon_state;

    reg [3:0] ascon_counter;
    reg [3:0] next_ascon_counter;

    always@(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ascon_state <= 3'd0;

            ascon_counter <= 4'd0;
        end else begin
            ascon_state <= next_ascon_state;

            ascon_counter <= next_ascon_counter;
        end
    end

    // State transition logic
    reg load_init_val;
    reg rounds_enable;

    reg [2:0] post_init_state;

    reg ascon_counter_done;
    reg [3:0] decr_ascon_counter;

    assign ascon_counter_done = (ascon_counter == 'd0);
    assign decr_ascon_counter = (ascon_counter - 'd1);

    always@(*) begin
        load_init_val = 1'b0;
        rounds_enable = 1'b0;

        case (ascon_state)
            `IDLE_STATE      : begin
                if (operation_ready) begin
                    next_ascon_state = `INIT_STATE;

                    next_ascon_counter = 4'd11;

                    load_init_val = 1'b1;
                end else begin
                    next_ascon_state = ascon_state;

                    next_ascon_counter = 4'd0;
                end
            end
            `INIT_STATE      : begin
                if (ascon_counter_done) begin
                    next_ascon_state = post_init_state;

                    next_ascon_counter = 4'd11;
                end else begin
                    next_ascon_state = ascon_state;

                    next_ascon_counter = decr_ascon_counter;

                    rounds_enable = 1'b1;
                end
            end
            `DATA_PROC_STATE : begin
                if (ascon_counter_done) begin
                    next_ascon_state = `TEXT_PROC_STATE;

                    next_ascon_counter = 4'd11;
                end else begin
                    next_ascon_state = ascon_state;

                    next_ascon_counter = decr_ascon_counter;
                end
            end
            `TEXT_PROC_STATE : begin
                if (ascon_counter_done) begin
                    next_ascon_state = `FINAL_STATE;

                    next_ascon_counter = 4'd11;
                end else begin
                    next_ascon_state = ascon_state;

                    next_ascon_counter = decr_ascon_counter;
                end
            end
            `FINAL_STATE   : begin
                // TODO
                if (ascon_counter_done) begin
                    next_ascon_state = `IDLE_STATE;

                    next_ascon_counter = 4'd11;
                end else begin
                    next_ascon_state = ascon_state;

                    next_ascon_counter = decr_ascon_counter;
                end
            end
            `CUSTOM_STATE  : begin
                // TODO
                if (ascon_counter_done) begin
                    next_ascon_state = `ABSORB_STATE;

                    next_ascon_counter = 4'd11;
                end else begin
                    next_ascon_state = ascon_state;

                    next_ascon_counter = decr_ascon_counter;
                end
            end
            `ABSORB_STATE  : begin
                // TODO
                if (ascon_counter_done) begin
                    next_ascon_state = `SQUEEZE_STATE;

                    next_ascon_counter = 4'd11;
                end else begin
                    next_ascon_state = ascon_state;

                    next_ascon_counter = decr_ascon_counter;
                end
            end
            `SQUEEZE_STATE : begin
                // TODO
                if (ascon_counter_done) begin
                    next_ascon_state = `FINAL_STATE;

                    next_ascon_counter = 4'd11;
                end else begin
                    next_ascon_state = ascon_state;

                    next_ascon_counter = decr_ascon_counter;
                end
            end
            default        : begin
                next_ascon_state = ascon_state;

                next_ascon_counter = 4'd0;
            end
        endcase
    end

    // Initialization values for state registers
    reg [63:0] S_0_init;
    reg [63:0] S_1_init;
    reg [63:0] S_2_init;
    reg [63:0] S_3_init;
    reg [63:0] S_4_init;

    always@(*) begin
        // Reuse the same decoder logic for operation mode to
        //   determine the state after initialization
        case (operation_mode)
            `IDLE_MODE    : begin 
                S_0_init = 64'd0;
                S_1_init = 64'd0;
                S_2_init = 64'd0;
                S_3_init = 64'd0;
                S_4_init = 64'd0;

                post_init_state = `DATA_PROC_STATE;
            end
            `ENCRYPT_MODE,
            `DECRYPT_MODE : begin
                S_0_init = 64'h00001000808c0001;
                S_1_init = reg0_128b[127:64];
                S_2_init = reg0_128b[63:0];
                S_3_init = reg1_128b[127:64];
                S_4_init = reg1_128b[63:0];

                post_init_state = `DATA_PROC_STATE;
            end
            `HASH_MODE    : begin
                S_0_init = 64'h0000080100cc0002;
                S_1_init = 64'd0;
                S_2_init = 64'd0;
                S_3_init = 64'd0;
                S_4_init = 64'd0;

                post_init_state = `ABSORB_STATE;
            end
            `XOF_MODE     : begin
                S_0_init = 64'h0000080000cc0003;
                S_1_init = 64'd0;
                S_2_init = 64'd0;
                S_3_init = 64'd0;
                S_4_init = 64'd0;

                post_init_state = `ABSORB_STATE;
            end
            `CXOF_MODE    : begin
                S_0_init = 64'h0000080000cc0004;
                S_1_init = 64'd0;
                S_2_init = 64'd0;
                S_3_init = 64'd0;
                S_4_init = 64'd0;

                post_init_state = `CUSTOM_STATE;
            end
            default       : begin
                S_0_init = 64'd0;
                S_1_init = 64'd0;
                S_2_init = 64'd0;
                S_3_init = 64'd0;
                S_4_init = 64'd0;

                post_init_state = `DATA_PROC_STATE;
            end
        endcase
    end

    // Instantiate permutations
    // TODO: Make num_rounds an input instead of a parameter
    asconp #(
        .NUM_ROUNDS(12)
    ) u_asconp(
        .clk      (clk),
        .rst_n    (rst_n),

        .S_0_init (S_0_init),
        .S_1_init (S_1_init),
        .S_2_init (S_2_init),
        .S_3_init (S_3_init),
        .S_4_init (S_4_init),

        .load_init_val(load_init_val),
        .rounds_enable(rounds_enable),

        .S_0_reg  (S_0_reg),
        .S_1_reg  (S_1_reg),
        .S_2_reg  (S_2_reg),
        .S_3_reg  (S_3_reg),
        .S_4_reg  (S_4_reg)
    );

endmodule
