const MINUTE = 60_000;

export function setupClock() {
  for (const slot of document.querySelectorAll("[data-clock]")) {
    const { clock: timeZone, clockLabel: label } = slot.dataset;
    const format = new Intl.DateTimeFormat("en-US", { timeZone, hour: "numeric", minute: "2-digit" });

    const tick = () => {
      const time = format.format(Date.now()).replace(/\s+/u, " ").toLowerCase();
      slot.textContent = label.replace("%{time}", time);
      setTimeout(tick, MINUTE - (Date.now() % MINUTE));
    };

    tick();
  }
}
