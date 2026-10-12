import { fresh } from "./fresh.js";
import { showToast } from "./toast.js";

const ready = new WeakSet();

export function copy(text, message) {
  return navigator.clipboard.writeText(text).then(() => showToast(message));
}

export function setupRecordKeys(root = document) {
  for (const button of fresh(ready, root.querySelectorAll("[data-record-key]"))) {
    button.addEventListener("click", () => copy(button.dataset.recordKey, button.dataset.recordKeyCopied));
  }
}
