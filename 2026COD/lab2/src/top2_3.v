module TOP (
    input                   [ 0 : 0]            clk,
    input                   [ 0 : 0]            rst,

    input                   [ 0 : 0]            enable,
    input                   [ 4 : 0]            in,
    input                   [ 1 : 0]            ctrl,

    output                  [ 3 : 0]            seg_data,
    output                  [ 2 : 0]            seg_an
);

    reg [31:0]  alu_src0; // 操作数0寄存器
    reg [31:0]  alu_src1; // 操作数1寄存器
    reg [4:0]   alu_op;   // 操作码寄存器
    reg [31:0]  res;      // 结果寄存器
    wire [31:0] alu_res;  // ALU运算结果

    always @(posedge clk) begin
        if(rst) begin
            alu_src0 <= 32'b0;
            alu_src1 <= 32'b0;
            alu_op   <= 5'b0;
            res      <= 32'b0;
        end else if(enable) begin
            case (ctrl)
                2'b00: begin
                    alu_op <= in[4:0];
                end
                2'b01: begin
                    alu_src0 <= {{27{in[4]}}, in[4:0]};
                end
                2'b10: begin
                    alu_src1 <= {{27{in[4]}}, in[4:0]};
                end
                2'b11: begin
                    res <= alu_res;
                end
            endcase
        end
    end

    ALU alu (
        .alu_src0(alu_src0),
        .alu_src1(alu_src1),
        .alu_op(alu_op),
        .alu_res(alu_res)
    );

    Segment segment (
        .clk         (clk),
        .rst         (rst),
        .output_data (res),
        .seg_data    (seg_data),
        .seg_an      (seg_an)
    );
endmodule