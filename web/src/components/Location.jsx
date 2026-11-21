import { useLayoutEffect, useRef } from 'react';
import { cx } from '../lib/nui';
import { useFitText } from '../lib/useFitText';

const NS = 'http://www.w3.org/2000/svg';
const mk = (n, at) => { const e = document.createElementNS(NS, n); for (const k in at) e.setAttribute(k, at[k]); return e; };

function arcLen(A, B, T) {
  const n = 24, h = T / n, f = t => Math.sqrt((A * Math.cos(t)) ** 2 + (B * Math.sin(t)) ** 2);
  let sum = f(0) + f(T);
  for (let i = 1; i < n; i++) sum += f(i * h) * (i % 2 ? 4 : 2);
  return 2 * sum * h / 3;
}
function arcPath(cx0, cy0, A, B, T) {
  const x = t => (cx0 + A * Math.sin(t)).toFixed(2), y = t => (cy0 - B * Math.cos(t)).toFixed(2);
  return `M${x(-T)} ${y(-T)}A${A.toFixed(2)} ${B.toFixed(2)} 0 0 1 ${x(T)} ${y(T)}`;
}

function drawArc(box, svg, loc, rx, z, st) {
  const A = ((loc.width || 291) * rx) / 2, B = loc.ry || 100, gap = loc.gap == null ? 14 : loc.gap;
  const span = (loc.span || 44) * Math.PI / 180;

  const pad = 90, W = 2 * (A + pad), H = B + pad + 40, cx0 = W / 2, cy0 = H;
  box.style.width = W + 'px'; box.style.height = H + 'px';
  box.style.left = (loc.left * rx + A - W / 2) + 'px';
  box.style.bottom = (loc.bottom - B) + 'px';
  svg.setAttribute('width', W); svg.setAttribute('height', H); svg.setAttribute('viewBox', `0 0 ${W} ${H}`);
  svg.textContent = '';

  const TMAX = 82 * Math.PI / 180, MARGIN = 22, PADV = 9;
  const hasSt = !!st;
  const dSt = gap + PADV;
  let fz = 22, fs = 15;
  const defs = mk('defs', {}); svg.appendChild(defs);
  const pZ = mk('path', { id: 'arcZ', fill: 'none' }), pS = mk('path', { id: 'arcS', fill: 'none' });
  defs.appendChild(pZ); defs.appendChild(pS);
  const mkText = (txt, size, cls, id) => {
    const t = mk('text', { 'font-size': size, 'text-anchor': 'middle', class: cls || '' });
    const tp = mk('textPath', { startOffset: '50%' });
    tp.setAttribute('href', '#' + id); tp.setAttributeNS('http://www.w3.org/1999/xlink', 'xlink:href', '#' + id);
    tp.textContent = txt; t.appendChild(tp); svg.appendChild(t); return t;
  };
  const full = d => arcPath(cx0, cy0, A + d, B + d, TMAX);
  const dZ0 = dSt + (hasSt ? fs + 6 : 0);
  pZ.setAttribute('d', full(dZ0)); pS.setAttribute('d', full(dSt));
  const tz = mkText(z, fz, '', 'arcZ'), ts = hasSt ? mkText(st, fs, 'sub', 'arcS') : null;
  const avail = d => arcLen(A + d, B + d, TMAX) - 2 * MARGIN;
  while (tz.getComputedTextLength() > avail(dZ0) && fz > 11) { fz -= .5; tz.setAttribute('font-size', fz); }
  if (ts) while (ts.getComputedTextLength() > avail(dSt) && fs > 8) { fs -= .5; ts.setAttribute('font-size', fs); }
  const dZ = dSt + (hasSt ? fs + 6 : 0);

  const need = (d, len) => { let T = .1; while (T < TMAX && arcLen(A + d, B + d, T) < len + 2 * MARGIN) T += .01; return T; };
  const T = Math.max(span, need(dZ, tz.getComputedTextLength()), ts ? need(dSt, ts.getComputedTextLength()) : 0);
  pZ.setAttribute('d', arcPath(cx0, cy0, A + dZ, B + dZ, T)); pS.setAttribute('d', arcPath(cx0, cy0, A + dSt, B + dSt, T));
}

function LocArc({ on, text, loc, rx, zoom, hide }) {
  const boxRef = useRef(null), svgRef = useRef(null);
  useLayoutEffect(() => {
    if (!on || !loc || !boxRef.current) return;
    drawArc(boxRef.current, svgRef.current, loc, rx, text.z, text.st);
  }, [on, loc, rx, text.z, text.st]);
  return (
    <div className={cx('sp-arc', on && 'on', hide && 'hide')} id="sparc" ref={boxRef} style={{ zoom }}>
      <svg id="arcsvg" ref={svgRef} />
    </div>
  );
}

export default function Location({ loc, text, pos, isRound, curStyle, view, hide }) {
  const on = !!(loc && (loc.zone || loc.street));
  const zRef = useRef(null), sRef = useRef(null), zcRef = useRef(null), scRef = useRef(null);
  const L = pos || null;
  const w = L && L.width ? L.width * view.rx : undefined;
  const dep = [text.z, text.st, view.rx, view.z, L && L.width];
  useFitText(zRef, 22, 12, dep);
  useFitText(sRef, 15, 9, dep);
  useFitText(zcRef, 17, 10, dep);
  useFitText(scRef, 12.5, 8, dep);

  const boxStyle = { zoom: view.z };
  const pillStyle = { zoom: view.z };
  if (L) {
    boxStyle.left = (L.left * view.rx) + 'px'; boxStyle.bottom = L.bottom + 'px';
    pillStyle.left = (L.left * view.rx) + 'px'; pillStyle.bottom = (L.bottom - (L.overlap || 0)) + 'px';
    if (w) { boxStyle.width = w + 'px'; pillStyle.width = w + 'px'; }
  }

  return (
    <>
      <div className={cx('sp-loc', on && !isRound && 'on', isRound && 'round', hide && 'hide')} id="sploc" style={boxStyle}>
        <b id="lcz" ref={zRef}>{text.z}</b><span id="lcs" ref={sRef}>{text.st}</span>
      </div>

      <LocArc on={on && isRound && curStyle === 'arc'} text={text} loc={L} rx={view.rx} zoom={view.z} hide={hide} />

      <div className={cx('sp-locc', on && isRound && curStyle !== 'arc' && 'on', hide && 'hide')} id="splocc" style={pillStyle}>
        <div className="lc-pill">
          <div className="lc-ico">
            <svg viewBox="0 0 24 24"><path d="M12 21s-6.500-5.600-6.500-11a6.500 6.500 0 0 1 13 0c0 5.400-6.500 11-6.500 11z" /><circle cx="12" cy="10" r="2.300" /></svg>
          </div>
          <div className="lc-txt"><b id="lccz" ref={zcRef}>{text.z}</b><span id="lccs" ref={scRef}>{text.st}</span></div>
        </div>
      </div>
    </>
  );
}
