import { fresh } from "./fresh.js";

const DURATION = 2400;

const ready = new WeakSet();

export function setupToasts() {
  for (const region of fresh(ready, document.querySelectorAll("[data-toast]"))) {
    play(region);
  }
}

export function showToast(message, { failed = false } = {}) {
  const region = document.createElement("div");
  const toast = document.createElement("div");
  const icon = document.createElement("i");
  const text = document.createElement("span");

  region.setAttribute("role", "status");
  toast.className = failed ? "toast toast-failed" : "toast";
  toast.hidden = true;
  icon.className = `fa-solid ${failed ? "fa-triangle-exclamation" : "fa-check"} toast-icon`;
  icon.setAttribute("aria-hidden", "true");
  text.textContent = message;

  toast.append(icon, text);
  region.append(toast);
  document.body.append(region);
  play(region);
}

function play(region) {
  const toast = region.firstElementChild;

  requestAnimationFrame(() => {
    toast.hidden = false;
    setTimeout(() => region.remove(), DURATION);
  });
}
