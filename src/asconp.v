module asconp(
    input wire clk,
    input wire rst_n,

    output reg [47:0] S_0_reg,
    output reg [47:0] S_1_reg,
    output reg [47:0] S_2_reg,
    output reg [47:0] S_3_reg,
    output reg [47:0] S_4_reg,

    output reg rounds_done
);

    parameter NUM_ROUNDS = 12;

    // State registers

    reg [47:0] S_0_L;
    reg [47:0] S_1_L;
    reg [47:0] S_2_L;
    reg [47:0] S_3_L;
    reg [47:0] S_4_L;

    reg       state_initialized;
    reg [3:0] round_ctr;

    assign rounds_done = (round_ctr == NUM_ROUNDS);

    always@(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_initialized <= 1'b0;
            round_ctr   <= 4'd0;
        end else if (!state_initialized) begin
            state_initialized <= 1'b1;
        end else if (round_ctr < NUM_ROUNDS) begin
            round_ctr   <= round_ctr + 1'b1;
        end
    end

    always@(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            S_0_reg <= 48'd0;
            S_1_reg <= 48'd0;
            S_2_reg <= 48'd0;
            S_3_reg <= 48'd0;
            S_4_reg <= 48'd0;
        end else if (!state_initialized) begin
            // TODO: Replace with actual initialization via state machine
            //       For now, using random initial states from one run of
            //         Python reference implementation
            //x0=00001000808c0001
            //x1=f23494a4b1f09f72
            //x2=1120821ab7ef5039
            //x3=0288f6cd3f44a4c2
            //x4=122103181031374d
            // TODO: Return back to 64 bits
            S_0_reg <= 48'h1000808c0001;
            S_1_reg <= 48'h94a4b1f09f72;
            S_2_reg <= 48'h821ab7ef5039;
            S_3_reg <= 48'hf6cd3f44a4c2;
            S_4_reg <= 48'h03181031374d;
        end else if (round_ctr < NUM_ROUNDS) begin
            S_0_reg <= S_0_L;
            S_1_reg <= S_1_L;
            S_2_reg <= S_2_L;
            S_3_reg <= S_3_L;
            S_4_reg <= S_4_L;
        end
    end

    reg [47:0] S_0_C;
    reg [47:0] S_1_C;
    reg [47:0] S_2_C;
    reg [47:0] S_3_C;
    reg [47:0] S_4_C;

    reg [7:0] const_i;

    reg [47:0] S_0_S;
    reg [47:0] S_1_S;
    reg [47:0] S_2_S;
    reg [47:0] S_3_S;
    reg [47:0] S_4_S;

    reg [4:0] Sbox_out;

    // Constant-addition layer
    
    // Index used for LUT constants
    wire [3:0] index;
    assign index = 16-NUM_ROUNDS+round_ctr;

    always@(*) begin
        S_0_C = S_0_reg;
        S_1_C = S_1_reg;
        S_2_C[47:8] = S_2_reg[47:8];
        S_3_C = S_3_reg;
        S_4_C = S_4_reg;

        // LUT for constants
        // TODO: Try out optimization used in Python reference implementation
        case (index)
            4'd0   : const_i = 8'h3c;
            4'd1   : const_i = 8'h2d;
            4'd2   : const_i = 8'h1e;
            4'd3   : const_i = 8'h0f;
            4'd4   : const_i = 8'hf0;
            4'd5   : const_i = 8'he1;
            4'd6   : const_i = 8'hd2;
            4'd7   : const_i = 8'hc3;
            4'd8   : const_i = 8'hb4;
            4'd9   : const_i = 8'ha5;
            4'd10  : const_i = 8'h96;
            4'd11  : const_i = 8'h87;
            4'd12  : const_i = 8'h78;
            4'd13  : const_i = 8'h69;
            4'd14  : const_i = 8'h5a;
            4'd15  : const_i = 8'h4b;
            default: const_i = 8'h3c; // default case arbitrarily chosen to be index = 0
        endcase

        S_2_C[7:0] = S_2_reg[7:0] ^ const_i;
    end

    // Substitution layer
    always@(*) begin
        for (int i = 0; i < 48; i = i + 1) begin
            // SBox LUT
            case ({S_0_C[i], S_1_C[i], S_2_C[i], S_3_C[i], S_4_C[i]})
                5'h00 : Sbox_out = 5'h04;
                5'h01 : Sbox_out = 5'h0b;
                5'h02 : Sbox_out = 5'h1f;
                5'h03 : Sbox_out = 5'h14;
                5'h04 : Sbox_out = 5'h1a;
                5'h05 : Sbox_out = 5'h15;
                5'h06 : Sbox_out = 5'h09;
                5'h07 : Sbox_out = 5'h02;
                5'h08 : Sbox_out = 5'h1b;
                5'h09 : Sbox_out = 5'h05;
                5'h0a : Sbox_out = 5'h08;
                5'h0b : Sbox_out = 5'h12;
                5'h0c : Sbox_out = 5'h1d;
                5'h0d : Sbox_out = 5'h03;
                5'h0e : Sbox_out = 5'h06;
                5'h0f : Sbox_out = 5'h1c;
                5'h10 : Sbox_out = 5'h1e;
                5'h11 : Sbox_out = 5'h13;
                5'h12 : Sbox_out = 5'h07;
                5'h13 : Sbox_out = 5'h0e;
                5'h14 : Sbox_out = 5'h00;
                5'h15 : Sbox_out = 5'h0d;
                5'h16 : Sbox_out = 5'h11;
                5'h17 : Sbox_out = 5'h18;
                5'h18 : Sbox_out = 5'h10;
                5'h19 : Sbox_out = 5'h0c;
                5'h1a : Sbox_out = 5'h01;
                5'h1b : Sbox_out = 5'h19;
                5'h1c : Sbox_out = 5'h16;
                5'h1d : Sbox_out = 5'h0a;
                5'h1e : Sbox_out = 5'h0f;
                5'h1f : Sbox_out = 5'h17;
            endcase

            S_0_S[i] = Sbox_out[4];
            S_1_S[i] = Sbox_out[3];
            S_2_S[i] = Sbox_out[2];
            S_3_S[i] = Sbox_out[1];
            S_4_S[i] = Sbox_out[0];
        end
    end

    // Linear diffusion layer
    always@(*) begin
        // Linear functions
        S_0_L = S_0_S ^ ({S_0_S[18:0], S_0_S[47:19]}) ^ ({S_0_S[27:0], S_0_S[47:28]});
        // TODO: Return back when extended back to 64 bits
        //S_1_L = S_1_S ^ ({S_1_S[60:0], S_1_S[47:61]}) ^ ({S_1_S[38:0], S_1_S[47:39]});
        S_1_L = S_1_S ^ ({S_1_S[44:0], S_1_S[47:45]}) ^ ({S_1_S[38:0], S_1_S[47:39]});
        S_2_L = S_2_S ^ ({S_2_S[   0], S_2_S[47:01]}) ^ ({S_2_S[ 5:0], S_2_S[47:06]});
        S_3_L = S_3_S ^ ({S_3_S[ 9:0], S_3_S[47:10]}) ^ ({S_3_S[16:0], S_3_S[47:17]});
        S_4_L = S_4_S ^ ({S_4_S[ 6:0], S_4_S[47:07]}) ^ ({S_4_S[40:0], S_4_S[47:41]});
    end

endmodule
