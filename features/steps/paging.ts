import { expect } from "@playwright/test";
import { keep, recall } from "../support/api.ts";
import { chicagoDay, type Http } from "../support/http.ts";
import { rpc } from "../support/mcp.ts";
import { Given, Then, When } from "../support/world.ts";

const seeds: Record<string, (count: number) => string> = {
  list_mail_threads: (count) => `
    INSERT INTO mail_accounts (provider, name) VALUES ('gmail', 'Inbox');
    INSERT INTO mail_threads (mail_account_id, subject, received_at)
    SELECT 1, 'Thread ' || n, now() - n * interval '1 minute' FROM generate_series(1, ${count}) AS n`,
  list_posts: (count) => `
    INSERT INTO posts (title, slug, status, published_at, body, body_html, read_time, word_count, webmentions_enabled)
    SELECT 'Post ' || n, 'post-' || n, 'published', now() - n * interval '1 minute', 'a', '<p>a</p>', 1, 1, false
    FROM generate_series(1, ${count}) AS n`,
  list_social_posts: (count) => `
    INSERT INTO social_posts (targets, status, posted_at)
    SELECT '{mastodon}', 'posted', now() - n * interval '1 minute' FROM generate_series(1, ${count}) AS n;
    INSERT INTO social_post_parts (social_post_id, position, body) SELECT id, 1, 'Part' FROM social_posts`,
  list_suggestions: (count) => `
    INSERT INTO posts (title, slug, status, body, body_html, read_time, word_count, webmentions_enabled)
    SELECT 'Post ' || n, 'post-' || n, 'draft', 'a', '<p>a</p>', 1, 1, false FROM generate_series(1, ${count}) AS n;
    INSERT INTO suggestions (post_id, created_at) SELECT id, now() - id * interval '1 minute' FROM posts;
    INSERT INTO suggestion_edits (suggestion_id, position, original, replacement, reason) SELECT id, 1, 'a', 'b', 'typo' FROM suggestions`,
  list_tags: (count) => `
    INSERT INTO tags (name, color, scope) SELECT 'tag-' || n, 'mk-green', 'public' FROM generate_series(1, ${count}) AS n`,
  list_webmentions: (count) => `
    INSERT INTO posts (title, slug, status, published_at, body, body_html, read_time, word_count, webmentions_enabled)
    VALUES ('Post', 'post', 'published', now() - interval '1 day', 'a', '<p>a</p>', 1, 1, true);
    INSERT INTO webmentions (post_id, source_url, type, received_at)
    SELECT 1, 'https://203.0.113.5/' || n, 'mention', now() - n * interval '1 minute' FROM generate_series(1, ${count}) AS n`,
};

const day = (ago: number) => chicagoDay(-ago);

const argsFor = (tool: string): Record<string, unknown> => {
  if (["list_social_posts", "list_mail_threads", "list_webmentions", "list_suggestions"].includes(tool)) {
    return { from: day(1), to: day(0) };
  }
  if (tool === "list_tags") return { scope: "public" };
  return {};
};

const keyFor: Record<string, string> = {
  list_mail_threads: "mail_threads",
  list_posts: "posts",
  list_social_posts: "social_posts",
  list_suggestions: "suggestions",
  list_tags: "tags",
  list_webmentions: "webmentions",
};

const page = async (
  request: import("@playwright/test").APIRequestContext,
  http: Http,
  token: string | undefined,
  tool: string,
  extra: Record<string, unknown> = {},
) => {
  http.last = await rpc(request, token, "tools/call", { arguments: { ...argsFor(tool), ...extra }, name: tool });
  http.body = await http.last.text();
  const result = JSON.parse(http.body).result;
  return result.isError ? { isError: true } : JSON.parse(result.content[0].text);
};

Given("{int} rows that {word} lists", async ({ app }, count: number, tool: string) => {
  await app.sql.unsafe(seeds[tool](count)).simple();
});

When("I read every row {word} lists, two pages of it", async ({ http, request, tokens }, tool: string) => {
  const first = await page(request, http, tokens.mcp, tool);
  const second = await page(request, http, tokens.mcp, tool, { page: 2 });
  keep(http, "first", JSON.stringify(first));
  keep(http, "second", JSON.stringify(second));
});

Then("the first page of {word} holds 100 rows, says more remain and names page 2", ({ http }, tool: string) => {
  const first = JSON.parse(String(recall(http, "first")));
  expect(first[keyFor[tool]]).toHaveLength(100);
  expect([first.partial, first.next_page]).toEqual([true, 2]);
});

Then(
  "page 2 of {word} holds the {int} rows after them and says it is whole",
  ({ http }, tool: string, count: number) => {
    const first = JSON.parse(String(recall(http, "first")));
    const second = JSON.parse(String(recall(http, "second")));
    const ids = (answer: Record<string, { id: number }[]>) => answer[keyFor[tool]].map(({ id }) => id);
    expect(ids(second)).toHaveLength(count);
    expect(ids(second).filter((id) => ids(first).includes(id))).toEqual([]);
    expect(second.partial).toBe(false);
    expect(second).not.toHaveProperty("next_page");
  },
);

Then("{word} answers no rows on page {int}", async ({ http, request, tokens }, tool: string, number: number) => {
  const answer = await page(request, http, tokens.mcp, tool, { page: number });
  expect(answer[keyFor[tool]]).toEqual([]);
});

Then("{word} refuses page {int}", async ({ http, request, tokens }, tool: string, number: number) => {
  expect((await page(request, http, tokens.mcp, tool, { page: number })).isError).toBe(true);
});

Then(
  "paging {word} with {string} over two pages finds {int} rows, none of them {string}",
  async ({ http, request, tokens }, tool: string, filter: string, count: number, left: string) => {
    const extra = JSON.parse(filter);
    const first = await page(request, http, tokens.mcp, tool, extra);
    const second = await page(request, http, tokens.mcp, tool, { ...extra, page: 2 });
    const rows = [...first[keyFor[tool]], ...second[keyFor[tool]]] as Record<string, unknown>[];
    expect(rows).toHaveLength(count);
    expect(JSON.stringify(rows)).not.toContain(left);
  },
);

When("I page through list_posts' social posts", async ({ http, request, tokens }) => {
  const first = await page(request, http, tokens.mcp, "list_posts");
  const second = await page(request, http, tokens.mcp, "list_posts", { page: 2 });
  keep(http, "first", JSON.stringify(first));
  keep(http, "second", JSON.stringify(second));
});

Then(
  "the social posts come drafts newest first, then the queue soonest first, with no posts",
  async ({ app, http }) => {
    const first = JSON.parse(String(recall(http, "first")));
    const second = JSON.parse(String(recall(http, "second")));
    const drafts = (await app.sql`SELECT id FROM social_posts WHERE status = 'draft' ORDER BY id DESC`).map(
      ({ id }) => id,
    );
    const queued = (await app.sql`SELECT id FROM social_posts WHERE status = 'scheduled' ORDER BY posted_at, id`).map(
      ({ id }) => id,
    );
    const ids = [...first.social_posts, ...second.social_posts].map(({ id }: { id: number }) => id);
    expect(ids).toEqual([...drafts, ...queued]);
    expect([first.posts, first.partial, first.next_page]).toEqual([[], true, 2]);
  },
);

Then(
  "paging list_posts with the range of the last day over two pages finds {int} rows, none of them {string}",
  async ({ http, request, tokens }, count: number, left: string) => {
    const extra = { from: day(1) };
    const first = await page(request, http, tokens.mcp, "list_posts", extra);
    const second = await page(request, http, tokens.mcp, "list_posts", { ...extra, page: 2 });
    const rows = [...first.posts, ...second.posts];
    expect(rows).toHaveLength(count);
    expect(JSON.stringify(rows)).not.toContain(left);
  },
);
