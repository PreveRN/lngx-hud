export function startDemo() {
  const send = m => window.postMessage(m, '*');
  const hash = location.hash, timers = [];
  document.body.classList.add('demo');

  send({ action: 'config', border: { enabled: true, thick: 3, color: 'rgba(255,255,255,.55)', glow: 'rgba(47,155,255,.25)', shadow: true, left: 28, bottom: 66, width: 312, height: 198, radius: 6 } });
  send({ action: 'mapborder', show: true });
  send({ action: 'config', lines: { master: true, enabled: true, rounded: false, radius: 5, height: 11, height2: 5, gap: 3, rowGap: 7, left: 27, bottom: 50, width: 314, show: {}, hideEmpty: { stress: true }, hideFull: { stamina: true, oxygen: true }, colors: {}, lowAt: 17 } });
  if (hash === '#settings') send({ action: 'settings', open: true, values: { visible: true, status: { health: true, armor: true, hunger: true, thirst: false, stress: true, stamina: true, oxygen: true, premium: true }, speedo: true, unit: 'kmh', location: true, nav: true, shape: 'square', onlyVeh: false, beltSound: true, volume: .6, cruiseSound: true, style: 'line' } });
  if (hash === '#admin') send({ action: 'admin', open: true, shape: 'circle', loc: { left: 42, bottom: 292, width: 291, style: 'arc', ry: 105, gap: 16, span: 50, overlap: 20 }, border: { left: 42, bottom: 82, width: 291, height: 210, thick: 3, radius: -1 } });
  if (hash === '#round') send({ action: 'prefs', speedoStyle: 'round' });
  if (hash === '#petrol') send({ action: 'prefs', speedoStyle: 'petrol' });
  if (hash === '#vehicle') send({ action: 'vc:open', data: {} });

  const st = { health: 82, armor: 45, hunger: 64, thirst: 38, stress: 30, stamina: 70, oxygen: 55, premium: 240 };
  send({ action: 'update', data: { ...st } });

  let sp = 0, dir = 1, fuel = 100, nt = 0;
  timers.push(setInterval(() => {
    nt = (nt + 1) % 300; fuel = fuel <= 0 ? 100 : fuel - .03; sp += dir * (1 + Math.random() * 3);
    if (sp > 185) dir = -1; if (sp < 5) dir = 1;
    send({ action: 'vehicle', data: { show: true, speed: sp, gear: Math.min(6, 1 + Math.floor(sp / 32)), fuel, engine: 90, seatbelt: sp > 40, cruise: sp > 120, rpm: Math.min(1, .25 + .7 * ((sp % 32) / 32)), navDist: Math.max(0, 1800 - nt * 6), navAng: (nt * 3) % 360, navArrive: 30, destZone: 'Pillbox Hill' } });
    send({ action: 'loc', show: true, zone: 'Davis', street: 'Strawberry Ave / Carson Ave' });
  }, 120));
  timers.push(setInterval(() => {
    st.thirst = Math.max(8, st.thirst - 1); st.stamina = st.stamina <= 10 ? 100 : st.stamina - 3; st.stress = (st.stress + 2) % 100;
    send({ action: 'update', data: { thirst: st.thirst, stamina: st.stamina, stress: st.stress } });
  }, 1200));

  if (hash === '#plane' || hash === '#heli') {
    const heli = hash === '#heli';
    let t = 0;
    timers.push(setInterval(() => {
      t += .05; const th = .6 + .35 * Math.sin(t * .6), s = heli ? 30 + th * 110 + 8 * Math.sin(t * 1.7) : 70 + th * 270 + 15 * Math.sin(t * 1.7), a = Math.max(0, 2800 + 2400 * Math.sin(t * .35)), v = 1900 * Math.cos(t * .35);
      send({ action: 'plane', data: { show: true, speed: s, altitude: a, vspeed: v, heading: (t * 16) % 360, throttle: th, fuel: Math.max(8, 100 - (t * 1.4) % 100),
        pitch: Math.max(-25, Math.min(25, v / 90)), roll: 28 * Math.sin(t * .8), gear: a < 350, flaps: a < 500 ? 2 : (a < 900 ? 1 : 0), stall: !heli && s < 70 && a > 40, heli,
        belt: Math.sin(t * .2) > -.3, cruise: Math.sin(t * .15) > 0, navDist: Math.max(0, 6400 - t * 40), navAng: (t * 20) % 360, navArrive: 150, destZone: 'Mount Chiliad' } });
    }, 50));
  }
  return () => timers.forEach(clearInterval);
}
