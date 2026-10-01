import { slugify } from "./slug.js";

export function setupPersonForms(root = document) {
  for (const form of root.querySelectorAll("form[data-person-form='new']")) setupPersonForm(form);
}

function setupPersonForm(form) {
  const name = form.querySelector("[data-person-field='name']");
  const key = form.querySelector("[data-person-field='key']");
  let follows = key.value === slugify(name.value);

  name.addEventListener("input", () => {
    if (follows) key.value = slugify(name.value);
  });

  key.addEventListener("input", () => {
    follows = key.value === "";
  });
}
