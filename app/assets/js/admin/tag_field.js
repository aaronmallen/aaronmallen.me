import { getJSON } from "./fetching.js";
import { fresh } from "./fresh.js";
import { countText, removeButton, setupListbox, setupToggle } from "./listbox.js";

const NAME = "{name}";
const OPTION = "[role='option']:not([aria-disabled])";
const SEPARATOR = ", ";

const ready = new WeakSet();
const palettes = new WeakMap();
const loads = new WeakMap();

export function setupTagFields(root = document) {
  for (const pick of root.querySelectorAll("[data-tag-field]")) setupTagField(pick);
}

const normalize = (name) => name.trim().toLowerCase();

function setupTagField(pick) {
  const value = pick.previousElementSibling;
  const chips = pick.querySelector("[data-tag-field-chips]");
  const input = pick.querySelector("[data-tag-field-input]");
  const colors = colorsFor(pick);
  const names = () => [...new Set(value.value.split(",").map(normalize).filter(Boolean))];
  const write = (list) => (value.value = list.join(SEPARATOR));

  const tagClass = (name) => ["tag", colors.get(name)].filter(Boolean).join(" ");

  const tag = (name) => {
    const element = document.createElement("span");
    element.className = tagClass(name);
    element.textContent = `#${name}`;
    return element;
  };

  const chip = (name) => {
    const remove = removeButton("tag-pick-remove", pick.dataset.tagFieldRemove.replace(NAME, name), () => {
      write(names().filter((other) => other !== name));
      showChips();
      input.focus();
    });

    const item = document.createElement("li");
    item.className = "tag-pick-chip";
    item.dataset.tagFieldName = name;
    item.append(tag(name), remove);
    return item;
  };

  const showChips = () => chips.replaceChildren(...names().map(chip));
  const recolor = () => {
    for (const item of chips.children) item.querySelector(".tag").className = tagClass(item.dataset.tagFieldName);
  };

  const add = (text) => {
    const name = normalize(text);
    if (!name || names().includes(name)) return;

    write([...names(), name]);
    showChips();
  };

  const load = () =>
    loadColors(pick, colors, () => {
      recolor();
      if (document.activeElement === input && input.value.trim()) input.dispatchEvent(new Event("input"));
    });

  if (fresh(ready, [pick]).length) {
    setupSearch({ pick, input, colors, names, tag, add });
    input.addEventListener("focus", load);
  }
  if (names().length) load();

  value.hidden = true;
  const label = pick.parentElement.querySelector(`label[for="${CSS.escape(value.id)}"]`);
  if (label) label.htmlFor = input.id;
  pick.hidden = false;
  showChips();
}

function colorsFor(pick) {
  const colors = palettes.get(pick) ?? new Map();
  palettes.set(pick, colors);
  for (const { name, color } of JSON.parse(pick.dataset.tagField || "[]")) colors.set(name, color);
  return colors;
}

function loadColors(pick, colors, done) {
  const url = pick.dataset.tagFieldSrc;
  if (!url || loads.has(pick)) return;

  loads.set(pick, false);
  getJSON(url)
    .then(({ tags }) => {
      for (const { name, color } of tags) colors.set(name, color);
      loads.set(pick, true);
      done();
    })
    .catch(() => loads.delete(pick));
}

const waiting = (pick) => pick.dataset.tagFieldSrc && !loads.get(pick);

function setupSearch({ pick, input, colors, names, tag, add }) {
  const list = pick.querySelector("[data-tag-field-results]");
  const status = pick.querySelector("[data-tag-field-status]");
  const options = () => [...list.querySelectorAll(OPTION)];

  const choose = (option) => {
    add(option.dataset.tagFieldName);
    input.value = "";
    close();
    input.focus();
  };

  const { active, select, step } = setupListbox({ list, owner: () => input, choice: OPTION, options, choose });

  const row = (name, label, index) => {
    const element = document.createElement("div");
    element.id = `${list.id}-${index}`;
    element.className = "tag-pick-result";
    element.setAttribute("role", "option");
    element.setAttribute("aria-selected", "false");
    element.dataset.tagFieldName = name;
    element.append(label);
    return element;
  };

  const { open: show, close } = setupToggle({
    list,
    input,
    status,
    select,
    none: { className: "tag-pick-result tag-pick-note", text: pick.dataset.tagFieldNone },
    count: (count) => countText(pick, "tagFieldResults", count),
  });

  const open = () => {
    if (waiting(pick)) return;

    const query = normalize(input.value);
    const chosen = names();
    const found = [...colors.keys()]
      .filter((name) => !chosen.includes(name) && name.includes(query))
      .map((name, index) => row(name, tag(name), index));
    if (query && !colors.has(query) && !chosen.includes(query)) {
      found.push(row(query, pick.dataset.tagFieldAdd.replace(NAME, query), found.length));
    }

    show(found);
  };

  const commit = () => {
    add(input.value);
    input.value = "";
  };

  input.addEventListener("input", () => {
    const parts = input.value.split(",");
    if (parts.length > 1) {
      input.value = parts.pop();
      parts.forEach(add);
    }
    if (input.value.trim()) open();
    else close();
  });

  input.addEventListener("keydown", (event) => {
    if (event.isComposing) return;

    if (event.key === "Enter") {
      if (active()) choose(active());
      else if (input.value.trim()) {
        commit();
        close();
      } else return;
    } else if (list.hidden) {
      if (event.key !== "ArrowDown") return;
      open();
      step(event);
    } else if (event.key === "Escape") close();
    else if (!step(event)) return;

    event.preventDefault();
    event.stopPropagation();
  });

  input.addEventListener("blur", () => {
    commit();
    if (!list.hidden) close();
  });
}
