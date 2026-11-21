import { memo, useEffect, useRef, useState } from 'react';
import { clamp, cx } from '../lib/nui';
import { useT } from '../lib/i18n';

function useSpeedoAnim(d, SEG) {
  const [view, setView] = useState({ digits: '000', lit: 0 });
  const s = useRef({ tgS: 0, tgR: 0, shS: 0, shR: 0, raf: 0, active: false, snap: true, hideT: 0 });
  const tick = useRef(null);

  useEffect(() => {
    const q = s.current;
    const draw = () => {
      const digits = String(clamp(Math.round(q.shS), 0, 999)).padStart(3, '0');
      const lit = Math.round(clamp(q.shR, 0, 1) * SEG);
      setView(p => (p.digits === digits && p.lit === lit ? p : { digits, lit }));
    };
    tick.current = () => {
      q.shS += (q.tgS - q.shS) * 0.35;
      q.shR += (q.tgR - q.shR) * 0.4;
      draw();
      q.raf = requestAnimationFrame(tick.current);
    };
    return () => { cancelAnimationFrame(q.raf); q.raf = 0; clearTimeout(q.hideT); };
  }, [SEG]);

  useEffect(() => {
    const q = s.current;
    if (d) {
      clearTimeout(q.hideT);
      if (!q.active) { q.active = true; q.snap = true; }
      q.tgS = Math.max(0, +d.speed || 0); q.tgR = clamp(+d.rpm || 0, 0, 1);
      if (q.snap) { q.snap = false; q.shS = q.tgS; q.shR = q.tgR; }
      if (!q.raf) q.raf = requestAnimationFrame(tick.current);
    } else if (q.active) {
      q.active = false; clearTimeout(q.hideT);
      q.hideT = setTimeout(() => { cancelAnimationFrame(q.raf); q.raf = 0; }, 400);
    }
  }, [d]);

  return view;
}

function Digits({ digits }) {
  let lead = true;
  return digits.split('').map((ch, i) => {
    if (lead && ch === '0' && i < 2) return <span key={i} className="ghost">0</span>;
    lead = false;
    return <span key={i}>{ch}</span>;
  });
}

function useVeh(d) {
  const last = useRef(null);
  if (d) last.current = d;
  return d || last.current || {};
}

function gearText(v) {
  const rev = v.gear === 'R';
  return { rev, text: rev ? 'R' : ((v.gear === undefined || v.gear === null || v.gear === 0) ? 'N' : String(v.gear)) };
}
function unitText(v, t) {
  const u = (v.unit || 'km/h').toLowerCase();
  return u === 'mph' ? t('ui.unit.mph', 'MP/H') : (u === 'km/h' ? t('ui.unit.kmh', 'KM/H') : u.toUpperCase());
}
const fuelOf = v => Math.round(clamp(Number.isFinite(+v.fuel) ? +v.fuel : 100, 0, 100));
const segColor = (i, SEG) => {
  const k = Math.min(1, Math.max(0, (i / (SEG - 1) - 0.65) / 0.3));
  return `rgb(255,${Math.round(255 - k * 195)},${Math.round(255 - k * 189)})`;
};

const SvgIcon = ({ children }) => <svg viewBox="0 0 24 24">{children}</svg>;
const ICON = {
  belt: <SvgIcon><circle cx="12" cy="4.5" r="2.5" /><path d="M6.5 21v-7.5a5.5 5.5 0 0 1 11 0V21" /><path d="M8 11.5l9 6.5" /></SvgIcon>,
  cruise: <SvgIcon><path d="M3.5 17a8.5 8.5 0 1 1 17 0" /><path d="M12 17l4-5" /><circle cx="12" cy="17" r="1" /></SvgIcon>,
  light: <SvgIcon><path d="M9 5c4.5 0 7 3 7 7s-2.5 7-7 7c-1.5 0-2-1-2-2V7c0-1 .5-2 2-2z" /><path d="M19 8h3M19 12h3M19 16h3" /></SvgIcon>,
  engine: <SvgIcon><path d="M5 9h3V7h6v2h2l3 3v4h-2l-2 2H9l-2-2H5z" /><path d="M2 11v5" /></SvgIcon>,
  fuel: <SvgIcon><path d="M4 21V5a1 1 0 0 1 1-1h7a1 1 0 0 1 1 1v16" /><path d="M3 21h11" /><path d="M6.5 8h4" /><path d="M13 9h2.5a1.5 1.5 0 0 1 1.5 1.5V16a1.5 1.5 0 0 0 3 0V9l-3-3" /></SvgIcon>,
};

const CX = 100, CY = 100, R = 84, SEG_RG = 36, START = 135, SWEEP = 270, GAP = 1.6, OFF = 'rgba(255,255,255,.22)';
const pt = (a, r) => { const t = a * Math.PI / 180; return [CX + r * Math.cos(t), CY + r * Math.sin(t)]; };
const arc = (a0, a1, r) => {
  const [x0, y0] = pt(a0, r), [x1, y1] = pt(a1, r);
  return 'M' + x0.toFixed(2) + ' ' + y0.toFixed(2) + ' A' + r + ' ' + r + ' 0 ' + ((a1 - a0) > 180 ? 1 : 0) + ' 1 ' + x1.toFixed(2) + ' ' + y1.toFixed(2);
};

const RG_STATIC = (() => {
  const ticks = [];
  for (let k = 0; k <= 16; k++) {
    const major = k % 2 === 0, a = START + SWEEP * (k / 16);
    const [x0, y0] = pt(a, R + 8), [x1, y1] = pt(a, R + (major ? 13 : 11));
    const p = { x1: x0.toFixed(2), y1: y0.toFixed(2), x2: x1.toFixed(2), y2: y1.toFixed(2) };
    ticks.push(<line key={'s' + k} className="tick-shadow" {...p} />);
    ticks.push(<line key={'l' + k} className="tick-line" strokeWidth={major ? 1.6 : 1} {...p} />);
  }
  const labels = [];
  for (let n = 0; n <= 8; n++) {
    const [x, y] = pt(START + SWEEP * (n / 8), R + 21);
    labels.push(<text key={n} className="tick" x={x.toFixed(2)} y={y.toFixed(2)}>{n}</text>);
  }
  return { ticks, labels };
})();
const RG_SEGS = Array.from({ length: SEG_RG }, (_, i) => ({
  d: arc(START + SWEEP * (i / SEG_RG) + GAP / 2, START + SWEEP * ((i + 1) / SEG_RG) - GAP / 2, R),
  color: segColor(i, SEG_RG),
}));

const RgGauge = memo(function RgGauge({ lit }) {
  return (
    <svg id="rgsvg" viewBox="-12 -12 224 224">
      <defs>
        <radialGradient id="rgFill" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stopColor="#000" stopOpacity=".36" />
          <stop offset="72%" stopColor="#000" stopOpacity=".26" />
          <stop offset="100%" stopColor="#000" stopOpacity="0" />
        </radialGradient>
      </defs>
      <circle cx={CX} cy={CY} r="82" fill="url(#rgFill)" />
      <circle className="ring-shadow" cx={CX} cy={CY} r="70" />
      <circle className="ring" cx={CX} cy={CY} r="70" />
      <path className="track" d={arc(START - 1.5, START + SWEEP + 1.5, R)} />
      {RG_SEGS.map((s, i) => <path key={i} className="seg" d={s.d} style={{ stroke: i < lit ? s.color : OFF }} />)}
      {RG_STATIC.ticks}
      {RG_STATIC.labels}
    </svg>
  );
});

export function SpeedoRound({ d, hide, zoom }) {
  const t = useT();
  const view = useSpeedoAnim(d, SEG_RG);
  const v = useVeh(d);
  const { rev, text } = gearText(v);
  const hasBelt = typeof v.seatbelt === 'boolean', hasCruise = typeof v.cruise === 'boolean';
  const f = fuelOf(v);
  const ico = (id, c, gone) => cx('rg-ico', c, gone && 'gone');
  return (
    <div className={cx('rg', d && 'on', hide && 'hide')} id="rg" style={{ zoom }}>
      <div className="rg-gauge">
        <RgGauge lit={view.lit} />
        <div className="rg-center">
          <div className={cx('rg-gear', rev && 'rev')} id="rggear"><b>{text}</b></div>
          <div className="rg-speed" id="rgspeed"><Digits digits={view.digits} /></div>
          <div className="rg-unit" id="rgunit">{unitText(v, t)}</div>
        </div>
      </div>
      <div className="rg-icons">
        <div className={ico('belt', v.seatbelt ? 'on' : ((v.speed || 0) > 10 ? 'red' : ''), !hasBelt)} id="rgBelt">{ICON.belt}</div>
        <div className={ico('cruise', hasCruise && v.cruise ? 'on' : '', !hasCruise)} id="rgCruise">{ICON.cruise}</div>
        <div className={ico('light', (v.lights || v.highBeam) ? 'on' : '')} id="rgLight">{ICON.light}</div>
        <div className={ico('engine', v.engineOn === false ? '' : ((+v.engine || 0) < 30 ? 'red' : 'on'))} id="rgEngine">{ICON.engine}</div>
        <div className={ico('fuel', f <= 15 ? 'red' : 'on')} id="rgFuel">{ICON.fuel}<span id="rgFuelVal">{f}</span></div>
      </div>
    </div>
  );
}

const SEG_PG = 28, FSEG = 10;
const PG_COLORS = Array.from({ length: SEG_PG }, (_, i) => segColor(i, SEG_PG));

export function SpeedoPetrol({ d, hide }) {
  const t = useT();
  const view = useSpeedoAnim(d, SEG_PG);
  const v = useVeh(d);
  const { rev, text } = gearText(v);
  const hasBelt = typeof v.seatbelt === 'boolean', hasCruise = typeof v.cruise === 'boolean';
  const f = fuelOf(v);
  const litF = Math.ceil(f / FSEG);
  const cv = hasCruise && v.cruise && v.cruiseSpeed ? String(v.cruiseSpeed) : '';
  const ico = (c, gone) => cx('pg-ico', c, gone && 'gone');
  return (
    <div className={cx('pg', d && 'on', hide && 'hide')} id="pg">
      <div className="pg-fuelcol">
        <div className={ico(f <= 15 ? 'red' : 'on')} id="pgFuel">{ICON.fuel}</div>
        <div className={cx('pg-fuelbar', f <= 20 && 'low')} id="pgFuelBar">
          {Array.from({ length: FSEG }, (_, i) => <i key={i} className={i < litF ? 'on' : undefined} />)}
        </div>
        <div className="pg-fuelpct"><span id="pgFuelVal">{f}</span><small>%</small></div>
      </div>
      <div className="pg-main">
        <div className="pg-top">
          <div className={cx('pg-gear', rev && 'rev')} id="pgGear"><b>{text}</b></div>
          <div className="pg-speed" id="pgSpeed"><Digits digits={view.digits} /></div>
          <div className="pg-unit" id="pgUnit">{unitText(v, t)}</div>
        </div>
        <div className="pg-rpm" id="pgRpm">
          {PG_COLORS.map((c, i) => <i key={i} className={i < view.lit ? 'on' : undefined} style={{ '--c': c }} />)}
        </div>
        <div className="pg-icons">
          <div className={ico(v.seatbelt ? 'on' : ((v.speed || 0) > 10 ? 'red' : ''), !hasBelt)} id="pgBelt">{ICON.belt}</div>
          <div className={ico(hasCruise && v.cruise ? 'on' : '', !hasCruise)} id="pgCruise">{ICON.cruise}<span id="pgCruiseVal">{cv}</span></div>
          <div className={ico((v.lights || v.highBeam) ? 'on' : '')} id="pgLight">{ICON.light}</div>
          <div className={ico(v.engineOn === false ? '' : ((+v.engine || 0) < 30 ? 'red' : 'on'))} id="pgEngine">{ICON.engine}</div>
        </div>
      </div>
    </div>
  );
}
