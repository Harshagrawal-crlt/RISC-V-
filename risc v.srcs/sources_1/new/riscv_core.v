`timescale 1ns / 1ps

module riscv_core (
    input  wire        clk,
    input  wire        rst_n,
    output wire [31:0] instr_addr,
    input  wire [31:0] instr_in,
    output wire [31:0] data_addr,
    output wire [31:0] data_write_out,
    input  wire [31:0] data_read_in,
    output wire        mem_read_en,
    output wire        mem_write_en
);

    
    wire [31:0] fetch_pc, id_pc, id_instr;
    wire [4:0]  id_rs1, id_rs2, id_rd;
    wire [31:0] id_imm, id_rdata1, id_rdata2;
    wire        id_reg_write, id_alu_src, id_mem_read, id_mem_write, id_branch, id_mul_div_valid, id_csr_we;
    wire [3:0]  id_alu_op;
    wire [11:0] id_csr_addr;

    wire        hazard_stall, mul_busy, mul_done;
    wire [4:0]  mul_rd;
    wire [31:0] mul_res;
    wire        global_stall = hazard_stall || mul_busy;

    
    wire branch_taken;
    wire [31:0] branch_target;

    fetch u_fetch (
        .clk(clk), 
        .rst_n(rst_n), 
        .stall(global_stall),
        .branch_taken(branch_taken), 
        .branch_target(branch_target), 
        .pc(fetch_pc)
    );

    assign instr_addr = fetch_pc;

    
    stall_skid_buffer u_skid (
        .clk(clk), 
        .rst_n(rst_n), 
        .stall(global_stall), 
        .flush(branch_taken),
        .fetch_pc(fetch_pc), 
        .fetch_instr(instr_in), 
        .id_pc(id_pc), 
        .id_instr(id_instr)
    );

    
    decode u_decode (
        .instr(id_instr), 
        .rs1(id_rs1), 
        .rs2(id_rs2), 
        .rd(id_rd), 
        .imm_ext(id_imm),
        .reg_write(id_reg_write), 
        .alu_src(id_alu_src), 
        .alu_op(id_alu_op),
        .mem_read(id_mem_read), 
        .mem_write(id_mem_write), 
        .branch(id_branch),
        .mul_div_valid(id_mul_div_valid), 
        .csr_we(id_csr_we), 
        .csr_addr(id_csr_addr)
    );

    
    wire uses_rs1 = id_reg_write || id_mem_read || id_mem_write || id_branch || id_mul_div_valid || id_csr_we;
    wire uses_rs2 = (!id_alu_src && (id_reg_write || id_mul_div_valid)) || id_mem_write || id_branch;

    scoreboard u_scoreboard (
        .clk(clk), 
        .rst_n(rst_n), 
        .id_rs1(id_rs1), 
        .id_rs2(id_rs2), 
        .uses_rs1(uses_rs1),
        .uses_rs2(uses_rs2),
        .id_rd(id_rd),
        .id_reg_write(id_reg_write), 
        .id_mul_div_valid(id_mul_div_valid && !global_stall),
        .ex_clear_valid(mul_done),
        .ex_clear_rd(mul_rd), 
        .hazard_stall(hazard_stall)
    );

    
    wire [4:0]  wb_rd = mul_done ? mul_rd : id_rd;
    wire        wb_en = mul_done || (id_reg_write && !id_mul_div_valid && !global_stall);
    wire [31:0] final_write_back_data;

    reg_file u_reg_file (
        .clk(clk), 
        .reg_write(wb_en),
        .rs1(id_rs1), 
        .rs2(id_rs2), 
        .rd(wb_rd), 
        .write_data(final_write_back_data),
        .read_data1(id_rdata1), 
        .read_data2(id_rdata2)
    );

    
    wire [31:0] alu_op_a = (id_instr[6:0] == 7'b0110111) ? 32'd0 : id_rdata1;
    wire [31:0] alu_op_b = id_alu_src ? id_imm : id_rdata2;
    wire [31:0] alu_res;
    wire        alu_zero;

    alu u_alu (
        .alu_in_a(alu_op_a), 
        .alu_in_b(alu_op_b), 
        .alu_op(id_alu_op),
        .alu_out(alu_res), 
        .alu_zero(alu_zero)
    );

    
    wire branch_condition = (id_instr[14:12] == 3'b001) ? (!alu_zero) : alu_zero;
    assign branch_taken   = id_branch && branch_condition && !global_stall;
    assign branch_target  = id_pc + id_imm;

    
    mul_div_unit u_mul_div (
        .clk(clk), 
        .rst_n(rst_n), 
        .operand_a(id_rdata1), 
        .operand_b(id_rdata2),
        .rd_in(id_rd),
        .funct3(id_instr[14:12]), 
        .valid(id_mul_div_valid && !hazard_stall),
        .result(mul_res), 
        .rd_out(mul_rd),
        .done(mul_done), 
        .busy(mul_busy)
    );

    
    wire [31:0] csr_res;
    csr_unit u_csr (
        .clk(clk), 
        .rst_n(rst_n), 
        .csr_addr(id_csr_addr), 
        .csr_wdata(id_rdata1),
        .csr_we(id_csr_we && !global_stall), 
        .csr_rdata(csr_res)
    );

   
    assign data_addr      = alu_res;
    assign data_write_out = id_rdata2;
    assign mem_read_en    = id_mem_read && !global_stall;
    assign mem_write_en   = id_mem_write && !global_stall;

    
    assign final_write_back_data = mul_done    ? mul_res      : 
                                   id_csr_we   ? csr_res      : 
                                   id_mem_read ? data_read_in : alu_res;

endmodule
