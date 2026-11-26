`timescale 1ns / 1ps

module decode (
    input  wire [31:0] instr,
    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire [4:0]  rd,
    output reg  [31:0] imm_ext,
    output reg         reg_write,
    output reg         alu_src,
    output reg  [3:0]  alu_op,
    output reg         mem_read,
    output reg         mem_write,
    output reg         branch,
    output reg         mul_div_valid,
    output reg         csr_we,
    output wire [11:0] csr_addr
);

    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];

    assign rs1 = instr[19:15];
    assign rs2 = instr[24:20];
    assign rd  = instr[11:7];
    assign csr_addr = instr[31:20];

    always @(*) begin
        reg_write     = 1'b0; 
        alu_src       = 1'b0; 
        alu_op        = 4'b0000;
        mem_read      = 1'b0; 
        mem_write     = 1'b0; 
        branch        = 1'b0;
        mul_div_valid = 1'b0;
        csr_we        = 1'b0;
        imm_ext       = 32'd0;

        case (opcode)
            7'b0110011: begin // R-type (ALU & M-Extension Multiply/Divide)
                if (funct7 == 7'b0000001) begin
                    mul_div_valid = 1'b1;
                    reg_write     = 1'b1;
                end else begin
                    reg_write = 1'b1;
                    case (funct3)
                        3'b000: alu_op = (funct7[5]) ? 4'b0001 : 4'b0000; // SUB : ADD
                        3'b001: alu_op = 4'b0101; // SLL
                        3'b010: alu_op = 4'b1000; // SLT
                        3'b011: alu_op = 4'b1001; // SLTU
                        3'b100: alu_op = 4'b0100; // XOR
                        3'b101: alu_op = (funct7[5]) ? 4'b0111 : 4'b0110; // SRA : SRL
                        3'b110: alu_op = 4'b0011; // OR
                        3'b111: alu_op = 4'b0010; // AND
                    endcase
                end
            end

            7'b0010011: begin // I-type Arithmetic (ADDI, XORI, etc.)
                reg_write = 1'b1;
                alu_src   = 1'b1;
                imm_ext   = {{20{instr[31]}}, instr[31:20]};
                case (funct3)
                    3'b000: alu_op = 4'b0000; // ADDI
                    3'b001: alu_op = 4'b0101; // SLLI
                    3'b010: alu_op = 4'b1000; // SLTI
                    3'b011: alu_op = 4'b1001; // SLTIU
                    3'b100: alu_op = 4'b0100; // XORI
                    3'b101: alu_op = (funct7[5]) ? 4'b0111 : 4'b0110; // SRAI : SRLI
                    3'b110: alu_op = 4'b0011; // ORI
                    3'b111: alu_op = 4'b0010; // ANDI
                    default: alu_op = 4'b0000;
                endcase
            end

            7'b0000011: begin // I-type Load (LW)
                reg_write = 1'b1;
                alu_src   = 1'b1;
                mem_read  = 1'b1;
                imm_ext   = {{20{instr[31]}}, instr[31:20]};
                alu_op    = 4'b0000;
            end

            7'b0100011: begin // S-type Store (SW)
                alu_src   = 1'b1;
                mem_write = 1'b1;
                imm_ext   = {{20{instr[31]}}, instr[31:25], instr[11:7]};
                alu_op    = 4'b0000;
            end

            7'b1100011: begin // B-type Branch (BEQ, BNE, BLT, BGE)
                branch  = 1'b1;
                imm_ext = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
                alu_op  = 4'b0001; // Comparison check via internal subtraction
            end

            7'b0110111: begin // U-type LUI
                reg_write = 1'b1;
                alu_src   = 1'b1;
                imm_ext   = {instr[31:12], 12'd0};
                alu_op    = 4'b0000;
            end

            7'b0010111: begin // U-type AUIPC
                reg_write = 1'b1;
                alu_src   = 1'b1;
                imm_ext   = {instr[31:12], 12'd0};
                alu_op    = 4'b0000;
            end

            7'b1110011: begin // CSR System Instructions (CSRRW)
                reg_write = 1'b1;
                csr_we    = 1'b1;
            end
            
            default: ;
        endcase
    end
endmodule
