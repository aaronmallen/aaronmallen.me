import { randomBytes } from "node:crypto";
import { type APIRequestContext, expect, type Page } from "@playwright/test";
import type postgres from "postgres";
import { seal } from "../support/seal.ts";
import { Before, Given, Then, When } from "../support/world.ts";

const kinds = [
  "task",
  "post",
  "social_post",
  "journal_entry",
  "commit",
  "project",
  "work_entry",
  "decision",
  "pull_request",
  "mail_thread",
  "memory_file",
  "artifact",
  "note",
  "note_folder",
];

let posted = 0;
let paired: Record<string, number> = {};

const norm = (text: string | null) => (text ?? "").replace(/\s+/g, " ").trim();
const list = (text: string) => (text ? text.split(", ") : []);
const escaped = (text: string) => text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const exact = (text: string) => new RegExp(`^\\s*${escaped(text)}\\s*$`);

const contactForm = async (sql: postgres.Sql) => {
  const [found] = await sql`SELECT id FROM mail_accounts WHERE provider = 'contact_form'`;
  if (found) return found.id as number;
  const [{ id }] = await sql`
    INSERT INTO mail_accounts (provider, name) VALUES ('contact_form', 'Contact form') RETURNING id
  `;
  return id as number;
};

const one = async (rows: Promise<postgres.RowList<postgres.Row[]>>) => (await rows)[0].id as number;

const insertRecord = async (sql: postgres.Sql, kind: string, text: string): Promise<number> => {
  const slug = text.toLowerCase().replaceAll(/[^a-z0-9]+/g, "-");
  switch (kind) {
    case "task":
      return one(sql`
        INSERT INTO tasks (title, list, position)
        VALUES (${text}, 'next', (SELECT coalesce(max(position), 0) + 1 FROM tasks)) RETURNING id
      `);
    case "post":
      return one(sql`
        INSERT INTO posts (title, slug, body, body_html, webmentions_enabled, read_time, word_count)
        VALUES (${text}, ${slug}, '', '', false, 1, 0) RETURNING id
      `);
    case "social_post": {
      const id = await one(sql`INSERT INTO social_posts (targets) VALUES ('{mastodon,bluesky}') RETURNING id`);
      await sql`INSERT INTO social_post_parts (social_post_id, position, body) VALUES (${id}, 1, ${text})`;
      return id;
    }
    case "journal_entry":
      return one(sql`
        INSERT INTO journal_entries (entry_date, entry_time, body, body_html)
        VALUES ('2026-09-30', '09:00', ${text}, ${`<p>${text}</p>`}) RETURNING id
      `);
    case "commit":
      return one(sql`
        INSERT INTO commits (sha, repo, branch, message, commit_date, commit_time)
        VALUES (${randomBytes(20).toString("hex")}, 'aaronmallen/aaronmallen.me', 'main', ${text},
                '2026-09-30', '09:00')
        RETURNING id
      `);
    case "project":
      return one(sql`
        INSERT INTO projects (name, visibility, key)
        VALUES (${text}, 'public', ${`P${randomBytes(2).toString("hex").toUpperCase()}`}) RETURNING id
      `);
    case "work_entry":
      return one(sql`
        INSERT INTO work_entries (org, role, from_year, position)
        VALUES ('Rackspace', ${text}, 2018, (SELECT coalesce(max(position), 0) + 1 FROM work_entries)) RETURNING id
      `);
    case "decision":
      return one(sql`INSERT INTO decisions (title, problem) VALUES (${text}, 'It came up') RETURNING id`);
    case "pull_request": {
      const number = Math.floor(Math.random() * 100_000) + 1;
      return one(sql`
        INSERT INTO pull_requests (repo, number, title, url, ready_at, opened_at)
        VALUES ('aaronmallen/aaronmallen.me', ${number}, ${text},
                ${`https://github.com/aaronmallen/aaronmallen.me/pull/${number}`}, now(), now())
        RETURNING id
      `);
    }
    case "mail_thread":
      return one(sql`
        INSERT INTO mail_threads (mail_account_id, subject) VALUES (${await contactForm(sql)}, ${text}) RETURNING id
      `);
    case "memory_file":
      return one(sql`
        INSERT INTO memory_files (path, scope, description) VALUES (${`${slug}.md`}, 'global', 'notes for agents')
        RETURNING id
      `);
    case "artifact":
      return one(sql`INSERT INTO artifacts (title, type) VALUES (${text}, 'plan') RETURNING id`);
    case "note":
      return one(sql`INSERT INTO notes (title) VALUES (${text}) RETURNING id`);
    case "note_folder":
      return one(sql`INSERT INTO note_folders (name) VALUES (${text}) RETURNING id`);
    default:
      throw new Error(`no record kind ${kind}`);
  }
};

const linkRecords = async (sql: postgres.Sql, kind: string, id: number, other: string, otherId: number) => {
  const [first, second] = [
    [kind, id],
    [other, otherId],
  ].sort(([ak, ai], [bk, bi]) => kinds.indexOf(String(ak)) - kinds.indexOf(String(bk)) || Number(ai) - Number(bi));
  if (first[0] === "task" && second[0] === "project") {
    await sql`UPDATE tasks SET project_id = ${second[1]} WHERE id = ${first[1]}`;
    return;
  }
  await sql`
    INSERT INTO record_links (left_kind, left_id, right_kind, right_id)
    VALUES (${first[0]}::record_kind, ${first[1]}, ${second[0]}::record_kind, ${second[1]})
  `;
};

const linksOf = async (sql: postgres.Sql, kind: string, id: number) => {
  const rows = await sql`
    WITH pairs AS (
      SELECT left_kind::text AS lk, left_id AS li, right_kind::text AS rk, right_id AS ri FROM record_links
      UNION ALL
      SELECT 'task', id, 'project', project_id FROM tasks WHERE project_id IS NOT NULL
    )
    SELECT CASE WHEN lk = ${kind} AND li = ${id} THEN rk || ' ' || ri ELSE lk || ' ' || li END AS other
    FROM pairs WHERE (lk = ${kind} AND li = ${id}) OR (rk = ${kind} AND ri = ${id})
    ORDER BY 1
  `;
  return rows.map(({ other }) => other).join(", ") || "nothing";
};

const csrf = async (page: Page) => {
  const token = page.locator("input[name='_csrf_token']").first();
  if (!new URL(page.url(), "http://x").pathname.startsWith("/admin") || !(await token.count())) {
    await page.goto("/admin");
  }
  return token.inputValue();
};

const postForm = async (page: Page, action: string, fields: string) => {
  const all = [["_csrf_token", await csrf(page)], ...new URLSearchParams(fields).entries()];
  const path = new URL(action, "http://x").pathname;
  const response = page.waitForResponse(
    (sent) => sent.request().method() === "POST" && new URL(sent.url()).pathname === path,
  );
  const navigated = page.waitForNavigation();
  await page.evaluate(
    ({ action, all }) => {
      const form = document.createElement("form");
      form.method = "post";
      form.action = action;
      for (const [name, value] of all) {
        const input = document.createElement("input");
        input.type = "hidden";
        input.name = name;
        input.value = value;
        form.append(input);
      }
      document.body.append(form);
      form.submit();
    },
    { action, all },
  );
  posted = (await response).status();
  await navigated;
};

const trusted = (value: unknown): unknown => {
  if (Array.isArray(value)) return value.map(trusted);
  if (value && typeof value === "object") {
    const record = value as Record<string, unknown>;
    if (record.untrusted === true && "text" in record) return record.text;
    return Object.fromEntries(Object.entries(record).map(([key, inner]) => [key, trusted(inner)]));
  }
  return value;
};

const parse = (text: string) => {
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
};

const fetchApi = async (request: APIRequestContext, token: string | undefined, call: string, data?: string) => {
  const [method, path] = call.split(" ");
  const response = await request.fetch(path, {
    data: data === undefined ? undefined : JSON.parse(data),
    headers: { Authorization: `Bearer ${token}` },
    method,
  });
  const text = await response.text();
  return { body: trusted(parse(text)), status: response.status(), text };
};

const api = async (request: APIRequestContext, token: string | undefined, call: string, data?: string) =>
  (await fetchApi(request, token, call, data)).body;

const okApi = async (request: APIRequestContext, token: string | undefined, call: string, data?: string) => {
  const { body, status, text } = await fetchApi(request, token, call, data);

  expect(status, `${call}: ${text}`).toBeLessThan(400);
  return body;
};

const rpc = async (request: APIRequestContext, token: string | undefined, method: string, params: unknown) => {
  const response = await request.post("/mcp", {
    data: { id: 1, jsonrpc: "2.0", method, params },
    headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${token}` },
  });
  return parse(await response.text());
};

const mcp = async (request: APIRequestContext, token: string | undefined, name: string, data: string) => {
  const reply = await rpc(request, token, "tools/call", { arguments: JSON.parse(data), name });

  expect(Boolean(reply?.error ?? reply?.result?.isError), `${name}: ${JSON.stringify(reply)}`).toBe(false);
  return trusted(parse(reply.result.content[0].text));
};

const menu = (page: Page) => page.locator("[data-context-menu]");
const menuItem = (page: Page, label: string) => menu(page).locator(".ctx-item").filter({ hasText: label }).first();
const kindGroup = (page: Page, kind: string) =>
  page
    .locator(".record-links .record-link-group")
    .filter({ has: page.locator(".record-link-kind", { hasText: exact(kind) }) });

Given("a record link {word} titled {string}", async ({ app }, kind: string, text: string) => {
  await insertRecord(app.sql, kind, text);
});

Given(
  "the record links tie the {word} {int} to the {word} {int}",
  async ({ app }, kind: string, id: number, other: string, otherId: number) => {
    await linkRecords(app.sql, kind, id, other, otherId);
  },
);

Given("the record picker has two tasks numbered 23", async ({ app }) => {
  const [{ id }] = await app.sql`
    INSERT INTO projects (name, repo, visibility, key) VALUES ('Podcast', 'aaronmallen/podcast', 'public', 'POD')
    RETURNING id
  `;
  const loose = await insertRecord(app.sql, "task", "Loose end");
  await app.sql`UPDATE tasks SET number = 23 WHERE id = ${loose}`;
  await app.sql`
    INSERT INTO tasks (title, list, position, project_id) VALUES ('Record the intro', 'next', 99, ${id})
  `;
  await app.sql`UPDATE tasks SET number = 23 WHERE title = 'Record the intro'`;
});

const privateTag = async (sql: postgres.Sql, name: string, color: string) =>
  one(sql`INSERT INTO tags (name, color, scope) VALUES (${name}, ${color}, 'private') RETURNING id`);

Given(
  "the record menus have the private tag {string} coloured {string}",
  async ({ app }, name: string, color: string) => {
    await privateTag(app.sql, name, color);
  },
);

Given("the record menus have the journal entry {string} tagged home", async ({ app }, body: string) => {
  const [{ id }] = await app.sql`
    INSERT INTO journal_entries (entry_date, entry_time, body, body_html)
    VALUES ('2026-10-01', '09:30', ${body}, ${`<p>${body}</p>`}) RETURNING id
  `;
  const home = await privateTag(app.sql, "home", "mk-blue");
  await privateTag(app.sql, "work", "mk-green");
  await app.sql`INSERT INTO tags (name, color, scope) VALUES ('ruby', 'mk-pink', 'public')`;
  await app.sql`INSERT INTO journal_entry_tags (journal_entry_id, tag_id) VALUES (${id}, ${home})`;
});

Given(
  "the record menus have the file {string} of the type {string} at {string}",
  async ({ app }, filename: string, type: string, code: string) => {
    const [{ id }] = await app.sql`INSERT INTO short_codes (code) VALUES (${code}) RETURNING id`;
    await app.sql`
      INSERT INTO share_group_files (key, filename, content_type, byte_size, short_code_id)
      VALUES (${randomBytes(16).toString("hex")}, ${filename}, ${type}, 1, ${id})
    `;
  },
);

Given(
  "the record menus have the short link {string} to {string}",
  async ({ app }, code: string, destination: string) => {
    const [{ id }] = await app.sql`INSERT INTO short_codes (code) VALUES (${code}) RETURNING id`;
    await app.sql`INSERT INTO short_links (short_code_id, destination) VALUES (${id}, ${destination})`;
  },
);

Given("the record lists have a GitHub token", async ({ app }) => {
  const credentials = seal(JSON.stringify({ access_token: "ghp_token" }));
  await app.sql`
    INSERT INTO service_connections (provider, account_id, label, credentials, scopes)
    VALUES ('github', '931094', '@aaronmallen', ${credentials}, '{repo}')
  `;
});

When("I post the record link form to {string}", async ({ page }, action: string) => {
  await postForm(page, action, "");
});

When("I post the record link form to {string} with {string}", async ({ page }, action: string, fields: string) => {
  await postForm(page, action, fields);
});

Then("the record link post answers {int}", ({}, status: number) => {
  expect(posted).toBe(status);
});

Then("the record link post lands on {string}", ({ page }, path: string) => {
  const url = new URL(page.url());

  expect(`${url.pathname}${url.search}${url.hash}`).toBe(path);
});

Then("the record links of the {word} {int} read {string}", async ({ app }, kind: string, id: number, read: string) => {
  expect(await linksOf(app.sql, kind, id)).toBe(read);
});

Then("the record page has {string}", async ({ page }, css: string) => {
  await expect(page.locator(css).first()).toBeAttached();
});

Then("the record page has no {string}", async ({ page }, css: string) => {
  await expect(page.locator(css)).toHaveCount(0);
});

Then("the record page has {string} reading {string}", async ({ page }, css: string, text: string) => {
  await expect(page.locator(css).filter({ hasText: text }).first()).toBeAttached();
});

Then("the record page's {string} reads {string}", async ({ page }, css: string, text: string) => {
  expect(norm(await page.locator(css).first().textContent())).toBe(text);
});

Then("the record page's {string} holds {string}", async ({ page }, css: string, value: string) => {
  await expect(page.locator(css).first()).toHaveValue(value);
});

Then(
  "the record page's {string} has the {word} {string}",
  async ({ page }, css: string, attribute: string, value: string) => {
    await expect(page.locator(css).first()).toHaveAttribute(attribute, value);
  },
);

Then("the record page links {string} to {string}", async ({ page }, name: string, href: string) => {
  const link = page.getByRole("link", { exact: true, name }).and(page.locator(`[href='${href}']`));

  await expect(link.first()).toBeAttached();
});

Then(
  "the record links group {string} links {string} to {string}",
  async ({ page }, kind: string, title: string, href: string) => {
    await expect(kindGroup(page, kind).getByRole("link", { exact: true, name: title })).toHaveAttribute("href", href);
  },
);

Then("the record links group {string} links {string}", async ({ page }, kind: string, title: string) => {
  await expect(kindGroup(page, kind).getByRole("link", { exact: true, name: title })).toBeVisible();
});

Then("the record picker offers {string}", async ({ page }, titles: string) => {
  const found = await page.locator(".record-links .record-picker-target .record-link-title").allTextContents();

  expect(found.map(norm)).toEqual(list(titles));
});

Then("the record picker offers {string} in any order", async ({ page }, titles: string) => {
  const found = await page.locator(".record-links .record-picker-target .record-link-title").allTextContents();

  expect(found.map(norm).sort()).toEqual(list(titles).sort());
});

Then("the record picker offers {int} records, the last {string}", async ({ page }, count: number, title: string) => {
  const found = await page.locator(".record-links .record-picker-target .record-link-title").allTextContents();

  expect([found.length, norm(found.at(-1) ?? "")]).toEqual([count, title]);
});

Then("the record picker groups read {string}", async ({ page }, names: string) => {
  const found = await page.locator(".record-picker-results .record-link-group .record-link-kind").allTextContents();

  expect(found.map(norm)).toEqual(list(names));
});

Then("the record menu items read {string}", async ({ page }, labels: string) => {
  const found = await page.locator(".ctx-label").allTextContents();

  expect(found.map(norm).join(", ")).toBe(labels);
});

Then("the record menu copies {string} as {string}", async ({ page }, label: string, value: string) => {
  const item = page.locator("[data-copy]").filter({ has: page.locator(".ctx-label", { hasText: exact(label) }) });

  await expect(item).toHaveAttribute("data-copy", value);
});

Then("every record menu form returns to {string}", async ({ page }, path: string) => {
  const found = await page
    .locator("[data-context-menu] form input[name=return_to]")
    .evaluateAll((inputs) => inputs.map((input) => (input as HTMLInputElement).value));

  expect([...new Set(found)]).toEqual([path]);
});

When("I open the record menu on {string}", async ({ page }, css: string) => {
  const target = page.locator(css).first();
  const box = await target.boundingBox();
  await page.evaluate(() => Object.assign(window, { kept: true }));
  await page.mouse.click((box?.x ?? 0) + 2, (box?.y ?? 0) + (box?.height ?? 4) / 2, { button: "right" });
  await expect(menu(page)).toBeVisible();
});

When("I right click {string} on the record page", async ({ page }, css: string) => {
  await page.evaluate(() =>
    document.addEventListener("contextmenu", () => Object.assign(window, { rightClicked: true }), { capture: true }),
  );
  await page.locator(css).first().click({ button: "right" });
});

When("I pick {string} in the record menu", async ({ page }, label: string) => {
  await menuItem(page, label).click();
});

When("I point at {string} in the record menu", async ({ page }, label: string) => {
  await menuItem(page, label).hover();
});

Then("the record menu offers {string}", async ({ page }, label: string) => {
  await expect(menuItem(page, label)).toBeVisible();
});

Then("no record menu opens", async ({ page }) => {
  const landed = () => page.evaluate(() => (window as unknown as { rightClicked?: boolean }).rightClicked);

  await expect.poll(landed).toBe(true);
  await page.waitForTimeout(500);

  await expect(menu(page)).toHaveCount(0);
});

Then("the record page stayed", async ({ page }) => {
  expect(await page.evaluate(() => (window as unknown as { kept?: boolean }).kept)).toBe(true);
});

When("I watch the record clipboard", async ({ page }) => {
  await page.evaluate(() => {
    const copied: string[] = [];
    Object.assign(window, { copiedKeys: copied });
    Object.defineProperty(navigator, "clipboard", {
      value: { writeText: (text: string) => Promise.resolve(copied.push(text)) },
    });
  });
});

Then("the record clipboard holds {string}", async ({ page }, text: string) => {
  await expect
    .poll(() => page.evaluate(() => (window as unknown as { copiedKeys: string[] }).copiedKeys))
    .toEqual([text]);
});

Then("the record clipboard starts with {string}", async ({ page }, text: string) => {
  await expect
    .poll(() => page.evaluate(() => (window as unknown as { copiedKeys: string[] }).copiedKeys[0] ?? ""))
    .toMatch(new RegExp(`^${escaped(text)}`));
});

When(
  "I fill {string} in the record dialog {string} with {string}",
  async ({ page }, field: string, dialog: string, value: string) => {
    await page.locator(dialog).locator(`[name='${field}']`).fill(value);
  },
);

When("I click {string} in the record dialog {string}", async ({ page }, button: string, dialog: string) => {
  await page.locator(dialog).getByRole("button", { exact: true, name: button }).click();
});

When("the record links API links every pair of kinds", async ({ app, request, tokens }) => {
  const linkable = kinds.filter((kind) => !kind.startsWith("note"));
  paired = {};
  for (const kind of linkable) paired[kind] = await insertRecord(app.sql, kind, `A ${kind}`);
  for (const [index, kind] of linkable.entries()) {
    for (const other of linkable.slice(index + 1)) {
      const body = JSON.stringify({ other_id: paired[other], other_kind: other });
      const answer = (await api(request, tokens.api, `POST /api/v1/links/${kind}/${paired[kind]}`, body)) as {
        kind?: string;
      };
      expect(answer.kind, JSON.stringify(answer)).toBe(kind);
    }
  }
});

Then("the record links API shows each record linked to every other kind", async ({ request, tokens }) => {
  for (const [kind, id] of Object.entries(paired)) {
    const answer = (await api(request, tokens.api, `GET /api/v1/links/${kind}/${id}`)) as {
      links: Record<string, { id: number }[]>;
    };
    const ids = Object.fromEntries(Object.entries(answer.links).map(([other, rows]) => [other, rows.map((r) => r.id)]));
    const others = Object.fromEntries(
      Object.entries(paired)
        .filter(([other]) => other !== kind)
        .map(([other, otherId]) => [other, [otherId]]),
    );

    expect(ids, kind).toEqual(others);
  }
});

Then(
  "the record MCP tool {string} answers as {string} does, given:",
  async ({ request, tokens }, tool: string, call: string, data: string) => {
    const [method] = call.split(" ");
    const expected = await okApi(request, tokens.api, call, method === "GET" ? undefined : data);

    expect(await mcp(request, tokens.mcp, tool, data)).toEqual(expected);
  },
);

Then(
  "the record MCP tool {string} answers as {string} does once {string} undoes it, given:",
  async ({ request, tokens }, tool: string, call: string, undo: string, data: string) => {
    const [method, path, ...body] = undo.split(" ");
    const expected = await okApi(request, tokens.api, call, call.startsWith("DELETE") ? undefined : data);
    await okApi(request, tokens.api, `${method} ${path}`, body.length ? body.join(" ") : undefined);

    expect(await mcp(request, tokens.mcp, tool, data)).toEqual(expected);
  },
);

Then(
  "the record MCP tool {string} gives the message {string} answers, given:",
  async ({ request, tokens }, tool: string, call: string, data: string) => {
    const [method] = call.split(" ");
    const expected = (await api(request, tokens.api, call, method === "GET" ? undefined : data)) as {
      message: string;
    };
    const reply = await rpc(request, tokens.mcp, "tools/call", { arguments: JSON.parse(data), name: tool });

    expect(reply.result.content[0].text).toBe(expected.message);
  },
);

Then(
  "the record MCP tool {string} gives {string} within a minute of now",
  async ({ request, tokens }, tool: string, path: string) => {
    const answer = await mcp(request, tokens.mcp, tool, "{}");
    const value = path.split(".").reduce<unknown>((inner, key) => (inner as Record<string, unknown>)?.[key], answer);

    expect(Math.abs(Date.parse(String(value)) - Date.now())).toBeLessThan(60_000);
  },
);

Then("the record MCP tools {string} each say {string}", async ({ request, tokens }, names: string, text: string) => {
  const reply = await rpc(request, tokens.mcp, "tools/list", {});
  const tools = (reply.result.tools as { description: string; name: string }[]).filter(({ name }) =>
    list(names).includes(name),
  );

  expect(tools.map(({ name }) => name).sort()).toEqual(list(names).sort());
  for (const { description, name } of tools) expect(description, name).toContain(text);
});

type Reply = { body: Record<string, unknown>; challenge: string; status: number };

let reply: Reply = { body: {}, challenge: "", status: 0 };

Before(() => {
  posted = 0;
  paired = {};
  reply = { body: {}, challenge: "", status: 0 };
});

const callLinks = async (request: APIRequestContext, token: string | undefined, call: string, data?: string) => {
  const [method, path] = call.split(" ");
  const response = await request.fetch(path, {
    data: data === undefined ? undefined : JSON.parse(data),
    headers: { Authorization: `Bearer ${token}` },
    method,
  });
  reply = {
    body: trusted(parse(await response.text())) as Record<string, unknown>,
    challenge: response.headers()["www-authenticate"] ?? "",
    status: response.status(),
  };
};

When("I call the record links API with {string}", async ({ request, tokens }, call: string) => {
  await callLinks(request, tokens.api, call);
});

When("I call the record links API with {string} and:", async ({ request, tokens }, call: string, data: string) => {
  await callLinks(request, tokens.api, call, data);
});

Then("the record links API refuses for want of the {string} scope", ({}, scope: string) => {
  expect([reply.status, reply.challenge, reply.body]).toEqual([
    403,
    `Bearer error="insufficient_scope", scope="${scope}"`,
    { error: "insufficient_scope", error_description: `this endpoint needs a token with the ${scope} scope` },
  ]);
});

Then("the record links API answers {int} with errors only on {string}", ({}, status: number, field: string) => {
  expect([reply.status, Object.keys(reply.body.errors as object)]).toEqual([status, [field]]);
});

Then("the record links API message names the kinds {string}", ({}, names: string) => {
  const quoted = [...String(reply.body.message).matchAll(/"(\w+)"/g)].map(([, name]) => name);

  expect(quoted).toEqual(list(names));
});

Then("the record links API lists the titles {string}", ({}, titles: string) => {
  const links = reply.body.links as Record<string, { title: string }[]>;
  const found = Object.entries(links).map(([kind, rows]) => `${kind}: ${rows.map(({ title }) => title).join(", ")}`);

  expect(found.join("; ")).toBe(titles);
});

Then("the record links API title at {string} runs to {int} characters", ({}, path: string, length: number) => {
  const value = path.split(".").reduce<unknown>((inner, key) => (inner as Record<string, unknown>)?.[key], reply.body);

  expect(String(value)).toHaveLength(length);
});

Then(
  "the record links API answers {int} with rows at {string} holding only {string}",
  ({}, status: number, path: string, keys: string) => {
    const rows = reply.body[path] as Record<string, unknown>[];

    expect([reply.status, rows.map((row) => Object.keys(row))]).toEqual([status, [list(keys)]]);
  },
);
