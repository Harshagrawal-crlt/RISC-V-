`timescale 1ns / 1ps

module mul_div_unit (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] operand_a,
    input  wire [31:0] operand_b,
    input  wire [4:0]  rd_in,
    input  wire [2:0]  funct3,
    input  wire        valid,
    output reg  [31:0] result,
    output reg  [4:0]  rd_out,
    output reg         done,
    output wire        busy
);

    localparam IDLE = 2'b00, CALC = 2'b01, DONE = 2'b10;
    reg [1:0]  state;
    reg [5:0]  count;
    reg [31:0] reg_a, reg_b;
    reg [63:0] accum;
    reg [2:0]  saved_funct3;
    reg [4:0]  saved_rd;


    assign busy = (state != IDLE) || (valid && (state == IDLE) && !done);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= IDLE;
            done         <= 1'b0;
            result       <= 32'd0;
            count        <= 6'd0;
            accum        <= 64'd0;
            reg_a        <= 32'd0;
            reg_b        <= 32'd0;
            saved_funct3 <= 3'd0;
            saved_rd     <= 5'd0;
            rd_out       <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (valid && !done) begin
                        state        <= CALC;
                        count        <= 6'd0;
                        reg_a        <= operand_a;
                        reg_b        <= operand_b;
                        saved_funct3 <= funct3;
                        saved_rd     <= rd_in;
                        accum        <= {32'd0, operand_a};
                    end
                end

                CALC: begin
                    count <= count + 1'b1;
                    if (saved_funct3[2] == 1'b0) begin 
                        if (count == 6'd0) begin
                            accum <= (saved_funct3 == 3'b001) ? 
                                     ($signed({{32{reg_a[31]}}, reg_a}) * $signed({{32{reg_b[31]}}, reg_b})) :
                                     ({32'd0, reg_a} * {32'd0, reg_b});
                            state <= DONE;
                        end
                    end else begin 
                        if (count == 6'd32) begin
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    done   <= 1'b1;
                    state  <= IDLE;
                    rd_out <= saved_rd;
                    case (saved_funct3)
                        3'b000: result <= accum[31:0];                                                     // MUL
                        3'b001: result <= accum[63:32];                                                    // MULH
                        3'b010, 3'b011: result <= accum[63:32];                                            // MULHSU / MULHU
                        3'b100: result <= (reg_b == 0) ? 32'hFFFFFFFF : $signed(reg_a) / $signed(reg_b);   // DIV
                        3'b101: result <= (reg_b == 0) ? 32'hFFFFFFFF : reg_a / reg_b;                    // DIVU
                        3'b110: result <= (reg_b == 0) ? reg_a : $signed(reg_a) % $signed(reg_b);         // REM
                        3'b111: result <= (reg_b == 0) ? reg_a : reg_a % reg_b;                           // REMU
                        default: result <= accum[31:0];
                    endcase
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
