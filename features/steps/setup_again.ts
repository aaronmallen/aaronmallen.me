import { expect } from "@playwright/test";
import { Then, When } from "../support/world.ts";

type Counted = { closes: number };

When("the admin page swaps in new markup and hears two morphs", async ({ page }) => {
  await page.evaluate(() => {
    for (const part of document.querySelectorAll("main, .top-bar, [data-palette], [data-key-help]")) {
      const html = part.outerHTML;
      if (part.isConnected) part.outerHTML = html;
    }
    document.dispatchEvent(new Event("admin:morphed"));
    document.dispatchEvent(new Event("admin:morphed"));
  });
});

When("I count the dialog closes", async ({ page }) => {
  await page.evaluate(() => {
    const counted = window as unknown as Counted;
    const close = HTMLDialogElement.prototype.close;
    counted.closes = 0;
    HTMLDialogElement.prototype.close = function (...args) {
      counted.closes += 1;
      close.apply(this, args);
    };
  });
});

Then("dialogs closed {int} time(s)", async ({ page }, count: number) => {
  expect(await page.evaluate(() => (window as unknown as Counted).closes)).toBe(count);
});

Then("the palette picks its second shown row", async ({ page }) => {
  await expect
    .poll(() =>
      page.evaluate(() => {
        const picked = document.querySelector("[data-palette-option][aria-selected='true']")?.id;
        return Boolean(picked) && picked === document.querySelectorAll("[data-palette-option]:not([hidden])")[1]?.id;
      }),
    )
    .toBe(true);
});

const picks = new WeakMap<object, string>();

When("I pick the theme the avatar menu does not mark", async ({ page }) => {
  await page.locator("button.avatar").click();
  const choice = page.locator(".avatar-menu-item[data-theme-choice][aria-pressed='false']").first();
  picks.set(page, (await choice.getAttribute("data-theme-choice")) ?? "");
  await choice.click();
});

Then("the avatar menu marks the theme I picked", async ({ page }) => {
  const picked = picks.get(page);
  expect(picked).toBeTruthy();
  await expect(page.locator(`.avatar-menu-item[data-theme-choice='${picked}'][aria-pressed='true']`)).toBeVisible();
});
