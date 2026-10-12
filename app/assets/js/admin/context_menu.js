import { load } from "./in_place.js";
import { copy } from "./record_key.js";
import { showToast } from "./toast.js";

export const MENU = "[data-context-menu]";

const BESIDE = { x: 24, y: 40 };
const CONTROL = "a, input, textarea, select";
const EDGE = 8;
const ITEM = "[data-context-item]";
const LIST = "[role=menu]";
const OPEN = "[data-key-open]";
const ROW = "[data-menu]";
const STEPS = { ArrowDown: 1, ArrowUp: -1 };

let bound = false;
let shown = null;

export function setupContextMenus() {
  if (bound) return;

  bound = true;
  document.addEventListener("contextmenu", pointed);
  document.addEventListener("keydown", keyed);
  document.addEventListener("pointerdown", outside, true);
  document.addEventListener("scroll", outside, true);
  window.addEventListener("resize", () => close());
  window.addEventListener("blur", () => close());
}

function back(list) {
  const trigger = list.previousElementSibling;

  collapse(trigger.closest(LIST));
  focus(trigger);
}

function clicked(event) {
  const item = event.target.closest(ITEM);
  if (!item || item.disabled) return;

  if (item.hasAttribute("aria-haspopup")) return expand(item, event.detail === 0);
  if ("confirmInline" in item.dataset && !("sure" in item.dataset)) {
    event.preventDefault();
    return sure(item);
  }
  if ("copy" in item.dataset) {
    copy(item.dataset.copy, item.dataset.copied);
    return close(true);
  }
  if (item.matches("a")) setTimeout(() => close(true));
}

function close(refocus = false) {
  if (!shown) return;

  const { row, menu } = shown;
  shown = null;
  row.classList.remove("ctx-on");
  if (!menu) return;

  menu.remove();
  if (refocus && row.isConnected) home(row);
  document.dispatchEvent(new Event("close"));
}

function collapse(list, keep = null) {
  for (const open of list.querySelectorAll(`${LIST}:not([hidden])`)) {
    if (open.contains(keep)) continue;

    open.hidden = true;
    open.previousElementSibling.setAttribute("aria-expanded", "false");
  }
}

function expand(trigger, keys) {
  const list = trigger.nextElementSibling;

  collapse(trigger.closest(LIST), list);
  if (list.hidden) {
    const box = trigger.getBoundingClientRect();

    list.hidden = false;
    trigger.setAttribute("aria-expanded", "true");
    place(list, box.right - 2, box.top - 6, box.left + 2);
  }
  if (keys) focus(items(list)[0]);
}

function focus(target) {
  if (!target) return;

  for (const asked of shown.menu.querySelectorAll("[data-sure]")) {
    if (asked !== target) unsure(asked);
  }
  target.focus({ preventScroll: true });
}

function home(row) {
  const target = row.querySelector(OPEN) ?? row;
  if (target === row && !row.hasAttribute("tabindex")) row.tabIndex = -1;

  target.focus({ preventScroll: true });
}

function hovered(event) {
  const item = event.target.closest(ITEM);
  if (!item || item.disabled) return;

  if (item.hasAttribute("aria-haspopup")) expand(item, false);
  else collapse(item.closest(LIST));
  if (document.activeElement !== item) focus(item);
}

function items(list) {
  return [...list.querySelectorAll(ITEM)].filter((item) => item.closest(LIST) === list && !item.disabled);
}

function keyed(event) {
  if (event.key !== "ContextMenu" && !(event.key === "F10" && event.shiftKey)) return;

  const row = event.target.closest?.(ROW);
  if (!row) return;

  const box = row.getBoundingClientRect();
  event.preventDefault();
  open(row, box.left + BESIDE.x, box.top + Math.min(box.height, BESIDE.y), true);
}

function onControl({ target, clientX: x, clientY: y }) {
  const control = target.closest(CONTROL);
  if (!control) return false;

  return [...control.getClientRects()].some(
    (box) => x >= box.left && x <= box.right && y >= box.top && y <= box.bottom,
  );
}

async function open(row, x, y, keys) {
  close();

  const mine = { row, keys, menu: null };
  const url = new URL(row.dataset.menu, window.location.href);
  url.searchParams.set("return_to", window.location.pathname + window.location.search);
  shown = mine;

  const menu = await load(url, MENU).catch(() => null);
  if (shown !== mine) return;
  if (!menu) return close();

  mine.menu = menu;
  menu.addEventListener("click", clicked);
  menu.addEventListener("keydown", press);
  menu.addEventListener("pointerover", hovered);
  menu.addEventListener("submit", submitted);
  document.body.append(menu);
  row.classList.add("ctx-on");
  place(menu, x, y);
  focus(keys ? items(menu)[0] : menu);
}

function outside(event) {
  if (shown && !shown.menu?.contains(event.target)) close();
}

function place(list, x, y, flip = x) {
  const width = list.offsetWidth;
  const height = list.offsetHeight;

  list.style.left = `${x + width > window.innerWidth - EDGE ? Math.max(EDGE, flip - width) : x}px`;
  list.style.top = `${y + height > window.innerHeight - EDGE ? Math.max(EDGE, window.innerHeight - height - EDGE) : y}px`;
}

function pointed(event) {
  if (shown?.menu?.contains(event.target) || (shown?.keys && shown.row.contains(event.target))) {
    return event.preventDefault();
  }

  const row = event.target.closest?.(ROW);
  if (!row || event.shiftKey || onControl(event)) return;

  event.preventDefault();
  open(row, event.clientX, event.clientY, false);
}

function press(event) {
  event.stopPropagation();

  const list = event.target.closest(LIST);
  const item = event.target.closest(ITEM);
  const typing = event.target.matches("input");

  if (event.key in STEPS || event.key === "Tab") {
    event.preventDefault();
    return step(list, item, STEPS[event.key] ?? (event.shiftKey ? -1 : 1));
  }
  if (event.key === "Escape") {
    event.preventDefault();
    return list === shown.menu ? close(true) : back(list);
  }
  if (typing) return;

  if (event.key === "ArrowLeft" && list !== shown.menu) {
    event.preventDefault();
    back(list);
  } else if (event.key === "ArrowRight" && item?.hasAttribute("aria-haspopup")) {
    event.preventDefault();
    expand(item, true);
  } else if ((event.key === "Enter" || event.key === " ") && item) {
    event.preventDefault();
    item.click();
  }
}

function step(list, item, by) {
  const all = items(list);
  if (all.length === 0) return;

  const at = all.indexOf(item);
  focus(all[at === -1 ? (by > 0 ? 0 : all.length - 1) : (at + by + all.length) % all.length]);
}

function submitted(event) {
  const field = event.target.querySelector("input[data-invalid]");
  if (field && !field.value.trim()) return event.preventDefault();
  if (field && !field.checkValidity()) {
    event.preventDefault();
    return showToast(field.dataset.invalid, { failed: true });
  }

  setTimeout(() => close(true));
}

function sure(item) {
  const label = item.querySelector(".ctx-label");

  item.dataset.sure = label.textContent;
  label.textContent = item.dataset.confirmInline;
}

function unsure(item) {
  item.querySelector(".ctx-label").textContent = item.dataset.sure;
  delete item.dataset.sure;
}
