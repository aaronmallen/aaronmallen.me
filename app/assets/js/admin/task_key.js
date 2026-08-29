import { showToast } from "./toast.js";

export function setupTaskKeys() {
  for (const button of document.querySelectorAll("[data-task-key]")) {
    button.addEventListener("click", () => {
      navigator.clipboard.writeText(button.dataset.taskKey).then(() => showToast(button.dataset.taskKeyCopied));
    });
  }
}
