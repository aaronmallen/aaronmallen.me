const ACCEPT = "accept";
const INVALID = "[aria-invalid='true']";

export const FIELD = "input:not([type=hidden]), textarea, select";

export function ask(dialog, { opener, focus, accept, refocus = "always" }) {
  const back = opener ?? document.activeElement;

  dialog.returnValue = "";
  dialog.addEventListener(
    "close",
    () => {
      const accepted = dialog.returnValue === ACCEPT;

      if (!accepted || refocus === "always") back?.focus();
      if (accepted) accept();
    },
    { once: true },
  );

  showDialog(dialog);
  focus?.focus();
}

export function focusField(root) {
  (root.querySelector(INVALID) ?? root.querySelector(FIELD))?.focus();
}

export function openDialog(id) {
  const dialog = document.getElementById(id);
  if (!dialog || dialog.open) return false;

  showDialog(dialog);
  focusField(dialog);
  return true;
}

export function showDialog(dialog) {
  dialog.hidden = false;
  dialog.showModal();
}

export function setupDialogs() {
  for (const trigger of document.querySelectorAll("[data-dialog-open]")) {
    trigger.addEventListener("click", (event) => {
      if (openDialog(trigger.dataset.dialogOpen)) event.preventDefault();
    });
  }

  for (const dialog of document.querySelectorAll("[data-dialog]")) {
    dialog.addEventListener("close", () => {
      dialog.hidden = true;
    });
    dialog.addEventListener("click", (event) => {
      if (event.target === dialog && dialog.dataset.dialog !== "static") dialog.close();
    });

    for (const close of dialog.querySelectorAll("[data-dialog-close]")) {
      close.addEventListener("click", () => dialog.close());
    }

    for (const accept of dialog.querySelectorAll("[data-dialog-accept]")) {
      accept.addEventListener("click", () => dialog.close(ACCEPT));
    }
  }
}
