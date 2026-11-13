// =============================================================================
// Testbench  : control_tb
// Module DUT : control_unit
// Project    : 8-Lane SIMD Vector Processing Unit
// Author     : Shourya Pratap
// Description: Automated pass/fail testbench for the SIMD control unit.
//              Covers all five valid opcodes and all three invalid opcodes.
//              Generates a VCD waveform file for inspection in GTKWave/Surfer.
// =============================================================================

`timescale 1ns/1ps

module control_tb;

    // -------------------------------------------------------------------------
    // DUT I/O
    // -------------------------------------------------------------------------
    reg  [2:0] opcode;
    wire [2:0] alu_opcode;
    wire       operation_valid;

    // -------------------------------------------------------------------------
    // Instantiate DUT
    // -------------------------------------------------------------------------
    control_unit dut (
        .opcode         (opcode),
        .alu_opcode     (alu_opcode),
        .operation_valid(operation_valid)
    );

    // -------------------------------------------------------------------------
    // Bookkeeping
    // -------------------------------------------------------------------------
    integer pass_count;
    integer fail_count;

    // -------------------------------------------------------------------------
    // Task: check_result
    //   Compares actual outputs against expected values and prints PASS/FAIL.
    // -------------------------------------------------------------------------
    task check_result;
        input [2:0]  test_opcode;
        input [2:0]  exp_alu_opcode;
        input        exp_valid;
        input [63:0] test_id;        // string encoded as 64-bit for display
        begin
            #5; // small settle delay (combinational – should be instant)

            if ((alu_opcode === exp_alu_opcode) && (operation_valid === exp_valid)) begin
                $display("[PASS] Test %-20s | opcode=%b | alu_opcode=%b (expected %b) | valid=%b (expected %b)",
                         test_id, test_opcode,
                         alu_opcode, exp_alu_opcode,
                         operation_valid, exp_valid);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %-20s | opcode=%b | alu_opcode=%b (expected %b) | valid=%b (expected %b)",
                         test_id, test_opcode,
                         alu_opcode, exp_alu_opcode,
                         operation_valid, exp_valid);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin

        // VCD dump for waveform analysis
        $dumpfile("control.vcd");
        $dumpvars(0, control_tb);

        pass_count = 0;
        fail_count = 0;

        $display("=============================================================");
        $display(" SIMD Control Unit & Opcode Decoder – Simulation Results");
        $display("=============================================================");
        $display("");
        $display(" Test                 | Opcode | ALU Out | Valid");
        $display("------------------------------------------------------------");

        // -----------------------------------------------------------------
        // TC-01: ADD  (opcode 000) → alu_opcode 000, valid = 1
        // -----------------------------------------------------------------
        opcode = 3'b000;
        check_result(opcode, 3'b000, 1'b1, "TC-01: ADD");

        // -----------------------------------------------------------------
        // TC-02: SUB  (opcode 001) → alu_opcode 001, valid = 1
        // -----------------------------------------------------------------
        opcode = 3'b001;
        check_result(opcode, 3'b001, 1'b1, "TC-02: SUB");

        // -----------------------------------------------------------------
        // TC-03: AND  (opcode 010) → alu_opcode 010, valid = 1
        // -----------------------------------------------------------------
        opcode = 3'b010;
        check_result(opcode, 3'b010, 1'b1, "TC-03: AND");

        // -----------------------------------------------------------------
        // TC-04: OR   (opcode 011) → alu_opcode 011, valid = 1
        // -----------------------------------------------------------------
        opcode = 3'b011;
        check_result(opcode, 3'b011, 1'b1, "TC-04: OR");

        // -----------------------------------------------------------------
        // TC-05: LESS THAN (opcode 100) → alu_opcode 100, valid = 1
        // -----------------------------------------------------------------
        opcode = 3'b100;
        check_result(opcode, 3'b100, 1'b1, "TC-05: LESS_THAN");

        // -----------------------------------------------------------------
        // TC-06: Invalid opcode 101 → alu_opcode 000 (safe default), valid = 0
        // -----------------------------------------------------------------
        opcode = 3'b101;
        check_result(opcode, 3'b000, 1'b0, "TC-06: INVALID_101");

        // -----------------------------------------------------------------
        // TC-07: Invalid opcode 110 → alu_opcode 000 (safe default), valid = 0
        // -----------------------------------------------------------------
        opcode = 3'b110;
        check_result(opcode, 3'b000, 1'b0, "TC-07: INVALID_110");

        // -----------------------------------------------------------------
        // TC-08: Invalid opcode 111 → alu_opcode 000 (safe default), valid = 0
        // -----------------------------------------------------------------
        opcode = 3'b111;
        check_result(opcode, 3'b000, 1'b0, "TC-08: INVALID_111");

        // -----------------------------------------------------------------
        // Summary
        // -----------------------------------------------------------------
        $display("");
        $display("=============================================================");
        $display(" SIMULATION SUMMARY");
        $display("=============================================================");
        $display(" Total Tests : %0d", pass_count + fail_count);
        $display(" PASSED      : %0d", pass_count);
        $display(" FAILED      : %0d", fail_count);
        $display("=============================================================");

        if (fail_count == 0)
            $display(" ALL TESTS PASSED – Control Unit verified successfully.");
        else
            $display(" SOME TESTS FAILED – Please review the control unit.");

        $display("=============================================================");

        $finish;

    end

endmodule
