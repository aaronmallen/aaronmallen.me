import { fresh } from "./fresh.js";

const WORDS = /\S+/g;
const BLANK = /^\s*$/;
const WRITE = "input[type='radio'][value='write']";

const ready = new WeakSet();

export function setupJournals() {
  for (const form of fresh(ready, document.querySelectorAll("form[data-journal-entry]"))) {
    setupJournal(form);
  }

  for (const entry of fresh(ready, document.querySelectorAll("[data-journal-item]"))) {
    setupEntry(entry);
  }
}

function setupEntry(entry) {
  const text = entry.querySelector("[data-journal-text]");
  const actions = entry.querySelector("[data-journal-actions]");
  const edit = entry.querySelector("[data-journal-edit]");
  const form = entry.querySelector("[data-journal-edit-form]");
  const body = form.querySelector("[data-journal-body]");
  const save = form.querySelector("[data-journal-save]");
  const links = entry.querySelector("[data-journal-links]");

  const renderSave = () => {
    save.disabled = BLANK.test(body.value);
  };

  const setEditing = (editing) => {
    text.hidden = editing;
    actions.hidden = editing;
    form.hidden = !editing;
    if (links) links.hidden = !editing;
  };

  edit.addEventListener("click", () => {
    setEditing(true);
    body.focus();
  });

  form.querySelector("[data-journal-cancel]").addEventListener("click", () => {
    body.value = form.dataset.journalSource;
    body.removeAttribute("aria-invalid");
    body.removeAttribute("aria-describedby");
    form.querySelector(".field-error")?.remove();
    body.dispatchEvent(new Event("input", { bubbles: true }));
    showWrite(form);
    setEditing(false);
    edit.focus();
  });

  body.addEventListener("input", renderSave);
}

function showWrite(form) {
  const write = form.querySelector(WRITE);
  if (!write || write.checked) return;

  write.checked = true;
  write.dispatchEvent(new Event("change", { bubbles: true }));
}

function setupJournal(form) {
  const body = form.querySelector("[data-journal-body]");
  const words = form.querySelector("[data-journal-words]");
  const save = form.querySelector("[data-journal-save]");
  const title = form.querySelector(".card-title");
  const date = document.querySelector(`[data-journal-date][form="${form.id}"]`);

  const renderBody = () => {
    const count = (body.value.match(WORDS) ?? []).length;
    const template = count === 1 ? words.dataset.one : words.dataset.other;
    words.textContent = template.replace("%{count}", count);
    save.disabled = BLANK.test(body.value);
  };

  const renderTitle = () => {
    const chosen = date.value;
    title.textContent = chosen === "" || chosen === form.dataset.today ? form.dataset.todayLabel : fullDate(chosen);
  };

  body.addEventListener("input", renderBody);
  date?.addEventListener("input", renderTitle);
  renderBody();
}

function fullDate(value) {
  return new Intl.DateTimeFormat("en-US", {
    timeZone: "UTC",
    weekday: "long",
    month: "long",
    day: "numeric",
    year: "numeric",
  }).format(new Date(`${value}T00:00:00Z`));
}
