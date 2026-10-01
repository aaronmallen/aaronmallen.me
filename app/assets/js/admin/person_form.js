import { setupPersonSearch } from "./person_search.js";
import { slugify } from "./slug.js";

export function setupPersonForms(root = document) {
  for (const form of root.querySelectorAll("form[data-person-form]")) setupPersonForm(form);
}

function setupPersonForm(form) {
  const name = form.querySelector("[data-person-field='name']");

  if (form.dataset.personForm === "new") followName(form, name);

  for (const search of form.querySelectorAll("[data-person-search]")) setupPersonSearch(search, name);
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
