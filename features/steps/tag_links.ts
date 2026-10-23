import { type APIResponse, expect, type Page } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import type postgres from "postgres";
import { Before, Given, Then, When } from "../support/world.ts";

type Row = Record<string, string>;

const joins: Record<string, { label: string; owner: string; path: string; scope: string; table: string }> = {
  decision: { label: "title", owner: "decision_id", path: "decisions", scope: "private", table: "decisions" },
  journal_entry: {
    label: "body",
    owner: "journal_entry_id",
    path: "journal",
    scope: "private",
    table: "journal_entries",
  },
  mail_thread: { label: "subject", owner: "mail_thread_id", path: "mail", scope: "private", table: "mail_threads" },
  note: { label: "title", owner: "note_id", path: "notes", scope: "private", table: "notes" },
  post: { label: "title", owner: "post_id", path: "posts", scope: "public", table: "posts" },
  project: { label: "name", owner: "project_id", path: "projects", scope: "public", table: "projects" },
  task: { label: "title", owner: "task_id", path: "tasks", scope: "private", table: "tasks" },
};

const tagTable = (kind: string) => `${kind}_tags`;

const recordId = async (sql: postgres.Sql, kind: string, label: string) => {
  const { label: column, table } = joins[kind];
  const [found] = await sql`SELECT id FROM ${sql(table)} WHERE ${sql(column)} = ${label}`;
  if (!found) throw new Error(`no ${kind} ${label}`);
  return found.id as number;
};

const projectId = async (sql: postgres.Sql, key: string) => {
  const [found] = await sql`SELECT id FROM projects WHERE key = ${key}`;
  if (found) return found.id as number;
  const [made] = await sql`
    INSERT INTO projects ${sql({ key, name: key.toLowerCase(), visibility: "public" })} RETURNING id
  `;
  return made.id as number;
};

const tagId = async (sql: postgres.Sql, row: Row) => {
  const [scope, key] = row.scope.split(" ");
  const project = key ? await projectId(sql, key) : null;
  const [found] = await sql`
    SELECT id FROM tags WHERE name = ${row.name} AND scope = ${scope} AND project_id IS NOT DISTINCT FROM ${project}
  `;
  if (found) return { id: found.id as number, scope };
  const tag = {
    color: row.color || "mk-green",
    description: row.description || null,
    name: row.name,
    project_id: project,
    scope,
    ...(row.id ? { id: Number(row.id) } : {}),
  };
  const [made] = await sql`INSERT INTO tags ${sql(tag)} RETURNING id`;
  return { id: made.id as number, scope };
};

const contactForm = async (sql: postgres.Sql) => {
  const [found] = await sql`SELECT id FROM mail_accounts WHERE provider = 'contact_form'`;
  if (found) return found.id as number;
  const [made] = await sql`
    INSERT INTO mail_accounts (provider, name) VALUES ('contact_form', 'Contact form') RETURNING id
  `;
  return made.id as number;
};

const insertRecord = async (sql: postgres.Sql, row: Row) => {
  const { kind, state = "", title } = row;
  const id = row.id ? { id: Number(row.id) } : {};
  const done = ["done", "canceled"].includes(state);
  const fields: Record<string, Record<string, unknown>> = {
    decision: { problem: "A problem to settle.", status: state || "open", title },
    journal_entry: { body: title, body_html: `<p>${title}</p>`, entry_date: sql`current_date`, entry_time: "09:00" },
    mail_thread: { mail_account_id: await contactForm(sql), subject: title },
    note: { body: `Notes on ${title}.`, title },
    post: {
      body: `A post called ${title}.`,
      body_html: `<p>A post called ${title}.</p>`,
      published_at: state === "draft" ? null : sql`now() - interval '1 day'`,
      read_time: 1,
      slug: row.slug || title.toLowerCase().replaceAll(/\W+/g, "-"),
      status: state || "published",
      title,
      webmentions_enabled: false,
      word_count: 4,
    },
    project: {
      archived_on: state === "archived" ? sql`current_date` : null,
      name: title,
      visibility: "public",
      ...(row.key ? { key: row.key } : {}),
    },
    task: {
      completed_at: done ? sql`now()` : null,
      list: "next",
      position: 1,
      status: state || "open",
      title,
    },
  };
  const [made] = await sql`INSERT INTO ${sql(joins[kind].table)} ${sql({ ...fields[kind], ...id })} RETURNING id`;
  if (kind === "mail_thread") {
    const message = { body: "Hello.", mail_thread_id: made.id, reply_to: "someone@example.com", subject: title };
    await sql`INSERT INTO mail_messages ${sql(message)}`;
  }
  for (const name of (row.tags ?? "").split(", ").filter(Boolean)) {
    const [key, bare] = name.includes(":") ? name.split(":") : ["", name];
    const tag = await tagId(sql, { name: bare, scope: key ? `project ${key}` : joins[kind].scope });
    await sql`
      INSERT INTO ${sql(tagTable(kind))} ${sql({ [joins[kind].owner]: made.id, tag_id: tag.id, tag_scope: tag.scope })}
    `;
  }
};

Given("the tagging tags:", async ({ app }, table: DataTable) => {
  for (const row of table.hashes()) await tagId(app.sql, row);
});

Given("the tagging records:", async ({ app }, table: DataTable) => {
  for (const row of table.hashes()) await insertRecord(app.sql, row);
});

Given(
  "the tagging {word} {string} links to the project {string}",
  async ({ app }, kind: string, label: string, key: string) => {
    const sides = [
      [kind, await recordId(app.sql, kind, label)],
      ["project", await projectId(app.sql, key)],
    ] as const;
    const kinds = ["task", "post", "social_post", "journal_entry", "commit", "project", "work_entry", "decision"];
    const rank = (side: string) => (kinds.includes(side) ? kinds.indexOf(side) : kinds.length);
    const [left, right] = rank(sides[0][0]) < rank(sides[1][0]) ? sides : [sides[1], sides[0]];
    const link = { left_id: left[1], left_kind: left[0], right_id: right[1], right_kind: right[0] };
    await app.sql`INSERT INTO record_links ${app.sql(link)}`;
  },
);

When(
  "the tagging {word} {string} no longer links to the project {string}",
  async ({ app }, kind: string, label: string, key: string) => {
    const id = await recordId(app.sql, kind, label);
    const project = await projectId(app.sql, key);
    await app.sql`
      DELETE FROM record_links
      WHERE (left_kind = ${kind} AND left_id = ${id} AND right_kind = 'project' AND right_id = ${project})
          OR (right_kind = ${kind} AND right_id = ${id} AND left_kind = 'project' AND left_id = ${project})
    `;
  },
);

Given("the tagging task rule {string} carries {string}", async ({ app }, pattern: string, names: string) => {
  const [rule] = await app.sql`INSERT INTO task_rules (pattern, provider) VALUES (${pattern}, 'github') RETURNING id`;
  for (const name of names.split(", ")) {
    const tag = await tagId(app.sql, { name, scope: "private" });
    await app.sql`INSERT INTO task_rule_tags ${app.sql({ tag_id: tag.id, task_rule_id: rule.id })}`;
  }
});

Then("the tagged {word} {string} holds {string}", async ({ app }, kind: string, label: string, held: string) => {
  const id = await recordId(app.sql, kind, label);
  const rows = await app.sql`
    SELECT tags.name || ' in ' || coalesce(projects.key, tags.scope::text) AS tag
    FROM ${app.sql(tagTable(kind))} AS held
    JOIN tags ON tags.id = held.tag_id
    LEFT JOIN projects ON projects.id = tags.project_id
    WHERE held.${app.sql(joins[kind].owner)} = ${id}
    ORDER BY tags.name, projects.key
  `;

  expect(rows.map(({ tag }) => tag).join(", ")).toBe(held);
});

let sent: { location: string; status: number } = { location: "", status: 0 };

const csrfToken = async (page: Page) => {
  const token = page.locator("input[name='_csrf_token']").first();
  if (!new URL(page.url(), "http://x").pathname.startsWith("/admin") || !(await token.count())) {
    await page.goto("/admin/journal");
  }
  return token.inputValue();
};

const send = async (page: Page, action: string, fields: [string, string][]) => {
  const form = new URLSearchParams([["_csrf_token", await csrfToken(page)], ...fields]);
  const response: APIResponse = await page.request.post(action, {
    data: form.toString(),
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    maxRedirects: 0,
  });
  sent = { location: response.headers().location ?? "", status: response.status() };
};

const tagPath = async (sql: postgres.Sql, kind: string, label: string) =>
  `/admin/${joins[kind].path}/${label === "that is gone" ? 0 : await recordId(sql, kind, label)}`;

When("I tag the {word} {string} with {string}", async ({ app, page }, kind: string, label: string, tag: string) => {
  if (kind === "mail_thread") {
    const id = String(await recordId(app.sql, kind, label));
    await send(page, "/admin/mail/bulk", [
      ["ids[]", id],
      ["act", "tag"],
      ["tag", tag],
    ]);
    return;
  }
  await send(page, `${await tagPath(app.sql, kind, label)}/tags`, [["tag", tag]]);
});

When(
  "I tag the {word} {string} with {string}, asking to return to {string}",
  async ({ app, page }, kind: string, label: string, tag: string, back: string) => {
    await send(page, `${await tagPath(app.sql, kind, label)}/tags`, [
      ["tag", tag],
      ["return_to", back],
    ]);
  },
);

When(
  "I take the tag {string} off the {word} {string}",
  async ({ app, page }, tag: string, kind: string, label: string) => {
    await send(page, `${await tagPath(app.sql, kind, label)}/tags/delete`, [["tag", tag]]);
  },
);

When(
  "I save the {word} editor for {string} with:",
  async ({ app, page }, kind: string, label: string, table: DataTable) => {
    await page.goto(`${await tagPath(app.sql, kind, label)}/edit`);
    const changes = Object.fromEntries(table.raw());
    const { action, fields } = await page.evaluate((names) => {
      const field = document.querySelector<HTMLInputElement>(`[name='${names[0]}']`);
      const form = field?.form ?? document.querySelector("main form");
      if (!form) throw new Error("no editor form");
      const data = [...new FormData(form).entries()].filter(([, value]) => typeof value === "string");
      return { action: form.action, fields: data as [string, string][] };
    }, Object.keys(changes));
    const kept = fields.filter(([name]) => !(name in changes) && name !== "_csrf_token");
    await send(page, new URL(action).pathname, [...kept, ...Object.entries(changes)]);
    expect(sent.status, sent.location).toBe(302);
  },
);

Then("the tagging form answers {int}", ({}, status: number) => {
  expect(sent.status).toBe(status);
});

Then("the tagging form sends me to {string}", ({}, path: string) => {
  expect(sent.location.replace(/^https?:\/\/[^/]+/, "")).toBe(path);
});

Then("the tagging form toasts {string}", async ({ page }, text: string) => {
  await page.goto(sent.location);
  await expect(page.locator("[data-toast] .toast").first()).toHaveText(text);
});

When("I visit the {word} {string} at {string}", async ({ app, page }, kind: string, label: string, suffix: string) => {
  await page.goto(`${await tagPath(app.sql, kind, label)}${suffix}`);
});

Then("the tagging page holds {string}", async ({ page }, selector: string) => {
  await expect(page.locator(selector).first()).toBeAttached();
});

Then("the tagging page holds {int} of {string}", async ({ page }, count: number, selector: string) => {
  await expect(page.locator(selector)).toHaveCount(count);
});

Then("the tagging page lacks {string}", async ({ page }, selector: string) => {
  await expect(page.locator(selector)).toHaveCount(0);
});

Then("the tagging page source lacks {string}", async ({ page }, text: string) => {
  expect(await page.content()).not.toContain(text);
});

Then("the tagging page lists {string} in {string}", async ({ page }, texts: string, selector: string) => {
  await expect(page.locator(selector).first()).toBeAttached();
  const found = (await page.locator(selector).allTextContents()).map((text) => text.trim()).sort();

  expect(found).toEqual(texts.split(", ").sort());
});

Then("the tagging field {string} holds {string}", async ({ page }, selector: string, value: string) => {
  await expect(page.locator(selector).first()).toHaveValue(value);
});

Then("the tagging field {string} has the label {string}", async ({ page }, selector: string, text: string) => {
  const labelled = await page
    .locator(selector)
    .first()
    .evaluate((field) =>
      field.parentElement
        ?.querySelector(`label[for='${field.id}'], label[for='${field.id}-search']`)
        ?.textContent?.trim(),
    );

  expect(labelled).toBe(text);
});

const names = (json: string | null) =>
  (JSON.parse(json ?? "[]") as { name: string }[]).map(({ name }) => name).join(", ");

Then("the tag picker {string} offers {string}", async ({ page }, selector: string, offered: string) => {
  const pickers = await page.locator(selector).evaluateAll((all) => all.map((each) => each.dataset.tagField ?? null));

  expect(pickers.length).toBeGreaterThan(0);
  expect(pickers.map(names)).toEqual(pickers.map(() => offered));
});

const suggestions = async (page: Page) => {
  const json = await page.locator("[data-menu-suggest]").first().getAttribute("data-menu-suggest");
  return JSON.parse(json ?? "[]") as { color: string; name: string }[];
};

Then("the tag menu suggests {string}", async ({ page }, offered: string) => {
  expect((await suggestions(page)).map(({ name }) => name).join(", ")).toBe(offered);
});

Then("the tag menu gives {string} the color {string}", async ({ page }, name: string, color: string) => {
  expect((await suggestions(page)).find((tag) => tag.name === name)?.color).toBe(color);
});

Then("the tag menu gives {string} a color", async ({ page }, name: string) => {
  expect(typeof (await suggestions(page)).find((tag) => tag.name === name)?.color).toBe("string");
});

let choices: APIResponse | undefined;

When("I fetch the tag choices at {string}", async ({ app, page }, path: string) => {
  const ids = await Promise.all(
    [...path.matchAll(/\{(\w+) (.+?)\}/g)].map(async ([whole, kind, label]) => [
      whole,
      String(await recordId(app.sql, kind, label)),
    ]),
  );
  const filled = ids.reduce((text, [whole, id]) => text.replace(whole, id), path);
  choices = await page.request.get(filled, { headers: { Accept: "application/json" }, maxRedirects: 0 });
});

Then("the tag choices answer {int}", ({}, status: number) => {
  expect(choices?.status()).toBe(status);
});

Then("the tag choices come as JSON no one may keep", ({}) => {
  expect(choices?.headers()["content-type"]).toMatch(/^application\/json/);
  expect(choices?.headers()["cache-control"]).toBe("private, no-store");
});

const chosen = async () => (await choices?.json())?.tags as { color: string; name: string }[];

Then("the tag choices list {string}", async ({}, offered: string) => {
  expect((await chosen()).map(({ name }) => name).join(", ")).toBe(offered);
});

Then("the tag choices give {string} the color {string}", async ({}, name: string, color: string) => {
  expect((await chosen()).find((tag) => tag.name === name)?.color).toBe(color);
});

Then("the tag choices give {string} a color", async ({}, name: string) => {
  expect(typeof (await chosen()).find((tag) => tag.name === name)?.color).toBe("string");
});

const trusted = (value: unknown): unknown => {
  if (Array.isArray(value)) return value.map(trusted);
  if (value && typeof value === "object") {
    const record = value as Record<string, unknown>;
    if (record.untrusted === true && "text" in record) return record.text;
    return Object.fromEntries(Object.entries(record).map(([key, inner]) => [key, trusted(inner)]));
  }
  return value;
};

Then(
  "the tag API call {string} answers what the MCP tool {string} does with:",
  async ({ request, tokens }, call: string, tool: string, args: string) => {
    const [method, path] = call.split(" ");
    const api = await request.fetch(path, { headers: { Authorization: `Bearer ${tokens.api}` }, method });
    const mcp = await request.post("/mcp", {
      data: { id: 1, jsonrpc: "2.0", method: "tools/call", params: { arguments: JSON.parse(args), name: tool } },
      headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${tokens.mcp}` },
    });
    const text = (await mcp.json()).result.content[0].text;

    expect(api.status()).toBe(200);
    expect(trusted(JSON.parse(text))).toEqual(trusted(await api.json()));
  },
);

type Tool = {
  description: string;
  inputSchema: { properties: Record<string, { description?: string }> };
  name: string;
};

let tools: Tool[] = [];

When("I list the MCP tag tools", async ({ request, tokens }) => {
  const response = await request.post("/mcp", {
    data: { id: 1, jsonrpc: "2.0", method: "tools/list" },
    headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${tokens.mcp}` },
  });
  tools = (await response.json()).result.tools.filter(
    ({ name }: { name: string }) => name.endsWith("_tag") || name.endsWith("_tags"),
  );
});

Then("the MCP tag tools that take a scope include {string}", ({}, wanted: string) => {
  const scoped = tools.filter((tool) => tool.inputSchema.properties?.scope).map(({ name }) => name);

  expect(scoped).toEqual(expect.arrayContaining(wanted.split(", ")));
});

Then("each MCP tag tool that takes a scope says {string}", ({}, text: string) => {
  const texts = tools
    .filter((tool) => tool.inputSchema.properties?.scope)
    .flatMap((tool) => [tool.description, tool.inputSchema.properties.scope.description ?? ""]);

  expect(texts.filter((each) => !each.includes(text))).toEqual([]);
});

Then("the MCP tag tool {string} says {string}", ({}, name: string, text: string) => {
  expect(tools.find((tool) => tool.name === name)?.description).toContain(text);
});

Before(() => {
  sent = { location: "", status: 0 };
  choices = undefined;
  tools = [];
});

Then("a tagging page template holds {string}", async ({ page }, text: string) => {
  const templates = await page.locator("template").evaluateAll((all) => all.map((each) => each.innerHTML));

  expect(templates.some((html) => html.includes(text))).toBe(true);
});
