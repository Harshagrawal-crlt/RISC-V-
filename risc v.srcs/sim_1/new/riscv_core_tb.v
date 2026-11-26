`timescale 1ns / 1ps

module riscv_core_tb;

    reg         clk;
    reg         rst_n;
    reg  [31:0] instr_in;
    reg  [31:0] data_read_in;

    wire [31:0] instr_addr;
    wire [31:0] data_addr;
    wire [31:0] data_write_out;
    wire        mem_read_en;
    wire        mem_write_en;

    wire        uart_tx_line;
    wire        uart_busy;

    reg [31:0] instr_mem [0:31];
    reg [31:0] data_mem  [0:31];

 
    riscv_core uut (
        .clk(clk), .rst_n(rst_n), .instr_addr(instr_addr), .instr_in(instr_in),
        .data_addr(data_addr), .data_write_out(data_write_out), .data_read_in(data_read_in),
        .mem_read_en(mem_read_en), .mem_write_en(mem_write_en)
    );

    
    wire uart_we = mem_write_en && ((data_addr == 32'h0000_1000) || (data_addr == 32'h0000_0010));
    uart_tx tb_uart (
        .clk(clk), .rst_n(rst_n), .tx_data(data_write_out), .tx_we(uart_we),
        .tx_busy(uart_busy), .tx(uart_tx_line)
    );

    always #10 clk = ~clk; 

    
    always @(*) begin
        if (instr_addr[31:2] < 32) instr_in = instr_mem[instr_addr[31:2]];
        else                       instr_in = 32'h0000_0013; 

        if (mem_read_en && (data_addr[31:2] < 32)) data_read_in = data_mem[data_addr[31:2]];
        else                                       data_read_in = 32'd0;
    end

    always @(posedge clk) begin
        if (mem_write_en && (data_addr[31:2] < 32) && (data_addr != 32'h0000_1000) && (data_addr != 32'h0000_0010)) begin
            data_mem[data_addr[31:2]] <= data_write_out;
        end
    end

    integer k;
    initial begin
        
        for (k = 0; k < 32; k = k + 1) begin
            instr_mem[k] = 32'h0000_0013; // NOP (addi x0, x0, 0)
            data_mem[k]  = 32'd0;
        end

        // --- Test Vector 1: Multi-Cycle Multiplication & UART Output ---
        instr_mem[0]  = 32'h00500293; // addi x5, x0, 5      (x5 = 5)
        instr_mem[1]  = 32'h00A00313; // addi x6, x0, 10     (x6 = 10)
        instr_mem[2]  = 32'h02628333; // mul  x6, x5, x6     (x6 = 5 * 10 = 50 -> Multi-cycle)
        instr_mem[3]  = 32'h00602023; // sw   x6, 0(x0)      (Store 50 to address 0 -> data_mem[0])
        instr_mem[4]  = 32'h04100393; // addi x7, x0, 65     (ASCII 'A')
        instr_mem[5]  = 32'h00702823; // sw   x7, 4096(x0)   (Store to address 0x1000 / 0x10 -> UART out)

        // --- Test Vector 2: Memory Load (LW) & Subtraction (SUB) ---
        instr_mem[6]  = 32'h00002403; // lw   x8, 0(x0)      (Load data_mem[0] -> x8 = 50)
        instr_mem[7]  = 32'h405404b3; // sub  x9, x8, x5     (x9 = 50 - 5 = 45 -> R-type SUB)
        instr_mem[8]  = 32'h00902223; // sw   x9, 4(x0)      (Store 45 to address 4 -> data_mem[1])

        // --- Test Vector 3: Hardware Division (DIV) Multi-cycle Unit ---
        instr_mem[9]  = 32'h05a00513; // addi x10, x0, 90   (x10 = 90)
        instr_mem[10] = 32'h00900593; // addi x11, x0, 9    (x11 = 9)
        instr_mem[11] = 32'h02b54633; // div  x12, x10, x11  (x12 = 90 / 9 = 10 -> 32-cycle hardware DIV)
        instr_mem[12] = 32'h00c02423; // sw   x12, 8(x0)     (Store 10 to address 8 -> data_mem[2])

        // --- Test Vector 4: Conditional Branch (BEQ) ---
        instr_mem[13] = 32'h00948663; // beq  x9, x9, +12    (Branch taken: skips failure branch at 14, 15)
        instr_mem[14] = 32'h06300693; // addi x13, x0, 99    (Failure marker - skipped)
        instr_mem[15] = 32'h00d02623; // sw   x13, 12(x0)    (Store failure to address 12 - skipped)
        instr_mem[16] = 32'h06400693; // addi x13, x0, 100   (Success marker: 100)
        instr_mem[17] = 32'h00d02623; // sw   x13, 12(x0)    (Store 100 to address 12 -> data_mem[3])
        instr_mem[18] = 32'h00000013; // NOP
        instr_mem[19] = 32'h00000013; // NOP

        clk = 0; rst_n = 0;
        #20;
        rst_n = 1;

        $display("[VIVADO SIMULATION START]");
        #2000; 

        $display("--------------------------------------------------");
        $display("VERIFICATION REPORT:");
        $display("Vector 1: MUL (5 * 10)       -> Data Mem [0] = %0d (Expected: 50)  [%s]", 
                 data_mem[0], (data_mem[0] == 50) ? "PASS" : "FAIL");
        $display("Vector 2: LW & SUB (50 - 5)  -> Data Mem [1] = %0d (Expected: 45)  [%s]", 
                 data_mem[1], (data_mem[1] == 45) ? "PASS" : "FAIL");
        $display("Vector 3: DIV (90 / 9)       -> Data Mem [2] = %0d (Expected: 10)  [%s]", 
                 data_mem[2], (data_mem[2] == 10) ? "PASS" : "FAIL");
        $display("Vector 4: BEQ Branch Taken   -> Data Mem [3] = %0d (Expected: 100) [%s]", 
                 data_mem[3], (data_mem[3] == 100) ? "PASS" : "FAIL");
        $display("Vector 5: Memory-Mapped UART -> Activity Flag= %0b (Expected: 1)   [%s]", 
                 uart_busy, (uart_busy == 1'b1) ? "PASS" : "FAIL");
        $display("--------------------------------------------------");
        $finish;
    end

endmodule
