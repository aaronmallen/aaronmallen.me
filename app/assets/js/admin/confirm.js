const ACCEPT = "accept";
const DIALOG = "[data-confirm-dialog]";

const confirmed = new WeakSet();

export function setupConfirms(root = document) {
  if (root === document) setupDialog(document.querySelector(DIALOG));

  for (const form of root.querySelectorAll("form[data-confirm], form:has([type='submit'][data-confirm])")) {
    form.addEventListener("submit", (event) => {
      if (confirmed.delete(form)) return;

      const asker = event.submitter?.hasAttribute("data-confirm") ? event.submitter : form;
      if (!asker.hasAttribute("data-confirm")) return;

      const dialog = asker.hasAttribute("data-confirm-styled") && document.querySelector(DIALOG);

      if (dialog) {
        event.preventDefault();
        ask(dialog, form, event.submitter, asker.dataset.confirm);
      } else if (!window.confirm(asker.dataset.confirm)) {
        event.preventDefault();
      }
    });
  }
}

function ask(dialog, form, submitter, message) {
  const opener = submitter ?? document.activeElement;

  dialog.querySelector("[data-confirm-message]").textContent = message;
  dialog.returnValue = "";
  dialog.addEventListener(
    "close",
    () => {
      dialog.hidden = true;
      opener?.focus();
      if (dialog.returnValue !== ACCEPT) return;

      confirmed.add(form);
      form.requestSubmit(submitter);
    },
    { once: true },
  );

  dialog.hidden = false;
  dialog.showModal();
}

function setupDialog(dialog) {
  if (!dialog) return;

  dialog.querySelector("[data-confirm-accept]").addEventListener("click", () => dialog.close(ACCEPT));
  dialog.querySelector("[data-confirm-decline]").addEventListener("click", () => dialog.close());
  dialog.addEventListener("click", (event) => {
    if (event.target === dialog) dialog.close();
  });
}
