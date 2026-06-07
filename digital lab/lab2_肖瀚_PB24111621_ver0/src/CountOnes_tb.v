   `timescale 1ns / 1ps

module tb_CountOnes();
    reg [31:0] a;
    reg [4:0] b, c;
    wire [5:0] out;

    integer passed = 0;
    integer failed = 0;
    integer test_num = 0;

    CountOnes uut (.a(a), .b(b), .c(c), .out(out));

    function automatic [5:0] manual_count;
        input [31:0] data;
        input [5:0] start, end_bit;
        integer i;
        reg [5:0] count;
        begin
            count = 0;
            for (i = start; i <= end_bit; i = i + 1) begin
                if (data[i]) count = count + 1;
            end
            manual_count = count;
        end
    endfunction

    task run_test;
        input [31:0] test_a;
        input [5:0] test_b, test_c;
        reg [5:0] manual_result;
        reg [5:0] expected;
        begin
            test_num = test_num + 1;
            a = test_a;
            b = test_b;
            c = test_c;
            #20;

            manual_result = manual_count(test_a, test_b, test_c);
            expected = manual_result; // 预期结果就是手动计算的结果

            $display("Test %0d: a=32'h%h, b=%0d, c=%0d", 
                     test_num, test_a, test_b, test_c);
            $display("  Expected: %0d, Actual: %0d", 
                     expected, out);

            if (out === expected) begin
                $display("  PASS");
                passed = passed + 1;
            end else begin
                $display("  FAILED");
                failed = failed + 1;
            end
            $display("");
        end
    endtask

    // 生成随机但保证b<=c的测试
    task random_test;
        integer i;
        reg [31:0] rand_a;
        reg [4:0] rand_b, rand_c;
        begin
            for (i = 0; i < 30; i = i + 1) begin
                rand_a = $random;
                rand_b = $random & 5'b11111; // 确保在0-31范围内
                rand_c = $random & 5'b11111;

                // 保证b<=c
                if (rand_b > rand_c) begin
                    rand_b = rand_b ^ rand_c;
                    rand_c = rand_b ^ rand_c;
                    rand_b = rand_b ^ rand_c;
                end

                run_test(rand_a, rand_b, rand_c);
            end
        end
    endtask

    initial begin
        $display("CountOnes Test Suite (Randomized with b<=c guarantee)");
        $display("====================================================");

        // 特定边界测试用例
        $display("--- Specific Boundary Tests ---");
        // 1. 全0测试
        run_test(32'h00000000, 0, 31);

        // 2. 全1测试
        run_test(32'hFFFFFFFF, 0, 31);

        // 3. 单个位测试 - 最低位
        run_test(32'h00000001, 0, 0);

        // 4. 单个位测试 - 最高位
        run_test(32'h80000000, 31, 31);

        // 5. 交替模式测试
        run_test(32'hAAAAAAAA, 0, 31);

        // 6. 小范围测试
        run_test(32'h0000000F, 0, 3);

        // 7. 中间范围测试
        run_test(32'h0000FF00, 8, 15);

        // 8. 相同起始结束位置
        run_test(32'h00000008, 3, 3);

        // 9. 部分范围测试 - 低16位
        run_test(32'h0000FFFF, 0, 15);

        // 10. 部分范围测试 - 高16位
        run_test(32'hFFFF0000, 16, 31);

        $display("--- Randomized Tests ---");
        // 随机测试用例
        random_test();

        $display("TEST SUMMARY");
        $display("=========================================");
        $display("Total tests:  %0d", test_num);
        $display("Passed:       %0d", passed);
        $display("Failed:       %0d", failed);

        if (failed == 0) begin
            $display("SUCCESS: All tests passed!");
        end else begin
            $display("ERROR: %0d tests failed!", failed);
        end

        $finish;
    end
endmodule