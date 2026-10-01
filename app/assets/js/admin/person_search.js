import { fillField, typed } from "./person_field.js";

const COUNT = "{count}";
const DELAY = 300;
const MINIMUM = 2;
const PICK = "[data-person-pick]";
const STEPS = { ArrowDown: 1, ArrowUp: -1 };

export function setupPersonSearch(search, name) {
  const field = search.closest(".field").querySelector("[data-person-field]");
  const input = search.querySelector("[data-person-search-input]");
  const list = search.querySelector("[data-person-search-results]");
  const status = search.querySelector("[data-person-search-status]");
  const picks = () => [...list.querySelectorAll(PICK)];
  const active = () => picks().find((pick) => pick.getAttribute("aria-selected") === "true");
  let controller = null;
  let timer = null;

  const select = (pick) => {
    for (const other of picks()) other.setAttribute("aria-selected", String(other === pick));
    if (!pick) return input.removeAttribute("aria-activedescendant");

    input.setAttribute("aria-activedescendant", pick.id);
    pick.scrollIntoView({ block: "nearest" });
  };

  const close = () => {
    clearTimeout(timer);
    controller?.abort();
    select(null);
    list.hidden = true;
    list.replaceChildren();
    input.setAttribute("aria-expanded", "false");
  };

  const show = (rows) => {
    list.replaceChildren(...rows);
    list.hidden = false;
    input.setAttribute("aria-expanded", "true");
    select(null);

    const found = picks().length;
    status.textContent = found ? plural(search, found) : (rows[0]?.textContent ?? "");
  };

  const failed = () => {
    const row = document.createElement("div");
    row.id = `${list.id}-failed`;
    row.className = "person-search-result person-search-note";
    row.setAttribute("role", "option");
    row.setAttribute("aria-disabled", "true");
    row.setAttribute("aria-selected", "false");
    row.textContent = search.dataset.personSearchFailed;

    return [row];
  };

  const ask = async (query) => {
    controller?.abort();
    controller = new AbortController();
    const url = `${search.dataset.personSearchUrl}?${new URLSearchParams({ q: query })}`;

    let rows;
    try {
      const response = await fetch(url, { signal: controller.signal });
      rows = parse(await response.text());
    } catch (error) {
      if (error.name === "AbortError") return;
      rows = [];
    }

    if (input.value.trim() === query) show(rows.length ? rows : failed());
  };

  const choose = (pick) => {
    fillField(field, pick.dataset.personPick);
    if (!typed(name) && pick.dataset.personPickName) fillField(name, pick.dataset.personPickName);
    input.value = "";
    close();
    field.focus();
  };

  const move = (step) => {
    const all = picks();
    if (!all.length) return;

    const at = all.indexOf(active());
    select(all[at < 0 ? (step > 0 ? 0 : all.length - 1) : Math.min(Math.max(at + step, 0), all.length - 1)]);
  };

  search.hidden = false;

  input.addEventListener("input", () => {
    clearTimeout(timer);
    const query = input.value.trim();
    if (query.length < MINIMUM) return close();

    timer = setTimeout(() => ask(query), DELAY);
  });

  input.addEventListener("keydown", (event) => {
    if (event.isComposing) return;

    if (event.key in STEPS && !list.hidden) move(STEPS[event.key]);
    else if (event.key === "Enter") {
      if (active()) choose(active());
    } else if (event.key === "Escape" && !list.hidden) close();
    else return;

    event.preventDefault();
    event.stopPropagation();
  });

  input.addEventListener("blur", () => {
    if (!list.hidden) close();
  });

  list.addEventListener("mousedown", (event) => event.preventDefault());

  list.addEventListener("click", (event) => {
    const pick = event.target.closest(PICK);
    if (pick) choose(pick);
  });

  list.addEventListener("mousemove", (event) => {
    const pick = event.target.closest(PICK);
    if (pick && pick !== active()) select(pick);
  });
}

function parse(html) {
  const found = new DOMParser().parseFromString(html, "text/html");

  return [...found.body.querySelectorAll("[role='option']")];
}

function plural(search, count) {
  const template = count === 1 ? search.dataset.personSearchResultsOne : search.dataset.personSearchResultsOther;

  return template.replace(COUNT, String(count));
}
