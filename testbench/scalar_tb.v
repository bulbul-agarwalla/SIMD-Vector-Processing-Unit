module scalar_tb;

reg [63:0] A, B;
reg [2:0] opcode;

wire [63:0] simd_result;
reg  [63:0] scalar_result;

integer i;
integer passed;
integer failed;

// Existing SIMD design
simd_top simd_unit (
    .A(A),
    .B(B),
    .opcode(opcode),
    .result(simd_result)
);

// Scalar ALU model: one 8-bit operation at a time
function automatic [7:0] scalar_alu(
    input [7:0] x,
    input [7:0] y,
    input [2:0] op
);
begin
    case (op)
        3'b000: scalar_alu = x + y;
        3'b001: scalar_alu = x - y;
        3'b010: scalar_alu = x & y;
        3'b011: scalar_alu = x | y;
        3'b100: scalar_alu = (x < y) ? 8'd1 : 8'd0;
        default: scalar_alu = 8'd0;
    endcase
end
endfunction

// Process all eight elements sequentially and compare
task automatic check_operation(input [2:0] op);
begin
    opcode = op;
    #10;

    for (i = 0; i < 8; i = i + 1) begin
        scalar_result[i*8 +: 8] =
            scalar_alu(A[i*8 +: 8], B[i*8 +: 8], opcode);
    end

    if (scalar_result === simd_result) begin
        $display("PASS: Opcode %b | Scalar = %h | SIMD = %h",
                 opcode, scalar_result, simd_result);
        passed = passed + 1;
    end
    else begin
        $display("FAIL: Opcode %b | Scalar = %h | SIMD = %h",
                 opcode, scalar_result, simd_result);
        failed = failed + 1;
    end
end
endtask

initial begin
    passed = 0;
    failed = 0;
    scalar_result = 64'd0;

    A = {8'd10, 8'd20, 8'd30, 8'd40,
         8'd50, 8'd60, 8'd70, 8'd80};

    B = {8'd1, 8'd2, 8'd3, 8'd4,
         8'd5, 8'd6, 8'd7, 8'd8};

    $display("\n===== SCALAR vs SIMD VERIFICATION =====");

    check_operation(3'b000); // ADD
    check_operation(3'b001); // SUB
    check_operation(3'b010); // AND
    check_operation(3'b011); // OR
    check_operation(3'b100); // LESS THAN
    check_operation(3'b101); // Invalid opcode

    $display("\n===== FINAL SUMMARY =====");
    $display("Total tests : %0d", passed + failed);
    $display("Passed      : %0d", passed);
    $display("Failed      : %0d", failed);

    if (failed == 0)
        $display("RESULT: ALL TESTS PASSED");
    else
        $display("RESULT: SOME TESTS FAILED");

    $finish;
end

endmodule
