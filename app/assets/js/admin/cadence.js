import { fresh } from "./fresh.js";

const ready = new WeakSet();

export function setupCadences(root = document) {
  for (const box of fresh(ready, root.querySelectorAll("[data-cadence]"))) {
    const kind = box.querySelector("[data-cadence-kind]");

    kind.addEventListener("change", () => {
      for (const part of box.querySelectorAll("[data-cadence-for]")) {
        const off = !part.dataset.cadenceFor.split(" ").includes(kind.value);

        part.hidden = off;
        for (const control of part.querySelectorAll("input, select")) control.disabled = off;
      }
    });
  }
}
