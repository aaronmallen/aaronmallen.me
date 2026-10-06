import { setupFetch } from "./fetching.js";

const BRACKET = 2;
const EDITOR = "[data-markdown-editor]";
const PHOTO = "photo";
const TOKEN = "_csrf_token";

const ready = new WeakSet();

export function setupMarkdownEditors(root = document) {
  for (const editor of root.querySelectorAll(EDITOR)) {
    if (ready.has(editor)) continue;

    ready.add(editor);
    setupMarkdownEditor(editor);
  }
}

function setupMarkdownEditor(editor) {
  const body = editor.querySelector("[data-editor-body]");
  const preview = editor.querySelector("[data-editor-preview]");
  const pane = preview.closest("[data-editor-view]");
  const panels = editor.querySelectorAll("[data-editor-view]");
  const radios = [...editor.querySelectorAll("input[type='radio']")];
  const whole = preview.hasAttribute("data-editor-preview-form");
  let stale = !preview.hasChildNodes();

  const payload = () => {
    if (whole) return new URLSearchParams(new FormData(body.form ?? undefined));

    return new URLSearchParams({ [TOKEN]: tokenFor(body), markdown: body.value });
  };

  const refresh = setupFetch({
    request: () => ({ url: preview.dataset.editorPreview, method: "POST", body: payload(), redirect: "manual" }),
    done: (html) => {
      preview.innerHTML = html;
      stale = false;
    },
  });

  const view = () => radios.find((radio) => radio.checked)?.value;

  const showing = () => view() === pane.dataset.editorView;

  const renderView = () => {
    const current = view();
    if (!current) return;

    for (const panel of panels) panel.hidden = panel.dataset.editorView !== current;
  };

  for (const button of editor.querySelectorAll("[data-snippet]")) {
    button.addEventListener("click", () => {
      insertAtCursor(body, button.dataset.snippet);
      changed(body);
    });
  }

  if (editor.dataset.editorUpload) setupUploads(editor, body);

  for (const radio of radios) {
    radio.addEventListener("change", () => {
      renderView();
      if (showing() && stale) refresh.now();
      else refresh.stop();
    });
  }

  (whole && body.form ? body.form : body).addEventListener("input", (event) => {
    if (event.target.type === "radio" && event.target.closest(EDITOR)) return;

    stale = true;
    if (showing()) refresh.later();
    else refresh.stop();
  });

  renderView();
}

function setupUploads(editor, body) {
  const endpoint = editor.dataset.editorUpload;
  const alert = editor.querySelector("[data-editor-alert]");
  const picker = editor.querySelector("[data-editor-file]");

  const say = (message) => {
    alert.textContent = message;
  };

  const marker = (file, taken) => {
    const name = file.name.replace(/[[\]\n]/g, "");
    for (let count = 1; ; count += 1) {
      const text = `![${editor.dataset.editorUploading} ${name}${count > 1 ? ` (${count})` : ""}…]()`;
      if (!taken.includes(text)) return text;
    }
  };

  const upload = async (file) => {
    const data = new FormData();
    data.append(PHOTO, file);
    const response = await fetch(endpoint, {
      method: "POST",
      body: data,
      headers: { Accept: "application/json", "X-CSRF-Token": tokenFor(body) },
      redirect: "manual",
    });
    const answer = await response.json().catch(() => ({}));
    if (response.ok && answer.url) return answer.url;

    throw new Error(answer.error ?? editor.dataset.editorUploadFailed);
  };

  const settle = (text, replacement) => {
    const at = body.value.indexOf(text);
    if (at < 0) return;

    body.setRangeText(replacement, at, at + text.length, "preserve");
    changed(body);
    return at;
  };

  const send = (files) => {
    if (files.length === 0) return;

    say("");
    const markers = [];
    for (const file of files) markers.push(marker(file, body.value + markers.join()));
    insertAtCursor(body, markers.join("\n"));
    changed(body);

    files.forEach(async (file, index) => {
      try {
        const url = await upload(file);
        const at = settle(markers[index], `![](${url})`);
        if (at === undefined) return;

        body.focus();
        body.setSelectionRange(at + BRACKET, at + BRACKET);
      } catch (error) {
        settle(markers[index], "");
        say(error instanceof TypeError ? editor.dataset.editorUploadFailed : error.message);
      }
    });
  };

  body.addEventListener("dragover", (event) => {
    if (event.dataTransfer.types.includes("Files")) event.preventDefault();
  });

  body.addEventListener("drop", (event) => {
    const files = [...event.dataTransfer.files];
    if (files.length === 0) return;

    event.preventDefault();
    send(files);
  });

  body.addEventListener("paste", (event) => {
    const files = [...event.clipboardData.files];
    if (files.length === 0 || event.clipboardData.types.includes("text/plain")) return;

    event.preventDefault();
    send(files);
  });

  editor.querySelector("[data-editor-pick]").addEventListener("click", () => picker.click());

  picker.addEventListener("change", () => {
    send([...picker.files]);
    picker.value = "";
  });
}

function changed(body) {
  body.dispatchEvent(new Event("input", { bubbles: true }));
}

function tokenFor(body) {
  return new FormData(body.form ?? undefined).get(TOKEN) ?? "";
}

function insertAtCursor(textarea, snippet) {
  textarea.focus();
  textarea.setRangeText(snippet, textarea.selectionStart, textarea.selectionEnd, "end");
}
