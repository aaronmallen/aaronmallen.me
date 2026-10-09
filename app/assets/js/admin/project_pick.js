import { countText, setupListbox } from "./listbox.js";

const BOX = "[data-project-pick-boxes] input[type='checkbox']";
const NAME = "{name}";
const OPTION = "[role='option']";

const ready = new WeakSet();

export function setupProjectPicks() {
  for (const pick of document.querySelectorAll("[data-project-pick]")) setupProjectPick(pick);
}

function setupProjectPick(pick) {
  const field = pick.closest(".field");
  const chips = pick.querySelector("[data-project-pick-chips]");
  const input = pick.querySelector("[data-project-pick-input]");
  const list = pick.querySelector("[data-project-pick-results]");
  const status = pick.querySelector("[data-project-pick-status]");
  const boxes = () => [...field.querySelectorAll(BOX)];
  const options = () => [...list.querySelectorAll(OPTION)];

  const named = (element, box) => {
    const name = document.createElement("span");
    name.textContent = box.dataset.projectName;
    element.append(name);
    if (!("projectArchived" in box.dataset)) return element;

    const archived = document.createElement("span");
    archived.className = "project-pick-archived";
    archived.textContent = pick.dataset.projectPickArchived;
    element.append(" ", archived);
    return element;
  };

  const chip = (box) => {
    const remove = document.createElement("button");
    remove.type = "button";
    remove.className = "project-pick-remove";
    remove.setAttribute("aria-label", pick.dataset.projectPickRemove.replace(NAME, box.dataset.projectName));
    remove.innerHTML = '<i class="fa-solid fa-xmark" aria-hidden="true"></i>';
    remove.addEventListener("click", () => {
      box.checked = false;
      showChips();
      input.focus();
    });

    const item = named(document.createElement("li"), box);
    item.className = "project-pick-chip";
    item.append(remove);
    return item;
  };

  const showChips = () =>
    chips.replaceChildren(
      ...boxes()
        .filter((box) => box.checked)
        .map(chip),
    );

  if (!ready.has(pick)) {
    ready.add(pick);
    setupSearch({ pick, input, list, status, boxes, options, named, showChips });
  }

  field.querySelector("[data-project-pick-boxes]").hidden = true;
  field.querySelector(":scope > label").htmlFor = input.id;
  pick.hidden = false;
  showChips();
}

function setupSearch({ pick, input, list, status, boxes, options, named, showChips }) {
  const choose = (option) => {
    const box = boxes().find((found) => found.value === option.dataset.projectPickValue);
    if (!box) return;

    box.checked = true;
    input.value = "";
    close();
    showChips();
    input.focus();
  };

  const { active, select, step } = setupListbox({ list, owner: () => input, choice: OPTION, options, choose });

  const option = (box) => {
    const row = named(document.createElement("div"), box);
    row.id = `${list.id}-${box.value}`;
    row.className = "project-pick-result";
    row.setAttribute("role", "option");
    row.setAttribute("aria-selected", "false");
    row.dataset.projectPickValue = box.value;
    return row;
  };

  const none = () => {
    const row = document.createElement("div");
    row.id = `${list.id}-none`;
    row.className = "project-pick-result project-pick-note";
    row.setAttribute("role", "option");
    row.setAttribute("aria-disabled", "true");
    row.setAttribute("aria-selected", "false");
    row.textContent = pick.dataset.projectPickNone;
    return row;
  };

  const open = () => {
    const query = input.value.trim().toLowerCase();
    const found = boxes()
      .filter((box) => !box.checked && box.dataset.projectName.toLowerCase().includes(query))
      .map(option);

    list.replaceChildren(...(found.length ? found : [none()]));
    list.hidden = false;
    input.setAttribute("aria-expanded", "true");
    select(null);
    status.textContent = found.length
      ? countText(pick, "projectPickResults", found.length)
      : pick.dataset.projectPickNone;
  };

  const close = () => {
    select(null);
    list.hidden = true;
    list.replaceChildren();
    input.setAttribute("aria-expanded", "false");
  };

  input.addEventListener("input", () => (input.value.trim() ? open() : close()));

  input.addEventListener("keydown", (event) => {
    if (event.isComposing) return;

    if (list.hidden) {
      if (event.key !== "ArrowDown") return;
      open();
      step(event);
    } else if (event.key === "Enter") {
      if (active()) choose(active());
    } else if (event.key === "Escape") close();
    else if (!step(event)) return;

    event.preventDefault();
    event.stopPropagation();
  });

  input.addEventListener("blur", () => {
    if (!list.hidden) close();
  });
}
