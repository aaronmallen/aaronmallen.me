import { setupCommentAdds } from "./comment_add.js";
import { setupConfirms } from "./confirm.js";
import { FIELD, focusField, showDialog } from "./dialog.js";
import { fresh } from "./fresh.js";
import { parse, plain, setupPost, setupVisit } from "./in_place.js";
import { setupMarkdownEditors } from "./markdown_editor.js";
import { setupRecordKeys } from "./record_key.js";
import { setupTaskOrder } from "./task_order.js";
import { showToast } from "./toast.js";

const CANCEL = "a[data-task-cancel]";
const EDIT = "[data-task-edit]";
const EDIT_KEY = "e";
const EDIT_LINK = "footer a[data-task-open-edit]";
const FIND = "[data-task-find]";
const LINKS = "a[data-task-open], a[data-task-open-edit], a[data-task-close]";
const TASK = "[data-task-read], [data-task-edit]";
const TOAST = "[data-toast]";

const ready = new WeakSet();
let bound = false;
let follow = null;

export function setupTaskPanel() {
  for (const panel of fresh(ready, document.querySelectorAll("[data-task-panel]"))) {
    follow = setupPanel(panel);
  }

  if (bound || !follow) return;

  bound = true;
  document.addEventListener("click", (event) => follow(event));
}

function bind(root) {
  setupCommentAdds(root);
  setupConfirms(root);
  setupMarkdownEditors(root);
  setupRecordKeys(root);
  setupTaskOrder(root);
}

function findUrl(form, button) {
  const data = new FormData(form);
  const url = new URL(button.dataset.taskFind, window.location.href);

  if (form.method === "get") {
    for (const [name, value] of data) url.searchParams.set(name, value);
    return url.href;
  }

  url.searchParams.set("link_kind", data.get("link[kind]") ?? "");
  url.searchParams.set("link_q", data.get("link_q") ?? "");
  return url.href;
}

function here() {
  return window.location.pathname + window.location.search;
}

function typing(event) {
  return event.ctrlKey || event.metaKey || event.altKey || event.isComposing || event.target.closest(FIELD);
}

function setupPanel(panel) {
  const panelBody = panel.querySelector("[data-task-panel-body]");
  const visit = setupVisit();
  let opener = null;
  let saved = false;

  const show = (task, keep = false, hash = "") => {
    const scroll = keep ? panelBody.scrollTop : 0;
    const name = keep ? document.activeElement?.name : null;

    panelBody.replaceChildren(task);
    bind(task);

    if (!panel.open) showDialog(panel);

    const field = name && task.querySelector(`[name="${name}"]`);
    if (field) field.focus({ preventScroll: true });
    else if (task.matches(EDIT)) focusField(task);
    else panelBody.focus({ preventScroll: true });

    panelBody.scrollTop = scroll;
    if (hash) task.querySelector(`[id="${CSS.escape(hash.slice(1))}"]`)?.scrollIntoView({ block: "start" });
  };

  const reread = async (url) => {
    const response = await fetch(url).catch(() => null);
    const page = response?.ok ? parse(await response.text()) : null;
    const task = page?.querySelector(TASK);
    if (!task) return window.location.assign(here());

    show(task);

    const toast = page.querySelector(TOAST);
    if (toast) showToast(toast.textContent.trim());
  };

  const post = setupPost({
    selector: EDIT,
    saved: async (response) => {
      if (response.type !== "opaqueredirect") return false;

      saved = true;
      await reread(panelBody.querySelector(CANCEL).href);
      return true;
    },
    invalid: (task) => show(task),
    live: (form) => panel.contains(form),
  });

  const click = (event) => {
    const link = event.target.closest(LINKS);
    if (!link || event.defaultPrevented || !plain(event)) return;

    const dialog = link.closest("dialog");

    if (link.hasAttribute("data-task-close")) {
      if (!dialog?.open) return;

      event.preventDefault();
      dialog.close();
      return;
    }

    if (link.hasAttribute("data-task-open-edit") && dialog && dialog !== panel) return;

    event.preventDefault();
    if (!panel.open) opener = link;
    visit(link.href, TASK, (task) => show(task, false, link.hash));
  };

  panel.addEventListener("submit", (event) => {
    const find = event.submitter?.closest(FIND);

    if (find) {
      event.preventDefault();
      visit(findUrl(event.target, find), TASK, (task) => show(task, true));
    } else if (event.target.matches(`${EDIT} form.task-form`)) {
      event.preventDefault();
      post(event.target);
    }
  });

  panel.addEventListener("keydown", (event) => {
    if (event.key !== EDIT_KEY || event.defaultPrevented || typing(event)) return;

    const edit = panelBody.querySelector(EDIT_LINK);
    if (!edit) return;

    event.preventDefault();
    edit.click();
  });

  panel.addEventListener("close", () => {
    panelBody.replaceChildren();
    if (saved) return window.location.assign(here());

    opener?.focus();
  });

  return click;
}
