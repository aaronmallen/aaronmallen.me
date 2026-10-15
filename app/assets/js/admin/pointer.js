const ENDS = ["pointerup", "pointercancel"];

export const GHOST_OFFSET = 14;
export const HOLD = 300;
export const SLOP = 6;

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

export function waitForDrag(press, start) {
  const touch = press.pointerType === "touch";
  let latest = press;

  const stop = () => {
    clearTimeout(timer);
    document.removeEventListener("pointermove", moved);
    for (const type of ENDS) document.removeEventListener(type, stop);
  };

  const begin = () => {
    stop();
    start(latest);
  };

  const moved = (event) => {
    if (event.pointerId !== press.pointerId) return;

    latest = event;
    if (Math.hypot(event.clientX - press.clientX, event.clientY - press.clientY) <= SLOP) return;
    if (touch) return stop();

    begin();
  };

  const timer = touch ? setTimeout(begin, HOLD) : null;
  document.addEventListener("pointermove", moved);
  for (const type of ENDS) document.addEventListener(type, stop);
}

export function menu(event) {
  event.preventDefault();
  event.stopPropagation();
}

export function still(event) {
  if (event.cancelable) event.preventDefault();
}

export function swallowClick() {
  const swallow = (event) => menu(event);

  document.addEventListener("click", swallow, true);
  setTimeout(() => document.removeEventListener("click", swallow, true));
}
