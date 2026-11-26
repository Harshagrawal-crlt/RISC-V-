`timescale 1ns / 1ps

module axi_lite_master (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] cpu_addr,
    input  wire [31:0] cpu_wdata,
    input  wire        cpu_read_req,
    input  wire        cpu_write_req,
    output reg  [31:0] cpu_rdata,
    output wire        cpu_stall,

    output reg  [31:0] awaddr,   output reg  awvalid,   input wire  awready,
    output reg  [31:0] wdata,    output reg  wvalid,    input wire  wready,
    input  wire        bvalid,   output reg  bready,
    output reg  [31:0] araddr,   output reg  arvalid,   input wire  arready,
    input  wire [31:0] rdata,    input wire  rvalid,    output reg  rready
);

    localparam IDLE = 2'b00, WRITE = 2'b01, READ = 2'b10, RESP = 2'b11;
    reg [1:0] state;

    assign cpu_stall = (cpu_read_req || cpu_write_req) && (state != RESP && !(state == READ && rvalid));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; awvalid <= 1'b0; wvalid <= 1'b0; bready <= 1'b0;
            arvalid <= 1'b0; rready <= 1'b0; cpu_rdata <= 32'd0;
            awaddr <= 32'd0; wdata <= 32'd0; araddr <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (cpu_write_req) begin
                        state   <= WRITE;
                        awaddr  <= cpu_addr;
                        wdata   <= cpu_wdata;
                        awvalid <= 1'b1;
                        wvalid  <= 1'b1;
                    end else if (cpu_read_req) begin
                        state   <= READ;
                        araddr  <= cpu_addr;
                        arvalid <= 1'b1;
                        rready  <= 1'b1;
                    end
                end
                WRITE: begin
                    if (awready) awvalid <= 1'b0;
                    if (wready)  wvalid  <= 1'b0;
                    if (!awvalid && !wvalid) begin
                        state  <= RESP;
                        bready <= 1'b1;
                    end
                end
                RESP: begin
                    if (bvalid) begin
                        bready <= 1'b0;
                        state  <= IDLE;
                    end
                end
                READ: begin
                    if (arready) arvalid <= 1'b0;
                    if (rvalid) begin
                        cpu_rdata <= rdata;
                        rready    <= 1'b0;
                        state     <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule
