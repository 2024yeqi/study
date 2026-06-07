module GrayCounter(
input                               clk,
input                               rst,
output                              out        
); 

reg [3:0] gray_count;

always @(posedge clk) begin
    if (rst)
        gray_count <= 4'b0000;
    else begin
        case (gray_count)
            4'b0000:    gray_count <= 4'b0001;
            4'b0001:    gray_count <= 4'b0011;
            4'b0011:    gray_count <= 4'b0010;
            4'b0010:    gray_count <= 4'b0110;
            4'b0110:    gray_count <= 4'b0111;
            4'b0111:    gray_count <= 4'b0101;
            4'b0101:    gray_count <= 4'b0100;
            4'b0100:    gray_count <= 4'b1100;
            4'b1100:    gray_count <= 4'b1101;
            4'b1101:    gray_count <= 4'b1111;
            4'b1111:    gray_count <= 4'b1110;
            4'b1110:    gray_count <= 4'b1010;
            4'b1010:    gray_count <= 4'b1011;
            4'b1011:    gray_count <= 4'b1001;
            4'b1001:    gray_count <= 4'b1000;
            4'b1000:    gray_count <= 4'b0000;
        endcase
    end    
end

assign out = (gray_count == 4'b1000);

endmodule