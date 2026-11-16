# 8-Lane SIMD RTL Simulation Demonstration

This presentation demo exercises the repository's integrated `simd_processor_top` in Icarus Verilog. It is an RTL simulation, not an FPGA or physical hardware run.

## Run the demo

From the repository root:

```sh
./scripts/run_simd_demo.sh
```

The script compiles the actual RTL with `iverilog`, runs `testbench/simd_demo_tb.v` in `vvp`, prints expected and actual results plus byte-lane values, and writes `results/simd_demo.vcd`. A mismatch terminates the run with `$fatal`; successful completion reports 12 passing operation checks. No existing RTL or verification bench is modified by this demonstration.

The demo first asserts synchronous reset, loads two different 64-bit operand pairs, then executes ADD, SUB, AND, OR, LT, and invalid opcode `101` for each pair. Each byte of both vectors is distinct within its operand set, so the eight parallel lanes can be followed individually. The second operand set demonstrates changed registered inputs and repeated operations. In packed hexadecimal vectors, lane 0 is the rightmost byte `[7:0]` and lane 7 is the leftmost byte `[63:56]`.

## Open the waveform in GTKWave

Run the simulation first, then launch GTKWave from the repository root:

```sh
gtkwave results/simd_demo.vcd
```

If GTKWave is not on `PATH`, open GTKWave and load `results/simd_demo.vcd` using **File → Open New Dump File**. In the signal tree, expand `simd_demo_tb` and add these signals to the waveform pane:

- `clk`, `reset`
- `write_enable_a`, `write_enable_b`
- `data_in_a`, `data_in_b`
- `vector_a`, `vector_b`
- `opcode`, `operation_valid`, `op_select`
- `result`

Set `data_in_a`, `data_in_b`, `vector_a`, `vector_b`, and `result` to hexadecimal radix; leave `opcode` and `op_select` in binary if desired. Use **Zoom → Zoom Fit** to see the complete sequence. For a presentation, zoom in on the reset and first load, show the opcode progression `000` through `100`, point out the eight result bytes, then show the second operand load and invalid-opcode `101` result of zero with `operation_valid=0`.

The testbench also writes useful internal DUT signals through `$dumpvars(0, simd_demo_tb)`, but the top-level signals above are sufficient to explain the integrated interface and registered/combinational timing.
