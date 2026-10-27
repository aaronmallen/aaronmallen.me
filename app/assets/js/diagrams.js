import { currentTheme } from "./theme.js";

const DIAGRAM = "pre.mermaid";

const root = document.documentElement;
const systemDark = matchMedia("(prefers-color-scheme: dark)");
let watching = false;

async function draw(nodes) {
  if (nodes.length === 0) return;

  const { default: mermaid } = await import("mermaid");
  for (const node of nodes) {
    node.dataset.source ??= node.textContent;
    node.textContent = node.dataset.source;
    node.removeAttribute("data-processed");
  }
  mermaid.initialize({ startOnLoad: false, theme: currentTheme() === "dark" ? "dark" : "default" });
  await mermaid.run({ nodes });
}

function watchTheme() {
  const redraw = () => draw([...document.querySelectorAll(DIAGRAM)]);
  new MutationObserver(redraw).observe(root, { attributeFilter: ["data-site-theme"] });
  systemDark.addEventListener("change", redraw);
  watching = true;
}

export function setupDiagrams(scope = document) {
  if (!watching) watchTheme();
  draw([...scope.querySelectorAll(`${DIAGRAM}:not([data-processed])`)]);
}
