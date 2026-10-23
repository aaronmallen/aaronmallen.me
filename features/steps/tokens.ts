import { createHash } from "node:crypto";
import { expect, type Page } from "@playwright/test";
import { Given, Then, When } from "../support/world.ts";

const minted = new WeakMap<Page, string[]>();
const valuesOn = (page: Page) => minted.get(page) ?? [];
const digest = (value: string) => createHash("sha256").update(value).digest("hex");

Given("an API token {string} with the value {string}", async ({ app }, name: string, value: string) => {
  await app.sql`INSERT INTO api_tokens ${app.sql({ name, token_digest: digest(value) })}`;
});

When("I mint a token named {string} in the admin", async ({ page }, name: string) => {
  await page.goto("/admin/settings/services");
  await page.getByLabel("Token name").fill(name);
  await page.getByRole("button", { name: "Mint token" }).click();
  await page.waitForURL(/#tokens$/);
  minted.set(page, [await page.locator("#minted-token").inputValue(), ...valuesOn(page)]);
});

When(
  "I post to {string} with a name of {int} {string}s",
  async ({ http }, path: string, length: number, letter: string) => {
    await http.send("POST", path, {
      form: { _csrf_token: await http.csrf(), "token[name]": letter.repeat(length), "token[scopes][read]": "1" },
    });
  },
);

When("I decline", async ({ page }) => {
  await page.locator("[data-confirm-ask] [data-confirm-decline]").click();
});

Then("the page shows the new token", async ({ page }) => {
  await expect(page.locator("#minted-token")).toHaveValue(/^\S{32,}$/);
});

Then("the page hides the token shown", async ({ page }) => {
  await expect(page.locator("#minted-token")).toHaveCount(0);
  for (const value of valuesOn(page)) expect(await page.content()).not.toContain(value);
});

Then("the two tokens shown differ", ({ page }) => {
  expect(new Set(valuesOn(page)).size).toBe(2);
});

Then("the stored token is the SHA-256 digest of the value shown and never the value", async ({ app, page }) => {
  const [value] = valuesOn(page);
  const [row] = await app.sql`SELECT * FROM api_tokens`;
  expect(row.token_digest).toBe(digest(value));
  expect(Object.values(row).map(String)).not.toContain(value);
});

Then("the API answers GET {string} with the token shown", async ({ page, request }, path: string) => {
  const [value] = valuesOn(page);
  const response = await request.get(path, { headers: { Authorization: `Bearer ${value}` } });
  expect(response.status()).toBe(200);
});

Then("the API refuses GET {string} with {string}", async ({ request }, path: string, value: string) => {
  const response = await request.get(path, { headers: { Authorization: `Bearer ${value}` } });
  expect(response.status()).toBe(401);
});

Then("the checked boxes are {string}", async ({ page }, names: string) => {
  const checked = await page
    .locator("input[type=checkbox][name^='token[scopes]']:checked")
    .evaluateAll((boxes) => boxes.map((box) => box.getAttribute("name")));
  expect(checked.join(", ")).toBe(names);
});

Then("the answer checks only {string}", ({ http }, name: string) => {
  const checked = [...http.body.matchAll(/<input[^>]*type="checkbox"[^>]*>/g)]
    .filter(([input]) => / checked/.test(input) && input.includes('name="token[scopes]'))
    .map(([input]) => input.match(/name="([^"]+)"/)?.[1]);
  expect(checked).toEqual([name]);
});

Then("the answer lists the live tokens {string}", ({ http }, names: string) => {
  const list = http.body.slice(http.body.indexOf('id="tokens"'));
  const titles = [...list.matchAll(/class="li-title"[^>]*>([^<]+)</g)].map(([, title]) => title);
  expect(titles.join(", ")).toBe(names);
});

Then("the page never shows {string}", async ({ page }, text: string) => {
  expect(await page.content()).not.toContain(text);
});
