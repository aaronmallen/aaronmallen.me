export function setupSearchKey() {
  const input = document.querySelector(".sq input");
  if (!input) return;

  document.addEventListener("keydown", (event) => {
    if (event.key !== "/" || event.target.closest("input, textarea, select, [contenteditable]")) return;
    event.preventDefault();
    input.focus();
  });
}
