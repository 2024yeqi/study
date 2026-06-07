module Counter #(
    parameter   MAX_VALUE = 26'd50_000_000
)(
    input                   clk,
    input                   btn,
    output reg [7:0]        led
);

reg [25:0] counter;
assign rst = btn;

always @(posedge clk) begin
    if (rst)
        counter <= 0;
    else begin
        if (counter >= MAX_VALUE)
            counter <= 0;
        else
            counter <= counter + 26'b1;
    end
end

always @(posedge clk) begin
    if (rst)
        led <= 8'b0000_0000;
    else if (counter == 1) begin
        led <= ~led;
    end
end

endmodule