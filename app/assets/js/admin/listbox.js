const COUNT = "{count}";

export const ARROWS = { ArrowDown: 1, ArrowUp: -1 };

export function countText(element, key, count) {
  const template = element.dataset[`${key}${count === 1 ? "One" : "Other"}`];

  return template.replace(COUNT, String(count));
}

export function setupListbox({ list, owner, choice, options, shown = options, choose }) {
  const active = () => options().find((option) => option.getAttribute("aria-selected") === "true");

  const select = (option) => {
    for (const other of options()) other.setAttribute("aria-selected", String(other === option));
    if (!option) return owner()?.removeAttribute("aria-activedescendant");

    owner()?.setAttribute("aria-activedescendant", option.id);
    option.scrollIntoView({ block: "nearest" });
  };

  const move = (step) => {
    const visible = shown();
    if (!visible.length) return;

    const at = visible.indexOf(active());
    const next = at < 0 ? (step > 0 ? 0 : visible.length - 1) : Math.min(Math.max(at + step, 0), visible.length - 1);
    select(visible[next]);
  };

  const step = (event) => {
    if (!(event.key in ARROWS)) return false;

    move(ARROWS[event.key]);
    return true;
  };

  list.addEventListener("mousedown", (event) => event.preventDefault());

  list.addEventListener("click", (event) => {
    const option = event.target.closest(choice);
    if (!option) return;

    event.preventDefault();
    choose(option);
  });

  list.addEventListener("mousemove", (event) => {
    const option = event.target.closest(choice);
    if (option && option !== active()) select(option);
  });

  return { active, select, step };
}

export function removeButton(className, label, remove) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = className;
  button.setAttribute("aria-label", label);
  button.innerHTML = '<i class="fa-solid fa-xmark" aria-hidden="true"></i>';
  button.addEventListener("click", remove);
  return button;
}

export function noneRow(list, className, text) {
  const row = document.createElement("div");
  row.id = `${list.id}-none`;
  row.className = className;
  row.setAttribute("role", "option");
  row.setAttribute("aria-disabled", "true");
  row.setAttribute("aria-selected", "false");
  row.textContent = text;
  return row;
}

export function setupToggle({ list, input, status, select, none, count }) {
  const open = (rows) => {
    list.replaceChildren(...(rows.length ? rows : [noneRow(list, none.className, none.text)]));
    list.hidden = false;
    input.setAttribute("aria-expanded", "true");
    select(null);
    status.textContent = rows.length ? count(rows.length) : none.text;
  };

  const close = () => {
    select(null);
    list.hidden = true;
    list.replaceChildren();
    input.setAttribute("aria-expanded", "false");
  };

  return { open, close };
}
