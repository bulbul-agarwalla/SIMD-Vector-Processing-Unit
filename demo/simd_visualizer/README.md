# 8-Lane SIMD Vector Processing Unit — RTL Simulation Visualizer

An interactive, animated datapath visualizer for `simd_processor_top`.
**This is an RTL simulation visualization (Icarus Verilog), not an FPGA implementation.**
It makes no timing, frequency or speed-up claims. The only time shown is the testbench's
own simulation timestamp, read from the VCD.

## Launch (macOS, no internet, no install)

```bash
cd demo/simd_visualizer
open index.html                 # opens in your default browser
```

If you prefer a local server (identical result):

```bash
cd demo/simd_visualizer
python3 -m http.server 8000     # then browse to http://localhost:8000
```

Best for screen recording: Chrome/Safari, full-screen (⌃⌘F), 1920×1080. The stage is a fixed
16:9 canvas that scales to any window.

## Where the numbers come from

| Step | What | File |
|---|---|---|
| 1 | Your self-checking testbench run on the repo RTL (12/12 checks pass) | `testbench/simd_demo_tb.v` → `evidence/simd_demo_resimulation.log` |
| 2 | Parse `TRACE|…` log lines **and** decode the VCD (lane ALU outputs, decoder signals, sim time) | `tools/generate_simd_trace.py` |
| 3 | Cross-check log = VCD = independent Python model, per operation and per lane (96 lanes); abort on any mismatch | same script |
| 4 | Emit `simulation_data.json` (+ `simulation_data.js` so `index.html` works from `file://`) | generated |
| 5 | At page load, `model.js` re-computes every lane in JavaScript and compares with the RTL data (header badge, click it for the table) | `model.js` |

Nothing displayed is random or hand-typed. Lane ordering is exact: **L0 = bits [7:0] … L7 = bits [63:56]**.
By default the screen shows L7 on the left so the bytes read like the hex string; the
`LANES` button in the header reverses the on-screen order (data unchanged).

### Regenerating the data

```bash
./scripts/run_simd_demo.sh
python3 demo/simd_visualizer/tools/generate_simd_trace.py \
        results/simd_demo.log demo/simd_visualizer/simulation_data.json \
        --vcd results/simd_demo.vcd
```
The visualizer's generator parses the fresh testbench log, cross-checks it against the VCD and
an independent Python model, then writes both `simulation_data.json` and `simulation_data.js`.
The JavaScript data file lets `index.html` run directly from `file://`; the VCD is required for
the lane-level waveform cross-check.

## What you see

* **Control unit** — `opcode[2:0]`, decoded operation name, `alu_opcode`, `operation_valid`, one-hot `op_select`.
* **Vector A / Vector B** — the two 64-bit registers as eight hex bytes (decimal underneath).
* **Eight lanes** — each shows its own A and B bytes (with bit strips), the ALU, and the 8-bit result.
* **Output register** — eight result bytes combined into `result[63:0]`, `operation_valid`, PASS vs the testbench's expected value, and the VCD timestamp.
* **Pipeline** — ① operands → ② split into bytes → ③ one instruction broadcast → ④ all lanes execute → ⑤ results appear together → ⑥ combine into the output.

Faithful details taken from the RTL/VCD: operand registers are only *written* on the first
operation of each set (the other five operations show "registers hold"); ADD/SUB wrap
mod 256; LT outputs `1`/`0`. For **opcode 101** the control unit still sends a
safe-default `alu_opcode = 000` to the lanes (so the lanes compute ADD internally, real
values from the VCD) but `operation_valid = 0` and `simd_processor_top` forces
`result = 0`; the animation shows the lane outputs struck out/gated.

## Controls

| Control | Action | Key |
|---|---|---|
| Play / Pause | start / freeze the animation | `Space` |
| Prev / Next | previous / next of the 12 verified operations | `←` / `→` |
| Replay | restart the current operation | `R` |
| Speed | 0.25× · 0.5× · 1× · 2× · 4× | |
| Operand set | Set 1 / Set 2 (keeps the current operation) | |
| Operation | ADD · SUB · AND · OR · LT · 101 INVALID | |
| Pipeline stage chips | jump to the end of a stage and pause | |
| Loop | repeat the 12-operation sequence | |
| `RTL VERIFIED` badge | opens the verification table | `Esc` closes |

## Files

```
index.html  styles.css  app.js  model.js     the visualizer (no libraries, no network)
simulation_data.json / .js                   generated from the real simulation
tools/generate_simd_trace.py                 log + VCD → data, with cross-checks
evidence/simd_demo_resimulation.log          the Icarus run used to build the data
VALIDATION.md                                what was tested, and how
```
No RTL, testbench or report file in the repository was touched.
