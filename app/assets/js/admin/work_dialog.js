import { setupWorkForm } from "./work_form.js";

const CLOSE = "[data-dialog-close]";
const FIELD = "input:not([type=hidden]), textarea, select";
const FORM = "main form[data-work-form]";
const INVALID = "[aria-invalid='true']";

export function setupWorkDialog() {
  const dialog = document.querySelector("[data-work-dialog]");

  if (dialog) setupDialog(dialog);
}

function here() {
  return window.location.pathname + window.location.search;
}

function part(html, selector) {
  return new DOMParser().parseFromString(html, "text/html").querySelector(selector);
}

function setupDialog(dialog) {
  const body = dialog.querySelector("[data-work-dialog-body]");
  let blank = null;
  let saving = false;

  const show = (form) => {
    if (!blank) blank = [...body.childNodes];

    body.replaceChildren(form);
    setupWorkForm(form);
    (form.querySelector(INVALID) ?? form.querySelector(FIELD))?.focus();
  };

  const save = async (form) => {
    let response;

    try {
      response = await fetch(form.action, {
        method: "POST",
        body: new URLSearchParams(new FormData(form)),
        redirect: "manual",
      });
    } catch {
      return form.submit();
    }

    if (response.type === "opaqueredirect") return window.location.assign(here());

    const next = response.status === 422 ? part(await response.text(), FORM) : null;
    if (!next) return form.submit();

    show(next);
  };

  body.addEventListener("click", (event) => {
    if (!blank || !event.target.closest(CLOSE)) return;

    event.preventDefault();
    dialog.close();
  });

  dialog.addEventListener("submit", (event) => {
    event.preventDefault();
    if (saving) return;

    saving = true;
    save(event.target).finally(() => {
      saving = false;
    });
  });

  dialog.addEventListener("close", () => {
    if (!blank) return;

    body.replaceChildren(...blank);
    blank = null;
  });
}
