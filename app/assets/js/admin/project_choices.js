import { json } from "./fetching.js";
import { fresh } from "./fresh.js";

const ready = new WeakSet();
const loads = new WeakSet();

export function setupProjectChoices() {
  for (const select of fresh(ready, document.querySelectorAll("select[data-project-choices]"))) {
    (select.closest("dialog") ?? select).addEventListener("focusin", () => load(select));
  }
}

function load(select) {
  if (loads.has(select)) return;

  loads.add(select);
  fetch(select.dataset.projectChoices, { headers: { Accept: "application/json" }, redirect: "manual" })
    .then(json)
    .then(({ projects }) => select.append(...projects.map(({ key, name }) => new Option(name, key))))
    .catch(() => loads.delete(select));
}
