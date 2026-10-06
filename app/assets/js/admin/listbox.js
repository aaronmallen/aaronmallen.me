const COUNT = "{count}";
const STEPS = { ArrowDown: 1, ArrowUp: -1 };

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
    if (!(event.key in STEPS)) return false;

    move(STEPS[event.key]);
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
