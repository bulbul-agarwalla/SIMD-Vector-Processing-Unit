/* Independent reference model + verifier. Runs in the browser at load time and
   re-computes every lane from the A/B operands, comparing against the values that
   were extracted from the real Verilog simulation (simulation_data.js). */
(function (g) {
  'use strict';
  const byte = (hex, n) => parseInt(hex.substr(14 - 2 * n, 2), 16);   // L0 = bits [7:0]
  function laneOp(opcode, a, b) {
    switch (opcode) {
      case 0: return (a + b) & 0xFF;
      case 1: return (a - b) & 0xFF;
      case 2: return a & b;
      case 3: return a | b;
      case 4: return a < b ? 1 : 0;
      default: return 0;
    }
  }
  const SELECT = ['00001', '00010', '00100', '01000', '10000'];
  function verify(data) {
    const rows = []; let lanesOk = 0, lanesTotal = 0, opsOk = 0, problems = [];
    data.steps.forEach((s) => {
      const op = parseInt(s.opcode, 2), valid = op <= 4 ? 1 : 0;
      let ok = true, packed = '';
      for (let n = 7; n >= 0; n--) {
        const L = s.lanes[n];
        const a = byte(s.A, n), b = byte(s.B, n);
        const want = valid ? laneOp(op, a, b) : 0;
        const rtl = byte(s.actual, n);
        const laneOk = L.lane === n && L.lo === 8 * n && L.hi === 8 * n + 7 &&
                       L.a === a && L.b === b && L.out === rtl && want === rtl &&
                       (valid || L.raw === ((a + b) & 0xFF));     // invalid: safe-default ADD, then gated
        lanesTotal++; if (laneOk) lanesOk++; else { ok = false; problems.push(`set ${s.set} ${s.name} lane ${n}`); }
        packed += want.toString(16).padStart(2, '0');
      }
      if (s.valid !== valid || s.select !== (valid ? SELECT[op] : '00000') ||
          s.expected !== s.actual || packed !== s.actual) { ok = false; problems.push(`set ${s.set} ${s.name} control/packed`); }
      if (ok) opsOk++;
      rows.push({ s, ok, model: packed });
    });
    return { rows, opsOk, opsTotal: data.steps.length, lanesOk, lanesTotal, ok: problems.length === 0, problems };
  }
  g.SIMDModel = { laneOp, byte, verify };
})(window);
