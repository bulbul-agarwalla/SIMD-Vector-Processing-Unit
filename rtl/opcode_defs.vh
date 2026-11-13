// =============================================================================
// File        : opcode_defs.vh
// Project     : 8-Lane SIMD Vector Processing Unit
// Author      : Shourya Pratap
// Description : Shared opcode definitions header for the SIMD control unit.
//               Include this file in any module that needs opcode constants.
//               Usage: `include "opcode_defs.vh"
// =============================================================================

`ifndef OPCODE_DEFS_VH
`define OPCODE_DEFS_VH

// -----------------------------------------------------------------------------
// Supported ALU Operation Opcodes (3-bit)
// -----------------------------------------------------------------------------
`define OP_ADD  3'b000   // Vector Addition         : result = A + B
`define OP_SUB  3'b001   // Vector Subtraction      : result = A - B
`define OP_AND  3'b010   // Bitwise AND             : result = A & B
`define OP_OR   3'b011   // Bitwise OR              : result = A | B
`define OP_LT   3'b100   // Less-Than Comparison    : result = (A < B) ? 1 : 0

// -----------------------------------------------------------------------------
// Reserved / Invalid Opcodes
// -----------------------------------------------------------------------------
`define OP_RSVD0 3'b101  // Reserved – treat as invalid
`define OP_RSVD1 3'b110  // Reserved – treat as invalid
`define OP_RSVD2 3'b111  // Reserved – treat as invalid

// -----------------------------------------------------------------------------
// Safe Default for invalid decodes (passed to ALU but valid de-asserted)
// -----------------------------------------------------------------------------
`define OP_SAFE_DEFAULT 3'b000

`endif // OPCODE_DEFS_VH
