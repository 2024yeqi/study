`timescale 1ns / 1ps

module ALU_tb();

    `define ADD     5'b00000
    `define SUB     5'b00010
    `define SLT     5'b00100
    `define SLTU    5'b00101
    `define AND     5'b01001
    `define OR      5'b01010
    `define XOR     5'b01011
    `define SLL     5'b01110
    `define SRL     5'b01111
    `define SRA     5'b10000
    `define SRC0    5'b10001
    `define SRC1    5'b10010

    // 输入信号
    reg  [31:0] alu_src0;
    reg  [31:0] alu_src1;
    reg  [4:0]  alu_op;

    // 输出信号
    wire [31:0] alu_res;

    // 实例化 ALU
    ALU u_ALU (
        .alu_src0 (alu_src0),
        .alu_src1 (alu_src1),
        .alu_op   (alu_op),
        .alu_res  (alu_res)
    );

    initial begin
        // 初始化输入
        alu_src0 = 32'hFFFF_FFFF;   // 全1，作为有符号数 -1
        alu_src1 = 32'h0000_0001;   // 数值 1
        alu_op   = 5'b00000;

        // 遍历所有可能的操作码（0~31）
        repeat(32) begin
            #20;                     // 等待 20ns，让电路稳定并观察结果
            alu_op = alu_op + 1'b1; // 递增操作码
        end

        #20;
        $finish;
    end

endmodule