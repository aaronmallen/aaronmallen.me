const ACTS = "[data-bulk-acts]";
const ALL = "[data-bulk-all]";
const COUNT = "[data-bulk-count]";

export function setupBulk(root = document) {
  for (const form of root.querySelectorAll("form[data-bulk]")) {
    const all = form.querySelector(ALL);
    const box = all.querySelector("input");
    const sync = () => show(form, box);

    all.hidden = false;
    box.addEventListener("change", () => {
      for (const pick of picks(form)) pick.checked = box.checked;
      sync();
    });
    document.addEventListener("change", (event) => {
      if (event.target.form === form && event.target !== box) sync();
    });
    window.addEventListener("pageshow", sync);
    sync();
  }
}

function picks(form) {
  return [...form.elements].filter((element) => element.name === form.dataset.bulk);
}

function show(form, box) {
  const shown = picks(form);
  const ticked = shown.filter((pick) => pick.checked).length;
  const count = form.querySelector(COUNT);

  box.checked = ticked > 0 && ticked === shown.length;
  box.indeterminate = ticked > 0 && ticked < shown.length;
  count.textContent = ticked > 0 ? count.dataset.bulkCount.replace("%{count}", ticked) : "";
  form.querySelector(ACTS).hidden = ticked === 0;
}
