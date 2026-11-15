`timescale 1ns/1ps

module simd_processor_top_tb;
    reg clk;
    reg reset;
    reg write_enable_a;
    reg write_enable_b;
    reg [63:0] data_in_a;
    reg [63:0] data_in_b;
    reg [2:0] opcode;

    wire [63:0] result;
    wire operation_valid;
    wire [4:0] op_select;
    wire [63:0] vector_a;
    wire [63:0] vector_b;

    integer checks;
    integer lane;

    localparam [2:0] OP_ADD = 3'b000;
    localparam [2:0] OP_SUB = 3'b001;
    localparam [2:0] OP_AND = 3'b010;
    localparam [2:0] OP_OR  = 3'b011;
    localparam [2:0] OP_LT  = 3'b100;

    simd_processor_top dut (
        .clk(clk),
        .reset(reset),
        .write_enable_a(write_enable_a),
        .write_enable_b(write_enable_b),
        .data_in_a(data_in_a),
        .data_in_b(data_in_b),
        .opcode(opcode),
        .result(result),
        .operation_valid(operation_valid),
        .op_select(op_select),
        .vector_a(vector_a),
        .vector_b(vector_b)
    );

    always #5 clk = ~clk;

    function automatic [63:0] reference_result;
        input [63:0] lhs;
        input [63:0] rhs;
        input [2:0] op;
        integer idx;
        reg [7:0] a_byte;
        reg [7:0] b_byte;
        begin
            reference_result = 64'd0;
            for (idx = 0; idx < 8; idx = idx + 1) begin
                a_byte = lhs[idx*8 +: 8];
                b_byte = rhs[idx*8 +: 8];
                case (op)
                    OP_ADD: reference_result[idx*8 +: 8] = a_byte + b_byte;
                    OP_SUB: reference_result[idx*8 +: 8] = a_byte - b_byte;
                    OP_AND: reference_result[idx*8 +: 8] = a_byte & b_byte;
                    OP_OR:  reference_result[idx*8 +: 8] = a_byte | b_byte;
                    OP_LT:  reference_result[idx*8 +: 8] = (a_byte < b_byte) ? 8'd1 : 8'd0;
                    default: reference_result[idx*8 +: 8] = 8'd0;
                endcase
            end
        end
    endfunction

    function automatic [4:0] expected_select;
        input [2:0] op;
        begin
            case (op)
                OP_ADD: expected_select = 5'b00001;
                OP_SUB: expected_select = 5'b00010;
                OP_AND: expected_select = 5'b00100;
                OP_OR:  expected_select = 5'b01000;
                OP_LT:  expected_select = 5'b10000;
                default: expected_select = 5'b00000;
            endcase
        end
    endfunction

    task automatic check_state;
        input [8*64-1:0] label_text;
        input [63:0] expected_a;
        input [63:0] expected_b;
        begin
            checks = checks + 1;
            if (vector_a !== expected_a || vector_b !== expected_b)
                $fatal(1, "FAIL %0s: A expected %016h got %016h; B expected %016h got %016h",
                       label_text, expected_a, vector_a, expected_b, vector_b);
            $display("PASS %0s", label_text);
        end
    endtask

    task automatic check_operation;
        input [8*64-1:0] label_text;
        input [2:0] op;
        input [63:0] expected_value;
        reg expected_valid;
        begin
            expected_valid = (op <= OP_LT);
            opcode = op;
            #1;

            checks = checks + 1;
            if (operation_valid !== expected_valid)
                $fatal(1, "FAIL %0s valid: expected %b got %b", label_text, expected_valid, operation_valid);

            checks = checks + 1;
            if (op_select !== expected_select(op))
                $fatal(1, "FAIL %0s select: expected %05b got %05b", label_text, expected_select(op), op_select);

            checks = checks + 1;
            if (result !== expected_value)
                $fatal(1, "FAIL %0s result: expected %016h got %016h", label_text, expected_value, result);
            $display("PASS %0s opcode=%03b result=%016h", label_text, op, result);
        end
    endtask

    task automatic write_operands;
        input write_a;
        input write_b;
        input [63:0] next_a;
        input [63:0] next_b;
        begin
            @(negedge clk);
            reset = 1'b0;
            write_enable_a = write_a;
            write_enable_b = write_b;
            data_in_a = next_a;
            data_in_b = next_b;
            @(posedge clk);
            #1;
        end
    endtask

    task automatic check_current_operation;
        input [8*64-1:0] label_text;
        input [2:0] op;
        begin
            check_operation(label_text, op, reference_result(vector_a, vector_b, op));
        end
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b0;
        write_enable_a = 1'b0;
        write_enable_b = 1'b0;
        data_in_a = 64'd0;
        data_in_b = 64'd0;
        opcode = OP_ADD;
        checks = 0;

        // Synchronous reset has priority over both asserted write enables.
        @(negedge clk);
        reset = 1'b1;
        write_enable_a = 1'b1;
        write_enable_b = 1'b1;
        data_in_a = 64'hffff_ffff_ffff_ffff;
        data_in_b = 64'hffff_ffff_ffff_ffff;
        @(posedge clk);
        #1;
        check_state("reset clears both vectors and wins over writes", 64'd0, 64'd0);

        // Independent writes, then simultaneous write and hold behavior.
        write_operands(1'b1, 1'b0, 64'h0123_4567_89ab_cdef, 64'h1111_2222_3333_4444);
        check_state("write A only", 64'h0123_4567_89ab_cdef, 64'd0);
        write_operands(1'b0, 1'b1, 64'h5555_5555_5555_5555, 64'hfedc_ba98_7654_3210);
        check_state("write B only while A holds", 64'h0123_4567_89ab_cdef, 64'hfedc_ba98_7654_3210);
        write_operands(1'b1, 1'b1, 64'h0a14_1e28_323c_4650, 64'h0102_0304_0506_0708);
        check_state("simultaneous writes", 64'h0a14_1e28_323c_4650, 64'h0102_0304_0506_0708);
        write_operands(1'b0, 1'b0, 64'hffff_ffff_ffff_ffff, 64'h0000_0000_0000_0000);
        check_state("disabled writes hold both vectors", 64'h0a14_1e28_323c_4650, 64'h0102_0304_0506_0708);

        // Reset stored nonzero values, then load distinct lane data including
        // overflow, underflow, equality and mixed comparison relations.
        @(negedge clk);
        reset = 1'b1;
        write_enable_a = 1'b0;
        write_enable_b = 1'b0;
        @(posedge clk);
        #1;
        check_state("reset clears previously stored operands", 64'd0, 64'd0);
        write_operands(1'b1, 1'b1,
            {8'd255, 8'd0, 8'd10, 8'd200, 8'd128, 8'd1, 8'd42, 8'd5},
            {8'd1, 8'd255, 8'd20, 8'd100, 8'd128, 8'd2, 8'd42, 8'd9});
        check_state("load eight distinct mixed boundary lanes",
            {8'd255, 8'd0, 8'd10, 8'd200, 8'd128, 8'd1, 8'd42, 8'd5},
            {8'd1, 8'd255, 8'd20, 8'd100, 8'd128, 8'd2, 8'd42, 8'd9});

        check_current_operation("vector ADD with overflow wraparound", OP_ADD);
        check_current_operation("vector SUB with underflow wraparound", OP_SUB);
        check_current_operation("vector AND", OP_AND);
        check_current_operation("vector OR", OP_OR);
        check_current_operation("mixed per-lane unsigned LESS THAN", OP_LT);

        // Equality and greater-than checks preserve the ALU's per-byte
        // unsigned comparison result (8'd1 if less, otherwise 8'd0).
        write_operands(1'b1, 1'b1, 64'h8877_6655_4433_2211, 64'h8877_6655_4433_2211);
        check_current_operation("equal operands compare false", OP_LT);
        write_operands(1'b1, 1'b1, 64'hff_fe_fd_fc_fb_fa_f9_f8, 64'h01_02_03_04_05_06_07_08);
        check_current_operation("greater-than operands compare false", OP_LT);
        write_operands(1'b1, 1'b1, 64'h00_01_0a_32_64_7f_c8_fe, 64'h01_02_0b_33_65_80_c9_ff);
        check_current_operation("less-than operands compare true in all lanes", OP_LT);

        // Every supported opcode is also checked against the expected decode;
        // invalid encodings must select nothing and mask the ADD safe default.
        for (lane = 0; lane < 5; lane = lane + 1)
            check_current_operation("supported opcode decode and result", lane[2:0]);
        check_operation("invalid opcode 101 masks result", 3'b101, 64'd0);
        check_operation("invalid opcode 110 masks result", 3'b110, 64'd0);
        check_operation("invalid opcode 111 masks result", 3'b111, 64'd0);

        // Rapid opcode changes and repeated operations without operand writes.
        check_current_operation("rapid switch ADD", OP_ADD);
        check_current_operation("rapid switch SUB", OP_SUB);
        check_current_operation("rapid switch AND", OP_AND);
        check_current_operation("rapid switch OR", OP_OR);
        check_current_operation("rapid switch LT", OP_LT);
        check_current_operation("repeat LT without rewriting operands", OP_LT);
        check_current_operation("repeat ADD without rewriting operands", OP_ADD);

        // Reset, new writes, and another operation prove the datapath recovers.
        @(negedge clk);
        reset = 1'b1;
        write_enable_a = 1'b0;
        write_enable_b = 1'b0;
        @(posedge clk);
        #1;
        check_state("final reset", 64'd0, 64'd0);
        write_operands(1'b1, 1'b1, {8{8'hff}}, {8{8'h01}});
        check_current_operation("post-reset ADD wraps every lane", OP_ADD);

        $display("============================================================");
        $display("Integrated SIMD checks: %0d passed, 0 failed", checks);
        $display("============================================================");
        $finish;
    end
endmodule
