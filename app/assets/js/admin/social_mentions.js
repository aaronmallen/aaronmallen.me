const BODY = "[data-social-body]";
const COUNT = "{count}";
const NAME = "{name}";
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
  const options = [...list.querySelectorAll(OPTION)];
  const groups = [...list.querySelectorAll("[data-social-mention-group]")];
  let body = null;
  let start = 0;

  const shown = () => options.filter((option) => !option.hidden);
  const active = () => options.find((option) => option.getAttribute("aria-selected") === "true");

  const select = (option) => {
    for (const other of options) other.setAttribute("aria-selected", String(other === option));
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

    for (const option of options) option.hidden = !option.dataset.socialMentionText.includes(text);
    for (const group of groups) group.hidden = !group.querySelector(`${OPTION}:not([hidden])`);

    return shown();
  };

  const refresh = (textarea) => {
    const query = typed(textarea);
    if (query === null) return close();

    const visible = filter(query);
    if (visible.length === 0) return close();

    const keep = active();
    show(textarea);
    start = textarea.selectionStart - query.length - 1;
    select(visible.includes(keep) ? keep : visible[0]);
    say(status, plural(status, visible.length));
  };

  const choose = (option) => {
    const textarea = body;
    const end = textarea.selectionStart;
    const space = SPACE.test(textarea.value.slice(end)) ? "" : " ";

    close();
    textarea.setRangeText(`@{${option.dataset.socialMention}}${space}`, start, end, "end");
    textarea.dispatchEvent(new Event("input", { bubbles: true }));
    say(status, status.dataset.socialMentionChosen.replace(NAME, option.dataset.socialMentionName));
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
    const option = event.target.closest(OPTION);
    if (option) choose(option);
  });

  list.addEventListener("mousemove", (event) => {
    const option = event.target.closest(OPTION);
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
