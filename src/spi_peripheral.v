
// Commands
// MSB = 0 for write, 1 for read
`define WR_REG0_COMMAND    3'b000
`define WR_REG1_COMMAND    3'b001
`define WR_REG2_COMMAND    3'b010
`define WR_OP_MODE_COMMAND 3'b011
`define RD_REG0_COMMAND    3'b100
`define RD_REG1_COMMAND    3'b101
`define RD_REG2_COMMAND    3'b110
`define RD_OP_MODE_COMMAND 3'b111

// SPI states
`define INPUT_COMMAND_STATE 3'b000
`define INPUT_DATA_STATE    3'b001
`define INPUT_MODE_STATE    3'b010
`define OUTPUT_DATA_STATE   3'b011
`define OUTPUT_MODE_STATE   3'b100
`define IDLE_STATE          3'b101

// Operation modes
`define IDLE_MODE    3'b000
`define ENCRYPT_MODE 3'b001
`define DECRYPT_MODE 3'b010
`define HASH_MODE    3'b011
`define XOF_MODE     3'b100
`define CXOF_MODE    3'b101

module spi_subnode(
    input wire rst_n,

    input wire sck,
    input wire csb,
    input wire mosi,

    output reg miso,
    output reg [2:0] operation_mode
);

    reg cs;

    assign cs = !csb;

    reg [2:0] curr_state;
    reg [2:0] next_state;
    reg [2:0] command;
    reg [2:0] next_command;
    reg [6:0] counter;
    reg [6:0] next_counter;

    always@(posedge sck or negedge cs) begin
        if (csb) begin
            curr_state <= 3'd0;
            command    <= 3'd0;
            counter    <= 7'd2; // reset counter value to (no. of bits of command)-1
        end else begin
            curr_state <= next_state;
            command    <= next_command;
            counter    <= next_counter;
        end
    end

    // Input/output registers
    reg [127:0] reg0_128b;
    reg [127:0] reg1_128b;
    reg [127:0] reg2_128b;

    reg next_miso;

    reg [2:0] operation_mode;

    always@(posedge sck or negedge rst_n) begin
        if (!rst_n) begin
            reg0_128b <= 128'd0;
            reg1_128b <= 128'd0;
            reg2_128b <= 128'd0;

            miso <= 1'b1;

            operation_mode <= 3'b000;
        end else if (curr_state == `INPUT_DATA_STATE) begin
            reg0_128b <= (command == `WR_REG0_COMMAND) ? {reg0_128b[126:0], mosi} : reg0_128b;
            reg1_128b <= (command == `WR_REG1_COMMAND) ? {reg1_128b[126:0], mosi} : reg1_128b;
            reg2_128b <= (command == `WR_REG2_COMMAND) ? {reg2_128b[126:0], mosi} : reg2_128b;
        end else if (curr_state == `INPUT_MODE_STATE) begin
            operation_mode <= {operation_mode[1:0], mosi};
        end else begin
            miso <= next_miso;
        end
    end

    // FSM
    reg counter_done;
    reg [1:0] shift_left_command;
    reg [6:0] decr_counter;

    assign counter_done = (counter == 'd0);

    assign shift_left_command = {command[0], mosi};

    assign decr_counter = (counter - 'd1);

    always@(*) begin
        case (curr_state)
            `INPUT_COMMAND_STATE : begin
                // Constant output
                next_miso = 1'b1;

                if (counter_done) begin
                    next_command = command;

                    case (command)
                        `WR_REG0_COMMAND    : begin next_counter = 'd127;   next_state = `INPUT_DATA_STATE;  end
                        `WR_REG1_COMMAND    : begin next_counter = 'd127;   next_state = `INPUT_DATA_STATE;  end
                        `WR_REG2_COMMAND    : begin next_counter = 'd127;   next_state = `INPUT_DATA_STATE;  end
                        `WR_OP_MODE_COMMAND : begin next_counter = 'd2;     next_state = `INPUT_MODE_STATE;  end
                        `RD_REG0_COMMAND    : begin next_counter = 'd127;   next_state = `OUTPUT_DATA_STATE; end
                        `RD_REG1_COMMAND    : begin next_counter = 'd127;   next_state = `OUTPUT_DATA_STATE; end 
                        `RD_REG2_COMMAND    : begin next_counter = 'd127;   next_state = `OUTPUT_DATA_STATE; end 
                        `RD_OP_MODE_COMMAND : begin next_counter = 'd2;     next_state = `OUTPUT_MODE_STATE; end
                        default             : begin next_counter = counter; next_state = curr_state;         end
                    endcase
                end else begin
                    next_state   = curr_state;
                    next_command = shift_left_command;
                    next_counter = decr_counter;
                end
            end
            `INPUT_DATA_STATE : begin
                // Command no longer being updated
                next_command = command;

                // Constant output
                next_miso = 1'b1;

                if (counter_done) begin
                    next_state   = `IDLE_STATE;
                    next_counter = counter;
                end else begin
                    next_state   = curr_state;
                    next_counter = decr_counter;
                end
            end
            `INPUT_MODE_STATE : begin
                // Command no longer being updated
                next_command = command;

                // Constant output
                next_miso = 1'b1;

                if (counter_done) begin
                    next_state   = `IDLE_STATE;
                    next_counter = counter;
                end else begin
                    next_state   = curr_state;
                    next_counter = decr_counter;
                end
            end
            `OUTPUT_DATA_STATE : begin
                // Command no longer being updated
                next_command = command;

                if (counter_done) begin
                    next_state   = `IDLE_STATE;
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
                    default          : next_miso = 1'b1;
                    // default case should be impossible during
                    //   this state, but added
                    //   here for lint clean-up
                endcase
            end
            `OUTPUT_MODE_STATE : begin
                // Command no longer being updated
                next_command = command;

                if (counter_done) begin
                    next_state   = `IDLE_STATE;
                    next_counter = counter;
                end else begin
                    next_state   = curr_state;
                    next_counter = decr_counter;
                end

                // Output MISO
                next_miso = operation_mode[counter];
            end
            `IDLE_STATE : begin
                next_state   = curr_state;
                next_command = command;
                next_counter = counter;

                next_miso = miso;
            end
            default : begin
                // default case is the same as idle state,
                //   this case is not possible, but added for lint clean-up
                next_state   = curr_state;
                next_command = command;
                next_counter = counter;

                next_miso = miso;
            end
        endcase
    end

endmodule
