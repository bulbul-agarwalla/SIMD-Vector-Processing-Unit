#!/usr/bin/env python3
"""
generate_simd_trace.py
Builds demo/simd_visualizer/simulation_data.{json,js} from REAL simulation output.

Sources (nothing is invented):
  1. The testbench log  (TRACE| lines printed by testbench/simd_demo_tb.v)
  2. The VCD waveform   (per-lane ALU outputs, decoder signals, simulation time)

Every one of the 12 operations is cross-checked three ways:
  log expected == log actual == VCD result == independent Python model,
and every lane byte is checked against the VCD lane_alu outputs.
The script exits non-zero on any mismatch.

Usage:
  generate_simd_trace.py LOG OUT_JSON [--vcd FILE ...]
If no --vcd is given, <repo>/results/simd_demo.vcd is used when present.
"""
import argparse, json, re, sys
from pathlib import Path

OPS = {0: "ADD", 1: "SUB", 2: "AND", 3: "OR", 4: "LT"}
SEL = {0: 0b00001, 1: 0b00010, 2: 0b00100, 3: 0b01000, 4: 0b10000}


# ------------------------------------------------------------------ model --
def model_lane(op, a, b):
    """Independent lane model (unsigned 8-bit), mirrors rtl/alu.v semantics."""
    if op == 0: return (a + b) & 0xFF
    if op == 1: return (a - b) & 0xFF
    if op == 2: return a & b
    if op == 3: return a | b
    if op == 4: return 1 if a < b else 0
    return 0


def lanes_of(v):                      # L0 = bits [7:0] ... L7 = bits [63:56]
    return [(v >> (8 * i)) & 0xFF for i in range(8)]


def pack(lanes):
    return sum((x & 0xFF) << (8 * i) for i, x in enumerate(lanes))


# -------------------------------------------------------------------- log --
TRACE = re.compile(
    r"TRACE\|set=(\d+)\|name=(\w+)\|opcode=([01]{3})\|valid=([01])\|select=([01]{5})"
    r"\|A=([0-9a-f]{16})\|B=([0-9a-f]{16})\|expected=([0-9a-f]{16})\|actual=([0-9a-f]{16})")


def parse_log(path):
    rows = []
    for line in Path(path).read_text().splitlines():
        m = TRACE.search(line)
        if m:
            s, name, opc, valid, sel, a, b, exp, act = m.groups()
            rows.append(dict(set=int(s), name=name, opcode=int(opc, 2), valid=int(valid),
                             select=int(sel, 2), A=int(a, 16), B=int(b, 16),
                             expected=int(exp, 16), actual=int(act, 16)))
    txt = Path(path).read_text()
    m = re.search(r"SIMD DEMO COMPLETE: (\d+) operation checks passed", txt)
    return rows, int(m.group(1)) if m else None


# -------------------------------------------------------------------- vcd --
def parse_vcd(path):
    """Return (timescale_ps, snapshots). A snapshot is the settled value set of
    the signals we care about, taken at the end of every timestamp."""
    ids = {}            # id -> list of signal keys
    scope = []
    wanted_top = {"vector_a", "vector_b", "result", "operation_valid", "op_select",
                  "alu_opcode", "datapath_result", "opcode"}
    timescale_ps = 1
    txt = Path(path).read_text().splitlines()
    i = 0
    while i < len(txt):
        ln = txt[i].strip()
        if ln.startswith("$timescale"):
            body = " ".join(txt[i + 1:i + 2]).strip()
            m = re.match(r"(\d+)\s*(ps|ns|fs|us)", body)
            if m: timescale_ps = int(m.group(1)) * {"fs": 0.001, "ps": 1, "ns": 1000, "us": 1e6}[m.group(2)]
        elif ln.startswith("$scope"):
            scope.append(ln.split()[2])
        elif ln.startswith("$upscope"):
            scope.pop()
        elif ln.startswith("$var"):
            p = ln.split()
            vid, name = p[3], p[4]
            path_ = ".".join(scope)
            key = None
            if path_ == "simd_demo_tb.dut" and name in wanted_top:
                key = name
            elif path_.startswith("simd_demo_tb.dut.parallel_datapath.SIMD_LANES[") \
                    and path_.endswith(".lane_alu") and name == "result":
                n = int(re.search(r"SIMD_LANES\[(\d+)\]", path_).group(1))
                key = f"lane{n}"
            if key:
                ids.setdefault(vid, []).append(key)
        elif ln.startswith("$enddefinitions"):
            i += 1
            break
        i += 1

    state, snaps, t = {}, [], 0

    def flush():
        if state: snaps.append((t, dict(state)))

    seen_time = False
    for ln in txt[i:]:
        ln = ln.strip()
        if not ln or ln.startswith("$"): continue
        if ln[0] == "#":
            if seen_time: flush()
            t = int(ln[1:]); seen_time = True
        elif ln[0] == "b":
            val, vid = ln[1:].split()
            for k in ids.get(vid, []):
                state[k] = None if "x" in val or "z" in val else int(val, 2)
        elif ln[0] in "01xz":
            vid = ln[1:]
            for k in ids.get(vid, []):
                state[k] = None if ln[0] in "xz" else int(ln[0])
    flush()
    return timescale_ps, snaps


def find_in_vcd(rows, timescale_ps, snaps):
    """Match each logged operation to the first settled VCD snapshot (in order)."""
    out, cursor, problems = [], 0, []
    for r in rows:
        hit = None
        for j in range(cursor, len(snaps)):
            t, s = snaps[j]
            if (s.get("opcode") == r["opcode"] and s.get("vector_a") == r["A"]
                    and s.get("vector_b") == r["B"] and s.get("result") == r["actual"]
                    and s.get("operation_valid") == r["valid"]
                    and s.get("op_select") == r["select"]
                    and all(s.get(f"lane{n}") is not None for n in range(8))):
                hit = (j, t, s); break
        if not hit:
            problems.append(f"VCD has no settled state matching set{r['set']} {r['name']}")
            out.append(None); continue
        cursor = hit[0]
        out.append(dict(time_ps=hit[1] * timescale_ps, state=hit[2]))
    return out, problems


# ------------------------------------------------------------------- main --
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log"); ap.add_argument("out")
    ap.add_argument("--vcd", action="append", default=[])
    a = ap.parse_args()

    out_json = Path(a.out).resolve()
    repo = out_json.parents[2] if len(out_json.parents) > 2 else Path.cwd()
    vcds = [Path(v) for v in a.vcd]
    if not vcds and (repo / "results" / "simd_demo.vcd").exists():
        vcds = [repo / "results" / "simd_demo.vcd"]
    if not vcds:
        sys.exit("ERROR: no VCD supplied/found; refusing to build without waveform cross-check")

    rows, declared = parse_log(a.log)
    errors = []
    if len(rows) != 12: errors.append(f"expected 12 TRACE rows, found {len(rows)}")
    if declared != 12: errors.append(f"log says {declared} checks passed (expected 12)")

    vcd_results = []
    for v in vcds:
        ts, snaps = parse_vcd(v)
        found, probs = find_in_vcd(rows, ts, snaps)
        errors += [f"[{v.name}] {p}" for p in probs]
        vcd_results.append((v, found))

    steps, lane_checks, op_checks = [], 0, 0
    for idx, r in enumerate(rows):
        la, lb = lanes_of(r["A"]), lanes_of(r["B"])
        la_out = lanes_of(r["actual"])
        model = [model_lane(r["opcode"], x, y) if r["valid"] else 0 for x, y in zip(la, lb)]
        if pack(model) != r["actual"] or r["expected"] != r["actual"]:
            errors.append(f"step {idx}: model/log mismatch")
        op_checks += 1

        primary = vcd_results[0][1][idx]
        raw = [None] * 8
        if primary:
            s = primary["state"]
            raw = [s[f"lane{n}"] for n in range(8)]
            # lane ALU outputs: equal to the packed result when valid; for the
            # invalid opcode they equal the safe-default ADD and are gated to 0
            for n in range(8):
                want = la_out[n] if r["valid"] else (la[n] + lb[n]) & 0xFF
                if raw[n] != want: errors.append(f"step {idx} lane {n}: VCD lane_alu {raw[n]:02x} != {want:02x}")
                if s.get("datapath_result") is not None and lanes_of(s["datapath_result"])[n] != raw[n]:
                    errors.append(f"step {idx} lane {n}: datapath_result slice != lane_alu")
                lane_checks += 1
        for v, found in vcd_results[1:]:           # additional VCDs: same results required
            f = found[idx]
            if f and [f["state"][f"lane{n}"] for n in range(8)] != raw:
                errors.append(f"[{v.name}] lane outputs differ from primary VCD at step {idx}")

        steps.append(dict(
            index=idx, set=r["set"], name=r["name"], opcode=format(r["opcode"], "03b"),
            valid=r["valid"], select=format(r["select"], "05b"),
            aluOpcode=format(primary["state"]["alu_opcode"], "03b") if primary else None,
            A=format(r["A"], "016x"), B=format(r["B"], "016x"),
            expected=format(r["expected"], "016x"), actual=format(r["actual"], "016x"),
            datapathResult=format(primary["state"]["datapath_result"], "016x") if primary else None,
            simTimeNs=(primary["time_ps"] / 1000.0) if primary else None,
            lanes=[dict(lane=n, hi=8 * n + 7, lo=8 * n, a=la[n], b=lb[n],
                        raw=raw[n], out=la_out[n]) for n in range(8)],
        ))

    if errors:
        print("VERIFICATION FAILED:", *errors, sep="\n  ", file=sys.stderr); sys.exit(1)

    sets = {}
    for s in steps: sets.setdefault(s["set"], (s["A"], s["B"]))
    data = dict(
        meta=dict(
            title="8-Lane SIMD Vector Processing Unit",
            kind="RTL simulation visualization (Icarus Verilog) - not an FPGA implementation",
            testbench="testbench/simd_demo_tb.v", top="simd_processor_top",
            checksPassedInTestbench=declared,
            laneMapping="L0 = bits [7:0] ... L7 = bits [63:56]",
            vcdFiles=[v.name for v in vcds], vcdTimescalePs=1,
            note="Values are parsed from the testbench log and cross-checked against the VCD; "
                 "simTimeNs is the testbench simulation time of the settled state, not a hardware timing claim."),
        operandSets=[dict(id=k, A=v[0], B=v[1]) for k, v in sorted(sets.items())],
        steps=steps,
        verification=dict(operationChecks=op_checks, laneChecks=lane_checks,
                          crossChecked=["testbench log", "VCD waveform", "independent Python model"]),
    )
    out_json.write_text(json.dumps(data, indent=2) + "\n")
    out_json.with_suffix(".js").write_text(
        "/* AUTO-GENERATED by tools/generate_simd_trace.py - do not edit. */\n"
        "window.SIMD_DATA = " + json.dumps(data, indent=2) + ";\n")
    print(f"OK: {op_checks} operations, {lane_checks} lane outputs verified "
          f"(log + VCD + model) -> {out_json.name}, {out_json.with_suffix('.js').name}")


if __name__ == "__main__":
    main()
