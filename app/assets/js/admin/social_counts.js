import { expand } from "./social_expand.js";

const ENCODER = new TextEncoder();
const FULL = 100;
const LINK = /(?<![\w@])https?:\/\/[^\s<>"]*[^\s<>".,;:!?]/gi;
const MENTION = /@(\w[\w.-]*)@[\w-]+(?:\.[\w-]+)+/g;
const OPENER = { ")": "(", "]": "[" };
const REF = /(?:^|&)ref=/;
const RESERVED_PER_URL = 23;
const SEGMENTER = new Intl.Segmenter(undefined, { granularity: "grapheme" });

const COUNTS = {
  bluesky: (text) => graphemes(text),
  mastodon: (text) => graphemes(shrinkLinks(text).replace(MENTION, "@$1")),
};

export function renderCounts(root, text, selected) {
  const counters = [...root.querySelectorAll("[data-social-count]")];

  return counters.map((counter) => renderCount(counter, text, selected)).some(Boolean);
}

export function selectedTargets(root) {
  const boxes = [...root.querySelectorAll("[data-social-target]")];

  return new Set(boxes.filter((box) => box.checked).map((box) => box.value));
}

function graphemes(text) {
  let count = 0;
  for (const _grapheme of SEGMENTER.segment(text)) count += 1;

  return count;
}

function hostname(address) {
  try {
    return new URL(address).hostname;
  } catch {
    return "";
  }
}

function renderCount(counter, typed, selected) {
  const network = counter.dataset.socialCount;
  const text = expand(tagLinks(typed, counter.dataset.taggedHost, network), network);
  const limit = Number(counter.dataset.limit);
  const count = COUNTS[network](text);
  const on = selected.has(network);
  const blown = count > limit || overBytes(counter, text);
  const over = on && blown;

  counter.querySelector("[data-social-count-text]").textContent = counter.dataset.template.replace("%{count}", count);
  counter.querySelector("[data-social-meter]").style.width = `${blown ? FULL : Math.floor((count * FULL) / limit)}%`;
  counter.classList.toggle("off", !on);
  counter.classList.toggle("over", over);

  return over;
}

function overBytes(counter, text) {
  const maxBytes = Number(counter.dataset.maxBytes ?? 0);

  return maxBytes > 0 && ENCODER.encode(text).length > maxBytes;
}

function proseClose(url) {
  const close = url.at(-1);
  const open = OPENER[close];

  return open !== undefined && tally(url, close) > tally(url, open);
}

function shrinkLinks(text) {
  return text.replace(LINK, (match) => "x".repeat(RESERVED_PER_URL) + match.slice(trimLink(match).length));
}

function splitAt(text, char) {
  const at = text.indexOf(char);

  return at === -1 ? [text, null] : [text.slice(0, at), text.slice(at + 1)];
}

function tagLink(url, host, source) {
  const [head, fragment] = splitAt(url, "#");
  const [address, query] = splitAt(head, "?");
  if (!host || hostname(address) !== host || REF.test(query ?? "")) return url;

  const path = /^https?:\/\/[^/]*$/i.test(address) ? `${address}/` : address;
  const tagged = `${path}?${query ? `${query}&` : ""}ref=${source}`;

  return fragment === null ? tagged : `${tagged}#${fragment}`;
}

function tagLinks(text, host, source) {
  return text.replace(LINK, (match) => {
    const url = trimLink(match);

    return tagLink(url, host, source) + match.slice(url.length);
  });
}

function tally(text, char) {
  return text.split(char).length - 1;
}

function trimLink(url) {
  let trimmed = url;
  while (proseClose(trimmed)) trimmed = trimmed.slice(0, -1);

  return trimmed;
}
