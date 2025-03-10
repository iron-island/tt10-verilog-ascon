module sync_2ff(
    input wire data_in,
    input wire clk_sync,
    input wire rst_n,

    output reg data_sync_out
);

    parameter RESET_VAL = 1'b0;

    // 2FF synchronizer
    reg data_reg;

    always@(posedge clk_sync or negedge rst_n) begin
        if (!rst_n) begin
            data_reg      <= RESET_VAL;
            data_sync_out <= RESET_VAL;
        end else begin
            data_reg      <= data_in;
            data_sync_out <= data_reg;
        end
    end

endmodule
