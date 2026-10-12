import { setupFetch, text } from "./fetching.js";
import { fresh } from "./fresh.js";
import { parse } from "./in_place.js";
import { forgetEdits, morphPage } from "./live.js";

const FORM = "form[data-autosubmit]";
const FILTER = `${FORM}[method="get"]`;

const ready = new WeakSet();
let bound = false;

export function setupAutosubmit() {
  for (const form of fresh(ready, document.querySelectorAll(FORM))) {
    form.addEventListener("change", () => form.requestSubmit());
  }

  if (bound) return;

  bound = true;
  const filter = setupFetch({
    request: (form) => ({ url: target(form) }),
    read: async (response) => ({ url: response.url, html: await text(response) }),
    done: ({ url, html }, form) => {
      history.replaceState(history.state, "", url);
      forgetEdits(form);
      morphPage(parse(html));
    },
    failed: (_error, form) => window.location.assign(target(form)),
  });

  document.addEventListener("submit", (event) => {
    if (event.defaultPrevented || !event.target.matches(FILTER)) return;

    event.preventDefault();
    filter.now(event.target);
  });
  window.addEventListener("pageshow", () => {
    for (const form of document.querySelectorAll(FORM)) form.reset();
  });
}

function target(form) {
  const url = new URL(form.action);
  url.search = new URLSearchParams(new FormData(form)).toString();
  return url.href;
}
