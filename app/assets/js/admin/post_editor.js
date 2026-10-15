import { fresh } from "./fresh.js";
import { slugify } from "./slug.js";

const WORD = /[\p{L}\p{N}]/u;

const ready = new WeakSet();
let finding = false;

export function setupPostEditors() {
  for (const form of fresh(ready, document.querySelectorAll("form[data-post-editor]"))) {
    setupPostEditor(form);
  }
  setupFindLink();
}

function setupFindLink() {
  if (finding) return;

  finding = true;
  document.addEventListener("click", (event) => {
    const button = event.target.closest("[data-find-link]");
    const body = document.querySelector("form[data-post-editor] [data-post-body]");
    if (!button || !body) return;

    button.closest("dialog")?.close();
    findIn(body, button.dataset.findLink);
  });
}

function findIn(body, url) {
  const pane = body.closest("[data-editor-view]");
  const radio = body.closest("[data-markdown-editor]")?.querySelector(`input[value="${pane?.dataset.editorView}"]`);
  if (pane?.hidden && radio) {
    radio.checked = true;
    radio.dispatchEvent(new Event("change"));
  }

  const at = body.value.indexOf(url);
  if (at >= 0) body.setSelectionRange(at, at + url.length);
  body.focus();
}

function setupPostEditor(form) {
  const body = form.querySelector("[data-post-body]");
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

  body.addEventListener("input", renderCounts);
  title.addEventListener("input", renderSlug);
  slug.addEventListener("input", renderSlug);
  publishAt.addEventListener("input", renderSchedule);
  renderSlug();
}

function countWords(text) {
  return (text.match(/\S+/g) ?? []).filter((word) => WORD.test(word)).length;
}

function readMinutes(count, wordsPerMinute) {
  return Math.max(1, Math.round(count / wordsPerMinute));
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
