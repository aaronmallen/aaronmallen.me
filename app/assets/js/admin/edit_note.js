const ACCEPT = "accept";

export function setupEditNotes() {
  for (const dialog of document.querySelectorAll("[data-edit-note-dialog]")) {
    const form = dialog.closest("form");
    if (form) setupEditNote(form, dialog);
  }
}

function setupEditNote(form, dialog) {
  const watched = [...form.querySelectorAll("[data-edit-note-watch]")];
  const card = form.querySelector("[data-edit-note]");
  const field = card.querySelector("[data-edit-note-field]");
  const note = field.querySelector("textarea");
  if (note.value.trim() !== "" || note.getAttribute("aria-invalid") === "true") return;

  const loaded = watched.map((input) => lines(input.defaultValue));
  const changed = () => watched.some((input, index) => lines(input.value) !== loaded[index]);
  let confirmed = false;

  dialog.querySelector("[data-edit-note-slot]").append(field);
  card.hidden = true;

  dialog.querySelector("[data-edit-note-accept]").addEventListener("click", () => dialog.close(ACCEPT));
  dialog.querySelector("[data-edit-note-decline]").addEventListener("click", () => dialog.close());

  form.addEventListener("submit", (event) => {
    if (confirmed || !changed()) return;

    event.preventDefault();
    ask(dialog, note, event.submitter, () => {
      confirmed = true;
      form.requestSubmit(event.submitter);
    });
  });
}

function ask(dialog, note, submitter, accept) {
  const opener = submitter ?? document.activeElement;

  dialog.returnValue = "";
  dialog.addEventListener(
    "close",
    () => {
      dialog.hidden = true;
      if (dialog.returnValue === ACCEPT) return accept();

      opener?.focus();
    },
    { once: true },
  );

  dialog.hidden = false;
  dialog.showModal();
  note.focus();
}

function lines(text) {
  return text.replace(/\r\n?/g, "\n");
}
