const FORM = "contact-form";

export function setupContactErrors() {
  const form = document.getElementById(FORM);
  if (!form) return;

  const slotFor = (field) => form.querySelector(`.f-e[data-for="${field.id}"]`);

  const messageFor = (slot, validity) =>
    validity.typeMismatch && slot.dataset.format ? slot.dataset.format : slot.dataset.blank;

  const show = (field) => {
    const slot = slotFor(field);
    if (!slot) return;

    slot.textContent = messageFor(slot, field.validity);
    slot.hidden = false;
    field.setAttribute("aria-invalid", "true");
    field.setAttribute("aria-describedby", slot.id);
  };

  const clear = (field) => {
    const slot = slotFor(field);
    if (!slot) return;

    slot.hidden = true;
    slot.textContent = "";
    field.removeAttribute("aria-invalid");
    field.removeAttribute("aria-describedby");
  };

  for (const field of form.querySelectorAll(".f-i")) {
    field.addEventListener("invalid", (event) => {
      event.preventDefault();
      show(field);
      const firstInvalid = form.querySelector(":invalid") === field;
      if (firstInvalid) field.focus();
    });

    field.addEventListener("input", () => {
      if (field.validity.valid) clear(field);
    });
  }
}
