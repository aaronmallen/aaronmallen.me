export function setupDisclosures() {
  for (const toggle of document.querySelectorAll("[data-disclosure]")) {
    const panel = document.getElementById(toggle.getAttribute("aria-controls"));
    const isOpen = () => toggle.getAttribute("aria-expanded") === "true";
    const setOpen = (open) => toggle.setAttribute("aria-expanded", String(open));

    toggle.addEventListener("click", () => setOpen(!isOpen()));

    document.addEventListener("keydown", (event) => {
      if (event.key !== "Escape" || !isOpen()) return;

      setOpen(false);
      toggle.focus();
    });

    document.addEventListener("click", (event) => {
      if (!isOpen() || toggle.contains(event.target) || panel?.contains(event.target)) return;

      setOpen(false);
    });
  }
}
