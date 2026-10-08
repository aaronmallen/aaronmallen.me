import { fresh } from "./fresh.js";

const ACTS = "[data-bulk-acts]";
const ALL = "[data-bulk-all]";
const COUNT = "[data-bulk-count]";
const FORM = "form[data-bulk]";
const TOGGLE = "[data-bulk-toggle]";

const ready = new WeakSet();
let bound = false;

export function setupBulk(root = document) {
  for (const form of root.querySelectorAll(FORM)) {
    form.querySelector(ALL).hidden = false;
    show(form);
  }

  for (const button of fresh(ready, root.querySelectorAll(TOGGLE))) {
    const form = document.getElementById(button.dataset.bulkToggle);
    if (!form) continue;

    button.hidden = false;
    pick(form, button, false);
    button.addEventListener("click", () => pick(form, button, button.getAttribute("aria-pressed") !== "true"));
  }

  for (const form of fresh(ready, root.querySelectorAll(FORM))) {
    const box = all(form);

    box.addEventListener("change", () => {
      for (const pick of picks(form)) pick.checked = box.checked;
      show(form);
    });
  }

  if (bound) return;

  bound = true;
  document.addEventListener("change", (event) => {
    const form = event.target.form;
    if (form?.matches(FORM) && event.target !== all(form)) show(form);
  });
  window.addEventListener("pageshow", () => {
    for (const form of document.querySelectorAll(FORM)) show(form);
  });
}

function all(form) {
  return form.querySelector(ALL).querySelector("input");
}

function pick(form, button, on) {
  button.setAttribute("aria-pressed", String(on));
  form.toggleAttribute("data-bulk-off", !on);
  if (!on) for (const box of picks(form)) box.checked = false;
  show(form);
}

function picks(form) {
  return [...form.elements].filter((element) => element.name === form.dataset.bulk);
}

function show(form) {
  const box = all(form);
  const shown = picks(form);
  const ticked = shown.filter((pick) => pick.checked).length;
  const count = form.querySelector(COUNT);

  box.checked = ticked > 0 && ticked === shown.length;
  box.indeterminate = ticked > 0 && ticked < shown.length;
  count.textContent = ticked > 0 ? count.dataset.bulkCount.replace("%{count}", ticked) : "";
  form.querySelector(ACTS).hidden = ticked === 0;
}
