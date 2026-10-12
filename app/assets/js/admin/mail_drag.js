import { parse } from "./in_place.js";
import { morphPage } from "./live.js";
import { followPointer } from "./pointer.js";
import { showToast } from "./toast.js";

const BULK = "#mail-bulk";
const DRAGGING = "mail-dragging";
const DROP = "a[data-mail-drop]";
const FAILED = "[data-morph-failed]";
const FIELD = "ids[]";
const FOLDERS = "[data-mail-many]";
const GRIP = "[data-mail-grip]";
const OVER = "mail-over";
const ROW = ".mail-row";
const TARGET = "mail-drop";
const TOAST = "[data-toast]";

let bound = false;
let busy = false;

export function setupMailDrag() {
  for (const grip of document.querySelectorAll(GRIP)) grip.hidden = false;
  if (bound) return;

  bound = true;
  document.addEventListener("pointerdown", (event) => {
    const grip = event.target.closest(GRIP);
    if (grip && !busy) drag(grip, event);
  });
}

function drag(grip, press) {
  const form = document.querySelector(BULK);
  const row = grip.closest(ROW);
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
    ghost.remove();
    for (const target of targets) target.classList.remove(TARGET, OVER);
    for (const each of rows) each.classList.remove(DRAGGING);

    const target = cancelled ? null : dropAt(done);
    if (!target) return;

    busy = true;
    try {
      await send(form, ids, target);
    } finally {
      busy = false;
    }
  };

  if (!followPointer(press, { element: row, dragging: DRAGGING, move, end })) return;

  for (const target of targets) target.classList.add(TARGET);
  for (const each of rows) each.classList.add(DRAGGING);
  ghost = floating(ids.length === 1 ? grip.dataset.mailGrip : many(ids.length), press);
}

function dragged(form, row) {
  const own = row.querySelector(`input[name="${FIELD}"]`);
  if (form.hasAttribute("data-bulk-off") || !own.checked) return [own.value];

  return [...form.elements].filter((box) => box.name === FIELD && box.checked).map((box) => box.value);
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
