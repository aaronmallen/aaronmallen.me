const FIELD = "input:not([type=hidden]), textarea, select";

export function openDialog(id) {
  const dialog = document.getElementById(id);
  if (!dialog || dialog.open) return false;

  dialog.hidden = false;
  dialog.showModal();
  dialog.querySelector(FIELD)?.focus();
  return true;
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
      if (event.target === dialog) dialog.close();
    });

    for (const close of dialog.querySelectorAll("[data-dialog-close]")) {
      close.addEventListener("click", () => dialog.close());
    }
  }
}
