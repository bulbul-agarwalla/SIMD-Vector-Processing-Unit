#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/results"
mkdir -p "$OUT_DIR"
SIM_BIN="$(mktemp "${TMPDIR:-/tmp}/simd_demo.XXXXXX")"
trap 'rm -f "$SIM_BIN"' EXIT

cd "$ROOT_DIR"
printf '%s\n' 'Compiling integrated SIMD RTL and presentation testbench...'
iverilog -g2012 -Wall -s simd_demo_tb -I "$ROOT_DIR/rtl" \
    -o "$SIM_BIN" \
    rtl/alu.v \
    rtl/vector_register.v \
    rtl/simd_top.v \
    rtl/control_unit.v \
    rtl/simd_processor_top.v \
    testbench/simd_demo_tb.v

printf '%s\n' 'Running self-checking RTL simulation...'
vvp "$SIM_BIN"
printf '\nVCD waveform written to: %s\n' "$OUT_DIR/simd_demo.vcd"
