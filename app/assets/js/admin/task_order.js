import { bind } from "./keys.js";
import { followPointer } from "./pointer.js";
import { showToast } from "./toast.js";

const DRAGGING = "task-dragging";
const GRIP = "[data-task-grip]";
const KEYS = { ArrowDown: 1, ArrowUp: -1 };
const ROW = "[data-task-order]";

const ready = new WeakSet();
const saves = [];
let saving = false;

export function setupTaskOrder(root = document) {
  for (const grip of root.querySelectorAll(GRIP)) {
    if (ready.has(grip)) continue;

    ready.add(grip);
    grip.hidden = false;
    grip.addEventListener("pointerdown", (event) => drag(event, grip));
  }

  if (root === document) bind(nudges, nudge);
}

function after(row) {
  const rows = peers(row);
  const at = rows.indexOf(row);

  return at > 0 ? rows[at - 1].dataset.taskId : (row.querySelector(GRIP).dataset.taskLead ?? "");
}

function drag(event, grip) {
  const row = grip.closest(ROW);
  const before = peers(row);

  followPointer(event, {
    element: row,
    dragging: DRAGGING,
    move: (moved) => slot(row, moved.clientY),
    end: (_done, cancelled) => {
      if (cancelled) return restore(row, before);
      if (peers(row).indexOf(row) !== before.indexOf(row)) save(row, before);
    },
  });
}

function nudge(event) {
  const step = KEYS[event.key];
  const row = event.target.closest?.(ROW);
  if (!row?.querySelector(`${GRIP}:not([hidden])`)) return;

  event.preventDefault();

  const before = peers(row);
  const other = before[before.indexOf(row) + step];
  if (!other) return;

  keepFocus(() => place(row, step > 0 ? other.nextSibling : other));
  save(row, before);
}

function keepFocus(work) {
  const focused = document.activeElement;
  work();
  focused?.focus({ preventScroll: true });
  focused?.scrollIntoView({ block: "nearest" });
}

function nudges(event) {
  return event.key in KEYS && event.altKey && !event.ctrlKey && !event.metaKey && !event.shiftKey;
}

function peers(row) {
  return [...row.parentElement.children].filter((sibling) => sibling.dataset.taskOrder === row.dataset.taskOrder);
}

function place(row, next) {
  row.parentElement.insertBefore(row, next);
}

function restore(row, order) {
  const marks = peers(row).map((peer) => peer.parentElement.insertBefore(document.createComment(""), peer));

  for (const [index, mark] of marks.entries()) mark.replaceWith(order[index]);
}

function save(row, before) {
  const grip = row.querySelector(GRIP);
  const body = new URLSearchParams({ _csrf_token: grip.dataset.taskToken, after: after(row) });

  saves.push({ body, before, grip, row });
  if (!saving) send();
}

async function send() {
  const next = saves.shift();
  if (!next) {
    saving = false;
    return;
  }

  saving = true;

  let ok = false;
  try {
    const response = await fetch(next.grip.dataset.taskGrip, { method: "POST", body: next.body, redirect: "manual" });
    ok = response.ok;
  } catch {
    ok = false;
  }

  if (!ok) fail(next);
  send();
}

function fail({ before, grip, row }) {
  const lost = saves.filter((pending) => pending.row.dataset.taskOrder === row.dataset.taskOrder);

  saves.splice(0, saves.length, ...saves.filter((pending) => !lost.includes(pending)));
  restore(row, before);
  showToast(grip.dataset.taskFailed, { failed: true });
}

function slot(row, y) {
  const rows = peers(row).filter((peer) => peer !== row);
  const below = rows.find((peer) => {
    const box = peer.getBoundingClientRect();
    return y < box.top + box.height / 2;
  });

  if (below) {
    if (row.nextElementSibling !== below) place(row, below);
  } else if (rows.length > 0) {
    const last = rows[rows.length - 1];
    if (last.nextElementSibling !== row) place(row, last.nextSibling);
  }
}
