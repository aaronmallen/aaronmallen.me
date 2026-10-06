import { focusField, showDialog } from "./dialog.js";
import { load, parse, setupPost } from "./in_place.js";
import { fillField } from "./person_field.js";
import { setupPersonForms } from "./person_form.js";

const FORM = "form[data-person-form]";
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
  const form = await load(href, FORM);
  if (!form) throw new Error(href);

  let added = null;

  const show = (next) => {
    body.replaceChildren(next);
    setupPersonForms(body);
    next.addEventListener("submit", submit);
    focusField(next);
  };

  const post = setupPost({
    selector: FORM,
    body: (current) => {
      const data = new FormData(current);
      data.set("reply", REPLY);
      return data;
    },
    live: (current) => body.contains(current),
    saved: async (response) => {
      if (response.status !== 201) return false;

      added = person(await response.text());
      dialog.close();
      return true;
    },
    invalid: show,
  });

  const submit = (event) => {
    event.preventDefault();
    post(event.target);
  };

  dialog.addEventListener(
    "close",
    () => {
      body.replaceChildren();
      resolve(added);
    },
    { once: true },
  );

  showDialog(dialog);
  show(form);
  prefill(form.querySelector(NAME), name);
}

function person(html) {
  const found = parse(html);

  return {
    option: found.querySelector("[data-social-mention]"),
    people: JSON.parse(found.querySelector("[data-social-people]").dataset.socialPeople),
  };
}

function prefill(field, name) {
  if (field && name !== "") fillField(field, name);
}
