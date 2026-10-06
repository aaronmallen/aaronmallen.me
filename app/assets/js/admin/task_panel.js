import { setupConfirms } from "./confirm.js";
import { focusField, openDialog, showDialog } from "./dialog.js";
import { fresh } from "./fresh.js";
import { plain, setupPost, setupVisit } from "./in_place.js";
import { setupMarkdownEditors } from "./markdown_editor.js";
import { setupRecordKeys } from "./record_key.js";
import { setupTaskOrder } from "./task_order.js";

const EDIT = "[data-task-edit]";
const FIND = "[data-task-find]";
const LINKS = "a[data-task-open], a[data-task-open-edit], a[data-task-close]";
const READ = "[data-task-read]";

const ready = new WeakSet();
let bound = false;
let follow = null;

export function setupTaskPanel() {
  const body = document.querySelector("[data-task-modal-body]");
  if (!body) return;

  for (const panel of fresh(ready, document.querySelectorAll("[data-task-panel]"))) {
    follow = setupPanel(panel, body.closest("dialog"));
  }

  if (bound || !follow) return;

  bound = true;
  document.addEventListener("click", (event) => follow(event));
}

function bind(root) {
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

function setupPanel(panel, modal) {
  const panelBody = panel.querySelector("[data-task-panel-body]");
  const modalBody = modal.querySelector("[data-task-modal-body]");
  const modalTitle = modal.querySelector("[data-task-modal-title]");
  const visit = setupVisit();
  let opener = null;
  let created = null;

  const read = (task, keep = false) => {
    const scroll = keep ? panel.scrollTop : 0;
    const field = keep ? document.activeElement?.name : null;

    panelBody.replaceChildren(task);
    bind(task);

    if (!panel.open) showDialog(panel);

    const focus = (field && task.querySelector(`[name="${field}"]`)) || panelBody;
    focus.focus({ preventScroll: true });
    panel.scrollTop = scroll;
  };

  const showEdit = (edit) => {
    if (!created) created = { nodes: [...modalBody.childNodes], title: modalTitle.textContent };

    modalBody.replaceChildren(edit);
    modalTitle.textContent = modalTitle.dataset.taskModalTitle;
    bind(edit);

    if (!modal.open) openDialog(modal.id);
    focusField(edit);
  };

  const edit = (form) => {
    panel.close();
    showEdit(form);
  };

  const post = setupPost({
    selector: EDIT,
    saved: (response) => {
      if (response.type !== "opaqueredirect") return false;

      window.location.assign(here());
      return true;
    },
    invalid: showEdit,
  });

  const click = (event) => {
    const link = event.target.closest(LINKS);
    if (!link || event.defaultPrevented || !plain(event)) return;

    const dialog = link.closest("dialog");

    if (link.hasAttribute("data-task-close")) {
      if (!dialog?.open) return;

      event.preventDefault();
      dialog.close();
    } else if (link.hasAttribute("data-task-open-edit")) {
      if (dialog && dialog !== panel) return;

      event.preventDefault();
      if (!dialog) opener = link;
      visit(link.href, EDIT, edit);
    } else {
      event.preventDefault();
      if (!panel.open) opener = link;
      visit(link.href, READ, read);
    }
  };

  panel.addEventListener("submit", (event) => {
    const find = event.submitter?.closest(FIND);
    if (!find) return;

    event.preventDefault();
    visit(findUrl(event.target, find), READ, (task) => read(task, true));
  });

  panel.addEventListener("close", () => opener?.focus());

  modal.addEventListener("submit", (event) => {
    const form = event.target;
    if (!created || !form.matches(`${EDIT} form.task-form`)) return;

    event.preventDefault();
    post(form);
  });

  modal.addEventListener("close", () => {
    if (!created) return;

    modalBody.replaceChildren(...created.nodes);
    modalTitle.textContent = created.title;
    created = null;
    opener?.focus();
  });

  return click;
}
