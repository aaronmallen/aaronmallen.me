import { fresh } from "./admin/fresh.js";
import { ARROWS, setupListbox } from "./admin/listbox.js";

const LABEL = /^(-?)(?:label|l):"?([^"]*)$/i;
const COLUMN = /^(-?)(?:column|col):(.*)$/i;
const IS = /^(-?)is:(.*)$/i;
const OPTION = "[role='option']";
const STATES = ["open", "closed", "doing", "blocked"];
const TAG_LIMIT = 8;

const ready = new WeakSet();

export function setupTaskFilters() {
  for (const root of fresh(ready, document.querySelectorAll("[data-task-filter]"))) setupTaskFilter(root);
}

function setupTaskFilter(root) {
  const choices = JSON.parse(root.dataset.taskFilter);
  const form = root.querySelector("form");
  const input = form.querySelector("[role='combobox']");
  const list = form.querySelector("[role='listbox']");
  const options = () => [...list.querySelectorAll(OPTION)];

  const token = () => /(\S*)$/.exec(input.value)[1];

  const close = () => {
    select(null);
    list.hidden = true;
    list.replaceChildren();
    input.setAttribute("aria-expanded", "false");
  };

  const open = () => {
    const found = suggestions(token(), choices);
    if (!found.length) return close();

    list.replaceChildren(...found.map((suggestion, at) => option(list, suggestion, at)));
    list.hidden = false;
    input.setAttribute("aria-expanded", "true");
    select(null);
  };

  const choose = (picked) => {
    const insert = picked.dataset.insert;
    input.value = input.value.slice(0, input.value.length - token().length) + insert;
    input.focus();
    if (insert.endsWith(" ")) {
      close();
      form.requestSubmit();
    } else open();
  };

  const { active, select, step } = setupListbox({ list, owner: () => input, choice: OPTION, options, choose });

  input.addEventListener("focus", open);
  input.addEventListener("input", open);
  input.addEventListener("blur", close);

  input.addEventListener("keydown", (event) => {
    if (event.isComposing) return;

    if (event.key in ARROWS) {
      event.preventDefault();
      if (list.hidden) open();
      step(event);
    } else if (event.key === "Enter" && !list.hidden && token()) {
      event.preventDefault();
      choose(active() ?? options()[0]);
    } else if (event.key === "Tab" && active()) {
      event.preventDefault();
      choose(active());
    } else if (event.key === "Tab") close();
    else if (event.key === "Escape") {
      event.stopPropagation();
      if (!list.hidden) close();
      else if (input.value) {
        input.value = "";
        form.requestSubmit();
      } else input.blur();
    }
  });
}

function option(list, { insert, label, hint, color }, at) {
  const row = document.createElement("div");
  row.id = `${list.id}-${at}`;
  row.className = "task-filter-option";
  row.setAttribute("role", "option");
  row.setAttribute("aria-selected", "false");
  row.dataset.insert = insert;

  const term = document.createElement("span");
  term.className = color === undefined ? "task-filter-term" : ["tag", color].filter(Boolean).join(" ");
  term.textContent = color === undefined ? label : `#${label}`;
  row.append(term);

  if (hint) {
    const text = document.createElement("span");
    text.className = "task-filter-hint";
    text.textContent = hint;
    row.append(text);
  }
  return row;
}

function suggestions(token, { qualifiers, tags, columns }) {
  const lower = token.toLowerCase();
  const described = Object.fromEntries(qualifiers);

  const label = LABEL.exec(token);
  if (label) {
    const typed = label[2].toLowerCase();
    return tags
      .filter(([name, hint]) => name.includes(typed) || (hint ?? "").toLowerCase().includes(typed))
      .sort(([one], [two]) => two.startsWith(typed) - one.startsWith(typed) || one.localeCompare(two))
      .slice(0, TAG_LIMIT)
      .map(([name, hint, color]) => ({ insert: `${label[1]}label:${name} `, label: name, hint, color: color ?? "" }));
  }

  const state = IS.exec(lower);
  if (state) {
    return STATES.filter((value) => value.startsWith(state[2])).map((value) => ({
      insert: `${state[1]}is:${value} `,
      label: `is:${value}`,
      hint: described[`is:${value}`],
    }));
  }

  const column = COLUMN.exec(lower);
  if (column) {
    return columns
      .filter(([id, name]) => id.startsWith(column[2]) || name.toLowerCase().startsWith(column[2]))
      .map(([id, name]) => ({ insert: `${column[1]}column:${id} `, label: `column:${id}`, hint: name }));
  }

  return qualifiers
    .filter(([term]) => term.startsWith(lower))
    .map(([term, hint]) => ({ insert: term.endsWith(":") ? term : `${term} `, label: term, hint }));
}
