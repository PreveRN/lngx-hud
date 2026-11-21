import { PURE_ICONS } from '../data/pureIcons';

const ITEMS = [
  { k: 'health',  pure: 'Health',  col: '#F3163E' },
  { k: 'armor',   pure: 'Armour',  col: '#00A3FF' },
  { k: 'hunger',  pure: 'Hunger',  col: '#ADFE00' },
  { k: 'thirst',  pure: 'Thirst',  col: '#00FFF0' },
  { k: 'stress',  pure: 'Stress',  col: '#FF0099' },
  { k: 'stamina', pure: 'Stamina', col: '#FFA048', hideAt: 'full' },
  { k: 'oxygen',  c: '--o2',   hideAt: 'full', i: '<path d="M3 9c3 0 3-2 6-2s3 2 6 2 3-2 6-2M3 15c3 0 3-2 6-2s3 2 6 2 3-2 6-2"/>' },
  { k: 'premium', c: '--prem', i: '<path d="M3 8l4 4 5-7 5 7 4-4-2 11H5z"/>' },
];
const LOWKEYS = new Set(['health', 'hunger', 'thirst', 'stamina', 'oxygen']);

const DASH = 5, GAP_DEG = 22, RR = 17.5;
const DASH_PATHS = (() => {
  const step = 360 / DASH;
  const pt = a => { const r = (a - 90) * Math.PI / 180; return [(20 + RR * Math.cos(r)).toFixed(2), (20 + RR * Math.sin(r)).toFixed(2)]; };
  return Array.from({ length: DASH }, (_, i) => {
    const p0 = pt(i * step + GAP_DEG / 2), p1 = pt((i + 1) * step - GAP_DEG / 2);
    return `M${p0[0]} ${p0[1]}A${RR} ${RR} 0 0 1 ${p1[0]} ${p1[1]}`;
  });
})();

function calc(it, state, prefs) {
  let v = state[it.k], show = true, pct = 0;
  if (it.k === 'premium') {
    show = v !== null && v !== undefined && v !== false;
    pct = typeof v === 'number' ? Math.min(v / 720, 1) * 100 : 100;
  } else {
    v = Math.max(0, Math.min(100, Math.round(v ?? 0))); pct = v;
    if (it.hideAt === 'full') show = v < 100;
  }
  if (prefs.status[it.k] === false) show = false;
  const low = show && LOWKEYS.has(it.k) && pct < 17;
  return { show, pct, low };
}

function Item({ it, show, pct, low }) {
  const col = it.col || `var(${it.c})`;
  const iconHtml = it.pure ? PURE_ICONS[it.pure] : `<svg class="lx" viewBox="0 0 24 24">${it.i}</svg>`;
  return (
    <div className={'item' + (show ? '' : ' off') + (low ? ' low' : '')} style={{ '--c': col, color: col }}>
      <div className="disc" />
      <div className="Icon" style={it.pure ? { filter: `drop-shadow(0 0 4px ${col}40)` } : undefined}
        dangerouslySetInnerHTML={{ __html: iconHtml }} />
      <svg className="ring" width="40" height="40" viewBox="0 0 40 40" fill="none">
        {DASH_PATHS.map((d, i) => <path key={i} d={d} className={pct > (i + .5) * 100 / DASH ? 'on' : undefined} />)}
      </svg>
    </div>
  );
}

export default function StatusDock({ state, prefs, ready, hidden, linesOn, view, pos }) {
  const style = { zoom: view.z };
  if (pos) { style.left = (pos.left * view.rx) + 'px'; style.bottom = pos.bottom + 'px'; }
  return (
    <div id="hud" className={hidden ? 'hidden' : undefined} style={style}>
      <div className="dock" id="dock" style={linesOn ? { display: 'none' } : undefined}>
        {ITEMS.map(it => {
          const c = ready ? calc(it, state, prefs) : { show: false, pct: 0, low: false };
          return <Item key={it.k} it={it} {...c} />;
        })}
      </div>
    </div>
  );
}
