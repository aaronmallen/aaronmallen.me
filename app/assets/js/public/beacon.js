const MAX_READ_SECONDS = 20 * 60;
const MIDDLE_BUTTON = 1;
const SCROLL_DEPTHS = [100, 75, 50, 25];
const TYPE = "application/json";
const WEB = ["http:", "https:"];

const mintToken = () =>
  Array.from(crypto.getRandomValues(new Uint8Array(16)), (byte) => byte.toString(16).padStart(2, "0")).join("");

const depthReached = () => {
  const seen = (100 * Math.ceil(scrollY + innerHeight)) / document.documentElement.scrollHeight;

  return SCROLL_DEPTHS.find((depth) => seen >= depth) ?? 0;
};

const referrerOf = (url) => {
  try {
    const { origin, pathname } = new URL(url);

    return origin === location.origin ? origin + pathname : origin;
  } catch {
    return undefined;
  }
};

const outboundLink = (event) => {
  if (event.type === "auxclick" && event.button !== MIDDLE_BUTTON) return undefined;

  const link = event.target.closest?.("a[href]");
  if (!link || typeof link.href !== "string") return undefined;

  try {
    const { hostname, pathname, protocol } = new URL(link.href);
    if (!WEB.includes(protocol) || hostname === location.hostname) return undefined;

    return { link_host: hostname, link_path: pathname };
  } catch {
    return undefined;
  }
};

export function setupBeacon() {
  const { beacon: endpoint, beaconClicks: clicks, beaconRef: refKey } = document.body.dataset;
  if (!endpoint || !navigator.sendBeacon) return;

  const path = location.pathname;
  const ref = refKey && new URLSearchParams(location.search).get(refKey);
  const viewToken = mintToken();
  let opened = Date.now();
  let read = 0;
  let left = false;
  let deepest = depthReached();

  const send = (visit) => {
    const body = JSON.stringify({ path, view_token: viewToken, ...visit });

    return navigator.sendBeacon(endpoint, new Blob([body], { type: TYPE }));
  };

  const leave = () => {
    if (left) return;
    left = true;
    read += Math.ceil((Date.now() - opened) / 1000);
    send({ kind: "read", read_seconds: Math.min(read, MAX_READ_SECONDS) });
  };

  const readAgain = () => {
    if (!left) return;
    left = false;
    opened = Date.now();
  };

  const scrolled = () => {
    const depth = depthReached();
    if (depth <= deepest) return;
    deepest = depth;
    send({ kind: "scroll", scroll_depth: depth });
  };

  const clicked = (event) => {
    const link = outboundLink(event);
    if (link) send({ kind: "click", ...link });
  };

  addEventListener("pagehide", leave);
  addEventListener("pageshow", (event) => {
    if (event.persisted) readAgain();
  });
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "hidden") leave();
    else readAgain();
  });

  send({
    kind: "view",
    title: document.title,
    referrer: referrerOf(document.referrer),
    ...(ref && { [refKey]: ref }),
    ...(deepest && { scroll_depth: deepest }),
  });
  addEventListener("scroll", scrolled, { passive: true });
  if (clicks === undefined) return;
  document.addEventListener("click", clicked);
  document.addEventListener("auxclick", clicked);
}
