import { countText, setupListbox } from "./listbox.js";
import { fillField, typed } from "./person_field.js";

const DELAY = 300;
const MINIMUM = 2;
const PICK = "[data-person-pick]";

export function setupPersonSearch(search, name) {
  const field = search.closest(".field").querySelector("[data-person-field]");
  const input = search.querySelector("[data-person-search-input]");
  const list = search.querySelector("[data-person-search-results]");
  const status = search.querySelector("[data-person-search-status]");
  const picks = () => [...list.querySelectorAll(PICK)];
  let controller = null;
  let timer = null;

  const choose = (pick) => {
    fillField(field, pick.dataset.personPick);
    if (!typed(name) && pick.dataset.personPickName) fillField(name, pick.dataset.personPickName);
    input.value = "";
    close();
    field.focus();
  };

  const { active, select, step } = setupListbox({ list, owner: () => input, choice: PICK, options: picks, choose });

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
    status.textContent = found ? countText(search, "personSearchResults", found) : (rows[0]?.textContent ?? "");
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

  search.hidden = false;

  input.addEventListener("input", () => {
    clearTimeout(timer);
    const query = input.value.trim();
    if (query.length < MINIMUM) return close();

    timer = setTimeout(() => ask(query), DELAY);
  });

  input.addEventListener("keydown", (event) => {
    if (event.isComposing) return;

    if (event.key === "Enter") {
      if (active()) choose(active());
    } else if (list.hidden) return;
    else if (event.key === "Escape") close();
    else if (!step(event)) return;

    event.preventDefault();
    event.stopPropagation();
  });

  input.addEventListener("blur", () => {
    if (!list.hidden) close();
  });
}

function parse(html) {
  const found = new DOMParser().parseFromString(html, "text/html");

  return [...found.body.querySelectorAll("[role='option']")];
}
