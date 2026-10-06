const ENDS = ["pointerup", "pointercancel"];

export function followPointer(press, { element, dragging, move, end }) {
  if (!press.isPrimary || press.button !== 0) return false;

  const mine = (other) => other.pointerId === press.pointerId;

  const moved = (event) => {
    if (mine(event)) move(event);
  };

  const ended = (event) => {
    if (!mine(event)) return;

    document.removeEventListener("pointermove", moved);
    for (const type of ENDS) document.removeEventListener(type, ended);
    element.classList.remove(dragging);
    end(event, event.type === "pointercancel");
  };

  press.preventDefault();
  element.classList.add(dragging);
  document.addEventListener("pointermove", moved);
  for (const type of ENDS) document.addEventListener(type, ended);
  return true;
}
