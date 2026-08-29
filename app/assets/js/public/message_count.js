export function setupMessageCount() {
  for (const line of document.querySelectorAll("[data-count-for]")) {
    const field = document.getElementById(line.dataset.countFor);
    if (!field) continue;

    const count = line.querySelector("[data-count]");
    const render = () => {
      count.textContent = field.value.length;
    };

    line.querySelector("[data-total]").textContent = field.maxLength;
    field.addEventListener("input", render);
    render();
    line.hidden = false;
  }
}
