# 8-Lane SIMD Vector Processing Unit

Design, implementation, and comprehensive verification of an 8-lane SIMD (Single Instruction, Multiple Data) Vector Processing Unit in Verilog HDL.

---

## Architecture Overview

- **Lanes**: 8 parallel processing units (Lane 0 to Lane 7)
- **Data Width**: 8-bit unsigned data per lane (64-bit vector registers)
- **Instruction Width**: 3-bit shared opcode
- **Implementation**: Pure combinational datapath

### Supported ALU Operations

| Opcode | Operation | Expression |
|:------:|:---------:|:-----------|
| `3'b000` | Vector Addition (ADD) | `result = A + B` (modulo 256) |
| `3'b001` | Vector Subtraction (SUB) | `result = A - B` (modulo 256) |
| `3'b010` | Bitwise AND (AND) | `result = A & B` |
| `3'b011` | Bitwise OR (OR) | `result = A \| B` |
| `3'b100` | Less-Than Comparison (LT) | `result = (A < B) ? 8'd1 : 8'd0` |

---

## Directory Structure

```
.
├── rtl/
│   ├── alu.v                 # Single 8-bit ALU lane
│   ├── simd_top.v            # 8-lane top-level SIMD module
│   ├── control_unit.v        # Opcode decoder & control unit
│   ├── opcode_defs.vh        # Shared opcode macro definitions
│   └── vector_register.v     # 64-bit vector register file
├── testbench/
│   ├── alu_tb.v              # Single-lane ALU testbench
│   ├── simd_tb.v             # Basic SIMD testbench
│   ├── simd_verification_tb.v# Comprehensive self-checking verification testbench
│   ├── control_tb.v          # Control unit testbench
│   └── register_tb.v         # Vector register testbench
├── results/
│   ├── simulation_results.md # Full verification test log & report
│   ├── test_cases.md         # Detailed test vector specifications
│   ├── simd_verification_sim.log # Simulation terminal transcript
│   ├── control_unit.md
│   └── vector_register.md
└── README.md
```

---

## Simulation & Verification

### Prerequisites
- [Icarus Verilog](http://iverilog.icarus.com/) (`iverilog` & `vvp`)
- [GTKWave](https://gtkwave.sourceforge.net/) (optional, for waveform inspection)

### Run Comprehensive SIMD Verification
```bash
# Compile
iverilog -g2012 \
  -o verify_sim \
  rtl/alu.v \
  rtl/simd_top.v \
  testbench/simd_verification_tb.v

# Execute simulation
vvp verify_sim
```

### Waveform Inspection
Waveforms are generated as `simd_verification.vcd` and can be inspected using GTKWave:
```bash
gtkwave simd_verification.vcd
```

---

## Verification Summary

The comprehensive verification suite covers **184 automated lane checks** across 7 test categories:
1. **Vector Addition**: Verified arithmetic addition across all 8 lanes.
2. **Vector Subtraction**: Verified positive differences, zero equality, and underflow wraparound ($0 - 1 = 255$).
3. **Bitwise AND**: Tested complementary and masking bit patterns on each lane.
4. **Bitwise OR**: Tested complementary and identity properties on each lane.
5. **Comparison (Less-Than)**: Tested $A < B$, $A == B$, $A > B$, and mixed conditions.
6. **Boundary & Edge Testing**: Verified zeros, 255, overflow wraparound, and boundary conditions.
7. **Rapid Dynamic Opcode Switching**: Stress-tested combinational updates under 2 ns switching.

All 184 checks passed with zero errors. Full details can be found in [`results/simulation_results.md`](results/simulation_results.md).
