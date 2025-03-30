
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

    input wire state_shift_en,
    input wire [2:0] state_shift_sel,
    input wire state_shift_lsb,

    output reg [63:0] S_0_reg,
    output reg [63:0] S_1_reg,
    output reg [63:0] S_2_reg,
    output reg [63:0] S_3_reg,
    output reg [63:0] S_4_reg
);

    // 128-bit XOR
    reg [127:0] xor_128b_in0;
    reg [127:0] xor_128b_in1;
    reg [127:0] xor_128b_out;

    assign xor_128b_out = (xor_128b_in0 ^ xor_128b_in1);

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

    // Initial values for state registers
    reg [63:0] S_0_init;
    reg [63:0] S_1_init;
    reg [63:0] S_2_init;
    reg [63:0] S_3_init;
    reg [63:0] S_4_init;

    // Load values for state registers
    reg [63:0] S_0_load_val;
    reg [63:0] S_1_load_val;
    reg [63:0] S_2_load_val;
    reg [63:0] S_3_load_val;
    reg [63:0] S_4_load_val;

    // State transition logic
    reg load_val;

    reg [3:0] num_rounds;
    reg rounds_enable;
    reg [3:0] round_ctr;

    reg [2:0] post_init_state;

    reg ascon_counter_done;
    reg [3:0] decr_ascon_counter;

    assign ascon_counter_done = (ascon_counter == 'd0);

    assign decr_ascon_counter = ascon_counter_done ? 'd0 : (ascon_counter - 'd1);

    // TODO: optimize round_ctr
    // TODO: generate rounds_enable based on round_ctr,
    always@(*) begin
        // Default values, more readable to put here
        //   than on repeated else statements on each case
        
        // State register load values
        S_0_load_val = 64'd0;
        S_1_load_val = 64'd0;
        S_2_load_val = 64'd0;
        S_3_load_val = 64'd0;
        S_4_load_val = 64'd0;

        // XOR inputs
        xor_128b_in0 = 128'd0;
        xor_128b_in1 = 128'd0;

        // Control signals
        load_val      = 1'b0;

        num_rounds    = 4'd12;
        rounds_enable = 1'b0;

        round_ctr = 4'd0;

        next_ascon_state = ascon_state;

        next_ascon_counter = decr_ascon_counter;

        case (ascon_state)
            `IDLE_STATE      : begin
                if (operation_ready) begin
                    next_ascon_state = `INIT_STATE;

                    next_ascon_counter = 4'd12;

                    load_val = 1'b1;

                    S_0_load_val = S_0_init;
                    S_1_load_val = S_1_init;
                    S_2_load_val = S_2_init;
                    S_3_load_val = S_3_init;
                    S_4_load_val = S_4_init;
                end
            end
            `INIT_STATE      : begin
                if (ascon_counter_done) begin
                    next_ascon_state = post_init_state;

                    next_ascon_counter = 4'd9;

                    load_val = 1'b1;

                    // Update XOR inputs
                    xor_128b_in0 = {S_3_reg, S_4_reg};
                    xor_128b_in1 = reg0_128b;

                    // Load output values of initialization phase
                    S_0_load_val = S_0_reg;
                    S_1_load_val = S_1_reg;
                    S_2_load_val = S_2_reg;
                    S_3_load_val = xor_128b_out[127:64];
                    S_4_load_val = xor_128b_out[63:0];
                end else begin
                    rounds_enable = 1'b1;

                    round_ctr = (4'd12 - ascon_counter);
                end
            end
            `DATA_PROC_STATE : begin
                num_rounds = 4'd8;

                if (ascon_counter_done) begin
                    next_ascon_state = `TEXT_PROC_STATE;

                    next_ascon_counter = 4'd0;

                    load_val = 1'b1;

                    // Update XOR inputs
                    xor_128b_in0 = {S_3_reg, S_4_reg};
                    xor_128b_in1 = {64'd0, 1'd1, 63'd0};

                    // Load output values of associated data phase
                    S_0_load_val = S_0_reg;
                    S_1_load_val = S_1_reg;
                    S_2_load_val = S_2_reg;
                    S_3_load_val = S_3_reg;
                    S_4_load_val = xor_128b_out[63:0];
                end else if (ascon_counter == 'd9) begin
                    load_val = 1'b1;

                    // Update XOR inputs
                    xor_128b_in0 = {S_0_reg, S_1_reg};
                    xor_128b_in1 = reg2_128b;

                    // Load input values of associated data processing phase
                    S_0_load_val = xor_128b_out[127:64];
                    S_1_load_val = xor_128b_out[63:0];
                    S_2_load_val = S_2_reg;
                    S_3_load_val = S_3_reg;
                    S_4_load_val = S_4_reg;
                end else begin
                    rounds_enable = 1'b1;

                    round_ctr = (4'd8 - ascon_counter);
                end
            end
            `TEXT_PROC_STATE : begin
                if (ascon_counter_done) begin
                    next_ascon_state = `FINAL_STATE;

                    next_ascon_counter = 4'd13;

                    load_val = 1'b1;

                    // Update XOR inputs
                    xor_128b_in0 = {S_0_reg, S_1_reg};
                    xor_128b_in1 = reg1_128b;

                    // Load input values of plaintext processing phase
                    S_0_load_val = xor_128b_out[127:64];
                    S_1_load_val = xor_128b_out[63:0];
                    S_2_load_val = S_2_reg;
                    S_3_load_val = S_3_reg;
                    S_4_load_val = S_4_reg;
                end
            end
            `FINAL_STATE   : begin
                // TODO
                if (ascon_counter_done) begin
                    next_ascon_state = `IDLE_STATE;

                    next_ascon_counter = 4'd11;

                    // Update XOR inputs
                    xor_128b_in0 = {S_3_reg, S_4_reg};
                    xor_128b_in1 = reg0_128b;

                    // TODO
                    // Output tag won't be loaded to the state registers,
                    //   but to an output register
                end else if (ascon_counter == 4'd13) begin
                    load_val = 1'b1;

                    // Update XOR inputs
                    xor_128b_in0 = {S_2_reg, S_3_reg};
                    xor_128b_in1 = reg0_128b;

                    // Load input values of finalization phase
                    S_0_load_val = S_0_reg;
                    S_1_load_val = S_1_reg;
                    S_2_load_val = xor_128b_out[127:64];
                    S_3_load_val = xor_128b_out[63:0];
                    S_4_load_val = S_4_reg;
                end else begin
                    rounds_enable = 1'b1;

                    round_ctr = (4'd12 - ascon_counter);
                end
            end
            `CUSTOM_STATE  : begin
                // TODO
                if (ascon_counter_done) begin
                    next_ascon_state = `ABSORB_STATE;

                    next_ascon_counter = 4'd11;
                end
            end
            `ABSORB_STATE  : begin
                // TODO
                if (ascon_counter_done) begin
                    next_ascon_state = `SQUEEZE_STATE;

                    next_ascon_counter = 4'd11;
                end
            end
            `SQUEEZE_STATE : begin
                // TODO
                if (ascon_counter_done) begin
                    next_ascon_state = `FINAL_STATE;

                    next_ascon_counter = 4'd11;
                end
            end
            default        : begin
                next_ascon_state = ascon_state;

                next_ascon_counter = 4'd0;
            end
        endcase
    end

    // Initialization of state registers
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
                // S_3 and S_4 aren't changed since it is assumed that
                //   the nonce has already been written directly to
                //   S_3_reg and S_4_reg via SPI
                S_3_init = S_3_reg;
                S_4_init = S_4_reg;

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
    asconp u_asconp(
        .clk      (clk),
        .rst_n    (rst_n),

        .state_shift_en  (state_shift_en),
        .state_shift_sel (state_shift_sel),
        .state_shift_lsb (state_shift_lsb),

        .S_0_load_val (S_0_load_val),
        .S_1_load_val (S_1_load_val),
        .S_2_load_val (S_2_load_val),
        .S_3_load_val (S_3_load_val),
        .S_4_load_val (S_4_load_val),

        .load_val (load_val),

        .num_rounds   (num_rounds),
        .rounds_enable(rounds_enable),
        .round_ctr    (round_ctr),

        .S_0_reg  (S_0_reg),
        .S_1_reg  (S_1_reg),
        .S_2_reg  (S_2_reg),
        .S_3_reg  (S_3_reg),
        .S_4_reg  (S_4_reg)
    );

endmodule
