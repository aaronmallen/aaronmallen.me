import { ask } from "./dialog.js";
import { fresh } from "./fresh.js";

const DIALOG = "[data-confirm-dialog]";
const FORM = "form[data-confirm], form:has([type='submit'][data-confirm])";

const confirmed = new WeakSet();
const ready = new WeakSet();

export function setupConfirms(root = document) {
  for (const form of fresh(ready, root.querySelectorAll(FORM))) {
    form.addEventListener("submit", (event) => {
      if (confirmed.delete(form)) return;

      const asker = event.submitter?.hasAttribute("data-confirm") ? event.submitter : form;
      if (!asker.hasAttribute("data-confirm")) return;

      const dialog = asker.hasAttribute("data-confirm-styled") && document.querySelector(DIALOG);

      if (dialog) {
        event.preventDefault();
        dialog.querySelector("[data-confirm-message]").textContent = asker.dataset.confirm;
        ask(dialog, {
          opener: event.submitter,
          accept: () => {
            confirmed.add(form);
            form.requestSubmit(event.submitter);
          },
        });
      } else if (!window.confirm(asker.dataset.confirm)) {
        event.preventDefault();
      }
    });
  }
}
