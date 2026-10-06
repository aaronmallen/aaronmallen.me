import { fresh } from "./fresh.js";
import { plain } from "./in_place.js";

const LINK = "[data-pool]";

const ready = new WeakSet();

export function setupPools() {
  for (const pools of fresh(ready, document.querySelectorAll("[data-pools]"))) {
    pools.addEventListener("click", (event) => {
      const link = event.target.closest(LINK);
      if (!link || !plain(event)) return;

      event.preventDefault();
      show(pools, link.dataset.pool);
      history.replaceState(history.state, "", link.href);
    });
  }
}

function show(pools, pool) {
  for (const link of pools.querySelectorAll(LINK)) {
    const current = link.dataset.pool === pool;
    link.classList.toggle("current", current);
    if (current) link.setAttribute("aria-current", "page");
    else link.removeAttribute("aria-current");
  }

  for (const panel of pools.querySelectorAll("[data-pool-panel]")) {
    panel.hidden = panel.dataset.poolPanel !== pool;
  }
}
