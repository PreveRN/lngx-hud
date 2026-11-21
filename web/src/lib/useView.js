import { useEffect, useState } from 'react';

function calc() {
  const ky = Math.max(.5, Math.min(3, innerHeight / 1080));
  const kx = Math.max(.5, Math.min(3, Math.min(innerWidth, innerHeight * 16 / 9) / 1920));
  return { z: ky.toFixed(3), rx: kx / ky };
}

export function useView() {
  const [v, setV] = useState(calc);
  useEffect(() => {
    let raf = 0;
    const on = () => {
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => setV(p => { const n = calc(); return p.z === n.z && p.rx === n.rx ? p : n; }));
    };
    addEventListener('resize', on);
    return () => { removeEventListener('resize', on); cancelAnimationFrame(raf); };
  }, []);
  return v;
}
