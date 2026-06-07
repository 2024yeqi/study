module multiple5(
    input           [7:0]          num,
    output   reg                   ismultiple5
);

wire [2:0]  sum1, sum2;
wire        Cout1, Cout2;
wire [1:0]  out1, out2;
reg  [2:0]  substract;

adder2bit adder2bit1(
    .a(num[1:0]),
    .b(num[5:4]),
    .out(out1),
    .Cout(Cout1)
);

adder2bit adder2bit2(
    .a(num[3:2]),
    .b(num[7:6]),
    .out(out2),
    .Cout(Cout2)
);

assign sum1[2:0] = {Cout1, out1};
assign sum2[2:0] = {Cout2, out2};

always @(*) begin
    substract = 3'b111;
    ismultiple5 = 1'b0;

    if (sum1 > sum2)
        substract = ~(sum2 + ~sum1 + 1) + 1;
    else 
        substract = ~(sum1 + ~sum2 + 1) + 1;

    if (substract == 3'b101 || substract == 3'b000)
        ismultiple5 = 1'b1;
end

endmodule


module top4_3(
    input   [7:0]       sw,
    output  [1:0]       led
);

wire ismultiple5;

multiple5 Multiple5(
    .num(sw),
    .ismultiple5(ismultiple5)
);

assign led = {1'b0, ismultiple5};

endmodule