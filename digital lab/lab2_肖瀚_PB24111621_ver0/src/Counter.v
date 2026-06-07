`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/10/22 12:24:35
// Design Name: 
// Module Name: Counter
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


module Counter #(
    parameter   MAX_VALUE = 8'd100,
    parameter   MIN_VALUE = 8'd0
)(
    input                   clk,
    input                   rst,
    input                   enable,
    output                  out
);

reg [7:0] counter;
always @(posedge clk) begin
    if (rst)
        counter <= 0;
    else if (enable) begin
        if (counter < MIN_VALUE)
            counter <= MIN_VALUE;
        else if (counter >= MAX_VALUE)
            counter <= MIN_VALUE;
        else
            counter <= counter + 8'b1;
    end
    else
        counter <= 0;
end

assign out = (counter == MAX_VALUE);
endmodule