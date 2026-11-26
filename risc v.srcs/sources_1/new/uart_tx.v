`timescale 1ns / 1ps

module uart_tx (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] tx_data,
    input  wire        tx_we,
    output wire        tx_busy,
    output reg         tx
);

    localparam CLK_PER_BIT = 16'd434; 
    localparam IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;

    reg [1:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  tx_buf;

    assign tx_busy = (state != IDLE);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; tx <= 1'b1; clk_cnt <= 16'd0; bit_idx <= 3'd0; tx_buf <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    if (tx_we) begin
                        tx_buf <= tx_data[7:0];
                        state  <= START;
                    end
                end
                START: begin
                    tx <= 1'b0;
                    if (clk_cnt < CLK_PER_BIT - 1) clk_cnt <= clk_cnt + 1'b1;
                    else begin clk_cnt <= 16'd0; state <= DATA; bit_idx <= 3'd0; end
                end
                DATA: begin
                    tx <= tx_buf[bit_idx];
                    if (clk_cnt < CLK_PER_BIT - 1) clk_cnt <= clk_cnt + 1'b1;
                    else begin
                        clk_cnt <= 16'd0;
                        if (bit_idx < 3'd7) bit_idx <= bit_idx + 1'b1;
                        else state <= STOP;
                    end
                end
                STOP: begin
                    tx <= 1'b1;
                    if (clk_cnt < CLK_PER_BIT - 1) clk_cnt <= clk_cnt + 1'b1;
                    else begin clk_cnt <= 16'd0; state <= IDLE; end
                end
            endcase
        end
    end
endmodule
