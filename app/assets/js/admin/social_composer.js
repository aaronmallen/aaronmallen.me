import { fresh } from "./fresh.js";
import { renderCounts, selectedTargets } from "./social_counts.js";
import { expand, mentions } from "./social_expand.js";
import { setupMentions } from "./social_mentions.js";
import { pendingPhotos, renderPhotos, setupPhotos } from "./social_photos.js";
import { setupPicks } from "./social_picks.js";

const SCHEDULE = "schedule";

const ready = new WeakSet();

export function setupSocialComposers() {
  for (const form of fresh(ready, document.querySelectorAll("form[data-social-composer]"))) {
    setupComposer(form);
  }
}

function setupComposer(form) {
  const parts = form.querySelector("[data-social-parts]");
  const partTemplate = form.querySelector("[data-social-part-template]");
  const draft = form.querySelector("[data-social-draft]");
  const send = form.querySelector("[data-social-send]");
  const picked = form.querySelector("[data-social-picked]");

  const render = () => {
    const selected = selectedTargets(form);
    const bodies = [...parts.querySelectorAll("[data-social-part]")];
    const texts = bodies.map((part) => part.querySelector("[data-social-body]").value);
    const over = bodies.map((part, index) => renderPart(part, index + 1, selected, texts)).some(Boolean);
    const blank = bodies.every((part) => part.querySelector("[data-social-body]").value.trim() === "");

    const count = form.querySelectorAll("[data-social-target]:checked").length;
    picked.textContent = picked.dataset.template.replace("%{picked}", count);
    draft.disabled = blank || selected.size === 0 || pendingPhotos(form);
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
  setupPicks(form);
  setupPhotos(form, render);
  render();
}

function renderPart(part, number, selected, texts) {
  const text = texts[number - 1];
  part.querySelector("[data-social-remove]").hidden = texts.length < 2;
  const photos = renderPhotos(part, number);
  renderPreview(part.querySelector("[data-social-preview]"), text, photos, selected);

  return renderCounts(part, text, selected, texts);
}

function renderPreview(preview, text, photos, selected) {
  preview.hidden = (!mentions(text) && photos === 0) || selected.size === 0;

  for (const line of preview.querySelectorAll("[data-social-preview-line]")) {
    const network = line.dataset.socialPreviewLine;
    line.hidden = !selected.has(network);
    line.querySelector("[data-social-preview-text]").textContent = expand(text, network);
  }
}
