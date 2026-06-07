module SLU (
    input       [31:0]  addr,
    input       [ 3:0]  dmem_access,
    input       [31:0]  rd_in,
    input       [31:0]  wd_in,
    output reg  [31:0]  rd_out,
    output reg  [31:0]  wd_out
);

wire [1:0] offset = addr[1:0];

// ========== 读数据处理 ==========
always @(*) begin
    case (dmem_access)
        // lb: 符号扩展字节
        4'b0000: begin
            case (offset)
                2'b00: rd_out = {{24{rd_in[7]}}, rd_in[7:0]};
                2'b01: rd_out = {{24{rd_in[15]}}, rd_in[15:8]};
                2'b10: rd_out = {{24{rd_in[23]}}, rd_in[23:16]};
                2'b11: rd_out = {{24{rd_in[31]}}, rd_in[31:24]};
                default: rd_out = 32'd0;
            endcase
        end

        // lh: 符号扩展半字 (只支持 offset=0 或 2，不对齐按需求给0)
        4'b0001: begin
            case (offset)
                2'b00: rd_out = {{16{rd_in[15]}}, rd_in[15:0]};
                2'b10: rd_out = {{16{rd_in[31]}}, rd_in[31:16]};
                default: rd_out = 32'd0;
            endcase
        end

        // lw: 字对齐
        4'b0010: begin
            rd_out = rd_in;
        end

        // lbu: 零扩展字节
        4'b0100: begin
            case (offset)
                2'b00: rd_out = {24'd0, rd_in[7:0]};
                2'b01: rd_out = {24'd0, rd_in[15:8]};
                2'b10: rd_out = {24'd0, rd_in[23:16]};
                2'b11: rd_out = {24'd0, rd_in[31:24]};
                default: rd_out = 32'd0;
            endcase
        end

        // lhu: 零扩展半字 (只支持 offset=0 或 2)
        4'b0101: begin
            case (offset)
                2'b00: rd_out = {16'd0, rd_in[15:0]};
                2'b10: rd_out = {16'd0, rd_in[31:16]};
                default: rd_out = 32'd0;
            endcase
        end

        default: rd_out = 32'd0;
    endcase
end

// ========== 写数据处理 ==========
always @(*) begin
    case (dmem_access)
        // sb: 存储字节
        4'b1000: begin
            wd_out = rd_in;
            case (offset)
                2'b00: wd_out[7:0]   = wd_in[7:0];
                2'b01: wd_out[15:8]  = wd_in[7:0];
                2'b10: wd_out[23:16] = wd_in[7:0];
                2'b11: wd_out[31:24] = wd_in[7:0];
            endcase
        end

        // sh: 存储半字 (只允许 offset=0 或 2)
        4'b1001: begin
            wd_out = rd_in;
            case (offset)
                2'b00: wd_out[15:0]  = wd_in[15:0];
                2'b10: wd_out[31:16] = wd_in[15:0];
                default: wd_out = rd_in;
            endcase
        end

        // sw: 存储字
        4'b1010: begin
            wd_out = wd_in;
        end

        default: wd_out = 32'd0;
    endcase
end

endmodule