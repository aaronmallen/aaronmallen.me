import { openDialog, showDialog } from "./dialog.js";
import { json, setupFetch } from "./fetching.js";
import { fresh } from "./fresh.js";
import { bind } from "./keys.js";
import { countText, setupListbox } from "./listbox.js";

const ACCEPT = { Accept: "application/json" };
const DELAY = 150;
const FOUND = "[data-palette-found]";
const NO_TASK = "no_task";
const OPTION = "[data-palette-option]";
const SHOWN = "[data-palette-option]:not([hidden])";
const SLASH_CODES = ["Slash", "NumpadDivide"];
const TASK = "[data-task-read]";
const TITLE = "{title}";

const ready = new WeakSet();
let bound = false;
let palette = null;

export function setupPalette() {
  for (const dialog of fresh(ready, document.querySelectorAll("[data-palette]"))) {
    palette = { dialog, open: setupDialog(dialog) };
  }

  for (const trigger of fresh(ready, document.querySelectorAll("[data-palette-open]"))) {
    trigger.addEventListener("click", () => palette?.open());
  }

  if (bound) return;

  bound = true;
  bind(opens, (event) => {
    if (!palette || palette.dialog.open) return;

    event.preventDefault();
    palette.open();
  });
}

function setupDialog(dialog) {
  const query = dialog.querySelector("[data-palette-query]");
  const list = dialog.querySelector("[data-palette-list]");
  const status = dialog.querySelector("[data-palette-status]");
  const groups = [...dialog.querySelectorAll("[data-palette-group]")];
  const kinds = new Map(
    [...dialog.querySelectorAll("[data-palette-kind]")].map((group) => [group.dataset.paletteKind, group]),
  );
  const sources = [...dialog.querySelectorAll("[data-palette-from]")];
  const all = dialog.querySelector("[data-palette-all]");
  const views = dialog.querySelector("[data-palette-views]");
  const filled = new Set();
  let options = [];
  let task = null;
  let asked = "";

  const shown = () => options.filter((option) => !option.hidden);

  const { active, select, step } = setupListbox({
    list,
    owner: () => query,
    choice: OPTION,
    options: () => options,
    shown,
    choose: (option) => {
      select(option);
      run();
    },
  });

  const filter = () => {
    const text = query.value.trim().toLowerCase();

    if (all) all.dataset.paletteHref = searchUrl(all.dataset.paletteAll, query.value.trim());

    for (const option of options) option.hidden = !matches(option, text) || !applies(option, task);

    for (const group of groups) group.hidden = !group.querySelector(SHOWN);

    const visible = shown();
    status.textContent = countText(status, "paletteResults", visible.filter((option) => option !== all).length);
    select(visible[0]);
  };

  const rebuild = () => {
    options = [...dialog.querySelectorAll(OPTION)];
    filter();
  };

  const run = () => {
    const option = active();
    if (!option) return;

    if (option.hasAttribute("data-palette-post")) return post(option, dialog.dataset.paletteToken);

    const target = option.dataset.paletteDialog;
    if (!target) return window.location.assign(option.dataset.paletteHref);

    dialog.close();
    if (!openDialog(target)) window.location.assign(option.dataset.paletteHref);
  };

  const show = (found) => {
    for (const row of dialog.querySelectorAll(FOUND)) row.remove();
    for (const { kind, hits } of found) kinds.get(kind)?.append(...hits.map((hit) => foundRow(kinds.get(kind), hit)));

    rebuild();
  };

  const load = (holder, url, place) => {
    if (filled.has(holder)) return;

    filled.add(holder);
    fetchJSON(url)
      .then(({ rows }) => {
        place(rows);
        rebuild();
      })
      .catch(() => filled.delete(holder));
  };

  const fill = () => {
    for (const source of sources) {
      load(source, source.dataset.paletteFrom, (rows) => source.after(...rows.map((row) => actionRow(source, row))));
    }
  };

  const fillViews = () => {
    if (views)
      load(views, views.dataset.paletteViews, (rows) => views.append(...rows.map((row) => viewRow(views, row))));
  };

  const finder = setupFetch({
    delay: DELAY,
    request: (text) => ({ url: searchUrl(dialog.dataset.paletteSearch, text), headers: ACCEPT, redirect: "manual" }),
    read: json,
    done: ({ groups }) => show(groups),
    failed: () => {
      asked = "";
    },
  });

  const search = () => {
    const text = query.value.trim();
    if (text === asked) return;

    finder.stop();
    asked = text;
    if (text === "") return show([]);

    finder.later(text);
  };

  const open = () => {
    if (dialog.open) return;

    query.value = "";
    task = taskOnScreen();
    aim(options, task);
    if (!task) fill();
    fillViews();
    finder.stop();
    asked = "";
    show([]);
    showDialog(dialog);
    query.focus();
  };

  query.addEventListener("input", () => {
    filter();
    search();
  });
  query.addEventListener("keydown", (event) => steer(event, { run, select, shown, step }));

  dialog.addEventListener("close", finder.stop);
  document.addEventListener("admin:morphed", () => filled.clear());

  rebuild();
  return open;
}

function actionRow(source, { id, title, href }) {
  const row = source.content.firstElementChild.cloneNode(true);
  const label = row.querySelector(".pal-r-label");

  row.id = `${row.id}-${id}`;
  row.dataset.paletteHref = href;
  row.dataset.paletteText = row.dataset.paletteText.replace(TITLE, () => title.toLowerCase());
  label.textContent = label.textContent.replace(TITLE, () => title);

  return row;
}

function act(task, needs) {
  return task?.querySelector(`[data-task-act="${needs}"]`)?.getAttribute("action") ?? "";
}

function aim(options, task) {
  for (const option of options) {
    const needs = option.dataset.paletteNeeds;
    if (needs && needs !== NO_TASK) option.dataset.paletteHref = act(task, needs);
  }
}

function applies(option, task) {
  const needs = option.dataset.paletteNeeds;
  if (!needs) return true;
  if (needs === NO_TASK) return !task;

  return act(task, needs) !== "";
}

async function fetchJSON(url) {
  return json(await fetch(url, { headers: ACCEPT, redirect: "manual" }));
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
  if (option.hasAttribute("data-palette-found") || option.hasAttribute("data-palette-all")) return text !== "";
  if (option.hasAttribute("data-palette-typed")) return text !== "" && option.dataset.paletteText.includes(text);

  return text === "" || option.dataset.paletteText.includes(text);
}

function hiddenField(name, value) {
  const field = document.createElement("input");

  field.type = "hidden";
  field.name = name;
  field.value = value;

  return field;
}

function opens(event) {
  return (event.metaKey || event.ctrlKey) && (event.key === "/" || SLASH_CODES.includes(event.code));
}

function post(option, token) {
  const form = document.createElement("form");

  form.method = "post";
  form.action = option.dataset.paletteHref;
  form.hidden = true;
  form.append(
    hiddenField("_csrf_token", token),
    hiddenField("return_to", window.location.pathname + window.location.search),
  );
  document.body.append(form);
  form.submit();
}

function searchUrl(route, text) {
  return `${route}?${new URLSearchParams({ q: text })}`;
}

function steer(event, { run, select, shown, step }) {
  if (event.key === "Home") select(shown()[0]);
  else if (event.key === "End") select(shown().at(-1));
  else if (event.key === "Enter") run();
  else if (!step(event)) return;

  event.preventDefault();
}

function taskOnScreen() {
  const panel = document.querySelector("[data-task-panel]");
  const scope = panel?.open ? panel : document.querySelector("main");

  return scope?.querySelector(TASK) ?? null;
}

function viewRow(group, { id, title, screen, href }) {
  const row = group.querySelector("[data-palette-view-row]").content.firstElementChild.cloneNode(true);

  row.id = `command-palette-saved-view-${id}`;
  row.dataset.paletteHref = href;
  row.dataset.paletteText = title.toLowerCase();
  row.querySelector(".pal-r-label").textContent = title;
  row.querySelector(".pal-r-sub").textContent = screen;

  return row;
}
