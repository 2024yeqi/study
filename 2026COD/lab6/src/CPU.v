module IF_ID_REG(
    input clk,rst,en,stall,flush,
    input [31:0] if_pc,if_pcadd4,if_inst,
    input commit_instr_if,
    output reg [31:0] id_pc,id_pcadd4,id_inst,
    output reg commit_instr_id,
    output reg [4:0] id_rs1,id_rs2
);
    always @(posedge clk) begin
        if(rst) begin
            id_pc<=0;id_pcadd4<=0;id_inst<=0;
            commit_instr_id<=0;
            id_rs1<=0;id_rs2<=0;
        end else if(en) begin
            if(flush) begin
                id_pc<=if_pc;id_pcadd4<=if_pcadd4;
                id_inst<=0;commit_instr_id<=0;
                id_rs1<=0;id_rs2<=0;
            end else if(!stall) begin
                id_pc<=if_pc;id_pcadd4<=if_pcadd4;id_inst<=if_inst;
                commit_instr_id<=commit_instr_if;
                id_rs1<=if_inst[19:15];id_rs2<=if_inst[24:20];
            end
        end
    end
endmodule

module ID_EX_REG(
    input clk,rst,en,stall,flush,
    input [31:0] id_pc,id_pcadd4,id_inst,
    input [31:0] id_rf_rd0,id_rf_rd1,id_imm,
    input [4:0] id_alu_op,id_rf_wa,id_rs1,id_rs2,
    input id_rf_we,id_alu_src0_sel,id_alu_src1_sel,id_dmem_we,
    input [1:0] id_rf_wd_sel,
    input [3:0] id_dmem_access,id_br_type,
    input commit_instr_id,
    output reg [31:0] ex_pc,ex_pcadd4,ex_inst,
    output reg [31:0] ex_rf_rd0,ex_rf_rd1,ex_imm,
    output reg [4:0] ex_alu_op,ex_rf_wa,ex_rs1,ex_rs2,
    output reg ex_rf_we,ex_alu_src0_sel,ex_alu_src1_sel,ex_dmem_we,
    output reg [1:0] ex_rf_wd_sel,
    output reg [3:0] ex_dmem_access,ex_br_type,
    output reg commit_instr_ex
);
    always @(posedge clk) begin
        if(rst) begin
            ex_pc<=0;ex_pcadd4<=0;ex_inst<=0;
            ex_rf_rd0<=0;ex_rf_rd1<=0;ex_imm<=0;
            ex_alu_op<=0;ex_rf_wa<=0;ex_rs1<=0;ex_rs2<=0;
            ex_rf_we<=0;ex_alu_src0_sel<=0;ex_alu_src1_sel<=0;ex_dmem_we<=0;
            ex_rf_wd_sel<=0;ex_dmem_access<=0;ex_br_type<=0;
            commit_instr_ex<=0;
        end else if(en) begin
            if(flush) begin
                ex_pc<=id_pc;ex_pcadd4<=id_pcadd4;
                ex_inst<=0;ex_rf_rd0<=0;ex_rf_rd1<=0;ex_imm<=0;
                ex_alu_op<=0;ex_rf_wa<=0;ex_rs1<=0;ex_rs2<=0;
                ex_rf_we<=0;ex_alu_src0_sel<=0;ex_alu_src1_sel<=0;ex_dmem_we<=0;
                ex_rf_wd_sel<=0;ex_dmem_access<=0;ex_br_type<=0;
                commit_instr_ex<=0;
            end else if(!stall) begin
                ex_pc<=id_pc;ex_pcadd4<=id_pcadd4;ex_inst<=id_inst;
                ex_rf_rd0<=id_rf_rd0;ex_rf_rd1<=id_rf_rd1;ex_imm<=id_imm;
                ex_alu_op<=id_alu_op;ex_rf_wa<=id_rf_wa;ex_rs1<=id_rs1;ex_rs2<=id_rs2;
                ex_rf_we<=id_rf_we;ex_alu_src0_sel<=id_alu_src0_sel;ex_alu_src1_sel<=id_alu_src1_sel;ex_dmem_we<=id_dmem_we;
                ex_rf_wd_sel<=id_rf_wd_sel;ex_dmem_access<=id_dmem_access;ex_br_type<=id_br_type;
                commit_instr_ex<=commit_instr_id;
            end
        end
    end
endmodule

module EX_MEM_REG(
    input clk,rst,en,stall,
    input [31:0] ex_pc,ex_pcadd4,ex_inst,ex_alu_res,ex_rf_rd1,
    input [4:0] ex_rf_wa,
    input ex_rf_we,ex_dmem_we,
    input [1:0] ex_rf_wd_sel,
    input [3:0] ex_dmem_access,
    input commit_instr_ex,
    output reg [31:0] mem_pc,mem_pcadd4,mem_inst,mem_alu_res,mem_rf_rd1,
    output reg [4:0] mem_rf_wa,
    output reg mem_rf_we,mem_dmem_we,
    output reg [1:0] mem_rf_wd_sel,
    output reg [3:0] mem_dmem_access,
    output reg commit_instr_mem
);
    always @(posedge clk) begin
        if(rst) begin
            mem_pc<=0;mem_pcadd4<=0;mem_inst<=0;mem_alu_res<=0;mem_rf_rd1<=0;
            mem_rf_wa<=0;mem_rf_we<=0;mem_dmem_we<=0;mem_rf_wd_sel<=0;mem_dmem_access<=0;
            commit_instr_mem<=0;
        end else if(en&&!stall) begin
            mem_pc<=ex_pc;mem_pcadd4<=ex_pcadd4;mem_inst<=ex_inst;
            mem_alu_res<=ex_alu_res;mem_rf_rd1<=ex_rf_rd1;
            mem_rf_wa<=ex_rf_wa;mem_rf_we<=ex_rf_we;mem_dmem_we<=ex_dmem_we;
            mem_rf_wd_sel<=ex_rf_wd_sel;mem_dmem_access<=ex_dmem_access;
            commit_instr_mem<=commit_instr_ex;
        end
    end
endmodule


module MEM_WB_REG(
    input clk,rst,en,stall,
    input [31:0] mem_pc,mem_pcadd4,mem_inst,mem_alu_res,mem_dmem_rd,
    input [4:0] mem_rf_wa,
    input mem_rf_we,
    input [1:0] mem_rf_wd_sel,
    input commit_instr_mem,
    input mem_dmem_we_pipe,
    input [31:0] mem_dmem_addr,mem_dmem_wd,
    output reg [31:0] wb_pc,wb_pcadd4,wb_inst,wb_alu_res,wb_dmem_rd,
    output reg [4:0] wb_rf_wa,
    output reg wb_rf_we,
    output reg [1:0] wb_rf_wd_sel,
    output reg commit_instr_wb,
    output reg wb_dmem_we,
    output reg [31:0] wb_dmem_addr,wb_dmem_wd
);
    always @(posedge clk) begin
        if(rst) begin
            wb_pc<=0;wb_pcadd4<=0;wb_inst<=0;wb_alu_res<=0;wb_dmem_rd<=0;
            wb_rf_wa<=0;wb_rf_we<=0;wb_rf_wd_sel<=0;
            commit_instr_wb<=0;
            wb_dmem_we<=0;wb_dmem_addr<=0;wb_dmem_wd<=0;
        end else if(en&&!stall) begin
            wb_pc<=mem_pc;wb_pcadd4<=mem_pcadd4;wb_inst<=mem_inst;
            wb_alu_res<=mem_alu_res;wb_dmem_rd<=mem_dmem_rd;
            wb_rf_wa<=mem_rf_wa;wb_rf_we<=mem_rf_we;wb_rf_wd_sel<=mem_rf_wd_sel;
            commit_instr_wb<=commit_instr_mem;
            wb_dmem_we<=mem_dmem_we_pipe;wb_dmem_addr<=mem_dmem_addr;wb_dmem_wd<=mem_dmem_wd;
        end
    end
endmodule

module Forward(
    input mem_rf_we,
    input [4:0] mem_wa,
    input [31:0] mem_wd,
    input wb_rf_we,
    input [4:0] wb_wa,
    input [31:0] wb_wd,
    input [4:0] ex_rs1,ex_rs2,
    // 输出：00=reg,01=MEM,10=WB
    output [1:0] fw_a,fw_b,
    output [31:0] fw_data_a,fw_data_b
);
    // MEM 优先级高于 WB（MEM 的数据更新），且排除 x0
    assign fw_a=(mem_rf_we&&mem_wa!=0&&mem_wa==ex_rs1)?2'b01:
                (wb_rf_we&&wb_wa!=0&&wb_wa==ex_rs1)?2'b10:2'b00;
    assign fw_b=(mem_rf_we&&mem_wa!=0&&mem_wa==ex_rs2)?2'b01:
                (wb_rf_we&&wb_wa!=0&&wb_wa==ex_rs2)?2'b10:2'b00;
    assign fw_data_a=(fw_a==2'b01)?mem_wd:wb_wd;
    assign fw_data_b=(fw_b==2'b01)?mem_wd:wb_wd;
endmodule

module SegCtrl(
    // Load‑Use：EX是load，ID读相同
    input ex_rf_we,
    input [1:0] ex_wd_sel,
    input [4:0] ex_wa,
    input [4:0] id_rs1,id_rs2,
    // 分支
    input [1:0] npc_sel,
    // 输出
    output stall_pc,stall_if_id,
    output flush_if_id,flush_id_ex
);
    // Load‑Use：ex是load（wd_sel=1），且id_rs1/2==ex_wa≠0
    wire load_use=ex_rf_we&&(ex_wd_sel==2'b01)&&(ex_wa!=0)&&
                  ((id_rs1==ex_wa)||(id_rs2==ex_wa));
    // 分支跳转：npc_sel≠0
    wire branch= (npc_sel!=2'b00);

    assign stall_pc=load_use;
    assign stall_if_id=load_use;
    assign flush_if_id=branch;
    assign flush_id_ex=branch||load_use;
endmodule

module CPU(
    input clk,rst,global_en,
    output [31:0] imem_raddr,
    input [31:0] imem_rdata,
    input [31:0] dmem_rdata,
    output dmem_we,
    output [31:0] dmem_addr,dmem_wdata,
    output commit,
    output [31:0] commit_pc,commit_instr,
    output commit_halt,
    output commit_reg_we,
    output [4:0] commit_reg_wa,
    output [31:0] commit_reg_wd,
    output commit_dmem_we,
    output [31:0] commit_dmem_wa,commit_dmem_wd,
    input [4:0] debug_reg_ra,
    output [31:0] debug_reg_rd
);
    // IF
    wire [31:0] if_pc,if_pcadd4,if_inst,if_npc;
    wire commit_instr_if=1'b1;
    wire stall_pc,flush_pc;
    assign imem_raddr=if_pc;
    assign if_pcadd4=if_pc+4;
    assign if_inst=imem_rdata;
    PC u_pc(
        .clk(clk),.rst(rst),.en(global_en),
        .stall(stall_pc),.flush(flush_pc),
        .npc(if_npc),.pc(if_pc)
    );

    // IF/ID
    wire stall_if_id,flush_if_id;
    wire [31:0] id_pc,id_pcadd4,id_inst;
    wire commit_instr_id;
    wire [4:0] id_rs1,id_rs2;
    IF_ID_REG u_ifid(
        .clk(clk),.rst(rst),.en(global_en),
        .stall(stall_if_id),.flush(flush_if_id),
        .if_pc(if_pc),.if_pcadd4(if_pcadd4),.if_inst(if_inst),
        .commit_instr_if(commit_instr_if),
        .id_pc(id_pc),.id_pcadd4(id_pcadd4),.id_inst(id_inst),
        .commit_instr_id(commit_instr_id),
        .id_rs1(id_rs1),.id_rs2(id_rs2)
    );

    // ID
    wire [4:0] alu_op,rf_ra0,rf_ra1,rf_wa;
    wire [31:0] imm;
    wire rf_we,alu_src0_sel,alu_src1_sel,dmem_we_dec;
    wire [1:0] rf_wd_sel;
    wire [3:0] dmem_access,br_type;
    DECODER u_dec(
        .inst(id_inst),.alu_op(alu_op),.dmem_access(dmem_access),.imm(imm),
        .rf_ra0(rf_ra0),.rf_ra1(rf_ra1),.rf_wa(rf_wa),.rf_we(rf_we),
        .rf_wd_sel(rf_wd_sel),.alu_src0_sel(alu_src0_sel),.alu_src1_sel(alu_src1_sel),
        .br_type(br_type),.dmem_we(dmem_we_dec)
    );
    wire [31:0] rf_rd0,rf_rd1,wb_rf_wd;
    wire wb_rf_we;
    wire [4:0] wb_rf_wa;
    REG_FILE u_rf(
        .clk(clk),.rf_ra0(rf_ra0),.rf_ra1(rf_ra1),
        .rf_wa(wb_rf_wa),.rf_we(wb_rf_we),.rf_wd(wb_rf_wd),
        .rf_rd0(rf_rd0),.rf_rd1(rf_rd1),
        .debug_reg_ra(debug_reg_ra),.debug_reg_rd(debug_reg_rd)
    );

    // ID/EX
    wire flush_id_ex;
    wire [31:0] ex_pc,ex_pcadd4,ex_inst,ex_rf_rd0,ex_rf_rd1,ex_imm;
    wire [4:0] ex_alu_op,ex_rf_wa,ex_rs1,ex_rs2;
    wire ex_rf_we,ex_alu_src0_sel,ex_alu_src1_sel,ex_dmem_we;
    wire [1:0] ex_rf_wd_sel;
    wire [3:0] ex_dmem_access,ex_br_type;
    wire commit_instr_ex;
    ID_EX_REG u_idex(
        .clk(clk),.rst(rst),.en(global_en),
        .stall(1'b0),.flush(flush_id_ex),
        .id_pc(id_pc),.id_pcadd4(id_pcadd4),.id_inst(id_inst),
        .id_rf_rd0(rf_rd0),.id_rf_rd1(rf_rd1),.id_imm(imm),
        .id_alu_op(alu_op),.id_rf_wa(rf_wa),.id_rs1(id_rs1),.id_rs2(id_rs2),
        .id_rf_we(rf_we),.id_alu_src0_sel(alu_src0_sel),.id_alu_src1_sel(alu_src1_sel),.id_dmem_we(dmem_we_dec),
        .id_rf_wd_sel(rf_wd_sel),.id_dmem_access(dmem_access),.id_br_type(br_type),
        .commit_instr_id(commit_instr_id),
        .ex_pc(ex_pc),.ex_pcadd4(ex_pcadd4),.ex_inst(ex_inst),
        .ex_rf_rd0(ex_rf_rd0),.ex_rf_rd1(ex_rf_rd1),.ex_imm(ex_imm),
        .ex_alu_op(ex_alu_op),.ex_rf_wa(ex_rf_wa),.ex_rs1(ex_rs1),.ex_rs2(ex_rs2),
        .ex_rf_we(ex_rf_we),.ex_alu_src0_sel(ex_alu_src0_sel),.ex_alu_src1_sel(ex_alu_src1_sel),.ex_dmem_we(ex_dmem_we),
        .ex_rf_wd_sel(ex_rf_wd_sel),.ex_dmem_access(ex_dmem_access),.ex_br_type(ex_br_type),
        .commit_instr_ex(commit_instr_ex)
    );

    // EX：Branch、SegCtrl、Forward、ALU
    // Forwarded ALU inputs — declared here for use by BRANCH and ALU
    wire [31:0] alu_src0,alu_src1;
    wire [31:0] alu_src0_final,alu_src1_final;
    wire [1:0] npc_sel;
    BRANCH u_br(
        .br_type(ex_br_type),.br_src0(alu_src0_final),.br_src1(alu_src1_final),
        .npc_sel(npc_sel)
    );
    SegCtrl u_segctrl(
        .ex_rf_we(ex_rf_we),.ex_wd_sel(ex_rf_wd_sel),.ex_wa(ex_rf_wa),
        .id_rs1(id_rs1),.id_rs2(id_rs2),
        .npc_sel(npc_sel),
        .stall_pc(stall_pc),.stall_if_id(stall_if_id),
        .flush_if_id(flush_if_id),.flush_id_ex(flush_id_ex)
    );
    // MEM阶段前递数据选择：ALU结果 vs PC+4 (JAL/JALR)
    wire [31:0] mem_rf_wd_pre = (mem_rf_wd_sel == 2'b10) ? mem_pcadd4 : mem_alu_res;
    wire [1:0] fw_a,fw_b;
    wire [31:0] fw_data_a,fw_data_b;
    Forward u_forward(
        .mem_rf_we(mem_rf_we),.mem_wa(mem_rf_wa),.mem_wd(mem_rf_wd_pre),
        .wb_rf_we(wb_rf_we),.wb_wa(wb_rf_wa),.wb_wd(wb_rf_wd),
        .ex_rs1(ex_rs1),.ex_rs2(ex_rs2),
        .fw_a(fw_a),.fw_b(fw_b),
        .fw_data_a(fw_data_a),.fw_data_b(fw_data_b)
    );
    MUX2 #(32) mux_a(.src0(ex_rf_rd0),.src1(mem_rf_wd_pre),.src2(wb_rf_wd),.src3(0),.sel(fw_a),.res(alu_src0));
    MUX2 #(32) mux_b(.src0(ex_rf_rd1),.src1(mem_rf_wd_pre),.src2(wb_rf_wd),.src3(0),.sel(fw_b),.res(alu_src1));
    MUX1 #(32) mux0(.src0(alu_src0),.src1(ex_pc),.sel(ex_alu_src0_sel),.res(alu_src0_final));
    MUX1 #(32) mux1(.src0(alu_src1),.src1(ex_imm),.sel(ex_alu_src1_sel),.res(alu_src1_final));
    wire [31:0] ex_alu_res;
    ALU u_alu(
        .alu_src0(alu_src0_final),.alu_src1(alu_src1_final),
        .alu_op(ex_alu_op),.alu_res(ex_alu_res)
    );
    wire [31:0] pc_offset=ex_pc+ex_imm;
    wire [31:0] pc_j={ex_alu_res[31:1],1'b0};
    NPC_MUX u_npc(
        .npc_sel(npc_sel),.pc_add4(if_pcadd4),.pc_offset(pc_offset),.pc_j(pc_j),
        .npc(if_npc)
    );

    // Store data forwarding: rs2 may need forwarding from MEM or WB
    wire [31:0] ex_rf_rd1_fwd;
    MUX2 #(32) mux_fwd_rd1(
        .src0(ex_rf_rd1),.src1(mem_rf_wd_pre),.src2(wb_rf_wd),.src3(0),
        .sel(fw_b),.res(ex_rf_rd1_fwd)
    );

    // EX/MEM
    wire [31:0] mem_pc,mem_pcadd4,mem_inst,mem_alu_res,mem_rf_rd1;
    wire [4:0] mem_rf_wa;
    wire mem_rf_we,mem_dmem_we;
    wire [1:0] mem_rf_wd_sel;
    wire [3:0] mem_dmem_access;
    wire commit_instr_mem;
    wire [1:0] wb_rf_wd_sel;   // 新增：WB段写回数据选择信号
    EX_MEM_REG u_exmem(
        .clk(clk),.rst(rst),.en(global_en),.stall(1'b0),
        .ex_pc(ex_pc),.ex_pcadd4(ex_pcadd4),.ex_inst(ex_inst),
        .ex_alu_res(ex_alu_res),.ex_rf_rd1(ex_rf_rd1_fwd),
        .ex_rf_wa(ex_rf_wa),.ex_rf_we(ex_rf_we),.ex_dmem_we(ex_dmem_we),
        .ex_rf_wd_sel(ex_rf_wd_sel),.ex_dmem_access(ex_dmem_access),
        .commit_instr_ex(commit_instr_ex),
        .mem_pc(mem_pc),.mem_pcadd4(mem_pcadd4),.mem_inst(mem_inst),
        .mem_alu_res(mem_alu_res),.mem_rf_rd1(mem_rf_rd1),
        .mem_rf_wa(mem_rf_wa),.mem_rf_we(mem_rf_we),.mem_dmem_we(mem_dmem_we),
        .mem_rf_wd_sel(mem_rf_wd_sel),.mem_dmem_access(mem_dmem_access),
        .commit_instr_mem(commit_instr_mem)
    );

    // MEM
    wire [31:0] slu_rd,slu_wd;
    SLU u_slu(
        .addr(mem_alu_res),.dmem_access(mem_dmem_access),
        .rd_in(dmem_rdata),.wd_in(mem_rf_rd1),
        .rd_out(slu_rd),.wd_out(slu_wd)
    );
    assign dmem_we=mem_dmem_we;
    assign dmem_addr=mem_alu_res;
    assign dmem_wdata=slu_wd;

    // MEM/WB
    wire [31:0] wb_pc,wb_pcadd4,wb_inst,wb_alu_res,wb_dmem_rd;
    wire commit_instr_wb;
    wire wb_dmem_we;
    wire [31:0] wb_dmem_addr,wb_dmem_wd;
    MEM_WB_REG u_memwb(
        .clk(clk),.rst(rst),.en(global_en),.stall(1'b0),
        .mem_pc(mem_pc),.mem_pcadd4(mem_pcadd4),.mem_inst(mem_inst),
        .mem_alu_res(mem_alu_res),.mem_dmem_rd(slu_rd),
        .mem_rf_wa(mem_rf_wa),.mem_rf_we(mem_rf_we),.mem_rf_wd_sel(mem_rf_wd_sel),
        .commit_instr_mem(commit_instr_mem),
        .mem_dmem_we_pipe(mem_dmem_we),.mem_dmem_addr(mem_alu_res),.mem_dmem_wd(slu_wd),
        .wb_pc(wb_pc),.wb_pcadd4(wb_pcadd4),.wb_inst(wb_inst),
        .wb_alu_res(wb_alu_res),.wb_dmem_rd(wb_dmem_rd),
        .wb_rf_wa(wb_rf_wa),.wb_rf_we(wb_rf_we),.wb_rf_wd_sel(wb_rf_wd_sel),
        .commit_instr_wb(commit_instr_wb),
        .wb_dmem_we(wb_dmem_we),.wb_dmem_addr(wb_dmem_addr),.wb_dmem_wd(wb_dmem_wd)
    );

    // WB
    MUX2 #(32) wb_mux(
        .src0(wb_alu_res),.src1(wb_dmem_rd),.src2(wb_pcadd4),.src3(0),
        .sel(wb_rf_wd_sel),.res(wb_rf_wd)
    );

    // Commit
    reg commit_reg;
    reg [31:0] commit_pc_reg,commit_instr_reg;
    reg commit_halt_reg,commit_reg_we_reg;
    reg [4:0] commit_reg_wa_reg;
    reg [31:0] commit_reg_wd_reg;
    reg commit_dmem_we_reg;
    reg [31:0] commit_dmem_wa_reg,commit_dmem_wd_reg;

    always @(posedge clk) begin
        if(rst) begin
            commit_reg<=0;
            commit_pc_reg<=0;commit_instr_reg<=0;
            commit_halt_reg<=0;commit_reg_we_reg<=0;
            commit_reg_wa_reg<=0;commit_reg_wd_reg<=0;
            commit_dmem_we_reg<=0;commit_dmem_wa_reg<=0;commit_dmem_wd_reg<=0;
        end else if(global_en) begin
            commit_reg<=commit_instr_wb;
            commit_pc_reg<=wb_pc;
            commit_instr_reg<=wb_inst;
            commit_halt_reg<=(wb_inst==32'h00100073);
            commit_reg_we_reg<=wb_rf_we;
            commit_reg_wa_reg<=wb_rf_wa;
            commit_reg_wd_reg<=wb_rf_wd;
            commit_dmem_we_reg<=wb_dmem_we;
            commit_dmem_wa_reg<=wb_dmem_addr;
            commit_dmem_wd_reg<=wb_dmem_wd;
        end
    end

    assign commit=commit_reg;
    assign commit_pc=commit_pc_reg;
    assign commit_instr=commit_instr_reg;
    assign commit_halt=commit_halt_reg;
    assign commit_reg_we=commit_reg_we_reg;
    assign commit_reg_wa=commit_reg_wa_reg;
    assign commit_reg_wd=commit_reg_wd_reg;
    assign commit_dmem_we=commit_dmem_we_reg;
    assign commit_dmem_wa=commit_dmem_wa_reg;
    assign commit_dmem_wd=commit_dmem_wd_reg;

endmodule
