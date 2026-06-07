module encode(
    input [3:0]         I,
    output reg [1:0]    Y,
    output reg          en
);
    always @(*) begin
        en = 1;
        case (I)
            4'b1000: Y = 2'b11;
            4'b0100: Y = 2'b10;
            4'b0010: Y = 2'b01;
            4'b0001: Y = 2'b00;
            default: begin
                Y = 2'b00;
                en = 0;
            end
        endcase     
    end
endmodule


module top4_1(
    input [3:0]         sw,
    output [7:0]        led
);

wire [1:0]  Y;
wire en;

encode encode1(
    .I(sw[3:0]),
    .Y(Y),
    .en(en)
);

assign led = {en, 5'b00000, Y};

endmodule