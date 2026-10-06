import { fresh } from "./fresh.js";
import { setupPersonSearch } from "./person_search.js";
import { slugify } from "./slug.js";

const FORM = "form[data-person-form]";

const ready = new WeakSet();

export function setupPersonForms(root = document) {
  for (const form of root.querySelectorAll(FORM)) {
    const name = form.querySelector("[data-person-field='name']");

    for (const search of form.querySelectorAll("[data-person-search]")) setupPersonSearch(search, name);
  }

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
