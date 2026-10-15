import { copyLater, refresh } from "./file_drop.js";
import { fresh } from "./fresh.js";
import { parse } from "./in_place.js";
import { forgetEdits, morphPage, whilePosting } from "./live.js";
import { showToast } from "./toast.js";

const CREATED = 201;
const REFUSED = 422;

const ready = new WeakSet();

export function setupLinkForms() {
  for (const form of fresh(ready, document.querySelectorAll("[data-link-form]"))) {
    form.addEventListener("submit", (event) => {
      event.preventDefault();
      send(form);
    });
  }
}

async function send(form) {
  const sent = whilePosting(
    fetch(form.action, {
      method: "POST",
      body: new URLSearchParams(new FormData(form)),
      headers: { Accept: "application/json" },
    }).then(async (response) => ({
      status: response.status,
      body: response.status === CREATED ? await response.json() : await response.text(),
    })),
  );
  const copied = copyLater(
    sent.then(({ status, body }) => {
      if (status !== CREATED) throw new Error("not shortened");

      return body.link;
    }),
  );
  const { status, body } = await sent.catch(() => ({}));

  if (status === CREATED) {
    form.reset();
    await refresh();
    return showToast((await copied) ? form.dataset.linkFormCopied : body.message);
  }

  const next = status === REFUSED && parse(body);
  if (!next?.querySelector("main")) return form.submit();

  forgetEdits(form);
  morphPage(next);
}
