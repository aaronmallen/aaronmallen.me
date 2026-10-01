import { askForPerson } from "./person_dialog.js";
import { learn } from "./social_expand.js";

const ADD = "[data-social-mention-add]";
const BODY = "[data-social-body]";
const COUNT = "{count}";
const NAME = "{name}";
const CHOICE = "[role='option']";
const GROUP = "[data-social-mention-group]";
const OPTION = "[data-social-mention]";
const REFRESH_KEYS = ["ArrowLeft", "ArrowRight", "End", "Home", "PageDown", "PageUp"];
const SPACE = /^\s/;
const STEPS = { ArrowDown: 1, ArrowUp: -1 };
const TRIGGER = /(?:^|[\s(])@([^\s@{}()]*)$/;

export function setupMentions(form) {
  const list = form.querySelector("[data-social-mentions]");
  if (list) setupList(form, list);
}

function setupList(form, list) {
  const parts = form.querySelector("[data-social-parts]");
  const status = form.querySelector("[data-social-mention-status]");
  const home = list.parentElement;
  const homeNext = list.nextSibling;
  const add = list.querySelector(ADD);
  const choices = () => [...list.querySelectorAll(CHOICE)];
  let body = null;
  let start = 0;

  const shown = () => choices().filter((choice) => !choice.hidden);
  const active = () => choices().find((choice) => choice.getAttribute("aria-selected") === "true");

  const select = (option) => {
    for (const other of choices()) other.setAttribute("aria-selected", String(other === option));
    if (!option) return body?.removeAttribute("aria-activedescendant");

    body?.setAttribute("aria-activedescendant", option.id);
    option.scrollIntoView({ block: "nearest" });
  };

  const close = () => {
    if (list.hidden) return;

    list.hidden = true;
    select(null);
    body = null;
    home.insertBefore(list, homeNext);
  };

  const show = (textarea) => {
    const opening = list.hidden || body !== textarea;

    body = textarea;
    if (textarea.nextElementSibling !== list) textarea.after(list);
    list.style.top = `${textarea.offsetTop + textarea.offsetHeight}px`;
    list.hidden = false;
    if (opening) list.scrollIntoView({ block: "nearest" });
  };

  const filter = (query) => {
    const text = query.toLowerCase();

    for (const option of list.querySelectorAll(OPTION))
      option.hidden = !option.dataset.socialMentionText.includes(text);
    for (const group of list.querySelectorAll(GROUP)) group.hidden = !group.querySelector(`${OPTION}:not([hidden])`);

    return shown();
  };

  const refresh = (textarea) => {
    const query = typed(textarea);
    if (query === null) return close();

    const visible = filter(query);
    const keep = active();
    show(textarea);
    start = textarea.selectionStart - query.length - 1;
    select(visible.includes(keep) ? keep : visible[0]);
    say(status, plural(status, visible.length - 1));
  };

  const mention = (textarea, option, from, to) => {
    const space = SPACE.test(textarea.value.slice(to)) ? "" : " ";

    textarea.setRangeText(`@{${option.dataset.socialMention}}${space}`, from, to, "end");
    textarea.dispatchEvent(new Event("input", { bubbles: true }));
    say(status, status.dataset.socialMentionChosen.replace(NAME, option.dataset.socialMentionName));
  };

  const place = (option) => {
    const group = list.querySelector(`[data-social-mention-group="${option.dataset.socialMentionIn}"]`);
    const name = option.dataset.socialMentionName;
    const after = [...group.querySelectorAll(OPTION)].find(
      (other) => other.dataset.socialMentionName.localeCompare(name) > 0,
    );

    group.insertBefore(option, after ?? null);
  };

  const invite = (textarea) => {
    const from = start;
    const to = textarea.selectionStart;

    close();
    askForPerson(add.href, textarea.value.slice(from + 1, to)).then((added) => {
      if (added) {
        learn(added.people);
        place(added.option);
        mention(textarea, added.option, from, to);
      }
      textarea.focus();
    });
  };

  const choose = (option) => {
    const textarea = body;
    if (option === add) return invite(textarea);

    const end = textarea.selectionStart;

    close();
    mention(textarea, option, start, end);
  };

  const move = (step) => {
    const visible = shown();
    const at = visible.indexOf(active());
    select(visible[Math.min(Math.max(at + step, 0), visible.length - 1)]);
  };

  const steer = (event) => {
    if (event.key in STEPS) move(STEPS[event.key]);
    else if ((event.key === "Enter" || event.key === "Tab") && active()) choose(active());
    else if (event.key === "Escape") close();
    else return;

    event.preventDefault();
  };

  const prepare = (textarea) => {
    textarea.setAttribute("aria-autocomplete", "list");
    textarea.setAttribute("aria-controls", list.id);
    textarea.setAttribute("aria-haspopup", "listbox");
  };

  for (const textarea of parts.querySelectorAll(BODY)) prepare(textarea);

  parts.addEventListener("focusin", (event) => {
    if (event.target.matches(BODY)) prepare(event.target);
  });

  parts.addEventListener("focusout", (event) => {
    if (event.target === body) close();
  });

  parts.addEventListener("input", (event) => {
    if (event.target.matches(BODY)) refresh(event.target);
  });

  parts.addEventListener("keydown", (event) => {
    if (event.isComposing || list.hidden || event.target !== body) return;

    steer(event);
  });

  parts.addEventListener("keyup", (event) => {
    if (REFRESH_KEYS.includes(event.key) && event.target.matches(BODY)) refresh(event.target);
  });

  parts.addEventListener("click", (event) => {
    if (event.target.matches(BODY)) refresh(event.target);
  });

  list.addEventListener("mousedown", (event) => event.preventDefault());

  list.addEventListener("click", (event) => {
    const option = event.target.closest(CHOICE);
    if (!option) return;

    event.preventDefault();
    choose(option);
  });

  list.addEventListener("mousemove", (event) => {
    const option = event.target.closest(CHOICE);
    if (option && option !== active()) select(option);
  });
}

function plural(status, count) {
  const template = count === 1 ? status.dataset.socialMentionResultsOne : status.dataset.socialMentionResultsOther;

  return template.replace(COUNT, String(count));
}

function say(status, text) {
  status.textContent = text;
}

function typed(textarea) {
  if (textarea.selectionStart !== textarea.selectionEnd) return null;

  const match = TRIGGER.exec(textarea.value.slice(0, textarea.selectionStart));

  return match ? match[1] : null;
}
