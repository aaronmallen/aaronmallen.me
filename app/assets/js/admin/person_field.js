export function fillField(field, value) {
  field.value = value;
  field.dataset.personFilled = value;
  field.dispatchEvent(new Event("input", { bubbles: true }));
}

export function typed(field) {
  return field.value.trim() !== "" && field.value !== field.dataset.personFilled;
}
