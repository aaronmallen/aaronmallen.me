import { createHash, randomBytes } from "node:crypto";
import { rmSync } from "node:fs";
import { resolve } from "node:path";
import { expect, type Locator, type Page } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import type postgres from "postgres";
import { seal } from "../support/seal.ts";
import { ownerEmail } from "../support/stub.ts";
import { Before, Given, Then, When } from "../support/world.ts";

const zone = "America/Chicago";
const today = `(now() AT TIME ZONE '${zone}')::date`;
const agents: Record<string, string> = {
  Chrome: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/141.0.0.0 Safari/537.36",
  Firefox: "Mozilla/5.0 (X11; Linux x86_64; rv:131.0) Gecko/20100101 Firefox/131.0",
  curl: "curl/8.7.1",
};

let posted = { body: "", location: "", status: 0 };
let deadJob = { at: 0, jid: "" };
let named: Record<string, string> = {};

Before(() => {
  posted = { body: "", location: "", status: 0 };
  deadJob = { at: 0, jid: "" };
  named = {};
});

const norm = (text: string | null) => (text ?? "").replace(/\s+/g, " ").trim();
const list = (text: string) => (text ? text.split(", ") : []);
const lines = (text: string) => text.split("\n").map((line) => line.trim());
const escaped = (text: string) => text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const exact = (text: string) => new RegExp(`^\\s*${escaped(text)}\\s*$`);
const texts = async (locator: Locator) => (await locator.allTextContents()).map(norm);

const chicago = (date: Date, options: Intl.DateTimeFormatOptions) =>
  new Intl.DateTimeFormat("en-US", { timeZone: zone, ...options }).format(date);

const clock = (date: Date) => chicago(date, { hour: "2-digit", hourCycle: "h23", minute: "2-digit" });

const dayAhead = (days: number) => {
  const date = new Date(Date.now() + days * 86_400_000);
  return chicago(date, { day: "numeric", month: "short" });
};

const expand = (text: string) => text.replace(/<today([+-]\d+)>/g, (_, days) => dayAhead(Number(days)));

const todaySprint = async (sql: postgres.Sql) => {
  await sql.unsafe(`INSERT INTO sprints (sprint_date) VALUES (${today}) ON CONFLICT DO NOTHING`);
  const [{ id }] = await sql.unsafe(`SELECT id FROM sprints WHERE sprint_date = ${today}`);
  return id as number;
};

const nextPosition = async (sql: postgres.Sql) => {
  const [{ position }] = await sql`SELECT coalesce(max(position), 0) + 1 AS position FROM tasks`;
  return position as number;
};

const syncPrint = async (sql: postgres.Sql) =>
  (
    await sql`
      SELECT coalesce(string_agg(concat_ws('/', id, kind, sync, repo, synced_at, failure_count), ','), '') AS print
      FROM sync_states
    `
  )[0].print as string;

type Worker = { pushJob: (job: string, ...args: unknown[]) => Promise<void>; sql: postgres.Sql };

const runSync = async (app: Worker, job: string, args: unknown[]) => {
  const before = await syncPrint(app.sql);
  await app.pushJob(job, ...args);
  await expect.poll(() => syncPrint(app.sql), { timeout: 30_000 }).not.toBe(before);
};

const line = (page: Page, label: string) =>
  page.locator("a.today-line").filter({ has: page.locator(":scope > span:first-child", { hasText: exact(label) }) });

const card = (page: Page) => page.locator("section.card[data-attention]");

const row = (page: Page, title: string) =>
  card(page)
    .locator(".li")
    .filter({ has: page.locator(".li-title", { hasText: exact(title) }) });

const titled = (page: Page, title: string) =>
  page.locator("section.card").filter({ has: page.locator("h2.card-title", { hasText: exact(title) }) });

const shipped = (page: Page) => titled(page, "Shipped today");
const calendar = (page: Page) => page.locator("section.card[data-today-calendar]");
const panel = (page: Page) => page.locator("[data-sprint-panel]");
const pulls = (page: Page) => panel(page).locator(".task-planner-pull");
const sprintTask = (page: Page, title: string) =>
  panel(page)
    .locator(".task")
    .filter({ has: page.locator(".task-title", { hasText: exact(title) }) });
const event = (page: Page, title: string) =>
  calendar(page)
    .locator(".today-event")
    .filter({ has: page.locator(".cal-event-name", { hasText: exact(title) }) });
const commit = (page: Page, message: string) =>
  shipped(page)
    .locator(".commits .commit")
    .filter({ has: page.locator(".commit-message", { hasText: exact(message) }) });

const pathOf = (url: URL) => `${url.pathname}${url.search}`;

const send = async (page: Page, form: Locator) => {
  const action = pathOf(new URL((await form.getAttribute("action")) ?? "", page.url()));
  const answered = page.waitForResponse(
    (response) => response.request().method() === "POST" && pathOf(new URL(response.url())) === action,
  );
  await form.evaluate((element) => HTMLFormElement.prototype.submit.call(element));
  const response = await answered;
  const location = (await response.headerValue("location")) ?? "";
  posted = { body: "", location, status: response.status() };
  const landing = location ? pathOf(new URL(location, response.url())) : action;
  await page.waitForURL((url) => pathOf(url) === landing);
  await page.waitForLoadState();
};

const csrf = async (page: Page) => {
  if (!new URL(page.url(), "http://x").pathname.startsWith("/admin")) await page.goto("/admin");
  return (await page.locator("input[name=_csrf_token]").first().getAttribute("value")) ?? "";
};

Given("the Today page has a GitHub token", async ({ app }) => {
  const credentials = seal(JSON.stringify({ access_token: "ghp_token" }));
  await app.sql`
    INSERT INTO service_connections (provider, account_id, label, credentials, scopes)
    VALUES ('github', '931094', '@aaronmallen', ${credentials}, '{repo}')
  `;
});

const connectLinkedIn = async (sql: postgres.Sql, label: string, days: number | null) => {
  const credentials = seal(
    JSON.stringify({ access_token: "li-token", expires_at: Math.floor(Date.now() / 1000) + 3600 }),
  );
  await sql`
    INSERT INTO service_connections (provider, account_id, label, credentials, scopes, lapses_at)
    VALUES ('linkedin', 'member-ada', ${label}, ${credentials}, '{openid}',
            CASE WHEN ${days}::int IS NULL THEN NULL ELSE now() + make_interval(days => ${days}::int) END)
  `;
};

Given(
  "an attention LinkedIn connection for {string} that lapses in {int} day(s)",
  async ({ app }, label: string, days: number) => {
    await connectLinkedIn(app.sql, label, days);
  },
);

Given(
  "an attention LinkedIn connection for {string} that lapsed {int} day(s) ago",
  async ({ app }, label: string, days: number) => {
    await connectLinkedIn(app.sql, label, -days);
  },
);

Given("an attention LinkedIn connection for {string} that never lapses", async ({ app }, label: string) => {
  await connectLinkedIn(app.sql, label, null);
});

Given("today's sprint plans {string}", async ({ app }, titles: string) => {
  const sprint = await todaySprint(app.sql);
  for (const title of list(titles)) {
    await app.sql`INSERT INTO tasks ${app.sql({ position: await nextPosition(app.sql), sprint_id: sprint, title })}`;
  }
});

Given("today's sprint plans {string} with {int} done", async ({ app }, titles: string, done: number) => {
  const sprint = await todaySprint(app.sql);
  for (const [index, title] of list(titles).entries()) {
    const position = await nextPosition(app.sql);
    const closed = index < done ? { completed_at: new Date(), status: "done" } : {};
    await app.sql`INSERT INTO tasks ${app.sql({ position, sprint_id: sprint, title, ...closed })}`;
  }
});

Given("today's sprint holds the canceled task {string}", async ({ app }, title: string) => {
  const sprint = await todaySprint(app.sql);
  const position = await nextPosition(app.sql);
  await app.sql`
    INSERT INTO tasks ${app.sql({ completed_at: new Date(), position, sprint_id: sprint, status: "canceled", title })}
  `;
});

Given("the Today pool {word} holds {string}", async ({ app }, name: string, titles: string) => {
  for (const title of list(titles)) {
    await app.sql`INSERT INTO tasks ${app.sql({ list: name, position: await nextPosition(app.sql), title })}`;
  }
});

Given("these commits for the Today page:", async ({ app }, table: DataTable) => {
  for (const [index, commit] of table.hashes().entries()) {
    const days = commit.day === "yesterday" ? 1 : 0;
    const sha = commit.sha || createHash("sha1").update(`${index}-${commit.message}`).digest("hex");
    await app.sql.unsafe(
      `INSERT INTO commits (sha, repo, branch, message, commit_date, commit_time, additions, deletions)
        VALUES ($1, $2, 'main', $3, ${today} - ${days}, $4, $5, $6)`,
      [
        sha,
        commit.repo || "aaronmallen/aaronmallen.me",
        commit.message.replaceAll("\\n", "\n"),
        commit.time || "09:00",
        Number(commit.additions || 1),
        Number(commit.deletions || 0),
      ],
    );
  }
});

Given("these calendar events for the Today page:", async ({ app }, table: DataTable) => {
  const at = (value: string, day: number) => {
    const offset = value.match(/^([+-])(?:(\d+)h)? ?(?:(\d+)m)?$/);
    if (offset) {
      const minutes = Number(offset[2] ?? 0) * 60 + Number(offset[3] ?? 0);
      return `(now() ${offset[1]} make_interval(mins => ${minutes}))`;
    }
    return `(((${today} + ${day}) + time '${value}') AT TIME ZONE '${zone}')`;
  };
  for (const [index, event] of table.hashes().entries()) {
    const name = event.calendar || "Aaron";
    await app.sql`
      INSERT INTO calendars (account, google_id, name, hidden)
      VALUES ('me@example.com', ${`calendar-${name}`}, ${name}, ${name === "Hidden"})
      ON CONFLICT DO NOTHING
    `;
    const day = Number(event.day || 0);
    const starts = event.starts ? at(event.starts, day) : "NULL";
    const ends = event.ends ? at(event.ends, day) : "NULL";
    const startsOn = event.starts ? `(${starts} AT TIME ZONE '${zone}')::date` : `${today} + ${day}`;
    const endsOn = event.until ? `${today} + ${Number(event.until)}` : startsOn;
    await app.sql.unsafe(
      `INSERT INTO calendar_events
          (calendar_id, google_id, title, starts_on, ends_on, starts_at, ends_at, place, meet_url, notes, attendees,
          link)
        SELECT id, $1, $2, ${startsOn}, ${endsOn}, ${starts}, ${ends}, $3, $4, $5, $6, $7
        FROM calendars WHERE google_id = $8`,
      [
        `event-${index}`,
        event.title,
        event.place || null,
        event.meet || null,
        event.notes || null,
        event.guests ? event.guests.split(", ") : [],
        event.link || null,
        `calendar-${name}`,
      ],
    );
  }
});

const killJob = async (
  redis: { zAdd: (key: string, member: { score: number; value: string }) => Promise<unknown> },
  name: string,
  { args = [] as unknown[], at = Date.now() / 1000, error = "boom", queue = "default", set = "dead" } = {},
) => {
  const jid = randomBytes(12).toString("hex");
  const job = { args, class: name, error_class: "RuntimeError", error_message: error, failed_at: at, jid, queue };
  await redis.zAdd(set, { score: at, value: JSON.stringify({ ...job, retry: 3 }) });
  deadJob = { at, jid };
};

Given("the dead job {string} died {int} minute(s) ago", async ({ app }, name: string, minutes: number) => {
  await killJob(app.redis.client, name, { at: Date.now() / 1000 - minutes * 60 });
});

Given(
  "the dead job {string} died {int} minute(s) ago with the error {string}",
  async ({ app }, name: string, minutes: number, error: string) => {
    await killJob(app.redis.client, name, { at: Date.now() / 1000 - minutes * 60, error });
  },
);

Given(
  "the dead job {string} died at {string} with the error {string}",
  async ({ app }, name: string, time: string, error: string) => {
    await killJob(app.redis.client, name, { at: Date.parse(time) / 1000, error });
  },
);

Given(
  "the dead job {string} from the queue {string} died {int} minute(s) ago",
  async ({ app }, name: string, queue: string, minutes: number) => {
    await killJob(app.redis.client, name, { at: Date.now() / 1000 - minutes * 60, queue });
  },
);

Given(
  "the dead commit backfill for {string} died {int} minute(s) ago",
  async ({ app }, repo: string, minutes: number) => {
    await killJob(app.redis.client, "Record::Jobs::BackfillRepoCommits", {
      args: [repo, new Date().toISOString()],
      at: Date.now() / 1000 - minutes * 60,
    });
  },
);

Given("the job {string} waits to retry", async ({ app }, name: string) => {
  await killJob(app.redis.client, name, { at: Date.now() / 1000 + 60, set: "retry" });
});

Given("an attention API token named {string}", async ({ app }, name: string) => {
  named[name] = randomBytes(32).toString("base64url");
  const digest = createHash("sha256").update(named[name]).digest("hex");
  await app.sql`INSERT INTO api_tokens ${app.sql({ name, token_digest: digest })}`;
});

When("the attention API token {string} calls from {word}", async ({ request }, name: string, agent: string) => {
  const response = await request.get("/api/v1/token", {
    headers: { Authorization: `Bearer ${named[name]}`, "User-Agent": agents[agent] },
  });

  expect(response.status()).toBe(200);
});

When("the attention MCP client calls from {word}", async ({ request, tokens }, agent: string) => {
  const response = await request.post("/mcp", {
    data: { id: 1, jsonrpc: "2.0", method: "tools/list" },
    headers: {
      Accept: "application/json, text/event-stream",
      Authorization: `Bearer ${tokens.mcp}`,
      ...(agents[agent] ? { "User-Agent": agents[agent] } : {}),
    },
  });

  expect(response.status()).toBe(200);
});

When("a sign-in to the admin comes from {word}", async ({ app, browser }, agent: string) => {
  await app.sql`INSERT INTO owner_identities ${app.sql({ email: ownerEmail })} ON CONFLICT DO NOTHING`;
  const context = await browser.newContext({ baseURL: app.url, userAgent: agents[agent] });
  const page = await context.newPage();
  await page.goto("/admin/sign-in");
  const callback = page.waitForResponse((response) => response.url().includes("/auth/github/callback"));
  await page.getByRole("button", { name: /GitHub/ }).click();
  await callback;
  await page.waitForLoadState();
  await context.close();
});

When("the Today link check runs", async ({ app }) => {
  const [{ count }] = await app.sql`SELECT count(*)::int AS count FROM link_check_runs WHERE finished_at IS NOT NULL`;
  await app.pushJob("Posts::Jobs::CheckPostLinks");
  await expect
    .poll(
      async () =>
        (await app.sql`SELECT count(*)::int AS count FROM link_check_runs WHERE finished_at IS NOT NULL`)[0].count,
      { timeout: 30_000 },
    )
    .toBe(count + 1);
});

When("the sprint roll over job runs", async ({ app }) => {
  await app.pushJob("Tasks::Jobs::RollOverSprint");
  await expect
    .poll(
      async () =>
        (
          await app.sql`
            SELECT count(*)::int AS count FROM performance_jobs WHERE job = 'Tasks::Jobs::RollOverSprint'
          `
        )[0].count,
      { timeout: 30_000 },
    )
    .toBeGreaterThan(0);
  await expect
    .poll(
      async () =>
        (
          await app.sql.unsafe(
            `SELECT count(*)::int AS count FROM tasks JOIN sprints ON sprints.id = tasks.sprint_id
              WHERE sprints.sprint_date < ${today} AND tasks.status = 'open'`,
          )
        )[0].count,
      { timeout: 30_000 },
    )
    .toBe(0);
});

When("I post {string} from the Today page with {string}", async ({ page }, path: string, fields: string) => {
  const form = { _csrf_token: await csrf(page), ...Object.fromEntries(new URLSearchParams(fields)) };
  const response = await page.request.post(path, { form, maxRedirects: 0 });
  posted = { body: await response.text(), location: response.headers().location ?? "", status: response.status() };
});

Then("the Today post answers {int}", ({}, status: number) => {
  expect(posted.status, posted.body).toBe(status);
});

Then("the Today post sends me to {string}", ({}, location: string) => {
  expect(new URL(posted.location, "http://x").href.replace(/^http:\/\/[^/]+/, "")).toBe(location);
});

When("I send the {string} form on the attention row {string}", async ({ page }, label: string, title: string) => {
  await send(page, row(page, title).locator(`form:has([aria-label="${label}"])`));
});

When("I send the {string} form on the sprint task {string}", async ({ page }, label: string, title: string) => {
  await send(page, sprintTask(page, title).locator(`form:has([aria-label="${label}"])`));
});

When("I pull {string} into today from the pools", async ({ page }, title: string) => {
  const item = pulls(page)
    .locator(".li")
    .filter({ has: page.locator(".li-title", { hasText: exact(title) }) });
  await send(page, item.locator("form[action$='/move/today']"));
});

When("I send the Create Task dialog with the title {string}", async ({ page }, title: string) => {
  const form = page.locator("dialog#task-create form[action='/admin/tasks']");
  await form.locator("[name='task[title]']").evaluate((input, value) => {
    (input as HTMLInputElement).value = value;
  }, title);
  await send(page, form);
});

When("I open the menu of the attention row {string}", async ({ page }, title: string) => {
  const menu = await row(page, title).getAttribute("data-menu");
  await page.goto(`${menu}?return_to=/admin`);
});

When("I follow the link under the commit list", async ({ page }) => {
  await page.goto((await shipped(page).locator(".commits-foot a").getAttribute("href")) ?? "");
});

Then("the Today page sends me to {string}", async ({ page }, path: string) => {
  await expect(page).toHaveURL((url) => `${url.pathname}${url.search}` === path);
});

Then("the activity page mentions {string}", async ({ page }, text: string) => {
  expect(norm(await page.locator("body").textContent())).toContain(text);
});

Then("the Today line {string} reads {string}", async ({ page }, label: string, value: string) => {
  expect(norm(await line(page, label).locator(".today-line-value").textContent())).toBe(value);
});

Then("the Today line {string} ends with {string}", async ({ page }, label: string, value: string) => {
  expect(norm(await line(page, label).locator(".today-line-value").textContent())).toMatch(
    new RegExp(`${escaped(value)}$`),
  );
});

Then("the Today line {string} links to {string}", async ({ page }, label: string, href: string) => {
  await expect(line(page, label)).toHaveAttribute("href", href);
});

Then("the Today line {string} links to the post {string}", async ({ app, page }, label: string, title: string) => {
  const [{ id }] = await app.sql`SELECT id FROM posts WHERE title = ${title}`;

  await expect(line(page, label)).toHaveAttribute("href", `/admin/posts/${id}/edit`);
});

Then("the Today page has no line {string}", async ({ page }, label: string) => {
  await expect(line(page, label)).toHaveCount(0);
});

Then("the Today line {string} has the time {string}", async ({ page }, label: string, datetime: string) => {
  await expect(line(page, label).locator("time")).toHaveAttribute("datetime", datetime);
});

Then("the Today line {string} opens the dialog {string}", async ({ page }, label: string, dialog: string) => {
  await expect(line(page, label)).toHaveAttribute("data-dialog-open", dialog);
});

Then("the Today line {string} shows the key {string}", async ({ page }, label: string, key: string) => {
  await expect(line(page, label).locator("kbd.kbd")).toHaveText(exact(key));
});

Then("the Today line {string} warns", async ({ page }, label: string) => {
  await expect(line(page, label).locator(".today-line-value.warn")).toHaveCount(1);
});

Then("the Today line {string} does not warn", async ({ page }, label: string) => {
  await expect(line(page, label).locator(".warn")).toHaveCount(0);
});

Then("the quiet Today lines are {string}", async ({ page }, labels: string) => {
  const found = await texts(page.locator(".today-side > .card:last-child .today-line > span:first-child"));

  expect(found).toEqual(list(labels));
});

Then("the Today {word} column holds the cards {string}", async ({ page }, column: string, titles: string) => {
  expect(await texts(page.locator(`.today-${column} > section.card h2.card-title`))).toEqual(list(titles));
});

Then("the Today page has no card {string}", async ({ page }, title: string) => {
  await expect(titled(page, title)).toHaveCount(0);
});

Then("the Today page shows no stat strip", async ({ page }) => {
  await expect(page.locator(".stat")).toHaveCount(0);
});

Then("the command palette's Inbox reads {string}", async ({ page }, text: string) => {
  expect(norm(await page.locator("#command-palette-inbox .pal-r-sub").textContent())).toBe(text);
});

Then("the attention card lists:", async ({ page }, titles: string) => {
  await expect
    .poll(async () => {
      await page.waitForLoadState();
      return texts(card(page).locator(".li-title")).catch(() => []);
    })
    .toEqual(lines(titles));
});

Then("the attention card is not shown", async ({ page }) => {
  await expect(card(page)).toHaveCount(0);
});

Then("the attention card counts {string}", async ({ page }, count: string) => {
  await expect(card(page).locator(".card-side")).toHaveText(exact(count));
});

Then("the attention row {string} says {string}", async ({ page }, title: string, sub: string) => {
  expect(await texts(row(page, title).locator(".li-sub"))).toContain(sub);
});

Then("the attention row {string} says only {string}", async ({ page }, title: string, sub: string) => {
  expect(await texts(row(page, title).locator(".li-sub"))).toEqual([sub]);
});

Then("the attention row {string} ends with {string}", async ({ page }, title: string, ending: string) => {
  expect(norm(await row(page, title).locator(".li-sub").textContent())).toMatch(new RegExp(`${escaped(ending)}$`));
});

Then("the attention row {string} gives the time the job died", async ({ page }, title: string) => {
  const datetime = await row(page, title).locator(".li-sub time").getAttribute("datetime");

  expect(Date.parse(datetime ?? "") / 1000).toBe(Math.floor(deadJob.at));
});

Then("the attention row {string} opens {string}", async ({ page }, title: string, href: string) => {
  await expect(row(page, title).locator(".li-title")).toHaveAttribute("href", href);
});

Then("every link on the attention row {string} goes to {string}", async ({ page }, title: string, href: string) => {
  const hrefs = await row(page, title)
    .locator("a")
    .evaluateAll((links) => links.map((link) => link.getAttribute("href")));

  expect([...new Set(hrefs)]).toEqual([href]);
});

Then(
  "every link on the attention row {string} opens the dialog {string}",
  async ({ page }, title: string, dialog: string) => {
    const opens = await row(page, title)
      .locator("a")
      .evaluateAll((links) => links.map((link) => link.getAttribute("data-dialog-open")));

    expect([...new Set(opens)]).toEqual([dialog]);
  },
);

Then(
  "the attention row {string} offers {string} at {string}",
  async ({ page }, title: string, label: string, href: string) => {
    await expect(row(page, title).locator(`a[title="${label}"]`)).toHaveAttribute("href", href);
  },
);

Then(
  "the attention row {string} asks {string} before {string}",
  async ({ page }, title: string, question: string, label: string) => {
    await expect(row(page, title).locator(`form:has([aria-label="${label}"])`)).toHaveAttribute(
      "data-confirm",
      question,
    );
  },
);

Then(
  "the attention row {string} names {string} before {string}",
  async ({ page }, title: string, name: string, label: string) => {
    const question = await row(page, title).locator(`form:has([aria-label="${label}"])`).getAttribute("data-confirm");

    expect(question).toContain(name);
  },
);

Then("the attention row {string} snoozes as {string}", async ({ page }, title: string, kind: string) => {
  await expect(
    row(page, title).locator(`form[action='/admin/attention/snooze'] input[name=kind][value="${kind}"]`),
  ).toHaveCount(1);
});

Then("the attention row {string} posts {string} to:", async ({ page }, title: string, field: string, docs: string) => {
  const forms = row(page, title).locator("form:has([aria-label='Retry']), form:has([aria-label='Discard'])");
  const actions = await forms.evaluateAll((all) => all.map((form) => form.getAttribute("action")));
  const values = await forms
    .locator(`input[name=${field.split("=")[0]}]`)
    .evaluateAll((all) => [...new Set(all.map((input) => (input as HTMLInputElement).value))]);

  expect(actions).toEqual(lines(docs).map((action) => action.replace("<jid>", deadJob.jid)));
  expect(values).toEqual([field.split("=")[1]]);
});

Then("the attention row {string} has the menu of the dead job", async ({ page }, title: string) => {
  await expect(row(page, title)).toHaveAttribute("data-menu", `/admin/settings/jobs/dead/${deadJob.jid}/menu`);
});

Then(
  "the {string} button on the attention row {string} shows a trash can",
  async ({ page }, label: string, title: string) => {
    await expect(row(page, title).locator(`button[aria-label="${label}"] i.fa-regular.fa-trash-can`)).toHaveCount(1);
  },
);

Then("the dead job menu offers {string}", async ({ page }, labels: string) => {
  expect(await texts(page.locator(".ctx-label"))).toEqual(list(labels));
});

Then("the dead job menu copies {string}", async ({ page }, text: string) => {
  await expect(page.locator("[data-copy]")).toHaveAttribute("data-copy", text);
});

Then("the Today page shows no sync failures", async ({ page }) => {
  await expect(page.locator(".sync-failures")).toHaveCount(0);
});

Then("the sync failures read:", async ({ page }, docs: string) => {
  expect(await texts(page.locator(".sync-failures .sync-failure"))).toEqual(lines(docs));
});

Then("the sync failures match:", async ({ page }, docs: string) => {
  const found = await texts(page.locator(".sync-failures .sync-failure"));
  const patterns = lines(docs).map((pattern) => new RegExp(`^${escaped(pattern).replaceAll("<any>", ".+")}$`));

  expect(found).toHaveLength(patterns.length);
  for (const [index, text] of found.entries()) expect(text).toMatch(patterns[index]);
});

Then("the Today page shows {int} sync failure(s)", async ({ page }, count: number) => {
  await expect(page.locator(".sync-failures .sync-failure")).toHaveCount(count);
});

Then("the sync failure warns with a sign", async ({ page }) => {
  await expect(page.locator(".sync-failures .sync-failure i.fa-triangle-exclamation")).toHaveCount(1);
});

Then("the sync failure has the time {string}", async ({ page }, datetime: string) => {
  await expect(page.locator(".sync-failure time")).toHaveAttribute("datetime", datetime);
});

Then("the Today page never names {string}", async ({ page }, text: string) => {
  expect(await page.content()).not.toContain(text);
});

Then("the Today page has no link to a backfill", async ({ page }) => {
  await expect(page.locator("a[href^='/admin/commits/backfill']")).toHaveCount(0);
});

Then("the Today kicker shows the day and the time", async ({ page }) => {
  const day = (date: Date) =>
    `${chicago(date, { weekday: "long" })}, ${chicago(date, { day: "numeric", month: "long" })} · ${clock(date)}`;
  const kicker = norm(await page.locator(".page-head-kicker").textContent());

  expect([day(new Date()), day(new Date(Date.now() - 60_000))]).toContain(kicker);
});

Then("the Today headline reads {string}", async ({ page }, text: string) => {
  await expect(page.locator(".page-head-title")).toHaveText(exact(text));
});

Then("the Today lede reads {string}", async ({ page }, text: string) => {
  await expect(page.locator(".page-head-sub")).toHaveText(exact(text));
});

Then("the Today lede says {string}", async ({ page }, text: string) => {
  expect(norm(await page.locator(".page-head-sub").textContent())).toContain(text);
});

Then("the Today lede ends with {string}", async ({ page }, text: string) => {
  expect(norm(await page.locator(".page-head-sub").textContent())).toMatch(new RegExp(`${escaped(text)}$`));
});

Then("the sprint lists the open tasks {string}", async ({ page }, titles: string) => {
  expect(await texts(panel(page).locator(".sprint-rows .task-title"))).toEqual(list(titles));
});

Then("the sprint lists the open tasks {string} in some order", async ({ page }, titles: string) => {
  expect((await texts(panel(page).locator(".sprint-rows .task-title"))).sort()).toEqual(list(titles).sort());
});

Then("the sprint folds {string} away under {string}", async ({ page }, titles: string, summary: string) => {
  const folded = panel(page).locator("details.today-more:not([open])").filter({ hasText: "done today" });

  expect(norm(await folded.locator("summary").textContent())).toBe(summary);
  expect(await texts(folded.locator(".task-title"))).toEqual(list(titles));
});

Then("the sprint folds nothing away as done", async ({ page }) => {
  await expect(panel(page).locator("details.today-more").filter({ hasText: "done today" })).toHaveCount(0);
});

Then("the sprint progress bar is {string} full", async ({ page }, width: string) => {
  await expect(panel(page).locator(".sprint-progress-fill")).toHaveAttribute("style", `width: ${width}`);
});

Then(
  "the sprint progress bar is named {string} from {int} to {int} at {int}",
  async ({ page }, name: string, min: number, max: number, now: number) => {
    const bar = panel(page).locator("[role='progressbar']");

    await expect(bar).toHaveAttribute("aria-label", name);
    await expect(bar).toHaveAttribute("aria-valuemin", String(min));
    await expect(bar).toHaveAttribute("aria-valuemax", String(max));
    await expect(bar).toHaveAttribute("aria-valuenow", String(now));
  },
);

Then("the sprint has no progress bar", async ({ page }) => {
  await expect(panel(page).locator("[role='progressbar']")).toHaveCount(0);
});

Then("the sprint notes {string}", async ({ page }, text: string) => {
  await expect(panel(page).locator(".sprint-note")).toHaveText(exact(text));
});

Then("the sprint says {string}", async ({ page }, text: string) => {
  expect(await texts(panel(page).locator(".empty"))).toContain(text);
});

Then("the sprint says something with {string}", async ({ page }, text: string) => {
  expect((await texts(panel(page).locator(".empty"))).join(" ")).toContain(text);
});

Then("the sprint offers no capture row", async ({ page }) => {
  await expect(panel(page).locator("[name='task[title]']")).toHaveCount(0);
});

Then("the pools list {string}", async ({ page }, titles: string) => {
  expect(await texts(pulls(page).locator(".li-title"))).toEqual(list(titles));
});

Then("the pools show {int} tasks", async ({ page }, count: number) => {
  await expect(pulls(page).locator(".li-title")).toHaveCount(count);
});

Then("the pool tabs read {string}", async ({ page }, labels: string) => {
  expect(await texts(panel(page).locator(".seg-option"))).toEqual(list(labels));
});

Then("the pool tabs link to {string}", async ({ page }, hrefs: string) => {
  const found = await panel(page)
    .locator(".seg-option")
    .evaluateAll((all) => all.map((link) => link.getAttribute("href")));

  expect(found).toEqual(list(hrefs));
});

Then("the pools link {string} to {string}", async ({ page }, text: string, href: string) => {
  await expect(pulls(page).locator("a", { hasText: exact(text) })).toHaveAttribute("href", href);
});

Then("the pools are folded away under {string}", async ({ page }, summary: string) => {
  const pull = panel(page).locator("details.today-more").filter({ hasText: summary });

  await expect(pull).not.toHaveAttribute("open");
  await expect(pull.locator(".task-planner-pull")).toHaveCount(1);
});

Then("the pools are open", async ({ page }) => {
  await expect(panel(page).locator("details.today-more[open] .task-planner-pull")).toHaveCount(1);
});

Then("only the {string} pool is drawn", async ({ page }, name: string) => {
  const drawn = await panel(page)
    .locator("[data-pool-panel]")
    .evaluateAll((all) => all.map((pool) => pool.getAttribute("data-pool-panel")));

  expect(drawn).toEqual([name]);
});

Then("each pool row leads with its task number", async ({ app, page }) => {
  const keys = await texts(pulls(page).locator(".task-planner-list .task-meta .record-key"));
  const titles = await texts(pulls(page).locator(".task-planner-list .li-title"));
  const numbers = await app.sql`SELECT title, number FROM tasks WHERE title IN ${app.sql(titles)}`;

  expect(keys).toEqual(titles.map((title) => String(numbers.find((task) => task.title === title)?.number)));
});

Then("each open sprint task leads with its task number", async ({ app, page }) => {
  const keys = await texts(panel(page).locator(".record-key"));
  const numbers = await app.sql`SELECT number FROM tasks WHERE sprint_id IS NOT NULL AND status = 'open'`;

  expect(keys.sort()).toEqual(numbers.map(({ number }) => String(number)).sort());
});

Then("the sprint task {string} ends with a pen that edits it from Today", async ({ app, page }, title: string) => {
  const [{ id }] = await app.sql`SELECT id FROM tasks WHERE title = ${title}`;
  const pen = sprintTask(page, title).locator(".task-acts > :last-child");

  await expect(pen).toHaveAttribute("data-task-open-edit", "");
  await expect(pen).toHaveAttribute("aria-label", "Edit");
  await expect(pen).toHaveAttribute("href", `/admin/tasks/${id}/edit?filter=today&origin=today`);
});

Then("the sprint task {string} counts {string} comments", async ({ page }, title: string, count: string) => {
  const mark = sprintTask(page, title)
    .locator(".task-meta .task-mark")
    .filter({ has: page.locator(".fa-comment") });

  await expect(mark).toHaveText(exact(count));
});

Then("the sprint task {string} shows no comment count", async ({ page }, title: string) => {
  await expect(sprintTask(page, title).locator(".task-meta .fa-comment")).toHaveCount(0);
});

Then("the sprint panel comes first in the main column", async ({ page }) => {
  await expect(page.locator(".g-main > .today-main > [data-sprint-panel]:first-child")).toHaveCount(1);
});

Then("the sprint panel is titled {string}", async ({ page }, title: string) => {
  await expect(panel(page).locator("h2.card-title")).toHaveText(exact(title));
});

Then("the sprint panel links {string} to {string}", async ({ page }, text: string, href: string) => {
  await expect(panel(page).locator(".card-side a", { hasText: exact(text) })).toHaveAttribute("href", href);
});

Then("the Today page links {string} to {string}", async ({ page }, text: string, href: string) => {
  await expect(page.getByRole("link", { exact: true, name: text })).toHaveAttribute("href", href);
});

Then(
  "the Create Task button links to {string} and opens the dialog {string}",
  async ({ page }, href: string, dialog: string) => {
    const button = page.locator(".page-head-actions a", { hasText: "Create Task" });

    await expect(button).toHaveAttribute("href", href);
    await expect(button).toHaveAttribute("data-dialog-open", dialog);
  },
);

Then("the Create Task dialog posts to {string}", async ({ page }, action: string) => {
  await expect(page.locator(`dialog#task-create form[action="${action}"]`)).toHaveCount(1);
});

Then(
  "the {string} task form starts on the list {string} from {string}",
  async ({ page }, where: string, list: string, origin: string) => {
    const form = page.locator(where === "dialog" ? "dialog#task-create form" : "main form.task-form");

    await expect(form.locator("select[name='task[list]']")).toHaveValue(list);
    await expect(form.locator("input[type=hidden][name=origin]")).toHaveValue(origin);
  },
);

Then("the Today task form says {string}", async ({ page }, text: string) => {
  expect(await texts(page.locator(".field-error"))).toContain(text);
});

Then("the Today new task form's title holds {string}", async ({ page }, title: string) => {
  await expect(page.locator("[name='task[title]']").first()).toHaveValue(title);
});

Then("the Shipped today card reads {string}", async ({ page }, text: string) => {
  expect(norm(await shipped(page).locator(".today-para").textContent())).toBe(text);
});

Then("the Shipped today count reads {string}", async ({ page }, text: string) => {
  expect(norm(await shipped(page).locator(".today-stat").textContent())).toBe(text);
});

Then("the Shipped today count matches the commit rows", async ({ page }) => {
  const rows = await shipped(page).locator(".commit").count();

  expect(norm(await shipped(page).locator(".today-stat").textContent())).toMatch(new RegExp(`^${rows} commits`));
});

Then("the Shipped today card has no count", async ({ page }) => {
  await expect(shipped(page).locator(".today-stat")).toHaveCount(0);
});

Then("the Shipped today card lists the commits:", async ({ page }, messages: string) => {
  expect(await texts(shipped(page).locator(".commit-message"))).toEqual(lines(messages));
});

Then("the Shipped today card lists no commits", async ({ page }) => {
  await expect(shipped(page).locator(".commits")).toHaveCount(0);
});

Then("the Shipped today card says {string}", async ({ page }, text: string) => {
  await expect(shipped(page).locator(".empty")).toHaveText(exact(text));
});

Then("the Shipped today card has no link {string}", async ({ page }, text: string) => {
  await expect(shipped(page).locator("a", { hasText: exact(text) })).toHaveCount(0);
});

Then("the Shipped today card hints {string}", async ({ page }, text: string) => {
  await expect(shipped(page).locator(".hint")).toHaveText(exact(text));
});

Then("the Shipped today card gives no hint", async ({ page }) => {
  await expect(shipped(page).locator(".hint")).toHaveCount(0);
});

Then("the commit {string} reads {string}", async ({ page }, message: string, meta: string) => {
  expect(norm(await commit(page, message).locator(".commit-meta").textContent())).toBe(meta);
});

Then(
  "the commit {string} adds {string} and removes {string}",
  async ({ page }, message: string, added: string, removed: string) => {
    expect(norm(await commit(page, message).locator(".commit-added").textContent())).toBe(added);
    expect(norm(await commit(page, message).locator(".commit-removed").textContent())).toBe(removed);
  },
);

Then("the whole row of the commit {string} opens its page", async ({ app, page }, message: string) => {
  const [{ id }] = await app.sql`SELECT id FROM commits WHERE split_part(message, E'\n', 1) = ${message}`;
  const found = commit(page, message);

  expect(await found.evaluate((element) => element.tagName)).toBe("A");
  await expect(found).toHaveAttribute("href", `/admin/commits/${id}`);
});

Then("the commit list is folded away", async ({ page }) => {
  await expect(shipped(page).locator("details.today-more:not([open]) .commits")).toHaveCount(1);
});

Then("the commit list ends with the link {string} to today's commits in activity", async ({ page }, text: string) => {
  const day = new Intl.DateTimeFormat("en-CA", { timeZone: zone }).format(new Date());
  const link = shipped(page).locator(".commits + .commits-foot a");

  expect(norm(await link.textContent())).toBe(text);
  await expect(link).toHaveAttribute("href", `/admin/activity?from=${day}&to=${day}&types%5Bcommit%5D=1`);
});

Then("the commit list says {string}", async ({ page }, text: string) => {
  expect(norm(await shipped(page).locator(".today-more > summary .commits-synced").textContent())).toBe(text);
});

Then("the commit list's sync time is {string}", async ({ page }, datetime: string) => {
  await expect(shipped(page).locator(".today-more > summary .commits-synced time")).toHaveAttribute(
    "datetime",
    datetime,
  );
});

Then("the commit list says it synced today at the last sync's Chicago time", async ({ app, page }) => {
  const [{ at }] = await app.sql`SELECT max(updated_at) AS at FROM sync_states WHERE kind = 'commits'`;
  const synced = norm(await shipped(page).locator(".today-more > summary .commits-synced").textContent());

  expect(synced).toBe(`synced today at ${clock(at)}`);
});

Then("the Shipped today card has no standing sync line", async ({ page }) => {
  await expect(shipped(page).locator(".commits-sub")).toHaveCount(0);
});

Then("the Import now form posts to {string} with a CSRF token", async ({ page }, action: string) => {
  const form = shipped(page).locator(`form[data-commits-import][method='post'][action="${action}"]`);

  await expect(form).toHaveCount(1);
  await expect(form.locator("input[name='_csrf_token']")).toHaveCount(1);
});

Then("the Import now button sits in the card head", async ({ page }) => {
  await expect(shipped(page).locator(".card-head form[data-commits-import] button[title='Import now']")).toHaveCount(1);
});

Then("the Import now button reads {string} with a rotate icon that holds still", async ({ page }, label: string) => {
  const idle = shipped(page).locator("[data-commits-idle]");

  await expect(idle).toHaveText(exact(label));
  await expect(idle.locator("i.fa-rotate")).toHaveCount(1);
  await expect(idle.locator("i.commit-spinner")).toHaveCount(0);
});

Then("the Import now button hides {string} with a spinning icon", async ({ page }, label: string) => {
  const busy = shipped(page).locator("[data-commits-busy]");

  expect(norm(await busy.textContent())).toBe(label);
  await expect(busy).toBeHidden();
  await expect(busy.locator("i.commit-spinner")).toHaveCount(1);
});

Then("the Import now button is {word}", async ({ page }, state: string) => {
  const button = shipped(page).getByRole("button", { name: "Import now" });

  await (state === "enabled" ? expect(button).toBeEnabled() : expect(button).toBeDisabled());
});

Then("the calendar card shows {string}", async ({ page }, titles: string) => {
  expect(await texts(calendar(page).locator(".card-body > .today-event .cal-event-name"))).toEqual(list(titles));
});

Then("the calendar card folds {string} under {string}", async ({ page }, titles: string, summary: string) => {
  const earlier = calendar(page).locator("details.today-more");

  expect(norm(await earlier.locator(":scope > summary").textContent())).toBe(summary);
  expect(await texts(earlier.locator(".cal-event-name"))).toEqual(list(titles));
});

Then("the calendar row {string} is {string}", async ({ page }, title: string, state: string) => {
  await expect(event(page, title)).toHaveAttribute("data-state", state);
});

Then("the calendar row {string} is marked now", async ({ page }, title: string) => {
  await expect(event(page, title).locator("[data-today-now] .pill.blue", { hasText: "now" })).toBeVisible();
});

Then("the calendar row {string} is not marked now", async ({ page }, title: string) => {
  await expect(event(page, title).locator("[data-today-now] .pill")).toBeHidden();
});

Then("the calendar row {string} counts down {string}", async ({ page }, title: string, soon: string) => {
  await expect(event(page, title).locator("[data-today-soon]")).toHaveText(exact(soon));
});

Then("the calendar row {string} shows no countdown", async ({ page }, title: string) => {
  await expect(event(page, title).locator("[data-today-soon]")).toHaveText(/^\s*$/);
});

Then("the calendar row {string} starts {string}", async ({ page }, title: string, time: string) => {
  expect(norm(await event(page, title).locator(".cal-event-time").textContent())).toBe(time);
});

Then("the calendar row {string} reads {string}", async ({ page }, title: string, meta: string) => {
  const found = await event(page, title)
    .locator(".cal-event-meta")
    .evaluate((element) => element.textContent ?? "");

  expect(found.trim()).toBe(expand(meta));
});

Then("the calendar row {string} joins at {string}", async ({ page }, title: string, href: string) => {
  await expect(event(page, title).locator("a.today-event-join")).toHaveAttribute("href", href);
});

Then("the calendar row {string} opens to {string}", async ({ page }, title: string, parts: string) => {
  expect(await texts(event(page, title).locator(".cal-event-more p"))).toEqual(list(parts));
});

Then("the calendar row {string} offers the buttons:", async ({ page }, title: string, table: DataTable) => {
  const buttons = await event(page, title)
    .locator(".cal-event-more a.bt")
    .evaluateAll((all) => all.map((link) => [(link.textContent ?? "").trim(), link.getAttribute("href")]));

  expect(buttons).toEqual(table.raw());
});

Then(
  "the calendar row {string} preps a task titled {string} in the dialog {string}",
  async ({ page }, title: string, prep: string, dialog: string) => {
    const link = event(page, title).locator(".cal-event-more a", { hasText: "Prep task" });

    await expect(link).toHaveAttribute("data-dialog-open", dialog);
    await expect(link).toHaveAttribute("data-prep-title", prep);
  },
);

Then("the calendar card tally reads {string}", async ({ page }, text: string) => {
  await expect(calendar(page).locator("[data-today-calendar-left]")).toHaveText(exact(text));
});

Then("the calendar card says {string}", async ({ page }, text: string) => {
  await expect(calendar(page).locator(".empty")).toHaveText(exact(text));
});

Then("the calendar card notes {string}", async ({ page }, text: string) => {
  await expect(calendar(page).locator(".today-para")).toHaveText(exact(text));
});

Then("the calendar card links {string} to {string}", async ({ page }, text: string, href: string) => {
  await expect(calendar(page).locator("a.today-link", { hasText: text })).toHaveAttribute("href", href);
});

Then("the dead job is back on the {string} queue", async ({ app }, queue: string) => {
  await expect
    .poll(() => app.redis.client.lRange(`queue:${queue}`, 0, -1))
    .toEqual([expect.stringContaining(deadJob.jid)]);
});

Then("the dead job set is empty", async ({ app }) => {
  expect(await app.redis.client.zCard("dead")).toBe(0);
});

Then("the job queue {string} is empty", async ({ app }, queue: string) => {
  expect(await app.redis.client.lLen(`queue:${queue}`)).toBe(0);
});

const untrusted = (value: unknown): unknown => {
  if (Array.isArray(value)) return value.map(untrusted);
  if (value && typeof value === "object") {
    const record = value as Record<string, unknown>;
    if (record.untrusted === true && "text" in record) return record.text;
    return Object.fromEntries(Object.entries(record).map(([key, inner]) => [key, untrusted(inner)]));
  }
  return value;
};

const callTool = async (
  request: import("@playwright/test").APIRequestContext,
  token: string | undefined,
  name: string,
  args: unknown,
) => {
  const response = await request.post("/mcp", {
    data: { id: 1, jsonrpc: "2.0", method: "tools/call", params: { arguments: args, name } },
    headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${token}` },
  });
  return JSON.parse((await response.json()).result.content[0].text);
};

const callEndpoint = async (
  request: import("@playwright/test").APIRequestContext,
  token: string | undefined,
  call: string,
  args: unknown,
) => {
  const [method, path] = call.split(" ");
  const response = await request.fetch(path, {
    data: method === "GET" ? undefined : args,
    headers: { Accept: "application/json", Authorization: `Bearer ${token}` },
    method,
  });
  return response.json();
};

Then("the MCP tool {string} answers what {string} answers", async ({ request, tokens }, tool: string, call: string) => {
  const fromTool = untrusted(await callTool(request, tokens.mcp, tool, {}));

  expect(fromTool).toEqual(await callEndpoint(request, tokens.api, call, {}));
});

Then(
  "the MCP tool {string} answers what {string} answers, but the end, for:",
  async ({ request, tokens }, tool: string, call: string, args: string) => {
    const { ends_at: _tool, ...fromTool } = (await callTool(request, tokens.mcp, tool, JSON.parse(args))) as Record<
      string,
      unknown
    >;
    const { ends_at: _call, ...fromCall } = await callEndpoint(request, tokens.api, call, JSON.parse(args));

    expect(fromTool).toEqual(fromCall);
  },
);

Given("these sync failures:", async ({ app }, table: DataTable) => {
  for (const failure of table.hashes()) {
    const at = failure.at || "2026-01-07T15:30:00Z";
    await app.sql`
      INSERT INTO sync_states ${app.sql({
        failing_since: failure.since || at,
        failure_count: Number(failure.count || 1),
        failure_message: failure.message || null,
        failure_reason: failure.reason,
        kind: "failure",
        repo: failure.repo || null,
        sync: failure.sync,
        synced_at: at,
      })}
    `;
  }
});

Given("a Linear key for the Today page", async ({ app }) => {
  const credentials = seal(JSON.stringify({ api_key: "lin_api_one" }));
  await app.sql`
    INSERT INTO service_connections (provider, account_id, label, credentials)
    VALUES ('linear', 'lin_api_one', 'lin_api_one', ${credentials})
  `;
});

When("the Today sync job {string} runs", async ({ app }, job: string) => {
  await runSync(app, job, []);
});

When("the Today sync job {string} runs for {string}", async ({ app }, job: string, arg: string) => {
  await runSync(app, job, [arg]);
});

When("I switch the Today pool to {string} further down the page", async ({ page }, label: string) => {
  await page.setViewportSize({ height: 400, width: 1024 });
  await page.evaluate(() => {
    document.querySelector("[data-pools] .seg")?.scrollIntoView({ block: "center" });
    Object.assign(window, { poolsLoaded: true, poolsScroll: window.scrollY });
  });
  await panel(page)
    .locator(".seg-option", { hasText: exact(label) })
    .click();
  const pool = label.split(" · ")[0];
  await expect(page).toHaveURL((url) => url.searchParams.get("pool") === pool);
  await page.waitForLoadState("networkidle");
});

Then("the Today page switched the pool without loading again or scrolling", async ({ page }) => {
  expect(await page.evaluate(() => Reflect.get(window, "poolsLoaded"))).toBe(true);
  expect(await page.evaluate(() => window.scrollY > 0 && window.scrollY === Reflect.get(window, "poolsScroll"))).toBe(
    true,
  );
});

Then("the pool tab {string} is the current page", async ({ page }, label: string) => {
  await expect(panel(page).locator(".seg-option[aria-current='page']")).toHaveText(exact(label));
  await expect(panel(page).locator(".seg-option[aria-current]")).toHaveCount(1);
});

When("I copy the key of the first task in the {string} pool", async ({ page }, pool: string) => {
  await page.evaluate(() => {
    Object.assign(window, { copiedKeys: [] });
    Object.defineProperty(navigator, "clipboard", {
      configurable: true,
      value: { writeText: async (text: string) => Reflect.get(window, "copiedKeys").push(text) },
    });
  });
  await page.locator(`[data-pool-panel='${pool}'] .record-key`).first().click();
});

Then("the Today page toasts {string} and copied {string}", async ({ page }, toast: string, key: string) => {
  await expect(page.locator(".toast", { hasText: toast })).toHaveCount(1);
  expect(await page.evaluate(() => Reflect.get(window, "copiedKeys"))).toEqual([key]);
});

Given("the Today page's country database is gone", ({ $testInfo }) => {
  const folder = `tmp/features-ws${process.env.WORKSPACE_ID ?? 0}-w${$testInfo.parallelIndex + 1}-maxmind`;
  rmSync(resolve(import.meta.dirname, "../..", folder, "GeoLite2-City.mmdb"), { force: true });
});

When("the country database refresh runs for the Today page", async ({ app }) => {
  await app.pushJob("Analytics::Jobs::RefreshCountryDatabase");
  await expect
    .poll(async () => (await app.sql`SELECT 1 FROM sync_states WHERE sync = 'country_database'`).length, {
      timeout: 30_000,
    })
    .toBeGreaterThan(0);
});

Then("the last sync failure reads {string}", async ({ page }, line: string) => {
  await expect(page.locator(".sync-failures .sync-failure").last()).toHaveText(line);
});

Given("the Chicago day has at least {int} hours left", ({ $test }, hours: number) => {
  const [hour, minute] = new Intl.DateTimeFormat("en-GB", {
    hour: "2-digit",
    minute: "2-digit",
    timeZone: "America/Chicago",
  })
    .format(new Date())
    .split(":")
    .map(Number);
  $test.skip(24 * 60 - (hour * 60 + minute) < hours * 60, "the events would land on tomorrow");
});
