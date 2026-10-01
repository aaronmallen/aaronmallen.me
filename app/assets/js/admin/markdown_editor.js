const DELAY = 300;
const EDITOR = "[data-markdown-editor]";
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
  let timer;
  let controller;
  let stale = !preview.hasChildNodes();

  const payload = () => {
    const data = new FormData(body.form ?? undefined);
    if (whole) return new URLSearchParams(data);

    return new URLSearchParams({ [TOKEN]: data.get(TOKEN) ?? "", markdown: body.value });
  };

  const refresh = async () => {
    controller?.abort();
    controller = new AbortController();
    const { signal } = controller;

    try {
      const response = await fetch(preview.dataset.editorPreview, {
        method: "POST",
        body: payload(),
        redirect: "manual",
        signal,
      });
      if (!response.ok) return;

      const html = await response.text();
      if (signal.aborted) return;

      preview.innerHTML = html;
      stale = false;
    } catch (error) {
      if (error.name !== "AbortError") throw error;
    }
  };

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
      body.dispatchEvent(new Event("input", { bubbles: true }));
    });
  }

  for (const radio of radios) {
    radio.addEventListener("change", () => {
      renderView();
      clearTimeout(timer);
      if (showing() && stale) refresh();
    });
  }

  (whole && body.form ? body.form : body).addEventListener("input", (event) => {
    if (event.target.type === "radio" && event.target.closest(EDITOR)) return;

    stale = true;
    clearTimeout(timer);
    if (showing()) timer = setTimeout(refresh, DELAY);
  });

  renderView();
}

function insertAtCursor(textarea, snippet) {
  textarea.focus();
  textarea.setRangeText(snippet, textarea.selectionStart, textarea.selectionEnd, "end");
}
