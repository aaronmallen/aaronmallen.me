import { ask } from "./dialog.js";

const DIALOG = "[data-confirm-dialog]";

const confirmed = new WeakSet();

export function setupConfirms(root = document) {
  for (const form of root.querySelectorAll("form[data-confirm], form:has([type='submit'][data-confirm])")) {
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
