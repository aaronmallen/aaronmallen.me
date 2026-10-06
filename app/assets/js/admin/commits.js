import { fresh } from "./fresh.js";

const FORM = "form[data-commits-import]";

const ready = new WeakSet();
let bound = false;

export function setupCommitImports() {
  const forms = [...document.querySelectorAll(FORM)].filter((form) => !button(form).disabled);

  for (const form of fresh(ready, forms)) {
    form.addEventListener("submit", () => setImporting(form, true));
  }

  if (bound) return;

  bound = true;
  window.addEventListener("pageshow", () => {
    for (const form of document.querySelectorAll(FORM)) {
      if (ready.has(form)) setImporting(form, false);
    }
  });
}

function button(form) {
  return form.querySelector("button");
}

function setImporting(form, importing) {
  form.querySelector("[data-commits-idle]").hidden = importing;
  form.querySelector("[data-commits-busy]").hidden = !importing;
  button(form).disabled = importing;
}
