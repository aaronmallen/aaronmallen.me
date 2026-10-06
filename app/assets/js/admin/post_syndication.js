import { setupFetch } from "./fetching.js";
import { renderCounts, selectedTargets } from "./social_counts.js";

const SOURCES = "[data-editor-title], [data-editor-slug]";

export function setupPostSyndication() {
  for (const card of document.querySelectorAll("[data-syndication]")) {
    setupCard(card);
  }
}

function setupCard(card) {
  const body = card.querySelector("[data-social-body]");
  const render = () => renderCounts(card, composed(body), selectedTargets(card));

  card.addEventListener("input", render);
  card.addEventListener("change", render);
  setupPreview(card, body, render);
  render();
}

function composed(body) {
  return body.value.trim() ? body.value : body.dataset.socialPreview;
}

function setupPreview(card, body, render) {
  const form = card.closest("form");
  if (!form) return;

  const empty = body.dataset.socialPlaceholder;
  const preview = setupFetch({
    request: () => ({
      url: card.dataset.syndication,
      method: "POST",
      body: new URLSearchParams(new FormData(form)),
      redirect: "manual",
    }),
    done: (text) => {
      body.dataset.socialPreview = text;
      body.placeholder = text || empty;
      render();
    },
  });

  form.addEventListener("input", (event) => {
    if (event.target.matches(SOURCES)) preview.later();
  });
}
