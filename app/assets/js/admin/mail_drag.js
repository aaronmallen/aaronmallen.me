import { parse } from "./in_place.js";
import { morphPage, whilePosting } from "./live.js";
import { followPointer } from "./pointer.js";
import { showToast } from "./toast.js";

const BULK = "#mail-bulk";
const DRAGGING = "mail-dragging";
const DROP = "a[data-mail-drop]";
const FAILED = "[data-morph-failed]";
const FIELD = "ids[]";
const FOLDERS = "[data-mail-many]";
const HOLD = 300;
const OVER = "mail-over";
const PICK = "input, label";
const ROW = "[data-mail-drag]";
const SLOP = 6;
const TARGET = "mail-drop";
const TOAST = "[data-toast]";

let bound = false;
let busy = false;

export function setupMailDrag() {
  if (bound) return;

  bound = true;
  document.addEventListener("pointerdown", (event) => {
    const row = event.target.closest(ROW);
    if (row && !busy && !event.target.closest(PICK) && droppable()) wait(row, event);
  });
}

function wait(row, press) {
  const touch = press.pointerType === "touch";
  let latest = press;

  const stop = () => {
    clearTimeout(timer);
    document.removeEventListener("pointermove", moved);
    document.removeEventListener("pointerup", stop);
    document.removeEventListener("pointercancel", stop);
  };

  const start = () => {
    stop();
    drag(row, press, latest);
  };

  const moved = (event) => {
    if (event.pointerId !== press.pointerId) return;

    latest = event;
    if (Math.hypot(event.clientX - press.clientX, event.clientY - press.clientY) <= SLOP) return;
    if (touch) return stop();

    start();
  };

  const timer = touch ? setTimeout(start, HOLD) : null;
  document.addEventListener("pointermove", moved);
  document.addEventListener("pointerup", stop);
  document.addEventListener("pointercancel", stop);
}

function drag(row, press, at) {
  const form = document.querySelector(BULK);
  const ids = dragged(form, row);
  const rows = ids.map((id) => document.getElementById(`thread-${id}`)).filter(Boolean);
  const targets = document.querySelectorAll(DROP);
  let ghost = null;
  let over = null;

  const move = (moved) => {
    ghost.style.translate = `${moved.clientX + 14}px ${moved.clientY + 14}px`;
    over?.classList.remove(OVER);
    over = dropAt(moved);
    over?.classList.add(OVER);
  };

  const end = async (done, cancelled) => {
    document.removeEventListener("touchmove", still);
    document.removeEventListener("contextmenu", menu, true);
    swallowClick();
    ghost.remove();
    for (const target of targets) target.classList.remove(TARGET, OVER);
    for (const each of rows) each.classList.remove(DRAGGING);

    const target = cancelled ? null : dropAt(done);
    if (!target) return;

    busy = true;
    try {
      await whilePosting(send(form, ids, target));
    } finally {
      busy = false;
    }
  };

  if (!followPointer(press, { element: row, dragging: DRAGGING, move, end })) return;

  document.addEventListener("touchmove", still, { passive: false });
  document.addEventListener("contextmenu", menu, true);
  for (const target of targets) target.classList.add(TARGET);
  for (const each of rows) each.classList.add(DRAGGING);
  ghost = floating(ids.length === 1 ? row.dataset.mailDrag : many(ids.length), at);
}

function dragged(form, row) {
  const own = row.querySelector(`input[name="${FIELD}"]`);
  if (form.hasAttribute("data-bulk-off") || !own.checked) return [own.value];

  return [...form.elements].filter((box) => box.name === FIELD && box.checked).map((box) => box.value);
}

function droppable() {
  return [...document.querySelectorAll(DROP)].some((target) => target.checkVisibility());
}

function dropAt(event) {
  return document.elementFromPoint(event.clientX, event.clientY)?.closest(DROP) ?? null;
}

function floating(text, start) {
  const ghost = document.createElement("div");

  ghost.className = "mail-ghost";
  ghost.setAttribute("aria-hidden", "true");
  ghost.textContent = text;
  ghost.style.left = "0";
  ghost.style.top = "0";
  ghost.style.translate = `${start.clientX + 14}px ${start.clientY + 14}px`;
  document.body.append(ghost);
  return ghost;
}

function many(count) {
  return document.querySelector(FOLDERS).dataset.mailMany.replace("%{count}", count);
}

function menu(event) {
  event.preventDefault();
  event.stopPropagation();
}

function still(event) {
  if (event.cancelable) event.preventDefault();
}

function swallowClick() {
  const swallow = (event) => {
    event.preventDefault();
    event.stopPropagation();
  };

  document.addEventListener("click", swallow, true);
  setTimeout(() => document.removeEventListener("click", swallow, true));
}

async function send(form, ids, target) {
  const body = new URLSearchParams(new FormData(form));
  body.delete(FIELD);
  for (const id of ids) body.append(FIELD, id);
  body.set("act", target.dataset.mailDrop);
  if (target.dataset.mailLabel) body.set("label", target.dataset.mailLabel);

  let landed = null;
  try {
    const response = await fetch(form.action, { method: "POST", body });
    if (response.ok) landed = { url: response.url, page: parse(await response.text()) };
  } catch {
    landed = null;
  }

  if (!landed) return showToast(document.querySelector(FAILED)?.dataset.morphFailed ?? "", { failed: true });

  if (landed.url !== window.location.href) history.replaceState(history.state, "", landed.url);
  morphPage(landed.page);

  const toast = landed.page.querySelector(TOAST);
  if (toast) showToast(toast.textContent.trim());
}
