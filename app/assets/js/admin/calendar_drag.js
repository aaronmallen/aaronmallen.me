import { parse } from "./in_place.js";
import { followPointer } from "./pointer.js";
import { showToast } from "./toast.js";

const DAY = "a[data-calendar-day]";
const DRAGGING = "cal-dragging";
const GRIP = "[data-calendar-grip]";
const ITEM = "[data-calendar-item]";
const MONTH = ".cal-month";
const PANEL = "[data-calendar-panel]";
const REFUSED = "cal-refused";
const TARGET = "cal-target";

export function armGrips(root) {
  for (const grip of root.querySelectorAll(GRIP)) grip.hidden = false;
}

export function setupCalendarDrag(calendar) {
  let busy = false;

  armGrips(calendar);

  calendar.addEventListener("pointerdown", (event) => {
    const grip = event.target.closest(GRIP);
    if (!grip || busy) return;

    drag(calendar, grip, event, async (day) => {
      busy = true;
      try {
        await move(calendar, grip, day);
      } finally {
        busy = false;
      }
    });
  });
}

function drag(calendar, grip, press, drop) {
  const row = grip.closest(ITEM);
  const from = grip.closest(PANEL).dataset.calendarPanel;
  let ghost = null;
  let over = null;

  const move = (moved) => {
    ghost.style.translate = `${moved.clientX + 12}px ${moved.clientY + 12}px`;
    over?.classList.remove(TARGET, REFUSED);
    over = dayAt(calendar, moved, from);
    over?.classList.add(refused(over) ? REFUSED : TARGET);
  };

  const end = (done, cancelled) => {
    ghost.remove();
    over?.classList.remove(TARGET, REFUSED);

    const day = cancelled ? null : dayAt(calendar, done, from);
    if (!day) return;
    if (refused(day)) return showToast(grip.dataset.calendarPast, { failed: true });

    drop(day.dataset.calendarDay);
  };

  if (followPointer(press, { element: row, dragging: DRAGGING, move, end })) ghost = floating(row, press);
}

function dayAt(calendar, event, from) {
  const day = document.elementFromPoint(event.clientX, event.clientY)?.closest(DAY);

  return day && calendar.contains(day) && day.dataset.calendarDay !== from ? day : null;
}

function floating(row, start) {
  const ghost = document.createElement("div");

  ghost.className = "cal-ghost";
  ghost.setAttribute("aria-hidden", "true");
  ghost.textContent = row.querySelector(".li-title")?.textContent ?? "";
  ghost.style.left = "0";
  ghost.style.top = "0";
  ghost.style.translate = `${start.clientX + 12}px ${start.clientY + 12}px`;
  document.body.append(ghost);
  return ghost;
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
  armGrips(panel);

  const stayed = panel.querySelector(`[data-calendar-item="${item}"]`) !== null;
  const message = page.querySelector("[data-toast]")?.textContent.trim();
  if (message) showToast(message, { failed: stayed });
}

function refused(day) {
  return "calendarPast" in day.dataset;
}
