import { fresh } from "./fresh.js";

const FORMAT = /^[a-z0-9]+(-[a-z0-9]+)*$/;

const ready = new WeakSet();

export function setupMessageLabels() {
  for (const form of fresh(ready, document.querySelectorAll("[data-message-label]"))) setupMessageLabel(form);
}

function setupMessageLabel(form) {
  const find = form.querySelector("[data-message-label-find]");
  const template = form.querySelector("[data-message-label-template]");
  const create = form.querySelector("[data-message-label-create]");
  const bad = form.querySelector("[data-message-label-bad]");
  const empty = form.querySelector("[data-message-label-empty]");
  const count = form.querySelector("[data-message-label-count]");
  const choices = () => [...form.querySelectorAll("[data-message-label-choice]")];
  const named = (name) => choices().find((choice) => choice.dataset.messageLabelChoice === name);
  const typed = () => find.value.trim().replace(/^#/, "").toLowerCase();

  const show = () => {
    const name = typed();
    const ok = FORMAT.test(name);

    for (const choice of choices()) choice.hidden = name !== "" && !choice.dataset.messageLabelChoice.includes(name);
    create.hidden = name === "" || Boolean(named(name));
    create.disabled = !ok;
    create.lastElementChild.textContent = create.dataset.messageLabelCreate.replace("{name}", name);
    bad.hidden = name === "" || ok;
    empty.hidden = name !== "" || choices().length > 0;
    find.setAttribute("aria-invalid", String(!bad.hidden));
  };

  const tally = () => {
    const on = choices().filter((choice) => choice.querySelector("input").checked).length;
    count.textContent = count.dataset.messageLabelCount.replace("{count}", String(on));
  };

  const add = (name) => {
    const choice = template.content.firstElementChild.cloneNode(true);
    choice.dataset.messageLabelChoice = name;
    choice.querySelector("input").value = name;
    choice.querySelector("input").checked = true;
    choice.querySelector(".tag").textContent = `#${name}`;

    const after = choices().find((other) => other.dataset.messageLabelChoice > name);
    after ? after.before(choice) : template.before(choice);
  };

  const pick = () => {
    const name = typed();
    const choice = named(name);
    if (choice) choice.querySelector("input").click();
    else if (FORMAT.test(name)) add(name);
    else return;

    find.value = "";
    show();
    tally();
    find.focus();
  };

  find.addEventListener("input", show);
  find.addEventListener("keydown", (event) => {
    if (event.key !== "Enter") return;

    event.preventDefault();
    pick();
  });
  create.addEventListener("click", pick);
  form.addEventListener("change", tally);
}
