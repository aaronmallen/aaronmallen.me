import { Idiomorph } from "idiomorph";
import { ASKING } from "./confirm.js";
import { MENU } from "./context_menu.js";
import { setupFetch } from "./fetching.js";
import { parse } from "./in_place.js";

const LONGEST_WAIT = 30000;
const MORPHED = "admin:morphed";
const OPENS = "dialog, details";
const PARTS = ["main", ".top-bar", "[data-palette]"];
const TYPED = "input, textarea, select, [contenteditable]";
const WAIT = 1000;
const HOLD = `dialog:modal, ${ASKING}, ${MENU}`;

export const MORPHED_PARTS = PARTS.join(", ");

const edits = trackEdits();
let morphs = 0;
let started = false;

export function forgetEdits(form) {
  for (const control of form.elements) edits.delete(control);
}

export function morphPage(next) {
  const typing = Boolean(document.activeElement?.matches(TYPED));
  morphs += 1;
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
    if (!next || document.querySelector(HOLD)) return;

    const drawn = next;
    next = null;
    if (asked === morphs) morphPage(drawn);
    else refetch.later();
  };

  const refetch = setupFetch({
    request: () => {
      asked = morphs;
      return { url: window.location.href, redirect: "manual" };
    },
    done: (html) => {
      next = parse(html);
      morph();
    },
  });

  let missed = false;
  const changed = () => {
    missed = document.hidden;
    if (!missed) refetch.later();
  };

  document.addEventListener("close", morph, true);
  document.addEventListener("visibilitychange", () => {
    if (missed) changed();
  });
  listen(url, changed);
}

function keepsOpen(name, node, change) {
  return !(change === "remove" && name === "open" && node.matches(OPENS));
}

function trackEdits() {
  const edited = new WeakSet();

  document.addEventListener("input", (event) => edited.add(event.target), true);
  document.addEventListener("reset", (event) => forgetEdits(event.target), true);

  return edited;
}

function untouched(node) {
  const controls = node instanceof HTMLFormElement ? [...node.elements] : [node];
  return !controls.some((control) => edits.has(control));
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
      if (opened) changed();
      opened = true;
      wait = WAIT;
    });
    current.addEventListener("change", changed);
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
