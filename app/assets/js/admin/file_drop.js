import { Idiomorph } from "idiomorph";
import { fresh } from "./fresh.js";
import { load } from "./in_place.js";
import { showToast } from "./toast.js";

const FIELD = "files[]";
const MORPHED = "admin:morphed";
const OVER = "file-drop-on";

const ready = new WeakSet();

export function setupFileDrops() {
  for (const form of fresh(ready, document.querySelectorAll("[data-file-drop]"))) setup(form);
}

function setup(form) {
  const input = form.querySelector("input[type=file]");
  const status = form.querySelector("[data-file-drop-status]");
  const { fileDropBusy, fileDropCopied, fileDropFailed } = form.dataset;

  const upload = async (files) => {
    const data = new FormData(form);
    data.delete(FIELD);
    for (const file of files) data.append(FIELD, file);

    const response = await fetch(form.action, { method: "POST", body: data, headers: { Accept: "application/json" } });
    const answer = await response.json().catch(() => ({}));
    return { ok: response.ok, links: answer.links ?? [], message: answer.message ?? fileDropFailed };
  };

  const send = async (files) => {
    if (files.length === 0) return;

    const idle = status.textContent;
    status.textContent = fileDropBusy;
    form.setAttribute("aria-busy", "true");

    const sent = upload(files).catch(() => ({ ok: false, links: [], message: fileDropFailed }));
    const single = files.length === 1 || form.querySelector("input[type=checkbox][name=group]")?.checked;
    const copied = single ? copyLater(sent.then(only)) : Promise.resolve(false);
    const { ok, links, message } = await sent;

    status.textContent = idle;
    form.removeAttribute("aria-busy");
    if (links.length > 0) await refresh();
    if (!ok) return showToast(message, { failed: true });

    showToast((await copied) ? fileDropCopied : message);
  };

  form.addEventListener("dragover", (event) => {
    if (!event.dataTransfer.types.includes("Files")) return;

    event.preventDefault();
    form.classList.add(OVER);
  });
  form.addEventListener("dragleave", () => form.classList.remove(OVER));
  form.addEventListener("drop", (event) => {
    event.preventDefault();
    form.classList.remove(OVER);
    send([...event.dataTransfer.files]);
  });
  input.addEventListener("change", () => {
    send([...input.files]);
    input.value = "";
  });
}

function only({ links }) {
  if (links.length !== 1) throw new Error("no link");

  return links[0];
}

export function copyLater(link) {
  const written = window.ClipboardItem
    ? navigator.clipboard.write([
        new ClipboardItem({ "text/plain": link.then((text) => new Blob([text], { type: "text/plain" })) }),
      ])
    : link.then((text) => navigator.clipboard.writeText(text));

  return written.then(
    () => true,
    () => false,
  );
}

export async function refresh() {
  const next = await load(window.location.href, "main").catch(() => null);
  if (!next) return window.location.reload();

  show(next);
}

export function show(next) {
  Idiomorph.morph(document.querySelector("main"), next);
  document.dispatchEvent(new Event(MORPHED));
}
