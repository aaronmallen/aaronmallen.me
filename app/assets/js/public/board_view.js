const KEY = "public:board-view";
const VIEWS = ["board", "list"];

export function setupBoardView() {
  const root = document.querySelector("[data-board-views]");
  if (!root) return;

  show(root, pick());
  root.addEventListener("click", (event) => {
    const view = event.target.closest("[data-board-view]")?.dataset.boardView;
    if (!view) return;

    show(root, view);
    save(view);
    const url = new URL(location.href);
    url.searchParams.set("view", view);
    history.replaceState(history.state, "", url);
  });
}

function pick() {
  const asked = new URLSearchParams(location.search).get("view");
  if (VIEWS.includes(asked)) return asked;

  const kept = saved();
  if (VIEWS.includes(kept)) return kept;

  return matchMedia("(width <= 700px)").matches ? "list" : "board";
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
    return localStorage.getItem(KEY);
  } catch {
    return null;
  }
}

function show(root, view) {
  root.dataset.view = view;
  for (const button of root.querySelectorAll("[data-board-view]")) {
    button.setAttribute("aria-pressed", String(button.dataset.boardView === view));
  }
}
