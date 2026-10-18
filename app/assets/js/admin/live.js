import { Idiomorph } from "idiomorph";
import { ASKING } from "./confirm.js";
import { MENU } from "./context_menu.js";
import { setupFetch } from "./fetching.js";
import { parse } from "./in_place.js";
import { showToast } from "./toast.js";

const CATCH_UP = "*";
const FAILED = "[data-live-failed]";
const KEEP = "data-live-keep";
const LONGEST_WAIT = 30000;
const OPENS = "dialog, details";
const PARTS = ["main", ".top-bar", "[data-palette]"];
const TYPED = "input, textarea, select, [contenteditable]";
const WAIT = 1000;

export const MORPHED = "admin:morphed";
export const MORPHED_PARTS = PARTS.join(", ");
export const UNHELD = "admin:unheld";

const edits = trackEdits();
let shown = drawnAt(document);
let leaving = false;
let posts = 0;
let refetch = null;
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
        callbacks: { beforeNodeMorphed: morphs, beforeNodeRemoved: keepsEdits, beforeAttributeUpdated: keepsOpen },
      });
  }

  morphed();
}

export function morphed() {
  document.dispatchEvent(new Event(MORPHED));
}

export function release() {
  document.dispatchEvent(new Event(UNHELD));
}

export function bootLive() {
  const url = document.querySelector("[data-live]")?.dataset.live;
  if (!url) return;

  let asked = 0;
  let askedFor = null;
  let next = null;
  let warned = false;

  const morph = () => {
    if (!next || leaving || held()) return;

    const page = next;
    next = null;
    if (drawnAt(page) > shown) morphPage(page);
  };

  refetch = setupFetch({
    marks: document.documentElement,
    queue: true,
    request: () => {
      asked = wanted;
      askedFor = window.location.href;
      return { url: askedFor, redirect: "manual" };
    },
    done: (html) => {
      warned = false;
      if (askedFor !== window.location.href) return refetch.later();

      next = parse(html);
      if (wanted === asked) wanted = 0;
      morph();
    },
    failed: (error) => {
      if (error.cause?.type === "opaqueredirect") return window.location.reload();
      if (warned) return;

      warned = true;
      showToast(document.querySelector(FAILED)?.dataset.liveFailed ?? "", { failed: true });
    },
  });

  let missed = false;
  const want = (at) => {
    wanted = Math.max(wanted, at);
    missed = document.hidden;
    if (!missed && !posts) refetch.later();
  };
  const changed = (at) => {
    if (!leaving && at >= shown) want(at);
  };
  const missedChanges = () => {
    shown = 0;
    if (!leaving) want(Infinity);
  };

  document.addEventListener(UNHELD, morph);
  document.addEventListener("close", morph, true);
  document.addEventListener("visibilitychange", () => {
    if (!missed) return;
    if (wanted === Infinity) missedChanges();
    else changed(wanted);
  });
  listen(url, changed, missedChanges);
}

function drawnAt(page) {
  return Number(page.querySelector("[data-live-at]")?.dataset.liveAt) || 0;
}

function held() {
  return document.querySelector(`dialog:modal:not([data-dialog-live]), ${ASKING}, ${MENU}`) !== null;
}

function keepsEdits(node) {
  return !(node instanceof HTMLFormElement) || untouched(node);
}

function keepsOpen(name, node, change) {
  return !(change === "remove" && name === "open" && node.matches(OPENS));
}

function morphs(node) {
  return !node.hasAttribute?.(KEEP) && untouched(node);
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

function listen(url, changed, missedChanges) {
  let heard = 0;
  let opened = false;
  let source = null;
  let timer = null;
  let wait = WAIT;

  const connect = () => {
    const current = new EventSource(url);
    source = current;

    current.addEventListener("open", () => {
      if (opened) missedChanges();
      opened = true;
      wait = WAIT;
    });
    current.addEventListener("change", (event) => {
      const at = Number(event.lastEventId) || 0;
      if (shows(event.data)) {
        if (at) changed(at);
        else missedChanges();
      }
      heard = Math.max(heard, at);
      document.documentElement.dataset.liveHeard = heard;
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
