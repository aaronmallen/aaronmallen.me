import { showToast } from "./toast.js";

export function setupTaskKeys(root = document) {
  for (const button of root.querySelectorAll("[data-task-key]")) {
    button.addEventListener("click", () => {
      navigator.clipboard.writeText(button.dataset.taskKey).then(() => showToast(button.dataset.taskKeyCopied));
    });
  }
}
