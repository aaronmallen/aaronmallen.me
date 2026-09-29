const ACCEPT = "accept";
const DIALOG = "[data-confirm-dialog]";

const confirmed = new WeakSet();

export function setupConfirms(root = document) {
  if (root === document) setupDialog(document.querySelector(DIALOG));

  for (const form of root.querySelectorAll("form[data-confirm]")) {
    form.addEventListener("submit", (event) => {
      if (confirmed.delete(form)) return;

      const dialog = form.hasAttribute("data-confirm-styled") && document.querySelector(DIALOG);

      if (dialog) {
        event.preventDefault();
        ask(dialog, form, event.submitter);
      } else if (!window.confirm(form.dataset.confirm)) {
        event.preventDefault();
      }
    });
  }
}

function ask(dialog, form, submitter) {
  const opener = submitter ?? document.activeElement;

  dialog.querySelector("[data-confirm-message]").textContent = form.dataset.confirm;
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
