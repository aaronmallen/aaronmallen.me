export async function load(url, selector) {
  const response = await fetch(url);
  if (!response.ok) return null;

  return part(await response.text(), selector);
}

export function parse(html) {
  return new DOMParser().parseFromString(html, "text/html");
}

export function part(html, selector) {
  return parse(html).querySelector(selector);
}

export function plain(event) {
  return event.button === 0 && !event.metaKey && !event.ctrlKey && !event.shiftKey && !event.altKey;
}

export function setupPost({ selector, saved, invalid, body = (form) => new FormData(form), live = () => true }) {
  let saving = false;

  const save = async (form) => {
    let response;
    try {
      response = await fetch(form.action, {
        method: "POST",
        body: new URLSearchParams(body(form)),
        redirect: "manual",
      });
    } catch {
      return form.submit();
    }

    if (!live(form) || (await saved(response))) return;

    const next = response.status === 422 ? part(await response.text(), selector) : null;
    if (!next) return form.submit();

    invalid(next);
  };

  return (form) => {
    if (saving) return;

    saving = true;
    save(form).finally(() => {
      saving = false;
    });
  };
}

export function setupVisit() {
  let latest = 0;

  return (url, selector, show) => {
    const ticket = ++latest;
    const current = () => ticket === latest;

    load(url, selector)
      .then((found) => {
        if (!current()) return true;
        if (!found) return false;

        show(found);
        return true;
      })
      .catch(() => false)
      .then((done) => {
        if (!done && current()) window.location.assign(url);
      });
  };
}
