`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/10/22 23:01:58
// Design Name: 
// Module Name: CountOnes
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module CountOnes(
    input       [31:0]         a,
    input       [4:0]          b,
    input       [4:0]          c,
    output reg  [5:0]         out
);
    integer i;
    always @(*) begin
        out = 'b0;
        for (i = b; i <= c; i = i + 1) begin
            out = out + a[i];
        end
    end
endmodule