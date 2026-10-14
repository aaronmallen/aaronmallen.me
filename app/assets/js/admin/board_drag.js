import { followPointer } from "./pointer.js";

const CARD = "[data-board-card]";
const COLUMN = "[data-board-column]";
const DRAGGING = "kc-dragging";
const HOLD = 300;
const MOVE = "form[data-morph]";
const OVER = "kcol-over";
const PRESS = "button, form, input, label";
const SLOP = 6;
const TITLE = ".kc-title";

let bound = false;

export function setupBoardDrag() {
  if (bound) return;

  bound = true;
  document.addEventListener("pointerdown", (event) => {
    const card = event.target.closest(CARD);
    if (card && !event.target.closest(PRESS)) wait(card, event);
  });
}

function wait(card, press) {
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
    drag(card, press, latest);
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

function drag(card, press, at) {
  const from = card.closest(COLUMN);
  let ghost = null;
  let over = null;

  const move = (moved) => {
    ghost.style.translate = `${moved.clientX + 14}px ${moved.clientY + 14}px`;
    over?.classList.remove(OVER);
    over = columnAt(moved, from);
    over?.classList.add(OVER);
  };

  const end = (done, cancelled) => {
    document.removeEventListener("touchmove", still);
    document.removeEventListener("contextmenu", menu, true);
    swallowClick();
    ghost.remove();
    over?.classList.remove(OVER);

    const column = cancelled ? null : columnAt(done, from);
    if (column) submitTo(card, column.dataset.boardColumn);
  };

  if (!followPointer(press, { element: card, dragging: DRAGGING, move, end })) return;

  document.addEventListener("touchmove", still, { passive: false });
  document.addEventListener("contextmenu", menu, true);
  ghost = floating(card, at);
}

function columnAt(event, from) {
  const column = document.elementFromPoint(event.clientX, event.clientY)?.closest(COLUMN);

  return column && column !== from ? column : null;
}

function floating(card, start) {
  const ghost = document.createElement("div");

  ghost.className = "kc-ghost";
  ghost.setAttribute("aria-hidden", "true");
  ghost.textContent = card.querySelector(TITLE)?.textContent ?? "";
  ghost.style.left = "0";
  ghost.style.top = "0";
  ghost.style.translate = `${start.clientX + 14}px ${start.clientY + 14}px`;
  document.body.append(ghost);
  return ghost;
}

function menu(event) {
  event.preventDefault();
  event.stopPropagation();
}

function still(event) {
  if (event.cancelable) event.preventDefault();
}

function submitTo(card, column) {
  const form = card.querySelector(MOVE);
  const to = form.elements.to;
  const was = to.value;

  to.value = column;
  form.requestSubmit();
  to.value = was;
}

function swallowClick() {
  const swallow = (event) => {
    event.preventDefault();
    event.stopPropagation();
  };

  document.addEventListener("click", swallow, true);
  setTimeout(() => document.removeEventListener("click", swallow, true));
}
