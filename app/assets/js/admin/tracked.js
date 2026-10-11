const HOUR = 3600;
const MINUTE = 60;
const SECOND = 1000;

let started = false;

export function setupTracked() {
  if (started) return;

  started = true;
  setInterval(tick, SECOND);
}

function hours(seconds) {
  const whole = Math.floor(seconds / HOUR);
  const minutes = Math.floor((seconds % HOUR) / MINUTE);

  return whole ? `${whole}h ${String(minutes).padStart(2, "0")}m` : `${minutes}m`;
}

function tick() {
  for (const figure of document.querySelectorAll("[data-tracked-since]")) {
    const text = hours(Math.floor((Date.now() - Number(figure.dataset.trackedSince)) / SECOND));
    if (figure.textContent !== text) figure.textContent = text;
  }
}
