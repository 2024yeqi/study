module TIMER (
    input                        clk, rst,
    output           [3:0]       out,
    output           [2:0]       select
);

    reg [3:0]  outh ;
    reg [3:0]  outms;
    reg [3:0]  outmg;
    reg [3:0]  outss;
    reg [3:0]  outsg;
    reg [39:0] count;
    wire clk1s;

    initial begin
        outh    = 4'H9 ;
        outms   = 4'H5 ;
        outmg   = 4'H8 ;
        outss   = 4'H3 ;
        outsg   = 4'H0 ;
        count   = 40'H0;
    end

    always @(posedge clk) begin
        if (rst)
            count <= 40'd0;
        else begin
            if (count == 40'd9999_9999)
                count <= 40'd0;
            else
                count <= count + 40'd1;
        end
    end

    assign clk1s = (count == 40'd49_999_999);

    Segment segment(
        .clk                (clk),
        .btn                (rst),
        .output_data        ({outh, outms, outmg, outss, outsg}),
        .seg_data           (out),
        .seg_an             (select)
    );

    always @(posedge clk) begin
        if(rst) begin
            outh  <= 4'H9;
            outms <= 4'H5;
            outmg <= 4'H8;
            outss <= 4'H3;
            outsg <= 4'H0;
        end
        else if(clk1s) begin
            if(outsg == 9) begin
                outsg <= 0;
                if(outss == 5) begin
                    outss <= 0;
                    if(outmg == 9) begin
                        outmg <= 0;
                        if(outms == 5) begin
                            outms <= 0;
                            if(outh == 4'HF)
                                outh <= 0;
                            else
                                outh <= outh + 1;
                        end
                        else
                            outms <= outms + 1;
                    end
                    else
                        outmg <= outmg + 1;
                end
                else
                    outss <= outss + 1;
            end
            else
                outsg <= outsg + 1;
        end
    end

endmodule