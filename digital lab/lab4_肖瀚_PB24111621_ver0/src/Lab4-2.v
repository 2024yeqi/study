module adder2bit(
    input           [1:0]         a,
    input           [1:0]         b,
    output   reg    [1:0]         out,
    output   reg                  Cout
);
    always @(*) begin
        Cout = (a[1]&b[1]) | (a[0]&b[1]&b[0]) | (a[1]&a[0]&b[0]);
        out[1] = (~a[1]&a[0]&~b[1]&b[0]) | (a[1]&a[0]&b[1]&b[0]) | (a[1]&~b[1]&~b[0]) | (a[1]&~a[0]&~b[1]) | (~a[1]&~a[0]&b[1]) | (~a[1]&b[1]&~b[0]);
        out[0] = a[0] ^ b[0];
    end
endmodule


module top2(
    input   [3:0]    sw,
    output  [7:0]    led
);

wire [1:0] out;
wire Cout;

adder2bit Adder2bit(
    .a(sw[3:2]),
    .b(sw[1:0]),
    .out(out),
    .Cout(Cout)
);

assign led = {5'b00000, Cout, out};

endmodule