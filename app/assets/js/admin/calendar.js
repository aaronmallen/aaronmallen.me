import { armGrips, setupCalendarDrag } from "./calendar_drag.js";
import { plain, setupVisit } from "./in_place.js";

const DAY = "a[data-calendar-day]";
const PANEL = "[data-calendar-panel]";

export function setupCalendars() {
  for (const calendar of document.querySelectorAll("[data-calendar]")) {
    setupCalendar(calendar);
  }
}

function pick(calendar, link) {
  for (const day of calendar.querySelectorAll(DAY)) {
    day.parentElement.classList.toggle("cal-picked", day === link);
  }
}

function setupCalendar(calendar) {
  const visit = setupVisit();

  setupCalendarDrag(calendar);

  calendar.addEventListener("click", (event) => {
    const link = event.target.closest(DAY);
    if (!link || event.defaultPrevented || !plain(event)) return;

    event.preventDefault();
    visit(link.href, PANEL, (panel) => {
      calendar.querySelector(PANEL).replaceWith(panel);
      armGrips(panel);
      pick(calendar, link);
      history.replaceState(history.state, "", link.href);
      panel.focus();
    });
  });
}
