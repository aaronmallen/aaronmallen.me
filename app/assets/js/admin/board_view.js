const KEY = "admin:board-view";
const NARROW = "(width <= 43.75rem)";
const PARAM = "view";
const PICK = "[data-board-pick]";
const ROOT = "[data-board-views]";
const VIEWS = ["board", "list"];

let shown = null;

export function setupBoardView() {
  const root = document.querySelector(ROOT);
  if (!root) {
    shown = null;
    return;
  }

  show(root, asked() ?? shown ?? saved() ?? (window.matchMedia(NARROW).matches ? "list" : "board"));
}

export function bootBoardView() {
  document.addEventListener("click", (event) => {
    const pick = event.target.closest?.(PICK);
    const root = document.querySelector(ROOT);
    if (!pick || !root || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey) return;

    event.preventDefault();
    const view = pick.dataset.boardPick;
    show(root, view);
    save(view);

    const url = new URL(window.location.href);
    url.searchParams.set(PARAM, view);
    history.replaceState(history.state, "", url);
  });
}

function asked() {
  const view = new URLSearchParams(window.location.search).get(PARAM);
  return VIEWS.includes(view) ? view : null;
}

function save(view) {
  try {
    localStorage.setItem(KEY, view);
  } catch {
    return;
  }
}

function saved() {
  try {
    const view = localStorage.getItem(KEY);
    return VIEWS.includes(view) ? view : null;
  } catch {
    return null;
  }
}

function show(root, view) {
  shown = view;
  root.dataset.boardView = view;

  for (const pick of document.querySelectorAll(PICK)) {
    const on = pick.dataset.boardPick === view;
    pick.classList.toggle("current", on);
    if (on) pick.setAttribute("aria-current", "page");
    else pick.removeAttribute("aria-current");
  }
}
