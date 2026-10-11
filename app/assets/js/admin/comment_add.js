import { fresh } from "./fresh.js";

const ready = new WeakSet();

export function setupCommentAdds(root = document) {
  for (const form of fresh(ready, root.querySelectorAll("form[data-comment-add]"))) {
    const body = form.querySelector("[data-editor-body]");
    const button = form.querySelector("button[type='submit']");
    const show = () => {
      button.hidden = !body.value.trim();
    };

    body.addEventListener("input", show);
    show();
  }
}
