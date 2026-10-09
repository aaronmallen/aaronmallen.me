const KEY = "social:accounts";
const SEND = "send";

export function setupPicks(form) {
  if ("socialRestore" in form.dataset) restorePicks(form);

  form.addEventListener("submit", (event) => {
    if (event.submitter?.value === SEND) rememberPicks(form);
  });
}

function boxes(form) {
  return [...form.querySelectorAll("[data-social-target]")];
}

function remembered() {
  try {
    return JSON.parse(localStorage.getItem(KEY)) ?? [];
  } catch {
    return [];
  }
}

function rememberPicks(form) {
  const picked = boxes(form)
    .filter((box) => box.checked)
    .map((box) => box.value);

  try {
    localStorage.setItem(KEY, JSON.stringify(picked));
  } catch {
    return;
  }
}

function restorePicks(form) {
  const ids = remembered();
  const all = boxes(form);
  if (!Array.isArray(ids) || !all.some((box) => ids.includes(box.value))) return;

  for (const box of all) box.checked = ids.includes(box.value);
  all[0].dispatchEvent(new Event("change", { bubbles: true }));
}
