import { setupFetch } from "./fetching.js";
import { parse } from "./in_place.js";
import { countText, setupListbox } from "./listbox.js";
import { fillField, typed } from "./person_field.js";

const MINIMUM = 2;
const PICK = "[data-person-pick]";

const ready = new WeakSet();

export function setupPersonSearch(search, name) {
  search.hidden = false;
  if (ready.has(search)) return;

  ready.add(search);
  const field = search.closest(".field").querySelector("[data-person-field]");
  const input = search.querySelector("[data-person-search-input]");
  const list = search.querySelector("[data-person-search-results]");
  const status = search.querySelector("[data-person-search-status]");
  const picks = () => [...list.querySelectorAll(PICK)];

  const choose = (pick) => {
    fillField(field, pick.dataset.personPick);
    if (!typed(name) && pick.dataset.personPickName) fillField(name, pick.dataset.personPickName);
    input.value = "";
    close();
    field.focus();
  };

  const { active, select, step } = setupListbox({ list, owner: () => input, choice: PICK, options: picks, choose });

  const close = () => {
    finder.stop();
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

  const answer = (query, rows) => {
    if (input.value.trim() === query) show(rows.length ? rows : failed());
  };

  const finder = setupFetch({
    request: (query) => ({ url: `${search.dataset.personSearchUrl}?${new URLSearchParams({ q: query })}` }),
    read: (response) => response.text(),
    done: (html, query) => answer(query, options(html)),
    failed: (_error, query) => answer(query, []),
  });

  input.addEventListener("input", () => {
    const query = input.value.trim();
    if (query.length < MINIMUM) return close();

    finder.later(query);
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

function options(html) {
  return [...parse(html).body.querySelectorAll("[role='option']")];
}
