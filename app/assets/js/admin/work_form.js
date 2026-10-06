import { fresh } from "./fresh.js";

const ready = new WeakSet();

export function setupWorkForms() {
  for (const form of fresh(ready, document.querySelectorAll("form[data-work-form]"))) {
    setupWorkForm(form);
  }
}

function setupWorkForm(form) {
  const org = form.querySelector("[data-work-org]");
  const role = form.querySelector("[data-work-role]");
  const add = form.querySelector("[data-work-add]");

  const render = () => {
    add.disabled = org.value.trim() === "" || role.value.trim() === "";
  };

  form.addEventListener("input", render);
  render();
}
