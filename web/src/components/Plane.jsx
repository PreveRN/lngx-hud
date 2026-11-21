import { memo, useEffect, useMemo, useRef, useState } from 'react';
import { cx } from '../lib/nui';
import { useT } from '../lib/i18n';

const MAXA = 6000, PX = 4, ARC = 395.8;
const L = (a, b, k) => a + (b - a) * k;
const LA = (a, b, k) => { const d = ((b - a + 540) % 360) - 180; return (a + d * k + 360) % 360; };

function Ticks({ major, minor, step, fmt }) {
  const n = major * minor, out = [];
  for (let i = 0; i <= n; i++) {
    const a = (135 + i / n * 270) * Math.PI / 180, M = i % minor === 0, r1 = M ? 64 : 70, c = Math.cos(a), s = Math.sin(a);
    out.push(<line key={'l' + i} x1={(100 + r1 * c).toFixed(1)} y1={(100 + r1 * s).toFixed(1)} x2={(100 + 77 * c).toFixed(1)} y2={(100 + 77 * s).toFixed(1)}
      stroke={M ? '#f2f8ff' : '#6f869b'} strokeWidth={M ? 1.8 : 1} />);
    if (M) out.push(<text key={'t' + i} x={(100 + 54 * c).toFixed(1)} y={(100 + 54 * s + 4).toFixed(1)} fill="#b9cde0" fontSize="11.5" fontWeight="700" textAnchor="middle">{fmt(i / minor * step)}</text>);
  }
  return out;
}
const SpeedTicks = memo(({ heli }) => <Ticks major={8} minor={5} step={heli ? 25 : 50} fmt={v => v} />);
const AltTicks = memo(() => <Ticks major={6} minor={5} step={1000} fmt={v => v / 1000} />);

const PITCH = [-30, -20, -10, 10, 20, 30].map(p => {
  const y = 100 - p * 1.7, w = Math.abs(p) % 20 === 0 ? 28 : 18;
  return <line key={p} x1={100 - w} y1={y} x2={100 + w} y2={y} />;
});

const CARD = { 0: 'N', 90: 'E', 180: 'S', 270: 'W' };
const TAPE = (() => {
  const out = [];
  for (let d = -180; d <= 540; d += 5) {
    const dg = ((d % 360) + 360) % 360, x = (d + 180) * PX;
    if (d % 10) { out.push(<i key={d} style={{ left: x }} />); continue; }
    const mj = d % 30 === 0;
    out.push(<i key={d} className={mj ? 'pl-m' : undefined} style={{ left: x }}>{mj ? <b className={CARD[dg] ? 'pl-c' : undefined}>{CARD[dg] || dg}</b> : null}</i>);
  }
  return out;
})();

const ST_ALT = { stroke: 'var(--cy)', color: 'var(--cy)' };
const ST_SPD = { stroke: 'url(#pl-g)', color: '#ffb020' };
const GLOW_CY = { filter: 'drop-shadow(0 0 4px #35e0ff)' };
const GLOW_AM = { filter: 'drop-shadow(0 0 4px #ffb020)' };
const GLOW_AM2 = { filter: 'drop-shadow(0 0 4px #ffb020)' };
const ST_VS = { top: '70%' };
const ST_HD = { top: '14%', color: 'var(--cy)' };
const NEEDLE = '84,97.6 168,99.2 176,100 168,100.8 84,102.4';
const Ico = ({ children }) => <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">{children}</svg>;

const BELT_CLS = { hide: 'pl-hide', ok: 'pl-ok', warn: 'pl-warn', off: 'pl-off' };

export default function Plane({ gone }) {
  const t = useT();
  const rootRef = useRef(null), hudRef = useRef(null);
  const [active, setActive] = useState(false);
  const [heli, setHeli] = useState(false);
  const [lay, setLay] = useState(null);
  const [scale, setScale] = useState(1);
  const [disc, setDisc] = useState({ gear: true, flaps: 0, stall: false, belt: 'hide', cruise: 'hide', nav: null });
  const userScale = useRef(.42);
  const fitRef = useRef(() => {});

  useEffect(() => {
    const fit = () => setScale(Math.max(.4, Math.min(innerWidth / 1920, innerHeight / 1080)) * userScale.current);
    fitRef.current = fit;
    fit();
    addEventListener('resize', fit);
    return () => removeEventListener('resize', fit);
  }, []);

  useEffect(() => {
    const root = rootRef.current;
    const g = id => root.querySelector('#pl-' + id);
    const el = {
      sArc: g('sArc'), sN: g('sN'), aArc: g('aArc'), aN: g('aN'), hz: g('hz'), mach: g('mach'), vsP: g('vsP'), hdP: g('hdP'),
      thr: g('thr'), thrM: g('thrM'), thrT: g('thrT'), fuel: g('fuel'), fuM: g('fuM'), fuT: g('fuT'), fuP: g('fuP'), strip: g('strip'),
    };

    let MAXS = 400, isHeli = false;
    const cur = { s: 0, a: 0, v: 0, h: 0, t: 0, f: 100, p: 0, r: 0 };
    const tg = { s: 0, a: 0, v: 0, h: 0, t: 0, f: 100, p: 0, r: 0, gear: true, flaps: 0, stall: false, belt: null, cruise: null, nd: null, na: 0, nz: '', nr: 30 };
    const C = Object.create(null);
    const txt = (k, v) => { if (C[k] !== v) { C[k] = v; el[k].textContent = v; } };
    const set = (k, prop, v) => { if (C[k + prop] !== v) { C[k + prop] = v; el[k].style[prop] = v; } };
    const cn = (k, v) => { if (C[k + 'c'] !== v) { C[k + 'c'] = v; el[k].className = v; } };
    let raf = 0, stopT = 0, isActive = false, snap = false, navCur = 0, discKey = '';

    function loop() {
      cur.s = L(cur.s, tg.s, .14); cur.a = L(cur.a, tg.a, .14); cur.v = L(cur.v, tg.v, .12);
      cur.h = LA(cur.h, tg.h, .16); cur.t = L(cur.t, tg.t, .15); cur.f = L(cur.f, tg.f, .1);
      cur.p = L(cur.p, tg.p, .16); cur.r = L(cur.r, tg.r, .16);

      const sp = Math.max(0, cur.s), ps = Math.min(1, sp / MAXS), pa = Math.max(0, Math.min(1, cur.a / MAXA));
      set('sArc', 'strokeDashoffset', (ARC * (1 - ps)).toFixed(2));
      el.sN.setAttribute('transform', 'rotate(' + (135 + 270 * ps).toFixed(2) + ' 100 100)');
      txt('mach', 'M ' + (sp / 661).toFixed(2));
      set('aArc', 'strokeDashoffset', (ARC * (1 - pa)).toFixed(2));
      el.aN.setAttribute('transform', 'rotate(' + (135 + 270 * pa).toFixed(2) + ' 100 100)');
      el.hz.setAttribute('transform', 'rotate(' + (-cur.r).toFixed(2) + ' 100 100) translate(0 ' + (cur.p * 1.7).toFixed(2) + ')');

      const v = Math.round(cur.v / 10) * 10;
      txt('vsP', (v > 0 ? '+' : '') + v.toLocaleString(document.documentElement.lang === 'en' ? 'en-US' : 'id-ID') + ' fpm');
      cn('vsP', 'pl-pill ' + (v > 50 ? 'pl-up' : (v < -50 ? 'pl-dn' : '')));
      txt('hdP', ('00' + (Math.round(cur.h) % 360)).slice(-3) + '\u00b0');
      el.strip.style.transform = 'translateX(' + (320 - (cur.h + 180) * PX).toFixed(1) + 'px)';

      const tp = Math.max(0, Math.min(100, cur.t * 100)), fp = Math.max(0, Math.min(100, cur.f));
      txt('thr', Math.round(tp) + '%'); set('thrM', 'width', tp.toFixed(1) + '%'); set('thrT', 'left', tp.toFixed(1) + '%');
      txt('fuel', Math.round(fp) + '%'); set('fuM', 'width', (100 - fp).toFixed(1) + '%'); set('fuT', 'left', fp.toFixed(1) + '%');
      cn('fuP', 'pl-it' + (fp < 20 ? ' pl-low' : ''));
      raf = requestAnimationFrame(loop);
    }

    function applyDiscrete() {
      let nav = null;
      if (tg.nd != null) {
        const arr = tg.nd <= tg.nr;
        navCur += ((tg.na - navCur + 540) % 360) - 180;
        nav = { arr, zone: tg.nz, dist: arr ? 'TIBA' : (tg.nd >= 1000 ? (tg.nd / 1000).toFixed(1).replace('.', ',') + ' km' : tg.nd + ' m'), rot: navCur };
      }

      const next = {
        gear: tg.gear, flaps: tg.flaps, stall: tg.stall,
        belt: tg.belt == null ? 'hide' : (tg.belt ? 'ok' : (tg.s > 10 ? 'warn' : 'off')),
        cruise: tg.cruise == null ? 'hide' : (tg.cruise ? 'ok' : 'off'),
        nav,
      };
      const key = JSON.stringify(next);
      if (key !== discKey) { discKey = key; setDisc(next); }
    }

    function activate(on) {
      if (on === isActive) return;
      isActive = on; setActive(on);
      clearTimeout(stopT);
      if (on) { snap = true; if (!raf) raf = requestAnimationFrame(loop); }
      else stopT = setTimeout(() => { cancelAnimationFrame(raf); raf = 0; }, 500);
    }

    function setHeliMode(h) {
      h = !!h; if (h === isHeli) return;
      isHeli = h; MAXS = h ? 200 : 400; setHeli(h);
    }

    function update(d) {
      if (d.speed != null) tg.s = +d.speed || 0;
      if (d.altitude != null) tg.a = +d.altitude || 0;
      if (d.vspeed != null) tg.v = +d.vspeed || 0;
      if (d.heading != null) tg.h = +d.heading || 0;
      if (d.pitch != null) tg.p = +d.pitch || 0;
      if (d.roll != null) tg.r = +d.roll || 0;
      if (d.throttle != null) tg.t = +d.throttle || 0;
      if (d.fuel != null) tg.f = +d.fuel;
      if (d.gear != null) tg.gear = !!d.gear;
      if (d.flaps != null) tg.flaps = Math.max(0, Math.min(3, d.flaps | 0));
      tg.stall = !!d.stall;
      tg.belt = (d.belt == null) ? null : !!d.belt;
      tg.cruise = (d.cruise == null) ? null : !!d.cruise;
      setHeliMode(d.heli);
      tg.nd = (typeof d.navDist === 'number') ? d.navDist : null;
      tg.na = +d.navAng || 0; tg.nz = d.destZone || ''; tg.nr = +d.navArrive || 150;
      if (snap) { snap = false; Object.assign(cur, { s: tg.s, a: tg.a, v: tg.v, h: tg.h, t: tg.t, f: tg.f, p: tg.p, r: tg.r }); }
      applyDiscrete();
    }

    const onMsg = e => {
      const m = e.data; if (!m || m.action !== 'plane') return;
      const d = m.data || {};
      if (d.show === false) activate(false);
      else {
        if (d.layout) {
          setLay({ right: +d.layout.right || 0, bottom: +d.layout.bottom || 0 });
          userScale.current = Math.max(.2, Math.min(1.5, +d.layout.scale || .42));
          fitRef.current();
        }
        activate(true); update(d);
      }
    };
    addEventListener('message', onMsg);
    return () => { removeEventListener('message', onMsg); cancelAnimationFrame(raf); clearTimeout(stopT); };
  }, []);

  const hudStyle = lay ? { '--pr': lay.right + 'px', '--pb': lay.bottom + 'px' } : undefined;
  const nav = disc.nav, dl = t('ui.dest', 'TUJUAN');
  const flapsTxt = ['0', '10', '20', '30'][disc.flaps] + '\u00b0';

  return (
    <div id="plane" ref={rootRef} className={cx(heli && 'pl-heli', gone && 'pl-gone')} style={{ transform: 'scale(' + scale.toFixed(4) + ')' }}>
      <div id="pl-hud" ref={hudRef} className={active ? undefined : 'pl-hidden'} style={hudStyle}>
        <div id="pl-tape"><div id="pl-strip">{TAPE}</div><div id="pl-mark" /></div>
        <div id="pl-nav" className={nav ? cx('pl-on', nav.arr && 'pl-arr') : undefined}>
          <div className="pl-nr"><svg id="pl-nvar" viewBox="0 0 24 24" style={nav ? { transform: `rotate(${nav.rot}deg)` } : undefined}><path d="M12 3l7 17-7-4-7 4z" /></svg></div>
          <div className="pl-nt"><small id="pl-nvl">{nav && nav.zone ? dl + ' \u00b7 ' + nav.zone.toUpperCase() : dl}</small><b id="pl-nvd">{nav ? nav.dist : '0 m'}</b></div>
        </div>

        <div className="pl-row">

          <div className="pl-dial pl-side">
            <svg viewBox="0 0 200 200">
              <g id="pl-aT"><AltTicks /></g>
              <circle className="pl-trk" cx="100" cy="100" r="84" />
              <circle className="pl-arc" id="pl-aArc" cx="100" cy="100" r="84" style={ST_ALT} />
              <g id="pl-aN" style={GLOW_CY}><polygon points={NEEDLE} fill="#fff" /></g>
              <circle cx="100" cy="100" r="8" fill="#0a121b" stroke="#fff" strokeWidth="2.4" />
              <circle cx="100" cy="100" r="2.6" fill="#35e0ff" />
            </svg>
            <div className="pl-txt pl-kn"><div className="pl-lb">ALT</div><div className="pl-un" style={{ marginTop: 0 }}>FT</div></div>
          </div>

          <div className="pl-dial pl-main">
            <svg viewBox="0 0 200 200">
              <defs><linearGradient id="pl-g" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stopColor="#35e0ff" /><stop offset=".6" stopColor="#ffb020" /><stop offset="1" stopColor="#ff3b3b" /></linearGradient></defs>
              <g id="pl-sT"><SpeedTicks heli={heli} /></g>
              <circle className="pl-trk" cx="100" cy="100" r="84" />
              <circle className="pl-arc" id="pl-sArc" cx="100" cy="100" r="84" style={ST_SPD} />
              <g id="pl-sN" style={GLOW_AM}><polygon points={NEEDLE} fill="#ffb020" /></g>
              <circle cx="100" cy="100" r="8" fill="#0a121b" stroke="#ffb020" strokeWidth="2.4" />
              <circle cx="100" cy="100" r="2.6" fill="#ffb020" />
            </svg>
            <div id="pl-stall" className={disc.stall ? 'pl-on' : ''}>{t('ui.plane.stall', 'STALL')}</div>
            <div className="pl-txt pl-kn"><div className="pl-un">{t('ui.plane.knot', 'KNOT')}</div><div id="pl-mach" /></div>
            <div className="pl-ind">
              <div id="pl-belt" className={'pl-ic ' + BELT_CLS[disc.belt]}><Ico><circle cx="12" cy="4.5" r="2" /><path d="M12 8c-2.500 0-4 1.200-4 3.500V15l1 6M12 8c2.500 0 4 1.200 4 3.500V15l-1 6" /><path d="M8 9.500l8 7" /></Ico></div>
              <div id="pl-cr" className={'pl-ic ' + (disc.cruise === 'hide' ? 'pl-hide' : disc.cruise === 'ok' ? 'pl-ok' : 'pl-off')}><Ico><path d="M4 17a8 8 0 1 1 16 0" /><path d="M12 17l4-5" /><circle cx="12" cy="17" r="1" /><path d="M6.500 11.500l1 .6M12 8.500V10M17.500 11.500l-1 .6" /></Ico></div>
            </div>
          </div>

          <div className="pl-dial pl-side">
            <svg viewBox="0 0 200 200">
              <defs>
                <clipPath id="pl-cp"><circle cx="100" cy="100" r="86" /></clipPath>
                <linearGradient id="pl-sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#1a63c9" /><stop offset="1" stopColor="#58b4ff" /></linearGradient>
                <linearGradient id="pl-gnd" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#8a5a2b" /><stop offset="1" stopColor="#3b2512" /></linearGradient>
              </defs>
              <g clipPath="url(#pl-cp)"><g id="pl-hz">
                <rect x="-200" y="-300" width="600" height="400" fill="url(#pl-sky)" />
                <rect x="-200" y="100" width="600" height="400" fill="url(#pl-gnd)" />
                <g id="pl-pl" stroke="#fff" strokeWidth="1.4">{PITCH}</g>
                <line x1="-200" y1="100" x2="400" y2="100" stroke="#fff" strokeWidth="2.2" />
              </g></g>
              <circle cx="100" cy="100" r="86" fill="none" stroke="rgba(255,255,255,.25)" strokeWidth="2" />
              <path d="M60 104h28M112 104h28M100 98l-5 -9h10z" stroke="#ffb020" strokeWidth="3.4" fill="#ffb020" strokeLinejoin="round" style={GLOW_AM2} />
              <circle cx="100" cy="104" r="3.4" fill="#ffb020" />
            </svg>
            <div className="pl-pill" id="pl-vsP" style={ST_VS} />
            <div className="pl-pill" id="pl-hdP" style={ST_HD} />
          </div>
        </div>

        <div className="pl-sys">
          <div className="pl-it" id="pl-thrP"><div className="pl-lb">{t('ui.plane.throttle', 'THROTTLE')}</div><b className="pl-n" id="pl-thr" /><div className="pl-ln pl-th"><u id="pl-thrM" /><s id="pl-thrT" /></div><div className="pl-tk"><span>0</span><span>50</span><span>100</span></div></div>
          <div className="pl-it" id="pl-fuP"><div className="pl-lb"><span>{t('ui.plane.fuel', 'BAHAN BAKAR')}</span><em id="pl-low">{t('ui.plane.low', 'LOW')}</em></div><b className="pl-n" id="pl-fuel" /><div className="pl-ln pl-fu"><u id="pl-fuM" /><s id="pl-fuT" /></div><div className="pl-tk"><span>E</span><span>{'\u00bd'}</span><span>F</span></div></div>

          <div className="pl-it pl-sm pl-tile pl-gf"><div className="pl-lb">{t('ui.plane.gear', 'RODA')}</div>
            <div className={'pl-st ' + (disc.gear ? 'pl-ok' : 'pl-off')} id="pl-gear">
              <Ico><path d="M12 2.500v9" /><path d="M7.500 6h9" /><g className="pl-wh"><path d="M12 11.500v3" /><circle cx="12" cy="18" r="3.500" /><circle cx="12" cy="18" r="1" fill="currentColor" /></g></Ico>
              <b id="pl-gearT">{disc.gear ? t('ui.plane.gear_down', 'Turun') : t('ui.plane.gear_up', 'Naik')}</b>
            </div></div>
          <div className="pl-it pl-sm pl-tile pl-gf"><div className="pl-lb">{t('ui.plane.flaps', 'FLAPS')}</div>
            <div className={'pl-fl ' + (disc.flaps ? 'pl-f' + disc.flaps : 'pl-z')}>
              <Ico><path d="M2.500 8h13l5 2.500-5 .5H2.500z" /><g className="pl-flp"><path d="M4 14.500h8l-2.500 5.500H4z" /></g></Ico>
              <div className="pl-pips" id="pl-flaps">{[0, 1, 2].map(k => <i key={k} className={k < disc.flaps ? 'pl-on' : ''} />)}</div>
              <b id="pl-flapsT">{flapsTxt}</b>
            </div></div>
        </div>
      </div>
    </div>
  );
}
