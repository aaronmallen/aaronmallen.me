import { expect, type Page } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import type postgres from "postgres";
import { dayOf, iso } from "../support/calendar.ts";
import { insertComment, insertSource, insertTimedTask, instant, marked, plain } from "../support/task_api.ts";
import { insertTask, taskId } from "../support/tasks.ts";
import { Given, Then, When } from "../support/world.ts";

Given("the tasks with their times:", async ({ app }, table: DataTable) => {
  for (const row of table.hashes()) await insertTimedTask(app.sql, row);
});

Given("{int} more open tasks", async ({ app }, count: number) => {
  for (let made = 0; made < count; made++) await insertTask(app.sql, { title: `Filler ${made + 1}` });
});

for (const [wording, type, flip] of [
  ["blocks", "blocks", false],
  ["is blocked by", "blocks", true],
  ["relates to", "relates", false],
  ["duplicates", "duplicates", false],
  ["is the parent of", "parent", false],
] as const) {
  Given(`the task {string} ${wording} the task {string}`, async ({ app }, one: string, two: string) => {
    const [from, to] = flip ? [two, one] : [one, two];
    await app.sql`
      INSERT INTO task_links ${app.sql({ from_task_id: await taskId(app.sql, from), to_task_id: await taskId(app.sql, to), type })}
    `;
  });
}

Given("the task sources:", async ({ app }, table: DataTable) => {
  for (const row of table.hashes()) await insertSource(app.sql, row);
});

Given("the task comments:", async ({ app }, table: DataTable) => {
  for (const row of table.hashes()) await insertComment(app.sql, row);
});

Given("the task contributors:", async ({ app }, table: DataTable) => {
  for (const { agent, model, task } of table.hashes()) {
    const kind = agent ? "agent" : "owner";
    const row = { agent: agent || null, kind, model: model || null, task_id: await taskId(app.sql, task) };
    await app.sql`INSERT INTO task_contributors ${app.sql(row)}`;
  }
});

Given("the task events:", async ({ app }, table: DataTable) => {
  for (const {
    at,
    from_list,
    from_status,
    from_sprint,
    kind,
    tag,
    task,
    to_list,
    to_sprint,
    to_status,
  } of table.hashes()) {
    await app.sql`
      INSERT INTO task_events ${app.sql({
        from_list: from_list || null,
        from_sprint_on: from_sprint ? dayOf(from_sprint) : null,
        from_status: from_status || null,
        kind,
        occurred_at: instant(at),
        tag_name: tag || null,
        task_id: await taskId(app.sql, task),
        to_list: to_list || null,
        to_sprint_on: to_sprint ? dayOf(to_sprint) : null,
        to_status: to_status || null,
      })}
    `;
  }
});

Given("the task work sessions:", async ({ app }, table: DataTable) => {
  for (const { from, task, until } of table.hashes()) {
    const started = from === "10 minutes ago" ? new Date(Date.now() - 600_000) : instant(from);
    const row = { ended_at: until ? instant(until) : null, started_at: started, task_id: await taskId(app.sql, task) };
    await app.sql`INSERT INTO work_sessions ${app.sql(row)}`;
  }
});

Then("the API lists these tasks:", async ({ app, request, tokens }, table: DataTable) => {
  for (const { query, titles } of table.hashes()) {
    const response = await request.get(`/api/v1/tasks${query ? `?${await marked(app.sql, query)}` : ""}`, {
      headers: { Authorization: `Bearer ${tokens.api}` },
    });
    const body = await response.text();
    expect(response.status(), `${query}: ${body}`).toBe(200);
    const found = JSON.parse(body).tasks.map((task: { title: string }) => task.title);
    expect(found.join(", "), query).toBe(titles);
  }
});

Then("the API calls answer:", async ({ answer, app, request, tokens }, table: DataTable) => {
  for (const { body, call, holds, status } of table.hashes()) {
    const [method, ...rest] = call.split(" ");
    const path = rest.join(" ");
    const response = await request.fetch(`/api/v1${await marked(app.sql, path)}`, {
      data: body ? JSON.parse(await marked(app.sql, body)) : undefined,
      headers: { Authorization: `Bearer ${tokens.api}` },
      method,
    });
    const text = await response.text();
    answer.status = response.status();
    answer.body = text;
    expect(response.status(), `${call} ${body}: ${text}`).toBe(Number(status));
    if (!holds) continue;
    const expected = await marked(app.sql, holds);
    if (expected.startsWith("{")) expect(JSON.parse(text), call).toMatchObject(JSON.parse(expected));
    else expect(text, call).toContain(expected);
  }
});

Then("the API answer has {string} as {string}", ({ answer }, path: string, value: string) => {
  const found = path.split(".").reduce((part, key) => part?.[key], JSON.parse(answer.body));
  expect(String(JSON.stringify(found))).toBe(value);
});

Then(
  "the MCP tool {string} answers as the API did, apart from {string}, with:",
  async ({ answer, app, request, tokens }, tool: string, keys: string, args: string) => {
    const api = plain(JSON.parse(answer.body), keys.split(", ").filter(Boolean));
    const response = await request.post("/mcp", {
      data: {
        id: 1,
        jsonrpc: "2.0",
        method: "tools/call",
        params: { arguments: JSON.parse(await marked(app.sql, args)), name: tool },
      },
      headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${tokens.mcp}` },
    });
    const result = (await response.json()).result;
    const text = result.content[0].text;
    expect(result.isError ? text : plain(JSON.parse(text), keys.split(", ").filter(Boolean))).toEqual(
      result.isError ? api.message : api,
    );
  },
);

Then("the database holds {int} {word} row(s)", async ({ app }, count: number, table: string) => {
  await expect.poll(async () => (await app.sql`SELECT 1 FROM ${app.sql(table)}`).length).toBe(count);
});

Then("the running session counts between {int} and {int} seconds", ({ answer }, low: number, high: number) => {
  const { seconds } = JSON.parse(answer.body).timeline.find((entry: { running?: boolean }) => entry.running);
  expect(seconds).toBeGreaterThanOrEqual(low);
  expect(seconds).toBeLessThanOrEqual(high);
});

When(
  "I POST {string} through the API with a body of {string}",
  async ({ answer, request, tokens }, path: string, body: string) => {
    const response = await request.post(`/api/v1${path}`, {
      data: body,
      headers: { Authorization: `Bearer ${tokens.api}`, "Content-Type": "application/json" },
    });
    answer.status = response.status();
    answer.body = await response.text();
  },
);

Then("the next list reads {string}", async ({ app }, titles: string) => {
  const rows =
    await app.sql`SELECT title FROM tasks WHERE list = 'next' AND status IN ('open', 'in_progress') ORDER BY position, id`;
  expect(rows.map(({ title }) => title).join(", ")).toBe(titles);
});

Then("the database reads {string} for:", async ({ app }, answer: string, query: string) => {
  const rows = await app.sql.unsafe(await marked(app.sql, query));
  expect(rows.map((row) => Object.values(row).join(", ")).join(" / ")).toBe(await marked(app.sql, answer));
});

Then(
  "a bulk complete of {int} IDs gets a 422 naming {string}",
  async ({ request, tokens }, count: number, field: string) => {
    const ids = Array.from({ length: count }, (_, index) => index + 1);
    const response = await request.post("/api/v1/tasks/bulk/complete", {
      data: { ids },
      headers: { Authorization: `Bearer ${tokens.api}` },
    });
    expect(response.status()).toBe(422);
    expect(Object.keys((await response.json()).errors)).toEqual([field]);
  },
);

Then("the MCP call is refused", ({ answer }) => {
  expect(answer.error, answer.content).toBe(true);
});

Then("the first task in order is {string}", async ({ app }, title: string) => {
  const [first] = await app.sql`SELECT title FROM tasks ORDER BY position, id LIMIT 1`;
  expect(first.title).toBe(title);
});

Then("the API answer has the comment's stamps as the database does", async ({ answer, app }) => {
  const { created_at, id, updated_at } = JSON.parse(answer.body);
  const [row] = await app.sql`SELECT created_at, updated_at FROM task_comments WHERE id = ${id}`;
  expect({ created_at, updated_at }).toEqual({ created_at: iso(row.created_at), updated_at: iso(row.updated_at) });
});

const kept = new WeakMap<object, { body: string; status: number }>();

When("I keep the API answer", ({ answer }) => {
  kept.set(answer, { body: answer.body, status: answer.status });
});

When("I take back the kept API answer", ({ answer }) => {
  Object.assign(answer, kept.get(answer));
});

Then("the blocking mark on {string} lists {string} on hover", async ({ page }, title: string, titles: string) => {
  const mark = page.locator(`.task:has(.task-title:text-is("${title}")) .task-meta .task-mark.sand`).first();
  const listed = ((await mark.getAttribute("title")) ?? "").split("\n").sort();
  expect(listed.join(", ")).toBe(titles);
});

Then("the link finder on {string} finds:", async ({ app, page }, title: string, table: DataTable) => {
  const id = await taskId(app.sql, title);
  for (const { query, targets } of table.hashes()) {
    await page.goto(`/admin/tasks/${id}?filter=next&link_q=${encodeURIComponent(query)}`);
    const keys = await page.locator(".task-link-target .record-key").allTextContents();
    expect(keys.map((key) => key.trim()).join(", "), query).toBe(targets);
  }
});

Given("the task {string} repeats every {int} days", async ({ app }, title: string, every: number) => {
  const task = await taskId(app.sql, title);
  const [{ id }] =
    await app.sql`INSERT INTO task_series ${app.sql({ cadence: "days", every, task_id: task })} RETURNING id`;
  await app.sql`UPDATE tasks SET series_id = ${id} WHERE id = ${task}`;
});

Given("the task {string} moved on to a newer copy", async ({ app }, title: string) => {
  const old = await taskId(app.sql, title);
  const copy = await insertTask(app.sql, { title });
  const [{ id }] = await app.sql`UPDATE task_series SET task_id = ${copy} WHERE task_id = ${old} RETURNING id`;
  await app.sql`UPDATE tasks SET series_id = ${id} WHERE id IN ${app.sql([old, copy])}`;
});

Then("the page part {string} holds the long day {string}", async ({ page }, selector: string, day: string) => {
  const long = new Intl.DateTimeFormat("en-US", { day: "numeric", month: "long", timeZone: "UTC", year: "numeric" });
  await expect(page.locator(selector).first()).toContainText(long.format(new Date(`${dayOf(day)}T12:00:00Z`)));
});

Then("the recurring tab follows the external tab, counting {string}", async ({ page }, count: string) => {
  const tabs = (await page.locator(".task-tabs .screen-tab").allTextContents()).map((tab) =>
    tab.replaceAll(/\s+/g, ""),
  );
  const external = tabs.findIndex((tab) => tab.startsWith("external"));
  expect(tabs[external + 1]).toBe(`recurring${count}`);
});

Then("the tags on each task read {string}", async ({ app }, wanted: string) => {
  const rows = await app.sql`
    SELECT title, string_agg(name, ' ' ORDER BY name) AS tags
    FROM tasks LEFT JOIN task_tags ON task_id = tasks.id LEFT JOIN tags ON tags.id = tag_id
    GROUP BY tasks.id, title ORDER BY tasks.id
  `;
  expect(rows.map(({ tags, title }) => `${title}:${tags ? ` ${tags}` : ""}`).join(" / ")).toBe(wanted);
});

async function postForm(page: Page, path: string, pairs: string[][]) {
  await page.goto("/admin/settings/tagging");
  const token = await page.locator("input[name='_csrf_token']").first().inputValue();
  const form = new URLSearchParams({ _csrf_token: token });
  for (const [key, value] of pairs) form.append(key, value.replace(/^"(.*)"$/, "$1"));
  return page.request.post(path, {
    data: form.toString(),
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    maxRedirects: 0,
  });
}

Then("the admin rule form refuses:", async ({ page }, table: DataTable) => {
  for (const { error, field, pattern, projects, provider, tags } of table.hashes()) {
    const pairs = [
      ["rule[pattern]", pattern],
      ["rule[provider]", provider],
      ["rule[tags]", tags],
      ...projects
        .split(", ")
        .filter(Boolean)
        .map((id) => ["rule[projects][]", id]),
    ];
    const response = await postForm(page, "/admin/tasks/rules", pairs);
    expect(response.status(), pattern).toBe(422);
    await page.setContent(await response.text());
    const shown = page.locator(`#rule-${field}-error`);
    if (error) await expect(shown).toContainText(error);
    else await expect(shown).toHaveCount(1);
  }
});

Given(
  "the task {string} repeats every {int} weeks from {string}",
  async ({ app }, title: string, every: number, from: string) => {
    const startsOn = dayOf(from);
    const weekday = new Date(`${startsOn}T12:00:00Z`).getUTCDay();
    const task = await taskId(app.sql, title);
    const row = { cadence: "weeks", every, starts_on: startsOn, task_id: task, weekday };
    const [{ id }] = await app.sql`INSERT INTO task_series ${app.sql(row)} RETURNING id`;
    await app.sql`UPDATE tasks SET series_id = ${id} WHERE id = ${task}`;
  },
);

When("I save the task {string} in the admin with:", async ({ answer, app, page }, title: string, table: DataTable) => {
  const id = await taskId(app.sql, title);
  await page.goto("/admin/settings/tagging");
  const token = await page.locator("input[name='_csrf_token']").first().inputValue();
  const fields = new Map([
    ["filter", "next"],
    ["task[title]", title],
    ["task[list]", "next"],
    ["task[note]", ""],
    ["task[tags]", ""],
  ]);
  for (const [key, value] of table.raw()) fields.set(key, value);
  const form = new URLSearchParams({ _csrf_token: token });
  for (const [key, value] of fields) form.append(key, await marked(app.sql, value));
  const response = await page.request.post(`/admin/tasks/${id}`, {
    data: form.toString(),
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    maxRedirects: 0,
  });
  answer.status = response.status();
  answer.body = await response.text();
  answer.headers = response.headers();
});

Given("the task {string} repeats on the cadence:", async ({ app }, title: string, table: DataTable) => {
  const task = await taskId(app.sql, title);
  const [given] = table.hashes();
  const row = Object.fromEntries(Object.entries(given).filter(([, value]) => value !== ""));
  const [{ id }] = await app.sql`INSERT INTO task_series ${app.sql({ ...row, task_id: task })} RETURNING id`;
  await app.sql`UPDATE tasks SET series_id = ${id} WHERE id = ${task}`;
});

Then("the next copy of {string} sits in the sprint on {string}", async ({ app }, title: string, day: string) => {
  const rows = await app.sql`
    SELECT sprint_date::text AS day FROM tasks JOIN sprints ON sprints.id = sprint_id
    WHERE title = ${title} AND status = 'open'
  `;
  expect(rows.map(({ day }) => day)).toEqual([dayOf(day)]);
});

Then("the events of {string} read {string}", async ({ app }, title: string, wanted: string) => {
  const rows = await app.sql`
    SELECT kind, from_list, from_sprint_on::text AS from_day, to_list, to_sprint_on::text AS to_day, tag_name,
      from_status, to_status
    FROM task_events WHERE task_id = ${await taskId(app.sql, title)} ORDER BY occurred_at, id
  `;
  const said = rows.map((row) => {
    if (row.kind === "moved") return `moved ${row.from_list ?? row.from_day} to ${row.to_list ?? row.to_day}`;
    if (row.kind === "status_changed") return `${row.from_status} to ${row.to_status}`;
    return row.tag_name ? `${row.kind} ${row.tag_name}` : row.kind;
  });
  expect(said.join(" / ")).toBe(await marked(app.sql, wanted));
});

Then("today's sprint reads {string}", async ({ app }, titles: string) => {
  const rows = await app.sql`
    SELECT title FROM tasks JOIN sprints ON sprints.id = sprint_id WHERE sprint_date = ${dayOf("today")}
    ORDER BY position, tasks.id
  `;
  expect(rows.map(({ title }) => title).join(", ")).toBe(titles);
});

Then("the database refuses a value its type does not hold:", async ({ app }, statement: string) => {
  await expect(app.sql.unsafe(statement)).rejects.toMatchObject({ code: "22P02" });
});

const waiting = async (sql: postgres.Sql) => {
  const [{ count }] = await sql`
    SELECT count(*)::int AS count FROM pg_locks
    WHERE NOT granted AND database = (SELECT oid FROM pg_database WHERE datname = current_database())
  `;
  return count;
};

When(
  "two tasks are captured through the API while another session holds the task lock",
  async ({ app, request, tokens }) => {
    const holder = await app.sql.reserve();
    await holder`SELECT pg_advisory_lock(hashtext('tasks'))`;
    const headers = { Authorization: `Bearer ${tokens.api}` };
    const sent = ["one", "two"].map((title) => request.post("/api/v1/tasks", { data: { title }, headers }));
    await expect.poll(() => waiting(app.sql)).toBe(2);
    await holder`SELECT pg_advisory_unlock(hashtext('tasks'))`;
    holder.release();
    for (const response of await Promise.all(sent)) expect(response.status()).toBe(201);
  },
);

When(
  "the task {string} is started twice at once while another session holds its row",
  async ({ app, request, tokens }, title: string) => {
    const id = await taskId(app.sql, title);
    const holder = await app.sql.reserve();
    await holder`BEGIN`;
    await holder`SELECT id FROM tasks WHERE id = ${id} FOR UPDATE`;
    const headers = { Authorization: `Bearer ${tokens.api}` };
    const sent = [1, 2].map(() => request.post(`/api/v1/tasks/${id}/start`, { data: {}, headers }));
    await expect.poll(() => waiting(app.sql)).toBeGreaterThan(0);
    await new Promise((done) => setTimeout(done, 1000));
    await holder`COMMIT`;
    holder.release();
    for (const response of await Promise.all(sent)) expect(response.status()).toBe(200);
  },
);
