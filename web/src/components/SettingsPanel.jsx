import { useEffect, useRef, useState } from 'react';
import { cx } from '../lib/nui';
import { useT } from '../lib/i18n';
import { playSound } from '../lib/sound';

const STATUS_DEF = [['health', 'Darah'], ['armor', 'Armor'], ['hunger', 'Lapar'], ['thirst', 'Haus'], ['stress', 'Stres'], ['stamina', 'Stamina'], ['oxygen', 'Oksigen'], ['premium', 'Premium']];

function buildSections(t) {
  const r = (k, d, type, extra) => ({ k, l: t('ui.row.' + k.replace(/^info\./, ''), d), type, ...extra });
  return [
    { t: t('ui.sec.general', 'Umum'), rows: [r('visible', 'Tampilkan HUD', 'switch'), r('weapon', 'Tampilkan ikon senjata', 'switch'), r('style', 'Gaya status', 'seg', { opts: [['ring', t('ui.style.ring', 'Bulat')], ['line', t('ui.style.line', 'Garis')]] })] },
    { t: t('ui.sec.status', 'Ikon status'), rows: STATUS_DEF.map(([k, d]) => ({ k: 'status.' + k, l: t('ui.status.' + k, d), type: 'switch' })) },
    { t: t('ui.sec.info', 'Info pemain'), rows: [
      r('info', 'Tampilkan info pemain', 'switch'),
      r('info.id', 'ID', 'switch'),
      r('info.job', 'Job', 'switch'),
      r('info.cash', 'Uang cash', 'switch'),
      r('info.bank', 'Uang bank', 'switch'),
      r('info.black', 'Uang kotor', 'switch')] },
    { t: t('ui.sec.speedo', 'Speedometer'), rows: [
      r('speedo', 'Tampilkan speedometer', 'switch'),
      r('speedoStyle', 'Gaya speedometer', 'seg', { opts: [['round', t('ui.speedoStyle.round', 'Bulat')], ['petrol', t('ui.speedoStyle.petrol', 'Bensin')]] }),
      r('unit', 'Satuan kecepatan', 'seg', { opts: [['kmh', t('ui.unit.kmh', 'KM/H')], ['mph', t('ui.unit.mph', 'MP/H')]] }),
      r('location', 'Nama lokasi', 'switch'),
      r('nav', 'Navigasi waypoint', 'switch')] },
    { t: t('ui.sec.minimap', 'Minimap'), rows: [
      r('shape', 'Bentuk minimap', 'seg', { opts: [['square', t('ui.shape.square', 'Kotak')], ['circle', t('ui.shape.circle', 'Lingkaran')]] }),
      r('mapBorder', 'Border minimap', 'switch'),
      r('onlyVeh', 'Hanya tampil di kendaraan', 'switch')] },
    { t: t('ui.sec.sound', 'Suara'), rows: [
      r('beltSound', 'Suara sabuk pengaman', 'switch'),
      r('volume', 'Volume sabuk', 'range'),
      r('cruiseSound', 'Suara cruise control', 'switch')] },
  ];
}

const getVal = (vals, k) => k.startsWith('status.') ? (vals.status || {})[k.slice(7)] : k.startsWith('info.') ? (vals.infoItems || {})[k.slice(5)] : vals[k];

function RangeRow({ value, onCommit }) {
  const [v, setV] = useState(Math.round((value ?? .6) * 100));
  const ref = useRef(null), commit = useRef(onCommit);
  commit.current = onCommit;
  useEffect(() => { setV(Math.round((value ?? .6) * 100)); }, [value]);
  useEffect(() => {
    const el = ref.current;
    const h = () => commit.current(+el.value / 100);
    el.addEventListener('change', h);
    return () => el.removeEventListener('change', h);
  }, []);
  return (
    <div className="st-rng">
      <input ref={ref} type="range" min="0" max="100" step="5" value={v} onChange={e => setV(+e.target.value)} />
      <em>{v}%</em>
    </div>
  );
}

export default function SettingsPanel({ open, values, rev, onSet, onClose, onReset, zoom }) {
  const t = useT();
  const [vals, setVals] = useState({ status: {}, infoItems: {} });
  const [tab, setTab] = useState(0);
  const paneRef = useRef(null);

  useEffect(() => { if (values) setVals({ status: {}, infoItems: {}, ...values }); }, [values, rev]);
  useEffect(() => { if (paneRef.current) paneRef.current.scrollTop = 0; }, [tab, open]);
  useEffect(() => {
    if (!open) return;
    const h = e => { if (e.key === 'Escape') onClose(); };
    addEventListener('keydown', h);
    return () => removeEventListener('keydown', h);
  }, [open, onClose]);

  const secs = buildSections(t);
  const cur = tab >= secs.length ? 0 : tab;

  const setVal = (k, v) => {
    setVals(p => {
      if (k.startsWith('status.')) return { ...p, status: { ...p.status, [k.slice(7)]: v } };
      if (k.startsWith('info.')) return { ...p, infoItems: { ...(p.infoItems || {}), [k.slice(5)]: v } };
      return { ...p, [k]: v };
    });
    onSet(k, v);
  };

  const title = t('ui.settings.title', 'Pengaturan HUD');
  return (
    <div className={cx('st-wrap', open && 'on')} id="stwrap" onMouseDown={e => { if (e.target === e.currentTarget) onClose(); }}>
      <div className="st" id="st" role="dialog" aria-label={title} style={{ zoom }}>
        <div className="st-head"><div><b>{title}</b><small>lngx-hud</small></div></div>
        <div className="st-body" id="stbody">
          <div className="st-nav">
            <img className="st-logo" src="logo-chrome.png" alt="LNGX" draggable={false} />
            {secs.map((sec, i) => <button key={i} className={cx('st-nb', i === cur && 'on')} onClick={() => setTab(i)}>{sec.t}</button>)}
          </div>
          <div className="st-pane" ref={paneRef}>
            {secs.map((sec, i) => (
              <div key={i} className={cx('st-col', i === cur && 'on')}>
                {sec.rows.map(r => {
                  const v = getVal(vals, r.k);
                  return (
                    <div key={r.k} className="st-row">
                      <label>{r.l}</label>
                      {r.type === 'switch' && <button className={cx('st-sw', v && 'on')} onClick={() => setVal(r.k, !v)} />}
                      {r.type === 'seg' && (
                        <div className="st-seg">
                          {r.opts.map(([val, txt]) => <button key={val} className={cx(v === val && 'on')} onClick={() => setVal(r.k, val)}>{txt}</button>)}
                        </div>
                      )}
                      {r.type === 'range' && (
                        <RangeRow value={v}
                          onCommit={x => { setVal(r.k, x); playSound('seatbeltOn', x); }} />
                      )}
                    </div>
                  );
                })}
              </div>
            ))}
          </div>
        </div>
        <div className="st-foot">
          <button className="st-btn" id="strst" onClick={onReset}>{t('ui.reset', 'Reset')}</button>
          <button className="st-btn pri" id="stok" onClick={onClose}>{t('ui.done', 'Selesai')}</button>
        </div>
      </div>
    </div>
  );
}
