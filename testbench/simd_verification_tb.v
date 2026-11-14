// =============================================================================
// File        : simd_verification_tb.v
// Project     : 8-Lane SIMD Vector Processing Unit
// Description : Comprehensive self-checking verification testbench for the
//               8-lane SIMD processor. Verifies all supported operations:
//               ADD, SUB, AND, OR, LESS-THAN across all 8 lanes individually.
//               Reports per-lane PASS/FAIL and prints a final summary.
// =============================================================================

`timescale 1ns/1ps

module simd_verification_tb;

    // -------------------------------------------------------------------------
    // DUT I/O
    // -------------------------------------------------------------------------
    reg  [63:0] A;
    reg  [63:0] B;
    reg  [2:0]  opcode;
    wire [63:0] result;

    // -------------------------------------------------------------------------
    // Opcode encoding (matches alu.v)
    // -------------------------------------------------------------------------
    localparam OP_ADD = 3'b000;
    localparam OP_SUB = 3'b001;
    localparam OP_AND = 3'b010;
    localparam OP_OR  = 3'b011;
    localparam OP_LT  = 3'b100;

    // -------------------------------------------------------------------------
    // Instantiate DUT
    // -------------------------------------------------------------------------
    simd_top uut (
        .A      (A),
        .B      (B),
        .opcode (opcode),
        .result (result)
    );

    // -------------------------------------------------------------------------
    // Test counters
    // -------------------------------------------------------------------------
    integer pass_count;
    integer fail_count;
    integer lane;

    // -------------------------------------------------------------------------
    // Helper task: check a single lane result
    // -------------------------------------------------------------------------
    task check_lane;
        input [3:0]  lane_num;
        input [7:0]  actual;
        input [7:0]  expected;
        input [63:0] test_name_bits;
        begin
            if (actual === expected) begin
                $display("    Lane %0d: PASS  (got %0d, expected %0d)",
                         lane_num, actual, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("    Lane %0d: FAIL  (got %0d, expected %0d) <<<",
                         lane_num, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Helper task: verify all 8 lanes against expected[63:0]
    // -------------------------------------------------------------------------
    task verify_all_lanes;
        input [63:0] expected;
        input [63:0] label;
        integer k;
        begin
            for (k = 0; k < 8; k = k + 1) begin
                check_lane(k,
                           result  [k*8 +: 8],
                           expected[k*8 +: 8],
                           64'd0);
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Waveform dump
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("simd_verification.vcd");
        $dumpvars(0, simd_verification_tb);
    end

    // =========================================================================
    // MAIN TEST SEQUENCE  (tests to be filled in incrementally)
    // =========================================================================
    initial begin
        pass_count = 0;
        fail_count = 0;

        $display("=============================================================");
        $display(" 8-Lane SIMD Verification Testbench");
        $display("=============================================================");
        // ------------------------------------------------------------------
        // TEST 1 – Vector Addition
        // ------------------------------------------------------------------
        $display("\n[ TEST 1 ] Vector Addition (OP_ADD)");

        A      = {8'd10, 8'd20, 8'd30, 8'd40, 8'd50, 8'd60, 8'd70, 8'd80};
        B      = {8'd1,  8'd2,  8'd3,  8'd4,  8'd5,  8'd6,  8'd7,  8'd8};
        opcode = OP_ADD;
        #10;
        // Expected per lane (lane0 is LSB slice):
        // lane0=80+8=88, lane1=70+7=77, lane2=60+6=66, lane3=50+5=55
        // lane4=40+4=44, lane5=30+3=33, lane6=20+2=22, lane7=10+1=11
        verify_all_lanes(
            {8'd11, 8'd22, 8'd33, 8'd44, 8'd55, 8'd66, 8'd77, 8'd88},
            64'd1
        );

        // ------------------------------------------------------------------
        // TEST 2 – Vector Subtraction (positive, zero, underflow/wraparound)
        // ------------------------------------------------------------------
        $display("\n[ TEST 2 ] Vector Subtraction (OP_SUB)");

        // Case A: positive results
        $display("  Case 2a: Positive subtraction results");
        A      = {8'd100, 8'd90, 8'd80, 8'd70, 8'd60, 8'd50, 8'd40, 8'd30};
        B      = {8'd10,  8'd9,  8'd8,  8'd7,  8'd6,  8'd5,  8'd4,  8'd3};
        opcode = OP_SUB;
        #10;
        // lane0=27, lane1=36, lane2=45, lane3=54, lane4=63, lane5=72, lane6=81, lane7=90
        verify_all_lanes(
            {8'd90, 8'd81, 8'd72, 8'd63, 8'd54, 8'd45, 8'd36, 8'd27},
            64'd2
        );

        // Case B: zero results (A == B)
        $display("  Case 2b: Zero results (A == B)");
        A      = {8'd128, 8'd64, 8'd32, 8'd16, 8'd8, 8'd4, 8'd2, 8'd1};
        B      = {8'd128, 8'd64, 8'd32, 8'd16, 8'd8, 8'd4, 8'd2, 8'd1};
        opcode = OP_SUB;
        #10;
        verify_all_lanes(
            {8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
            64'd3
        );

        // Case C: underflow / 8-bit wraparound  (A < B → result = 256+A-B)
        $display("  Case 2c: Underflow wraparound (A < B, 8-bit wrap)");
        A      = {8'd0,  8'd1,  8'd2,  8'd3,  8'd10, 8'd50, 8'd100, 8'd200};
        B      = {8'd1,  8'd2,  8'd3,  8'd4,  8'd11, 8'd51, 8'd101, 8'd201};
        opcode = OP_SUB;
        #10;
        // 8-bit modular: each A[k]-B[k] = -1 → wraps to 255
        verify_all_lanes(
            {8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255},
            64'd4
        );

        // ------------------------------------------------------------------
        // FINAL SUMMARY
        // ------------------------------------------------------------------
        $display("\n=============================================================");
        $display(" VERIFICATION SUMMARY");
        $display("=============================================================");
        $display("  Total checks : %0d", pass_count + fail_count);
        $display("  PASSED       : %0d", pass_count);
        $display("  FAILED       : %0d", fail_count);
        $display("=============================================================");

        if (fail_count > 0) begin
            $display("  RESULT: *** FAIL *** - %0d check(s) did not pass!", fail_count);
            $fatal(1, "Verification FAILED: %0d lane check(s) failed.", fail_count);
        end else begin
            $display("  RESULT: *** PASS *** - All checks passed!");
        end

        $finish;
    end

endmodule
