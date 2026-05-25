module IF_ID_REG(
    input         clk,
    input         rst,
    input         en,
    input         flush,      // 分支冲刷
    // 输入 IF 段
    input  [31:0] if_pc,
    input  [31:0] if_pc_add4,
    input  [31:0] if_inst,
    input         if_commit,  // IF 段产生 commit=1
    // 输出到 ID 段
    output reg [31:0] id_pc,
    output reg [31:0] id_pc_add4,
    output reg [31:0] id_inst,
    output reg       id_commit
);
    always @(posedge clk) begin
        if(rst) begin
            id_pc       <= 32'b0;
            id_pc_add4  <= 32'b0;
            id_inst     <= 32'b0;
            id_commit   <= 1'b0;
        end
        else if(en) begin
            if(flush) begin
                // 冲刷：置为 NOP，清空 commit 和所有控制
                id_pc       <= if_pc;
                id_pc_add4  <= if_pc_add4;
                id_inst     <= 32'b0;
                id_commit   <= 1'b0;
            end
            else begin
                id_pc       <= if_pc;
                id_pc_add4  <= if_pc_add4;
                id_inst     <= if_inst;
                id_commit   <= if_commit;
            end
        end
    end
endmodule


module ID_EX_REG(
    input         clk,rst,en,flush,
    // ID 输入
    input [31:0] id_pc,id_pc_add4,id_inst,
    input [31:0] id_rf_rd0,id_rf_rd1,id_imm,
    input [4:0]  id_alu_op,id_rf_wa,id_rs1,id_rs2,
    input        id_rf_we,id_alu_src0_sel,id_alu_src1_sel,id_dmem_we,
    input [1:0]  id_rf_wd_sel,
    input [3:0]  id_dmem_access,id_br_type,
    input        id_commit,

    // EX 输出
    output reg [31:0] ex_pc,ex_pc_add4,ex_inst,
    output reg [31:0] ex_rf_rd0,ex_rf_rd1,ex_imm,
    output reg [4:0]  ex_alu_op,ex_rf_wa,ex_rs1,ex_rs2,
    output reg        ex_rf_we,ex_alu_src0_sel,ex_alu_src1_sel,ex_dmem_we,
    output reg [1:0]  ex_rf_wd_sel,
    output reg [3:0]  ex_dmem_access,ex_br_type,
    output reg        ex_commit
);
    always @(posedge clk) begin
        if(rst) begin
            ex_pc<=0;ex_pc_add4<=0;ex_inst<=0;
            ex_rf_rd0<=0;ex_rf_rd1<=0;ex_imm<=0;
            ex_alu_op<=0;ex_rf_wa<=0;ex_rs1<=0;ex_rs2<=0;
            ex_rf_we<=0;ex_alu_src0_sel<=0;ex_alu_src1_sel<=0;ex_dmem_we<=0;
            ex_rf_wd_sel<=0;ex_dmem_access<=0;ex_br_type<=0;
            ex_commit<=0;
        end
        else if(en) begin
            if(flush) begin
                // 冲刷：清空所有控制 + commit
                ex_pc       <= id_pc;
                ex_pc_add4  <= id_pc_add4;
                ex_inst     <= 32'b0;
                ex_rf_rd0   <= 32'b0;
                ex_rf_rd1   <= 32'b0;
                ex_imm      <= 32'b0;
                ex_alu_op   <= 5'b0;
                ex_rf_wa    <= 5'b0;
                ex_rs1      <= 5'b0;
                ex_rs2      <= 5'b0;
                ex_rf_we    <= 1'b0;
                ex_alu_src0_sel <= 1'b0;
                ex_alu_src1_sel <= 1'b0;
                ex_dmem_we  <= 1'b0;
                ex_rf_wd_sel<= 2'b0;
                ex_dmem_access<=4'b0;
                ex_br_type  <=4'b0;
                ex_commit   <=1'b0;
            end
            else begin
                ex_pc       <= id_pc;
                ex_pc_add4  <= id_pc_add4;
                ex_inst     <= id_inst;
                ex_rf_rd0   <= id_rf_rd0;
                ex_rf_rd1   <= id_rf_rd1;
                ex_imm      <= id_imm;
                ex_alu_op   <= id_alu_op;
                ex_rf_wa    <= id_rf_wa;
                ex_rs1      <= id_rs1;
                ex_rs2      <= id_rs2;
                ex_rf_we    <= id_rf_we;
                ex_alu_src0_sel <= id_alu_src0_sel;
                ex_alu_src1_sel <= id_alu_src1_sel;
                ex_dmem_we  <= id_dmem_we;
                ex_rf_wd_sel<= id_rf_wd_sel;
                ex_dmem_access<=id_dmem_access;
                ex_br_type  <= id_br_type;
                ex_commit   <= id_commit;
            end
        end
    end
endmodule


module EX_MEM_REG(
    input         clk,rst,en,
    input [31:0] ex_pc,ex_pc_add4,ex_inst,ex_alu_res,ex_rf_rd1,
    input [4:0]  ex_rf_wa,
    input        ex_rf_we,ex_dmem_we,
    input [1:0]  ex_rf_wd_sel,
    input [3:0]  ex_dmem_access,
    input        ex_commit,

    output reg [31:0] mem_pc,mem_pc_add4,mem_inst,mem_alu_res,mem_rf_rd1,
    output reg [4:0]  mem_rf_wa,
    output reg        mem_rf_we,mem_dmem_we,
    output reg [1:0]  mem_rf_wd_sel,
    output reg [3:0]  mem_dmem_access,
    output reg        mem_commit
);
    always @(posedge clk) begin
        if(rst) begin
            mem_pc<=0;mem_pc_add4<=0;mem_inst<=0;mem_alu_res<=0;mem_rf_rd1<=0;
            mem_rf_wa<=0;mem_rf_we<=0;mem_dmem_we<=0;mem_rf_wd_sel<=0;mem_dmem_access<=0;
            mem_commit<=0;
        end
        else if(en) begin
            mem_pc       <= ex_pc;
            mem_pc_add4  <= ex_pc_add4;
            mem_inst     <= ex_inst;
            mem_alu_res  <= ex_alu_res;
            mem_rf_rd1   <= ex_rf_rd1;
            mem_rf_wa    <= ex_rf_wa;
            mem_rf_we    <= ex_rf_we;
            mem_dmem_we  <= ex_dmem_we;
            mem_rf_wd_sel<= ex_rf_wd_sel;
            mem_dmem_access<=ex_dmem_access;
            mem_commit   <= ex_commit;
        end
    end
endmodule


module MEM_WB_REG(
    input         clk,rst,en,
    input [31:0] mem_pc,mem_pc_add4,mem_inst,mem_alu_res,mem_dmem_rd,
    input [4:0]  mem_rf_wa,
    input        mem_rf_we,
    input [1:0]  mem_rf_wd_sel,  // 输入是2位
    input        mem_commit,

    output reg [31:0] wb_pc,wb_pc_add4,wb_inst,wb_alu_res,wb_dmem_rd,
    output reg [4:0]  wb_rf_wa,
    output reg        wb_rf_we,
    output reg [1:0]  wb_rf_wd_sel,  // 必须显式声明为2位！
    output reg        wb_commit
);
    always @(posedge clk) begin
        if(rst) begin
            wb_pc<=0;wb_pc_add4<=0;wb_inst<=0;wb_alu_res<=0;wb_dmem_rd<=0;
            wb_rf_wa<=0;wb_rf_we<=0;wb_rf_wd_sel<=2'b0; // 复位值也用2位
            wb_commit<=0;
        end
        else if(en) begin
            wb_pc       <= mem_pc;
            wb_pc_add4  <= mem_pc_add4;
            wb_inst     <= mem_inst;
            wb_alu_res  <= mem_alu_res;
            wb_dmem_rd  <= mem_dmem_rd;
            wb_rf_wa    <= mem_rf_wa;
            wb_rf_we    <= mem_rf_we;
            wb_rf_wd_sel<= mem_rf_wd_sel; // 正确传递2位信号
            wb_commit   <= mem_commit;
        end
    end
endmodule


module Hazard_Unit(
    input  [1:0] npc_sel,
    output       flush_if_id,
    output       flush_id_ex
);
    // EX 段分支跳转生效，冲刷 IF/ID、ID/EX 两级
    assign flush_if_id = (npc_sel != 2'b00);
    assign flush_id_ex = (npc_sel != 2'b00);
endmodule



module CPU (
    input           clk,
    input           rst,
    input           global_en,

    output [31:0]   imem_raddr,
    input  [31:0]   imem_rdata,

    input  [31:0]   dmem_rdata,
    output          dmem_we,
    output [31:0]   dmem_addr,
    output [31:0]   dmem_wdata,

    // 仿真框架输出端口（严格匹配）
    output          commit,
    output [31:0]   commit_pc,
    output [31:0]   commit_instr,
    output          commit_halt,
    output          commit_reg_we,
    output [ 4:0]   commit_reg_wa,
    output [31:0]   commit_reg_wd,
    output          commit_dmem_we,
    output [31:0]   commit_dmem_wa,
    output [31:0]   commit_dmem_wd,

    input  [ 4:0]   debug_reg_ra,
    output [31:0]   debug_reg_rd
);

// 显式声明2位信号，解决位宽报错
wire [1:0] wb_rf_wd_sel;
// 停机指令宏定义
`define HALT_INST 32'h00100073

//==================== IF 阶段 ====================
wire [31:0] if_pc, npc;
wire [31:0] if_pc_add4 = if_pc + 32'd4;
// 框架要求：IF段固定产生commit=1
wire        commit_if = 1'H1;    

assign imem_raddr = if_pc;

PC u_PC(
    .clk(clk), .rst(rst), .en(global_en),
    .npc(npc), .pc(if_pc)
);

//==================== IF/ID 寄存器 ====================
wire flush_if_id, flush_id_ex;
wire [31:0] id_pc, id_pc_add4, id_inst;
wire        id_commit;

IF_ID_REG u_IF_ID(
    .clk(clk), .rst(rst), .en(global_en), .flush(flush_if_id),
    .if_pc(if_pc), .if_pc_add4(if_pc_add4), .if_inst(imem_rdata),
    .if_commit(commit_if),  // 流入commit信号
    .id_pc(id_pc), .id_pc_add4(id_pc_add4), .id_inst(id_inst),
    .id_commit(id_commit)
);

//==================== ID 阶段 ====================
wire [4:0]  alu_op, rf_ra0, rf_ra1, rf_wa;
wire [31:0] imm;
wire        rf_we, alu_src0_sel, alu_src1_sel, dmem_we_dec;
wire [1:0]  rf_wd_sel;
wire [3:0]  dmem_access, br_type;

DECODER u_DEC(
    .inst(id_inst),
    .alu_op(alu_op), .dmem_access(dmem_access), .imm(imm),
    .rf_ra0(rf_ra0), .rf_ra1(rf_ra1), .rf_wa(rf_wa),
    .rf_we(rf_we), .rf_wd_sel(rf_wd_sel),
    .alu_src0_sel(alu_src0_sel), .alu_src1_sel(alu_src1_sel),
    .br_type(br_type), .dmem_we(dmem_we_dec)
);

wire [31:0] rf_rd0, rf_rd1;
wire [31:0] wb_rf_wd;
wire        wb_rf_we;
wire [4:0]  wb_rf_wa;

REG_FILE u_RF(
    .clk(clk),
    .rf_ra0(rf_ra0), .rf_ra1(rf_ra1),
    .rf_wa(wb_rf_wa), .rf_we(wb_rf_we), .rf_wd(wb_rf_wd),
    .rf_rd0(rf_rd0), .rf_rd1(rf_rd1),
    .debug_reg_ra(debug_reg_ra), .debug_reg_rd(debug_reg_rd)
);

//==================== ID/EX 寄存器 ====================
wire [31:0] ex_pc, ex_pc_add4, ex_inst;
wire [31:0] ex_rf_rd0, ex_rf_rd1, ex_imm;
wire [4:0]  ex_alu_op, ex_rf_wa, ex_rs1, ex_rs2;
wire        ex_rf_we, ex_alu_src0_sel, ex_alu_src1_sel, ex_dmem_we;
wire [1:0]  ex_rf_wd_sel;
wire [3:0]  ex_dmem_access, ex_br_type;
wire        ex_commit;

ID_EX_REG u_ID_EX(
    .clk(clk), .rst(rst), .en(global_en), .flush(flush_id_ex),
    .id_pc(id_pc), .id_pc_add4(id_pc_add4), .id_inst(id_inst),
    .id_rf_rd0(rf_rd0), .id_rf_rd1(rf_rd1), .id_imm(imm),
    .id_alu_op(alu_op), .id_rf_wa(rf_wa), .id_rs1(rf_ra0), .id_rs2(rf_ra1),
    .id_rf_we(rf_we), .id_alu_src0_sel(alu_src0_sel), .id_alu_src1_sel(alu_src1_sel), .id_dmem_we(dmem_we_dec),
    .id_rf_wd_sel(rf_wd_sel), .id_dmem_access(dmem_access), .id_br_type(br_type),
    .id_commit(id_commit),

    .ex_pc(ex_pc), .ex_pc_add4(ex_pc_add4), .ex_inst(ex_inst),
    .ex_rf_rd0(ex_rf_rd0), .ex_rf_rd1(ex_rf_rd1), .ex_imm(ex_imm),
    .ex_alu_op(ex_alu_op), .ex_rf_wa(ex_rf_wa), .ex_rs1(ex_rs1), .ex_rs2(ex_rs2),
    .ex_rf_we(ex_rf_we), .ex_alu_src0_sel(ex_alu_src0_sel), .ex_alu_src1_sel(ex_alu_src1_sel), .ex_dmem_we(ex_dmem_we),
    .ex_rf_wd_sel(ex_rf_wd_sel), .ex_dmem_access(ex_dmem_access), .ex_br_type(ex_br_type),
    .ex_commit(ex_commit)
);

//==================== EX 阶段 ====================
wire [1:0] npc_sel;
BRANCH u_BRANCH(
    .br_type(ex_br_type),
    .br_src0(ex_rf_rd0),
    .br_src1(ex_rf_rd1),
    .npc_sel(npc_sel)
);

Hazard_Unit u_HAZARD(
    .npc_sel(npc_sel),
    .flush_if_id(flush_if_id),
    .flush_id_ex(flush_id_ex)
);

wire [31:0] alu_src0, alu_src1;
MUX1 #(32) mux_src0(.src0(ex_rf_rd0), .src1(ex_pc), .sel(ex_alu_src0_sel), .res(alu_src0));
MUX1 #(32) mux_src1(.src0(ex_rf_rd1), .src1(ex_imm), .sel(ex_alu_src1_sel), .res(alu_src1));

wire [31:0] ex_alu_res;
ALU u_ALU(
    .alu_src0(alu_src0),
    .alu_src1(alu_src1),
    .alu_op(ex_alu_op),
    .alu_res(ex_alu_res)
);

wire [31:0] pc_offset = ex_pc + ex_imm;
wire [31:0] pc_j      = {ex_alu_res[31:1],1'b0};

NPC_MUX u_NPC_MUX(
    .npc_sel(npc_sel),
    .pc_add4(if_pc_add4),
    .pc_offset(pc_offset),
    .pc_j(pc_j),
    .npc(npc)
);

//==================== EX/MEM 寄存器 ====================
wire [31:0] mem_pc, mem_pc_add4, mem_inst, mem_alu_res, mem_rf_rd1;
wire [4:0]  mem_rf_wa;
wire        mem_rf_we, mem_dmem_we;
wire [1:0]  mem_rf_wd_sel;
wire [3:0]  mem_dmem_access;
wire        mem_commit;

EX_MEM_REG u_EX_MEM(
    .clk(clk), .rst(rst), .en(global_en),
    .ex_pc(ex_pc), .ex_pc_add4(ex_pc_add4), .ex_inst(ex_inst),
    .ex_alu_res(ex_alu_res), .ex_rf_rd1(ex_rf_rd1),
    .ex_rf_wa(ex_rf_wa), .ex_rf_we(ex_rf_we), .ex_dmem_we(ex_dmem_we),
    .ex_rf_wd_sel(ex_rf_wd_sel), .ex_dmem_access(ex_dmem_access),
    .ex_commit(ex_commit),

    .mem_pc(mem_pc), .mem_pc_add4(mem_pc_add4), .mem_inst(mem_inst),
    .mem_alu_res(mem_alu_res), .mem_rf_rd1(mem_rf_rd1),
    .mem_rf_wa(mem_rf_wa), .mem_rf_we(mem_rf_we), .mem_dmem_we(mem_dmem_we),
    .mem_rf_wd_sel(mem_rf_wd_sel), .mem_dmem_access(mem_dmem_access),
    .mem_commit(mem_commit)
);

//==================== MEM 阶段 ====================
wire [31:0] slu_rd_out, slu_wd_out;
SLU u_SLU(
    .addr(mem_alu_res),
    .dmem_access(mem_dmem_access),
    .rd_in(dmem_rdata),
    .wd_in(mem_rf_rd1),
    .rd_out(slu_rd_out),
    .wd_out(slu_wd_out)
);

assign dmem_we    = mem_dmem_we;
assign dmem_addr  = mem_alu_res;
assign dmem_wdata = slu_wd_out;

//==================== MEM/WB 寄存器 ====================
// 对应框架信号：pc_wb, inst_wb, commit_wb, rf_we_wb, rf_wa_wb, rf_wd_wb
wire [31:0] pc_wb, pc_add4_wb, inst_wb, alu_res_wb, dmem_rd_wb;
wire        commit_wb;

MEM_WB_REG u_MEM_WB(
    .clk(clk), .rst(rst), .en(global_en),
    .mem_pc(mem_pc), .mem_pc_add4(mem_pc_add4), .mem_inst(mem_inst),
    .mem_alu_res(mem_alu_res), .mem_dmem_rd(slu_rd_out),
    .mem_rf_wa(mem_rf_wa), .mem_rf_we(mem_rf_we), .mem_rf_wd_sel(mem_rf_wd_sel),
    .mem_commit(mem_commit),

    .wb_pc(pc_wb),          // 重命名为框架要求的 pc_wb
    .wb_pc_add4(pc_add4_wb),
    .wb_inst(inst_wb),      // 重命名为框架要求的 inst_wb
    .wb_alu_res(alu_res_wb),
    .wb_dmem_rd(dmem_rd_wb),
    .wb_rf_wa(wb_rf_wa),
    .wb_rf_we(wb_rf_we),
    .wb_rf_wd_sel(wb_rf_wd_sel),
    .wb_commit(commit_wb)   // 重命名为框架要求的 commit_wb
);

//==================== WB 阶段 写回选择 ====================
MUX2 #(32) rf_wd_mux(
    .src0(alu_res_wb),
    .src1(dmem_rd_wb),
    .src2(pc_add4_wb),
    .src3(32'b0),
    .sel(wb_rf_wd_sel),
    .res(wb_rf_wd)
);

// ====================== ✅ 仿真框架标准 Commit 时序寄存器（你提供的代码，完全适配） ======================
reg         commit_reg;
reg [31:0]  commit_pc_reg;
reg [31:0]  commit_instr_reg;
reg         commit_halt_reg;
reg         commit_reg_we_reg;
reg [4:0]   commit_reg_wa_reg;
reg [31:0]  commit_reg_wd_reg;
reg         commit_dmem_we_reg;
reg [31:0]  commit_dmem_wa_reg;
reg [31:0]  commit_dmem_wd_reg;

always @(posedge clk) begin
    if (rst) begin
        commit_reg          <= 1'H0;
        commit_pc_reg       <= 32'H0;
        commit_instr_reg     <= 32'H0;
        commit_halt_reg     <= 1'H0;
        commit_reg_we_reg   <= 1'H0;
        commit_reg_wa_reg   <= 5'H0;
        commit_reg_wd_reg   <= 32'H0;
        commit_dmem_we_reg  <= 1'H0;
        commit_dmem_wa_reg  <= 32'H0;
        commit_dmem_wd_reg  <= 32'H0;
    end
    else if (global_en) begin
        // 严格对接 MEM/WB 输出信号
        commit_reg          <= commit_wb;
        commit_pc_reg       <= pc_wb;
        commit_instr_reg     <= inst_wb;
        commit_halt_reg     <= inst_wb == 32'h00100073;
        commit_reg_we_reg   <= wb_rf_we;
        commit_reg_wa_reg   <= wb_rf_wa;
        commit_reg_wd_reg   <= wb_rf_wd;
        commit_dmem_we_reg  <= mem_dmem_we;
        commit_dmem_wa_reg  <= mem_alu_res;
        commit_dmem_wd_reg  <= slu_wd_out;
    end
end

// 最终输出到仿真框架
assign commit               = commit_reg;
assign commit_pc            = commit_pc_reg;
assign commit_instr          = commit_instr_reg;
assign commit_halt          = commit_halt_reg;
assign commit_reg_we        = commit_reg_we_reg;
assign commit_reg_wa        = commit_reg_wa_reg;
assign commit_reg_wd        = commit_reg_wd_reg;
assign commit_dmem_we       = commit_dmem_we_reg;
assign commit_dmem_wa       = commit_dmem_wa_reg;
assign commit_dmem_wd       = commit_dmem_wd_reg;

endmodule
