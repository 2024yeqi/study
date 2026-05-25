module DECODER (
    input  [31:0] inst,
    output [4:0]  alu_op,
    output [3:0]  dmem_access,
    output [31:0] imm,

    output [4:0]  rf_ra0,
    output [4:0]  rf_ra1,
    output [4:0]  rf_wa,
    output        rf_we,
    output [1:0]  rf_wd_sel,
    
    output        alu_src0_sel,
    output        alu_src1_sel,
    output [3:0]  br_type
);

wire [6:0] opcode = inst[6:0];
wire [2:0] func3  = inst[14:12];
wire [6:0] func7  = inst[31:25];
assign rf_ra0     = inst[19:15];
assign rf_ra1     = inst[24:20];
assign rf_wa      = inst[11:7];

reg [4:0]  alu_op_reg;
reg [31:0] imm_reg;
reg [3:0]  dmem_access_reg;
reg        rf_we_reg;
reg [1:0]  rf_wd_sel_reg;   // 00 ALU计算结果，01 读到的内容，10 PC+4
reg        src0_sel_reg;
reg        src1_sel_reg;
reg [3:0]  br_type_reg;

always @(*) begin
    alu_op_reg       = 5'b00000;
    imm_reg          = 32'd0;
    dmem_access_reg  = 4'b0000;
    rf_we_reg        = 1'b0;
    rf_wd_sel_reg    = 2'b00;
    src0_sel_reg     = 1'b0;
    src1_sel_reg     = 1'b0;
    br_type_reg      = 4'b0000;

    case(opcode)
        7'b0110011: begin // R型
            rf_we_reg = 1'b1;
            case(func3)
                3'b000: alu_op_reg = (func7==7'b0000000) ? 5'b00000 : 5'b00010; // ADD or SUB
                3'b001: alu_op_reg = 5'b01110; // SLL
                3'b010: alu_op_reg = 5'b00100; // SLT
                3'b011: alu_op_reg = 5'b00101; // SLTU
                3'b100: alu_op_reg = 5'b01011; // XOR
                3'b101: alu_op_reg = (func7==7'b0000000) ? 5'b01111 : 5'b10000; // SRL or SRA
                3'b110: alu_op_reg = 5'b01010; // OR
                3'b111: alu_op_reg = 5'b01001; // AND
                default:alu_op_reg = 5'b00000;
            endcase
        end

        7'b0010011: begin // I型
            rf_we_reg = 1'b1;
            src1_sel_reg = 1'b1;
            imm_reg = {{20{inst[31]}},inst[31:20]};
            case(func3)
                3'b000: alu_op_reg=5'b00000;    // ADDI
                3'b010: alu_op_reg=5'b00100;    // SLTI
                3'b011: alu_op_reg=5'b00101;    // SLTIU
                3'b100: alu_op_reg=5'b01011;    // XORI
                3'b110: alu_op_reg=5'b01010;    // ORI
                3'b111: alu_op_reg=5'b01001;    // ANDI
                3'b001: alu_op_reg=5'b01110;    // SLLI
                3'b101: alu_op_reg=(func7==7'b0000000) ? 5'b01111 : 5'b10000;   // SRLI or SRAI
                default:alu_op_reg = 5'b00000;
            endcase
        end

        7'b0110111: begin // LUI
            rf_we_reg=1'b1;
            src1_sel_reg=1'b1;
            imm_reg={inst[31:12],12'b0};
            alu_op_reg = 5'b10010; // SRC1
        end

        7'b0010111: begin // AUIPC
            rf_we_reg=1'b1;
            src0_sel_reg=1'b1;
            src1_sel_reg=1'b1;
            imm_reg={inst[31:12],12'b0};
        end

        7'b0000011: begin // LOAD
            rf_we_reg = 1'b1;
            src1_sel_reg = 1'b1;
            rf_wd_sel_reg = 2'b01;
            imm_reg = {{20{inst[31]}},inst[31:20]};
            case(func3)
                3'b000: dmem_access_reg = 4'b0000;  // LB
                3'b001: dmem_access_reg = 4'b0001;  // LH
                3'b010: dmem_access_reg = 4'b0010;  // LW
                3'b100: dmem_access_reg = 4'b0100;  // LBU
                3'b101: dmem_access_reg = 4'b0101;  // LHU
                default:dmem_access_reg = 4'b0000;
            endcase
        end

        7'b0100011: begin // STORE
            src1_sel_reg = 1'b1;
            imm_reg = {{20{inst[31]}},inst[31:25],inst[11:7]};
            case(func3)
                3'b000: dmem_access_reg = 4'b1000;  // SB
                3'b001: dmem_access_reg = 4'b1001;  // SH
                3'b010: dmem_access_reg = 4'b1010;  // SW
                default:dmem_access_reg = 4'b0000;
            endcase
        end

        7'b1100011: begin // BRANCH
            imm_reg = {{19{inst[31]}},inst[31],inst[7],inst[30:25],inst[11:8],1'b0};
            case(func3)
                3'b000: br_type_reg = 4'b0001;  // BEQ
                3'b001: br_type_reg = 4'b0010;  // BNE
                3'b100: br_type_reg = 4'b0011;  // BLT
                3'b101: br_type_reg = 4'b0100;  // BGE
                3'b110: br_type_reg = 4'b0101;  // BLTU
                3'b111: br_type_reg = 4'b0110;  // BGEU
                default:br_type_reg = 4'b0000;
            endcase
        end

        7'b1101111: begin // JAL
            rf_we_reg = 1'b1;
            rf_wd_sel_reg = 2'b10;
            br_type_reg = 4'b0111;
            imm_reg = {{11{inst[31]}},inst[31],inst[19:12],inst[20],inst[30:21],1'b0};
        end

        7'b1100111: begin // JALR
            rf_we_reg = 1'b1;
            src1_sel_reg = 1'b1;
            rf_wd_sel_reg = 2'b10;
            br_type_reg = 4'b1000;
            imm_reg = {{20{inst[31]}},inst[31:20]};
        end
        default:;
    endcase
end

assign alu_op       = alu_op_reg;
assign imm          = imm_reg;
assign dmem_access  = dmem_access_reg;
assign rf_we        = rf_we_reg;
assign rf_wd_sel    = rf_wd_sel_reg;
assign alu_src0_sel = src0_sel_reg;
assign alu_src1_sel = src1_sel_reg;
assign br_type      = br_type_reg;

endmodule