import { expect } from "@playwright/test";
import { insertPost, slugFor } from "../support/rows.ts";
import { Given, Then, When } from "../support/world.ts";

Given("a post {string} that takes webmentions", async ({ app }, title: string) => {
  await insertPost(app.sql, { publishedAt: new Date(), status: "published", title, webmentions: true });
});

Given(
  "the page {string} replies to the post {string} as {string}",
  ({ app, stub }, source: string, title: string, author: string) => {
    const body = `
      <div class="h-entry">
        <a class="p-author h-card" href="${new URL("/", source)}">${author}</a>
        <p class="e-content">Lovely work on <a href="${app.url}/writing/${slugFor(title)}">${title}</a>.</p>
      </div>`;
    stub.reply("GET", source, { body, status: 200 });
  },
);

When("{string} sends a webmention for the post {string}", async ({ app, request }, source: string, title: string) => {
  const response = await request.post("/webmention", {
    form: { source, target: `${app.url}/writing/${slugFor(title)}` },
  });

  expect(response.status()).toBe(202);
});

Then("the inbox lists a webmention from {string}", async ({ page }, author: string) => {
  await expect
    .poll(async () => {
      await page.goto("/admin/inbox");
      return page.getByText(author).count();
    })
    .toBeGreaterThan(0);
});
