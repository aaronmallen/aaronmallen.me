import { dragOnto, waitForDrag } from "./pointer.js";

const CARD = "[data-board-card]";
const COLUMN = "[data-board-column]";
const DRAGGING = "kc-dragging";
const MOVE = "form[data-morph]";
const OVER = "kcol-over";
const PRESS = "button, form, input, label";
const TITLE = ".kc-title";

export function bootBoardDrag() {
  document.addEventListener("pointerdown", (event) => {
    const card = event.target.closest(CARD);
    if (card && !event.target.closest(PRESS)) waitForDrag(event, (at) => drag(card, event, at));
  });
}

function drag(card, press, at) {
  const from = card.closest(COLUMN);

  dragOnto(press, {
    element: card,
    dragging: DRAGGING,
    ghost: "kc-ghost",
    label: card.querySelector(TITLE)?.textContent ?? "",
    at,
    target: COLUMN,
    accepts: (column) => column !== from,
    over: OVER,
    drop: (column) => submitTo(card, column.dataset.boardColumn),
  });
}

function submitTo(card, column) {
  const form = card.querySelector(MOVE);
  const to = form.elements.to;
  const was = to.value;

  to.value = column;
  form.requestSubmit();
  to.value = was;
}
