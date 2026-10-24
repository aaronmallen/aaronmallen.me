import { readFile } from "node:fs/promises";
import { join } from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { expect, type Page } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { filled } from "../support/api.ts";
import { root } from "../support/shell.ts";
import { Given, Then, When } from "../support/world.ts";

Given("I use a phone", async ({ page }) => {
  await page.setViewportSize({ height: 844, width: 390 });
});

When("I visit the home page", async ({ page }) => {
  await page.goto("/");
});

const breaches = async (page: Page) => {
  const found: string[] = [];
  for (const colorScheme of ["light", "dark"] as const) {
    await page.emulateMedia({ colorScheme });
    const { violations } = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa"])
      .disableRules(["color-contrast"])
      .analyze();
    found.push(
      ...violations.flatMap(({ id, nodes }) => nodes.map((node) => `${colorScheme}: ${id} at ${node.target}`)),
    );
  }
  return found;
};

Then("the page has no axe breaches in light or dark", async ({ page }) => {
  expect(await breaches(page)).toEqual([]);
});

const listed = new WeakMap<Page, string[]>();

Then(
  "every admin GET route in slices\\/admin\\/config\\/routes.rb is a page below or left out for a reason:",
  async ({ page }, table: DataTable) => {
    const routes = await readFile(join(root, "slices/admin/config/routes.rb"), "utf8");
    const gets = [...routes.matchAll(/\bget\(?\s*"([^"]+)"/g)].map(([, route]) => route);
    const rows = table.hashes();
    expect(gets.filter((route) => !rows.some((row) => row.route === route))).toEqual([]);
    expect(rows.filter((row) => !row.page === !row["left out because"]).map((row) => row.route)).toEqual([]);
    listed.set(
      page,
      rows.filter((row) => row.page).map((row) => row.page),
    );
  },
);

Then("each page above answers with no axe breaches in light or dark", async ({ app, page }) => {
  const found: string[] = [];
  await page.route("http://shares.localhost/**", (route) => route.fulfill({ status: 404 }));
  for (const template of listed.get(page) ?? []) {
    let path = template;
    for (const [whole, table, column] of template.matchAll(/\{(\w+)(?:\.(\w+))?\}/g)) {
      const [row] = await app.sql.unsafe(`SELECT ${column ?? "id"} AS value FROM ${table} ORDER BY id LIMIT 1`);
      path = path.replace(whole, encodeURIComponent(String(row?.value)));
    }
    const response = await page.goto(`/admin${path === "/" ? "" : path}`);
    const expected = template === "/nowhere" ? 404 : 200;
    if (response?.status() !== expected) found.push(`${path} answered ${response?.status()}`);
    for (const breach of await breaches(page)) found.push(`${path} ${breach}`);
  }
  expect(found).toEqual([]);
});

Then("the page has a {string} button", async ({ page }, name: string) => {
  await expect(page.getByRole("button", { name })).toBeVisible();
});

When("I visit {string}", async ({ answer, app, http, page }, path: string) => {
  answer.status = (await page.goto(await filled(app.sql, path, http)))?.status() ?? 0;
});

When("I post to {string} from the page with:", async ({ answer, app, page }, path: string, table: DataTable) => {
  const token = await page.locator("input[name='_csrf_token']").first().inputValue();
  const response = await page.request.post(await filled(app.sql, path), {
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
  const exact = page.getByLabel(label, { exact: true }).filter({ visible: true }).first();
  await ((await exact.count()) ? exact : page.getByLabel(label).filter({ visible: true }).first()).fill(text);
});

When("I press {string}", async ({ page }, key: string) => {
  await page.keyboard.press(key);
});

Then("I do not see {string}", async ({ page }, text: string) => {
  await expect(page.getByText(text).filter({ visible: true })).toHaveCount(0);
});

Then("I am on {string}", async ({ page }, path: string) => {
  await expect(page).toHaveURL((url) => `${url.pathname}${url.search}${path.includes("#") ? url.hash : ""}` === path);
});

Then("the answer shows {string}", ({ answer }, text: string) => {
  expect(answer.body).toContain(text);
});
