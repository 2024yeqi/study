/*
N路组相联Cache
- Cache组数：8组（INDEX_WIDTH=3）
- 每组N路（WAY_NUM可配置为2,4,8,16）
- 块大小：4字（16字节 128位）
- 采用写回写分配策略
- 替换策略：LRU（计数器法）、FIFO、RAND
*/
module cache #(
    parameter INDEX_WIDTH       = 3,    // Cache索引位宽 2^3=8组
    parameter LINE_OFFSET_WIDTH = 2,    // 行偏移位宽，一行2^2=4字
    parameter SPACE_OFFSET      = 2,    // 字节偏移（字地址低2位为0）
    parameter WAY_NUM           = 2,    // N路组相联(N=2,4,8,16)
    parameter REPLACEMENT_POLICY = "LRU" // 替换策略：LRU, FIFO, RAND
)(
    input                     clk,
    input                     rstn,
    /* CPU接口 */
    input [31:0]              addr,   // CPU地址
    input                     r_req,  // CPU读请求
    input                     w_req,  // CPU写请求
    input [31:0]              w_data, // CPU写数据
    output [31:0]             r_data, // CPU读数据（wire，由assign驱动）
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
    localparam TAG_WIDTH = 32 - INDEX_WIDTH - LINE_OFFSET_WIDTH - SPACE_OFFSET; // 25
    localparam SET_NUM   = 1 << INDEX_WIDTH; // 8
    localparam WAY_BITS  = (WAY_NUM <= 2)  ? 1 :
                           (WAY_NUM <= 4)  ? 2 :
                           (WAY_NUM <= 8)  ? 3 : 4;

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

    // ========== N路信号定义（打包数组） ==========
    wire [WAY_NUM-1:0]                  valid_arr;    // valid bits for each way
    wire [WAY_NUM-1:0]                  dirty_arr;    // dirty bits for each way
    wire [TAG_WIDTH-1:0]                r_tag_arr  [0:WAY_NUM-1];
    wire [LINE_WIDTH-1:0]               r_line_arr [0:WAY_NUM-1];
    wire [WAY_NUM-1:0]                  hit_way_arr;  // one-hot hit
    reg  [WAY_NUM-1:0]                  tag_we_arr;
    reg  [WAY_NUM-1:0]                  data_we_arr;
    reg  [WAY_NUM-1:0]                  w_valid_arr;
    reg  [WAY_NUM-1:0]                  w_dirty_arr;

    wire hit;
    reg  [WAY_BITS-1:0]                 hit_way_idx;
    reg  [WAY_BITS-1:0]                 way_to_replace;

    // ========== LRU状态（计数器法：值越大越近被使用） ==========
    reg [WAY_BITS-1:0] lru_cnt [0:(SET_NUM * WAY_NUM) - 1];  // 扁平化数组

    // ========== FIFO状态 ==========
    reg [WAY_BITS-1:0] fifo_ptr [0:SET_NUM-1];   // 每个组的下一次替换路

    // ========== RAND状态 ==========
    reg [31:0]         lfsr;
    reg                random_bit;
    reg [WAY_BITS-1:0] rand_way;

    // ========== 脏块写回缓冲 ==========
    reg [31:0]   dirty_mem_addr_buf;
    reg [127:0]  dirty_mem_data_buf;

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
    genvar gi;
    generate
        for (gi = 0; gi < WAY_NUM; gi = gi + 1) begin : hit_gen
            assign hit_way_arr[gi] = valid_arr[gi] && (r_tag_arr[gi] == tag);
        end
    endgenerate
    assign hit = |hit_way_arr;

    // ========== 命中路编码（one-hot → binary） ==========
    integer hi;
    always @(*) begin
        hit_way_idx = 0;
        for (hi = WAY_NUM - 1; hi >= 0; hi = hi - 1) begin
            if (hit_way_arr[hi]) hit_way_idx = hi[WAY_BITS-1:0];
        end
    end

    // ========== 替换路选择组合逻辑 ==========
    integer ri;
    always @(*) begin
        way_to_replace = 0;
        // 优先选择invalid的路（最低索引优先）
        for (ri = WAY_NUM - 1; ri >= 0; ri = ri - 1) begin
            if (!valid_arr[ri]) way_to_replace = ri[WAY_BITS-1:0];
        end
        // 如果所有路都valid，根据替换策略选择
        if (&valid_arr) begin
            if (REPLACEMENT_POLICY == "LRU") begin
                // 找到cnt==0的路（最近最少使用）
                for (ri = WAY_NUM - 1; ri >= 0; ri = ri - 1) begin
                    if (lru_cnt[w_index * WAY_NUM + ri] == 0)
                        way_to_replace = ri[WAY_BITS-1:0];
                end
            end else if (REPLACEMENT_POLICY == "FIFO") begin
                way_to_replace = fifo_ptr[w_index];
            end else begin
                way_to_replace = rand_way;
            end
        end
    end

    // ========== 脏块地址计算 ==========
    wire [31:0] dirty_mem_addr_arr [0:WAY_NUM-1];
    generate
        for (gi = 0; gi < WAY_NUM; gi = gi + 1) begin : dirty_addr_gen
            assign dirty_mem_addr_arr[gi] = {r_tag_arr[gi], w_index} << (LINE_OFFSET_WIDTH+SPACE_OFFSET);
        end
    endgenerate

    // ========== MUX：根据way_to_replace选择对应路的line和dirty_addr ==========
    reg [LINE_WIDTH-1:0] r_line_replace;    // way_to_replace对应的line数据
    reg [31:0]           dirty_mem_addr_replace; // way_to_replace对应的脏地址
    integer mi;
    always @(*) begin
        r_line_replace = 0;
        dirty_mem_addr_replace = 0;
        for (mi = 0; mi < WAY_NUM; mi = mi + 1) begin
            if (mi[WAY_BITS-1:0] == way_to_replace) begin
                r_line_replace = r_line_arr[mi];
                dirty_mem_addr_replace = dirty_mem_addr_arr[mi];
            end
        end
    end

    // ========== 输出数据选择（根据字偏移和命中路） ==========
    reg [31:0] cache_data_hit;
    integer oi;
    always @(*) begin
        cache_data_hit = 0;
        for (oi = WAY_NUM - 1; oi >= 0; oi = oi - 1) begin
            if (hit_way_arr[oi]) begin
                case (word_offset)
                    0: cache_data_hit = r_line_arr[oi][31:0];
                    1: cache_data_hit = r_line_arr[oi][63:32];
                    2: cache_data_hit = r_line_arr[oi][95:64];
                    3: cache_data_hit = r_line_arr[oi][127:96];
                endcase
            end
        end
    end

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

    wire [LINE_WIDTH-1:0] w_line_arr [0:WAY_NUM-1];
    generate
        for (gi = 0; gi < WAY_NUM; gi = gi + 1) begin : w_line_gen
            assign w_line_arr[gi] = (hit_way_arr[gi] && (CS==READ || CS==WRITE)) ?
                                    (r_line_arr[gi] & ~w_line_mask) | w_data_line :
                                    (refill && way_to_replace == gi[WAY_BITS-1:0]) ?
                                    (ret_buf & ~w_line_mask) | w_data_line :
                                    ret_buf;
        end
    endgenerate

    // ========== 随机数生成 ==========
    generate
        if (REPLACEMENT_POLICY == "RAND") begin : rand_gen
            always @(posedge clk or negedge rstn) begin
                if (!rstn) begin
                    lfsr <= 32'hDEADBEEF;
                    random_bit <= 1'b0;
                    rand_way <= 0;
                end else begin
                    random_bit <= ^(lfsr & 32'h80000057);
                    lfsr <= {lfsr[30:0], random_bit};
                    rand_way <= lfsr[WAY_BITS-1:0];
                end
            end
        end else begin : no_rand
            always @(*) rand_way = 0;
        end
    endgenerate

    // ========== LRU/FIFO 状态更新 ==========
    integer lru_i, lru_j;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            for (lru_i = 0; lru_i < SET_NUM; lru_i = lru_i + 1) begin
                fifo_ptr[lru_i] <= 0;
                for (lru_j = 0; lru_j < WAY_NUM; lru_j = lru_j + 1) begin
                    lru_cnt[lru_i * WAY_NUM + lru_j] <= lru_j[WAY_BITS-1:0];
                end
            end
        end else begin
            // LRU 更新：在命中或refill时更新计数器
            if (REPLACEMENT_POLICY == "LRU") begin
                if (hit && (CS == READ || CS == WRITE)) begin
                    for (lru_j = 0; lru_j < WAY_NUM; lru_j = lru_j + 1) begin
                        if (hit_way_arr[lru_j]) begin
                            lru_cnt[w_index * WAY_NUM + lru_j] <= WAY_NUM - 1;
                        end else if (lru_cnt[w_index * WAY_NUM + lru_j] >
                                     lru_cnt[w_index * WAY_NUM + hit_way_idx]) begin
                            lru_cnt[w_index * WAY_NUM + lru_j] <=
                                lru_cnt[w_index * WAY_NUM + lru_j] - 1;
                        end
                    end
                end else if (refill && (CS == IDLE)) begin
                    for (lru_j = 0; lru_j < WAY_NUM; lru_j = lru_j + 1) begin
                        if (lru_j[WAY_BITS-1:0] == way_to_replace) begin
                            lru_cnt[w_index * WAY_NUM + lru_j] <= WAY_NUM - 1;
                        end else if (lru_cnt[w_index * WAY_NUM + lru_j] >
                                     lru_cnt[w_index * WAY_NUM + way_to_replace]) begin
                            lru_cnt[w_index * WAY_NUM + lru_j] <=
                                lru_cnt[w_index * WAY_NUM + lru_j] - 1;
                        end
                    end
                end
            end

            // FIFO 更新
            if (REPLACEMENT_POLICY == "FIFO") begin
                if (refill && (CS == IDLE)) begin
                    fifo_ptr[w_index] <= (fifo_ptr[w_index] + 1) % WAY_NUM;
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
        end else begin
            if (addr_buf_we) begin
                addr_buf <= addr;
                w_data_buf <= w_data;
                op_buf <= w_req;
            end
            if (ret_buf_we) begin
                ret_buf <= mem_r_data;
            end
            if (CS == MISS && mem_ready) begin
                refill <= 1;
            end
            if (CS == IDLE) begin
                refill <= 0;
            end
            if (CS == READ || CS == WRITE) begin
                if (miss && dirty_arr[way_to_replace]) begin
                    dirty_mem_addr_buf <= dirty_mem_addr_replace;
                    dirty_mem_data_buf <= r_line_replace;
                end
            end
        end
    end

    // ========== 例化N路BRAM ==========
    generate
        for (gi = 0; gi < WAY_NUM; gi = gi + 1) begin : way_block
            // Tag Bram (存储 valid, dirty, tag)
            bram #(
                .ADDR_WIDTH(INDEX_WIDTH),
                .DATA_WIDTH(TAG_WIDTH+2)
            ) tag_bram (
                .clk(clk),
                .raddr(r_index),
                .waddr(w_index),
                .din({w_valid_arr[gi], w_dirty_arr[gi], tag}),
                .we(tag_we_arr[gi]),
                .dout({valid_arr[gi], dirty_arr[gi], r_tag_arr[gi]})
            );

            // Data Bram
            bram #(
                .ADDR_WIDTH(INDEX_WIDTH),
                .DATA_WIDTH(LINE_WIDTH)
            ) data_bram (
                .clk(clk),
                .raddr(r_index),
                .waddr(w_index),
                .din(w_line_arr[gi]),
                .we(data_we_arr[gi]),
                .dout(r_line_arr[gi])
            );
        end
    endgenerate

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
                    if (dirty_arr[way_to_replace])
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
                    if (dirty_arr[way_to_replace])
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
        data_we_arr   = {WAY_NUM{1'b0}};
        tag_we_arr    = {WAY_NUM{1'b0}};
        w_valid_arr   = {WAY_NUM{1'b0}};
        w_dirty_arr   = {WAY_NUM{1'b0}};
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
                    data_we_arr[way_to_replace] = 1'b1;
                    tag_we_arr[way_to_replace] = 1'b1;
                    w_valid_arr[way_to_replace] = 1'b1;
                    w_dirty_arr[way_to_replace] = op_buf;
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
                    if (dirty_arr[way_to_replace]) begin
                        mem_w = 1'b1;
                        mem_addr = dirty_mem_addr_replace;
                        mem_w_data = r_line_replace;
                    end
                end
            end

            WRITE: begin
                data_from_mem = 1'b0;
                if (hit) begin
                    miss = 1'b0;
                    addr_buf_we = 1'b1;
                    data_we_arr[hit_way_idx] = 1'b1;
                    tag_we_arr[hit_way_idx] = 1'b1;
                    w_valid_arr[hit_way_idx] = 1'b1;
                    w_dirty_arr[hit_way_idx] = 1'b1;
                end else begin
                    miss = 1'b1;
                    addr_buf_we = 1'b0;
                    if (dirty_arr[way_to_replace]) begin
                        mem_w = 1'b1;
                        mem_addr = dirty_mem_addr_replace;
                        mem_w_data = r_line_replace;
                    end
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
