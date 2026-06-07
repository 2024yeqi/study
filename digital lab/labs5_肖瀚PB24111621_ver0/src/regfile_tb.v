module RegFile1_tb ();
    reg              clk;
    reg     [4:0]    ra1, ra2, wa;
    reg              we;
    reg     [31:0]   din;
    wire    [31:0]   dout1;
    wire    [31:0]   dout2;

    Regfile u_regfile(
        .clk(clk),
        .ra1(ra1),
        .ra2(ra2),
        .wa(wa),
        .we(we),
        .din(din),
        .dout1(dout1),
        .dout2(dout2)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        ra1 = 5'h0; ra2 = 5'h0; wa = 5'h0; we = 1'b0; din = 32'h0;

        #10;

        ra1 = 5'h0; ra2 = 5'h0; wa = 5'h3; we = 1'b1; din = 32'h12345678;
        #10;

        ra1 = 5'h3; ra2 = 5'h2; wa = 5'h2; we = 1'b1; din = 32'h87654321;
        #10;
        
        ra1 = 5'h3; ra2 = 5'h2; wa = 5'h0; we = 1'b0; din = 32'h0;
        #10;
        
        ra1 = 5'h3; ra2 = 5'h0; wa = 5'h0; we = 1'b1; din = 32'habccdeff;
        #10;
        
        $finish;
    end

endmodule