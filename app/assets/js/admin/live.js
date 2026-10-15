import { Idiomorph } from "idiomorph";
import { ASKING } from "./confirm.js";
import { MENU } from "./context_menu.js";
import { setupFetch } from "./fetching.js";
import { parse } from "./in_place.js";

const CATCH_UP = "*";
const LONGEST_WAIT = 30000;
const MORPHED = "admin:morphed";
const OPENS = "dialog, details";
const PARTS = ["main", ".top-bar", "[data-palette]"];
const TYPED = "input, textarea, select, [contenteditable]";
const WAIT = 1000;
const HOLD = `dialog:modal:not([data-dialog-live]), ${ASKING}, ${MENU}`;

export const MORPHED_PARTS = PARTS.join(", ");

const edits = trackEdits();
let shown = drawnAt(document);
let leaving = false;
let posts = 0;
let refetch = null;
let started = false;
let wanted = 0;

export function forgetEdits(form) {
  for (const control of form.elements) edits.delete(control);
}

export function leavePage() {
  leaving = true;
  refetch?.stop();
}

export async function whilePosting(post) {
  posts += 1;
  try {
    return await post;
  } finally {
    posts -= 1;
    if (!posts && wanted > shown) refetch?.later();
  }
}

export function morphPage(next) {
  const typing = Boolean(document.activeElement?.matches(TYPED));
  shown = Math.max(shown, drawnAt(next));
  if (shown > wanted) refetch?.stop();
  for (const selector of PARTS) {
    const now = document.querySelector(selector);
    const drawn = next.querySelector(selector);
    if (now && drawn)
      Idiomorph.morph(now, drawn, {
        ignoreActiveValue: typing,
        callbacks: { beforeNodeMorphed: untouched, beforeAttributeUpdated: keepsOpen },
      });
  }

  document.dispatchEvent(new Event(MORPHED));
}

export function setupLive() {
  const url = document.querySelector("[data-live]")?.dataset.live;
  if (started || !url) return;

  started = true;
  let asked = 0;
  let next = null;

  const morph = () => {
    if (!next || leaving || document.querySelector(HOLD)) return;

    const page = next;
    next = null;
    if (drawnAt(page) > shown) morphPage(page);
  };

  refetch = setupFetch({
    queue: true,
    request: () => {
      asked = wanted;
      return { url: window.location.href, redirect: "manual" };
    },
    done: (html) => {
      next = parse(html);
      if (wanted === asked) wanted = 0;
      morph();
    },
  });

  let missed = false;
  const changed = (at) => {
    if (at === Infinity) shown = 0;
    if (leaving || at < shown) return;

    wanted = Math.max(wanted, at);
    missed = document.hidden;
    if (!missed && !posts) refetch.later();
  };

  document.addEventListener("close", morph, true);
  document.addEventListener("visibilitychange", () => {
    if (missed) changed(wanted);
  });
  listen(url, changed);
}

function drawnAt(page) {
  return Number(page.querySelector("[data-live-at]")?.dataset.liveAt) || 0;
}

function keepsOpen(name, node, change) {
  return !(change === "remove" && name === "open" && node.matches(OPENS));
}

function shows(table) {
  const listed = document.querySelector("[data-live-tables]")?.dataset.liveTables.split(" ");
  return !listed || table === CATCH_UP || listed.includes(table);
}

function trackEdits() {
  const edited = new WeakSet();

  document.addEventListener("input", (event) => edited.add(event.target), true);
  document.addEventListener("reset", (event) => forgetEdits(event.target), true);

  return edited;
}

function untouched(node) {
  const controls = node instanceof HTMLFormElement ? [...node.elements] : [node];
  return !controls.some((control) => edits.has(control) || control.checked !== control.defaultChecked);
}

function listen(url, changed) {
  let opened = false;
  let source = null;
  let timer = null;
  let wait = WAIT;

  const connect = () => {
    const current = new EventSource(url);
    source = current;

    current.addEventListener("open", () => {
      if (opened) changed(Infinity);
      opened = true;
      wait = WAIT;
    });
    current.addEventListener("change", (event) => {
      if (shows(event.data)) changed(Number(event.lastEventId) || Infinity);
    });
    current.addEventListener("error", () => {
      if (current.readyState !== EventSource.CLOSED) return;

      timer = setTimeout(connect, wait);
      wait = Math.min(wait * 2, LONGEST_WAIT);
    });
  };

  window.addEventListener("pagehide", () => {
    clearTimeout(timer);
    source.close();
  });
  window.addEventListener("pageshow", (event) => {
    if (event.persisted) connect();
  });

  connect();
}
