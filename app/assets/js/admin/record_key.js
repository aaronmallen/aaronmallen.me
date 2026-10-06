import { fresh } from "./fresh.js";
import { showToast } from "./toast.js";

const ready = new WeakSet();

export function setupRecordKeys(root = document) {
  for (const button of fresh(ready, root.querySelectorAll("[data-record-key]"))) {
    button.addEventListener("click", () => {
      navigator.clipboard.writeText(button.dataset.recordKey).then(() => showToast(button.dataset.recordKeyCopied));
    });
  }
}
