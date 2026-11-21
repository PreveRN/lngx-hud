import { useLayoutEffect } from 'react';

export function fitText(el, max, min) {
  if (!el) return;
  let size = max; el.style.fontSize = size + 'px';
  while (el.scrollWidth > el.clientWidth && size > min) { size -= .5; el.style.fontSize = size + 'px'; }
}
export function useFitText(ref, max, min, deps) {
  useLayoutEffect(() => { fitText(ref.current, max, min); }, deps);
}
