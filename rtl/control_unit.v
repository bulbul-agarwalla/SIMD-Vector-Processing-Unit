// =============================================================================
// Module      : control_unit
// Project     : 8-Lane SIMD Vector Processing Unit
// Author      : Shourya Pratap
// Description : Combinational SIMD Control Unit and Opcode Decoder.
//               Accepts a 3-bit instruction opcode, decodes it, produces a
//               3-bit ALU control opcode that is broadcast to all eight SIMD
//               lanes, asserts operation_valid for supported operations, and
//               provides a 5-bit one-hot op_select bus for external steering.
//               Invalid opcodes (101, 110, 111) are handled safely by
//               defaulting to opcode 000 (ADD) while de-asserting valid.
//
// Interface:
//   Inputs:
//     opcode[2:0]       – Raw 3-bit instruction opcode from instruction fetch.
//   Outputs:
//     alu_opcode[2:0]   – Decoded opcode forwarded to all 8 ALU lanes.
//     operation_valid   – 1 = supported operation; 0 = invalid / NOP.
//     op_select[4:0]    – One-hot decode: {LT, OR, AND, SUB, ADD}.
//
// Opcode Table:
//   000  ADD  – Vector addition
//   001  SUB  – Vector subtraction
//   010  AND  – Bitwise AND
//   011  OR   – Bitwise OR
//   100  LT   – Less-than comparison
//   101  ---  – INVALID (safe default applied)
//   110  ---  – INVALID (safe default applied)
//   111  ---  – INVALID (safe default applied)
// =============================================================================

module control_unit (
    // -------------------------------------------------------------------------
    // Inputs
    // -------------------------------------------------------------------------
    input  wire [2:0] opcode,          // Raw 3-bit instruction opcode

    // -------------------------------------------------------------------------
    // Outputs
    // -------------------------------------------------------------------------
    output reg  [2:0] alu_opcode,      // Decoded ALU control opcode for all 8 lanes
    output reg        operation_valid, // 1 = valid operation; 0 = invalid / NOP
    output reg  [4:0] op_select        // One-hot: bit4=LT, bit3=OR, bit2=AND, bit1=SUB, bit0=ADD
);

    // =========================================================================
    // Opcode Definitions (localparams for synthesisability and readability)
    // =========================================================================
    localparam OP_ADD = 3'b000;   // Addition
    localparam OP_SUB = 3'b001;   // Subtraction
    localparam OP_AND = 3'b010;   // Bitwise AND
    localparam OP_OR  = 3'b011;   // Bitwise OR
    localparam OP_LT  = 3'b100;   // Less-Than comparison

    localparam OP_SAFE_DEFAULT = 3'b000; // Safe default for invalid opcodes

    // One-hot bit positions
    localparam SEL_ADD = 5'b00001;
    localparam SEL_SUB = 5'b00010;
    localparam SEL_AND = 5'b00100;
    localparam SEL_OR  = 5'b01000;
    localparam SEL_LT  = 5'b10000;

    // =========================================================================
    // Combinational Decode Logic
    // =========================================================================
    always @(*) begin

        case (opcode)

            OP_ADD: begin
                alu_opcode      = OP_ADD;
                operation_valid = 1'b1;
                op_select       = SEL_ADD;
            end

            OP_SUB: begin
                alu_opcode      = OP_SUB;
                operation_valid = 1'b1;
                op_select       = SEL_SUB;
            end

            OP_AND: begin
                alu_opcode      = OP_AND;
                operation_valid = 1'b1;
                op_select       = SEL_AND;
            end

            OP_OR: begin
                alu_opcode      = OP_OR;
                operation_valid = 1'b1;
                op_select       = SEL_OR;
            end

            OP_LT: begin
                alu_opcode      = OP_LT;
                operation_valid = 1'b1;
                op_select       = SEL_LT;
            end

            // -----------------------------------------------------------------
            // Invalid opcodes: 3'b101, 3'b110, 3'b111
            // Safe default: pass ADD opcode so ALUs produce a deterministic
            // result, but assert operation_valid = 0 so the datapath can
            // suppress or discard the output.
            // -----------------------------------------------------------------
            default: begin
                alu_opcode      = OP_SAFE_DEFAULT;
                operation_valid = 1'b0;
                op_select       = 5'b00000; // No operation selected
            end

        endcase

    end

endmodule
