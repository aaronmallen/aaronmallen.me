import { setupConfirms } from "./confirm.js";
import { openDialog } from "./dialog.js";
import { setupMarkdownEditors } from "./markdown_editor.js";
import { setupTaskKeys } from "./task_key.js";
import { setupTaskOrder } from "./task_order.js";

const EDIT = "[data-task-edit]";
const FIELD = "input:not([type=hidden]), textarea, select";
const FIND = "[data-task-find]";
const INVALID = "[aria-invalid='true']";
const LINKS = "a[data-task-open], a[data-task-open-edit], a[data-task-close]";
const READ = "[data-task-read]";

export function setupTaskPanel() {
  const panel = document.querySelector("[data-task-panel]");
  const body = document.querySelector("[data-task-modal-body]");

  if (panel && body) setupPanel(panel, body.closest("dialog"));
}

function bind(root) {
  setupConfirms(root);
  setupMarkdownEditors(root);
  setupTaskKeys(root);
  setupTaskOrder(root);
}

function findUrl(form, button) {
  const data = new FormData(form);
  const url = new URL(button.dataset.taskFind, window.location.href);

  url.searchParams.set("link_kind", data.get("link[kind]") ?? "");
  url.searchParams.set("link_q", data.get("link_q") ?? "");
  return url.href;
}

function here() {
  return window.location.pathname + window.location.search;
}

async function load(url, selector) {
  const response = await fetch(url);
  if (!response.ok) return null;

  return part(await response.text(), selector);
}

function part(html, selector) {
  return new DOMParser().parseFromString(html, "text/html").querySelector(selector);
}

function plain(event) {
  return event.button === 0 && !event.metaKey && !event.ctrlKey && !event.shiftKey && !event.altKey;
}

function setupPanel(panel, modal) {
  const panelBody = panel.querySelector("[data-task-panel-body]");
  const modalBody = modal.querySelector("[data-task-modal-body]");
  const modalTitle = modal.querySelector("[data-task-modal-title]");
  let opener = null;
  let created = null;
  let latest = 0;
  let saving = false;

  const visit = (url, work) => {
    const ticket = ++latest;

    work(url, ticket)
      .catch(() => false)
      .then((done) => {
        if (!done && ticket === latest) window.location.assign(url);
      });
  };

  const read = async (url, ticket, keep = false) => {
    const task = await load(url, READ);
    if (ticket !== latest) return true;
    if (!task) return false;

    const scroll = keep ? panel.scrollTop : 0;
    const field = keep ? document.activeElement?.name : null;

    panelBody.replaceChildren(task);
    bind(task);

    if (!panel.open) {
      panel.hidden = false;
      panel.showModal();
    }

    const focus = (field && task.querySelector(`[name="${field}"]`)) || panelBody;
    focus.focus({ preventScroll: true });
    panel.scrollTop = scroll;
    return true;
  };

  const showEdit = (edit) => {
    if (!created) created = { nodes: [...modalBody.childNodes], title: modalTitle.textContent };

    modalBody.replaceChildren(edit);
    modalTitle.textContent = modalTitle.dataset.taskModalTitle;
    bind(edit);

    if (!modal.open) openDialog(modal.id);
    (edit.querySelector(INVALID) ?? edit.querySelector(FIELD))?.focus();
  };

  const edit = async (url, ticket) => {
    const form = await load(url, EDIT);
    if (ticket !== latest) return true;
    if (!form) return false;

    panel.close();
    showEdit(form);
    return true;
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

    const edit = response.status === 422 ? part(await response.text(), EDIT) : null;
    if (!edit) return form.submit();

    showEdit(edit);
  };

  document.addEventListener("click", (event) => {
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
      visit(link.href, edit);
    } else {
      event.preventDefault();
      if (!panel.open) opener = link;
      visit(link.href, read);
    }
  });

  panel.addEventListener("submit", (event) => {
    const find = event.submitter?.closest(FIND);
    if (!find) return;

    event.preventDefault();
    visit(findUrl(event.target, find), (href, ticket) => read(href, ticket, true));
  });

  panel.addEventListener("close", () => opener?.focus());

  modal.addEventListener("submit", (event) => {
    const form = event.target;
    if (!created || !form.matches(`${EDIT} form.task-form`)) return;

    event.preventDefault();
    if (saving) return;

    saving = true;
    save(form).finally(() => {
      saving = false;
    });
  });

  modal.addEventListener("close", () => {
    if (!created) return;

    modalBody.replaceChildren(...created.nodes);
    modalTitle.textContent = created.title;
    created = null;
    opener?.focus();
  });
}
