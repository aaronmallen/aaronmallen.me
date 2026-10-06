import { fresh } from "./fresh.js";

const ready = new WeakSet();

export function setupProjectEditors() {
  for (const form of fresh(ready, document.querySelectorAll("form[data-project-editor]"))) {
    setupProjectEditor(form);
  }
}

function setupProjectEditor(form) {
  const name = form.querySelector("[data-editor-name]");
  const tagline = form.querySelector("[data-editor-tagline]");
  const repo = form.querySelector("[data-editor-repo-input]");
  const save = form.querySelector("[data-editor-save]");
  const preview = form.querySelector("[data-editor-preview]");
  const subRepo = form.querySelector("[data-editor-repo]");

  const render = () => {
    save.disabled = name.value.trim() === "";
    fill(subRepo, repo.value, subRepo.dataset.editorRepo);
    fill(preview.querySelector(".n"), name.value, preview.dataset.name);
    fill(preview.querySelector("p"), tagline.value, preview.dataset.tagline);
  };

  settle(preview.querySelector("a.proj"));
  form.addEventListener("input", render);
  render();
}

function fill(target, value, placeholder) {
  if (!target) return;

  target.textContent = value.trim() === "" ? placeholder : value.trim();
}

function settle(card) {
  if (!card) return;

  card.tabIndex = -1;
  card.addEventListener("click", (event) => event.preventDefault());
}
