module Top(
    input                   clk,
    input                   btn,
    output [2:0]            an,
    output [3:0]            d
);
Segment segment(
    .clk(clk),
    .btn(btn),
    .output_data(32'h24111621),     // <- 改为你学号中的 8 位数字
    .seg_data(d),
    .seg_an(an)
);
endmodule