import { useEffect, useRef, useState, useLayoutEffect } from 'react';
import { cx, placeStyle } from '../lib/nui';
import { useT } from '../lib/i18n';

export function MapBorder({ cfg, radar, view, hide }) {
  const b = cfg;
  const on = !!(b && b.enabled && radar);
  const style = { zoom: view.z };
  if (b) {
    style.left = (b.left * view.rx) + 'px';
    style.bottom = b.bottom + 'px';
    style.width = (b.width * view.rx) + 'px';
    style.height = b.height + 'px';
    style.borderRadius = b.radius < 0 ? '50%' : (b.radius || 0) + 'px';
    style['--bt'] = (b.thick || 3) + 'px';
    style['--bc'] = b.color || 'rgba(255,255,255,.55)';
    style['--bg'] = b.glow || 'transparent';
  }
  return <div className={cx('map-border', on && 'on', b && b.shadow === false && 'noshadow', hide && 'hide')} id="mapborder" style={style} />;
}

export function Brand({ cfg, hide }) {
  const on = !!(cfg && cfg.enabled !== false && cfg.name);
  return (
    <div className={cx('brand', on && 'on', hide && 'hide')} id="brand" style={cfg ? placeStyle(cfg) : undefined}>
      <div className="br-txt"><b id="brn">{cfg ? cfg.name || '' : ''}</b><small id="brs">{cfg ? cfg.subtitle || '' : ''}</small></div>
    </div>
  );
}

export function ServerLogo({ cfg, hide }) {
  const on = !!(cfg && cfg.enabled !== false && cfg.file);
  const file = on ? cfg.file : '';
  const [src, setSrc] = useState('');
  const [broken, setBroken] = useState(false);
  const tries = useRef([]);

  useEffect(() => {
    if (!file) return;
    const base = file.replace(/\.[a-z0-9]+$/i, '');
    tries.current = ['png', 'svg', 'webp', 'jpg'].map(e => base + '.' + e).filter(f => f !== file);
    setBroken(false); setSrc(file);
  }, [file]);

  const style = cfg ? { ...placeStyle(cfg), '--sl': (+cfg.size || 96) + 'px' } : undefined;
  return (
    <div className={cx('slogo', cfg && cfg.round && 'round', on && 'on', broken && 'broken', hide && 'hide')} id="slogo" style={style}>
      <img id="slimg" alt="" src={src || undefined}
        onLoad={() => setBroken(false)}
        onError={() => { const n = tries.current.shift(); if (n) setSrc(n); else setBroken(true); }} />
    </div>
  );
}

export function PlayerInfo({ cfg, data, prefs, hide }) {
  const t = useT();
  const c = cfg, i = data;
  const on = !!(c && c.enabled !== false && i && i.show);
  const sh = (c && c.show) || {}, ok = k => sh[k] !== false && prefs.infoItems[k] !== false;
  const money = v => ((c && c.currency) || '$') + Number(v || 0).toLocaleString((c && c.locale) || 'en-US');
  const info = i || {};
  const idOn = ok('id') && info.id != null, jobOn = ok('job') && !!info.job;
  const rows = [
    ['cash', info.cash, 'ui.cash', 'Cash',
      <svg viewBox="0 0 24 24" key="i"><circle cx="12" cy="12" r="9" /><path d="M14.5 9.3c-.4-.8-1.400-1.300-2.500-1.300-1.400 0-2.500.7-2.500 1.800s1 1.500 2.500 1.900 2.500.8 2.500 1.900-1.100 1.800-2.500 1.800c-1.100 0-2.100-.5-2.500-1.300M12 6v2M12 16v2" /></svg>],
    ['bank', info.bank, 'ui.bank', 'Bank',
      <svg viewBox="0 0 24 24" key="i"><rect x="2.500" y="5" width="19" height="14" rx="2.500" /><path d="M2.500 9.500h19M6.500 15h4" /></svg>],
    ['black', info.black, 'ui.black', 'Uang kotor',
      <svg viewBox="0 0 24 24" key="i"><path d="M9 3.500h6l-1.400 3h-3.200z" /><path d="M10.400 6.500C6 9.500 4 12.500 4 16c0 3.200 3 5 8 5s8-1.800 8-5c0-3.500-2-6.500-6.400-9.500" /><path d="M14 13.600c-.4-.6-1.100-.9-2-.9-1.100 0-1.900.5-1.900 1.300s.8 1.200 1.900 1.500 1.900.6 1.900 1.400-.8 1.300-1.900 1.300c-.9 0-1.600-.3-2-.9M12 11.500v1.200M12 17.200v1.300" /></svg>],
  ];
  return (
    <div className={cx('pinfo', on && 'on', hide && 'hide')} id="pinfo" style={c ? placeStyle(c) : undefined}>
      <div className={cx('pi-top', !idOn && !jobOn && 'off')} id="pitop">
        <span className={cx('pi-id', !idOn && 'off')}><small>ID</small><b id="pid">{info.id != null ? info.id : ''}</b></span>
        <div className={cx('pi-job', !jobOn && 'off')}><b id="pjob">{info.job || '-'}</b><small id="pgr">{info.grade || ''}</small></div>
      </div>
      <div className="pi-rows">
        {rows.map(([k, v, tk, def, icon]) => (
          <div key={k} className={cx('pi-row', k, !(ok(k) && v != null) && 'off')} id={'r' + k}>
            {icon}<span>{t(tk, def)}</span><b id={'p' + k}>{ok(k) && v != null ? money(v) : ''}</b>
          </div>
        ))}
      </div>
    </div>
  );
}

const WPN_DEFS = '<defs><linearGradient id="wg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset=".55" stop-color="#e9edf2"/><stop offset="1" stop-color="#9aa3ad"/></linearGradient></defs>';
const WPN_ICONS = {
  pistol: '<path d="M5 5h49a2 2 0 0 1 2 2v5.5H33.5L32 15H23l-5.5 12H9.5l3.3-12H5z"/><path class="d" d="M34 12.5V16h-5M12 8h6M20 8h6M48 5v3"/>',
  smg: '<path d="M2 9l10-1h30l2-2h8v3h8v4H43l-2 1H31l-2.500 11h-7.500L23 16h-5l-2 1H12l-3 3-7-2z"/><path d="M33 16l-2 10h-6" class="d"/><path class="d" d="M20 8v6M26 8v6M50 9v3"/>',
  rifle: '<path d="M1 10l9-2h6l2-3h14l1 3h14v-1h14v3.500H47l-3 1.500H34l-2 .5-3 10.500h-8L23 15h-7l-3 1-3 4-9-3z"/><path class="d" d="M20 8v5M26 8v5M52 8.500v3.500M31 15l-2.500 10"/>',
  mg: '<path d="M1 10l9-2h6l2-3h14l1 3h12v-1.500h14v4H45l-3 1.500H34l-2 .5-.5 2h-9l-3 6.500h-6.500l2.500-8H16l-3 1-3 3-9-2.500z"/><path class="d" d="M22 14h10v8H22zM52 9l-3 11M56 9l3 11"/>',
  shotgun: '<path d="M1 10l12-2h10l2-1.500h37v3H46v2h-1v2.500H28l-4 .5-2 3.500h-6l1.500-3.500L9 16l-3 2-5-1z"/><path class="d" d="M26 9h30M30 13.500h14M34 9v4"/>',
  sniper: '<path d="M1 12l10-1h4v-1h14l1 1h18v-1.500h17v3H48l-3 1.500H30l-3 9h-6.500l2-8H16l-3 1-4 4-8-2z"/><path d="M19 4h23a2 2 0 0 1 2 2v1.500H17V6a2 2 0 0 1 2-2z"/><path class="d" d="M22 8v2M38 8v2M12 12v3M57 11v2"/>',
  heavy: '<path d="M3 9a2 2 0 0 1 2-2h46l2-2h5a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2h-5l-2-2H25l-2 8h-7l2.500-8H5a2 2 0 0 1-2-2z"/><path class="d" d="M34 4h8M56 9v6M14 11h30"/>',
  melee: '<path d="M2 17L33 6l5 2v3l-3 1.500L24 16l-5 2z"/><path d="M38 4a1.500 1.500 0 0 1 3 0v16a1.500 1.500 0 0 1-3 0z"/><path d="M41 8h14a4 4 0 0 1 4 4v1a4 4 0 0 1-4 4H41z"/><path class="d" d="M8 15l24-8M45 12.500h10"/>',
  thrown: '<path d="M30 8c-6.500 0-11 4.500-11 9.500S23.500 27 30 27s11-4.500 11-9.500S36.500 8 30 8z"/><path d="M26 4h8v4h-8zM34 5h10a2 2 0 0 1 2 2v1h-12z"/><path class="d" d="M22 15.500h16M21 20h18M30 8v19"/>',
  tool: '<path d="M8 9a3 3 0 0 1 3-3h28a3 3 0 0 1 3 3v10a3 3 0 0 1-3 3H11a3 3 0 0 1-3-3z"/><path d="M42 11h13a2 2 0 0 1 2 2v1.500a2 2 0 0 1-2 2H42z"/><path class="d" d="M18 6v-2h8v2M14 12h20"/>',
};

export function Weapon({ cfg, data, hide }) {
  const w = data || {};
  const on = !!(cfg && cfg.enabled !== false && data && data.show);
  const key = w.key || '';
  const [png, setPng] = useState(false);
  const [swap, setSwap] = useState(false);

  useLayoutEffect(() => { setPng(false); }, [key]);
  useEffect(() => { if (w.kind) setSwap(true); }, [w.kind]);

  const hasAmmo = w.clip != null;
  return (
    <div className={cx('wpn', on && 'on', png && 'png', swap && 'swap', w.low && 'low', hide && 'hide')} id="wpn" style={cfg ? placeStyle(cfg) : undefined}>
      <div className="wp-txt"><small id="wpname">{w.name || ''}</small>
        <div className={cx('wp-ammo', !hasAmmo && 'off')} id="wpammo"><b id="wpclip">{hasAmmo ? w.clip : ''}</b><em id="wpres">{(hasAmmo && w.reserve != null) ? w.reserve : ''}</em></div>
      </div>
      <div className="wp-ico-wrap">
        <img className="wp-img" id="wpimg" alt="" src={key ? 'weapons/' + key.toLowerCase() + '.png' : undefined}
          onLoad={() => setPng(true)} onError={() => setPng(false)} />
        <svg className="wp-ico" id="wpico" viewBox="0 0 64 28" key={w.kind || 'pistol'}
          dangerouslySetInnerHTML={{ __html: WPN_DEFS + (WPN_ICONS[w.kind] || WPN_ICONS.pistol) }} />
      </div>
    </div>
  );
}
