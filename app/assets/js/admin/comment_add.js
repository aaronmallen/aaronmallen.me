import { fresh } from "./fresh.js";

const ready = new WeakSet();

export function setupCommentAdds(root = document) {
  const forms = root.querySelectorAll("form[data-comment-add]");

  for (const form of fresh(ready, forms))
    form.querySelector("[data-editor-body]").addEventListener("input", () => show(form));
  for (const form of forms) show(form);
}

function show(form) {
  form.querySelector("button[type='submit']").hidden = !form.querySelector("[data-editor-body]").value.trim();
}
