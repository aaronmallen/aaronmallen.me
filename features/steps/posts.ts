import { expect } from "@playwright/test";
import { insertPost } from "../support/rows.ts";
import { Given, Then, When } from "../support/world.ts";

const hour = 60 * 60 * 1000;

Given("a post {string} published an hour ago", async ({ app }, title: string) => {
  await insertPost(app.sql, { publishedAt: new Date(Date.now() - hour), status: "published", title });
});

Given("a post {string} scheduled for an hour ago", async ({ app }, title: string) => {
  await insertPost(app.sql, { publishedAt: new Date(Date.now() - hour), status: "scheduled", title });
});

When("the due posts job runs", async ({ app }) => {
  await app.pushJob("Posts::Jobs::PublishDuePosts");
});

Then("the home page lists {string}", async ({ page }, title: string) => {
  await expect
    .poll(async () => {
      await page.goto("/");
      return page.locator(".entry .entry-title").allTextContents();
    })
    .toContain(title);
});

Then("the home page lists nothing under writing", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator(".entry")).toHaveCount(0);
});
