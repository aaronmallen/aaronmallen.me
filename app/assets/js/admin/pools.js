import { fresh } from "./fresh.js";
import { plain, setupVisit } from "./in_place.js";
import { morphed } from "./live.js";

const LINK = "[data-pool]";
const PANEL = "[data-pool-panel]";

const ready = new WeakSet();

export function setupPools() {
  for (const pools of fresh(ready, document.querySelectorAll("[data-pools]"))) {
    const visit = setupVisit();

    pools.addEventListener("click", (event) => {
      const link = event.target.closest(LINK);
      if (!link || !plain(event)) return;

      event.preventDefault();
      mark(pools, link.dataset.pool);
      visit(link.href, `${PANEL}[data-pool-panel="${link.dataset.pool}"]`, (panel) => {
        pools.querySelector(PANEL).replaceWith(panel);
        morphed();
        history.replaceState(history.state, "", link.href);
      });
    });
  }
}

function mark(pools, pool) {
  for (const link of pools.querySelectorAll(LINK)) {
    const current = link.dataset.pool === pool;
    link.classList.toggle("current", current);
    if (current) link.setAttribute("aria-current", "page");
    else link.removeAttribute("aria-current");
  }
}
