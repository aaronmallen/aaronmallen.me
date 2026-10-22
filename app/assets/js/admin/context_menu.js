import { clear, picks } from "./bulk.js";
import { focusField, openDialog } from "./dialog.js";
import { load } from "./in_place.js";
import { ARROWS } from "./listbox.js";
import { morphed, release } from "./live.js";
import { setupMenuSuggest } from "./menu_suggest.js";
import { copy } from "./record_key.js";
import { showToast } from "./toast.js";

export const MENU = "[data-context-menu]";

const BESIDE = { x: 24, y: 40 };
const CONTROL = "a, input, textarea, select";
const EDGE = 8;
const ITEM = "[data-context-item]";
const LIST = "[role=menu]";
const MORE = "[data-menu-more]";
const OPEN = "[data-key-open]";
const PICK = "input[name='ids[]'][form]";
const ROW = "[data-menu], [data-key-row]";
const SUB = "[aria-haspopup=menu]";

let shown = null;

export function bootContextMenus() {
  document.addEventListener("click", more);
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

  if (item.matches(SUB)) return expand(item, event.detail === 0);
  if ("confirmInline" in item.dataset && !("sure" in item.dataset)) {
    event.preventDefault();
    return sure(item);
  }
  if ("dialogOpen" in item.dataset) {
    event.preventDefault();
    return summon(item);
  }
  if ("bulkClear" in item.dataset) {
    clear(document.getElementById(item.dataset.bulkClear));
    return close(true);
  }
  if ("copy" in item.dataset) {
    copy(item.dataset.copy, item.dataset.copied);
    return close(true);
  }
  if ("menuClick" in item.dataset) {
    close(true);
    return document.getElementById(item.dataset.menuClick)?.click();
  }
  if (item.matches("a")) setTimeout(() => close(true));
}

function close(refocus = false) {
  if (!shown) return;

  const { row, from, menu } = shown;
  shown = null;
  row.classList.remove("ctx-on");
  if (from !== row) from.ariaExpanded = "false";
  if (!menu) return;

  menu.remove();
  if (refocus && from.isConnected) home(from);
  release();
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

function fit(list) {
  const top = window.innerHeight - list.offsetHeight - EDGE;

  if (list.getBoundingClientRect().top > top) list.style.top = `${Math.max(EDGE, top)}px`;
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
  if (!item || item.disabled || typing()) return;

  if (item.matches(SUB)) expand(item, false);
  else collapse(item.closest(LIST));
  if (document.activeElement !== item) focus(item);
}

function typing() {
  const field = document.activeElement;

  return field.matches("input") && field.value !== "" && shown.menu.contains(field);
}

function items(list) {
  return [...list.querySelectorAll(ITEM)].filter((item) => item.closest(LIST) === list && !item.disabled);
}

function keyed(event) {
  if (event.key !== "ContextMenu" && !(event.key === "F10" && event.shiftKey)) return;

  const row = event.target.closest?.(ROW);
  const url = row && source(row);
  if (!url) return;

  const box = row.getBoundingClientRect();
  event.preventDefault();
  open(row, url, box.left + BESIDE.x, box.top + Math.min(box.height, BESIDE.y), true);
}

function more(event) {
  const button = event.target.closest?.(MORE);
  const row = button?.closest(ROW);
  const url = row && source(row);
  if (!url) return;

  const box = button.getBoundingClientRect();
  event.preventDefault();
  open(row, url, box.left, box.bottom + 4, event.detail === 0, { from: button, flip: box.right });
}

function onControl({ target, clientX: x, clientY: y }, row) {
  const control = target.closest(CONTROL);
  if (!control || control === row) return false;

  return [...control.getClientRects()].some(
    (box) => x >= box.left && x <= box.right && y >= box.top && y <= box.bottom,
  );
}

async function open(row, url, x, y, keys, { from = row, flip = x } = {}) {
  close();

  const mine = { row, from, keys, menu: null };
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
  setupMenuSuggest(menu, fit);
  (row.closest("dialog[open]") ?? document.body).append(menu);
  row.classList.add("ctx-on");
  if (from !== row) from.ariaExpanded = "true";
  place(menu, x, y, flip);
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
  if (!row || event.shiftKey || onControl(event, row)) return;

  const url = source(row);
  if (!url) return;

  event.preventDefault();
  open(row, url, event.clientX, event.clientY, false);
}

function press(event) {
  event.stopPropagation();

  const list = event.target.closest(LIST);
  const item = event.target.closest(ITEM);
  const typing = event.target.matches("input");

  if (event.key in ARROWS || event.key === "Tab") {
    event.preventDefault();
    return step(list, item, ARROWS[event.key] ?? (event.shiftKey ? -1 : 1));
  }
  if (event.key === "Escape") {
    event.preventDefault();
    return list === shown.menu ? close(true) : back(list);
  }
  if (typing) return;

  if (event.key === "ArrowLeft" && list !== shown.menu) {
    event.preventDefault();
    back(list);
  } else if (event.key === "ArrowRight" && item?.matches(SUB)) {
    event.preventDefault();
    expand(item, true);
  } else if ((event.key === "Enter" || event.key === " ") && item) {
    event.preventDefault();
    item.click();
  }
}

function reveal(found) {
  if (!found || found.matches("dialog")) return false;

  const toggle = found.matches("input[type=checkbox]");
  const target = toggle ? found : found.querySelector("details");
  if (!target) return false;

  if (toggle) target.checked = true;
  else target.open = true;
  found.scrollIntoView({ block: "nearest" });

  const root = toggle ? target.parentElement.querySelector("form") : target;
  if (root) focusField(root);
  return true;
}

function source(row) {
  const form = row.querySelector(PICK)?.form;
  const picked = form?.dataset.bulkMenu ? picks(form).filter((pick) => pick.checked) : [];

  if (picked.length > 1 && picked.some((pick) => row.contains(pick))) {
    const url = new URL(form.dataset.bulkMenu, window.location.href);
    for (const pick of picked) url.searchParams.append("ids[]", pick.value);
    return url;
  }
  return row.dataset.menu ? new URL(row.dataset.menu, window.location.href) : null;
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

function summon(item) {
  const id = item.dataset.dialogOpen;
  const carried = shown.menu.querySelector(`dialog[id="${id}"]`);

  close();
  if (carried) {
    for (const old of document.querySelectorAll(`dialog[id="${id}"]`)) old.remove();
    document.querySelector("main").append(carried);
    morphed();
  }
  if (reveal(document.getElementById(id))) return;
  if (!openDialog(id)) window.location.assign(item.href);
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
