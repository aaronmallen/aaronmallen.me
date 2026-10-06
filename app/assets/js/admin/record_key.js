import { showToast } from "./toast.js";

export function setupRecordKeys(root = document) {
  for (const button of root.querySelectorAll("[data-record-key]")) {
    button.addEventListener("click", () => {
      navigator.clipboard.writeText(button.dataset.recordKey).then(() => showToast(button.dataset.recordKeyCopied));
    });
  }
}
