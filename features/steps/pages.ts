import AxeBuilder from "@axe-core/playwright";
import { expect } from "@playwright/test";
import { Given, Then, When } from "../support/world.ts";

Given("I use a phone", async ({ page }) => {
  await page.setViewportSize({ height: 844, width: 390 });
});

When("I visit the home page", async ({ page }) => {
  await page.goto("/");
});

Then("the page has no axe breaches in light or dark", async ({ page }) => {
  for (const colorScheme of ["light", "dark"] as const) {
    await page.emulateMedia({ colorScheme });
    const { violations } = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa"])
      .disableRules(["color-contrast"])
      .analyze();

    expect(
      violations.flatMap(({ id, nodes }) => nodes.map((node) => `${colorScheme}: ${id} at ${node.target}`)),
    ).toEqual([]);
  }
});

When("I visit {string}", async ({ page }, path: string) => {
  await page.goto(path);
});

When("I click {string}", async ({ page }, name: string) => {
  await page.getByRole("button", { name }).or(page.getByRole("link", { name })).first().click();
});

When("I fill in {string} with {string}", async ({ page }, label: string, value: string) => {
  await page.getByLabel(label).fill(value);
});

Then("I do not see {string}", async ({ page }, text: string) => {
  await expect(page.getByText(text)).toHaveCount(0);
});
