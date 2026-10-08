import { fresh } from "./fresh.js";

const FORM = "form[data-confirm], form:has([type='submit'][data-confirm])";
const TEMPLATE = "template[data-confirm-template]";

export const ASKING = "[data-confirm-ask]";

const confirmed = new WeakSet();
const ready = new WeakSet();

export function setupConfirms(root = document) {
  for (const form of fresh(ready, root.querySelectorAll(FORM))) {
    form.addEventListener("submit", (event) => {
      if (confirmed.delete(form)) return;

      const asker = event.submitter?.hasAttribute("data-confirm") ? event.submitter : form;
      if (!asker.hasAttribute("data-confirm")) return;

      event.preventDefault();
      ask(form, event.submitter, asker.dataset.confirm);
    });
  }
}

function ask(form, submitter, message) {
  const template = document.querySelector(TEMPLATE);
  const anchor = submitter ?? form;
  if (!template || anchor.nextElementSibling?.matches(ASKING)) return;

  const asking = template.content.firstElementChild.cloneNode(true);
  const accept = asking.querySelector("[data-confirm-accept]");
  const no = asking.querySelector("[data-confirm-decline]");
  const label = submitter?.textContent.trim();

  asking.querySelector("[data-confirm-message]").textContent = message;
  asking.setAttribute("aria-label", message);
  if (label) accept.textContent = label;

  const dialog = anchor.closest("dialog");
  const decline = () => settle(false);
  const onKey = (event) => {
    if (event.key === "Escape") decline();
  };

  const settle = (yes) => {
    dialog?.removeEventListener("close", decline);
    asking.remove();
    anchor.hidden = false;

    if (yes) {
      confirmed.add(form);
      form.requestSubmit(submitter);
    } else {
      submitter?.focus();
    }

    form.dispatchEvent(new Event("close"));
  };

  accept.addEventListener("click", () => settle(true));
  no.addEventListener("click", decline);
  if (dialog) dialog.addEventListener("close", decline);
  else asking.addEventListener("keydown", onKey);

  anchor.hidden = true;
  anchor.after(asking);
  no.focus();
}
