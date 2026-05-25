module PC (
    input         clk,
    input         rst,
    input         en,
    input  [31:0] npc,
    output reg [31:0] pc
);
    always @(posedge clk) begin
        if (rst)
            pc <= 32'h00400000;
        else if (en)
            pc <= npc;
    end
endmodule