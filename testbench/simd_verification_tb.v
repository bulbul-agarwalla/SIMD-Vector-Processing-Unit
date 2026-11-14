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
        $display(" [Skeleton] No tests yet.");

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
