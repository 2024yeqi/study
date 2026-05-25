module DECODER (
    input  [31:0] inst,
    
    output [ 4:0] rf_ra0,
    output [ 4:0] rf_ra1,
    output [ 4:0] rf_wa,
    output        rf_we,
    
    output [ 4:0] alu_op,
    output [31:0] imm,
    
    output        alu_src0_sel,
    output        alu_src1_sel
);

    // 字段提取
    wire [6:0] opcode = inst[6:0];
    wire [2:0] funct3 = inst[14:12];
    wire [6:0] funct7 = inst[31:25];
    wire [4:0] rs1    = inst[19:15];
    wire [4:0] rs2    = inst[24:20];
    wire [4:0] rd     = inst[11:7];
    
    assign rf_ra0 = rs1;
    assign rf_ra1 = rs2;
    assign rf_wa  = rd;
    
    // 立即数生成
    wire [31:0] imm_i = {{20{inst[31]}}, inst[31:20]};
    wire [31:0] imm_u = {inst[31:12], 12'b0};
    
    // 根据 opcode 选择立即数类型
    reg [31:0] imm_selected;
    always @(*) begin
        case (opcode)
            7'b0010011: imm_selected = imm_i;  // I-type
            7'b0110111, 7'b0010111: imm_selected = imm_u; // U-type
            default: imm_selected = 32'h0;
        endcase
    end
    assign imm = imm_selected;
    
    // 控制信号生成
    reg        rf_we_reg;
    reg [ 4:0] alu_op_reg;
    reg        alu_src0_sel_reg;
    reg        alu_src1_sel_reg;
    
    always @(*) begin
        // 默认值
        rf_we_reg = 1'b0;
        alu_op_reg = 5'b00000;
        alu_src0_sel_reg = 1'b0;
        alu_src1_sel_reg = 1'b0;
        
        case (opcode)
            // R-type
            7'b0110011: begin
                rf_we_reg = 1'b1;
                alu_src0_sel_reg = 1'b0;   // rs1
                alu_src1_sel_reg = 1'b0;   // rs2
                case ({funct7, funct3})
                    {7'b0000000, 3'b000}: alu_op_reg = 5'b00000; // ADD
                    {7'b0100000, 3'b000}: alu_op_reg = 5'b00010; // SUB
                    {7'b0000000, 3'b010}: alu_op_reg = 5'b00100; // SLT
                    {7'b0000000, 3'b011}: alu_op_reg = 5'b00101; // SLTU
                    {7'b0000000, 3'b111}: alu_op_reg = 5'b01001; // AND
                    {7'b0000000, 3'b110}: alu_op_reg = 5'b01010; // OR
                    {7'b0000000, 3'b100}: alu_op_reg = 5'b01011; // XOR
                    {7'b0000000, 3'b001}: alu_op_reg = 5'b01110; // SLL
                    {7'b0000000, 3'b101}: alu_op_reg = 5'b01111; // SRL
                    {7'b0100000, 3'b101}: alu_op_reg = 5'b10000; // SRA
                    default: rf_we_reg = 1'b0;
                endcase
            end
            
            // I-type (ALU immediate)
            7'b0010011: begin
                rf_we_reg = 1'b1;
                alu_src0_sel_reg = 1'b0;   // rs1
                alu_src1_sel_reg = 1'b1;   // imm
                case (funct3)
                    3'b000: alu_op_reg = 5'b00000; // ADDI
                    3'b010: alu_op_reg = 5'b00100; // SLTI
                    3'b011: alu_op_reg = 5'b00101; // SLTIU
                    3'b111: alu_op_reg = 5'b01001; // ANDI
                    3'b110: alu_op_reg = 5'b01010; // ORI
                    3'b100: alu_op_reg = 5'b01011; // XORI
                    3'b001: alu_op_reg = 5'b01110; // SLLI
                    3'b101: begin
                        if(funct7 == 7'b0000000)
                            alu_op_reg = 5'b01111; // SRLI
                        else if(funct7 == 7'b0100000)
                            alu_op_reg = 5'b10000; // SRAI
                    end
                    default: rf_we_reg = 1'b0;
                endcase
            end
            
            // U-type: lui
            7'b0110111: begin
                rf_we_reg = 1'b1;
                alu_src0_sel_reg = 1'b0;   // 无关（未用）
                alu_src1_sel_reg = 1'b1;   // imm
                alu_op_reg = 5'b10010;     // SRC1 (直接将imm传给结果)
            end
            
            // U-type: auipc
            7'b0010111: begin
                rf_we_reg = 1'b1;
                alu_src0_sel_reg = 1'b1;   // PC
                alu_src1_sel_reg = 1'b1;   // imm (U-type)
                alu_op_reg = 5'b00000;     // ADD (PC + imm)
            end
            
            default: begin
                rf_we_reg = 1'b0;
                alu_op_reg = 5'b00000;
                alu_src0_sel_reg = 1'b0;
                alu_src1_sel_reg = 1'b0;
            end
        endcase
    end
    
    assign rf_we = rf_we_reg;
    assign alu_op = alu_op_reg;
    assign alu_src0_sel = alu_src0_sel_reg;
    assign alu_src1_sel = alu_src1_sel_reg;

endmodule