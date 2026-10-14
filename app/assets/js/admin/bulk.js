import { fresh } from "./fresh.js";

const ACTS = "[data-bulk-acts]";
const ALL = "[data-bulk-all]";
const CHOOSE = "[data-bulk-choose]";
const COUNT = "[data-bulk-count]";
const FORM = "form[data-bulk]";
const TOGGLE = "[data-bulk-toggle]";

const pressed = new Set();
const ready = new WeakSet();
let bound = false;

export function setupBulk(root = document) {
  for (const form of root.querySelectorAll(FORM)) {
    form.querySelector(ALL).hidden = false;
    for (const choose of form.querySelectorAll(CHOOSE)) choose.nextElementSibling.hidden = true;
    show(form);
  }

  for (const button of root.querySelectorAll(TOGGLE)) {
    const form = document.getElementById(button.dataset.bulkToggle);
    if (!form) continue;

    button.hidden = false;
    pick(form, button, pressed.has(form.id));
    if (fresh(ready, [button]).length) button.addEventListener("click", () => flip(button));
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
    if (!form?.matches(FORM) || event.target === all(form)) return;

    show(form);
    if (event.target.matches(CHOOSE) && event.target.value) form.requestSubmit(event.target.nextElementSibling);
  });
  window.addEventListener("pageshow", () => {
    for (const choose of document.querySelectorAll(CHOOSE)) choose.value = "";
    for (const form of document.querySelectorAll(FORM)) show(form);
  });
}

export function clear(form) {
  for (const box of picks(form)) box.checked = false;
  show(form);
}

export function picks(form) {
  return [...form.elements].filter((element) => element.name === form.dataset.bulk);
}

function all(form) {
  return form.querySelector(ALL).querySelector("input");
}

function flip(button) {
  const form = document.getElementById(button.dataset.bulkToggle);
  pick(form, button, !pressed.has(form.id));
}

function pick(form, button, on) {
  if (on) pressed.add(form.id);
  else pressed.delete(form.id);
  button.setAttribute("aria-pressed", String(on));
  form.toggleAttribute("data-bulk-off", !on);
  if (on) show(form);
  else clear(form);
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
