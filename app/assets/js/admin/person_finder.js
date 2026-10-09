import { openDialog } from "./dialog.js";
import { setupFetch } from "./fetching.js";
import { fresh } from "./fresh.js";
import { parse } from "./in_place.js";
import { fillField } from "./person_field.js";
import { slugify } from "./slug.js";

const ANSWERED = [429, 502];
const DRAWER = "person-new-drawer";
const HANDLES = { bluesky: "bluesky_handle", mastodon: "mastodon_handle" };

const ready = new WeakSet();

export function setupPersonFinder() {
  for (const finder of fresh(ready, document.querySelectorAll("[data-person-finder]"))) setup(finder);
}

function setup(finder) {
  finder.hidden = false;
  const form = finder.querySelector("[data-person-finder-form]");
  const input = finder.querySelector("[data-person-finder-input]");
  const label = finder.querySelector("label[data-person-finder-label]");
  const results = finder.querySelector("[data-person-finder-results]");
  const network = () => finder.querySelector("input[name='network']:checked");

  const show = (html) => results.replaceChildren(...parse(html).body.childNodes);

  const fetcher = setupFetch({
    request: (query) => ({ url: `${network().dataset.personFinderUrl}?${new URLSearchParams({ q: query })}` }),
    read: (response) => {
      if (!response.ok && !ANSWERED.includes(response.status))
        throw new Error(`${response.url} answered ${response.status}`);

      return response.text();
    },
    done: show,
    failed: () => {
      const note = document.createElement("p");
      note.className = "hint bad";
      note.textContent = finder.dataset.personFinderFailed;
      results.replaceChildren(note);
    },
  });

  form.addEventListener("submit", (event) => {
    event.preventDefault();
    const query = input.value.trim();
    if (query) fetcher.now(query);
  });

  finder.addEventListener("change", (event) => {
    if (event.target.name !== "network") return;

    const { personFinderLabel, personFinderPlaceholder } = event.target.dataset;
    label.textContent = personFinderLabel;
    input.placeholder = personFinderPlaceholder;
    fetcher.stop();
    results.replaceChildren();
  });

  results.addEventListener("click", (event) => {
    const add = event.target.closest("[data-person-add]");
    if (add) addPerson(add.dataset);
  });
}

function addPerson({ personAdd, personAddName, personAddNetwork }) {
  const drawer = document.getElementById(DRAWER);
  if (!drawer) return;

  const field = (name) => drawer.querySelector(`[name='person[${name}]']`);
  fillField(field("name"), personAddName);
  fillField(field("key"), slugify(personAddName.split(" ")[0]));
  for (const [network, name] of Object.entries(HANDLES)) {
    fillField(field(name), network === personAddNetwork ? personAdd : "");
  }
  openDialog(DRAWER);
}
