module BRANCH(
    input       [ 3:0]  br_type,
    input       [31:0]  br_src0,
    input       [31:0]  br_src1,
    output reg  [ 1:0]  npc_sel
);

always @(*) begin
    case(br_type)   // 00 PC+4，01 JAL，10 JALR
        4'b0000: npc_sel = 2'b00;
        4'b0001: npc_sel = (br_src0 == br_src1) ? 2'b01 : 2'b00;
        4'b0010: npc_sel = (br_src0 != br_src1) ? 2'b01 : 2'b00;
        4'b0011: npc_sel = ($signed(br_src0) < $signed(br_src1)) ? 2'b01 : 2'b00;
        4'b0100: npc_sel = ($signed(br_src0) >= $signed(br_src1)) ? 2'b01 : 2'b00;
        4'b0101: npc_sel = (br_src0 < br_src1) ? 2'b01 : 2'b00;
        4'b0110: npc_sel = (br_src0 >= br_src1) ? 2'b01 : 2'b00;
        4'b0111: npc_sel = 2'b01;
        4'b1000: npc_sel = 2'b10;
        default: npc_sel = 2'b00;
    endcase
end

endmodule
