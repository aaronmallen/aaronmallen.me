import { ask } from "./dialog.js";

const armed = new WeakMap();

export function setupEditNotes() {
  for (const dialog of document.querySelectorAll("[data-edit-note-dialog]")) {
    const form = dialog.closest("form");
    if (form) setupEditNote(form, dialog);
  }
}

function setupEditNote(form, dialog) {
  const watched = [...form.querySelectorAll("[data-edit-note-watch]")];
  const card = form.querySelector("[data-edit-note]");
  const field = form.querySelector("[data-edit-note-field]");
  const note = field.querySelector("textarea");
  const known = armed.has(form);

  if (!known) armed.set(form, note.value.trim() === "" && note.getAttribute("aria-invalid") !== "true");
  if (!armed.get(form)) return;

  const slot = dialog.querySelector("[data-edit-note-slot]");
  if (field.parentElement !== slot) slot.append(field);
  card.hidden = true;

  if (known) return;

  const loaded = watched.map((input) => lines(input.defaultValue));
  const changed = () => watched.some((input, index) => lines(input.value) !== loaded[index]);
  let confirmed = false;

  form.addEventListener("submit", (event) => {
    if (confirmed || !changed()) return;

    event.preventDefault();
    ask(dialog, {
      opener: event.submitter,
      focus: note,
      refocus: "decline",
      accept: () => {
        confirmed = true;
        form.requestSubmit(event.submitter);
      },
    });
  });
}

function lines(text) {
  return text.replace(/\r\n?/g, "\n");
}
