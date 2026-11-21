export const isFivem = typeof GetParentResourceName !== 'undefined';

export const post = (name, data) => {
  if (!isFivem) return;
  fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data || {}),
  }).catch(() => {});
};

export const clamp = (v, a, b) => Math.min(b, Math.max(a, v));

export function placeStyle(b) {
  const px = +b.x || 0, py = +b.y || 0, pos = b.position || 'top-right';
  const s = { left: 'auto', right: 'auto', top: 'auto', bottom: 'auto', translate: '' };
  if (pos.indexOf('top') === 0) s.top = py + 'px'; else s.bottom = py + 'px';
  if (/left$/.test(pos)) s.left = px + 'px';
  else if (/right$/.test(pos)) s.right = px + 'px';
  else { s.left = `calc(50% + ${px}px)`; s.translate = '-50% 0'; }
  return s;
}

export const cx = (...a) => a.filter(Boolean).join(' ');
