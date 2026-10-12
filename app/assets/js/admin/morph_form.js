import { parse } from "./in_place.js";
import { MORPHED_PARTS, morphPage } from "./live.js";
import { showToast } from "./toast.js";

const FAILED = "[data-morph-failed]";
const FORM = "form[data-morph]";
const OPEN = "[data-key-open]";
const ROW = "[data-key-row]";
const TOAST = "[data-toast]";

const busy = new WeakSet();
let bound = false;

export function setupMorphForms() {
  if (bound) return;

  bound = true;
  document.addEventListener("submit", (event) => {
    const form = event.target;
    if (event.defaultPrevented || !form.matches(FORM) || !form.closest(MORPHED_PARTS)) return;

    event.preventDefault();
    if (busy.has(form)) return;

    busy.add(form);
    post(form, event.submitter).finally(() => busy.delete(form));
  });
}

async function landing(form, submitter) {
  const body = new URLSearchParams(new FormData(form, submitter));
  const response = await fetch(form.action, { method: "POST", body });
  if (!response.ok) return null;

  return { url: response.url, page: parse(await response.text()) };
}

async function post(form, submitter) {
  const landed = await landing(form, submitter).catch(() => null);
  if (!landed) return showToast(document.querySelector(FAILED)?.dataset.morphFailed ?? "", { failed: true });

  form.reset();
  form.closest("dialog")?.close();
  if (landed.url !== window.location.href) history.replaceState(history.state, "", landed.url);
  morphPage(landed.page);
  refocus(form);

  const toast = landed.page.querySelector(TOAST);
  if (toast) showToast(toast.textContent.trim());
}

function refocus(form) {
  const row = form.closest(ROW);
  if (document.activeElement !== document.body || !row?.isConnected) return;

  (row.querySelector(OPEN) ?? row).focus({ preventScroll: true });
}
