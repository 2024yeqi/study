/*
 * N路组相联Cache - LRU（年龄法）替换策略
 * Cache组数：8组
 * 每组N路（WAY_NUM=2,4,8,16）
 * 块大小：4字（128位）
 * 写回写分配
 */
module cache #(
    parameter INDEX_WIDTH        = 3,
    parameter LINE_OFFSET_WIDTH  = 2,
    parameter SPACE_OFFSET       = 2,
    parameter WAY_NUM            = 8      // 可配置
)(
    input                     clk,
    input                     rstn,
    input [31:0]              addr,
    input                     r_req,
    input                     w_req,
    input [31:0]              w_data,
    output [31:0]             r_data,
    output reg                miss,
    output reg                mem_r,
    output reg                mem_w,
    output reg [31:0]         mem_addr,
    output reg [127:0]        mem_w_data,
    input      [127:0]        mem_r_data,
    input                     mem_ready
);

    localparam LINE_WIDTH = 32 << LINE_OFFSET_WIDTH;
    localparam TAG_WIDTH  = 32 - INDEX_WIDTH - LINE_OFFSET_WIDTH - SPACE_OFFSET;
    localparam SET_NUM    = 1 << INDEX_WIDTH;
    localparam WAY_BITS   = (WAY_NUM <= 2) ? 1 :
                            (WAY_NUM <= 4) ? 2 :
                            (WAY_NUM <= 8) ? 3 : 4;

    // 地址分解
    wire [INDEX_WIDTH-1:0] r_index, w_index;
    wire [TAG_WIDTH-1:0]   tag;
    wire [LINE_OFFSET_WIDTH-1:0] word_offset;
    assign r_index     = addr[INDEX_WIDTH+LINE_OFFSET_WIDTH+SPACE_OFFSET-1 : LINE_OFFSET_WIDTH+SPACE_OFFSET];
    assign w_index     = addr_buf[INDEX_WIDTH+LINE_OFFSET_WIDTH+SPACE_OFFSET-1 : LINE_OFFSET_WIDTH+SPACE_OFFSET];
    assign tag         = addr_buf[31:INDEX_WIDTH+LINE_OFFSET_WIDTH+SPACE_OFFSET];
    assign word_offset = addr_buf[LINE_OFFSET_WIDTH+SPACE_OFFSET-1:SPACE_OFFSET];

    // 缓冲寄存器
    reg [31:0]           addr_buf;
    reg [31:0]           w_data_buf;
    reg                  op_buf;
    reg [LINE_WIDTH-1:0] ret_buf;

    // N路信号（打包数组）
    wire [WAY_NUM-1:0]                  valid_arr, dirty_arr;
    wire [TAG_WIDTH-1:0]                r_tag_arr  [0:WAY_NUM-1];
    wire [LINE_WIDTH-1:0]               r_line_arr [0:WAY_NUM-1];
    wire [WAY_NUM-1:0]                  hit_way_arr;
    reg  [WAY_NUM-1:0]                  tag_we_arr, data_we_arr;
    reg  [WAY_NUM-1:0]                  w_valid_arr, w_dirty_arr;
    wire hit;
    reg  [WAY_BITS-1:0]                 hit_way_idx;
    reg  [WAY_BITS-1:0]                 way_to_replace;      // 组合逻辑计算的替换路
    reg  [WAY_BITS-1:0]                 way_to_replace_reg;  // 锁存的替换路

    // ========== Age 字段（年龄越大表示越久未使用） ==========
    reg [WAY_BITS-1:0] age [0:(SET_NUM * WAY_NUM) - 1];

    // 脏块写回缓冲
    reg [31:0]   dirty_mem_addr_buf;
    reg [127:0]  dirty_mem_data_buf;

    // 控制信号
    reg addr_buf_we, ret_buf_we, data_from_mem, refill;

    // 状态机
    localparam IDLE = 3'd0, READ = 3'd1, MISS = 3'd2,
               WRITE = 3'd3, W_DIRTY = 3'd4;
    reg [2:0] CS, NS;

    // ========== 命中判断 ==========
    genvar gi;
    generate
        for (gi = 0; gi < WAY_NUM; gi = gi + 1) begin : hit_gen
            assign hit_way_arr[gi] = valid_arr[gi] && (r_tag_arr[gi] == tag);
        end
    endgenerate
    assign hit = |hit_way_arr;

    // 命中路编码（one-hot → binary，最小索引优先）
    integer hi;
    always @(*) begin
        hit_way_idx = 0;
        for (hi = WAY_NUM - 1; hi >= 0; hi = hi - 1)
            if (hit_way_arr[hi]) hit_way_idx = hi;
    end

    // ========== 替换路选择（优先无效路，否则选 Age 最大的路） ==========
    integer ri;
    reg [WAY_BITS-1:0] max_age;
    always @(*) begin
        way_to_replace = 0;
        // 优先选无效路（最小索引优先）
        for (ri = WAY_NUM - 1; ri >= 0; ri = ri - 1)
            if (!valid_arr[ri]) way_to_replace = ri;
        // 全有效时，选择 Age 最大的路（若有多个，选最小索引）
        if (&valid_arr) begin
            max_age = 0;
            for (ri = WAY_NUM - 1; ri >= 0; ri = ri - 1) begin
                if (age[w_index * WAY_NUM + ri] >= max_age) begin
                    max_age = age[w_index * WAY_NUM + ri];
                    way_to_replace = ri;
                end
            end
        end
    end

    // 脏块地址计算
    wire [31:0] dirty_mem_addr_arr [0:WAY_NUM-1];
    generate
        for (gi = 0; gi < WAY_NUM; gi = gi + 1) begin : dirty_addr_gen
            assign dirty_mem_addr_arr[gi] = {r_tag_arr[gi], w_index} << (LINE_OFFSET_WIDTH+SPACE_OFFSET);
        end
    endgenerate

    // 选择被替换路的 line 和脏地址
    reg [LINE_WIDTH-1:0] r_line_replace;
    reg [31:0]           dirty_mem_addr_replace;
    integer mi;
    always @(*) begin
        r_line_replace = 0;
        dirty_mem_addr_replace = 0;
        for (mi = 0; mi < WAY_NUM; mi = mi + 1) begin
            if (mi == way_to_replace) begin
                r_line_replace = r_line_arr[mi];
                dirty_mem_addr_replace = dirty_mem_addr_arr[mi];
            end
        end
    end

    // 输出数据选择
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

    // 写入数据合并
    wire [127:0] w_line_mask = 32'hFFFFFFFF << (word_offset*32);
    wire [127:0] w_data_line = w_data_buf << (word_offset*32);

    wire [LINE_WIDTH-1:0] w_line_arr [0:WAY_NUM-1];
    generate
        for (gi = 0; gi < WAY_NUM; gi = gi + 1) begin : w_line_gen
            assign w_line_arr[gi] = (hit_way_arr[gi] && (CS==READ || CS==WRITE)) ?
                                    (r_line_arr[gi] & ~w_line_mask) | w_data_line :
                                    (refill && way_to_replace_reg == gi) ?
                                    (ret_buf & ~w_line_mask) | w_data_line :
                                    ret_buf;
        end
    endgenerate

    // ========== Age 更新逻辑（年龄法，使用锁存的 way_to_replace_reg） ==========
    integer age_i, age_j;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            for (age_i = 0; age_i < SET_NUM; age_i = age_i + 1)
                for (age_j = 0; age_j < WAY_NUM; age_j = age_j + 1)
                    age[age_i * WAY_NUM + age_j] <= 0;
        end else begin
            if (hit && (CS == READ || CS == WRITE)) begin
                // 命中：命中路清零，其他路 Age 加 1（饱和至 WAY_NUM-1）
                for (age_j = 0; age_j < WAY_NUM; age_j = age_j + 1) begin
                    if (hit_way_arr[age_j])
                        age[w_index * WAY_NUM + age_j] <= 0;
                    else if (age[w_index * WAY_NUM + age_j] < WAY_NUM - 1)
                        age[w_index * WAY_NUM + age_j] <= age[w_index * WAY_NUM + age_j] + 1;
                end
            end else if (refill) begin
                // 填充：被替换路清零，其他路 Age 加 1（饱和）
                for (age_j = 0; age_j < WAY_NUM; age_j = age_j + 1) begin
                    if (age_j == way_to_replace_reg)
                        age[w_index * WAY_NUM + age_j] <= 0;
                    else if (age[w_index * WAY_NUM + age_j] < WAY_NUM - 1)
                        age[w_index * WAY_NUM + age_j] <= age[w_index * WAY_NUM + age_j] + 1;
                end
            end
        end
    end

    // ========== 状态机与控制 ==========
    always @(posedge clk or negedge rstn) begin
        if (!rstn) CS <= IDLE;
        else CS <= NS;
    end

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            addr_buf <= 0; ret_buf <= 0; w_data_buf <= 0;
            op_buf <= 0; refill <= 0;
            dirty_mem_addr_buf <= 0; dirty_mem_data_buf <= 0;
            way_to_replace_reg <= 0;
        end else begin
            if (addr_buf_we) begin
                addr_buf <= addr; w_data_buf <= w_data; op_buf <= w_req;
            end
            if (ret_buf_we) ret_buf <= mem_r_data;
            // refill 信号：在 MISS 状态且 mem_ready 时置1，下一周期 IDLE 中使用
            if (CS == MISS && mem_ready) begin
                refill <= 1;
            end
            if (CS == IDLE) begin
                refill <= 0;
            end
            // 锁存替换路：在 READ/WRITE 状态中，如果 miss，则锁存当前组合逻辑的 way_to_replace
            if ((CS == READ || CS == WRITE) && miss) begin
                way_to_replace_reg <= way_to_replace;
            end
            // 脏块写回缓冲：在 READ/WRITE 状态中，如果 miss 且被替换路为脏，则锁存脏地址和数据
            if ((CS == READ || CS == WRITE) && miss && dirty_arr[way_to_replace]) begin
                dirty_mem_addr_buf <= dirty_mem_addr_replace;
                dirty_mem_data_buf <= r_line_replace;
            end
        end
    end

    generate
        for (gi = 0; gi < WAY_NUM; gi = gi + 1) begin : way_block
            bram #(.ADDR_WIDTH(INDEX_WIDTH), .DATA_WIDTH(TAG_WIDTH+2))
            tag_bram (.clk(clk), .raddr(r_index), .waddr(w_index),
                      .din({w_valid_arr[gi], w_dirty_arr[gi], tag}),
                      .we(tag_we_arr[gi]),
                      .dout({valid_arr[gi], dirty_arr[gi], r_tag_arr[gi]}));
            bram #(.ADDR_WIDTH(INDEX_WIDTH), .DATA_WIDTH(LINE_WIDTH))
            data_bram (.clk(clk), .raddr(r_index), .waddr(w_index),
                       .din(w_line_arr[gi]), .we(data_we_arr[gi]),
                       .dout(r_line_arr[gi]));
        end
    endgenerate

    // 次态逻辑
    always @(*) begin
        case (CS)
            IDLE:    NS = r_req ? READ : (w_req ? WRITE : IDLE);
            READ:    NS = miss ? (dirty_arr[way_to_replace] ? W_DIRTY : MISS) :
                                  (r_req ? READ : (w_req ? WRITE : IDLE));
            WRITE:   NS = miss ? (dirty_arr[way_to_replace] ? W_DIRTY : MISS) :
                                  (r_req ? READ : (w_req ? WRITE : IDLE));
            MISS:    NS = mem_ready ? IDLE : MISS;
            W_DIRTY: NS = mem_ready ? MISS : W_DIRTY;
            default: NS = IDLE;
        endcase
    end

    // 输出控制（关键：只允许 W_DIRTY 状态发出 mem_w）
    always @(*) begin
        addr_buf_we = 0; ret_buf_we = 0; data_from_mem = 0;
        miss = 0; mem_r = 0; mem_w = 0; mem_addr = 0; mem_w_data = 0;
        data_we_arr = 0; tag_we_arr = 0; w_valid_arr = 0; w_dirty_arr = 0;
        case (CS)
            IDLE: begin
                addr_buf_we = 1;  // 始终采样新请求（即使 refill，非阻塞赋值特性保证填充使用旧addr_buf）
                if (refill) begin
                    data_from_mem = 1;
                    data_we_arr[way_to_replace_reg] = 1;
                    tag_we_arr[way_to_replace_reg]  = 1;
                    w_valid_arr[way_to_replace_reg] = 1;
                    w_dirty_arr[way_to_replace_reg] = op_buf;
                end
            end
            READ: begin
                if (hit) addr_buf_we = 1;
                else miss = 1;
                // 不在此处发出 mem_w
            end
            WRITE: begin
                if (hit) begin
                    addr_buf_we = 1;
                    data_we_arr[hit_way_idx] = 1;
                    tag_we_arr[hit_way_idx]  = 1;
                    w_valid_arr[hit_way_idx] = 1;
                    w_dirty_arr[hit_way_idx] = 1;
                end else begin
                    miss = 1;
                end
                // 不在此处发出 mem_w
            end
            MISS: begin
                miss = 1; mem_r = 1; mem_addr = addr_buf;
                if (mem_ready) begin mem_r = 0; ret_buf_we = 1; end
            end
            W_DIRTY: begin
                miss = 1; mem_w = 1;
                mem_addr = dirty_mem_addr_buf; mem_w_data = dirty_mem_data_buf;
                if (mem_ready) mem_w = 0;
            end
        endcase
    end

endmodule