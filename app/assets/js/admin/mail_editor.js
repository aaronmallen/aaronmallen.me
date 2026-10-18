import { fresh } from "./fresh.js";
import { whilePosting } from "./live.js";

const DRAFT_WAIT = 900;
const DROPPED = "script, style, meta, link, title, iframe, object, embed, template";
const ENTITIES = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" };
const KEYS = { KeyB: "bold", KeyI: "italic", KeyU: "underline", KeyK: "link", KeyE: "code", Backslash: "removeFormat" };
const SAFE_LINK = /^(https?:|mailto:)/i;
const SHIFT_KEYS = {
  KeyX: "strikeThrough",
  Digit8: "insertUnorderedList",
  Digit7: "insertOrderedList",
  Digit9: "quote",
};
const STATES = ["bold", "italic", "underline", "strikeThrough", "insertUnorderedList", "insertOrderedList"];
const WRAPS = { quote: "BLOCKQUOTE", code: "CODE", link: "A" };

const ready = new WeakSet();
const shows = new WeakMap();

export function setupMailEditors() {
  const editors = document.querySelectorAll("[data-mail-editor]");
  const forms = document.querySelectorAll("[data-mail-form]");

  for (const editor of fresh(ready, editors)) shows.set(editor, setupEditor(editor));
  for (const form of fresh(ready, forms)) shows.set(form, setupForm(form));
  for (const element of [...editors, ...forms]) shows.get(element)?.();
}

function cleanHtml(html) {
  const doc = new DOMParser().parseFromString(html, "text/html");
  for (const node of doc.body.querySelectorAll(DROPPED)) node.remove();
  for (const element of doc.body.querySelectorAll("*")) {
    for (const { name, value } of [...element.attributes]) {
      if (element.nodeName !== "A" || name !== "href" || !SAFE_LINK.test(value)) element.removeAttribute(name);
    }
  }
  return doc.body.innerHTML;
}

function escapeHtml(text) {
  return text.replace(/[&<>"]/g, (character) => ENTITIES[character]);
}

function setupEditor(editor) {
  const text = editor.querySelector("[data-mail-text]");
  const html = editor.querySelector("[data-mail-html]");
  const tools = editor.querySelector("[role=toolbar]");
  const bar = editor.querySelector("[data-mail-link]");
  const url = bar.querySelector("input");
  const surface = document.createElement("div");
  let range = null;

  surface.className = "mail-editor-surface";
  surface.contentEditable = "true";
  surface.setAttribute("role", "textbox");
  surface.setAttribute("aria-multiline", "true");
  surface.setAttribute("aria-label", text.placeholder);
  surface.dataset.placeholder = text.placeholder;
  for (const name of ["aria-describedby", "aria-invalid"]) {
    if (text.hasAttribute(name)) surface.setAttribute(name, text.getAttribute(name));
  }

  const within = (tag) => {
    for (let node = document.getSelection().anchorNode; node && node !== surface; node = node.parentNode) {
      if (node.nodeName === tag) return node;
    }
    return null;
  };

  const sync = () => {
    const empty = !surface.textContent.trim() && !surface.querySelector("li");
    surface.classList.toggle("empty", empty);
    html.value = empty ? "" : surface.innerHTML;
    text.value = surface.innerText;
  };

  const refresh = () => {
    if (!surface.contains(document.getSelection().anchorNode)) return;

    for (const button of tools.querySelectorAll("[data-mail-command]")) {
      const command = button.dataset.mailCommand;
      const on = STATES.includes(command) ? document.queryCommandState(command) : Boolean(within(WRAPS[command]));
      button.setAttribute("aria-pressed", String(on));
    }
  };

  const toggleCode = () => {
    const code = within("CODE");
    if (code) return code.replaceWith(code.textContent);

    const picked = document.getSelection().toString() || "code";
    document.execCommand("insertHTML", false, `<code>${escapeHtml(picked)}</code>&#8203;`);
  };

  const startLink = () => {
    if (within("A")) return document.execCommand("unlink");

    const selection = document.getSelection();
    range = selection.rangeCount ? selection.getRangeAt(0).cloneRange() : null;
    url.value = "";
    bar.hidden = false;
    url.focus();
  };

  const run = (command) => {
    surface.focus();
    if (command === "link") startLink();
    else if (command === "quote")
      document.execCommand("formatBlock", false, within("BLOCKQUOTE") ? "div" : "blockquote");
    else if (command === "code") toggleCode();
    else document.execCommand(command);
    sync();
    refresh();
  };

  const closeLink = () => {
    bar.hidden = true;
    surface.focus();
    const selection = document.getSelection();
    selection.removeAllRanges();
    if (range) selection.addRange(range);
  };

  const addLink = () => {
    let href = url.value.trim();
    closeLink();
    if (!href) return;

    if (!SAFE_LINK.test(href)) href = (href.includes("@") && !href.includes("/") ? "mailto:" : "https://") + href;
    if (document.getSelection().toString()) document.execCommand("createLink", false, href);
    else document.execCommand("insertHTML", false, `<a href="${escapeHtml(href)}">${escapeHtml(href)}</a>&nbsp;`);
    sync();
  };

  tools.addEventListener("mousedown", (event) => event.preventDefault());
  tools.addEventListener("click", (event) => {
    const button = event.target.closest("[data-mail-command]");
    if (button) run(button.dataset.mailCommand);
  });
  bar.querySelector("[data-mail-link-add]").addEventListener("click", addLink);
  bar.querySelector("[data-mail-link-cancel]").addEventListener("click", closeLink);
  url.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      event.preventDefault();
      addLink();
    } else if (event.key === "Escape") {
      event.preventDefault();
      event.stopPropagation();
      closeLink();
    }
  });

  surface.addEventListener("input", () => {
    sync();
    text.dispatchEvent(new Event("input"));
  });
  surface.addEventListener("keyup", refresh);
  surface.addEventListener("mouseup", refresh);
  surface.addEventListener("keydown", (event) => {
    if (!(event.metaKey || event.ctrlKey)) return;
    if (event.key === "Enter") {
      event.preventDefault();
      editor.closest("form").requestSubmit();
      return;
    }

    const command = (event.shiftKey ? SHIFT_KEYS : KEYS)[event.code];
    if (!command) return;

    event.preventDefault();
    run(command);
  });
  surface.addEventListener("paste", (event) => {
    const pasted = event.clipboardData.getData("text/html");
    if (!pasted) return;

    event.preventDefault();
    document.execCommand("insertHTML", false, cleanHtml(pasted));
    sync();
  });

  editor.closest("details")?.addEventListener("toggle", (event) => {
    if (event.target.open) surface.focus();
  });

  return () => {
    text.hidden = true;
    tools.hidden = false;
    if (surface.isConnected) return;

    surface.innerHTML = html.value ? cleanHtml(html.value) : escapeHtml(text.value).replace(/\n/g, "<br>");
    text.after(surface);
    sync();
  };
}

function setupAttach(form) {
  const files = form.querySelector("[data-mail-files]");
  const names = form.querySelector("[data-mail-file-names]");
  if (!files) return;

  files.addEventListener("change", () => {
    names.textContent = [...files.files].map((file) => file.name).join(", ");
  });
}

function dropResume() {
  const url = new URL(window.location.href);
  if (!url.searchParams.has("resume")) return;

  url.searchParams.delete("resume");
  window.history.replaceState(window.history.state, "", url);
}

function setupDraft(form) {
  const draft = form.querySelector("[data-mail-draft]");
  const status = form.querySelector("[data-mail-saved]");
  if (!draft) return;

  dropResume();

  let timer = null;
  let saving = Promise.resolve();
  let pending = 0;

  const save = async () => {
    const body = new FormData(form);
    body.delete("mail[files][]");
    if (!["mail[to]", "mail[subject]", "mail[body]"].some((name) => body.get(name)?.trim())) return;

    try {
      const response = await whilePosting(
        fetch(form.dataset.mailDraftUrl, { method: "POST", body, headers: { Accept: "application/json" } }),
      );
      if (!response.ok) throw new Error(response.statusText);

      draft.value = (await response.json()).draft;
      const time = new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
      status.textContent = status.dataset.mailSaved.replace("{time}", time);
    } catch {
      status.textContent = status.dataset.mailUnsaved;
    }
  };

  const queue = () => {
    timer = null;
    pending += 1;
    saving = saving.then(save).finally(() => {
      pending -= 1;
    });
  };

  form.addEventListener("input", (event) => {
    if (event.target.type === "file") return;

    clearTimeout(timer);
    timer = setTimeout(queue, DRAFT_WAIT);
  });
  form.addEventListener("submit", (event) => {
    clearTimeout(timer);
    if (pending === 0) return;

    event.preventDefault();
    saving.then(() => form.requestSubmit(event.submitter));
  });
}

function setupForm(form) {
  const from = form.querySelector("[data-mail-from]");
  const reveals = form.querySelector("[data-mail-reveals]");

  setupAttach(form);
  setupDraft(form);

  from?.addEventListener("change", () => {
    for (const signature of form.querySelectorAll("[data-mail-signature]")) {
      signature.hidden = signature.dataset.mailSignature !== from.value;
    }
  });

  if (!reveals) return undefined;

  const opened = new WeakSet();
  const pairs = [...reveals.querySelectorAll("[data-mail-reveal]")].map((button) => {
    const field = document.getElementById(button.dataset.mailReveal);
    return { button, field, row: field.closest("[data-mail-extra]") };
  });

  const show = () => {
    reveals.hidden = false;
    for (const { button, field, row } of pairs) {
      const shown = opened.has(row) || Boolean(field.value);
      row.hidden = !shown;
      button.hidden = shown;
    }
  };

  for (const { button, field, row } of pairs) {
    button.addEventListener("click", () => {
      opened.add(row);
      show();
      field.focus();
    });
  }

  return show;
}
