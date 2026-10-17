import { parse } from "./in_place.js";
import { whilePosting } from "./live.js";
import { dragOnto } from "./pointer.js";
import { showPageToast, showToast } from "./toast.js";

const DAY = "a[data-calendar-day]";
const DRAGGING = "cal-dragging";
const GRIP = "[data-calendar-grip]";
const ITEM = "[data-calendar-item]";
const MONTH = ".cal-month";
const MORPHED = "admin:morphed";
const PANEL = "[data-calendar-panel]";
const REFUSED = "cal-refused";
const TARGET = "cal-target";
const TITLE = ".li-title, .cal-event-name";

export function armGrips(root) {
  for (const grip of root.querySelectorAll(GRIP)) grip.hidden = false;
}

export function setupCalendarDrag(calendar) {
  let busy = false;

  calendar.addEventListener("pointerdown", (event) => {
    const grip = event.target.closest(GRIP);
    if (!grip || busy) return;

    drag(calendar, grip, event, async (day) => {
      busy = true;
      try {
        await whilePosting(move(calendar, grip, day));
      } finally {
        busy = false;
      }
    });
  });
}

function drag(calendar, grip, press, drop) {
  const row = grip.closest(ITEM);
  const from = grip.closest(PANEL).dataset.calendarPanel;

  dragOnto(press, {
    element: row,
    dragging: DRAGGING,
    ghost: "cal-ghost",
    label: row.querySelector(TITLE)?.textContent ?? "",
    target: DAY,
    accepts: (day) => calendar.contains(day) && day.dataset.calendarDay !== from,
    over: (day) => (refused(day) ? REFUSED : TARGET),
    drop: (day) => {
      if (refused(day)) return showToast(grip.dataset.calendarPast, { failed: true });

      drop(day.dataset.calendarDay);
    },
  });
}

async function move(calendar, grip, day) {
  const form = grip.closest("form");
  const item = grip.closest(ITEM).dataset.calendarItem;
  const body = new URLSearchParams(new FormData(form));
  body.set("to", day);

  let page = null;
  try {
    const response = await fetch(form.action, { method: "POST", body });
    if (response.ok) page = parse(await response.text());
  } catch {
    page = null;
  }

  const month = page?.querySelector(MONTH);
  const panel = page?.querySelector(PANEL);
  if (!month || !panel) return showToast(grip.dataset.calendarFailed, { failed: true });

  calendar.querySelector(MONTH).replaceWith(month);
  calendar.querySelector(PANEL).replaceWith(panel);
  document.dispatchEvent(new Event(MORPHED));

  const stayed = panel.querySelector(`[data-calendar-item="${item}"]`) !== null;
  showPageToast(page, { failed: stayed });
}

function refused(day) {
  return "calendarPast" in day.dataset;
}
