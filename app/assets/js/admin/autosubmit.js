import { fresh } from "./fresh.js";

const FORM = "form[data-autosubmit]";

const ready = new WeakSet();
let bound = false;

export function setupAutosubmit() {
  for (const form of fresh(ready, document.querySelectorAll(FORM))) {
    form.addEventListener("change", () => form.requestSubmit());
  }

  if (bound) return;

  bound = true;
  window.addEventListener("pageshow", () => {
    for (const form of document.querySelectorAll(FORM)) form.reset();
  });
}
