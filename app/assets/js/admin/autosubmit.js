export function setupAutosubmit() {
  for (const form of document.querySelectorAll("form[data-autosubmit]")) {
    form.addEventListener("change", () => form.requestSubmit());
    window.addEventListener("pageshow", () => form.reset());
  }
}
