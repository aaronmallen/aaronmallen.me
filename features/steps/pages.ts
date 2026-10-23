import AxeBuilder from "@axe-core/playwright";
import { expect } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
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

When("I visit {string}", async ({ answer, page }, path: string) => {
  answer.status = (await page.goto(path))?.status() ?? 0;
});

When("I post to {string} from the page with:", async ({ answer, page }, path: string, table: DataTable) => {
  const token = await page.locator("input[name='_csrf_token']").first().inputValue();
  const response = await page.request.post(path, {
    form: { _csrf_token: token, ...table.rowsHash() },
    maxRedirects: 0,
  });
  answer.headers = response.headers();
  answer.status = response.status();
  answer.body = await response.text();
});

Given("the admin scripts do not load", async ({ context }) => {
  await context.route(/\/assets\/.*\.js$/, (route) => route.abort());
});

Then("the server answers {int}", ({ answer }, status: number) => {
  expect(answer.status).toBe(status);
});

Then("the toast says {string}", async ({ page }, text: string) => {
  await expect(page.locator(".toast").filter({ hasText: text }).first()).toBeVisible();
});

When("I click {string}", async ({ page }, name: string) => {
  const target = (exact: boolean) =>
    page
      .getByRole("button", { exact, name })
      .or(page.getByRole("link", { exact, name }))
      .or(page.getByRole("menuitem", { exact, name }))
      .first();
  await target(false).waitFor();
  await ((await target(true).isVisible()) ? target(true) : target(false)).click();
});

When("I fill in {string} with {string}", async ({ page }, label: string, text: string) => {
  const exact = page.getByLabel(label, { exact: true }).first();
  await ((await exact.count()) ? exact : page.getByLabel(label).first()).fill(text);
});

When("I press {string}", async ({ page }, key: string) => {
  await page.keyboard.press(key);
});

Then("I do not see {string}", async ({ page }, text: string) => {
  await expect(page.getByText(text)).toHaveCount(0);
});

Then("I am on {string}", async ({ page }, path: string) => {
  await expect(page).toHaveURL((url) => `${url.pathname}${url.search}` === path);
});

Then("the answer shows {string}", ({ answer }, text: string) => {
  expect(answer.body).toContain(text);
});
