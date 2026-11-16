# Validation record

## Data (generator, `tools/generate_simd_trace.py`)
* Re-ran `testbench/simd_demo_tb.v` against the repo RTL with Icarus Verilog 12.0:
  `SIMD DEMO COMPLETE: 12 operation checks passed` (`evidence/simd_demo_resimulation.log`).
* 12 operations = 2 operand sets × (ADD, SUB, AND, OR, LT, opcode 101).
* Per operation, `testbench expected == RTL actual == VCD result == independent Python model`.
* Per lane (12 × 8 = **96** lane outputs): VCD `lane_alu.result` checked against the packed result;
  for opcode 101 the lanes' VCD outputs equal the safe-default ADD and `result` is 0.
* Both the VCD you supplied and the VCD produced by the re-simulation were cross-checked.
  They have different signal-ID layouts (yours was dumped by an earlier revision of the testbench)
  but identical operations and lane values.

## Interface (headless Chromium, `file://`)
* **Displayed vs Verilog:** for all 12 operations the page's DOM was compared with the Verilog
  `TRACE|` log — opcode bits, operation name, `operation_valid`, `op_select`, A/B register bytes,
  every lane's A, B and result (96 lane displays), the 8 output cells and the 64-bit output
  hex, and the PASS line. 0 mismatches. For opcode 101 the lanes show the safe-default ADD
  values and the output is `0x0000000000000000`.
* **Controls:** Play, Pause, Next, Prev, Replay, all five speeds (exact 0.25×…4× scaling checked
  with an injected clock), auto-advance, stop at the last operation, restart-after-end, Loop,
  Set 1/2 selection, all six operation buttons, pipeline-stage chips, keyboard shortcuts,
  lane-order toggle (data unchanged), verification modal (12/12 rows match).
* **Offline:** 0 external network requests; no CDN, fonts or scripts are loaded remotely.
* **JS console:** no errors. **Layouts** checked at 1920×1080, 2560×1440, 1440×900, 1366×768
  (no scrollbars; 16:9 stage letterboxes).

## Not verified
* Tested in headless Chromium with software rendering only — not in Safari or on a real Mac GPU.
  Frame rate on your MacBook was therefore not measured.
