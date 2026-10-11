import { uploadPhoto } from "./photo_upload.js";

const MAX = 4;
const PENDING = "socialPhotoPending";
const TOKEN = "_csrf_token";

export function setupPhotos(form, render) {
  const parts = form.querySelector("[data-social-parts]");
  const settings = (part) => part.querySelector("[data-social-photos]").dataset;

  const upload = async (part, file) => {
    const list = part.querySelector("[data-social-photo-list]");
    const template = part.querySelector("[data-social-photo-template]");
    const photo = template.content.firstElementChild.cloneNode(true);
    const image = photo.querySelector("[data-social-photo-img]");
    const preview = URL.createObjectURL(file);
    image.src = preview;
    hold(photo, true);
    list.append(photo);
    render();

    try {
      const token = new FormData(form).get(TOKEN) ?? "";
      const { socialUpload, socialUploadFailed } = settings(part);
      const { key, url } = await uploadPhoto(socialUpload, file, token, socialUploadFailed);
      photo.querySelector("[data-social-photo-key]").value = key;
      image.src = url;
      hold(photo, false);
    } catch (error) {
      photo.remove();
      say(part, error.message);
    } finally {
      URL.revokeObjectURL(preview);
      render();
    }
  };

  const send = (part, files) => {
    if (!part || !settings(part).socialUpload || files.length === 0) return false;

    const room = MAX - part.querySelectorAll("[data-social-photo]").length;
    say(part, files.length > room ? settings(part).socialPhotosFull : "");
    for (const file of files.slice(0, Math.max(room, 0))) upload(part, file);
    return true;
  };

  const partOf = (event) => event.target.closest("[data-social-part]");

  parts.addEventListener("click", (event) => {
    const button = event.target.closest("button");
    const part = button?.closest("[data-social-part]");
    if (!part) return;

    if (button.matches("[data-social-photo-pick]")) part.querySelector("[data-social-photo-file]").click();
    else if (button.matches("[data-social-photo-remove]")) remove(part, button.closest("[data-social-photo]"));
    else if (button.matches("[data-social-photo-move]")) move(button);
    else return;

    render();
  });

  parts.addEventListener("change", (event) => {
    const picker = event.target.closest("[data-social-photo-file]");
    if (!picker) return;

    send(picker.closest("[data-social-part]"), [...picker.files]);
    picker.value = "";
  });

  parts.addEventListener("dragover", (event) => {
    const part = partOf(event);
    if (part && settings(part).socialUpload && event.dataTransfer.types.includes("Files")) event.preventDefault();
  });

  parts.addEventListener("drop", (event) => {
    if (send(partOf(event), [...event.dataTransfer.files])) event.preventDefault();
  });

  parts.addEventListener("paste", (event) => {
    if (event.clipboardData.types.includes("text/plain")) return;
    if (send(partOf(event), [...event.clipboardData.files])) event.preventDefault();
  });
}

export function pendingPhotos(form) {
  return form.querySelector("[data-social-photo-pending]") !== null;
}

export function renderPhotos(part, number) {
  const photos = [...part.querySelectorAll("[data-social-photo]")];
  const count = part.querySelector("[data-social-photo-count]");
  if (count) count.textContent = count.dataset.template.replace("%{count}", photos.length);

  photos.forEach((photo, index) => {
    photo.querySelector("[data-social-photo-part]").value = number;
    photo.querySelector("[data-social-photo-move='-1']").disabled = index === 0;
    photo.querySelector("[data-social-photo-move='1']").disabled = index === photos.length - 1;
  });

  part.querySelector("[data-social-preview-photos]").replaceChildren(
    ...photos.map((photo) => {
      const image = document.createElement("img");
      image.className = "compose-preview-photo";
      image.src = photo.querySelector("[data-social-photo-img]").src;
      image.alt = photo.querySelector("[data-social-photo-alt]").value;
      return image;
    }),
  );

  return photos.length;
}

function hold(photo, pending) {
  if (pending) photo.dataset[PENDING] = "";
  else delete photo.dataset[PENDING];

  for (const field of photo.querySelectorAll("input, textarea")) field.disabled = pending;
}

function move(button) {
  const photo = button.closest("[data-social-photo]");
  const later = button.dataset.socialPhotoMove === "1";
  const sibling = later ? photo.nextElementSibling : photo.previousElementSibling;
  if (!sibling) return;

  if (later) sibling.after(photo);
  else sibling.before(photo);

  const edge = later ? !photo.nextElementSibling : !photo.previousElementSibling;
  const back = photo.querySelector(`[data-social-photo-move="${later ? "-1" : "1"}"]`);
  (edge ? back : button).focus();
}

function remove(part, photo) {
  const next = photo.nextElementSibling ?? photo.previousElementSibling;
  photo.remove();
  say(part, "");
  (next?.querySelector("[data-social-photo-alt]") ?? part.querySelector("[data-social-body]")).focus();
}

function say(part, message) {
  const alert = part.querySelector("[data-social-photo-alert]");
  if (alert) alert.textContent = message;
}
