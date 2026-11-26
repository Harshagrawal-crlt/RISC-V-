`timescale 1ns / 1ps

module scoreboard (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [4:0]  id_rs1,
    input  wire [4:0]  id_rs2,
    input  wire        uses_rs1,
    input  wire        uses_rs2,
    input  wire [4:0]  id_rd,
    input  wire        id_reg_write,
    input  wire        id_mul_div_valid,
    input  wire        ex_clear_valid,
    input  wire [4:0]  ex_clear_rd,
    output wire        hazard_stall
);

    reg [31:0] reg_busy;

    
    assign hazard_stall = (uses_rs1 && (id_rs1 != 5'd0) && reg_busy[id_rs1]) || 
                          (uses_rs2 && (id_rs2 != 5'd0) && reg_busy[id_rs2]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_busy <= 32'd0;
        end else begin
            
            if (id_mul_div_valid && (id_rd != 5'd0) && !hazard_stall && !ex_clear_valid) begin
                reg_busy[id_rd] <= 1'b1;
            end
            
            if (ex_clear_valid && (ex_clear_rd != 5'd0)) begin
                reg_busy[ex_clear_rd] <= 1'b0;
            end
        end
    end

endmodule
