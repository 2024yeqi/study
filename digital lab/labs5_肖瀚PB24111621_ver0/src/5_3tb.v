`timescale 1ns/1ps

module tb_CoinMachine();
    reg clk;
    reg rst;
    reg A;
    reg B;
    wire Y;
    wire Z;
    
    // 实例化被测模块
    CoinMachine uut (
        .clk(clk),
        .rst(rst),
        .A(A),
        .B(B),
        .Y(Y),
        .Z(Z)
    );
    
    // 时钟生成
    always #5 clk = ~clk;
    
    // 测试用例
    initial begin
        // 初始化
        clk = 0;
        rst = 1;
        A = 0;
        B = 0;
        
        // 复位
        #20 rst = 0;
        
        // 测试用例1: 投入10分，直接获得饮料
        #10 A = 0; B = 1;
        #10 A = 0; B = 0;
        
        // 测试用例2: 投入5分+5分，获得饮料
        #10 A = 1; B = 0;
        #10 A = 0; B = 0;
        #10 A = 1; B = 0;
        #10 A = 0; B = 0;
        
        // 测试用例3: 投入5分+10分，获得饮料和找零
        #10 A = 1; B = 0;
        #10 A = 0; B = 0;
        #10 A = 0; B = 1;
        #10 A = 0; B = 0;
        
        // 测试用例4: 连续投入10分
        #10 A = 0; B = 1;
        #10 A = 0; B = 0;
        #10 A = 1; B = 1;
        #10 A = 0; B = 0;

        #10 A = 1; B = 0;
        #10 A = 0; B = 0;
        #10 A = 1; B = 1;
        #10 A = 0; B = 0;
        
        #20 $display("测试完成");
        $finish;
    end
    
endmodule