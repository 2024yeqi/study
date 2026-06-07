module CoinMachine (
    input    clk,
    input    rst,
    input    A,         // 投入5分
    input    B,         // 投入10分
    output   Y,         // 出饮料
    output   Z          // 找零
);

reg  current_state, next_state;
localparam s0 = 1'd0;
localparam s1 = 1'd1;
reg Y_reg, Z_reg;

// 第一段：状态更新
always @(posedge clk) begin
    if (rst)
        current_state <= s0;
    else
        current_state <= next_state;
end

// 第二段：状态转移
always @(posedge clk) begin
    next_state <= current_state;
    Y_reg <= (~A & B) | (A & ~B & current_state);
    Z_reg <= (~A & B & current_state);
    case (current_state)
        s0: begin
            if(A && ~B)
                next_state <= s1;
            else
                next_state <= s0;
        end
        
        s1: begin
            if(~A && ~B)
                next_state <= s1;
            else
                next_state <= s0;
        end
        default: next_state <= s0;
    endcase
end

// 第三段：输出
assign Y = Y_reg;
assign Z = Z_reg;

endmodule