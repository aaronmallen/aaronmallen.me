const CHECKED_VIEW = "input[name='view']:checked";
const WORD = /[\p{L}\p{N}]/u;

export function setupPostEditors() {
  for (const form of document.querySelectorAll("form[data-post-editor]")) {
    setupPostEditor(form);
  }
}

function setupPostEditor(form) {
  const body = form.querySelector("[data-editor-body]");
  const title = form.querySelector("[data-editor-title]");
  const slug = form.querySelector("[data-editor-slug]");
  const publishAt = form.querySelector("[data-editor-publish-at]");
  const path = form.querySelector("[data-editor-path]");
  const words = form.querySelector("[data-editor-words]");
  const readTime = form.querySelector("[data-editor-read-time]");

  const renderCounts = () => {
    const count = countWords(body.value);
    const template = count === 1 ? words.dataset.one : words.dataset.other;
    words.textContent = template.replace("%{count}", count);
    readTime.textContent = readTime.dataset.editorReadTime.replace(
      "%{count}",
      readMinutes(count, Number(readTime.dataset.wordsPerMinute)),
    );
  };

  const renderSlug = () => {
    const titleSlug = slugify(title.value);
    slug.placeholder = titleSlug;
    path.textContent = path.dataset.editorPath + (slug.value.trim() || titleSlug);
  };

  const renderSchedule = () => {
    const later = publishAt.value !== "" && publishAt.value.slice(0, 16) > wallClock(form.dataset.timeZone);
    for (const element of form.querySelectorAll("[data-editor-now]")) element.hidden = later;
    for (const element of form.querySelectorAll("[data-editor-later]")) element.hidden = !later;
  };

  const renderView = () => {
    const view = form.querySelector(CHECKED_VIEW)?.value;
    if (!view) return;

    for (const panel of form.querySelectorAll("[data-editor-view]")) {
      panel.hidden = panel.dataset.editorView !== view;
    }
  };

  for (const button of form.querySelectorAll("[data-snippet]")) {
    button.addEventListener("click", () => {
      insertAtCursor(body, button.dataset.snippet);
      body.dispatchEvent(new Event("input", { bubbles: true }));
    });
  }

  body.addEventListener("input", renderCounts);
  title.addEventListener("input", renderSlug);
  slug.addEventListener("input", renderSlug);
  publishAt.addEventListener("input", renderSchedule);
  form.addEventListener("change", renderView);
  renderSlug();
  renderView();
}

function countWords(text) {
  return (text.match(/\S+/g) ?? []).filter((word) => WORD.test(word)).length;
}

function insertAtCursor(textarea, snippet) {
  textarea.focus();
  textarea.setRangeText(snippet, textarea.selectionStart, textarea.selectionEnd, "end");
}

function readMinutes(count, wordsPerMinute) {
  return Math.max(1, Math.round(count / wordsPerMinute));
}

function slugify(text) {
  return text
    .normalize("NFKD")
    .replace(/\p{M}/gu, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

function wallClock(timeZone) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(new Date());
  const part = (type) => parts.find((each) => each.type === type).value;

  return `${part("year")}-${part("month")}-${part("day")}T${part("hour")}:${part("minute")}`;
}
