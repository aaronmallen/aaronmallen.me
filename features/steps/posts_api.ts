import { randomBytes } from "node:crypto";
import { type APIRequestContext, expect } from "@playwright/test";
import { heard } from "../support/delivery.ts";
import { seal } from "../support/social.ts";
import { runCount, runJob, waitForRuns } from "../support/webmentions_more.ts";
import { Given, Then, When } from "../support/world.ts";

type Last = { body: string; status: number };

const chicagoDay = (daysAgo = 0) =>
  new Intl.DateTimeFormat("en-CA", { timeZone: "America/Chicago" }).format(new Date(Date.now() - daysAgo * 86_400_000));

async function tool(request: APIRequestContext, token: string | undefined, name: string, args: string, answer?: Last) {
  const response = await request.post("/mcp", {
    data: { id: 1, jsonrpc: "2.0", method: "tools/call", params: { arguments: JSON.parse(args), name } },
    headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${token}` },
  });
  const body = await response.text();
  const result = response.ok() ? JSON.parse(body).result : undefined;
  const mcp = {
    body,
    content: result?.content?.[0]?.text ?? body,
    error: result?.isError ?? false,
    status: response.status(),
  };
  if (answer) Object.assign(answer, mcp);
  const reply = JSON.parse(body);
  expect(reply.result, JSON.stringify(reply)).toBeDefined();
  return reply.result;
}

const without = (value: Record<string, unknown>, keys: string[]) =>
  Object.fromEntries(Object.entries(value).filter(([key]) => !keys.includes(key)));

function shape(value: unknown, keys: string[]): unknown {
  if (Array.isArray(value)) return value.map((item) => shape(item, keys));
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(without(value as Record<string, unknown>, keys)).map(([key, item]) => [key, shape(item, keys)]),
    );
  }
  return value;
}

Given("blog post {int} carries the tag {string}", async ({ app }, id: number, name: string) => {
  const [tag] = await app.sql`
    INSERT INTO tags ${app.sql({ color: "mk-blue", name, scope: "public" })}
    ON CONFLICT DO NOTHING RETURNING id
  `;
  const tagId = tag?.id ?? (await app.sql`SELECT id FROM tags WHERE name = ${name}`)[0].id;
  await app.sql`INSERT INTO post_tags ${app.sql({ post_id: id, tag_id: tagId })}`;
});

Then(
  "the MCP tool {string} answers as the API did, given:",
  async ({ answer, request, tokens }, name: string, args: string) => {
    const api = JSON.parse(answer.body);
    const result = await tool(request, tokens.mcp, name, args);

    expect(JSON.parse(result.content[0].text)).toEqual(api);
  },
);

Then(
  "the MCP tool {string} answers as the API did apart from {string}, given:",
  async ({ answer, request, tokens }, name: string, keys: string, args: string) => {
    const api = JSON.parse(answer.body);
    const result = await tool(request, tokens.mcp, name, args);

    expect(shape(JSON.parse(result.content[0].text), keys.split(" "))).toEqual(shape(api, keys.split(" ")));
  },
);

Then(
  "the MCP tool {string} refuses as the API did, given:",
  async ({ answer, request, tokens }, name: string, args: string) => {
    const api = JSON.parse(answer.body);
    const result = await tool(request, tokens.mcp, name, args);

    expect(result.isError).toBe(true);
    expect(result.content[0].text).toBe(api.message);
  },
);

Then(
  "the MCP tool {string} gives the API's {string}, given:",
  async ({ answer, request, tokens }, name: string, key: string, args: string) => {
    const api = JSON.parse(answer.body);
    const result = await tool(request, tokens.mcp, name, args);

    expect(JSON.parse(result.content[0].text)[key]).toEqual(api[key]);
  },
);

Then("blog post {int} is gone", async ({ app }, id: number) => {
  expect(await app.sql`SELECT id FROM posts WHERE id = ${id}`).toHaveLength(0);
});

Then("blog post {int} is still there", async ({ app }, id: number) => {
  expect(await app.sql`SELECT id FROM posts WHERE id = ${id}`).toHaveLength(1);
});

Then("blog post {int} carries the tags {string}", async ({ app }, id: number, names: string) => {
  const rows = await app.sql`
    SELECT tags.name FROM post_tags JOIN tags ON tags.id = post_tags.tag_id WHERE post_id = ${id} ORDER BY tags.name
  `;
  expect(rows.map((row) => row.name).join(" ")).toBe(names);
});

Then("blog post {int} was published within the last minute", async ({ app }, id: number) => {
  const [post] = await app.sql`SELECT published_at FROM posts WHERE id = ${id}`;
  expect(Math.abs(Date.now() - post.published_at.getTime())).toBeLessThan(60_000);
});

Then("the MCP tool call is refused", ({ answer }) => {
  expect(JSON.parse(answer.body).result.isError, answer.body).toBe(true);
});

Then("the announcement reads the title, a blank line and the link to {string}", ({ answer }, slug: string) => {
  const text = JSON.parse(JSON.parse(answer.body).result.content[0].text).announcement;
  expect(text).toMatch(new RegExp(`^Hello\\n\\nhttps?://\\S+/${slug}$`));
});

When("I call list_posts from {int} days ago", async ({ answer, request, tokens }, days: number) => {
  await tool(request, tokens.mcp, "list_posts", JSON.stringify({ from: chicagoDay(days) }), answer);
});

Given(
  "{string} drew {int} views from {int} visitors and {int} read-throughs today",
  async ({ app }, path: string, views: number, visitors: number, readThroughs: number) => {
    const day = chicagoDay();
    await app.sql`INSERT INTO analytics_rollups ${app.sql({ day, views, visitors })} ON CONFLICT DO NOTHING`;
    await app.sql`
      INSERT INTO analytics_rollup_paths ${app.sql({ bounces: 0, day, path, read_throughs: readThroughs, views, visitors })}
    `;
  },
);

Given("{int} readers read {string}", async ({ app }, count: number, path: string) => {
  for (let reader = 0; reader < count; reader++) {
    await app.sql`INSERT INTO post_reader_hashes ${app.sql({ path, reader_hash: randomBytes(32).toString("hex") })}`;
  }
});

Then("list_posts gives post {int}:", ({ answer }, id: number, json: string) => {
  const { posts } = JSON.parse(JSON.parse(answer.body).result.content[0].text);
  expect(posts.find((post: { id: number }) => post.id === id)).toMatchObject(JSON.parse(json));
});

Then("the MCP call is turned away for want of the {string} permission", ({ answer }, scope: string) => {
  const reply = JSON.parse(answer.body);
  expect(reply.error?.data ?? "", JSON.stringify(reply)).toMatch(new RegExp(`^\\w+ needs the ${scope} permission,`));
});

When(
  "I send the post editor form to {string} with:",
  async ({ answer, page }, path: string, table: import("playwright-bdd").DataTable) => {
    if (!page.url().startsWith("http")) await page.goto("/admin/posts/new");
    const fields = Object.fromEntries(table.raw());
    const token = await page.locator("input[name='_csrf_token']").first().inputValue();
    const response = await page.request.post(path, { form: { _csrf_token: token, ...fields }, maxRedirects: 0 });
    const result = { body: await response.text(), status: response.status() };
    Object.assign(answer, result);
  },
);

Then("blog post {int}'s rendered body holds {string}", async ({ app }, id: number, text: string) => {
  await expect
    .poll(async () => (await app.sql`SELECT body_html FROM posts WHERE id = ${id}`)[0].body_html)
    .toContain(text);
});

Then("edit note {int}'s rendered note reads {string}", async ({ app }, id: number, html: string) => {
  await expect
    .poll(async () => (await app.sql`SELECT note_html FROM post_edits WHERE id = ${id}`)[0].note_html)
    .toBe(html.replaceAll("\\n", "\n"));
});

Given("a Mastodon account on {string} takes announcements", async ({ app }, host: string) => {
  await app.sql`
    INSERT INTO service_connections ${app.sql({
      account_id: "1",
      credentials: seal({ access_token: "token" }),
      host,
      label: `@aaronmallen@${host}`,
      provider: "mastodon",
      scopes: "{write:statuses,write:media,read:accounts,read:search,read:statuses}",
    })}
  `;
});

When("the job {string} runs and finishes", async ({ app }, job: string) => {
  await runJob(app, job);
});

const baselines = new WeakMap<object, Map<string, number>>();

Given("jobs left over from before have finished", async ({ answer, app }) => {
  await new Promise((settle) => setTimeout(settle, 2000));
  const rows = await app.sql`SELECT job, count(*)::int AS count FROM performance_jobs GROUP BY job`;
  baselines.set(answer, new Map(rows.map((row) => [row.job, row.count])));
});

Then("the job {string} has run {int} time(s) and no more", async ({ answer, app }, job: string, count: number) => {
  const before = baselines.get(answer)?.get(job) ?? 0;
  if (count > 0) await waitForRuns(app, job, before + count);
  await new Promise((settle) => setTimeout(settle, 2000));
  expect((await runCount(app, job)) - before).toBe(count);
});

Then("the web heard {word} {string} {int} time(s)", ({ stub }, method: string, url: string, count: number) => {
  expect(heard(stub).filter((request) => request.method === method && request.url.href === url)).toHaveLength(count);
});
