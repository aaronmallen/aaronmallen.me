import { fresh } from "./fresh.js";
import { slugify } from "./slug.js";

const ready = new WeakSet();

export function setupPersonForms(root = document) {
  for (const form of fresh(ready, root.querySelectorAll("form[data-person-form='new']"))) {
    followName(form, form.querySelector("[data-person-field='name']"));
  }
}

function followName(form, name) {
  const key = form.querySelector("[data-person-field='key']");
  let follows = key.value === slugify(name.value);

  name.addEventListener("input", () => {
    if (follows) key.value = slugify(name.value);
  });

  key.addEventListener("input", () => {
    follows = key.value === "";
  });
}
