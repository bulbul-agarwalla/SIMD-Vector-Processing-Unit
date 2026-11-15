`timescale 1ns/1ps

// Integrated 8-lane SIMD processor wrapper.
// Operand storage updates synchronously; decode and lane execution are
// combinational after the register outputs and opcode settle.
module simd_processor_top (
    input         clk,
    input         reset,
    input         write_enable_a,
    input         write_enable_b,
    input  [63:0] data_in_a,
    input  [63:0] data_in_b,
    input  [2:0]  opcode,
    output [63:0] result,
    output        operation_valid,
    output [4:0]  op_select,
    output [63:0] vector_a,
    output [63:0] vector_b
);

    wire [2:0] alu_opcode;
    wire [63:0] datapath_result;

    vector_register operand_registers (
        .clk(clk),
        .reset(reset),
        .write_enable_a(write_enable_a),
        .write_enable_b(write_enable_b),
        .data_in_a(data_in_a),
        .data_in_b(data_in_b),
        .vector_a(vector_a),
        .vector_b(vector_b)
    );

    control_unit operation_decoder (
        .opcode(opcode),
        .alu_opcode(alu_opcode),
        .operation_valid(operation_valid),
        .op_select(op_select)
    );

    simd_top parallel_datapath (
        .A(vector_a),
        .B(vector_b),
        .opcode(alu_opcode),
        .result(datapath_result)
    );

    // The decoder defaults invalid opcodes to ADD internally; never expose
    // that safe-default datapath value as a valid architectural result.
    assign result = operation_valid ? datapath_result : 64'd0;

endmodule
