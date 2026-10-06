export function fresh(ready, elements) {
  return [...elements].filter((element) => {
    if (ready.has(element)) return false;

    ready.add(element);
    return true;
  });
}
