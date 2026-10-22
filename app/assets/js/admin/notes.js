import { fresh } from "./fresh.js";
import { whilePosting } from "./live.js";
import { showToast } from "./toast.js";

const KEY = "admin:notes-shut";
const SAVE_WAIT = 800;
const TAG = /^[a-z0-9]+(-[a-z0-9]+)*$/;

const ready = new WeakSet();

export function setupNotes() {
  const tree = document.querySelector("[data-note-tree]");
  if (tree) setupTree(tree);

  for (const form of fresh(ready, document.querySelectorAll("[data-note-editor]"))) setupEditor(form);
}

function shutIds() {
  try {
    return new Set(JSON.parse(localStorage.getItem(KEY)) ?? []);
  } catch {
    return new Set();
  }
}

function saveShut(tree) {
  const shut = [...tree.querySelectorAll("details[data-note-folder]:not([open])")].map((dir) => dir.dataset.noteFolder);
  try {
    localStorage.setItem(KEY, JSON.stringify(shut));
  } catch {}
}

function marked(dir) {
  for (const row of dir.querySelectorAll(":scope > [data-menu]")) {
    const url = new URL(row.dataset.menu, window.location.href);

    if (dir.open) url.searchParams.delete("shut");
    else url.searchParams.set("shut", "1");
    row.dataset.menu = url.pathname + url.search;
  }
}

function setupTree(tree) {
  const shut = shutIds();
  const dirs = [...tree.querySelectorAll("details[data-note-folder]")];

  for (const dir of dirs) {
    dir.open = !shut.has(dir.dataset.noteFolder);
    marked(dir);
  }
  if (ready.has(tree)) return;
  ready.add(tree);

  tree.addEventListener(
    "toggle",
    (event) => {
      if (!event.target.matches("details[data-note-folder]")) return;

      marked(event.target);
      saveShut(tree);
    },
    true,
  );

  const form = tree.querySelector("[data-note-folder-form]");
  const input = form.querySelector("input[name='path']");
  let sent = false;
  const hide = () => {
    form.hidden = true;
    input.value = "";
  };

  tree.addEventListener("click", (event) => {
    const add = event.target.closest("[data-note-new-folder]");
    const fold = event.target.closest("[data-note-fold]");

    if (fold) {
      for (const dir of tree.querySelectorAll("details[data-note-folder]")) dir.open = fold.dataset.noteFold === "open";
    }
    if (!add) return;

    form.hidden = false;
    input.value = add.dataset.noteNewFolder;
    input.focus();
    input.setSelectionRange(input.value.length, input.value.length);
  });
  input.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") return;

    event.preventDefault();
    hide();
  });
  form.addEventListener("submit", () => {
    sent = true;
  });
  input.addEventListener("blur", () => {
    const path = input.value.trim();
    if (sent) return;
    if (path && !path.endsWith("/")) form.requestSubmit();
    else hide();
  });
}

function setupEditor(form) {
  const version = form.querySelector("[data-note-version]");
  const title = form.querySelector("[name='note[title]']");
  const list = form.querySelector("[data-note-tag-list]");
  const tags = form.querySelector("[data-note-tags]");
  const titleError = form.querySelector("[data-note-title-error]");
  const refused = form.querySelector("[data-note-refused]");
  const status = document.querySelector("[data-note-status]");
  const { changed, failed, saved: savedText, taken } = form.dataset;

  let held = version.value;
  let savedTitle = title.dataset.noteTitle;
  let badTitle = null;
  let relinked = null;
  let stopped = !refused.hidden;
  let timer = null;
  let saving = Promise.resolve();

  form.querySelector("[data-note-save]").hidden = true;

  const body = () => {
    const data = new FormData(form);
    const typed = title.value.trim();
    data.set("note[version]", held);
    if (!typed || typed === badTitle) data.set("note[title]", savedTitle);
    return data;
  };

  const say = (text) => {
    if (status) status.textContent = text;
  };

  const tellRelinked = () => {
    if (relinked) showToast(relinked);
    relinked = null;
  };

  const settle = async (response) => {
    if (response.ok) {
      const answer = await response.json();
      held = String(answer.version);
      savedTitle = answer.title;
      relinked = answer.relinked ?? relinked;
      if (document.activeElement !== title) tellRelinked();
      say(savedText.replace("{time}", new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })));
      return;
    }
    if (response.status !== 422) return say(failed);

    const { errors } = await response.json();
    if (errors.version) {
      stopped = true;
      refused.textContent = changed;
      refused.hidden = false;
      return say(failed);
    }
    if (errors.title) {
      badTitle = title.value.trim();
      titleError.hidden = errors.title !== "taken";
      titleError.textContent = taken.replace("{title}", badTitle);
      queue();
    }
  };

  const save = async () => {
    if (stopped) return;

    try {
      const response = await whilePosting(
        fetch(form.action, {
          method: "POST",
          body: new URLSearchParams(body()),
          headers: { Accept: "application/json" },
        }),
      );
      await settle(response);
    } catch {
      say(failed);
    }
  };

  const queue = () => {
    clearTimeout(timer);
    timer = null;
    saving = saving.then(save);
  };

  const later = () => {
    clearTimeout(timer);
    timer = setTimeout(queue, SAVE_WAIT);
  };

  const names = () =>
    list.value
      .split(",")
      .map((name) => name.trim())
      .filter(Boolean);

  const retag = (next) => {
    list.value = [...new Set(next)].join(", ");
    queue();
  };

  const pill = (name) => {
    const made = document.createElement("span");
    const link = document.createElement("a");
    const remove = document.createElement("button");
    const icon = document.createElement("i");

    made.className = "nt-tg";
    made.dataset.noteTag = name;
    link.className = "tag";
    link.href = `/admin/tags/${name}`;
    link.textContent = `#${name}`;
    remove.type = "button";
    remove.className = "nt-x";
    remove.ariaLabel = tags.dataset.remove.replace("{tag}", name);
    icon.className = "fa-solid fa-xmark";
    icon.ariaHidden = "true";
    remove.append(icon);
    made.append(link, remove);
    return made;
  };

  form.addEventListener("input", (event) => {
    if (event.target.matches("[data-note-tag-input]")) return;
    if (event.target === title && title.value.trim() !== badTitle) {
      badTitle = null;
      titleError.hidden = true;
    }
    later();
  });
  form.addEventListener("submit", (event) => {
    event.preventDefault();
    queue();
  });
  title.addEventListener("keydown", (event) => {
    if (event.key !== "Enter") return;

    event.preventDefault();
    title.blur();
  });
  title.addEventListener("blur", () => {
    tellRelinked();
    if (title.value.trim() && title.value.trim() !== badTitle) return;

    title.value = savedTitle;
    badTitle = null;
    titleError.hidden = true;
  });

  tags.addEventListener("click", (event) => {
    const remove = event.target.closest(".nt-x");
    if (!remove) return;

    const tag = remove.closest("[data-note-tag]");
    tag.remove();
    retag(names().filter((name) => name !== tag.dataset.noteTag));
  });
  tags.querySelector("[data-note-tag-input]").addEventListener("keydown", (event) => {
    if (event.key !== "Enter") return;

    event.preventDefault();
    const field = event.target;
    const have = names();
    const added = field.value
      .split(",")
      .map((name) => name.trim().toLowerCase())
      .filter((name) => TAG.test(name) && !have.includes(name));
    for (const name of added) tags.querySelector("details").before(pill(name));
    field.value = "";
    field.closest("details").open = false;
    if (added.length) retag([...have, ...added]);
  });

  window.addEventListener("pagehide", () => {
    if (!timer || stopped) return;

    clearTimeout(timer);
    fetch(form.action, {
      method: "POST",
      body: new URLSearchParams(body()),
      headers: { Accept: "application/json" },
      keepalive: true,
    }).catch(() => {});
  });
}
