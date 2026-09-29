export function setupPools() {
  for (const pools of document.querySelectorAll("[data-pools]")) {
    setupPool(pools);
  }
}

function setupPool(pools) {
  const links = pools.querySelectorAll("[data-pool]");
  const panels = pools.querySelectorAll("[data-pool-panel]");

  for (const link of links) {
    link.addEventListener("click", (event) => {
      if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;

      event.preventDefault();
      show(link.dataset.pool, links, panels);
      history.replaceState(history.state, "", link.href);
    });
  }
}

function show(pool, links, panels) {
  for (const link of links) {
    const current = link.dataset.pool === pool;
    link.classList.toggle("current", current);
    if (current) link.setAttribute("aria-current", "true");
    else link.removeAttribute("aria-current");
  }

  for (const panel of panels) {
    panel.hidden = panel.dataset.poolPanel !== pool;
  }
}
