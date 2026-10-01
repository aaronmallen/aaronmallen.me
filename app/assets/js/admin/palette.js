import { openDialog } from "./dialog.js";

const COUNT = "{count}";
const OPTION = "[data-palette-option]";
const SHOWN = "[data-palette-option]:not([hidden])";
const SLASH_CODES = ["Slash", "NumpadDivide"];
const TASK_LIMIT = 5;
const TYPING = "input, textarea, select, [contenteditable]";

export function setupPalette() {
  const dialog = document.querySelector("[data-palette]");

  if (dialog) setupDialog(dialog);
}

function setupDialog(dialog) {
  const query = dialog.querySelector("[data-palette-query]");
  const list = dialog.querySelector("[data-palette-list]");
  const status = dialog.querySelector("[data-palette-status]");
  const tasks = dialog.querySelector("[data-palette-tasks]");
  const row = dialog.querySelector("[data-palette-task-row]");
  const groups = [...dialog.querySelectorAll("[data-palette-group]")];
  let options = [...dialog.querySelectorAll(OPTION)];
  let loading = null;

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
    let tasks = 0;

    for (const option of options) {
      let visible = matches(option, text);

      if (visible && option.hasAttribute("data-palette-task")) {
        tasks += 1;
        visible = tasks <= TASK_LIMIT;
      }

      option.hidden = !visible;
    }

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

  const load = () => {
    if (loading) return;

    loading = fetchTasks(tasks, row)
      .then((rows) => {
        tasks.append(...rows);
        options = [...dialog.querySelectorAll(OPTION)];
        if (query.value.trim() !== "") filter();
      })
      .catch(() => {
        loading = null;
      });
  };

  const open = () => {
    if (dialog.open) return;

    query.value = "";
    filter();
    dialog.showModal();
    query.focus();
    load();
  };

  for (const trigger of document.querySelectorAll("[data-palette-open]")) {
    trigger.addEventListener("click", open);
  }

  document.addEventListener("keydown", (event) => {
    if (dialog.open || !opens(event)) return;

    event.preventDefault();
    open();
  });

  query.addEventListener("input", filter);
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

  filter();
}

async function fetchTasks(group, template) {
  const response = await fetch(group.dataset.paletteTasks, {
    headers: { Accept: "application/json" },
    redirect: "manual",
  });
  if (!response.ok) throw new Error(`palette tasks answered ${response.status}`);

  const lists = JSON.parse(group.dataset.paletteLists);
  const { tasks } = await response.json();

  return tasks.map((task) => taskRow(template, task, lists[task.list]));
}

function taskRow(template, { id, title }, { href, sub }) {
  const row = template.content.firstElementChild.cloneNode(true);

  row.id = `command-palette-task-${id}`;
  row.dataset.paletteText = title.toLowerCase();
  row.dataset.paletteHref = href;
  row.querySelector(".pal-r-label").textContent = title;
  row.querySelector(".pal-r-sub").textContent = sub;

  return row;
}

function matches(option, text) {
  if (option.hasAttribute("data-palette-task")) return text !== "" && option.dataset.paletteText.includes(text);

  return text === "" || option.dataset.paletteText.includes(text);
}

function opens(event) {
  if (event.metaKey || event.ctrlKey) return event.key === "/" || SLASH_CODES.includes(event.code);

  return event.key === "/" && !event.target?.closest?.(TYPING);
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
