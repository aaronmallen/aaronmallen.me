import { execFileSync } from "node:child_process";
import { expect, type Page } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import type postgres from "postgres";
import { insertPost } from "../support/rows.ts";
import { Before, Given, Then, When } from "../support/world.ts";

type InboxRow = Partial<
  Record<
    "account" | "arrived" | "body" | "excerpt" | "gmail" | "id" | "reply_to" | "snoozed" | "source" | "state" | "tags",
    string
  >
> & { kind: string; title: string };

const zone = "America/Chicago";
const hour = 3600 * 1000;
const day = 24 * hour;

const expand = (text: string) =>
  text.replaceAll(/\[(.) × (\d+)\]/g, (_, letter: string, count: string) => letter.repeat(Number(count)));

const unicode = (text: string) =>
  text.replaceAll(/\\u([0-9a-f]{4})/gi, (_, code: string) => String.fromCharCode(Number.parseInt(code, 16)));

const when = (value: string | undefined) => {
  if (!value) return undefined;
  return /^-?\d+$/.test(value) ? new Date(Date.now() + Number(value) * 1000) : new Date(value);
};

const inputValue = (at: Date) => {
  const parts = new Intl.DateTimeFormat("en-CA", {
    day: "2-digit",
    hour: "2-digit",
    hourCycle: "h23",
    minute: "2-digit",
    month: "2-digit",
    timeZone: zone,
    year: "numeric",
  }).formatToParts(at);
  const { day: dd, hour: hh, minute, month, year } = Object.fromEntries(parts.map(({ type, value }) => [type, value]));
  return `${year}-${month}-${dd}T${hh}:${minute}`;
};

const quickPicks = (now = new Date()) => {
  const today = Date.parse(`${inputValue(now).slice(0, 10)}T00:00:00Z`);
  const later = new Date((Math.floor(now.getTime() / hour) + 3) * hour);
  const morning = (offset: number) => `${new Date(today + offset * day).toISOString().slice(0, 10)}T08:00`;
  const picks = [
    ["Tomorrow morning", morning(1)],
    ["Next week", morning(7 - ((new Date(today).getUTCDay() + 6) % 7))],
  ];
  const sameDay = inputValue(later).slice(0, 10) === inputValue(now).slice(0, 10);
  if (sameDay) picks.unshift(["Later today", inputValue(later)]);
  return picks;
};

const recentPicks = () => {
  const now = Date.now();
  return [quickPicks(new Date(now)), quickPicks(new Date(now - 60_000))];
};

const offered = (text: string) =>
  recentPicks().map((picks) =>
    picks.some(([label]) => label === "Later today") ? text : text.replace(/,? ?Later today/, ""),
  );

const contactForm = async (sql: postgres.Sql) => {
  const [found] = await sql`SELECT id FROM mail_accounts WHERE provider = 'contact_form'`;
  if (found) return found.id as number;
  const [{ id }] = await sql`
    INSERT INTO mail_accounts (provider, name) VALUES ('contact_form', 'Contact form') RETURNING id
  `;
  return id as number;
};

const mentionedPost = async (sql: postgres.Sql) => {
  const find = () => sql`SELECT id FROM posts WHERE title = 'Mentioned post'`;
  const [found] = await find();
  if (found) return found.id as number;
  await insertPost(sql, {
    publishedAt: new Date(Date.now() - hour),
    status: "published",
    title: "Mentioned post",
    webmentions: true,
  });
  const [{ id }] = await find();
  return id as number;
};

const withId = (row: InboxRow, columns: Record<string, unknown>) =>
  row.id ? { id: Number(row.id), ...columns } : columns;

const slug = (title: string) => title.toLowerCase().replaceAll(/\W+/g, "-");

async function tag(sql: postgres.Sql, taskId: number, names: string) {
  for (const name of names.split(/[ ,]+/).filter(Boolean)) {
    await sql`
      INSERT INTO tags (name, color, scope) SELECT ${name}, 'mk-blue', 'private'
      WHERE NOT EXISTS (SELECT 1 FROM tags WHERE name = ${name} AND scope = 'private')
    `;
    await sql`
      INSERT INTO task_tags (task_id, tag_id, tag_scope)
      SELECT ${taskId}, id, 'private' FROM tags WHERE name = ${name} AND scope = 'private'
    `;
  }
}

async function seedMessage(sql: postgres.Sql, row: InboxRow, arrived: Date, snoozed_until: Date | null) {
  const status = ["read", "spam"].includes(row.state ?? "") ? row.state : "unread";
  const account = row.account && (await sql`SELECT id FROM mail_accounts WHERE address = ${row.account}`)[0];
  const thread = withId(row, {
    gmail_id: row.gmail || null,
    mail_account_id: account ? account.id : await contactForm(sql),
    marked_spam_at: status === "spam" ? new Date() : null,
    received_at: arrived,
    snoozed_until,
    status,
    subject: row.title,
  });
  const [{ id }] = await sql`INSERT INTO mail_threads ${sql(thread)} RETURNING id`;
  const message = {
    body: expand(row.body || "Hello"),
    mail_thread_id: id,
    received_at: arrived,
    reply_to: row.reply_to || "sender@example.com",
    subject: row.title,
  };
  await sql`INSERT INTO mail_messages ${sql(message)}`;
}

async function seedWebmention(sql: postgres.Sql, row: InboxRow, arrived: Date, snoozed_until: Date | null) {
  const like = row.state === "like";
  const mention = withId(row, {
    author_name: row.title,
    author_url: `https://${slug(row.title)}.example/about`,
    excerpt: like ? null : row.excerpt || `A note from ${row.title}`,
    post_id: await mentionedPost(sql),
    received_at: arrived,
    seen_at: row.state === "seen" ? new Date() : null,
    snoozed_until,
    source_url: row.source || `https://${slug(row.title)}.example/note`,
    status: ["approved", "ignored", "spam"].includes(row.state ?? "") ? row.state : "pending",
    type: like ? "like" : "mention",
  });
  await sql`INSERT INTO webmentions ${sql(mention)}`;
}

async function seedTask(sql: postgres.Sql, row: InboxRow, arrived: Date, snoozed_until: Date | null) {
  const status = ["done", "canceled"].includes(row.state ?? "") ? row.state : "open";
  const task = withId(row, {
    completed_at: status === "open" ? null : new Date(),
    created_at: arrived,
    list: row.kind === "issue" ? "external" : "next",
    position: 1,
    status,
    title: row.title,
  });
  const [{ id }] = await sql`INSERT INTO tasks ${sql(task)} RETURNING id`;
  if (row.tags) await tag(sql, id, row.tags);
  if (row.kind !== "issue") return;
  const source = {
    provider: "github",
    remote_id: `I_${id}`,
    seen_at: row.state === "seen" ? new Date() : null,
    snoozed_until,
    task_id: id,
    url: row.source || `https://github.com/aaronmallen/aaronmallen.me/issues/${id}`,
  };
  await sql`INSERT INTO task_sources ${sql(source)}`;
}

const seeders = { message: seedMessage, webmention: seedWebmention };

const seed = (sql: postgres.Sql, row: InboxRow) => {
  const seeder = seeders[row.kind as keyof typeof seeders] ?? seedTask;
  return seeder(sql, row, when(row.arrived) ?? new Date(), when(row.snoozed) ?? null);
};

Given("the inbox holds:", async ({ app }, table: DataTable) => {
  for (const row of table.hashes()) await seed(app.sql, row as InboxRow);
});

Given(
  "{int} more inbox {word}s arrived in the last minutes, titled {string} and a number",
  async ({ app }, count: number, kind: string, title: string) => {
    const start = Date.now();
    for (let n = 1; n <= count; n++) {
      const arrived = new Date(start - (60 + n) * 1000).toISOString();
      await seed(app.sql, { arrived, kind, title: `${title} ${n}` });
    }
  },
);

let posted = { location: "", status: 0 };
let openTransactions: number[] = [];

Before(() => {
  posted = { location: "", status: 0 };
  openTransactions = [];
});

Given(
  "Gmail takes changes to the inbox thread {string} and counts the open transactions",
  ({ app, stub }, id: string) => {
    const { database, host, port, user } = app.sql.options;
    const query =
      "SELECT count(*) FROM pg_stat_activity WHERE datname = current_database() AND state LIKE 'idle in transaction%'";
    stub.reply("POST", `/google/gmail/users/me/threads/${id}/modify`, () => {
      const args = ["-h", host[0], "-p", String(port[0]), "-U", user, "-d", database, "-tAc", query];
      const env = { ...process.env, PGPASSWORD: process.env.DATABASE_PASSWORD };
      openTransactions.push(Number(execFileSync("psql", args, { env }).toString().trim()));
      return { body: "{}", status: 200 };
    });
  },
);

Then("Gmail saw {int} open transaction(s) while it marked the inbox thread", ({}, count: number) => {
  expect(openTransactions).toEqual([count]);
});

const csrfToken = async (page: Page) => {
  if (!new URL(page.url(), "http://x").pathname.startsWith("/admin")) await page.goto("/admin/inbox");
  return page.locator("input[name=_csrf_token]").first().inputValue();
};

const adminPost = async (page: Page, path: string, fields: string[][], token?: string) => {
  const body = new URLSearchParams([
    ["_csrf_token", token ?? (await csrfToken(page))],
    ...fields.map(([name, value]) => [name, unicode(value ?? "")]),
  ]);
  const response = await page.request.post(path, {
    data: body.toString(),
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    maxRedirects: 0,
  });
  posted = { location: response.headers().location ?? "", status: response.status() };
};

When("I post the form to the admin {string}", ({ page }, path: string) => adminPost(page, path, []));

When("I post the form to the admin {string} with:", ({ page }, path: string, table: DataTable) =>
  adminPost(page, path, table.raw()),
);

When("I post the form to the admin {string} with a forged CSRF token", ({ page }, path: string) =>
  adminPost(page, path, [], "forged"),
);

When("I follow the admin post", async ({ page }) => {
  await page.goto(posted.location);
});

Then("the admin post answers {int}", ({}, status: number) => {
  expect(posted.status).toBe(status);
});

Then("the admin post sends me to {string}", ({}, path: string) => {
  const location = new URL(posted.location, "http://x");

  expect(posted.status).toBe(302);
  expect(location.pathname + location.search).toBe(path);
});

const texts = async (page: Page, selector: string) =>
  (await page.locator(selector).allTextContents()).map((text) => text.replaceAll(/\s+/g, " ").trim());

Then("the admin toast says {string}", async ({ page }, text: string) => {
  await expect.poll(() => texts(page, "[data-toast] .toast")).toContainEqual(expect.stringContaining(text));
});

const titles = async (page: Page) => {
  await page.goto("/admin/inbox");
  return texts(page, "[data-key-list] .inbox-row-title");
};

Then("the inbox shows the rows {string}", async ({ page }, list: string) => {
  expect((await titles(page)).join(", ")).toBe(list);
});

Then("the inbox shows no rows", async ({ page }) => {
  expect(await titles(page)).toEqual([]);
});

Then("the inbox shows {int} rows, starting with {string}", async ({ page }, count: number, first: string) => {
  const shown = await titles(page);

  expect(shown).toHaveLength(count);
  expect(shown[0]).toBe(first);
});

const paletteCount = async (page: Page, entry: string) => {
  await page.goto("/admin");
  await expect(page.locator(`#command-palette-${entry}`)).toBeAttached();
  return (await texts(page, `#command-palette-${entry} .pal-r-sub`)).join(", ");
};

Then("the command palette's {word} entry counts {string}", async ({ page }, entry: string, count: string) => {
  expect(await paletteCount(page, entry)).toBe(count);
});

Then("the command palette's {word} entry shows no count", async ({ page }, entry: string) => {
  expect(await paletteCount(page, entry)).toBe("");
});

const attributes = (page: Page, selector: string, name: string) =>
  page.locator(selector).evaluateAll((nodes, attribute) => nodes.map((node) => node.getAttribute(attribute)), name);

Then("the inbox screen's {string} read {string}", async ({ page }, selector: string, list: string) => {
  const expected = offered(expand(list));

  await expect.poll(async () => expected.includes((await texts(page, selector)).join(", "))).toBe(true);
});

Then("the inbox screen's {string} include {string}", async ({ page }, selector: string, list: string) => {
  await expect(page.locator(selector).first()).toBeAttached();
  const found = await texts(page, selector);

  for (const item of list.split(", ")) expect(found).toContain(item);
});

Then("the inbox screen's {string} leave out {string}", async ({ page }, selector: string, list: string) => {
  await expect(page.locator(selector).first()).toBeAttached();
  const found = await texts(page, selector);

  for (const item of list.split(", ")) expect(found).not.toContain(item);
});

Then(
  "the inbox screen's {string} carry {string} {string}",
  async ({ page }, selector: string, attribute: string, list: string) => {
    expect((await attributes(page, selector, attribute)).join(", ")).toBe(list);
  },
);

Then(
  "every {string} on the inbox screen carries {string} {string}",
  async ({ page }, selector: string, attribute: string, value: string) => {
    const values = await attributes(page, selector, attribute);

    expect(values.length).toBeGreaterThan(0);
    expect([...new Set(values)]).toEqual([value]);
  },
);

Then("the inbox screen has {string}", async ({ page }, selector: string) => {
  await expect(page.locator(selector).first()).toBeAttached();
});

Then("the inbox screen has no {string}", async ({ page }, selector: string) => {
  await expect(page.locator(selector)).toHaveCount(0);
});

Then("the inbox screen holds {int} of {string}", async ({ page }, count: number, selector: string) => {
  await expect(page.locator(selector)).toHaveCount(count);
});

Then("the inbox screen's {string} post {string}", async ({ page }, selector: string, list: string) => {
  const fields = await page
    .locator(`${selector} input[type=hidden]:not([name=_csrf_token])`)
    .evaluateAll((nodes) => nodes.map((node) => `${node.getAttribute("name")}=${node.getAttribute("value")}`));

  expect(fields.sort()).toEqual(list.split(", ").sort());
});

Then("the snooze dialog {string} offers the quick picks for now", async ({ page }, selector: string) => {
  const buttons = await page
    .locator(`${selector} button[name=pick]`)
    .evaluateAll((nodes) => nodes.map((node) => [node.textContent?.trim(), node.getAttribute("value")]));

  expect(recentPicks()).toContainEqual(buttons);
});

Then("the snooze dialog {string} offers the quick pick labels", async ({ page }, selector: string) => {
  const labels = await texts(page, `${selector} button[name=pick]`);

  expect(recentPicks().map((picks) => picks.map(([label]) => label))).toContainEqual(labels);
});

Then("the forms {string} post the quick picks for now", async ({ page }, selector: string) => {
  const values = await attributes(page, `${selector} input[name=pick]`, "value");

  expect(recentPicks().map((picks) => picks.map(([, value]) => value))).toContainEqual(values);
});

Then("the inbox screen's {string} starts at the current minute", async ({ page }, selector: string) => {
  const min = await page.locator(selector).first().getAttribute("min");
  const now = Date.now();

  expect([inputValue(new Date(now)), inputValue(new Date(now - 60_000))]).toContain(min);
});

When(
  "I edit the inbox issue {string} in the drawer, setting {string} to {string}",
  async ({ page }, title: string, field: string, value: string) => {
    await page.locator(".inbox-row", { hasText: title }).getByRole("link", { exact: true, name: "Edit" }).click();
    const panel = page.locator("dialog#task-panel[open]");
    await expect(panel.locator("[data-task-edit]")).toBeAttached();
    await expect(page).toHaveURL(/\/admin\/inbox$/);
    const input =
      field === "Tags" ? panel.getByRole("combobox", { name: "Tags" }) : panel.locator(`[name="task[${field}]"]`);
    await input.fill(value);
    await panel.getByRole("button", { exact: true, name: "Save" }).click();
    await expect(panel.locator("[data-task-read]")).toBeAttached();
  },
);

When("I close the task drawer", async ({ page }) => {
  await page.locator("dialog#task-panel[open] .task-drawer-close").click();
  await expect(page.locator("dialog#task-panel[open]")).toHaveCount(0);
});

Then("the browser stays on {string}", async ({ page }, path: string) => {
  await expect.poll(() => new URL(page.url()).pathname).toBe(path);
});

Then("the inbox screen shows the row {string}", async ({ page }, title: string) => {
  await expect(page.locator(".inbox-row", { hasText: title })).toHaveCount(1);
});

Then("the inbox screen drops the row {string}", async ({ page }, title: string) => {
  await expect(page.locator(".inbox-row", { hasText: title })).toHaveCount(0);
});

const box = (page: Page, selector: string) =>
  page
    .locator(selector)
    .first()
    .evaluate((node) => node.getBoundingClientRect().toJSON());

Then("the inbox row's buttons sit to the right of its title", async ({ page }) => {
  const title = await box(page, ".inbox-row-main");
  const side = await box(page, ".inbox-row-acts");

  expect(side.left).toBeGreaterThanOrEqual(title.right);
  expect(side.top).toBeLessThan(title.bottom);
});

Then("the inbox row's buttons sit below its title", async ({ page }) => {
  await expect
    .poll(async () => (await box(page, ".inbox-row-acts")).top - (await box(page, ".inbox-row-main")).bottom)
    .toBeGreaterThanOrEqual(0);
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
  "the MCP tool {string} answers what {string} does, once its marks come off",
  async ({ request, tokens }, tool: string, call: string) => {
    const [method, path] = call.split(" ");
    const api = await request.fetch(path, { headers: { Authorization: `Bearer ${tokens.api}` }, method });
    const mcp = await request.post("/mcp", {
      data: { id: 1, jsonrpc: "2.0", method: "tools/call", params: { arguments: {}, name: tool } },
      headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${tokens.mcp}` },
    });
    const { result } = await mcp.json();

    expect(api.ok()).toBe(true);

    expect(trusted(JSON.parse(result.content[0].text))).toEqual(await api.json());
  },
);

Then(
  "the API inbox gives the row {int} the excerpt {string}",
  async ({ request, tokens }, id: number, excerpt: string) => {
    const response = await request.get("/api/v1/inbox", { headers: { Authorization: `Bearer ${tokens.api}` } });
    const { inbox } = await response.json();

    expect(inbox.find((row: { id: number }) => row.id === id)?.excerpt).toBe(expand(excerpt));
  },
);
