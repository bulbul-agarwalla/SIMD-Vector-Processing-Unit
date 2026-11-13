// =============================================================================
// Testbench  : control_tb
// Module DUT : control_unit
// Project    : 8-Lane SIMD Vector Processing Unit
// Author     : Shourya Pratap
// Description: Automated pass/fail testbench for the SIMD control unit.
//              Covers all five valid opcodes and all three invalid opcodes.
//              Verifies alu_opcode, operation_valid, and op_select outputs.
//              Generates a VCD waveform file for inspection in GTKWave/Surfer.
//
// Test Cases:
//   TC-01: opcode=000 (ADD)      → alu_opcode=000, valid=1, op_select=00001
//   TC-02: opcode=001 (SUB)      → alu_opcode=001, valid=1, op_select=00010
//   TC-03: opcode=010 (AND)      → alu_opcode=010, valid=1, op_select=00100
//   TC-04: opcode=011 (OR)       → alu_opcode=011, valid=1, op_select=01000
//   TC-05: opcode=100 (LESS_THAN)→ alu_opcode=100, valid=1, op_select=10000
//   TC-06: opcode=101 (INVALID)  → alu_opcode=000, valid=0, op_select=00000
//   TC-07: opcode=110 (INVALID)  → alu_opcode=000, valid=0, op_select=00000
//   TC-08: opcode=111 (INVALID)  → alu_opcode=000, valid=0, op_select=00000
// =============================================================================

`timescale 1ns/1ps

module control_tb;

    // -------------------------------------------------------------------------
    // DUT I/O
    // -------------------------------------------------------------------------
    reg  [2:0] opcode;
    wire [2:0] alu_opcode;
    wire       operation_valid;
    wire [4:0] op_select;

    // -------------------------------------------------------------------------
    // Instantiate DUT
    // -------------------------------------------------------------------------
    control_unit dut (
        .opcode         (opcode),
        .alu_opcode     (alu_opcode),
        .operation_valid(operation_valid),
        .op_select      (op_select)
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
        input [4:0]  exp_op_select;
        input [143:0] test_name;      // 18 chars max for display alignment
        begin
            #5; // combinational settle

            if ((alu_opcode      === exp_alu_opcode) &&
                (operation_valid === exp_valid)       &&
                (op_select       === exp_op_select)) begin

                $display("[PASS] %-20s | opcode=%b | alu_op=%b | valid=%b | op_sel=%b",
                         test_name, test_opcode, alu_opcode, operation_valid, op_select);
                pass_count = pass_count + 1;

            end else begin
                $display("[FAIL] %-20s | opcode=%b | alu_op=%b (exp %b) | valid=%b (exp %b) | op_sel=%b (exp %b)",
                         test_name, test_opcode,
                         alu_opcode,      exp_alu_opcode,
                         operation_valid, exp_valid,
                         op_select,       exp_op_select);
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

        $display("================================================================");
        $display("  SIMD Control Unit & Opcode Decoder – Simulation Results");
        $display("================================================================");
        $display(" %-20s | opcode | alu_op | valid | op_sel", "Test");
        $display("----------------------------------------------------------------");

        // TC-01: ADD
        opcode = 3'b000;
        check_result(opcode, 3'b000, 1'b1, 5'b00001, "TC-01: ADD");

        // TC-02: SUB
        opcode = 3'b001;
        check_result(opcode, 3'b001, 1'b1, 5'b00010, "TC-02: SUB");

        // TC-03: AND
        opcode = 3'b010;
        check_result(opcode, 3'b010, 1'b1, 5'b00100, "TC-03: AND");

        // TC-04: OR
        opcode = 3'b011;
        check_result(opcode, 3'b011, 1'b1, 5'b01000, "TC-04: OR");

        // TC-05: LESS THAN
        opcode = 3'b100;
        check_result(opcode, 3'b100, 1'b1, 5'b10000, "TC-05: LESS_THAN");

        // TC-06: Invalid 101
        opcode = 3'b101;
        check_result(opcode, 3'b000, 1'b0, 5'b00000, "TC-06: INVALID_101");

        // TC-07: Invalid 110
        opcode = 3'b110;
        check_result(opcode, 3'b000, 1'b0, 5'b00000, "TC-07: INVALID_110");

        // TC-08: Invalid 111
        opcode = 3'b111;
        check_result(opcode, 3'b000, 1'b0, 5'b00000, "TC-08: INVALID_111");

        // -----------------------------------------------------------------
        // Summary
        // -----------------------------------------------------------------
        $display("================================================================");
        $display(" SIMULATION SUMMARY");
        $display("================================================================");
        $display(" Total Tests : %0d", pass_count + fail_count);
        $display(" PASSED      : %0d", pass_count);
        $display(" FAILED      : %0d", fail_count);
        $display("================================================================");

        if (fail_count == 0) begin
            $display(" ALL TESTS PASSED – Control Unit verified successfully.");
        end else begin
            $display(" SOME TESTS FAILED – Please review the control unit.");
        end

        $display("================================================================");
        $finish;

    end

endmodule
