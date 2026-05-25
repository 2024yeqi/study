module CPU (
    // 时钟与复位（框架要求）
    input           clk,
    input           rst,
    input           global_en,

    // 指令存储器接口（框架要求）
    output [31:0]   imem_raddr,         // 原 inst_addr
    input  [31:0]   imem_rdata,         // 原 inst

    input  [31:0]   dmem_rdata,
    output          dmem_we,
    output [31:0]   dmem_addr,
    output [31:0]   dmem_wdata,

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

    // Debug 接口
    input  [ 4:0]   debug_reg_ra,
    output [31:0]   debug_reg_rd
);

    wire [31:0] inst = imem_rdata;              // 指令输入

    // ========== 数据存储器接口（固定为0） ==========
    assign dmem_we   = 1'b0;
    assign dmem_addr = 32'b0;
    assign dmem_wdata = 32'b0;

    // pc
    wire [31:0] pc, npc;
    assign npc = pc + 32'h4;
    assign imem_raddr = pc; // 输出指令地址到框架

    PC pc_inst (
        .clk (clk),
        .rst (rst),
        .en  (global_en),
        .npc (npc),
        .pc  (pc)
    );

    // 译码器例化
    wire [ 4:0] rf_ra0, rf_ra1, rf_wa;
    wire        rf_we;
    wire [ 4:0] alu_op;
    wire [31:0] imm;
    wire        alu_src0_sel;
    wire        alu_src1_sel;

    DECODER decoder (
        .inst         (inst),
        .rf_ra0       (rf_ra0),
        .rf_ra1       (rf_ra1),
        .rf_wa        (rf_wa),
        .rf_we        (rf_we),
        .alu_op       (alu_op),
        .imm          (imm),
        .alu_src0_sel (alu_src0_sel),
        .alu_src1_sel (alu_src1_sel)
    );

    // 寄存器堆例化
    wire [31:0] rf_rd0, rf_rd1;
    wire [31:0] rf_wd;
    assign rf_wd = alu_res;      // ALU 结果写回

    REG_FILE reg_file (
        .clk          (clk),
        .rf_ra0       (rf_ra0),
        .rf_ra1       (rf_ra1),
        .rf_wa        (rf_wa),
        .rf_we        (rf_we),
        .rf_wd        (rf_wd),
        .rf_rd0       (rf_rd0),
        .rf_rd1       (rf_rd1),
        .debug_reg_ra (debug_reg_ra),
        .debug_reg_rd (debug_reg_rd)
    );

    //ALU 源选择
    wire [31:0] alu_src0, alu_src1;

    MUX1 #(32) mux_alu_src0 (
        .src0 (rf_rd0),
        .src1 (pc),
        .sel  (alu_src0_sel),
        .res  (alu_src0)
    );

    MUX1 #(32) mux_alu_src1 (
        .src0 (rf_rd1),
        .src1 (imm),
        .sel  (alu_src1_sel),
        .res  (alu_src1)
    );

    // ALU 例化
    wire [31:0] alu_res;
    ALU alu (
        .alu_src0 (alu_src0),
        .alu_src1 (alu_src1),
        .alu_op   (alu_op),
        .alu_res  (alu_res)
    );

    // ========== Commit 信号生成 ==========
    // 单周期 CPU：每条指令执行后下一周期提交
    
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
            commit_halt_reg     <= inst == 32'H00100073;    // 注意！请根据指令集设置 HALT_INST！
            commit_reg_we_reg   <= rf_we;                       // 需要为当前的寄存器堆写使能
            commit_reg_wa_reg   <= rf_wa;                       // 需要为当前的寄存器堆写地址
            commit_reg_wd_reg   <= rf_wd;                       // 需要为当前的寄存器堆写数据
            commit_dmem_we_reg  <= 0;                           // 不需要改动
            commit_dmem_wa_reg  <= 0;                           // 不需要改动
            commit_dmem_wd_reg  <= 0;                           // 不需要改动
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