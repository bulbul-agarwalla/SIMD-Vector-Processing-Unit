
module simd_tb;

reg [63:0] A, B;
reg [2:0] opcode;
wire [63:0] result;

simd_top uut (
    .A(A),
    .B(B),
    .opcode(opcode),
    .result(result)
);

integer i;

initial begin

    $dumpfile("simd.vcd");
    $dumpvars(0, simd_tb);

    // Test 1: Vector Addition
    A = {8'd10, 8'd20, 8'd30, 8'd40,
         8'd50, 8'd60, 8'd70, 8'd80};

    B = {8'd1, 8'd2, 8'd3, 8'd4,
         8'd5, 8'd6, 8'd7, 8'd8};

    opcode = 3'b000;
    #10;

    $display("\nSIMD ADDITION:");

    for (i = 7; i >= 0; i = i - 1)
        $display("Lane %0d: %0d",
                 i, result[i*8 +: 8]);

    // Test 2: Subtraction
    opcode = 3'b001;
    #10;

    $display("\nSIMD SUBTRACTION:");

    for (i = 7; i >= 0; i = i - 1)
        $display("Lane %0d: %0d",
                 i, result[i*8 +: 8]);

    // Test 3: AND
    opcode = 3'b010;
    #10;

    $display("\nSIMD AND:");
    $display("Result = %h", result);

    // Test 4: OR
    opcode = 3'b011;
    #10;

    $display("\nSIMD OR:");
    $display("Result = %h", result);

    // Test 5: Comparison
    opcode = 3'b100;
    #10;

    $display("\nSIMD LESS THAN:");
    $display("Result = %h", result);

    $finish;

end

endmodule
