# SIMD Control Unit and Opcode Decoder – Simulation Results

## Module: `rtl/control_unit.v`
## Testbench: `testbench/control_tb.v`
## Author: Shourya Pratap
## Branch: `feature/control-unit`
## Closes: #3

---

## Overview

The `control_unit` module is a pure combinational opcode decoder for the 8-Lane SIMD Vector Processing Unit. It sits between the instruction fetch stage and the eight parallel ALU lanes, translating a 3-bit instruction opcode into:

1. **`alu_opcode[2:0]`** – The decoded control opcode, broadcast identically to all 8 ALU lanes.
2. **`operation_valid`** – Asserted high for all five supported operations; de-asserted for invalid opcodes.
3. **`op_select[4:0]`** – A one-hot bus for downstream steering logic (bit 0 = ADD, 1 = SUB, 2 = AND, 3 = OR, 4 = LT).

---

## Opcode Mapping

| Opcode (binary) | Operation    | `alu_opcode` | `operation_valid` | `op_select` |
|:---------------:|:-------------|:------------:|:-----------------:|:-----------:|
| `000`           | ADD          | `000`        | `1`               | `00001`     |
| `001`           | SUB          | `001`        | `1`               | `00010`     |
| `010`           | AND          | `010`        | `1`               | `00100`     |
| `011`           | OR           | `011`        | `1`               | `01000`     |
| `100`           | LESS THAN    | `100`        | `1`               | `10000`     |
| `101`           | **INVALID**  | `000`        | `0`               | `00000`     |
| `110`           | **INVALID**  | `000`        | `0`               | `00000`     |
| `111`           | **INVALID**  | `000`        | `0`               | `00000`     |

---

## Module Interface

```verilog
module control_unit (
    input  wire [2:0] opcode,          // 3-bit instruction opcode
    output reg  [2:0] alu_opcode,      // Decoded opcode → all 8 ALU lanes
    output reg        operation_valid, // 1 = valid; 0 = invalid / NOP
    output reg  [4:0] op_select        // One-hot operation select
);
```

---

## Implementation Details

- **Fully combinational** – uses `always @(*)` and a `case` statement; no clocked logic.
- **Synthesisable** – uses only `localparam`, `reg` assigned in `always @(*)`, and binary literals.
- **Safe defaults** – invalid opcodes (`101`, `110`, `111`) produce `alu_opcode = 000` (ADD) so ALUs never receive an `x` or `z`, while `operation_valid = 0` signals the datapath to suppress results.
- **Preserves existing opcode convention** – the decoded `alu_opcode` values are identical to the opcodes already used by `rtl/alu.v`; no changes were made to the ALU.
- **Broadcast architecture** – the same `alu_opcode` is wired to all 8 lanes (this matches the existing `simd_top.v` topology where all lanes share one opcode).

---

## Test Cases and Simulation Results

Compile command:
```
iverilog -g2012 -o control_sim rtl/control_unit.v testbench/control_tb.v
vvp control_sim
```

| Test ID | Input Opcode | Expected `alu_opcode` | Expected `valid` | Expected `op_select` | Result |
|:-------:|:------------:|:---------------------:|:----------------:|:--------------------:|:------:|
| TC-01   | `000` (ADD)      | `000` | `1` | `00001` | ✅ PASS |
| TC-02   | `001` (SUB)      | `001` | `1` | `00010` | ✅ PASS |
| TC-03   | `010` (AND)      | `010` | `1` | `00100` | ✅ PASS |
| TC-04   | `011` (OR)       | `011` | `1` | `01000` | ✅ PASS |
| TC-05   | `100` (LESS_THAN)| `100` | `1` | `10000` | ✅ PASS |
| TC-06   | `101` (INVALID)  | `000` | `0` | `00000` | ✅ PASS |
| TC-07   | `110` (INVALID)  | `000` | `0` | `00000` | ✅ PASS |
| TC-08   | `111` (INVALID)  | `000` | `0` | `00000` | ✅ PASS |

**All 8/8 tests passed.**

---

## Simulation Terminal Output

```
================================================================
  SIMD Control Unit & Opcode Decoder – Simulation Results
================================================================
 Test                 | opcode | alu_op | valid | op_sel
----------------------------------------------------------------
[PASS] TC-01: ADD            | opcode=000 | alu_op=000 | valid=1 | op_sel=00001
[PASS] TC-02: SUB            | opcode=001 | alu_op=001 | valid=1 | op_sel=00010
[PASS] TC-03: AND            | opcode=010 | alu_op=010 | valid=1 | op_sel=00100
[PASS] TC-04: OR             | opcode=011 | alu_op=011 | valid=1 | op_sel=01000
[PASS] TC-05: LESS_THAN      | opcode=100 | alu_op=100 | valid=1 | op_sel=10000
[PASS] TC-06: INVALID_101    | opcode=101 | alu_op=000 | valid=0 | op_sel=00000
[PASS] TC-07: INVALID_110    | opcode=110 | alu_op=000 | valid=0 | op_sel=00000
[PASS] TC-08: INVALID_111    | opcode=111 | alu_op=000 | valid=0 | op_sel=00000
================================================================
 SIMULATION SUMMARY
================================================================
 Total Tests : 8
 PASSED      : 8
 FAILED      : 0
================================================================
 ALL TESTS PASSED – Control Unit verified successfully.
================================================================
```

---

## Waveform

A VCD file `control.vcd` is generated during simulation via:
```verilog
$dumpfile("control.vcd");
$dumpvars(0, control_tb);
```
Open with GTKWave: `gtkwave control.vcd`

---

## Limitations

- The current design is **purely combinational** (no pipeline register). If the system is pipelined, a register stage should be inserted by the system integrator between this module and the ALU lanes.
- `op_select` is provided for future use by write-back or hazard detection logic; existing ALU and simd_top modules do not consume it.
- The module does not currently handle X/Z inputs – for a production design, consider adding an `x`-safe decode using casez if needed.
