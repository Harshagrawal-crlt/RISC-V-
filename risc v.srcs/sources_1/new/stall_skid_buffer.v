`timescale 1ns / 1ps

module stall_skid_buffer (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        stall,         
    input  wire        flush,         
    input  wire [31:0] fetch_pc,
    input  wire [31:0] fetch_instr,   
    output wire [31:0] id_pc,
    output wire [31:0] id_instr       
);

    reg [31:0] backup_pc;
    reg [31:0] backup_instr;
    reg        buffer_full;

    assign id_pc    = buffer_full ? backup_pc    : fetch_pc;
    assign id_instr = buffer_full ? backup_instr : fetch_instr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            backup_pc    <= 32'd0;
            backup_instr <= 32'd0;
            buffer_full  <= 1'b0;
        end else if (flush) begin
            backup_pc    <= 32'd0;
            backup_instr <= 32'd0;
            buffer_full  <= 1'b0;
        end else begin
            if (stall && !buffer_full) begin
                backup_pc    <= fetch_pc;
                backup_instr <= fetch_instr;
                buffer_full  <= 1'b1;
            end else if (!stall) begin
                buffer_full  <= 1'b0;
            end
        end
    end

endmodule
