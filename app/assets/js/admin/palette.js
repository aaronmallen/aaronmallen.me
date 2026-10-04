import { openDialog } from "./dialog.js";
import { bind } from "./keys.js";

const COUNT = "{count}";
const DELAY = 150;
const FOUND = "[data-palette-found]";
const OPTION = "[data-palette-option]";
const SHOWN = "[data-palette-option]:not([hidden])";
const SLASH_CODES = ["Slash", "NumpadDivide"];

export function setupPalette() {
  const dialog = document.querySelector("[data-palette]");

  if (dialog) setupDialog(dialog);
}

function setupDialog(dialog) {
  const query = dialog.querySelector("[data-palette-query]");
  const list = dialog.querySelector("[data-palette-list]");
  const status = dialog.querySelector("[data-palette-status]");
  const groups = [...dialog.querySelectorAll("[data-palette-group]")];
  const kinds = new Map(
    [...dialog.querySelectorAll("[data-palette-kind]")].map((group) => [group.dataset.paletteKind, group]),
  );
  let options = [...dialog.querySelectorAll(OPTION)];
  let asked = "";
  let controller = null;
  let timer = null;

  const shown = () => options.filter((option) => !option.hidden);
  const active = () => options.find((option) => option.getAttribute("aria-selected") === "true");

  const select = (option) => {
    for (const other of options) other.setAttribute("aria-selected", String(other === option));

    if (!option) return query.removeAttribute("aria-activedescendant");

    query.setAttribute("aria-activedescendant", option.id);
    option.scrollIntoView({ block: "nearest" });
  };

  const announce = (count) => {
    const template = count === 1 ? status.dataset.paletteResultsOne : status.dataset.paletteResultsOther;
    status.textContent = template.replace(COUNT, String(count));
  };

  const filter = () => {
    const text = query.value.trim().toLowerCase();

    for (const option of options) option.hidden = !matches(option, text);

    for (const group of groups) group.hidden = !group.querySelector(SHOWN);

    const visible = shown();
    announce(visible.length);
    select(visible[0]);
  };

  const move = (step) => {
    const visible = shown();
    if (visible.length === 0) return;

    const at = visible.indexOf(active());
    select(visible[Math.min(Math.max(at + step, 0), visible.length - 1)]);
  };

  const run = () => {
    const option = active();
    if (!option) return;

    const target = option.dataset.paletteDialog;
    if (!target) return window.location.assign(option.dataset.paletteHref);

    dialog.close();
    if (!openDialog(target)) window.location.assign(option.dataset.paletteHref);
  };

  const show = (found) => {
    for (const row of dialog.querySelectorAll(FOUND)) row.remove();
    for (const { kind, hits } of found) kinds.get(kind)?.append(...hits.map((hit) => foundRow(kinds.get(kind), hit)));

    options = [...dialog.querySelectorAll(OPTION)];
    filter();
  };

  const stop = () => {
    clearTimeout(timer);
    controller?.abort();
    controller = null;
  };

  const ask = async (text) => {
    controller = new AbortController();
    const { signal } = controller;

    try {
      const found = await fetchFound(dialog.dataset.paletteSearch, text, signal);
      if (!signal.aborted) show(found);
    } catch {
      if (!signal.aborted) asked = "";
    }
  };

  const search = () => {
    const text = query.value.trim();
    if (text === asked) return;

    stop();
    asked = text;
    if (text === "") return show([]);

    timer = setTimeout(() => ask(text), DELAY);
  };

  const open = () => {
    if (dialog.open) return;

    query.value = "";
    stop();
    asked = "";
    show([]);
    dialog.showModal();
    query.focus();
  };

  for (const trigger of document.querySelectorAll("[data-palette-open]")) {
    trigger.addEventListener("click", open);
  }

  bind(opens, (event) => {
    if (dialog.open) return;

    event.preventDefault();
    open();
  });

  query.addEventListener("input", () => {
    filter();
    search();
  });
  query.addEventListener("keydown", (event) => steer(event, { move, run, select, shown }));

  list.addEventListener("click", (event) => {
    const option = event.target.closest(OPTION);
    if (!option) return;

    select(option);
    run();
  });

  list.addEventListener("mousemove", (event) => {
    const option = event.target.closest(OPTION);
    if (option && option !== active()) select(option);
  });

  dialog.addEventListener("click", (event) => {
    if (event.target === dialog) dialog.close();
  });

  dialog.addEventListener("close", stop);

  filter();
}

async function fetchFound(route, text, signal) {
  const response = await fetch(`${route}?${new URLSearchParams({ q: text })}`, {
    headers: { Accept: "application/json" },
    redirect: "manual",
    signal,
  });
  if (!response.ok) throw new Error(`palette search answered ${response.status}`);

  const { groups } = await response.json();

  return groups;
}

function foundRow(group, { id, title, match, date, href }) {
  const row = group.querySelector("[data-palette-found-row]").content.firstElementChild.cloneNode(true);

  row.id = `command-palette-${group.dataset.paletteKind}-${id}`;
  row.dataset.paletteHref = href;
  row.querySelector(".pal-r-label").textContent = title;
  row.querySelector(".pal-r-match").textContent = match;
  row.querySelector(".pal-r-sub").textContent = date;

  return row;
}

function matches(option, text) {
  if (option.hasAttribute("data-palette-found")) return text !== "";

  return text === "" || option.dataset.paletteText.includes(text);
}

function opens(event) {
  return (event.metaKey || event.ctrlKey) && (event.key === "/" || SLASH_CODES.includes(event.code));
}

function steer(event, { move, run, select, shown }) {
  const steps = { ArrowDown: 1, ArrowUp: -1 };

  if (event.key in steps) move(steps[event.key]);
  else if (event.key === "Home") select(shown()[0]);
  else if (event.key === "End") select(shown().at(-1));
  else if (event.key === "Enter") run();
  else return;

  event.preventDefault();
}
