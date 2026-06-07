module Segment2(
    input                       clk,
    input                       btn,
    input       [31:0]          output_data,
    input       [ 7:0]          output_valid,

    output reg  [ 3:0]          seg_data,
    output reg  [ 2:0]          seg_an
);

reg [31:0]  counter;
reg [2:0]   seg_id;
parameter   TIME_CNT = 250_000;

always @(posedge clk) begin
    if (btn)
        counter <= 0;
    else if (counter >= TIME_CNT)
        counter <= 0;
    else
        counter <= counter + 1;
end

always @(posedge clk) begin
    if (btn)
        seg_id <= 0;
    else if(counter == 1)
        seg_id <= seg_id + 1;
end

always @(*) begin
    seg_an = seg_id;
    
    if (output_valid[seg_id] != 1'b0)    begin
        case(seg_id)
            3'b000: seg_data = output_data[3:0];
            3'b001: seg_data = output_data[7:4];
            3'b010: seg_data = output_data[11:8];
            3'b011: seg_data = output_data[15:12];
            3'b100: seg_data = output_data[19:16];
            3'b101: seg_data = output_data[23:20];
            3'b110: seg_data = output_data[27:24];
            3'b111: seg_data = output_data[31:28];
        endcase
    end
    else    begin
        seg_an = 3'b000;
        seg_data = output_data[3:0];
    end
end

endmodule
