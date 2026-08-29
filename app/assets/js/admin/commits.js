export function setupCommitImports() {
  for (const form of document.querySelectorAll("form[data-commits-import]")) {
    const button = form.querySelector("button");

    if (!button.disabled) setupCommitImport(form, button);
  }
}

function setupCommitImport(form, button) {
  const idle = form.querySelector("[data-commits-idle]");
  const busy = form.querySelector("[data-commits-busy]");

  const setImporting = (importing) => {
    idle.hidden = importing;
    busy.hidden = !importing;
    button.disabled = importing;
  };

  form.addEventListener("submit", () => setImporting(true));
  window.addEventListener("pageshow", () => setImporting(false));
}
