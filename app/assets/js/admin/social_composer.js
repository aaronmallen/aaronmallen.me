import { renderCounts, selectedTargets } from "./social_counts.js";
import { expand, mentions } from "./social_expand.js";
import { setupMentions } from "./social_mentions.js";

const SCHEDULE = "schedule";

export function setupSocialComposers() {
  for (const form of document.querySelectorAll("form[data-social-composer]")) {
    setupComposer(form);
  }
}

function setupComposer(form) {
  const parts = form.querySelector("[data-social-parts]");
  const partTemplate = form.querySelector("[data-social-part-template]");
  const draft = form.querySelector("[data-social-draft]");
  const send = form.querySelector("[data-social-send]");

  const render = () => {
    const selected = selectedTargets(form);
    const bodies = [...parts.querySelectorAll("[data-social-part]")];
    const over = bodies.map((part) => renderPart(part, selected, bodies.length > 1)).some(Boolean);
    const blank = bodies.every((part) => part.querySelector("[data-social-body]").value.trim() === "");

    draft.disabled = blank || selected.size === 0;
    send.disabled = draft.disabled || over;
  };

  const renderMode = () => {
    const later = form.querySelector("input[name='social[mode]']:checked")?.value === SCHEDULE;
    for (const element of form.querySelectorAll("[data-social-now]")) element.hidden = later;
    for (const element of form.querySelectorAll("[data-social-later]")) element.hidden = !later;
  };

  form.querySelector("[data-social-add]").addEventListener("click", () => {
    const part = partTemplate.content.firstElementChild.cloneNode(true);
    parts.append(part);
    part.querySelector("[data-social-body]").focus();
    render();
  });

  parts.addEventListener("click", (event) => {
    const button = event.target.closest("[data-social-remove]");
    if (!button || parts.querySelectorAll("[data-social-part]").length < 2) return;

    button.closest("[data-social-part]").remove();
    render();
  });

  parts.addEventListener("input", render);
  form.addEventListener("change", () => {
    renderMode();
    render();
  });
  setupMentions(form);
  render();
}

function renderPart(part, selected, removable) {
  const text = part.querySelector("[data-social-body]").value;
  part.querySelector("[data-social-remove]").hidden = !removable;
  renderPreview(part.querySelector("[data-social-preview]"), text, selected);

  return renderCounts(part, text, selected);
}

function renderPreview(preview, text, selected) {
  preview.hidden = !mentions(text) || selected.size === 0;

  for (const line of preview.querySelectorAll("[data-social-preview-line]")) {
    const network = line.dataset.socialPreviewLine;
    line.hidden = !selected.has(network);
    line.querySelector("[data-social-preview-text]").textContent = expand(text, network);
  }
}
