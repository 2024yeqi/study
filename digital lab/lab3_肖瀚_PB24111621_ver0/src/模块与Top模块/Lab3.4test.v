module test_segment2(
    input               clk,
    input               btn,
    input   [7:0]       sw,

    output  [2:0]       an,
    output  [3:0]       d
);

wire [7:0] output_valid;
assign output_valid = {sw[7:1], 1'b1};

Segment2 segment2(
    .clk(clk),
    .btn(btn),
    .output_data(32'h24111621),
    .output_valid(output_valid),
    .seg_data(d),
    .seg_an(an)
);
endmodule
