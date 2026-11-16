/* 8-Lane SIMD Vector Processing Unit - RTL simulation visualizer.
   All values come from simulation_data.js (parsed from the real testbench log and VCD)
   and are re-verified in the browser by model.js. Nothing is randomly generated. */
(function () {
  'use strict';
  const D = window.SIMD_DATA;
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));
  if (!D || !window.SIMDModel) { document.body.innerHTML = '<p style="padding:2rem;color:#f66;font-family:monospace">simulation_data.js failed to load - run tools/generate_simd_trace.py</p>'; return; }

  const H2 = (v) => v.toString(16).toUpperCase().padStart(2, '0');
  const BIN = (v) => v.toString(2).padStart(8, '0');
  const STEPS = D.steps, NSTEP = STEPS.length, PER_SET = 6;
  const OPINFO = {
    ADD: { g: '+', d: 'A + B  (8-bit, wraps mod 256)' }, SUB: { g: '−', d: 'A − B  (8-bit, wraps mod 256)' },
    AND: { g: '&', d: 'A AND B  (bitwise)' }, OR: { g: '|', d: 'A OR B  (bitwise)' },
    LT: { g: '<', d: '(A < B) ? 1 : 0   (unsigned)' }, INVALID: { g: '✕', d: 'invalid opcode → output forced to 0' } };

  /* ---------------- timeline (stage durations in ms at 1x) ---------------- */
  const STAGES = [
    { id: 'load', label: '① Operands', dur: 900 }, { id: 'split', label: '② Split bytes', dur: 1500 },
    { id: 'bcast', label: '③ Broadcast', dur: 1300 }, { id: 'exec', label: '④ Execute ×8', dur: 1400 },
    { id: 'res', label: '⑤ Results', dur: 800 }, { id: 'comb', label: '⑥ Combine', dur: 1400 } ];
  const HOLD = 1700;
  const START = []; let TOTAL = 0; STAGES.forEach((s) => { START.push(TOTAL); TOTAL += s.dur; });
  const END = TOTAL + HOLD;
  const locate = (t) => {
    if (t >= TOTAL) return { g: 6, p: 1 };
    for (let i = STAGES.length - 1; i >= 0; i--) if (t >= START[i]) return { g: i, p: (t - START[i]) / STAGES[i].dur };
    return { g: 0, p: 0 };
  };
  const ease = (x) => (x < 0 ? 0 : x > 1 ? 1 : x * x * (3 - 2 * x));

  const S = { step: 0, t: 0, playing: false, speed: 1, loop: false, order: 'msb' };

  /* ---------------- build static DOM ---------------- */
  const bandA = $('#bandA'), bandB = $('#bandB'), lanesEl = $('#lanes'), outCells = $('#outCells');
  const R = { A: [], B: [], lane: [], out: [] };
  for (let n = 0; n < 8; n++) {
    const mk = (cls) => { const d = document.createElement('div'); d.className = 'rcell ' + cls; d.dataset.lane = n;
      d.innerHTML = `<span class="tg">L${n}</span><b class="hx">--</b><span class="dc">&nbsp;</span>`; return d; };
    const a = mk('a'), b = mk('b'); bandA.appendChild(a); bandB.appendChild(b);
    R.A.push({ el: a, hx: $('.hx', a), dc: $('.dc', a) }); R.B.push({ el: b, hx: $('.hx', b), dc: $('.dc', b) });

    const l = document.createElement('div'); l.className = 'lane'; l.dataset.lane = n;
    l.innerHTML = `
      <i class="port pa"></i><i class="port pc"></i><i class="port pb"></i><i class="port po"></i>
      <div class="lane-h"><span class="lane-name">LANE ${n}</span><span class="lane-bits">[${8 * n + 7}:${8 * n}]</span><i class="led"></i></div>
      <div class="orow a"><span class="tg">A</span><b class="hx">--</b><span class="dc"></span><div class="bits"></div></div>
      <div class="orow b"><span class="tg">B</span><b class="hx">--</b><span class="dc"></span><div class="bits"></div></div>
      <div class="alu"><div class="alu-ring"><span class="alu-glyph">·</span></div>
        <div class="alu-txt"><span class="alu-eq">ALU idle</span><span class="alu-st">IDLE</span></div></div>
      <div class="res empty"><span class="tg">RESULT</span><b class="hx">--</b><span class="dc"></span><div class="bits"></div><div class="note"></div></div>`;
    lanesEl.appendChild(l);
    const bitsInit = () => '<i></i>'.repeat(8);
    $$('.bits', l).forEach((b0) => (b0.innerHTML = bitsInit()));
    const oa = $('.orow.a', l), ob = $('.orow.b', l), rs = $('.res', l), alu = $('.alu', l);
    R.lane.push({ el: l, a: { hx: $('.hx', oa), dc: $('.dc', oa), bits: $$('.bits i', oa) }, b: { hx: $('.hx', ob), dc: $('.dc', ob), bits: $$('.bits i', ob) },
      alu, ring: $('.alu-ring', alu), glyph: $('.alu-glyph', alu), eq: $('.alu-eq', alu), st: $('.alu-st', alu),
      res: rs, rhx: $('.hx', rs), rdc: $('.dc', rs), rbits: $$('.bits i', rs), note: $('.note', rs),
      pa: $('.pa', l), pc: $('.pc', l), pb: $('.pb', l), po: $('.po', l) });

    const o = document.createElement('div'); o.className = 'ocell'; o.dataset.lane = n;
    o.innerHTML = `<span class="tg">L${n} · [${8 * n + 7}:${8 * n}]</span><b class="hx">--</b><span class="dc">&nbsp;</span>`;
    outCells.appendChild(o); R.out.push({ el: o, hx: $('.hx', o), dc: $('.dc', o) });
  }
  const bigBytes = $('#bigBytes');
  const bigSpans = []; for (let n = 7; n >= 0; n--) { const s = document.createElement('span'); s.dataset.lane = n; s.textContent = '--'; bigBytes.appendChild(s); bigSpans[n] = s; }

  function applyOrder() {                      // purely visual; data/lane indices never change
    const asc = S.order === 'lsb';
    const place = (parent, key) => { const kids = Array.from(parent.children).sort((x, y) => asc ? x.dataset.lane - y.dataset.lane : y.dataset.lane - x.dataset.lane); kids.forEach((k) => parent.appendChild(k)); };
    [bandA, bandB, lanesEl, outCells].forEach(place);
    const bs = Array.from(bigBytes.children).sort((x, y) => asc ? x.dataset.lane - y.dataset.lane : y.dataset.lane - x.dataset.lane); bs.forEach((k) => bigBytes.appendChild(k));
    $('#stage').dataset.order = S.order; $('#btnOrder').textContent = asc ? 'LANES: L0 → L7' : 'LANES: L7 → L0';
    buildWires(); dirty = true; W.a.concat(W.b, W.c, W.o).forEach((w) => (w._p = -1));
  }

  /* control-bar widgets */
  const segSet = $('#segSet'), segOps = $('#segOps'), tracker = $('#tracker');
  D.operandSets.forEach((s) => { const b = document.createElement('button'); b.dataset.set = s.id; b.textContent = `SET ${s.id}`; b.title = `A = 0x${s.A.toUpperCase()}\nB = 0x${s.B.toUpperCase()}`; segSet.appendChild(b); });
  ['ADD 000', 'SUB 001', 'AND 010', 'OR 011', 'LT 100', '101 INVALID'].forEach((lab, i) => { const b = document.createElement('button'); b.dataset.op = i; b.textContent = lab; if (i === 5) b.className = 'inv'; segOps.appendChild(b); });
  STAGES.forEach((s, i) => { const b = document.createElement('button'); b.dataset.stage = i; b.innerHTML = `<i class="f"></i><span>${s.label}</span>`; tracker.appendChild(b); });
  const trF = $$('.f', tracker), trB = $$('button', tracker);

  /* ---------------- wires (SVG overlay, anchored to real DOM positions) ---------------- */
  const svg = $('#wires'), NS = 'http://www.w3.org/2000/svg';
  let W = { a: [], b: [], c: [], o: [] };
  function mk(tag, attrs) { const e = document.createElementNS(NS, tag); for (const k in attrs) e.setAttribute(k, attrs[k]); svg.appendChild(e); return e; }
  function wire(cls, d) {
    const base = mk('path', { class: 'w base', d }), len = base.getTotalLength();
    const act = mk('path', { class: 'w act ' + cls, d, 'stroke-dasharray': `${len} ${len}`, 'stroke-dashoffset': len, opacity: 0 });
    const dot = mk('circle', { class: 'pk ' + cls, r: 5, opacity: 0 });
    return { base, act, dot, len, path: base, cls };
  }
  function setWire(w, p, bad) {
    p = Math.max(0, Math.min(1, p));
    if (w._p === p && w._b === !!bad) return; w._p = p; w._b = !!bad;
    w.act.style.strokeDashoffset = w.len * (1 - p);
    w.act.setAttribute('opacity', p > 0 ? 1 : 0);
    w.act.classList.toggle('arrived', p >= 1);
    w.act.classList.toggle('bad', !!bad); w.dot.classList.toggle('bad', !!bad);
    if (p > 0 && p < 1) { const pt = w.path.getPointAtLength(w.len * p); w.dot.setAttribute('cx', pt.x); w.dot.setAttribute('cy', pt.y); w.dot.setAttribute('opacity', 1); }
    else w.dot.setAttribute('opacity', 0);
  }
  function buildWires() {
    while (svg.firstChild) svg.removeChild(svg.firstChild);
    const sr = $('#stage').getBoundingClientRect(), sc = sr.width / (120 * parseFloat(getComputedStyle(document.documentElement).fontSize));
    const pt = (el, ax, ay) => { const r = el.getBoundingClientRect(); return { x: (r.left + r.width * ax - sr.left) / sc, y: (r.top + r.height * ay - sr.top) / sc }; };
    svg.setAttribute('viewBox', `0 0 ${sr.width / sc} ${sr.height / sc}`); svg.setAttribute('preserveAspectRatio', 'none');
    const cu = $('#cu'), cuP = pt(cu, 0.5, 1), lanePorts = R.lane.map((L) => pt(L.pc, .5, .5));
    const railY = (pt(cu, .5, 1).y + pt(bandA, .5, 0).y) / 2;
    const xs = lanePorts.map((p) => p.x), x0 = Math.min(...xs), x1 = Math.max(...xs);
    mk('path', { class: 'rail', d: `M${x0},${railY} L${x1},${railY}` }); mk('path', { class: 'rail', d: `M${cuP.x},${cuP.y} L${cuP.x},${railY}` });
    W = { a: [], b: [], c: [], o: [] };
    for (let n = 0; n < 8; n++) {
      const L = R.lane[n];
      const aS = pt(R.A[n].el, .5, 1), aE = pt(L.pa, .5, .5); W.a[n] = wire('ca', `M${aS.x},${aS.y} L${aE.x},${aE.y}`);
      const bS = pt(R.B[n].el, .5, 1), bE = pt(L.pb, .5, .5); W.b[n] = wire('cb', `M${bS.x},${bS.y} L${bE.x},${bE.y}`);
      const cE = pt(L.pc, .5, .5); W.c[n] = wire('cc', `M${cuP.x},${cuP.y} L${cuP.x},${railY} L${cE.x},${railY} L${cE.x},${cE.y}`);
      const oS = pt(L.po, .5, .5), oE = pt(R.out[n].el, .5, 0); W.o[n] = wire('co', `M${oS.x},${oS.y} L${oE.x},${oE.y}`);
    }
  }

  /* ---------------- render ---------------- */
  const T = (el, v) => { if (el._v !== v) { el.textContent = v; el._v = v; } };
  const C = (el, c, on) => { if (el._c === undefined) el._c = {}; if (el._c[c] !== !!on) { el.classList.toggle(c, !!on); el._c[c] = !!on; } };
  const setBits = (cells, v, on) => cells.forEach((c, i) => { const bit = (v >> (7 - i)) & 1; C(c, 'one', on && bit); T(c, on ? String(bit) : ''); });
  const hexGroups = (h) => (h.slice(0, 8) + ' ' + h.slice(8)).toUpperCase();
  const zeroHex = '0000000000000000';

  function render(force) {
    const st = STEPS[S.step], { g, p } = locate(S.t), invalid = !st.valid, op = st.name;
    const first = st.index % PER_SET === 0, setIdx = st.set;
    const prev = setIdx === 1 ? { A: zeroHex, B: zeroHex } : { A: D.operandSets[setIdx - 2].A, B: D.operandSets[setIdx - 2].B };
    const newVals = !first || g > 0 || p > 0.4;
    const regA = newVals ? st.A : prev.A, regB = newVals ? st.B : prev.B;
    const byteOf = (h, n) => parseInt(h.substr(14 - 2 * n, 2), 16);

    const pAB = g < 1 ? 0 : g === 1 ? ease(p) : 1, pCtl = g < 2 ? 0 : g === 2 ? ease((p - .15) / .85) : 1;
    const decoded = g > 2 || (g === 2 && p > .2), selShown = g > 2 || (g === 2 && p > .45), opcodeShown = g >= 2;
    const exec = g === 3, execP = g < 3 ? 0 : g === 3 ? p : 1, arrived = pAB >= .92;
    const resShown = g > 4 || (g === 4 && p > .2), pOut = g < 5 ? 0 : g === 5 ? ease(p) : 1, outShown = g > 5 || (g === 5 && p > .92), done = g === 6;
    const gated = g > 5 || (g === 5 && p > .15);

    /* registers */
    $('#hexA').textContent = '0x' + hexGroups(regA); $('#hexB').textContent = '0x' + hexGroups(regB);
    for (let n = 0; n < 8; n++) {
      const a = byteOf(regA, n), b = byteOf(regB, n);
      T(R.A[n].hx, H2(a)); T(R.A[n].dc, String(a)); T(R.B[n].hx, H2(b)); T(R.B[n].dc, String(b));
      const loading = first && g === 0, sending = g === 1 && p < 1;
      [R.A[n].el, R.B[n].el].forEach((e) => { C(e, 'load', loading && p > .4); C(e, 'send', sending || (g === 1)); });
    }

    /* control unit */
    const cuEl = $('#cu'); C(cuEl, 'active', g === 2 || g === 3);
    const bits = (id, v, show, amber) => { const box = $(id); const cells = $$('i', box); C(box, 'on', show); cells.forEach((c, i) => { const b = show ? v[i] : '-'; T(c, b); C(c, 'one', show && b === '1'); }); };
    bits('#cuOpBits', st.opcode, opcodeShown); bits('#cuAluBits', st.aluOpcode, decoded);
    const nm = $('#cuName'); T(nm, decoded ? (invalid ? 'INVALID' : op) : '—'); C(nm, 'on', decoded && !invalid); C(nm, 'bad', decoded && invalid);
    T($('#cuDesc'), decoded ? (invalid ? `opcode ${st.opcode} not defined · safe-default alu_opcode = ${st.aluOpcode}` : OPINFO[op].d) : 'waiting for instruction');
    const vb = $('#cuValid'); C(vb, 'ok', decoded && !invalid); C(vb, 'bad', decoded && invalid); T($('#cuValidTxt'), decoded ? (invalid ? '0  (INVALID)' : '1  (valid)') : '—');
    $$('#cuSel span').forEach((s) => C(s, 'on', selShown && st.select[4 - s.dataset.s] === '1'));
    C($('#cuBcast'), 'on', g === 2 || g === 3);

    /* wires */
    for (let n = 0; n < 8; n++) { setWire(W.a[n], pAB); setWire(W.b[n], pAB); setWire(W.c[n], pCtl); setWire(W.o[n], pOut, invalid); }

    /* lanes */
    for (let n = 0; n < 8; n++) {
      const L = R.lane[n], ln = st.lanes[n], el = L.el;
      C(el, 'exec', exec); C(el, 'done', g >= 5 || (g === 4 && resShown)); C(el, 'bad', invalid);
      T(L.a.hx, arrived ? H2(ln.a) : '--'); T(L.a.dc, arrived ? String(ln.a) : ''); setBits(L.a.bits, ln.a, arrived);
      T(L.b.hx, arrived ? H2(ln.b) : '--'); T(L.b.dc, arrived ? String(ln.b) : ''); setBits(L.b.bits, ln.b, arrived);
      const ready = decoded && g < 3 && arrived;
      C(L.alu, 'ready', ready); C(L.alu, 'exec', exec); C(L.alu, 'done', g >= 4); C(L.alu, 'bad', decoded && invalid);
      L.ring.style.setProperty('--p', exec ? execP : g > 3 ? 1 : 0); L.ring.style.setProperty('--rc', invalid ? 'var(--red)' : 'var(--blue)');
      const gl = !decoded ? '·' : invalid ? '+' : OPINFO[op].g; T(L.glyph, gl);
      const eqOK = decoded && arrived;
      T(L.eq, !eqOK ? 'ALU idle' : invalid ? `${H2(ln.a)} + ${H2(ln.b)}` : `${H2(ln.a)} ${OPINFO[op].g} ${H2(ln.b)}`);
      T(L.st, g >= 4 ? (invalid ? 'DONE · DEFAULT ADD' : 'DONE') : exec ? (invalid ? 'DEFAULT ADD…' : 'EXECUTING') : ready ? 'READY' : 'IDLE');
      /* result block */
      const showRes = resShown, val = invalid ? ln.raw : ln.out;
      C(L.res, 'empty', !showRes); C(L.res, 'masked', showRes && invalid); C(L.res, 'struck', showRes && invalid && gated);
      T(L.rhx, showRes ? H2(val) : '--'); T(L.rdc, showRes ? String(val) : ''); setBits(L.rbits, val, showRes);
      let note = '';
      if (showRes) {
        if (invalid) note = gated ? 'gated → 00 · valid=0' : 'safe-default ADD out';
        else if (op === 'ADD' && ln.a + ln.b > 255) note = `${ln.a}+${ln.b}=${ln.a + ln.b} → wraps`;
        else if (op === 'SUB' && ln.a < ln.b) note = `${ln.a}−${ln.b}<0 → wraps +256`;
        else if (op === 'LT') note = ln.a < ln.b ? 'A < B → true (1)' : 'A < B → false (0)';
        else if (op === 'ADD') note = `${ln.a}+${ln.b}=${ln.a + ln.b}`;
        else if (op === 'SUB') note = `${ln.a}−${ln.b}=${ln.a - ln.b}`;
        else note = op === 'AND' ? 'bitwise AND' : 'bitwise OR';
      }
      T(L.note, note);
      if (L.res._popped !== (showRes && g === 4)) { L.res._popped = showRes && g === 4; C(L.res, 'pop', L.res._popped); }
    }

    /* output register */
    const out = $('#out'); C(out, 'done', done); C(out, 'bad', invalid);
    for (let n = 0; n < 8; n++) {
      const v = st.lanes[n].out, c = R.out[n];
      T(c.hx, outShown ? H2(v) : '--'); T(c.dc, outShown ? String(v) : '\u00a0'); C(c.el, 'on', outShown); C(c.el, 'bad', outShown && invalid);
      T(bigSpans[n], outShown ? H2(v) : '--'); C(bigSpans[n], 'on', outShown);
    }
    C($('#bigHex'), 'bad', invalid);
    const ov = $('#outValid'); C(ov, 'ok', outShown && !invalid); C(ov, 'bad', outShown && invalid);
    T($('#outValidTxt'), outShown ? `operation_valid = ${st.valid}${invalid ? '  → output forced to 0' : ''}` : 'operation_valid = —');
    const ck = $('#outChk'); C(ck, 'pass', done); T(ck, done ? `✓ PASS · result == expected (0x${st.expected.toUpperCase()})` : 'RTL check: pending');
    T($('#outT'), outShown && st.simTimeNs != null ? `VCD: settled at t = ${st.simTimeNs} ns\n(testbench simulation time)` : 'VCD: —');
    $('#outT').style.whiteSpace = 'pre';

    /* caption */
    const cap = captionFor(st, g, first), cs = $('#capStep');
    T(cs, g === 6 ? '✓' : ['①', '②', '③', '④', '⑤', '⑥'][g]); $('#capText').innerHTML = cap;

    /* tracker + selectors */
    for (let i = 0; i < 6; i++) { trF[i].style.width = (g > i ? 100 : g === i ? p * 100 : 0) + '%'; C(trB[i], 'cur', g === i); C(trB[i], 'done', g > i); }
    $('#stepNo').textContent = `· CHECK ${String(S.step + 1).padStart(2, '0')}/${NSTEP} · SET ${st.set} · ${invalid ? 'opcode 101' : op}`;
    $$('#segSet button').forEach((b) => C(b, 'on', +b.dataset.set === st.set));
    $$('#segOps button').forEach((b) => C(b, 'on', +b.dataset.op === (st.index % PER_SET)));
    T($('#btnPlay').firstChild, S.playing ? '⏸' : (S.t >= END ? '⟲' : '▶')); T($('#btnPlay small'), S.playing ? 'Pause' : 'Play');
  }

  function captionFor(st, g, first) {
    const op = st.name, inv = !st.valid, hx = (h) => '0x' + h.toUpperCase();
    switch (g) {
      case 0: return first
        ? `<b>vector_a / vector_b</b> loaded on the clock edge (write_enable_a/b = 1) → Set ${st.set}: A = <b>${hx(st.A)}</b>, B = <b>${hx(st.B)}</b>`
        : `Operand registers <b>hold Set ${st.set}</b> (write_enable = 0). Only the opcode changes → <b>${inv ? '101 (invalid)' : op + ' ' + st.opcode}</b>`;
      case 1: return `Each 64-bit vector is split into <b>eight 8-bit bytes</b>: lane 0 = bits [7:0] … lane 7 = bits [63:56]. Byte <i>n</i> of A and of B go to lane <i>n</i>.`;
      case 2: return inv
        ? `Control unit decodes <b>opcode ${st.opcode}</b> → <b>operation_valid = 0</b>. It still drives the safe-default <b>alu_opcode = ${st.aluOpcode}</b> to every lane.`
        : `Control unit decodes <b>opcode ${st.opcode} = ${op}</b> and <b>broadcasts one instruction</b> (alu_opcode = ${st.aluOpcode}) to <b>all 8 lanes</b> at once.`;
      case 3: return inv
        ? `All eight lane ALUs run the safe-default ADD in parallel — these outputs will be <b>discarded</b> by the output gate.`
        : `All <b>8 lane ALUs execute ${op} simultaneously</b>, each on its own independent 8-bit A and B values.`;
      case 4: return inv
        ? `Lane ALU outputs exist (safe-default ADD), but <b>operation_valid = 0</b>…`
        : `<b>All eight 8-bit results are produced at the same time</b> — no lane waits for another.`;
      case 5: return inv
        ? `Output gate: <b>result = operation_valid ? lanes : 0</b> → result[63:0] forced to <b>0x0000000000000000</b>.`
        : `Lane outputs are packed into <b>result[63:0] = ${hx(st.actual)}</b> (L7 at the left … L0 at the right).`;
      default: return `<b>Check ${st.index + 1}/${NSTEP} PASS</b> — Set ${st.set}, ${inv ? 'opcode 101 (INVALID)' : op}: RTL result <b>${hx(st.actual)}</b>, valid = ${st.valid}. Press Next ⏭ or choose any operation.`;
    }
  }

  /* ---------------- engine ---------------- */
  let last = 0, rs = -1, rt = -1, dirty = true;
  function tick(ts) {
    const dt = last ? Math.min(ts - last, 250) : 0; last = ts;
    if (S.playing) {
      S.t += dt * S.speed;
      if (S.t >= END) {
        if (S.step < NSTEP - 1) { S.step++; S.t = 0; }
        else if (S.loop) { S.step = 0; S.t = 0; }
        else { S.t = END; S.playing = false; }
      }
    }
    if (S.step !== rs || S.t !== rt || dirty) { render(); rs = S.step; rt = S.t; dirty = false; api.renders++; }
    requestAnimationFrame(tick);
  }
  const goto = (i, play = true) => { dirty = true; S.step = (i + NSTEP) % NSTEP; S.t = 0; S.playing = play; };
  const api = {
    play() { if (S.t >= END) { S.t = 0; } S.playing = true; dirty = true; }, pause() { S.playing = false; dirty = true; },
    toggle() { S.playing ? api.pause() : api.play(); },
    next() { goto(S.step + 1); }, prev() { goto(S.step - 1); }, replay() { goto(S.step); },
    speed(v) { dirty = true; S.speed = v; $$('#segSpeed button').forEach((b) => b.classList.toggle('on', +b.dataset.v === v)); },
    set(id) { goto((id - 1) * PER_SET + (S.step % PER_SET)); }, op(i) { goto(Math.floor(S.step / PER_SET) * PER_SET + i); },
    stage(i) { dirty = true; S.t = START[i] + STAGES[i].dur * 0.985; S.playing = false; },
    state: () => S, steps: STEPS, END, TOTAL, START, renders: 0 };
  window.SIMDApp = api;

  $('#btnPlay').onclick = api.toggle; $('#btnNext').onclick = api.next; $('#btnPrev').onclick = api.prev; $('#btnReplay').onclick = api.replay;
  $$('#segSpeed button').forEach((b) => (b.onclick = () => api.speed(+b.dataset.v)));
  $$('#segSet button').forEach((b) => (b.onclick = () => api.set(+b.dataset.set)));
  $$('#segOps button').forEach((b) => (b.onclick = () => api.op(+b.dataset.op)));
  trB.forEach((b) => (b.onclick = () => api.stage(+b.dataset.stage)));
  $('#chkLoop').onchange = (e) => (S.loop = e.target.checked);
  $('#btnOrder').onclick = () => { S.order = S.order === 'msb' ? 'lsb' : 'msb'; applyOrder(); };
  window.addEventListener('keydown', (e) => {
    if (!$('#modal').hidden) { if (e.key === 'Escape') $('#modal').hidden = true; return; }
    if (e.key === ' ') { e.preventDefault(); api.toggle(); } else if (e.key === 'ArrowRight') api.next(); else if (e.key === 'ArrowLeft') api.prev();
    else if (e.key === 'r' || e.key === 'R') api.replay();
  });
  window.addEventListener('resize', () => { buildWires(); dirty = true; });

  /* ---------------- verification report ---------------- */
  const V = SIMDModel.verify(D);
  const vb = $('#btnVerify');
  $('#verifyText').textContent = V.ok ? `RTL VERIFIED · ${V.opsOk}/${V.opsTotal} ops · ${V.lanesOk}/${V.lanesTotal} lanes` : `MISMATCH · ${V.problems.length} problem(s)`;
  vb.classList.toggle('bad', !V.ok);
  vb.onclick = () => {
    $('#modalDesc').innerHTML = `Data extracted from the real Icarus Verilog run of <code>${D.meta.testbench}</code> (log + <code>${D.meta.vcdFiles.join(', ')}</code>), then re-computed here by an independent JavaScript model. ` +
      `Testbench reported <b>${D.meta.checksPassedInTestbench}</b> operation checks passed. Lane order: ${D.meta.laneMapping}. ${D.meta.kind}.`;
    const rows = V.rows.map((r) => { const s = r.s; return `<tr><td>${s.set}</td><td>${s.name === 'INVALID' ? '101 INVALID' : s.name + ' ' + s.opcode}</td><td>${s.valid}</td><td>${s.A.toUpperCase()}</td><td>${s.B.toUpperCase()}</td>` +
      `<td>${s.actual.toUpperCase()}</td><td>${r.model.toUpperCase()}</td><td>${s.simTimeNs} ns</td><td class="${r.ok ? 'ok' : 'bad'}">${r.ok ? '✓ match' : '✗ MISMATCH'}</td></tr>`; }).join('');
    $('#vtable').innerHTML = `<tr><th>Set</th><th>Operation</th><th>valid</th><th>Vector A</th><th>Vector B</th><th>RTL result[63:0]</th><th>JS model</th><th>VCD t</th><th>8 lanes</th></tr>${rows}`;
    $('#modal').hidden = false;
  };
  $('#modalClose').onclick = () => ($('#modal').hidden = true);
  $('#modal').onclick = (e) => { if (e.target.id === 'modal') $('#modal').hidden = true; };

  /* init */
  (document.fonts && document.fonts.ready ? document.fonts.ready : Promise.resolve()).then(() => { applyOrder(); });
  applyOrder(); requestAnimationFrame(tick);
})();
