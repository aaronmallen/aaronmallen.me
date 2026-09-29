export function setupConfirms(root = document) {
  for (const form of root.querySelectorAll("form[data-confirm]")) {
    form.addEventListener("submit", (event) => {
      if (!window.confirm(form.dataset.confirm)) event.preventDefault();
    });
  }
}
