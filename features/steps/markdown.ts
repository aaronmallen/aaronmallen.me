import { expect } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { insertPost, slugFor } from "../support/rows.ts";
import { Given, Then, When } from "../support/world.ts";

Given("a published post {string} whose Markdown body is:", async ({ app }, title: string, body: string) => {
  await insertPost(app.sql, { body, publishedAt: new Date(Date.now() - 60_000), status: "published", title });
});

When("the rerender posts job runs", async ({ app }) => {
  await app.pushJob("Posts::Jobs::RerenderPosts");
});

When("I read the post {string}", async ({ app, page }, title: string) => {
  await expect
    .poll(async () => {
      const [{ body, body_html }] = await app.sql`SELECT body, body_html FROM posts WHERE title = ${title}`;
      return body_html === `<p>${body}</p>`;
    })
    .toBe(false);
  await page.goto(`/writing/${slugFor(title)}`);
});

const headings = "article :is(h2, h3, h4):not(.toc *):not(.kicker)";

Then("the post's headings are:", async ({ page }, table: DataTable) => {
  const found = await page
    .locator(headings)
    .evaluateAll((nodes) =>
      nodes.map((node) => ({ id: node.id, level: node.tagName.toLowerCase(), text: node.textContent?.trim() ?? "" })),
    );

  expect(found).toEqual(table.hashes());
});

Then("no heading holds an anchor link", async ({ page }) => {
  await expect(page.locator(`${headings} a[href^="#"]`)).toHaveCount(0);
});

Then("the contents list {string}", async ({ page }, items: string) => {
  await expect(page.locator(".toc li")).toHaveText(items.split(", "));
});

Then("the post shows no contents list", async ({ page }) => {
  await expect(page.locator(".toc")).toHaveCount(0);
});
