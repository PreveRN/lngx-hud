const SOUNDS = {
  seatbeltOn: new Audio('sounds/SeatbeltOnSound.mp3'),
  seatbeltOff: new Audio('sounds/SeatbeltOffSound.mp3'),
};
for (const k in SOUNDS) SOUNDS[k].preload = 'auto';

export function playSound(name, volume) {
  const a = SOUNDS[name]; if (!a) return;
  a.pause(); a.currentTime = 0;
  const n = Number(volume);
  const vol = (volume === undefined || volume === null || Number.isNaN(n)) ? 0.6 : Math.max(0, Math.min(1, n));
  if (vol <= 0) return;
  a.volume = vol;
  a.play().catch(() => {});
}
