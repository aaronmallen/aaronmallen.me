import { expect, type Locator } from "@playwright/test";
import { Then, When } from "../support/world.ts";

const mores = new WeakMap<import("@playwright/test").Page, Locator>();
const moreOf = (page: import("@playwright/test").Page) => mores.get(page) as Locator;

const box = async (locator: Locator) => {
  const found = await locator.first().boundingBox();
  expect(found, "the element shows").not.toBeNull();
  return found as NonNullable<typeof found>;
};

const moreIn = (page: import("@playwright/test").Page, scope: string) =>
  page.locator(scope).locator(".li").first().or(page.locator(scope).first()).first().locator("[data-menu-more]");

Then(
  "the More button of the first row in {string} is named {string}",
  async ({ page }, scope: string, name: string) => {
    await expect(moreIn(page, scope)).toHaveAttribute("aria-label", name);
  },
);

When("I click the More button of the first row in {string}", async ({ page }, scope: string) => {
  const more = moreIn(page, scope);
  mores.set(page, more);
  await more.hover();
  await more.click();
  await expect(page.locator("[data-context-menu]")).toBeVisible();
});

When(
  "I focus the More button of the first row in {string} and press {word}",
  async ({ page }, scope: string, key: string) => {
    const more = moreIn(page, scope);
    mores.set(page, more);
    await more.evaluate((button) => (button as HTMLElement).focus({ preventScroll: true }));
    await page.keyboard.press(key);
  },
);

When("I press Escape", async ({ page }) => {
  await page.keyboard.press("Escape");
});

Then("the menu opens within {int} pixels below the More button", async ({ page }, gap: number) => {
  const menu = await box(page.locator("[data-context-menu]"));
  const button = await box(moreOf(page));
  expect(menu.y - (button.y + button.height)).toBeGreaterThanOrEqual(0);
  expect(menu.y - (button.y + button.height)).toBeLessThanOrEqual(gap);
});

Then("the More button is marked expanded", async ({ page }) => {
  await expect(moreOf(page)).toHaveAttribute("aria-expanded", "true");
});

Then("the More button is not marked expanded", async ({ page }) => {
  await expect(moreOf(page)).toHaveAttribute("aria-expanded", "false");
});

Then("no dialog is open", async ({ page }) => {
  await expect(page.locator("dialog[open]")).toHaveCount(0);
});

Then("no menu is open", async ({ page }) => {
  await expect(page.locator("[data-context-menu]")).toHaveCount(0);
});

Then("a menu is open", async ({ page }) => {
  await expect(page.locator("[data-context-menu] .ctx-item").first()).toBeVisible();
});

Then("the first menu item has focus", async ({ page }) => {
  await expect(page.locator("[data-context-menu] [data-context-item]").first()).toBeFocused();
});
