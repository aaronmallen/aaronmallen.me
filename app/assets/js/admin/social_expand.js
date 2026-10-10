const PEOPLE = "[data-social-people]";

const parsed = new WeakMap();

export function expand(text, network) {
  const { handles, token } = directory();
  const names = handles[network] ?? {};

  return token ? text.replace(token, (_token, key) => names[key] ?? key) : text;
}

export function learn(people) {
  const { handles } = directory();

  for (const [network, names] of Object.entries(people)) handles[network] = { ...handles[network], ...names };
}

export function mentions(text) {
  const { token } = directory();

  return token !== null && text.search(token) !== -1;
}

function directory() {
  const element = document.querySelector(PEOPLE);
  if (!element) return { handles: {}, token: null };
  if (!parsed.has(element)) {
    parsed.set(element, {
      handles: JSON.parse(element.dataset.socialPeople),
      token: new RegExp(element.dataset.socialToken, "gu"),
    });
  }

  return parsed.get(element);
}
