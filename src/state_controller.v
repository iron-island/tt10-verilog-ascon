module state_controller(
    input wire clk,
    input wire rst_n,

    input wire [63:0] S_0_reg,
    input wire [63:0] S_1_reg,
    input wire [63:0] S_2_reg,
    input wire [63:0] S_3_reg,
    input wire [63:0] S_4_reg,

    input wire rounds_done,

    output reg        output_enable,
    output reg [15:0] double_byte_output
);

    // TODO: increase states for initializing key, nonce, etc.
    reg [4:0] curr_state;
    reg [4:0] next_state;

    always@(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_state    <= `OUT_DOUBLE_BYTES_15;
            output_enable <= 1'b0;
        end else if (rounds_done) begin
            curr_state    <= next_state;
            output_enable <= 1'b1;
        end
    end

    // FSM and output muxes
    always@(*) begin
        case (curr_state)
            `OUT_DOUBLE_BYTES_15 : begin next_state = `OUT_DOUBLE_BYTES_14; double_byte_output = S_1_reg[63:48]; end
            `OUT_DOUBLE_BYTES_14 : begin next_state = `OUT_DOUBLE_BYTES_13; double_byte_output = S_1_reg[47:32]; end
            `OUT_DOUBLE_BYTES_13 : begin next_state = `OUT_DOUBLE_BYTES_12; double_byte_output = S_1_reg[31:16]; end
            `OUT_DOUBLE_BYTES_12 : begin next_state = `OUT_DOUBLE_BYTES_11; double_byte_output = S_1_reg[15: 0]; end
            `OUT_DOUBLE_BYTES_11 : begin next_state = `OUT_DOUBLE_BYTES_10; double_byte_output = S_2_reg[63:48]; end
            `OUT_DOUBLE_BYTES_10 : begin next_state = `OUT_DOUBLE_BYTES_09; double_byte_output = S_2_reg[47:32]; end
            `OUT_DOUBLE_BYTES_09 : begin next_state = `OUT_DOUBLE_BYTES_08; double_byte_output = S_2_reg[31:16]; end
            `OUT_DOUBLE_BYTES_08 : begin next_state = `OUT_DOUBLE_BYTES_07; double_byte_output = S_2_reg[15: 0]; end
            `OUT_DOUBLE_BYTES_07 : begin next_state = `OUT_DOUBLE_BYTES_06; double_byte_output = S_3_reg[63:48]; end
            `OUT_DOUBLE_BYTES_06 : begin next_state = `OUT_DOUBLE_BYTES_05; double_byte_output = S_3_reg[47:32]; end
            `OUT_DOUBLE_BYTES_05 : begin next_state = `OUT_DOUBLE_BYTES_04; double_byte_output = S_3_reg[31:16]; end
            `OUT_DOUBLE_BYTES_04 : begin next_state = `OUT_DOUBLE_BYTES_03; double_byte_output = S_3_reg[15: 0]; end
            `OUT_DOUBLE_BYTES_03 : begin next_state = `OUT_DOUBLE_BYTES_02; double_byte_output = S_4_reg[63:48]; end
            `OUT_DOUBLE_BYTES_02 : begin next_state = `OUT_DOUBLE_BYTES_01; double_byte_output = S_4_reg[47:32]; end
            `OUT_DOUBLE_BYTES_01 : begin next_state = `OUT_DOUBLE_BYTES_00; double_byte_output = S_4_reg[31:16]; end
            `OUT_DOUBLE_BYTES_00 : begin next_state = `OUT_DOUBLE_BYTES_00; double_byte_output = S_4_reg[15: 0]; end
        endcase
    end

endmodule
