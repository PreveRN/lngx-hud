import { useCallback, useEffect, useMemo, useState } from 'react';
import { LocaleCtx } from './lib/i18n';
import { isFivem, post } from './lib/nui';
import { playSound } from './lib/sound';
import { useView } from './lib/useView';
import StatusDock from './components/StatusDock';
import LineHud from './components/LineHud';
import Location from './components/Location';
import { MapBorder, Brand, ServerLogo, PlayerInfo, Weapon } from './components/Overlays';
import { SpeedoRound, SpeedoPetrol } from './components/Speedometers';
import Plane from './components/Plane';
import VehicleMenu from './components/VehicleMenu';
import SettingsPanel from './components/SettingsPanel';
import AdminPanel from './components/AdminPanel';
import { startDemo } from './demo';

const INIT_STATE = { health: 100, armor: 0, hunger: 100, thirst: 100, stress: 0, stamina: 100, oxygen: 100, premium: null };
const merge = (a, b) => ({ ...a, ...b });

export default function App() {
  const view = useView();

  const [state, setState] = useState(INIT_STATE);
  const [prefs, setPrefs] = useState({ status: {}, infoItems: {} });
  const [ready, setReady] = useState(false);
  const [linesReady, setLinesReady] = useState(false);
  const [lines, setLines] = useState({ enabled: false });
  const [vehicle, setVehicle] = useState(null);
  const [spStyle, setSpStyle] = useState('round');
  const [loc, setLoc] = useState({});
  const [locText, setLocText] = useState({ z: '', st: '' });
  const [posLoc, setPosLoc] = useState(null);
  const [posHud, setPosHud] = useState(null);
  const [mapBorder, setMapBorder] = useState(null);
  const [radar, setRadar] = useState(false);
  const [isRound, setIsRound] = useState(false);
  const [brandCfg, setBrandCfg] = useState(null);
  const [logoCfg, setLogoCfg] = useState(null);
  const [infoCfg, setInfoCfg] = useState(null);
  const [infoData, setInfoData] = useState(null);
  const [wpnCfg, setWpnCfg] = useState(null);
  const [wpnData, setWpnData] = useState(null);
  const [visible, setVisible] = useState(true);
  const [brandVisible, setBrandVisible] = useState(true);
  const [lang, setLang] = useState({ lang: 'id', t: {} });
  const [settings, setSettings] = useState({ open: false, values: null, rev: 0 });
  const [admin, setAdmin] = useState({ open: false, shape: 'square', loc: {}, border: {}, rev: 0 });
  const [adExport, setAdExport] = useState(null);

  const setSpeedoStyle = v => setSpStyle(v === 'petrol' ? v : 'round');

  useEffect(() => {
    const onMsg = e => {
      const m = e.data; if (!m) return;
      switch (m.action) {
        case 'update':
          if (m.data) { setState(s => merge(s, m.data)); setReady(true); setLinesReady(true); }
          break;
        case 'vehicle': setVehicle(m.data || null); break;
        case 'loc': {
          const d = m.show ? m : {};
          setLoc(d);
          if (d.zone || d.street) setLocText({ z: d.zone || d.street, st: d.zone ? (d.street || '') : '' });
          break;
        }
        case 'visible':
          setVisible(!!m.state);
          setBrandVisible(m.brand !== undefined ? !!m.brand : !!m.state);
          break;
        case 'admin':
          if (m.open) setAdmin(a => ({ open: true, shape: m.shape || 'square', loc: m.loc || {}, border: m.border || {}, rev: a.rev + 1 }));
          else setAdmin(a => ({ ...a, open: false }));
          break;
        case 'adminExport': setAdExport(x => ({ text: m.text || '', rev: (x ? x.rev : 0) + 1 })); break;
        case 'mapborder': setRadar(!!m.show); break;
        case 'info': if (m.data) setInfoData(m.data); break;
        case 'weapon': if (m.data) setWpnData(m.data); break;
        case 'config':
          if (m.brand) setBrandCfg(m.brand);
          if (m.lines) { setLines(m.lines); setLinesReady(true); }
          if (m.logo) setLogoCfg(m.logo);
          if (m.info) setInfoCfg(m.info);
          if (m.weapon) setWpnCfg(m.weapon);
          if (m.loc) setPosLoc(m.loc);
          if (m.hud) setPosHud(m.hud);
          if (m.border) setMapBorder(m.border);
          if (m.shape) {
            setIsRound(m.shape === 'circle');
            setAdmin(a => (a.open && m.shape !== a.shape ? { open: true, shape: m.shape, loc: m.loc || {}, border: m.border || {}, rev: a.rev + 1 } : a));
          }
          break;
        case 'locale':
          document.documentElement.lang = m.lang || 'id';
          setLang({ lang: m.lang || 'id', t: m.t || {} });
          break;
        case 'sound': playSound(m.name, m.volume); break;
        case 'prefs':
          if (m.speedoStyle) setSpeedoStyle(m.speedoStyle);
          if (m.status) { setPrefs(p => ({ ...p, status: merge(p.status, m.status) })); setReady(true); setLinesReady(true); }
          if (m.infoItems) setPrefs(p => ({ ...p, infoItems: merge(p.infoItems, m.infoItems) }));
          break;
        case 'settings':
          if (m.open) {
            const v = m.values;
            if (v) {
              setPrefs(p => ({ status: merge(p.status, v.status), infoItems: merge(p.infoItems, v.infoItems) }));
              setReady(true); setLinesReady(true);
            }
            setSettings(s => ({ open: true, values: v || s.values, rev: s.rev + 1 }));
          } else setSettings(s => ({ ...s, open: false }));
          break;
      }
    };
    addEventListener('message', onMsg);
    let stopDemo = null;
    if (isFivem) post('ready');
    else stopDemo = startDemo();
    return () => { removeEventListener('message', onMsg); if (stopDemo) stopDemo(); };
  }, []);

  const onSet = useCallback((k, v) => {
    if (k.startsWith('status.')) setPrefs(p => ({ ...p, status: { ...p.status, [k.slice(7)]: v } }));
    else if (k.startsWith('info.')) setPrefs(p => ({ ...p, infoItems: { ...p.infoItems, [k.slice(5)]: v } }));
    if (k === 'speedoStyle') setSpStyle(v === 'petrol' ? v : 'round');
    if (k === 'style') setLines(l => ({ ...l, enabled: v === 'line' && l.master !== false }));
    if (k === 'visible') setVisible(!!v);
    post('setSetting', { key: k, value: v });
  }, []);
  const closeSettings = useCallback(() => { setSettings(s => ({ ...s, open: false })); post('closeSettings'); }, []);
  const resetSettings = useCallback(() => post('resetSettings'), []);
  const closeAdmin = useCallback(() => { setAdmin(a => ({ ...a, open: false })); post('adminClose'); }, []);
  const saveAdmin = useCallback(() => { setAdmin(a => ({ ...a, open: false })); post('adminSave'); }, []);

  const locale = useMemo(() => ({ lang: lang.lang, t: (k, d) => (lang.t[k] !== undefined ? lang.t[k] : d) }), [lang]);
  const hide = !visible, curStyle = (posLoc && posLoc.style) || 'pill';
  const vShow = !!(vehicle && vehicle.show);

  return (
    <LocaleCtx.Provider value={locale}>
      <StatusDock state={state} prefs={prefs} ready={ready} hidden={hide} linesOn={!!lines.enabled} view={view} pos={posHud} />
      <LineHud cfg={lines} state={state} prefs={prefs} ready={linesReady} hide={hide} view={view} />
      <PlayerInfo cfg={infoCfg} data={infoData} prefs={prefs} hide={hide} />
      <Weapon cfg={wpnCfg} data={wpnData} hide={hide} />
      <Brand cfg={brandCfg} hide={!brandVisible} />
      <ServerLogo cfg={logoCfg} hide={!brandVisible} />
      <MapBorder cfg={mapBorder} radar={radar} view={view} hide={hide} />
      <Location loc={loc} text={locText} pos={posLoc} isRound={isRound} curStyle={curStyle} view={view} hide={hide} />
      <SpeedoRound d={vShow && spStyle === 'round' ? vehicle : null} hide={hide} zoom={view.z} />
      <SpeedoPetrol d={vShow && spStyle === 'petrol' ? vehicle : null} hide={hide} />
      <Plane gone={hide} />
      <SettingsPanel open={settings.open} values={settings.values} rev={settings.rev} onSet={onSet} onClose={closeSettings} onReset={resetSettings} zoom={view.z} />
      <AdminPanel admin={admin} exportData={adExport} onClose={closeAdmin} onSave={saveAdmin} zoom={view.z} />
      <VehicleMenu />
    </LocaleCtx.Provider>
  );
}
