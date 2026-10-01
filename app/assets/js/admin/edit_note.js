const ACCEPT = "accept";

export function setupEditNotes() {
  for (const form of document.querySelectorAll("form[data-post-editor]")) {
    const dialog = form.querySelector("[data-edit-note-dialog]");
    if (dialog) setupEditNote(form, dialog);
  }
}

function setupEditNote(form, dialog) {
  const body = form.querySelector("[data-post-body]");
  const card = form.querySelector("[data-edit-note]");
  const field = card.querySelector("[data-edit-note-field]");
  const note = field.querySelector("textarea");
  if (note.value.trim() !== "" || note.getAttribute("aria-invalid") === "true") return;

  const loaded = lines(body.defaultValue);
  let confirmed = false;

  dialog.querySelector("[data-edit-note-slot]").append(field);
  card.hidden = true;

  dialog.querySelector("[data-edit-note-accept]").addEventListener("click", () => dialog.close(ACCEPT));
  dialog.querySelector("[data-edit-note-decline]").addEventListener("click", () => dialog.close());

  form.addEventListener("submit", (event) => {
    if (confirmed || lines(body.value) === loaded) return;

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
