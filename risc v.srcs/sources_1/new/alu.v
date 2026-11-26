`timescale 1ns / 1ps

module alu (
    input  wire [31:0] alu_in_a,
    input  wire [31:0] alu_in_b,
    input  wire [3:0]  alu_op,
    output reg  [31:0] alu_out,
    output wire        alu_zero
);

    always @(*) begin
        case (alu_op)
            4'b0000: alu_out = alu_in_a + alu_in_b;
            4'b0001: alu_out = alu_in_a - alu_in_b;
            4'b0010: alu_out = alu_in_a & alu_in_b;
            4'b0011: alu_out = alu_in_a | alu_in_b;
            4'b0100: alu_out = alu_in_a ^ alu_in_b;
            4'b0101: alu_out = alu_in_a << alu_in_b[4:0];
            4'b0110: alu_out = alu_in_a >> alu_in_b[4:0];
            4'b0111: alu_out = $signed(alu_in_a) >>> alu_in_b[4:0];
            4'b1000: alu_out = ($signed(alu_in_a) < $signed(alu_in_b)) ? 32'd1 : 32'd0;
            4'b1001: alu_out = (alu_in_a < alu_in_b) ? 32'd1 : 32'd0;
            default: alu_out = 32'd0;
        endcase
    end

    assign alu_zero = (alu_out == 32'd0);

endmodule
