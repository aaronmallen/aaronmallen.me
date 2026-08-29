const DELAY = 300;
const VIEW = "input[name='view']";

export function setupPostPreviews() {
  for (const form of document.querySelectorAll("form[data-post-editor]")) {
    const preview = form.querySelector("[data-editor-preview]");
    if (preview) setupPostPreview(form, preview);
  }
}

function setupPostPreview(form, preview) {
  const pane = preview.closest("[data-editor-view]");
  let timer;
  let controller;
  let stale = false;

  const refresh = async () => {
    controller?.abort();
    controller = new AbortController();
    const { signal } = controller;

    try {
      const response = await fetch(preview.dataset.editorPreview, {
        method: "POST",
        body: new URLSearchParams(new FormData(form)),
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

  const showing = () => form.querySelector(`${VIEW}:checked`)?.value === pane.dataset.editorView;

  form.addEventListener("input", (event) => {
    if (event.target.matches(VIEW)) return;

    stale = true;
    clearTimeout(timer);
    if (showing()) timer = setTimeout(refresh, DELAY);
  });

  for (const radio of form.querySelectorAll(VIEW)) {
    radio.addEventListener("change", () => {
      clearTimeout(timer);
      if (showing() && stale) refresh();
    });
  }
}
