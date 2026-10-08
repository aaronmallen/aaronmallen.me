import { Idiomorph } from "idiomorph";
import { ASKING } from "./confirm.js";
import { setupFetch } from "./fetching.js";
import { parse } from "./in_place.js";

const LONGEST_WAIT = 30000;
const MORPHED = "admin:morphed";
const PARTS = ["main", ".top-bar", "[data-palette]"];
const WAIT = 1000;
const HOLD = `dialog:modal, ${ASKING}`;

let started = false;

export function setupLive() {
  const url = document.querySelector("[data-live]")?.dataset.live;
  if (started || !url) return;

  started = true;
  let next = null;

  const morph = () => {
    if (!next || document.querySelector(HOLD)) return;

    for (const selector of PARTS) {
      const now = document.querySelector(selector);
      const drawn = next.querySelector(selector);
      if (now && drawn) Idiomorph.morph(now, drawn, { ignoreActiveValue: true });
    }

    next = null;
    document.dispatchEvent(new Event(MORPHED));
  };

  const refetch = setupFetch({
    request: () => ({ url: window.location.href, redirect: "manual" }),
    done: (html) => {
      next = parse(html);
      morph();
    },
  });

  document.addEventListener("close", morph, true);
  listen(url, () => refetch.later());
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
