import { followPointer, GHOST_OFFSET, menu, still, swallowClick, waitForDrag } from "./pointer.js";

const CARD = "[data-board-card]";
const COLUMN = "[data-board-column]";
const DRAGGING = "kc-dragging";
const MOVE = "form[data-morph]";
const OVER = "kcol-over";
const PRESS = "button, form, input, label";
const TITLE = ".kc-title";

let bound = false;

export function setupBoardDrag() {
  if (bound) return;

  bound = true;
  document.addEventListener("pointerdown", (event) => {
    const card = event.target.closest(CARD);
    if (card && !event.target.closest(PRESS)) waitForDrag(event, (at) => drag(card, event, at));
  });
}

function drag(card, press, at) {
  const from = card.closest(COLUMN);
  let ghost = null;
  let over = null;

  const move = (moved) => {
    ghost.style.translate = `${moved.clientX + GHOST_OFFSET}px ${moved.clientY + GHOST_OFFSET}px`;
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
  ghost.style.translate = `${start.clientX + GHOST_OFFSET}px ${start.clientY + GHOST_OFFSET}px`;
  document.body.append(ghost);
  return ghost;
}

function submitTo(card, column) {
  const form = card.querySelector(MOVE);
  const to = form.elements.to;
  const was = to.value;

  to.value = column;
  form.requestSubmit();
  to.value = was;
}
