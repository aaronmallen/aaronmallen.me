import { expect } from "@playwright/test";
import { Given, Then, When } from "../support/world.ts";
import { ask, lastReply } from "./http.ts";

let kept: { etag?: string; modified?: string } = {};

When("I keep the feed's ETag and time", () => {
  kept = { etag: lastReply().headers.etag, modified: lastReply().headers["last-modified"] };
});

When(
  /^I poll "([^"]*)" with (the ETag|the time|the ETag and the time)$/,
  async ({ app, context }, path: string, what: string) => {
    const headers: Record<string, string> = {};
    if (what.includes("ETag") && kept.etag) headers["If-None-Match"] = kept.etag;
    if (what.includes("time") && kept.modified) headers["If-Modified-Since"] = kept.modified;
    await ask({ app, context }, "GET", path, { headers });
  },
);

Then("the feed's ETag and time have both moved on", () => {
  const { etag, "last-modified": modified } = lastReply().headers;
  expect(etag).not.toBe(kept.etag);
  expect(Date.parse(modified ?? "")).toBeGreaterThan(Date.parse(kept.modified ?? ""));
});

Then("the ETag and Vary on the 304 are the ones the feed gave", () => {
  expect([lastReply().headers.etag, lastReply().headers.vary]).toEqual([kept.etag, "Cookie"]);
});

Then("the {string} header is the time the post {string} last changed", async ({ app }, name: string, title: string) => {
  const [post] = await app.sql`SELECT updated_at FROM posts WHERE title = ${title}`;
  expect(lastReply().headers[name.toLowerCase()]).toBe(new Date(post.updated_at).toUTCString());
});

Given("the post {string} sends its webmentions", async ({ app, stub }, title: string) => {
  const [post] = await app.sql`SELECT id FROM posts WHERE title = ${title}`;
  stub.reply("GET", "http://203.0.113.5/notes/1", {
    body: "<p>a note</p>",
    headers: { Link: '<http://203.0.113.5/wm>; rel="webmention"' },
    status: 200,
  });
  stub.reply("POST", "http://203.0.113.5/wm", { body: "", status: 202 });
  await app.pushJob("Social::Jobs::SendWebmentions", post.id);
  await expect
    .poll(
      async () => (await app.sql`SELECT cardinality(webmention_targets) AS n FROM posts WHERE id = ${post.id}`)[0].n,
    )
    .toBeGreaterThan(0);
});
