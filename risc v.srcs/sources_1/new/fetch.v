`timescale 1ns / 1ps

module fetch (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        stall,         
    input  wire        branch_taken,  
    input  wire [31:0] branch_target, 
    output reg  [31:0] pc             
);

    wire [31:0] next_pc;


    assign next_pc = branch_taken ? branch_target : 
                     stall        ? pc            : (pc + 32'd4);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'd0;
        end else begin
            pc <= next_pc;
        end
    end

endmodule
