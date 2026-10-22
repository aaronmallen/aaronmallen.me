import { slugify } from "./slug.js";

const FORM = "form[data-contact-form]";

export function bootContactForms() {
  document.addEventListener("click", (event) => {
    const form = event.target.closest(FORM);
    if (!form) return;

    const add = event.target.closest("[data-contact-add]");
    const remove = event.target.closest("[data-contact-remove]");
    const more = event.target.closest("[data-contact-more]");
    const label = event.target.closest("[data-contact-label-add]");

    if (add) addEntry(add);
    else if (remove) remove.closest("[data-contact-entry]").remove();
    else if (more) toggleMore(form, more);
    else if (label) addLabel(form);
  });

  document.addEventListener("keydown", (event) => {
    if (event.key !== "Enter" || !event.target.matches("[data-contact-label-input]")) return;

    event.preventDefault();
    addLabel(event.target.closest(FORM));
  });
}

function addEntry(button) {
  const list = button.closest("[data-contact-entries]");
  const entry = list.querySelector("template[data-contact-template]").content.firstElementChild.cloneNode(true);

  list.querySelector("template[data-contact-template]").before(entry);
  entry.querySelector("input")?.focus();
}

function addLabel(form) {
  const input = form.querySelector("[data-contact-label-input]");
  const name = slugify(input.value);
  input.value = "";
  if (!name) return;

  const picks = form.querySelector("[data-contact-picks]");
  const found = picks.querySelector(`input[value="${CSS.escape(name)}"]`);
  if (found) {
    found.checked = true;
    return;
  }

  const pick = document.createElement("label");
  pick.className = "search-kind contact-pick";
  const box = document.createElement("input");
  Object.assign(box, { type: "checkbox", className: "sr-only", name: "person[labels][]", value: name, checked: true });
  pick.append(box, `#${name}`);
  picks.append(pick);
}

function toggleMore(form, button) {
  const on = button.getAttribute("aria-expanded") !== "true";

  for (const field of form.querySelectorAll("[data-contact-extra]")) field.hidden = !on;
  button.setAttribute("aria-expanded", String(on));
  button.textContent = on ? button.dataset.contactMoreOn : button.dataset.contactMoreOff;
}
