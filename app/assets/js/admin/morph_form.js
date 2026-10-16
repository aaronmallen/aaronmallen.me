import { Idiomorph } from "idiomorph";
import { MENU } from "./context_menu.js";
import { focusField } from "./dialog.js";
import { parse } from "./in_place.js";
import { MORPHED_PARTS, morphPage, whilePosting } from "./live.js";
import { showPageToast, showToast } from "./toast.js";

const FAILED = "[data-morph-failed]";
const FORM = "form[data-morph]";
const HIDDEN = "input[type=hidden]";
const HOSTS = `${MORPHED_PARTS}, ${MENU}`;
const OPEN = "[data-key-open]";
const ROW = "[data-key-row]";
const UNPROCESSABLE = 422;

const busy = new WeakSet();
let bound = false;

export function setupMorphForms() {
  if (bound) return;

  bound = true;
  document.addEventListener("submit", (event) => {
    const form = event.target;
    if (event.defaultPrevented || !form.matches(FORM) || !form.closest(HOSTS)) return;

    event.preventDefault();
    if (busy.has(form)) return;

    busy.add(form);
    whilePosting(post(form, event.submitter)).finally(() => busy.delete(form));
  });
}

export async function postAndMorph(url, body, form = null) {
  const landed = await landing(url, body, form?.id).catch(() => null);
  if (!landed) return showToast(document.querySelector(FAILED)?.dataset.morphFailed ?? "", { failed: true });
  if (landed.refused) return refuse(form, landed.refused);

  form?.reset();
  form?.closest("dialog")?.close();
  if (landed.url !== window.location.href) history.replaceState(history.state, "", landed.url);
  morphPage(landed.page);
  if (form) refocus(form);

  showPageToast(landed.page);
}

async function landing(url, body, id) {
  const response = await fetch(url, { method: "POST", body });
  if (response.status === UNPROCESSABLE && id) {
    const refused = parse(await response.text()).getElementById(id);
    return refused && { refused };
  }
  if (!response.ok) return null;

  return { url: response.url, page: parse(await response.text()) };
}

function post(form, submitter) {
  const url = submitter?.hasAttribute("formaction") ? submitter.formAction : form.action;
  return postAndMorph(url, new URLSearchParams(new FormData(form, submitter)), form);
}

function refuse(form, refused) {
  Idiomorph.morph(form, refused.childNodes, {
    morphStyle: "innerHTML",
    callbacks: { beforeNodeRemoved: (node) => !node.matches?.(HIDDEN) },
  });
  focusField(form);
}

function refocus(form) {
  const row = form.closest(ROW);
  if (document.activeElement !== document.body || !row?.isConnected) return;

  (row.querySelector(OPEN) ?? row).focus({ preventScroll: true });
}
