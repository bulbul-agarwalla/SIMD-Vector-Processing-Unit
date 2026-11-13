// Vector Register File for the 8-lane SIMD Vector Processing Unit.
//
// Holds the two 64-bit source operands (Vector A and Vector B) that feed
// simd_top. Each vector packs eight 8-bit lanes: lane i = vector[i*8 +: 8].
//
// - Updates on the rising edge of clk.
// - reset is active-high and synchronous; it clears both vectors and takes
//   priority over the write enables.
// - write_enable_a / write_enable_b are independent; when an enable is low
//   that register keeps its previous value.

`timescale 1ns / 1ps

module vector_register (
    input             clk,
    input             reset,
    input             write_enable_a,
    input             write_enable_b,
    input      [63:0] data_in_a,
    input      [63:0] data_in_b,
    output reg [63:0] vector_a,
    output reg [63:0] vector_b
);

always @(posedge clk) begin
    if (reset) begin
        vector_a <= 64'd0;
        vector_b <= 64'd0;
    end else begin
        if (write_enable_a)
            vector_a <= data_in_a;
        if (write_enable_b)
            vector_b <= data_in_b;
    end
end

endmodule
