export function setupToc() {
  const pairs = [...document.querySelectorAll(".toc a")]
    .map((link) => [link, document.getElementById(decodeURIComponent(link.hash.slice(1)))])
    .filter(([, heading]) => heading);
  if (!pairs.length || !("IntersectionObserver" in window)) return;

  const mark = (target) => {
    for (const [link, heading] of pairs) {
      if (heading === target) link.setAttribute("aria-current", "location");
      else link.removeAttribute("aria-current");
    }
  };

  const observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) if (entry.isIntersecting) mark(entry.target);
    },
    { rootMargin: "-90px 0px -65% 0px" },
  );

  for (const [, heading] of pairs) observer.observe(heading);
  mark(pairs[0][1]);
}
