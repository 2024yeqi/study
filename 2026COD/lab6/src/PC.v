module PC(
    input clk,rst,en,stall,flush,
    input [31:0] npc,
    output reg [31:0] pc
);
    always @(posedge clk) begin
        if(rst) pc<=32'h00400000;
        else if(en) begin
            if(flush) pc<=32'h00400000;
            else if(!stall) pc<=npc;
        end
    end
endmodule