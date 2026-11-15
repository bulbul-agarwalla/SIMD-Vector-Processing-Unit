module scalar_performance_tb;

reg clk;
reg [63:0] A, B;
reg [2:0] opcode;

reg [7:0] scalar_result;
reg [63:0] scalar_vector_result;

wire [63:0] simd_result;

integer i;
integer scalar_cycles;

simd_top simd_unit (
    .A(A),
    .B(B),
    .opcode(opcode),
    .result(simd_result)
);

// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// One 8-bit scalar ALU operation
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

initial begin

    A = {8'd10, 8'd20, 8'd30, 8'd40,
         8'd50, 8'd60, 8'd70, 8'd80};

    B = {8'd1, 8'd2, 8'd3, 8'd4,
         8'd5, 8'd6, 8'd7, 8'd8};

    opcode = 3'b000;

    scalar_vector_result = 64'd0;
    scalar_cycles = 0;

    $display("\n===== CLOCKED SCALAR PERFORMANCE MODEL =====");

    // Process eight elements sequentially
    for (i = 0; i < 8; i = i + 1) begin

        @(posedge clk);

        scalar_result = scalar_alu(
            A[i*8 +: 8],
            B[i*8 +: 8],
            opcode
        );

        scalar_vector_result[i*8 +: 8] = scalar_result;

        scalar_cycles = scalar_cycles + 1;

        $display(
            "Cycle %0d: Element %0d | A=%0d | B=%0d | Result=%0d",
            scalar_cycles, i,
            A[i*8 +: 8],
            B[i*8 +: 8],
            scalar_result
        );

    end

    #1;

    $display("\n===== PERFORMANCE SUMMARY =====");

    $display("Scalar ALUs             : 1");
    $display("SIMD ALUs               : 8");
    $display("Elements per scalar cycle: 1");
    $display("Elements per SIMD evaluation: 8");
    $display("Scalar model cycles     : %0d", scalar_cycles);

    $display("\nScalar result : %h", scalar_vector_result);
    $display("SIMD result   : %h", simd_result);

    if (scalar_vector_result === simd_result)
        $display("VERIFICATION: PASSED");
    else
        $display("VERIFICATION: FAILED");

    $finish;

end

endmodule

