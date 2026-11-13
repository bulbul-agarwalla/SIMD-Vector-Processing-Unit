
module simd_top (
    input  [63:0] A,
    input  [63:0] B,
    input  [2:0] opcode,
    output [63:0] result
);

genvar i;

generate
    for (i = 0; i < 8; i = i + 1) begin : SIMD_LANES

        alu lane_alu (
            .A(A[i*8 +: 8]),
            .B(B[i*8 +: 8]),
            .opcode(opcode),
            .result(result[i*8 +: 8])
        );

    end
endgenerate

endmodule
