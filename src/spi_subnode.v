
// Commands
// MSB = 0 for write, 1 for read
`define WR_REG0_COMMAND    5'b00000
`define WR_REG1_COMMAND    5'b00001
`define WR_REG2_COMMAND    5'b00010
`define WR_OP_MODE_COMMAND 5'b00011
// TODO: Add writing to state registers?
//`define WR_S_0_COMMAND     5'b00100
//`define WR_S_1_COMMAND     5'b00101
//`define WR_S_2_COMMAND     5'b00110
//`define WR_S_3_COMMAND     5'b00111
//`define WR_S_4_COMMAND     5'b01000
`define RD_REG0_COMMAND    5'b10000
`define RD_REG1_COMMAND    5'b10001
`define RD_REG2_COMMAND    5'b10010
`define RD_OP_MODE_COMMAND 5'b10011
`define RD_S_0_COMMAND     5'b10100
`define RD_S_1_COMMAND     5'b10101
`define RD_S_2_COMMAND     5'b10110
`define RD_S_3_COMMAND     5'b10111
`define RD_S_4_COMMAND     5'b11000

// SPI states
`define INPUT_COMMAND_STATE 3'b000
`define INPUT_DATA_STATE    3'b001
`define INPUT_MODE_STATE    3'b010
`define OUTPUT_DATA_STATE   3'b011
`define OUTPUT_MODE_STATE   3'b100
`define IDLE_SPI_STATE      3'b101

module spi_subnode(
    input wire clk,
    input wire rst_n,

    input wire sck,
    input wire csb,
    input wire mosi,

    output reg miso,

    output reg [127:0] reg0_128b,
    output reg [127:0] reg1_128b,
    output reg [127:0] reg2_128b,

    output reg [2:0] operation_mode,
    output reg       operation_ready,

    input wire [63:0] S_0_reg,
    input wire [63:0] S_1_reg,
    input wire [63:0] S_2_reg,
    input wire [63:0] S_3_reg,
    input wire [63:0] S_4_reg
);

    // Reset signal using both rst_n and csb
    reg spi_rst_n;
   
    assign spi_rst_n = (rst_n & !csb);

    // SCK and CSB edge detectors
    reg sck_delay;
    reg csb_delay;

    reg sck_rise;
    reg sck_fall;
    reg csb_rise;
    reg csb_fall;

    assign sck_rise = (sck & !sck_delay);
    assign csb_rise = (csb & !csb_delay);

    assign sck_fall = (!sck & sck_delay);
    assign csb_fall = (!csb & csb_delay);

    always@(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sck_delay <= 1'b0;
            csb_delay <= 1'b0;
        end else begin
            sck_delay <= sck;
            csb_delay <= csb;
        end
    end

    // SPI subnode control signals
    reg [2:0] curr_state;
    reg [2:0] next_state;
    reg [4:0] command;
    reg [4:0] next_command;
    reg [6:0] counter;
    reg [6:0] next_counter;

    reg counter_done;

    reg next_miso;

    assign next_command = {command[3:0], mosi};

    always@(posedge clk or negedge spi_rst_n) begin
        if (!spi_rst_n) begin
            curr_state <= 3'd0;
            command    <= 5'd0;
            counter    <= 7'd4; // reset counter value to (no. of bits of command)-1
            
            miso <= 1'b1;
        end else if ((csb == 1'b0) && (sck_rise)) begin
            curr_state <= next_state;
            command    <= (curr_state == `INPUT_COMMAND_STATE) ? next_command : command;
            counter    <= next_counter;

            miso <= next_miso;
        end
    end

    // Input/output registers
    always@(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg0_128b <= 128'd0;
            reg1_128b <= 128'd0;
            reg2_128b <= 128'd0;

            operation_mode  <= 3'b000;
            operation_ready <= 1'b0;
        end else if (sck_rise) begin
            if (curr_state == `INPUT_DATA_STATE) begin
                reg0_128b <= (command == `WR_REG0_COMMAND) ? {reg0_128b[126:0], mosi} : reg0_128b;
                reg1_128b <= (command == `WR_REG1_COMMAND) ? {reg1_128b[126:0], mosi} : reg1_128b;
                reg2_128b <= (command == `WR_REG2_COMMAND) ? {reg2_128b[126:0], mosi} : reg2_128b;
            end else if (curr_state == `INPUT_MODE_STATE) begin
                operation_mode <= {operation_mode[1:0], mosi};

                if (counter_done) begin
                    operation_ready <= 1'b1;
                end else begin
                    operation_ready <= 1'b0;
                end
            end
        end
    end

    // FSM
    reg [6:0] decr_counter;

    assign counter_done = (counter == 'd0);
    assign decr_counter = (counter - 'd1);

    always@(*) begin
        case (curr_state)
            `INPUT_COMMAND_STATE : begin
                // Constant output
                next_miso = 1'b1;

                if (counter_done) begin
                    case (next_command)
                        `WR_REG0_COMMAND    : begin next_counter = 'd127;   next_state = `INPUT_DATA_STATE;  end
                        `WR_REG1_COMMAND    : begin next_counter = 'd127;   next_state = `INPUT_DATA_STATE;  end
                        `WR_REG2_COMMAND    : begin next_counter = 'd127;   next_state = `INPUT_DATA_STATE;  end
                        `WR_OP_MODE_COMMAND : begin next_counter = 'd2;     next_state = `INPUT_MODE_STATE;  end
                        `RD_REG0_COMMAND    : begin next_counter = 'd127;   next_state = `OUTPUT_DATA_STATE; end
                        `RD_REG1_COMMAND    : begin next_counter = 'd127;   next_state = `OUTPUT_DATA_STATE; end 
                        `RD_REG2_COMMAND    : begin next_counter = 'd127;   next_state = `OUTPUT_DATA_STATE; end 
                        `RD_OP_MODE_COMMAND : begin next_counter = 'd2;     next_state = `OUTPUT_MODE_STATE; end
                        `RD_S_0_COMMAND     : begin next_counter = 'd63;    next_state = `OUTPUT_DATA_STATE; end
                        `RD_S_1_COMMAND     : begin next_counter = 'd63;    next_state = `OUTPUT_DATA_STATE; end
                        `RD_S_2_COMMAND     : begin next_counter = 'd63;    next_state = `OUTPUT_DATA_STATE; end
                        `RD_S_3_COMMAND     : begin next_counter = 'd63;    next_state = `OUTPUT_DATA_STATE; end
                        `RD_S_4_COMMAND     : begin next_counter = 'd63;    next_state = `OUTPUT_DATA_STATE; end
                        default             : begin next_counter = counter; next_state = curr_state;         end
                    endcase
                end else begin
                    next_state   = curr_state;
                    next_counter = decr_counter;
                end
            end
            `INPUT_DATA_STATE : begin
                // Constant output
                next_miso = 1'b1;

                if (counter_done) begin
                    next_state   = `IDLE_SPI_STATE;
                    next_counter = counter;
                end else begin
                    next_state   = curr_state;
                    next_counter = decr_counter;
                end
            end
            `INPUT_MODE_STATE : begin
                // Constant output
                next_miso = 1'b1;

                if (counter_done) begin
                    next_state   = `IDLE_SPI_STATE;
                    next_counter = counter;
                end else begin
                    next_state   = curr_state;
                    next_counter = decr_counter;
                end
            end
            `OUTPUT_DATA_STATE : begin
                if (counter_done) begin
                    next_state   = `IDLE_SPI_STATE;
                    next_counter = counter;
                end else begin
                    next_state   = curr_state;
                    next_counter = decr_counter;
                end

                // Output MISO
                case (command)
                    `RD_REG0_COMMAND : next_miso = reg0_128b[counter];
                    `RD_REG1_COMMAND : next_miso = reg1_128b[counter];
                    `RD_REG2_COMMAND : next_miso = reg2_128b[counter];
                    `RD_S_0_COMMAND  : next_miso = S_0_reg[counter];
                    `RD_S_1_COMMAND  : next_miso = S_1_reg[counter];
                    `RD_S_2_COMMAND  : next_miso = S_2_reg[counter];
                    `RD_S_3_COMMAND  : next_miso = S_3_reg[counter];
                    `RD_S_4_COMMAND  : next_miso = S_4_reg[counter];
                    default          : next_miso = 1'b1;
                    // default case should be impossible during
                    //   this state, but added
                    //   here for lint clean-up
                endcase
            end
            `OUTPUT_MODE_STATE : begin
                if (counter_done) begin
                    next_state   = `IDLE_SPI_STATE;
                    next_counter = counter;
                end else begin
                    next_state   = curr_state;
                    next_counter = decr_counter;
                end

                // Output MISO
                next_miso = operation_mode[counter];
            end
            `IDLE_SPI_STATE : begin
                next_state   = curr_state;
                next_counter = counter;

                next_miso = miso;
            end
            default : begin
                // default case is the same as idle state,
                //   this case is not possible, but added for lint clean-up
                next_state   = curr_state;
                next_counter = counter;

                next_miso = miso;
            end
        endcase
    end

endmodule
