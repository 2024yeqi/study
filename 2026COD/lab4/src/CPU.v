module CPU (
    input               clk,
    input               rst,
    input               global_en,

    output      [31:0]  imem_raddr,
    input       [31:0]  imem_rdata,

    input       [31:0]  dmem_rdata,
    output              dmem_we,
    output      [31:0]  dmem_addr,
    output      [31:0]  dmem_wdata,

    output              commit,
    output      [31:0]  commit_pc,
    output      [31:0]  commit_instr,
    output              commit_halt,
    output              commit_reg_we,
    output      [4:0]   commit_reg_wa,
    output      [31:0]  commit_reg_wd,
    output              commit_dmem_we,
    output      [31:0]  commit_dmem_wa,
    output      [31:0]  commit_dmem_wd,

    input       [4:0]   debug_reg_ra,
    output      [31:0]  debug_reg_rd
);

wire [31:0] pc;
wire [31:0] pc_add4 = pc + 32'd4;
wire [31:0] inst = imem_rdata;
assign imem_raddr = pc;

wire [4:0]  alu_op;
wire [3:0]  dmem_access;
wire [31:0] imm;
wire        rf_we;
wire [1:0]  rf_wd_sel;

wire [4:0]  rf_ra0;
wire [4:0]  rf_ra1;
wire [4:0]  rf_wa;
wire        alu_src0_sel;
wire        alu_src1_sel;

wire [3:0]  br_type;

wire [31:0] rf_rd0;
wire [31:0] rf_rd1;
wire [31:0] alu_src0;
wire [31:0] alu_src1;
wire [31:0] alu_res;

wire [1:0]  npc_sel;

BRANCH branch(
    .br_type    (br_type),
    .br_src0    (rf_rd0),
    .br_src1    (rf_rd1),
    .npc_sel    (npc_sel)
);

wire [31:0] pc_offset = pc + imm;
wire [31:0] pc_j      = {alu_res[31:1], 1'b0};
wire [31:0] npc;

NPC_MUX npcmux (
    .npc_sel    (npc_sel),
    .pc_add4    (pc_add4),
    .pc_offset  (pc_offset),
    .pc_j       (pc_j),
    .npc        (npc)
);

PC pc0 (
    .clk    (clk),
    .rst    (rst),
    .en     (global_en),
    .npc    (npc),
    .pc     (pc)
);

DECODER decoder (
    .inst          (inst),
    .alu_op        (alu_op),
    .dmem_access   (dmem_access),
    .imm           (imm),
    .rf_ra0        (rf_ra0),
    .rf_ra1        (rf_ra1),
    .rf_wa         (rf_wa),
    .rf_we         (rf_we),
    .rf_wd_sel     (rf_wd_sel),
    .alu_src0_sel  (alu_src0_sel),
    .alu_src1_sel  (alu_src1_sel),
    .br_type       (br_type)
);

REG_FILE regfile (
    .clk           (clk),
    .rf_ra0        (rf_ra0),
    .rf_ra1        (rf_ra1),
    .rf_wa         (rf_wa),
    .rf_we         (rf_we),
    .rf_wd         (rf_wd),
    .rf_rd0        (rf_rd0),
    .rf_rd1        (rf_rd1),
    .debug_reg_ra  (debug_reg_ra),
    .debug_reg_rd  (debug_reg_rd)
);

MUX1 #(32) mux_src0 (
    .src0   (rf_rd0),
    .src1   (pc),
    .sel    (alu_src0_sel),
    .res    (alu_src0)
);

MUX1 #(32) mux_src1 (
    .src0   (rf_rd1),
    .src1   (imm),
    .sel    (alu_src1_sel),
    .res    (alu_src1)
);

ALU alu (
    .alu_src0  (alu_src0),
    .alu_src1  (alu_src1),
    .alu_op    (alu_op),
    .alu_res   (alu_res)
);

wire [31:0] slu_rd_out;
wire [31:0] slu_wd_out;
SLU slu (
    .addr        (alu_res),
    .dmem_access (dmem_access),
    .rd_in       (dmem_rdata),
    .wd_in       (rf_rd1),
    .rd_out      (slu_rd_out),
    .wd_out      (slu_wd_out)
);

assign dmem_addr   = alu_res;
assign dmem_wdata  = slu_wd_out;
assign dmem_we     = (dmem_access[3] == 1'b1) && global_en;

wire [31:0] rf_wd;
MUX2 #(32) wd_mux (
    .src0 (alu_res),
    .src1 (slu_rd_out),
    .src2 (pc_add4),
    .src3 (32'd0),
    .sel  (rf_wd_sel),
    .res  (rf_wd)
);

reg  [ 0 : 0]   commit_reg          ;
reg  [31 : 0]   commit_pc_reg       ;
reg  [31 : 0]   commit_instr_reg    ;
reg  [ 0 : 0]   commit_halt_reg     ;
reg  [ 0 : 0]   commit_reg_we_reg   ;
reg  [ 4 : 0]   commit_reg_wa_reg   ;
reg  [31 : 0]   commit_reg_wd_reg   ;
reg  [ 0 : 0]   commit_dmem_we_reg  ;
reg  [31 : 0]   commit_dmem_wa_reg  ;
reg  [31 : 0]   commit_dmem_wd_reg  ;

always @(posedge clk) begin
    if (rst) begin
        commit_reg          <= 1'H0;
        commit_pc_reg       <= 32'H0;
        commit_instr_reg    <= 32'H0;
        commit_halt_reg     <= 1'H0;
        commit_reg_we_reg   <= 1'H0;
        commit_reg_wa_reg   <= 5'H0;
        commit_reg_wd_reg   <= 32'H0;
        commit_dmem_we_reg  <= 1'H0;
        commit_dmem_wa_reg  <= 32'H0;
        commit_dmem_wd_reg  <= 32'H0;
    end
    else if (global_en) begin
        // !!!! 请注意根据自己的具体实现替换 <= 右侧的信号 !!!!
        commit_reg          <= 1'H1;                        // 不需要改动
        commit_pc_reg       <= pc;                      // 需要为当前的 PC
        commit_instr_reg    <= inst;                    // 需要为当前的指令
        commit_halt_reg     <= inst == 32'h00100073;      // 注意！请根据指令集设置 HALT_INST！
        commit_reg_we_reg   <= rf_we;                       // 需要为当前的寄存器堆写使能
        commit_reg_wa_reg   <= rf_wa;                       // 需要为当前的寄存器堆写地址
        commit_reg_wd_reg   <= rf_wd;                       // 需要为当前的寄存器堆写数据
        commit_dmem_we_reg   <= dmem_we;
        commit_dmem_wa_reg   <= dmem_addr;
        commit_dmem_wd_reg   <= dmem_wdata;
    end
end

assign commit               = commit_reg;
assign commit_pc            = commit_pc_reg;
assign commit_instr         = commit_instr_reg;
assign commit_halt          = commit_halt_reg;
assign commit_reg_we        = commit_reg_we_reg;
assign commit_reg_wa        = commit_reg_wa_reg;
assign commit_reg_wd        = commit_reg_wd_reg;
assign commit_dmem_we       = commit_dmem_we_reg;
assign commit_dmem_wa       = commit_dmem_wa_reg;
assign commit_dmem_wd       = commit_dmem_wd_reg;

endmodule