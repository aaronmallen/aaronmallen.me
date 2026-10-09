import { fresh } from "./fresh.js";

const BOX = "input[data-social-target]";
const CHIPS_SHOWN = 3;

const ready = new WeakSet();

export function setupAccountPickers() {
  const pickers = document.querySelectorAll("[data-social-picker]");
  for (const picker of fresh(ready, pickers)) setupAccountPicker(picker);
  for (const picker of pickers) render(picker);
}

function setupAccountPicker(picker) {
  const menu = picker.querySelector("details");
  const find = picker.querySelector("[data-social-find]");
  const boxes = [...picker.querySelectorAll(BOX)];
  const box = (id) => boxes.find((found) => found.value === id);
  const update = () => render(picker);

  const pick = (targets, checked) => {
    for (const target of targets) target.checked = checked;
    targets[0]?.dispatchEvent(new Event("change", { bubbles: true }));
  };

  const close = () => {
    menu.open = false;
  };

  picker.addEventListener("click", (event) => {
    const chip = event.target.closest(".compose-chip-remove");
    if (chip) pick([box(chip.closest("[data-social-chip]").dataset.socialChip)], false);
    if (event.target.closest("[data-social-more]")) menu.open = true;
    if (event.target.closest("[data-social-everywhere]")) pick(boxes, true);
    if (event.target.closest("[data-social-clear]")) pick(boxes, false);

    const group = event.target.closest("[data-social-group]");
    if (group) {
      const rows = shownBoxes(group.closest(".compose-account-group"));
      pick(rows, !rows.every((target) => target.checked));
    }
  });

  picker.addEventListener("change", update);
  find?.addEventListener("input", update);
  find?.addEventListener("keydown", (event) => {
    if (event.key === "Enter") event.preventDefault();
  });
  menu.addEventListener("toggle", () => {
    if (menu.open) find?.focus();
  });

  document.addEventListener("click", (event) => {
    if (menu.open && !picker.contains(event.target)) close();
  });
  document.addEventListener("keydown", (event) => {
    if (event.key !== "Escape" || !menu.open) return;

    close();
    menu.querySelector("summary").focus();
  });
}

function render(picker) {
  const boxes = [...picker.querySelectorAll(BOX)];
  const find = picker.querySelector("[data-social-find]");
  if (find) find.hidden = false;

  renderChips(picker, boxes);
  renderMenu(picker, find?.value ?? "");
  const all = boxes.every((target) => target.checked);
  picker.querySelector("[data-social-everywhere]").hidden = all;
  picker.querySelector("[data-social-clear]").hidden = !all;
}

function renderChips(picker, boxes) {
  const checked = new Set(boxes.filter((target) => target.checked).map((target) => target.value));
  const chips = [...picker.querySelectorAll("[data-social-chip]")];
  const picked = chips.filter((chip) => checked.has(chip.dataset.socialChip));
  const handles = picked.map((chip) => chip.dataset.handle);

  for (const chip of chips) chip.hidden = !picked.slice(0, CHIPS_SHOWN).includes(chip);
  for (const chip of picked) {
    const host = chip.querySelector(".compose-chip-host");
    if (host) host.hidden = handles.indexOf(chip.dataset.handle) === handles.lastIndexOf(chip.dataset.handle);
  }

  const more = picker.querySelector("[data-social-more]");
  more.hidden = picked.length <= CHIPS_SHOWN;
  more.textContent = more.dataset.template.replace("%{count}", picked.length - CHIPS_SHOWN);
  picker.querySelector("[data-social-empty]").hidden = picked.length > 0;
}

function renderMenu(picker, query) {
  const wanted = query.trim().toLowerCase().replace(/^@/, "");

  for (const row of picker.querySelectorAll(".compose-account")) {
    const handle = row.querySelector(".compose-account-handle").textContent.toLowerCase();
    row.hidden = !handle.includes(wanted);
  }

  for (const group of picker.querySelectorAll(".compose-account-group")) {
    const rows = shownBoxes(group);
    const link = group.querySelector("[data-social-group]");
    group.hidden = rows.length === 0;
    link.hidden = rows.length < 2;
    link.textContent = rows.every((target) => target.checked)
      ? link.dataset.none
      : link.dataset.all.replace("%{count}", rows.length);
  }

  const none = picker.querySelector("[data-social-none]");
  none.hidden = picker.querySelector(".compose-account:not([hidden])") !== null;
  none.textContent = none.dataset.template.replace("%{query}", query.trim());
}

function shownBoxes(group) {
  return [...group.querySelectorAll(`.compose-account:not([hidden]) ${BOX}`)];
}
