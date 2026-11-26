`timescale 1ns / 1ps

module csr_unit (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [11:0] csr_addr,
    input  wire [31:0] csr_wdata,
    input  wire        csr_we,
    output reg  [31:0] csr_rdata
);

    reg [63:0] cycle_count;
    reg [31:0] mepc;

    always @(*) begin
        case (csr_addr)
            12'hC00: csr_rdata = cycle_count[31:0];
            12'hC80: csr_rdata = cycle_count[63:32];
            12'h341: csr_rdata = mepc;
            default: csr_rdata = 32'd0;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 64'd0;
            mepc        <= 32'd0;
        end else begin
            cycle_count <= cycle_count + 1'b1;

            if (csr_we) begin
                case (csr_addr)
                    12'h341: mepc <= csr_wdata;
                    default: ;
                endcase
            end
        end
    end

endmodule
