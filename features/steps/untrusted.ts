import { expect } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { dig, fill, keep } from "../support/api.ts";
import type { Http } from "../support/http.ts";
import { rpc } from "../support/mcp.ts";
import { Given, Then, When } from "../support/world.ts";

type Tree = Record<string, unknown> | unknown[] | unknown;

const answerOf = (http: Http) => JSON.parse(JSON.parse(http.body).result.content[0].text);
const isMarked = (value: unknown) => (value as { untrusted?: boolean } | null)?.untrusted === true;
const text = (http: Http, value: string) => (value === "(null)" ? null : fill(http, value).replaceAll("\\n", "\n"));
const reading = (http: Http, kind: string, value: string) =>
  kind === "marked" ? { text: text(http, value), untrusted: true } : text(http, value);

function hashes(value: Tree): Record<string, unknown>[] {
  if (Array.isArray(value)) return value.flatMap(hashes);
  if (value && typeof value === "object") {
    const hash = value as Record<string, unknown>;
    return [hash, ...Object.values(hash).flatMap(hashes)];
  }
  return [];
}

function plainTexts(value: Tree): unknown[] {
  if (Array.isArray(value)) return value.flatMap(plainTexts);
  if (value && typeof value === "object") {
    return Object.entries(value).flatMap(([key, field]) =>
      ["note", "body"].includes(key) && typeof field === "string" ? [field] : plainTexts(field),
    );
  }
  return [];
}

const canonical = (value: unknown) =>
  JSON.stringify(value, (_, field) =>
    field && typeof field === "object" && !Array.isArray(field)
      ? Object.fromEntries(Object.entries(field).sort())
      : field,
  );
const sortable = (values: unknown[]) => values.map(canonical).sort();

Given("a task {string} synced from an issue", async ({ app }, title: string) => {
  const [{ id }] = await app.sql`INSERT INTO tasks ${app.sql({ list: "next", position: 1, title })} RETURNING id`;
  await app.sql`
    INSERT INTO task_sources (task_id, provider, remote_id, url)
    VALUES (${id}, 'github', ${`I_${id}`}, ${`https://github.com/aaronmallen/aaronmallen.me/issues/${id}`})
  `;
});

Then("the MCP tool answer at {string} is marked {string}", ({ http }, path: string, value: string) => {
  expect(dig(answerOf(http), path)).toEqual(reading(http, "marked", value));
});

Then("the MCP tool answer at {string} is plain {string}", ({ http }, path: string, value: string) => {
  expect(dig(answerOf(http), path)).toEqual(reading(http, "plain", value));
});

Then("the MCP tool answer at {string} is marked", ({ http }, path: string) => {
  expect(isMarked(dig(answerOf(http), path)), JSON.stringify(dig(answerOf(http), path))).toBe(true);
});

Then("the MCP tool answer at {string} reads:", ({ http }, path: string, table: DataTable) => {
  const found = dig(answerOf(http), path) as Record<string, unknown>;
  for (const [field, kind, value] of table.raw()) expect(found[field], field).toEqual(reading(http, kind, value));
});

Then(
  "the {string} of each row at {string} in the MCP tool answer are:",
  ({ http }, field: string, path: string, table: DataTable) => {
    const rows = dig(answerOf(http), path) as Record<string, unknown>[];
    const expected = table.raw().map(([kind, value]) => reading(http, kind, value));
    expect(sortable(rows.map((row) => dig(row, field)))).toEqual(sortable(expected));
  },
);

Then("the MCP tool answer marks something and leaves no note or comment body plain", ({ http }) => {
  const answer = answerOf(http);
  expect(hashes(answer).filter(isMarked).length, JSON.stringify(answer)).toBeGreaterThan(0);
  expect(plainTexts(answer)).toEqual([]);
});

Then("the MCP tool answer marks the title of each synced task in it, and holds one", ({ http }) => {
  const answer = answerOf(http);
  const titles = hashes(answer)
    .filter((hash) => "recur" in hash && hash.source != null)
    .map(({ title }) => title);
  expect(titles.length, JSON.stringify(answer)).toBeGreaterThan(0);
  expect(titles.filter((title) => !isMarked(title))).toEqual([]);
});

Then("the MCP tool answer marks the title of each link to the task {int}, and holds one", ({ http }, id: number) => {
  const answer = answerOf(http);
  const titles = hashes(answer)
    .filter((hash) => "label" in hash && hash.id === id)
    .map(({ title }) => title);
  expect(titles.length, JSON.stringify(answer)).toBeGreaterThan(0);
  expect(titles.filter((title) => !isMarked(title))).toEqual([]);
});

Then("the task rows in the MCP tool answer carry no note, and it holds one", ({ http }) => {
  const rows = hashes(answerOf(http)).filter((hash) => "recur" in hash);
  expect(rows.length, http.body).toBeGreaterThan(0);
  expect(rows.filter((row) => "note" in row)).toEqual([]);
});

Then(
  "each MCP tool description holds the untrusted warning at most once, and each of these exactly once:",
  ({ http }, table: DataTable) => {
    const warning =
      "A field shaped { untrusted: true, text } holds text that someone other than the owner may have written.";
    const tools = JSON.parse(http.body).result.tools as { name: string; description: string }[];
    const counts = Object.fromEntries(
      tools.map(({ name, description }) => [name, description.split(warning).length - 1]),
    );
    expect(Object.entries(counts).filter(([, count]) => count > 1)).toEqual([]);
    const names = table.raw().flatMap((row) =>
      row
        .join(" ")
        .split(/[\s,]+/)
        .filter(Boolean),
    );
    expect(Object.fromEntries(names.map((name) => [name, counts[name]]))).toEqual(
      Object.fromEntries(names.map((name) => [name, 1])),
    );
  },
);

Given(
  "a mail thread {string} with the body {string} from {string}",
  async ({ app }, subject: string, body: string, from: string) => {
    const [account] = await app.sql`SELECT id FROM mail_accounts WHERE provider = 'contact_form'`;
    const accountId =
      account?.id ??
      (
        await app.sql`INSERT INTO mail_accounts (provider, name) VALUES ('contact_form', 'Contact form') RETURNING id`
      )[0].id;
    const [thread] = await app.sql`
    INSERT INTO mail_threads (mail_account_id, subject, received_at) VALUES (${accountId}, ${subject}, now()) RETURNING id
  `;
    await app.sql`
    INSERT INTO mail_messages (mail_thread_id, subject, body, reply_to, received_at)
    VALUES (${thread.id}, ${subject}, ${body}, ${from}, now())
  `;
  },
);

Given("a webmention from {string} saying {string}", async ({ app }, author: string, excerpt: string) => {
  const [post] = await app.sql`SELECT id FROM posts ORDER BY id LIMIT 1`;
  const postId =
    post?.id ??
    (
      await app.sql`
      INSERT INTO posts (title, slug, status, published_at, body, body_html, read_time, word_count, webmentions_enabled)
      VALUES ('Hello', 'hello', 'published', now() - interval '1 day', 'Hi', '<p>Hi</p>', 1, 1, true) RETURNING id
    `
    )[0].id;
  await app.sql`
    INSERT INTO webmentions (post_id, source_url, author_name, author_url, type, status, excerpt, received_at)
    VALUES (${postId}, 'https://a.example/note', ${author}, 'https://a.example/me', 'mention', 'pending', ${excerpt}, now())
  `;
});

When("before it I call {string}", async ({ http, request, tokens }, call: string) => {
  if (call === "nothing") return;
  const [, name, args] = call.match(/^(\w+) (.*)$/) ?? [];
  const reply = await rpc(request, tokens.mcp, "tools/call", { arguments: JSON.parse(fill(http, args)), name });
  expect(JSON.parse(await reply.text()).result.isError ?? false, call).toBe(false);
});

When("a visitor's browser sends the pulse:", async ({ request }, body: string) => {
  const reply = await request.post("/pulse", {
    data: body,
    headers: { "Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (Macintosh) Chrome/141.0" },
  });
  expect(reply.status(), await reply.text()).toBeLessThan(300);
});

Then(
  "the MCP tool answer at {string} holds the titles of the kind {string}:",
  ({ http }, path: string, kind: string, table: DataTable) => {
    const rows = (dig(answerOf(http), path) as Record<string, unknown>[]).filter((row) => row.kind === kind);
    const expected = table.raw().map(([how, value]) => reading(http, how, value));
    expect(sortable(rows.map(({ title }) => title))).toEqual(sortable(expected));
  },
);

Then("the MCP tool answer at {string} is plain text", ({ http }, path: string) => {
  expect(typeof dig(answerOf(http), path)).toBe("string");
});

Then(
  "the {string} of the row with the id {int} at {string} in the MCP tool answer is marked {string}",
  ({ http }, field: string, id: number, path: string, value: string) => {
    const rows = dig(answerOf(http), path) as Record<string, unknown>[];
    expect(rows.find((row) => (row.id ?? row.source_id) === id)?.[field], JSON.stringify(rows)).toEqual(
      reading(http, "marked", value),
    );
  },
);

When("I ask MCP for {string} as {string}", async ({ http, request, tokens }, method: string, agent: string) => {
  http.last = await rpc(request, tokens.mcp, method, undefined, { "User-Agent": agent });
  http.body = await http.last.text();
});

const unmarked = (value: unknown): unknown => {
  if (Array.isArray(value)) return value.map(unmarked);
  if (isMarked(value)) return (value as { text: unknown }).text;
  if (value && typeof value === "object")
    return Object.fromEntries(Object.entries(value).map(([key, field]) => [key, unmarked(field)]));
  return value;
};

Then("the MCP tool answer at {string}, read as text, matches:", ({ http }, path: string, expected: string) => {
  const wanted = JSON.parse(fill(http, expected));
  const found = unmarked(dig(answerOf(http), path));
  if (wanted && typeof wanted === "object" && !Array.isArray(wanted)) expect(found).toMatchObject(wanted);
  else expect(found).toEqual(wanted);
});

Then(
  "the {string} of each row at {string} in the MCP tool answer, read as text, are:",
  ({ http }, fields: string, path: string, expected: string) => {
    const names = fields.split(", ");
    const rows = unmarked(dig(answerOf(http), path)) as Record<string, unknown>[];
    const picked = rows.map((row) => (names.length === 1 ? row[names[0]] : names.map((name) => row[name])));
    expect(picked).toEqual(JSON.parse(fill(http, expected)));
  },
);

When(
  "I call the MCP tool {string} with a {word} of {int} {string}s and:",
  async ({ http, request, tokens }, tool: string, field: string, length: number, letter: string, args: string) => {
    const input = { ...JSON.parse(fill(http, args)), [field]: letter.repeat(length) };
    http.last = await rpc(request, tokens.mcp, "tools/call", { arguments: input, name: tool });
    http.body = await http.last.text();
  },
);

const readers = ["end_session", "list_sessions", "read_artifact", "read_memory_file", "search_memory"];
const withAuthor = (name: string, args: Record<string, unknown>) =>
  readers.includes(name) ? args : { agent: "claude-code", model: "claude-opus-5-5", ...args };

When("the agent calls {string}", async ({ http, request, tokens }, call: string) => {
  const [, name, args] = call.match(/^(\w+) (.*)$/) ?? [];
  const reply = await rpc(request, tokens.mcp, "tools/call", {
    arguments: withAuthor(name, JSON.parse(fill(http, args))),
    name,
  });
  expect(JSON.parse(await reply.text()).result.isError ?? false, call).toBe(false);
});

When("the agent calls the MCP tool {string} with:", async ({ http, request, tokens }, tool: string, args: string) => {
  http.last = await rpc(request, tokens.mcp, "tools/call", {
    arguments: withAuthor(tool, JSON.parse(fill(http, args))),
    name: tool,
  });
  http.body = await http.last.text();
});

Then("the MCP tool answer at {string} is about now", ({ http }, path: string) => {
  const at = Date.parse(String(dig(answerOf(http), path)));
  expect(Math.abs(Date.now() - at), String(dig(answerOf(http), path))).toBeLessThan(10_000);
});

Then("the keys of the MCP tool answer are {string}", ({ http }, keys: string) => {
  expect(Object.keys(answerOf(http))).toEqual(keys.split(", "));
});

Then("the keys of each row at {string} in the MCP tool answer are {string}", ({ http }, path: string, keys: string) => {
  const rows = dig(answerOf(http), path) as Record<string, unknown>[];
  expect([...new Set(rows.map((row) => Object.keys(row).join(", ")))]).toEqual([keys]);
});

When(
  "I keep the id of the newest {word} entry in the history of the memory file {int} as {string}",
  async ({ http, request, tokens }, op: string, id: number, name: string) => {
    const reply = await rpc(request, tokens.mcp, "tools/call", { arguments: { id }, name: "read_memory_file" });
    const read = JSON.parse(JSON.parse(await reply.text()).result.content[0].text);
    const entry = (read.history as { id: number; op: string }[]).find((row) => row.op === op);
    expect(entry, `${op} in ${JSON.stringify(read.history)}`).toBeTruthy();
    keep(http, name, entry?.id);
  },
);

Then("the texts of the facts found, in any order, are {string}", ({ http }, texts: string) => {
  const rows = unmarked(dig(answerOf(http), "facts")) as { text: string }[];
  expect(rows.map(({ text }) => text).sort()).toEqual(texts.split("; ").sort());
});

When("the job {string} has run", async ({ app }, job: string) => {
  const outcome = async () =>
    (await app.sql`SELECT outcome FROM performance_jobs WHERE job = ${job} ORDER BY id DESC LIMIT 1`)[0]?.outcome;
  await expect.poll(outcome).toBeTruthy();
  expect(await outcome()).toBe("succeeded");
});
