import { floatGhost, followPointer, holdPage, moveGhost, releasePage, waitForDrag } from "./pointer.js";

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
  let ghost = null;
  let over = null;

  const move = (moved) => {
    moveGhost(ghost, moved);
    over?.classList.remove(OVER);
    over = columnAt(moved, from);
    over?.classList.add(OVER);
  };

  const end = (done, cancelled) => {
    releasePage();
    ghost.remove();
    over?.classList.remove(OVER);

    const column = cancelled ? null : columnAt(done, from);
    if (column) submitTo(card, column.dataset.boardColumn);
  };

  if (!followPointer(press, { element: card, dragging: DRAGGING, move, end })) return;

  holdPage();
  ghost = floatGhost("kc-ghost", card.querySelector(TITLE)?.textContent ?? "", at);
}

function columnAt(event, from) {
  const column = document.elementFromPoint(event.clientX, event.clientY)?.closest(COLUMN);

  return column && column !== from ? column : null;
}

function submitTo(card, column) {
  const form = card.querySelector(MOVE);
  const to = form.elements.to;
  const was = to.value;

  to.value = column;
  form.requestSubmit();
  to.value = was;
}
