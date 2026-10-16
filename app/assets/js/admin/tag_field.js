import { countText, setupListbox } from "./listbox.js";

const NAME = "{name}";
const OPTION = "[role='option']:not([aria-disabled])";
const SEPARATOR = ", ";

const ready = new WeakSet();

export function setupTagFields() {
  for (const pick of document.querySelectorAll("[data-tag-field]")) setupTagField(pick);
}

const normalize = (name) => name.trim().toLowerCase();

function setupTagField(pick) {
  const field = pick.closest(".field");
  const value = field.querySelector("[data-tag-field-value]");
  const chips = pick.querySelector("[data-tag-field-chips]");
  const input = pick.querySelector("[data-tag-field-input]");
  const colors = new Map(JSON.parse(pick.dataset.tagField).map(({ name, color }) => [name, color]));
  const names = () => [...new Set(value.value.split(",").map(normalize).filter(Boolean))];
  const write = (list) => (value.value = list.join(SEPARATOR));

  const tag = (name) => {
    const element = document.createElement("span");
    element.className = ["tag", colors.get(name)].filter(Boolean).join(" ");
    element.textContent = `#${name}`;
    return element;
  };

  const chip = (name) => {
    const remove = document.createElement("button");
    remove.type = "button";
    remove.className = "tag-pick-remove";
    remove.setAttribute("aria-label", pick.dataset.tagFieldRemove.replace(NAME, name));
    remove.innerHTML = '<i class="fa-solid fa-xmark" aria-hidden="true"></i>';
    remove.addEventListener("click", () => {
      write(names().filter((other) => other !== name));
      showChips();
      input.focus();
    });

    const item = document.createElement("li");
    item.className = "tag-pick-chip";
    item.append(tag(name), remove);
    return item;
  };

  const showChips = () => chips.replaceChildren(...names().map(chip));

  const add = (text) => {
    const name = normalize(text);
    if (!name || names().includes(name)) return;

    write([...names(), name]);
    showChips();
  };

  if (!ready.has(pick)) {
    ready.add(pick);
    setupSearch({ pick, input, colors, names, tag, add });
  }

  value.hidden = true;
  field.querySelector(":scope > label").htmlFor = input.id;
  pick.hidden = false;
  showChips();
}

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

  const none = () => {
    const element = document.createElement("div");
    element.id = `${list.id}-none`;
    element.className = "tag-pick-result tag-pick-note";
    element.setAttribute("role", "option");
    element.setAttribute("aria-disabled", "true");
    element.setAttribute("aria-selected", "false");
    element.textContent = pick.dataset.tagFieldNone;
    return element;
  };

  const open = () => {
    const query = normalize(input.value);
    const chosen = names();
    const found = [...colors.keys()]
      .filter((name) => !chosen.includes(name) && name.includes(query))
      .map((name, index) => row(name, tag(name), index));
    if (query && !colors.has(query) && !chosen.includes(query)) {
      found.push(row(query, pick.dataset.tagFieldAdd.replace(NAME, query), found.length));
    }

    list.replaceChildren(...(found.length ? found : [none()]));
    list.hidden = false;
    input.setAttribute("aria-expanded", "true");
    select(null);
    status.textContent = found.length ? countText(pick, "tagFieldResults", found.length) : pick.dataset.tagFieldNone;
  };

  const close = () => {
    select(null);
    list.hidden = true;
    list.replaceChildren();
    input.setAttribute("aria-expanded", "false");
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
