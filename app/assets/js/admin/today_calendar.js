const CARD = "[data-today-calendar]";
const HOUR = 60;
const MINUTE = 60000;
const PREP = "[data-prep-title]";
const SOON = 180;
const TICK = 30000;
const TITLE = "#task-create [name='task[title]']";

export function bootTodayCalendar() {
  setInterval(refresh, TICK);
  document.addEventListener("click", prep);
}

function prep(event) {
  const button = event.target.closest(PREP);
  const title = button && document.querySelector(TITLE);

  if (title) title.value = button.dataset.prepTitle;
}

function refresh() {
  const card = document.querySelector(CARD);
  if (!card) return;

  const now = Date.now();
  const rows = [...card.querySelectorAll("[data-today-event][data-starts]")];
  const left = rows.filter((row) => Date.parse(row.dataset.ends) > now);
  const next = left.find((row) => Date.parse(row.dataset.starts) > now);

  for (const row of rows) {
    const starts = Date.parse(row.dataset.starts);
    const state = !left.includes(row) ? "past" : starts <= now ? "now" : row === next ? "next" : "";

    row.dataset.state = state;
    row.querySelector("[data-today-now]").hidden = state !== "now";
    row.querySelector("[data-today-soon]").textContent = row === next ? soon(card, starts - now) : "";
  }

  const tally = card.querySelector("[data-today-calendar-left]");
  if (rows.length) tally.textContent = fill(card.dataset.left, { left: left.length, total: rows.length });
}

function soon(card, wait) {
  const minutes = Math.ceil(wait / MINUTE);
  if (minutes < HOUR) return fill(card.dataset.soonMinutes, { m: minutes });
  if (minutes >= SOON) return "";

  const h = Math.floor(minutes / HOUR);
  const m = minutes % HOUR;
  return m ? fill(card.dataset.soonBoth, { h, m }) : fill(card.dataset.soonHours, { h });
}

function fill(text, values) {
  return text.replace(/\{(\w+)\}/g, (_, key) => values[key]);
}
