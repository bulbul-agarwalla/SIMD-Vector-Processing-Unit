// =============================================================================
// Module      : control_unit
// Project     : 8-Lane SIMD Vector Processing Unit
// Author      : Shourya Pratap
// Description : Combinational SIMD Control Unit and Opcode Decoder.
//               Accepts a 3-bit instruction opcode, decodes it, produces a
//               3-bit ALU control opcode that is broadcast to all eight SIMD
//               lanes, and asserts operation_valid for supported operations.
//               Invalid opcodes (101, 110, 111) are handled safely by
//               defaulting to opcode 000 (ADD) while de-asserting valid.
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
    output reg        operation_valid  // 1 = valid operation; 0 = invalid / NOP
);

    // =========================================================================
    // Opcode Definitions (parameters for readability)
    // =========================================================================
    localparam OP_ADD = 3'b000;   // Addition
    localparam OP_SUB = 3'b001;   // Subtraction
    localparam OP_AND = 3'b010;   // Bitwise AND
    localparam OP_OR  = 3'b011;   // Bitwise OR
    localparam OP_LT  = 3'b100;   // Less-Than comparison

    localparam OP_SAFE_DEFAULT = 3'b000; // Safe default for invalid opcodes

    // =========================================================================
    // Combinational Decode Logic
    // =========================================================================
    always @(*) begin

        case (opcode)

            OP_ADD: begin
                alu_opcode      = OP_ADD;
                operation_valid = 1'b1;
            end

            OP_SUB: begin
                alu_opcode      = OP_SUB;
                operation_valid = 1'b1;
            end

            OP_AND: begin
                alu_opcode      = OP_AND;
                operation_valid = 1'b1;
            end

            OP_OR: begin
                alu_opcode      = OP_OR;
                operation_valid = 1'b1;
            end

            OP_LT: begin
                alu_opcode      = OP_LT;
                operation_valid = 1'b1;
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
            end

        endcase

    end

endmodule
