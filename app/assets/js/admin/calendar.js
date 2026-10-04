import { armGrips, setupCalendarDrag } from "./calendar_drag.js";

const DAY = "a[data-calendar-day]";
const PANEL = "[data-calendar-panel]";

export function setupCalendars() {
  for (const calendar of document.querySelectorAll("[data-calendar]")) {
    setupCalendar(calendar);
  }
}

async function load(url) {
  const response = await fetch(url);
  if (!response.ok) return null;

  return new DOMParser().parseFromString(await response.text(), "text/html").querySelector(PANEL);
}

function plain(event) {
  return event.button === 0 && !event.metaKey && !event.ctrlKey && !event.shiftKey && !event.altKey;
}

function pick(calendar, link) {
  for (const day of calendar.querySelectorAll(DAY)) {
    day.parentElement.classList.toggle("cal-picked", day === link);
  }
}

function setupCalendar(calendar) {
  let latest = 0;

  setupCalendarDrag(calendar);

  const open = async (link) => {
    const ticket = ++latest;
    const panel = await load(link.href);
    if (ticket !== latest) return true;
    if (!panel) return false;

    calendar.querySelector(PANEL).replaceWith(panel);
    armGrips(panel);
    pick(calendar, link);
    history.replaceState(history.state, "", link.href);
    panel.focus();
    return true;
  };

  calendar.addEventListener("click", (event) => {
    const link = event.target.closest(DAY);
    if (!link || event.defaultPrevented || !plain(event)) return;

    event.preventDefault();
    open(link)
      .catch(() => false)
      .then((done) => {
        if (!done) window.location.assign(link.href);
      });
  });
}
