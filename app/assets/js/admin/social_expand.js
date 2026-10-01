const PEOPLE = "[data-social-people]";
const TOKEN = /@\{([^{}\s]+)\}/g;

const parsed = new WeakMap();

export function expand(text, network) {
  const names = handles()[network] ?? {};

  return text.replace(TOKEN, (_token, key) => names[key] ?? key);
}

export function mentions(text) {
  return text.search(TOKEN) !== -1;
}

function handles() {
  const element = document.querySelector(PEOPLE);
  if (!element) return {};
  if (!parsed.has(element)) parsed.set(element, JSON.parse(element.dataset.socialPeople));

  return parsed.get(element);
}
