export function fillField(field, value) {
  field.value = value;
  field.dispatchEvent(new Event("input", { bubbles: true }));
}
