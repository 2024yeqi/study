module MAX3 (
    input   [7:0]         num1, num2, num3,
    output  [7:0]         max
);
    wire [7:0] bigger_of_two;

    MAX2 max_1 (
        .num1(num1),
        .num2(num2),
        .max(bigger_of_two)
    );

    MAX2 max_2 (
        .num1(bigger_of_two),
        .num2(num3),
        .max(max)
    );

endmodule