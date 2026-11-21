import { useEffect, useRef, useState } from 'react';
import { post } from '../lib/nui';

const LIGHT_TXT = ['Lampu', 'Lampu dekat', 'Lampu jauh'];
const INIT = { name: 'Vehicle Control', engine: false, lights: 0, hazard: false, interior: false, locked: false, hood: false, trunk: false, doors: [0, 0, 0, 0], windows: [0, 0, 0, 0], seat: -1 };

const Sprite = () => (
  <svg width="0" height="0" style={{ position: 'absolute' }}>
    <symbol id="vc-i-engine" viewBox="0 0 24 24"><path d="M12 3v8" /><path d="M6.3 6.8a8 8 0 1 0 11.4 0" /></symbol>
    <symbol id="vc-i-lights" viewBox="0 0 24 24"><path d="M3 7c5 0 8 2 8 5s-3 5-8 5z" /><path d="M14 8h7M14 12h7M14 16h7" /></symbol>
    <symbol id="vc-i-hazard" viewBox="0 0 24 24"><path d="M12 3 2 20h20z" /><path d="M12 10v4M12 17v.5" /></symbol>
    <symbol id="vc-i-bulb" viewBox="0 0 24 24"><path d="M9 18h6M10 21h4" /><path d="M12 3a6 6 0 0 0-4 10.5c.7.7 1 1.5 1 2.5h6c0-1 .3-1.8 1-2.5A6 6 0 0 0 12 3z" /></symbol>
    <symbol id="vc-i-lock" viewBox="0 0 24 24"><rect x="5" y="11" width="14" height="10" rx="2" /><path d="M8 11V8a4 4 0 0 1 8 0v3" /></symbol>
    <symbol id="vc-i-unlock" viewBox="0 0 24 24"><rect x="5" y="11" width="14" height="10" rx="2" /><path d="M8 11V8a4 4 0 0 1 7.5-2" /></symbol>
    <symbol id="vc-i-door" viewBox="0 0 24 24"><path d="M6 21V8l4-4h7a1 1 0 0 1 1 1v16z" /><path d="M14 12h3" /></symbol>
    <symbol id="vc-i-hood" viewBox="0 0 24 24"><path d="M3 17l2-5h14l2 5z" /><path d="M5 17v3M19 17v3" /><path d="M7 12 10 6h4" /></symbol>
    <symbol id="vc-i-trunk" viewBox="0 0 24 24"><rect x="3" y="9" width="18" height="11" rx="2" /><path d="M8 9V6h8v3" /><path d="M12 13v3" /></symbol>
    <symbol id="vc-i-window" viewBox="0 0 24 24"><rect x="4" y="3" width="16" height="18" rx="2" /><path d="M4 10h16" /><path d="M12 13v5M9.5 15.5 12 18l2.5-2.5" /></symbol>
    <symbol id="vc-i-seat" viewBox="0 0 24 24"><path d="M8 3c-1 0-1.6.8-1.4 1.7L8 14h8l1.2 6" /><path d="M8 14l-1.2 6" /><path d="M13 14v-3" /></symbol>
  </svg>
);

function Btn({ id, a, i, icon, label, on, full }) {
  return (
    <div className={'vc-btn' + (full ? ' full' : '') + (on ? ' on' : '')} data-a={a} data-i={i} id={id}>
      <svg><use href={'#' + icon} /></svg><span className="t">{label}</span>
    </div>
  );
}

export default function VehicleMenu() {
  const [S, setS] = useState(INIT);
  const [show, setShow] = useState(false);
  const [vs, setVs] = useState(() => Math.min(innerWidth / 1920, innerHeight / 1080) * 0.8);
  const ref = useRef({ S: INIT, show: false });
  ref.current.S = S; ref.current.show = show;

  useEffect(() => {
    const fit = () => setVs(Math.min(innerWidth / 1920, innerHeight / 1080) * 0.8);
    const onMsg = e => {
      const m = e.data || {};
      if (m.action === 'vc:open') { setS(s => ({ ...s, ...(m.data || {}) })); setShow(true); }
      else if (m.action === 'vc:update') setS(s => ({ ...s, ...(m.data || {}) }));
      else if (m.action === 'vc:close') setShow(false);
    };
    const onKey = e => { if (e.key === 'Escape') close(); };
    addEventListener('resize', fit); addEventListener('message', onMsg); addEventListener('keydown', onKey);
    return () => { removeEventListener('resize', fit); removeEventListener('message', onMsg); removeEventListener('keydown', onKey); };
  }, []);

  function close() {
    if (!ref.current.show) return;
    setShow(false); post('vcClose');
  }

  function act(a, i) {
    const s = ref.current.S;
    const n = { ...s, doors: [...s.doors], windows: [...s.windows] };
    switch (a) {
      case 'engine': n.engine = !n.engine; break;
      case 'lights': n.lights = (n.lights + 1) % 3; break;
      case 'hazard': n.hazard = !n.hazard; break;
      case 'interior': n.interior = !n.interior; break;
      case 'lock': n.locked = !n.locked; break;
      case 'hood': n.hood = !n.hood; break;
      case 'trunk': n.trunk = !n.trunk; break;
      case 'door': n.doors[i] = n.doors[i] ? 0 : 1; break;
      case 'window': n.windows[i] = n.windows[i] ? 0 : 1; break;
      case 'seat': n.seat = i; break;
      default: return;
    }
    post('vcAction', { type: a, index: i, state: n });
    ref.current.S = n; setS(n);
  }

  const onClick = e => {
    const t = e.target.closest('.vc-btn'); if (!t) return;
    act(t.dataset.a, t.dataset.i !== undefined ? +t.dataset.i : undefined);
  };

  return (
    <>
      <Sprite />
      <div id="vcwrap" className={show ? 'show' : undefined} style={{ '--vs': vs }} onClick={onClick}>
        <div className="vc-box">
          <div className="vc-title"><span id="vcname">{S.name}</span><button id="vcclose" onClick={close}>&#10005;</button></div>
          <div className="vc-cols">
            <div className="vc-col">
              <div className="vc-sec">Mesin &amp; lampu</div>
              <div className="vc-grid">
                <Btn full a="engine" id="vc-engine" icon="vc-i-engine" on={S.engine} label={S.engine ? 'Mesin: Hidup' : 'Mesin: Mati'} />
                <Btn a="lights" id="vc-lights" icon="vc-i-lights" on={S.lights > 0} label={LIGHT_TXT[S.lights] || LIGHT_TXT[0]} />
                <Btn a="hazard" id="vc-hazard" icon="vc-i-hazard" on={S.hazard} label="Hazard" />
                <Btn a="interior" id="vc-interior" icon="vc-i-bulb" on={S.interior} label="Lampu dalam" />
                <Btn a="lock" id="vc-lock" icon={S.locked ? 'vc-i-lock' : 'vc-i-unlock'} on={S.locked} label={S.locked ? 'Terkunci' : 'Kunci'} />
              </div>
            </div>
            <div className="vc-col">
              <div className="vc-sec">Pintu</div>
              <div className="vc-grid">
                {['Depan kiri', 'Depan kanan', 'Belakang kiri', 'Belakang kanan'].map((l, i) => <Btn key={i} a="door" i={i} id={'vc-door' + i} icon="vc-i-door" on={S.doors[i]} label={l} />)}
                <Btn a="hood" id="vc-hood" icon="vc-i-hood" on={S.hood} label="Kap mesin" />
                <Btn a="trunk" id="vc-trunk" icon="vc-i-trunk" on={S.trunk} label="Bagasi" />
              </div>
            </div>
            <div className="vc-col">
              <div className="vc-sec">Jendela</div>
              <div className="vc-grid">
                {['Depan kiri', 'Depan kanan', 'Belakang kiri', 'Belakang kanan'].map((l, i) => <Btn key={i} a="window" i={i} id={'vc-window' + i} icon="vc-i-window" on={S.windows[i]} label={l} />)}
              </div>
            </div>
            <div className="vc-col">
              <div className="vc-sec">Kursi</div>
              <div className="vc-grid">
                {[[-1, 'Sopir'], [0, 'Penumpang'], [1, 'Belakang kiri'], [2, 'Belakang kanan']].map(([i, l]) => <Btn key={i} a="seat" i={i} id={'vc-seat' + i} icon="vc-i-seat" on={S.seat === i} label={l} />)}
              </div>
            </div>
          </div>
          <div className="vc-foot">Esc untuk menutup</div>
        </div>
      </div>
    </>
  );
}
