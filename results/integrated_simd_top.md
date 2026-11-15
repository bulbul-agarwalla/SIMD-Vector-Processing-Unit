# Integrated SIMD Processor: Architecture and Verification

## Architecture

`rtl/simd_processor_top.v` integrates the existing register, control and datapath modules without changing their interfaces:

```text
data_in_a ─┐                         ┌── vector_a ──┐
           ├─ vector_register ───────┤              ├─ simd_top (8 × ALU) ── result
data_in_b ─┘                         └── vector_b ──┘             ▲
                                                                  │ alu_opcode
opcode ─────────────────────────────── control_unit ──────────────┘
                                          ├─ operation_valid
                                          └─ op_select
```

The register file stores two 64-bit operands. Byte lane `i` is bits `[i*8 +: 8]`, so lane 0 is the least-significant byte and lane 7 is the most-significant byte. `control_unit` decodes the external opcode and supplies the ALU opcode used by all eight parallel lanes. The top exposes the stored vectors, decoded validity, one-hot operation selection, and result for integration/debugging.

## Timing and reset

`vector_register` updates on the rising edge of `clk`. Reset is active-high and synchronous, clears both vectors, and takes priority over writes. The control decoder and SIMD lanes are combinational. After a rising edge updates an operand register, the result settles combinationally from the new stored operands and current opcode. The result is **not registered** and this wrapper does not claim a one-cycle registered output latency.

For opcodes `101`, `110`, and `111`, the control unit deasserts `operation_valid`, selects no operation (`op_select=00000`), and selects safe internal opcode `000`. The top masks that internal ADD output, making the externally visible result all zero.

## Supported operations

| Opcode | `op_select` | Operation | Per-lane behavior |
|---|---:|---|---|
| `000` | `00001` | ADD | 8-bit unsigned sum, modulo 256 |
| `001` | `00010` | SUB | 8-bit unsigned subtraction, modulo 256 |
| `010` | `00100` | AND | Bitwise AND |
| `011` | `01000` | OR | Bitwise OR |
| `100` | `10000` | LESS THAN | `8'd1` if unsigned A < B, otherwise `8'd0` |

## Integrated self-checking test

Testbench: `testbench/simd_processor_top_tb.v`.

Compile:

```sh
iverilog -g2012 -Wall -I rtl -s simd_processor_top_tb \
  -o /tmp/integrated_simv \
  rtl/alu.v rtl/vector_register.v rtl/simd_top.v rtl/control_unit.v \
  rtl/simd_processor_top.v testbench/simd_processor_top_tb.v
```

Run:

```sh
vvp /tmp/integrated_simv
```

Actual run in Icarus Verilog 13.0: compile exit 0, simulation exit 0, **80 assertions passed, 0 failed**. The bench checks reset priority and clearing, independent and simultaneous writes, hold behavior, all five operation decodes/results, overflow/underflow, AND/OR, less-than/equal/greater/mixed relations, invalid opcodes and result masking, rapid opcode switching, repeated operations without rewriting, and writes/operations after reset. Failures use `$fatal`, producing a nonzero simulation exit.

## Existing simulation runs

The following were also compiled and run from the current feature branch with Icarus Verilog 13.0. All compile and simulation processes exited 0. `-Wall` produced no warnings after adding explicit timescales to the touched legacy benches and RTL modules.

| Testbench | Checks/results reported by the executed run |
|---|---|
| `alu_tb` | Display-only smoke test for the five ALU opcodes; no pass/fail assertions |
| `simd_tb` | Display-only SIMD ADD/SUB/AND/OR/LT smoke test; no pass/fail assertions |
| `register_tb` | 1023 checks passed, 0 failed |
| `control_tb` | 8 tests passed, 0 failed |
| `simd_verification_tb` | 184 checks passed, 0 failed |
| `scalar_tb` | 6 tests passed, 0 failed |
| `scalar_performance_tb` | Printed 8 scalar cycles and `VERIFICATION: PASSED`; legacy bench prints a result but does not fail the simulator on a mismatch |
| `simd_processor_top_tb` | 80 assertions passed, 0 failed |

Exact commands for the existing benches:

```sh
iverilog -g2012 -Wall -I rtl -s alu_tb -o /tmp/alu.vvp rtl/alu.v testbench/alu_tb.v
(cd /tmp && vvp /tmp/alu.vvp)
iverilog -g2012 -Wall -I rtl -s simd_tb -o /tmp/simd.vvp rtl/alu.v rtl/simd_top.v testbench/simd_tb.v
(cd /tmp && vvp /tmp/simd.vvp)
iverilog -g2012 -Wall -I rtl -s register_tb -o /tmp/register.vvp rtl/vector_register.v testbench/register_tb.v
(cd /tmp && vvp /tmp/register.vvp)
iverilog -g2012 -Wall -I rtl -s control_tb -o /tmp/control.vvp rtl/control_unit.v testbench/control_tb.v
(cd /tmp && vvp /tmp/control.vvp)
iverilog -g2012 -Wall -I rtl -s simd_verification_tb -o /tmp/simd_verification.vvp rtl/alu.v rtl/simd_top.v testbench/simd_verification_tb.v
(cd /tmp && vvp /tmp/simd_verification.vvp)
iverilog -g2012 -Wall -I rtl -s scalar_tb -o /tmp/scalar.vvp rtl/alu.v rtl/simd_top.v testbench/scalar_tb.v
(cd /tmp && vvp /tmp/scalar.vvp)
iverilog -g2012 -Wall -I rtl -s scalar_performance_tb -o /tmp/scalar_performance.vvp rtl/alu.v rtl/simd_top.v testbench/scalar_performance_tb.v
(cd /tmp && vvp /tmp/scalar_performance.vvp)
```

## Limitations

- The wrapper's result path is combinational after registered operands; there is no result register, pipeline, ready/valid protocol, or instruction sequencing controller.
- The scalar performance bench is an illustrative model, not an equivalent clocked SIMD implementation or measured hardware speed-up.
- No synthesis, FPGA resource, maximum-frequency, or timing report is produced by these simulations.
