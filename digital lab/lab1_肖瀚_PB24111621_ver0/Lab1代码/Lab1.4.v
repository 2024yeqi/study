module test( 
    input  [7:0]        a, b, 
    output [7:0]        c, d, e, f, g, h, i, j, k, l
); 
assign c = a & b; 
assign d = a || b; 
assign e = a ^ b; 
assign f = ~a; 
assign g = {a[2:0], b[3:0], {1'b1}}; 
assign h = b >>> 3; 
assign i = &b; 
assign j = (a > b) ? a : b; 
assign k = a - b; 
assign l = !a;
endmodule

/*
a = 8'b0011_0011, b = 8'b1111_0000

c = 8'b0011_0000
d = 8'b0000_0001
e = 8'b1100_0011
f = 8'b1100_1100
g = 8'b0110_0001
h = 8'b0001_1110
i = 8'b0000_0000
j = 8'b1111_0000
k = 8'b0100_0011
l = 8'b0000_0000
*/