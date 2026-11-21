import { useEffect, useRef, useState } from 'react';
import { cx, post } from '../lib/nui';
import { useT } from '../lib/i18n';

const adRows = t => ({
  loc: [['left', t('ui.ad.left', 'Kiri'), 0, 700], ['bottom', t('ui.ad.bottom_street', 'Bawah (tepi atas peta)'), 0, 800], ['width', t('ui.ad.width', 'Lebar'), 100, 600]],
  locCircle: [['ry', t('ui.ad.ry', 'Tinggi lengkung (ry)'), 40, 200], ['gap', t('ui.ad.gap', 'Jarak dari peta'), 0, 60], ['span', t('ui.ad.span', 'Lebar lengkung (°)'), 15, 90]],
  border: [['left', t('ui.ad.left', 'Kiri'), 0, 700], ['bottom', t('ui.ad.bottom', 'Bawah'), 0, 800], ['width', t('ui.ad.width', 'Lebar'), 100, 600], ['height', t('ui.ad.height', 'Tinggi'), 80, 500], ['thick', t('ui.ad.thick', 'Tebal'), 0, 12]],
});

const adSend = {};
function adPost(group, key, value) {
  const id = group + '.' + key; const had = id in adSend; adSend[id] = [group, key, value];
  if (had) return;
  requestAnimationFrame(() => { const v = adSend[id]; delete adSend[id]; post('adminSet', { group: v[0], key: v[1], value: v[2] }); });
}

function AdRow({ group, k, label, min, max, cur }) {
  const [val, setVal] = useState(cur == null ? 0 : cur);
  return (
    <div className="st-row">
      <label>{label}</label>
      <div className="ad-r">
        <input type="range" min={min} max={max} step="1" value={val} onChange={e => { setVal(+e.target.value); adPost(group, k, +e.target.value); }} />
        <input type="number" step="1" value={val} onChange={e => { const x = e.target.value; setVal(x); if (x === '' || isNaN(+x)) return; adPost(group, k, +x); }} />
      </div>
    </div>
  );
}

function AdSeg({ label, opts, cur, onPick }) {
  return (
    <div className="st-row">
      <label>{label}</label>
      <div className="st-seg">{opts.map(([val, txt]) => <button key={val} className={cx(cur === val && 'on')} onClick={() => onPick(val)}>{txt}</button>)}</div>
    </div>
  );
}

export default function AdminPanel({ admin, exportData, onClose, onSave, zoom }) {
  const t = useT();
  const { open, shape } = admin;
  const [loc, setLoc] = useState(admin.loc || {});
  const [outOn, setOutOn] = useState(false);
  const [note, setNote] = useState('');
  const txtRef = useRef(null);

  useEffect(() => { setLoc(admin.loc || {}); setOutOn(false); }, [admin.rev]);

  const [tick, setTick] = useState(0);
  useEffect(() => {
    if (!exportData || !exportData.rev) return;
    setOutOn(true); setTick(exportData.rev);
  }, [exportData]);
  useEffect(() => {
    if (!tick || !exportData) return;
    const el = txtRef.current; if (!el) return;
    el.value = exportData.text; el.focus(); el.select();
    let ok = false; try { ok = document.execCommand('copy'); } catch (_) {  }
    setNote(ok ? t('ui.ad.copied', 'Tersalin ke clipboard. Tempel ke config.lua (juga tercetak di konsol F8).') : t('ui.ad.copy_manual', 'Blok teks di atas lalu Ctrl+C (juga tercetak di konsol F8).'));
  }, [tick]);

  useEffect(() => {
    if (!open) return;
    const h = e => { if (e.key === 'Escape') onClose(); };
    addEventListener('keydown', h);
    return () => removeEventListener('keydown', h);
  }, [open, onClose]);

  const round = shape === 'circle';
  const rows = adRows(t);
  const style = loc.style || 'pill';
  const rk = admin.rev + ':' + shape;
  const border = admin.border || {};

  return (
    <div className={cx('ad-wrap', open && 'on')} id="adwrap">
      <div className="ad" id="ad" role="dialog" aria-label={t('ui.ad.title', 'Admin HUD')} style={{ zoom }}>
        <div className="st-head">
          <div><b>{t('ui.ad.title', 'Admin HUD')}</b><small>{t('ui.ad.subtitle', 'Tuner minimap')}</small></div>
          <button className="st-x" id="adx" title={t('ui.close', 'Tutup (Esc)')} onClick={onClose}><svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18" /></svg></button>
        </div>
        <div className="st-body" id="adbody">
          <div className="st-sec">{t('ui.ad.sec_shape', 'Bentuk minimap')}</div>
          <AdSeg label={t('ui.ad.shape', 'Bentuk')} cur={shape}
            opts={[['square', t('ui.shape.square', 'Kotak')], ['circle', t('ui.shape.circle', 'Lingkaran')]]}
            onPick={v => { if (v !== shape) post('setSetting', { key: 'shape', value: v }); }} />

          <div className="st-sec">{t('ui.ad.sec_street', 'Nama jalan')}</div>
          {round && <AdSeg label={t('ui.ad.style', 'Gaya')} cur={style}
            opts={[['arc', t('ui.ad.arc', 'Melengkung')], ['pill', t('ui.ad.pill', 'Pil')]]}
            onPick={v => { setLoc(p => ({ ...p, style: v })); post('adminSet', { group: 'loc', key: 'style', value: v }); }} />}
          {rows.loc.map(([k, l, mn, mx]) => <AdRow key={rk + 'loc' + k} group="loc" k={k} label={l} min={mn} max={mx} cur={(admin.loc || {})[k]} />)}
          {round && style === 'arc' && rows.locCircle.map(([k, l, mn, mx]) => <AdRow key={rk + 'loc' + k} group="loc" k={k} label={l} min={mn} max={mx} cur={(admin.loc || {})[k]} />)}
          {round && style !== 'arc' && <AdRow key={rk + 'overlap'} group="loc" k="overlap" label={t('ui.ad.overlap', 'Menimpa peta (px)')} min={0} max={60} cur={(admin.loc || {}).overlap} />}

          <div className="st-sec">{t('ui.ad.sec_border', 'Border minimap')}</div>
          {rows.border.map(([k, l, mn, mx]) => <AdRow key={rk + 'b' + k} group="border" k={k} label={l} min={mn} max={mx} cur={border[k]} />)}
          {!round && <AdRow key={rk + 'radius'} group="border" k="radius" label={t('ui.ad.radius', 'Sudut membulat')} min={0} max={40} cur={border.radius} />}
        </div>
        <div className={cx('ad-out', outOn && 'on')} id="adout">
          <textarea id="adtxt" ref={txtRef} readOnly rows="9" spellCheck="false" />
          <small id="adnote">{note}</small>
        </div>
        <div className="st-foot">
          <button className="st-btn" id="adrst" onClick={() => { setOutOn(false); post('adminReset'); }}>{t('ui.reset', 'Reset')}</button>
          <button className="st-btn" id="adcp" onClick={() => post('adminExport')}>{t('ui.ad.copy', 'Salin config')}</button>
          <button className="st-btn pri" id="adok" onClick={onSave}>{t('ui.done', 'Selesai')}</button>
        </div>
      </div>
    </div>
  );
}
