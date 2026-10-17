import { whilePosting } from "./live.js";
import { postAndMorph } from "./morph_form.js";
import { dragOnto, waitForDrag } from "./pointer.js";

const BULK = "#mail-bulk";
const DRAGGING = "mail-dragging";
const DROP = "a[data-mail-drop]";
const FIELD = "ids[]";
const FOLDERS = "[data-mail-many]";
const OVER = "mail-over";
const PICK = "input, label";
const ROW = "[data-mail-drag]";
const TARGET = "mail-drop";

let busy = false;

export function bootMailDrag() {
  document.addEventListener("pointerdown", (event) => {
    const row = event.target.closest(ROW);
    if (row && !busy && !event.target.closest(PICK) && droppable()) waitForDrag(event, (at) => drag(row, event, at));
  });
}

function drag(row, press, at) {
  const form = document.querySelector(BULK);
  const ids = dragged(form, row);
  const rows = ids.map((id) => document.getElementById(`thread-${id}`)).filter(Boolean);
  const targets = document.querySelectorAll(DROP);

  dragOnto(press, {
    element: row,
    dragging: DRAGGING,
    ghost: "mail-ghost",
    label: ids.length === 1 ? row.dataset.mailDrag : many(ids.length),
    at,
    target: DROP,
    over: OVER,
    start: () => {
      for (const target of targets) target.classList.add(TARGET);
      for (const each of rows) each.classList.add(DRAGGING);

      return () => {
        for (const target of targets) target.classList.remove(TARGET);
        for (const each of rows) each.classList.remove(DRAGGING);
      };
    },
    drop: async (target) => {
      busy = true;
      try {
        await whilePosting(send(form, ids, target));
      } finally {
        busy = false;
      }
    },
  });
}

function dragged(form, row) {
  const own = row.querySelector(`input[name="${FIELD}"]`);
  if (form.hasAttribute("data-bulk-off") || !own.checked) return [own.value];

  return [...form.elements].filter((box) => box.name === FIELD && box.checked).map((box) => box.value);
}

function droppable() {
  return [...document.querySelectorAll(DROP)].some((target) => target.checkVisibility());
}

function many(count) {
  return document.querySelector(FOLDERS).dataset.mailMany.replace("%{count}", count);
}

function send(form, ids, target) {
  const body = new URLSearchParams(new FormData(form));
  body.delete(FIELD);
  for (const id of ids) body.append(FIELD, id);
  body.set("act", target.dataset.mailDrop);
  if (target.dataset.mailLabel) body.set("label", target.dataset.mailLabel);

  return postAndMorph(form.action, body);
}
