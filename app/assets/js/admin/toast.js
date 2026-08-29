const DURATION = 2400;

export function setupToasts() {
  for (const region of document.querySelectorAll("[data-toast]")) {
    play(region);
  }
}

export function showToast(message) {
  const region = document.createElement("div");
  const toast = document.createElement("div");
  const icon = document.createElement("i");
  const text = document.createElement("span");

  region.setAttribute("role", "status");
  toast.className = "toast";
  toast.hidden = true;
  icon.className = "fa-solid fa-check toast-icon";
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
