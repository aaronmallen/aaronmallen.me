import { fresh } from "./fresh.js";

const FIELD = [
  "input:not([type=button], [type=checkbox], [type=color], [type=file], [type=image], [type=radio], [type=range], " +
    "[type=reset], [type=submit])",
  "textarea",
  "select",
  "[contenteditable]:not([contenteditable=false])",
].join(", ");
const MODIFIERS = ["Alt", "AltGraph", "CapsLock", "Control", "Meta", "Shift"];
const OPEN = "[data-key-open]";
const OPEN_KEY = "e";
const ROW = "[data-key-row]";
const ROWS = "[data-key-list] [data-key-row]";
const STEPS = { j: 1, k: -1 };

const chords = [];
const ready = new WeakSet();
let bound = false;
let pending = "";

export function bind(matches, run) {
  chords.push({ matches, run });
}

export function setupKeys() {
  if (!bound) {
    bound = true;
    document.addEventListener("keydown", press);
  }

  for (const trigger of fresh(ready, document.querySelectorAll("[data-key-help-open]"))) {
    trigger.addEventListener("click", () => {
      const help = document.querySelector("[data-key-help]");
      if (help) fillHelp(help);
    });
  }
}

function press(event) {
  if (event.defaultPrevented || event.isComposing || MODIFIERS.includes(event.key)) return;
  if (event.ctrlKey || event.metaKey || event.altKey) return chord(event);

  const prefix = pending;
  pending = "";
  if (quiet(event.target)) return;

  if (!prefix && event.key in STEPS) return step(event, STEPS[event.key]);

  const key = prefix ? `${prefix} ${event.key}` : event.key;
  if (!prefix && waits(key)) {
    pending = key;
    return event.preventDefault();
  }

  const control =
    find(key, event.target) ?? (key === OPEN_KEY ? event.target.closest?.(ROWS)?.querySelector(OPEN) : null);
  if (!control) return;

  event.preventDefault();
  if (control.matches("summary")) control.focus();
  control.click();
}

function chord(event) {
  chords.find(({ matches }) => matches(event))?.run(event);
}

function controls() {
  return [...document.querySelectorAll("[data-key]")];
}

function fillHelp(help) {
  const list = help.querySelector("[data-key-help-list]");
  const template = help.querySelector("[data-key-help-row]");
  const keys = new Map();

  for (const row of help.querySelectorAll("[data-key-help-needs]")) {
    row.hidden = !document.querySelector(row.dataset.keyHelpNeeds);
  }

  for (const control of controls()) {
    if (!keys.has(control.dataset.key)) keys.set(control.dataset.key, control.dataset.keyLabel ?? "");
  }

  for (const added of list.querySelectorAll("[data-key-help-added]")) added.remove();
  list.append(...[...keys].map(([key, label]) => helpRow(template, key, label)));
}

function find(key, target) {
  const matching = controls().filter((control) => control.dataset.key === key);
  const row = target.closest?.(ROWS);

  return matching.find((control) => row?.contains(control)) ?? matching.find((control) => !control.closest(ROW));
}

function helpRow(template, key, label) {
  const row = template.content.firstElementChild.cloneNode(true);
  const keys = row.querySelector("[data-key-help-keys]");

  for (const part of key.split(" ")) {
    const kbd = document.createElement("kbd");
    kbd.className = "kbd";
    kbd.textContent = part;
    keys.append(kbd);
  }

  row.querySelector("[data-key-help-label]").textContent = label;
  return row;
}

function highlight(row) {
  const target = row.querySelector(OPEN) ?? row;
  if (target === row && !row.hasAttribute("tabindex")) row.tabIndex = -1;

  target.focus({ preventScroll: true });
  row.scrollIntoView({ block: "nearest" });
}

function quiet(target) {
  return Boolean(target.closest?.(FIELD)) || document.querySelector("dialog:modal") !== null;
}

function step(event, by) {
  const rows = [...document.querySelectorAll(ROWS)].filter((row) => row.checkVisibility());
  if (rows.length === 0) return;

  event.preventDefault();

  const at = rows.indexOf(document.activeElement?.closest(ROW));
  if (at === -1) return highlight(by > 0 ? rows[0] : rows.at(-1));

  highlight(rows[Math.min(Math.max(at + by, 0), rows.length - 1)]);
}

function waits(key) {
  return controls().some((control) => control.dataset.key.startsWith(`${key} `));
}
