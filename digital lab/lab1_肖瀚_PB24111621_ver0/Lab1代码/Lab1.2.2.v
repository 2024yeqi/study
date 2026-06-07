module MAX3 (
    input       [7:0]         num1, num2, num3,
    output reg  [7:0]         max
);
    always @(*) begin
        if (num3 > num1)
            max = (num3 > num2) ? num3 : num2;
        else
            max = (num1 > num2) ? num1 : num2;
    end
endmodule