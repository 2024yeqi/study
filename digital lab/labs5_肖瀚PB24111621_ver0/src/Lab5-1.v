module Regfile (
    input                       clk,          // 时钟信号
    input           [4:0]       ra1,          // 读端口 1 地址
    input           [4:0]       ra2,          // 读端口 2 地址
    input           [4:0]       wa,           // 写端口地址
    input                       we,           // 写使能信号
    input           [31:0]      din,          // 写数据
    output  reg     [31:0]      dout1,        // 读端口 1 数据输出
    output  reg     [31:0]      dout2         // 读端口 2 数据输出
);

reg [31:0] reg_file [31:0];
integer i;

// 初始化
initial begin
    for (i = 0; i < 32; i = i + 1) begin
        reg_file[i] = 32'b0;
    end
end

always @(posedge clk) begin
    if (we && (wa != 5'b0)) begin
        reg_file[wa] <= din;
    end
end

// 读端口1
always @(*) begin
    if (ra1 == 5'b0) begin
        dout1 = 32'b0;
    end
    else if (we && (ra1 == wa) && (wa != 5'b0)) begin
        dout1 = din;
    end
    else begin
        dout1 = reg_file[ra1];
    end
end

// 读端口2
always @(*) begin
    if (ra2 == 5'b0) begin
        dout2 = 32'b0;
    end
    else if (we && (ra2 == wa) && (wa != 5'b0)) begin
        dout2 = din;
    end
    else begin
        dout2 = reg_file[ra2];
    end
end

endmodule