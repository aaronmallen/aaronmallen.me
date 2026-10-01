import { fillField } from "./person_field.js";
import { setupPersonForms } from "./person_form.js";

const FIELD = "input:not([type=hidden]), textarea, select";
const FORM = "form[data-person-form]";
const INVALID = "[aria-invalid='true']";
const NAME = "[data-person-field='name']";
const REPLY = "mention";

export function askForPerson(href, name) {
  const dialog = document.querySelector("[data-person-dialog]");
  if (dialog?.open) return Promise.resolve(null);

  return new Promise((resolve) => {
    const leave = () => {
      window.location.assign(href);
      resolve(null);
    };

    if (dialog) ask(dialog, href, name, resolve).catch(leave);
    else leave();
  });
}

async function ask(dialog, href, name, resolve) {
  const body = dialog.querySelector("[data-person-dialog-body]");
  const form = await load(href);
  if (!form) throw new Error(href);

  let added = null;
  let saving = false;

  const show = (next) => {
    body.replaceChildren(next);
    setupPersonForms(body);
    next.addEventListener("submit", submit);
    (next.querySelector(INVALID) ?? next.querySelector(FIELD))?.focus();
  };

  const save = async (current) => {
    const data = new URLSearchParams(new FormData(current));
    data.set("reply", REPLY);

    let response;
    try {
      response = await fetch(current.action, { method: "POST", body: data, redirect: "manual" });
    } catch {
      return current.submit();
    }

    if (!body.contains(current)) return;
    if (response.status === 201) {
      added = person(await response.text());
      return dialog.close();
    }

    const next = response.status === 422 ? part(await response.text(), FORM) : null;
    if (!next) return current.submit();

    show(next);
  };

  const submit = (event) => {
    event.preventDefault();
    if (saving) return;

    saving = true;
    save(event.target).finally(() => {
      saving = false;
    });
  };

  dialog.addEventListener(
    "close",
    () => {
      body.replaceChildren();
      resolve(added);
    },
    { once: true },
  );

  dialog.hidden = false;
  dialog.showModal();
  show(form);
  prefill(form.querySelector(NAME), name);
}

async function load(url) {
  const response = await fetch(url);
  if (!response.ok) return null;

  return part(await response.text(), FORM);
}

function part(html, selector) {
  return new DOMParser().parseFromString(html, "text/html").querySelector(selector);
}

function person(html) {
  const found = new DOMParser().parseFromString(html, "text/html");

  return {
    option: found.querySelector("[data-social-mention]"),
    people: JSON.parse(found.querySelector("[data-social-people]").dataset.socialPeople),
  };
}

function prefill(field, name) {
  if (field && name !== "") fillField(field, name);
}
