/*
二路组相联Cache
- Cache组数：8组（INDEX_WIDTH=3）
- 每组2路（WAY_NUM=2）
- 块大小：4字（16字节 128位）
- 采用写回写分配策略
- 替换策略：FIFO 或 RAND
*/
module cache #(
    parameter INDEX_WIDTH       = 3,    // Cache索引位宽 2^3=8组
    parameter LINE_OFFSET_WIDTH = 2,    // 行偏移位宽，一行2^2=4字
    parameter SPACE_OFFSET      = 2,    // 字节偏移（字地址低2位为0）
    parameter WAY_NUM           = 2,     // 2路组相联
    parameter REPLACEMENT_POLICY = "FIFO" // 替换策略：FIFO, RAND
)(
    input                     clk,    
    input                     rstn,
    /* CPU接口 */  
    input [31:0]              addr,   // CPU地址
    input                     r_req,  // CPU读请求
    input                     w_req,  // CPU写请求
    input [31:0]              w_data, // CPU写数据
    output [31:0]             r_data, // CPU读数据
    output reg                miss,   // 缓存未命中
    /* 内存接口 */  
    output reg                mem_r,  // 内存读请求
    output reg                mem_w,  // 内存写请求
    output reg [31:0]         mem_addr, // 内存地址
    output reg [127:0]        mem_w_data, // 内存写数据（一行）
    input      [127:0]        mem_r_data, // 内存读数据（一行）
    input                     mem_ready   // 内存就绪
);

    // ========== 本地参数 ==========
    localparam LINE_WIDTH = 32 << LINE_OFFSET_WIDTH; // 128
    localparam TAG_WIDTH = 32 - INDEX_WIDTH - LINE_OFFSET_WIDTH - SPACE_OFFSET; // 32-3-2-2=25
    localparam SET_NUM   = 1 << INDEX_WIDTH; // 8

    // ========== 地址分解相关 ==========
    wire [INDEX_WIDTH-1:0] r_index;   // 读索引（来自当前CPU请求addr）
    wire [INDEX_WIDTH-1:0] w_index;   // 写索引（来自缓冲地址addr_buf）
    wire [TAG_WIDTH-1:0]   tag;       // 标记（来自addr_buf）
    wire [LINE_OFFSET_WIDTH-1:0] word_offset; // 字偏移

    assign r_index = addr[INDEX_WIDTH+LINE_OFFSET_WIDTH+SPACE_OFFSET-1 : LINE_OFFSET_WIDTH+SPACE_OFFSET];
    assign w_index = addr_buf[INDEX_WIDTH+LINE_OFFSET_WIDTH+SPACE_OFFSET-1 : LINE_OFFSET_WIDTH+SPACE_OFFSET];
    assign tag = addr_buf[31:INDEX_WIDTH+LINE_OFFSET_WIDTH+SPACE_OFFSET];
    assign word_offset = addr_buf[LINE_OFFSET_WIDTH+SPACE_OFFSET-1:SPACE_OFFSET];

    // ========== 缓冲寄存器 ==========
    reg [31:0]           addr_buf;    // 当前处理的地址
    reg [31:0]           w_data_buf;  // 写数据缓冲
    reg                  op_buf;      // 0:读 1:写
    reg [LINE_WIDTH-1:0] ret_buf;     // 从内存读回的一整行数据

    // ========== 双路信号定义 ==========
    // 路0信号
    wire                  valid_way0, dirty_way0;
    wire [TAG_WIDTH-1:0]  r_tag_way0;
    wire [LINE_WIDTH-1:0] r_line_way0;
    reg                   w_valid_way0, w_dirty_way0;
    reg                   tag_we_way0, data_we_way0;

    // 路1信号
    wire                  valid_way1, dirty_way1;
    wire [TAG_WIDTH-1:0]  r_tag_way1;
    wire [LINE_WIDTH-1:0] r_line_way1;
    reg                   w_valid_way1, w_dirty_way1;
    reg                   tag_we_way1, data_we_way1;

    // 命中及替换相关
    wire hit_way0, hit_way1;
    wire hit;
    wire [WAY_NUM-1:0] hit_way_idx; // one-hot
    reg  way_to_replace;            // 组合逻辑计算的替换路
    reg  way_to_replace_reg;        // 锁存的替换路（用于refill和FIFO更新）

    // ========== 状态寄存器 ==========
    reg              fifo_ptr     [0:SET_NUM-1];   // FIFO：每个组的下一次替换路
    reg [31:0]       lfsr;                         // RAND：线性反馈移位寄存器
    reg              random_bit;                   // RAND：生成的随机位
    reg [WAY_NUM-1:0] rand_way;                    // RAND：最终的替换路

    // ========== 脏块写回缓冲 ==========
    reg [31:0]   dirty_mem_addr_buf;
    reg [127:0]  dirty_mem_data_buf;
    reg          dirty_way_buf;     // 记录正在写回的脏块属于哪一路

    // ========== 控制信号 ==========
    reg addr_buf_we;    // 地址缓冲写使能
    reg ret_buf_we;     // 内存读返回缓冲写使能
    reg data_from_mem;  // 输出选择来自内存还是Cache
    reg refill;         // 重填标志

    // ========== 状态机定义 ==========
    localparam IDLE      = 3'd0,
               READ      = 3'd1,
               MISS      = 3'd2,
               WRITE     = 3'd3,
               W_DIRTY   = 3'd4;
    reg [2:0] CS, NS;

    // ========== 命中判断组合逻辑 ==========
    assign hit_way0 = valid_way0 && (r_tag_way0 == tag);
    assign hit_way1 = valid_way1 && (r_tag_way1 == tag);
    assign hit = hit_way0 || hit_way1;
    assign hit_way_idx = {hit_way1, hit_way0}; // 位1表示way1命中，位0表示way0命中

    // ========== 脏块地址计算（组合逻辑） ==========
    wire [31:0] dirty_mem_addr_way0 = {r_tag_way0, w_index} << (LINE_OFFSET_WIDTH+SPACE_OFFSET);
    wire [31:0] dirty_mem_addr_way1 = {r_tag_way1, w_index} << (LINE_OFFSET_WIDTH+SPACE_OFFSET);

    // ========== 输出数据选择（根据字偏移） ==========
    reg [31:0] cache_data_way0, cache_data_way1;
    wire [31:0] cache_data_hit;
    always @(*) begin
        case (word_offset)
            0: begin cache_data_way0 = r_line_way0[31:0];  cache_data_way1 = r_line_way1[31:0];  end
            1: begin cache_data_way0 = r_line_way0[63:32]; cache_data_way1 = r_line_way1[63:32]; end
            2: begin cache_data_way0 = r_line_way0[95:64]; cache_data_way1 = r_line_way1[95:64]; end
            3: begin cache_data_way0 = r_line_way0[127:96];cache_data_way1 = r_line_way1[127:96];end
            default: begin cache_data_way0 = 0; cache_data_way1 = 0; end
        endcase
    end
    assign cache_data_hit = hit_way0 ? cache_data_way0 : cache_data_way1;

    reg [31:0] mem_data;
    always @(*) begin
        case (word_offset)
            0: mem_data = ret_buf[31:0];
            1: mem_data = ret_buf[63:32];
            2: mem_data = ret_buf[95:64];
            3: mem_data = ret_buf[127:96];
            default: mem_data = 0;
        endcase
    end

    assign r_data = data_from_mem ? mem_data : (hit ? cache_data_hit : 0);

    // ========== 写入Cache的数据合并 ==========
    wire [127:0] w_line_mask = 32'hFFFFFFFF << (word_offset*32);
    wire [127:0] w_data_line = w_data_buf << (word_offset*32);
    wire [127:0] w_line_way0 = (hit_way0 && (CS==READ || CS==WRITE)) ? 
                                (r_line_way0 & ~w_line_mask) | w_data_line : 
                                (refill && way_to_replace_reg==0) ? 
                                (ret_buf & ~w_line_mask) | w_data_line : 
                                ret_buf;
    wire [127:0] w_line_way1 = (hit_way1 && (CS==READ || CS==WRITE)) ? 
                                (r_line_way1 & ~w_line_mask) | w_data_line : 
                                (refill && way_to_replace_reg==1) ? 
                                (ret_buf & ~w_line_mask) | w_data_line : 
                                ret_buf;

    // ========== 替换路选择（组合逻辑） ==========
    always @(*) begin
        if (!valid_way0)      way_to_replace = 1'b0;
        else if (!valid_way1) way_to_replace = 1'b1;
        else begin
            if (REPLACEMENT_POLICY == "FIFO")
                way_to_replace = fifo_ptr[w_index];
            else // RAND
                way_to_replace = rand_way;
        end
    end

    // 随机数生成
    generate
        if (REPLACEMENT_POLICY == "RAND") begin
            always @(posedge clk or negedge rstn) begin
                if (!rstn) begin
                    lfsr <= 32'hDEADBEEF;
                    random_bit <= 1'b0;
                    rand_way <= 1'b0;
                end else begin
                    random_bit <= ^(lfsr & 32'h80000057);
                    lfsr <= {lfsr[30:0], random_bit};
                    rand_way <= lfsr[0];
                end
            end
        end
    endgenerate

    // ========== FIFO 状态更新（使用锁存的替换路） ==========
    integer i;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            for (i = 0; i < SET_NUM; i = i + 1) begin
                fifo_ptr[i]  <= 1'b0;
            end
        end else begin
            // FIFO 更新：仅在 refill 时翻转指针
            if (REPLACEMENT_POLICY == "FIFO") begin
                if (refill) begin
                    fifo_ptr[w_index] <= ~fifo_ptr[w_index];
                end
            end
        end
    end

    // ========== 状态机时序逻辑 ==========
    always @(posedge clk or negedge rstn) begin
        if (!rstn) CS <= IDLE;
        else CS <= NS;
    end

    // 缓冲寄存器和refill标志更新
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            addr_buf <= 0;
            ret_buf <= 0;
            w_data_buf <= 0;
            op_buf <= 0;
            refill <= 0;
            dirty_mem_addr_buf <= 0;
            dirty_mem_data_buf <= 0;
            dirty_way_buf <= 0;
            way_to_replace_reg <= 0;
        end else begin
            if (addr_buf_we) begin
                addr_buf <= addr;
                w_data_buf <= w_data;
                op_buf <= w_req;
            end
            if (ret_buf_we) begin
                ret_buf <= mem_r_data;
            end
            // refill 信号：在 MISS 状态且 mem_ready 时置1，下一周期 IDLE 中使用
            if (CS == MISS && mem_ready) begin
                refill <= 1;
            end
            if (CS == IDLE) begin
                refill <= 0;
            end
            // 锁存替换路：在需要替换的时刻（进入 MISS 或 W_DIRTY 时）
            // 这里在 READ/WRITE 状态中，如果 miss，则锁存当前组合逻辑的 way_to_replace
            if ((CS == READ || CS == WRITE) && miss) begin
                way_to_replace_reg <= way_to_replace;
            end
            // 脏块写回缓冲：在 READ/WRITE 状态中，如果 miss 且被替换路为脏，则锁存脏地址和数据
            if ((CS == READ || CS == WRITE) && miss) begin
                if (way_to_replace == 0 && dirty_way0) begin
                    dirty_mem_addr_buf <= dirty_mem_addr_way0;
                    dirty_mem_data_buf <= r_line_way0;
                    dirty_way_buf <= 0;
                end else if (way_to_replace == 1 && dirty_way1) begin
                    dirty_mem_addr_buf <= dirty_mem_addr_way1;
                    dirty_mem_data_buf <= r_line_way1;
                    dirty_way_buf <= 1;
                end
            end
        end
    end

    // ========== 实例化双路BRAM ==========
    bram #(
        .ADDR_WIDTH(INDEX_WIDTH),
        .DATA_WIDTH(TAG_WIDTH+2)
    ) tag_bram_way0 (
        .clk(clk),
        .raddr(r_index),
        .waddr(w_index),
        .din({w_valid_way0, w_dirty_way0, tag}),
        .we(tag_we_way0),
        .dout({valid_way0, dirty_way0, r_tag_way0})
    );

    bram #(
        .ADDR_WIDTH(INDEX_WIDTH),
        .DATA_WIDTH(TAG_WIDTH+2)
    ) tag_bram_way1 (
        .clk(clk),
        .raddr(r_index),
        .waddr(w_index),
        .din({w_valid_way1, w_dirty_way1, tag}),
        .we(tag_we_way1),
        .dout({valid_way1, dirty_way1, r_tag_way1})
    );

    bram #(
        .ADDR_WIDTH(INDEX_WIDTH),
        .DATA_WIDTH(LINE_WIDTH)
    ) data_bram_way0 (
        .clk(clk),
        .raddr(r_index),
        .waddr(w_index),
        .din(w_line_way0),
        .we(data_we_way0),
        .dout(r_line_way0)
    );

    bram #(
        .ADDR_WIDTH(INDEX_WIDTH),
        .DATA_WIDTH(LINE_WIDTH)
    ) data_bram_way1 (
        .clk(clk),
        .raddr(r_index),
        .waddr(w_index),
        .din(w_line_way1),
        .we(data_we_way1),
        .dout(r_line_way1)
    );

    // ========== 状态机次态逻辑 ==========
    always @(*) begin
        case (CS)
            IDLE: begin
                if (r_req) NS = READ;
                else if (w_req) NS = WRITE;
                else NS = IDLE;
            end
            READ: begin
                if (miss) begin
                    if ((way_to_replace==0 && dirty_way0) || (way_to_replace==1 && dirty_way1))
                        NS = W_DIRTY;
                    else
                        NS = MISS;
                end else begin
                    if (r_req) NS = READ;
                    else if (w_req) NS = WRITE;
                    else NS = IDLE;
                end
            end
            WRITE: begin
                if (miss) begin
                    if ((way_to_replace==0 && dirty_way0) || (way_to_replace==1 && dirty_way1))
                        NS = W_DIRTY;
                    else
                        NS = MISS;
                end else begin
                    if (r_req) NS = READ;
                    else if (w_req) NS = WRITE;
                    else NS = IDLE;
                end
            end
            MISS: begin
                if (mem_ready) NS = IDLE;
                else NS = MISS;
            end
            W_DIRTY: begin
                if (mem_ready) NS = MISS;
                else NS = W_DIRTY;
            end
            default: NS = IDLE;
        endcase
    end

    // ========== 状态机输出控制信号 ==========
    always @(*) begin
        // 默认值
        addr_buf_we   = 1'b0;
        ret_buf_we    = 1'b0;
        data_we_way0  = 1'b0;
        data_we_way1  = 1'b0;
        tag_we_way0   = 1'b0;
        tag_we_way1   = 1'b0;
        w_valid_way0  = 1'b0;
        w_valid_way1  = 1'b0;
        w_dirty_way0  = 1'b0;
        w_dirty_way1  = 1'b0;
        data_from_mem = 1'b0;
        miss          = 1'b0;
        mem_r         = 1'b0;
        mem_w         = 1'b0;
        mem_addr      = 32'b0;
        mem_w_data    = 128'b0;

        case (CS)
            IDLE: begin
                addr_buf_we = 1'b1;
                miss = 1'b0;
                if (refill) begin
                    data_from_mem = 1'b1;
                    // 使用锁存的替换路 way_to_replace_reg
                    if (way_to_replace_reg == 0) begin
                        data_we_way0 = 1'b1;
                        tag_we_way0 = 1'b1;
                        w_valid_way0 = 1'b1;
                        w_dirty_way0 = op_buf;
                    end else begin
                        data_we_way1 = 1'b1;
                        tag_we_way1 = 1'b1;
                        w_valid_way1 = 1'b1;
                        w_dirty_way1 = op_buf;
                    end
                end
            end

            READ: begin
                data_from_mem = 1'b0;
                if (hit) begin
                    miss = 1'b0;
                    addr_buf_we = 1'b1;
                end else begin
                    miss = 1'b1;
                    addr_buf_we = 1'b0;
                end
            end

            WRITE: begin
                data_from_mem = 1'b0;
                if (hit) begin
                    miss = 1'b0;
                    addr_buf_we = 1'b1;
                    if (hit_way0) begin
                        data_we_way0 = 1'b1;
                        tag_we_way0 = 1'b1;
                        w_valid_way0 = 1'b1;
                        w_dirty_way0 = 1'b1;
                    end else begin
                        data_we_way1 = 1'b1;
                        tag_we_way1 = 1'b1;
                        w_valid_way1 = 1'b1;
                        w_dirty_way1 = 1'b1;
                    end
                end else begin
                    miss = 1'b1;
                    addr_buf_we = 1'b0;
                end
            end

            MISS: begin
                miss = 1'b1;
                mem_r = 1'b1;
                mem_addr = addr_buf;
                if (mem_ready) begin
                    mem_r = 1'b0;
                    ret_buf_we = 1'b1;
                end
            end

            W_DIRTY: begin
                miss = 1'b1;
                mem_w = 1'b1;
                mem_addr = dirty_mem_addr_buf;
                mem_w_data = dirty_mem_data_buf;
                if (mem_ready) begin
                    mem_w = 1'b0;
                end
            end

            default: ;
        endcase
    end

endmodule