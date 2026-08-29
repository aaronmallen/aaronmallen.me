const WORDS = /\S+/g;
const BLANK = /^\s*$/;

export function setupJournals() {
  for (const form of document.querySelectorAll("form[data-journal-entry]")) {
    setupJournal(form);
  }

  for (const entry of document.querySelectorAll("[data-journal-item]")) {
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
  const remove = entry.querySelector("[data-journal-delete]");

  const renderSave = () => {
    save.disabled = BLANK.test(body.value);
  };

  const setEditing = (editing) => {
    text.hidden = editing;
    actions.hidden = editing;
    form.hidden = !editing;
  };

  edit.addEventListener("click", () => {
    setEditing(true);
    body.focus();
  });

  form.querySelector("[data-journal-cancel]").addEventListener("click", () => {
    body.value = text.textContent;
    body.removeAttribute("aria-invalid");
    body.removeAttribute("aria-describedby");
    form.querySelector(".field-error")?.remove();
    renderSave();
    setEditing(false);
    edit.focus();
  });

  body.addEventListener("input", renderSave);

  remove.querySelector("[data-journal-delete-button]").addEventListener("click", () => {
    if (window.confirm(remove.dataset.confirm)) remove.submit();
  });
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
