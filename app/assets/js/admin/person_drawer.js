import { setupConfirms } from "./confirm.js";
import { openDialog } from "./dialog.js";
import { plain, setupVisit } from "./in_place.js";

const BODY = "[data-person-edit-body]";
const DRAWER = "person-edit-drawer";
const EDITOR = "[data-person-editor]";
const OPEN = "a[data-person-edit]";

export function bootPersonDrawer() {
  const visit = setupVisit();

  document.addEventListener("click", (event) => {
    const link = event.target.closest(OPEN);
    const drawer = document.getElementById(DRAWER);
    if (!link || !drawer || event.defaultPrevented || !plain(event)) return;

    event.preventDefault();
    visit(link.href, EDITOR, (editor) => {
      const body = drawer.querySelector(BODY);
      body.replaceChildren(...editor.childNodes);
      setupConfirms(body);
      openDialog(DRAWER);
    });
  });
}
