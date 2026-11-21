const ROW1 = ['health', 'armor'], ROW2 = ['hunger', 'thirst'], ROW3 = ['stress', 'stamina', 'oxygen'];
const LOW = new Set(['health', 'hunger', 'thirst', 'stamina', 'oxygen']);
const COL = { health: '#F3163E', armor: '#00A3FF', hunger: '#ADFE00', thirst: '#00FFF0', stress: '#FF0099', stamina: '#FFA048', oxygen: '#5AC8FA' };
const KEYS = [...ROW1, ...ROW2, ...ROW3];

export default function LineHud({ cfg, state, prefs, ready, hide, view }) {
  const c = cfg || {};
  const enabled = !!c.enabled;
  const show = c.show || {}, hEmpty = c.hideEmpty || {}, hFull = c.hideFull || {}, lowAt = c.lowAt ?? 17;

  const items = {}; let n1 = 0, n2 = 0, n3 = 0;
  for (const k of KEYS) {
    const v = Math.max(0, Math.min(100, Math.round(state[k] ?? 0)));
    let on = ready && show[k] !== false && prefs.status[k] !== false;
    if (on && hEmpty[k] && v <= 0) on = false;
    if (on && hFull[k] && v >= 100) on = false;
    const low = on && LOW.has(k) && v < lowAt;
    if (on) { if (ROW1.includes(k)) n1++; else if (ROW2.includes(k)) n2++; else n3++; }
    items[k] = { on, low, v };
  }

  const rr = c.rounded === false ? 0 : (c.radius ?? 5);
  const style = {
    zoom: view.z,
    '--lr': rr + 'px',
    '--lr2': Math.min(rr, Math.floor((c.height2 || 5) / 2)) + 'px',
    '--lh': (c.height || 6) + 'px',
    '--lh2': (c.height2 || 4) + 'px',
    '--lg': (c.gap ?? 4) + 'px',
    '--lg2': (c.rowGap ?? 7) + 'px',
  };
  if (enabled) {
    style.left = ((c.left || 0) * view.rx) + 'px';
    style.bottom = (c.bottom || 0) + 'px';
    style.width = ((c.width || 312) * view.rx) + 'px';
  }

  const row = (keys, id, cls, n) => (
    <div className={'ln-row ' + cls} id={id} style={n ? undefined : { display: 'none' }}>
      {keys.map(k => (
        <div key={k} className={'ln' + (items[k].on ? '' : ' off') + (items[k].low ? ' low' : '')}
          style={{ '--c': (c.colors && c.colors[k]) || COL[k], '--p': (items[k].v / 100).toFixed(3) }}>
          <u />
        </div>
      ))}
    </div>
  );

  return (
    <div className={'lines' + (enabled ? ' on' : '') + (hide ? ' hide' : '')} id="lines" style={style}>
      {row(ROW1, 'lnr1', 'ln-r1', n1)}
      <div className="ln-below">
        {row(ROW2, 'lnr2', 'ln-r2', n2)}
        {row(ROW3, 'lnr3', 'ln-r3', n3)}
      </div>
    </div>
  );
}
