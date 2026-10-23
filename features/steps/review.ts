import { randomBytes } from "node:crypto";
import { type APIRequestContext, expect, type Page } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import type postgres from "postgres";
import { Before, Given, Then, When } from "../support/world.ts";

type Answer = { body: Record<string, unknown>; status: number };

let reviewAnswer: Answer = { body: {}, status: 0 };
let notePosted = 0;

Before(() => {
  reviewAnswer = { body: {}, status: 0 };
  notePosted = 0;
});

const zone = "America/Chicago";

const stamp = (value: string) => (value.length === 10 ? `${value} 12:00` : value);

const chicagoToday = () => {
  const [year, month, day] = new Intl.DateTimeFormat("en-CA", { timeZone: zone }).format(new Date()).split("-");
  return new Date(Date.UTC(Number(year), Number(month) - 1, Number(day)));
};

const shift = (date: Date, days: number) => new Date(date.getTime() + days * 86_400_000);

const iso = (date: Date) => date.toISOString().slice(0, 10);

const thisMonday = () => {
  const today = chicagoToday();
  return shift(today, -((today.getUTCDay() + 6) % 7));
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

const unstamped = (value: unknown, keys = ["updated_at"]): unknown => {
  if (Array.isArray(value)) return value.map((inner) => unstamped(inner, keys));
  if (value && typeof value === "object") {
    const entries = Object.entries(value).filter(([key]) => !keys.includes(key));
    return Object.fromEntries(entries.map(([key, inner]) => [key, unstamped(inner, keys)]));
  }
  return value;
};

const dig = (body: unknown, path: string) =>
  path === "."
    ? body
    : path.split(".").reduce<unknown>((value, key) => (value as Record<string, unknown> | undefined)?.[key], body);

const callApi = async (request: APIRequestContext, token: string | undefined, call: string, data?: string) => {
  const [method, path] = call.split(" ");
  const response = await request.fetch(path, {
    data: data === undefined ? undefined : JSON.parse(data),
    headers: { Authorization: `Bearer ${token}` },
    method,
  });
  return { body: trusted(await response.json()) as Record<string, unknown>, status: response.status() };
};

const callMcp = async (request: APIRequestContext, token: string | undefined, name: string, data: string) => {
  const response = await request.post("/mcp", {
    data: { id: 1, jsonrpc: "2.0", method: "tools/call", params: { arguments: JSON.parse(data), name } },
    headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${token}` },
  });
  const { result } = await response.json();
  const text: string = result.content[0].text;
  return { isError: Boolean(result.isError), text };
};

const parsed = (text: string) => trusted(JSON.parse(text));

const tagIds = async (sql: postgres.Sql, names: string) => {
  const ids: number[] = [];
  for (const name of names.split(/,\s*/).filter(Boolean)) {
    let [tag] = await sql`SELECT id FROM tags WHERE name = ${name} AND scope = 'private'`;
    tag ??= (await sql`INSERT INTO tags (name, color, scope) VALUES (${name}, 'mk-blue', 'private') RETURNING id`)[0];
    ids.push(tag.id);
  }
  return ids;
};

const projectId = async (sql: postgres.Sql, name: string) => {
  const [found] = await sql`SELECT id FROM projects WHERE name = ${name}`;
  if (found) return found.id;
  const key = name
    .replaceAll(/[^A-Za-z0-9]/g, "")
    .toUpperCase()
    .slice(0, 6);
  const [made] = await sql`
    INSERT INTO projects (name, key, visibility) VALUES (${name}, ${key}, 'private') RETURNING id
  `;
  return made.id;
};

const insertTask = async (sql: postgres.Sql, title: string, status = "open", closed = "", worked = 0) => {
  const [task] = await sql`
    INSERT INTO tasks (title, list, position, status, completed_at, worked_seconds)
    VALUES (
      ${title}, 'next', (SELECT coalesce(max(position), 0) + 1 FROM tasks), ${status},
      ${closed ? stamp(closed) : null}::text::timestamp AT TIME ZONE 'America/Chicago', ${worked}
    )
    RETURNING id
  `;
  return task.id as number;
};

const taskId = async (sql: postgres.Sql, title: string) => {
  const [found] = await sql`SELECT id FROM tasks WHERE title = ${title} ORDER BY id DESC LIMIT 1`;
  return (found?.id as number | undefined) ?? insertTask(sql, title);
};

const carry = async (sql: postgres.Sql, id: number, from: string, to: string, on: string) => {
  await sql`
    INSERT INTO task_events (task_id, kind, occurred_at, from_sprint_on, to_sprint_on)
    VALUES (
      ${id}, 'moved', ${stamp(on)}::text::timestamp AT TIME ZONE 'America/Chicago', ${from}::text::date,
      ${to}::text::date
    )
  `;
};

const carryOut = async (sql: postgres.Sql, id: number, days: string) => {
  for (const day of days.split(/,\s*/)) {
    const next = iso(shift(new Date(`${day}T00:00:00Z`), 1));
    await carry(sql, id, day, next, next);
  }
};

const decide = async (sql: postgres.Sql, title: string, kind: string, on: string, chosen?: string) => {
  let [decision] = await sql`SELECT id FROM decisions WHERE title = ${title}`;
  decision ??= (await sql`INSERT INTO decisions (title, problem) VALUES (${title}, 'It came up') RETURNING id`)[0];
  const [option] = chosen
    ? await sql`INSERT INTO decision_options (decision_id, title) VALUES (${decision.id}, ${chosen}) RETURNING id`
    : [];
  const reason = ["resolved", "dropped", "reopened"].includes(kind) ? "Settled" : null;
  await sql`
    INSERT INTO decision_events (decision_id, kind, option_id, reason, created_at)
    VALUES (
      ${decision.id}, ${kind}, ${option?.id ?? null}, ${reason},
      ${stamp(on)}::text::timestamp AT TIME ZONE 'America/Chicago'
    )
  `;
};

const postNote = async (page: Page, fields: Record<string, string>) => {
  const token = page.locator("input[name='_csrf_token']").first();
  if (!(await token.count())) await page.goto("/admin/review");
  const all = { _csrf_token: await token.inputValue(), ...fields };
  const response = page.waitForResponse(
    (sent) => sent.request().method() === "POST" && new URL(sent.url()).pathname === "/admin/review/note",
  );
  const navigated = page.waitForNavigation();
  await page.evaluate((all) => {
    const form = document.createElement("form");
    form.method = "post";
    form.action = "/admin/review/note";
    for (const [name, value] of Object.entries(all)) {
      const input = document.createElement("input");
      input.type = "hidden";
      input.name = name;
      input.value = value;
      form.append(input);
    }
    document.body.append(form);
    form.submit();
  }, all);
  notePosted = (await response).status();
  await navigated;
};

Given("the review has the tasks:", async ({ app }, table: DataTable) => {
  for (const row of table.hashes()) {
    const status = row.status || "done";
    const id = await insertTask(app.sql, row.title, status, row.closed ?? "", Number(row.worked || 0));
    for (const tag of await tagIds(app.sql, row.tags ?? "")) {
      await app.sql`INSERT INTO task_tags (task_id, tag_id) VALUES (${id}, ${tag})`;
    }
    if (row.project) {
      await app.sql`UPDATE tasks SET project_id = ${await projectId(app.sql, row.project)} WHERE id = ${id}`;
    }
    for (const by of (row.by ?? "").split(/,\s*/).filter(Boolean)) {
      const [agent, model] = by === "owner" ? [null, null] : by.split("/");
      await app.sql`
        INSERT INTO task_contributors (task_id, kind, agent, model)
        VALUES (${id}, ${by === "owner" ? "owner" : "agent"}, ${agent}, ${model})
      `;
    }
  }
});

Given("the review has a day's work on {string} done as {string}", async ({ app }, day: string, title: string) => {
  const done = await insertTask(app.sql, title, "done", day, 5400);
  const carried = await insertTask(app.sql, "Call the accountant");
  const date = new Date(`${day}T00:00:00Z`);
  await carryOut(app.sql, carried, [-2, -1, 0].map((days) => iso(shift(date, days))).join(", "));
  await app.sql`
    INSERT INTO work_sessions (task_id, started_at, ended_at)
    VALUES (
      ${done},
      ${`${day} 09:00`}::text::timestamp AT TIME ZONE 'America/Chicago',
      ${`${day} 10:00`}::text::timestamp AT TIME ZONE 'America/Chicago'
    )
  `;
});

Given(
  "the review task {string} ran from {string} to {string}",
  async ({ app }, title: string, from: string, to: string) => {
    await app.sql`
      INSERT INTO work_sessions (task_id, started_at, ended_at)
      VALUES (
        ${await taskId(app.sql, title)},
        ${from}::text::timestamp AT TIME ZONE 'America/Chicago',
        ${to}::text::timestamp AT TIME ZONE 'America/Chicago'
      )
    `;
  },
);

Given("the review task {string} has run since {string}", async ({ app }, title: string, from: string) => {
  await app.sql`
    INSERT INTO work_sessions (task_id, started_at)
    VALUES (${await taskId(app.sql, title)}, ${from}::text::timestamp AT TIME ZONE 'America/Chicago')
  `;
});

Given(
  "the review task {string} has run for the last {int} minutes",
  async ({ app }, title: string, minutes: number) => {
    await app.sql`
      INSERT INTO work_sessions (task_id, started_at)
      VALUES (${await taskId(app.sql, title)}, now() - make_interval(mins => ${minutes}))
    `;
  },
);

Given(
  "the review task {string} was carried out of the sprints {string}",
  async ({ app }, title: string, days: string) => {
    await carryOut(app.sql, await taskId(app.sql, title), days);
  },
);

Given(
  "the review task {string} moved from the sprint {string} to the sprint {string} on {string}",
  async ({ app }, title: string, from: string, to: string, on: string) => {
    await carry(app.sql, await taskId(app.sql, title), from, to, on);
  },
);

Given(
  "the review task {string} moved from the sprint {string} to the list {string}",
  async ({ app }, title: string, from: string, list: string) => {
    await app.sql`
        INSERT INTO task_events (task_id, kind, occurred_at, from_sprint_on, to_list)
        VALUES (${await taskId(app.sql, title)}, 'moved', now(), ${from}::text::date, ${list})
      `;
  },
);

Given(
  "the review decision {string} was resolved on {string} choosing {string}",
  async ({ app }, title: string, on: string, chosen: string) => {
    await decide(app.sql, title, "resolved", on, chosen);
  },
);

Given(
  "the review decision {string} was {word} on {string}",
  async ({ app }, title: string, kind: string, on: string) => {
    await decide(app.sql, title, kind, on);
  },
);

Given(
  "the review has a {word} post {string} dated {string}",
  async ({ app }, status: string, title: string, on: string) => {
    await app.sql`
      INSERT INTO posts (title, slug, status, published_at, body, body_html, read_time, word_count, webmentions_enabled)
      VALUES (
        ${title}, ${`${title.toLowerCase().replaceAll(/\W+/g, "-")}-${randomBytes(3).toString("hex")}`}, ${status},
        ${stamp(on)}::text::timestamp AT TIME ZONE 'America/Chicago', 'A post.', '<p>A post.</p>', 1, 2, false
      )
    `;
  },
);

Given("the review has a {word} social post dated {string}", async ({ app }, status: string, on: string) => {
  const [social] = await app.sql`
    INSERT INTO social_posts (targets, status, posted_at)
    VALUES ('{mastodon,bluesky}', ${status}, ${on ? stamp(on) : null}::text::timestamp AT TIME ZONE 'America/Chicago')
    RETURNING id
  `;
  await app.sql`INSERT INTO social_post_parts (social_post_id, position, body) VALUES (${social.id}, 1, 'Hello')`;
});

Given("the review has a journal entry on {string} reading {string}", async ({ app }, day: string, body: string) => {
  const text = body.replaceAll("\\n", "\n");
  await app.sql`
    INSERT INTO journal_entries (entry_date, entry_time, body, body_html)
    VALUES (${day}, '09:00', ${text}, ${`<p>${text}</p>`})
  `;
});

Given(
  "the review has a journal entry on {string} reading {string} tagged {string}",
  async ({ app }, day: string, body: string, tags: string) => {
    const text = body.replaceAll("\\n", "\n");
    const [entry] = await app.sql`
        INSERT INTO journal_entries (entry_date, entry_time, body, body_html)
        VALUES (${day}, '09:00', ${text}, ${`<p>${text}</p>`})
        RETURNING id
      `;
    for (const tag of await tagIds(app.sql, tags)) {
      await app.sql`INSERT INTO journal_entry_tags (journal_entry_id, tag_id) VALUES (${entry.id}, ${tag})`;
    }
  },
);

Given("the review has the commits:", async ({ app }, table: DataTable) => {
  for (const row of table.hashes()) {
    await app.sql`
      INSERT INTO commits (sha, repo, branch, message, commit_date, commit_time, additions, deletions)
      VALUES (
        ${randomBytes(20).toString("hex")}, ${row.repo}, 'main', 'A commit', ${row.date}, '09:00',
        ${Number(row.additions || 0)}, ${Number(row.deletions || 0)}
      )
    `;
  }
});

When("I visit the review {int} days from today", async ({ page }, days: number) => {
  await page.goto(`/admin/review?day=${iso(shift(chicagoToday(), days))}`);
});

When("I post the review note {string} for the day {string}", async ({ page }, body: string, day: string) => {
  await postNote(page, { day, "note[body]": body.replaceAll("\\n", "\n") });
});

When("I post the review note {string} for the month ending {string}", async ({ page }, body: string, day: string) => {
  await postNote(page, { day, "note[body]": body, period: "month" });
});

When("I post the review note {string} for this week", async ({ page }, body: string) => {
  await postNote(page, { day: iso(shift(thisMonday(), 6)), "note[body]": body });
});

Then("the review note post answers {int}", ({}, status: number) => {
  expect(notePosted).toBe(status);
});

Then("the review page is at {string}", ({ page }, path: string) => {
  const url = new URL(page.url());

  expect(`${url.pathname}${url.search}`).toBe(path);
});

Then("the review shows {string}", async ({ page }, css: string) => {
  await expect(page.locator(css).first()).toBeAttached();
});

Then("the review shows {string} reading {string}", async ({ page }, css: string, text: string) => {
  await expect(page.locator(css).filter({ hasText: text }).first()).toBeAttached();
});

Then("the review's {string} reads {string}", async ({ page }, css: string, text: string) => {
  await expect(page.locator(css).first()).toHaveText(text);
});

Then("the review's {string} starts with {string}", async ({ page }, css: string, text: string) => {
  await expect(page.locator(css).first()).toHaveText(new RegExp(`^${text.replaceAll(/[.*+?^${}()|[\]\\]/g, "\\$&")}`));
});

Then("the review shows no {string}", async ({ page }, css: string) => {
  await expect(page.locator(css)).toHaveCount(0);
});

Then("the review shows no {string} reading {string}", async ({ page }, css: string, text: string) => {
  await expect(page.locator(css).filter({ hasText: text })).toHaveCount(0);
});

Then("the review lists {string} as {string}", async ({ page }, css: string, texts: string) => {
  await expect(page.locator(css)).toHaveText(texts ? texts.split(" | ") : []);
});

Then("the review counts {int} of {string}", async ({ page }, count: number, css: string) => {
  await expect(page.locator(css)).toHaveCount(count);
});

Then(
  "the review lists the {word} of {string} as {string}",
  async ({ page }, attribute: string, css: string, values: string) => {
    const found = await page
      .locator(css)
      .evaluateAll((all, name) => all.map((one) => one.getAttribute(name) ?? "none"), attribute);

    expect(found.join(" | ")).toBe(values);
  },
);

Then(
  "the review's {string} has the {word} {string}",
  async ({ page }, css: string, attribute: string, value: string) => {
    await expect(page.locator(css).first()).toHaveAttribute(attribute, value);
  },
);

Then("the review's {string} holds {string}", async ({ page }, css: string, value: string) => {
  await expect(page.locator(css).first()).toHaveValue(value);
});

Then("the review links {string} to {string}", async ({ page }, name: string, href: string) => {
  const links = page.getByRole("link", { exact: true, name, includeHidden: true });

  await expect(links.and(page.locator(`[href="${href}"]`)).first()).toBeAttached();
});

Then("the review has no link {string}", async ({ page }, name: string) => {
  await expect(page.getByRole("link", { exact: true, name, includeHidden: true })).toHaveCount(0);
});

Then("the review names this week from Monday to Sunday", async ({ page }) => {
  const monday = thisMonday();
  const short = (date: Date, year = false) =>
    date.toLocaleDateString("en-US", {
      day: "numeric",
      month: "short",
      timeZone: "UTC",
      ...(year && { year: "numeric" }),
    });

  await expect(page.locator(".page-head-sub")).toContainText(`${short(monday)} → ${short(shift(monday, 6), true)}`);
});

Then("the review's calendar API marks only the journal's own days this week", async ({ app, request, tokens }) => {
  const monday = thisMonday();
  const { body } = await callApi(
    request,
    tokens.api,
    `GET /api/v1/calendar?from=${iso(monday)}&to=${iso(shift(monday, 6))}`,
  );
  const rows = await app.sql`SELECT DISTINCT entry_date::text AS day FROM journal_entries`;
  const written = new Set(rows.map(({ day }) => day));
  const days = Array.from({ length: 7 }, (_, index) => written.has(iso(shift(monday, index))));

  expect((body.days as Record<string, unknown>[]).map((day) => day.journal)).toEqual(days);
});

Then("the review database holds no journal entry after today", async ({ app }) => {
  const [{ count }] = await app.sql`
    SELECT count(*)::int AS count FROM journal_entries WHERE entry_date > (now() AT TIME ZONE 'America/Chicago')::date
  `;

  expect(count).toBe(0);
});

Then("the review database holds this week's note {string}", async ({ app }, body: string) => {
  const rows = await app.sql`SELECT body FROM review_notes WHERE period = 'week' AND starts_on = ${iso(thisMonday())}`;

  expect(rows.map((row) => row.body)).toEqual([body]);
});

When("I call the review API with {string}", async ({ request, tokens }, call: string) => {
  reviewAnswer = await callApi(request, tokens.api, call);
});

When("I call the review API with {string} and:", async ({ request, tokens }, call: string, data: string) => {
  reviewAnswer = await callApi(request, tokens.api, call, data);
});

Then("the review API answers {int}", ({}, status: number) => {
  expect(reviewAnswer.status, JSON.stringify(reviewAnswer.body)).toBe(status);
});

Then("the review API answer, less its stamps, is:", ({}, json: string) => {
  expect(unstamped(reviewAnswer.body, ["created_at", "updated_at"])).toEqual(JSON.parse(json));
});

Then(
  "the review API answer's {string} carries the stored {word} note of {string}",
  async ({ app }, path: string, period: string, startsOn: string) => {
    const [note] = await app.sql`
      SELECT body, to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at,
              to_char(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS updated_at
      FROM review_notes WHERE period = ${period} AND starts_on = ${startsOn}
    `;

    const found = dig(reviewAnswer.body, path);

    expect(note, `no ${period} note starts on ${startsOn}`).toBeDefined();
    if (path === ".") expect(found).toMatchObject({ ...note });
    else expect(found).toEqual({ ...note });
  },
);

Then(
  "the review MCP tool {string} answers as {string} does, given:",
  async ({ request, tokens }, tool: string, call: string, data: string) => {
    const api = await callApi(request, tokens.api, call, call.startsWith("GET") ? undefined : data);
    const mcp = await callMcp(request, tokens.mcp, tool, data);

    expect(mcp.isError, mcp.text).toBe(false);
    expect(parsed(mcp.text)).toEqual(api.body);
  },
);

Then(
  "the review MCP tool {string} answers as {string} does but for its stamps, given:",
  async ({ request, tokens }, tool: string, call: string, data: string) => {
    const api = await callApi(request, tokens.api, call, data);
    const mcp = await callMcp(request, tokens.mcp, tool, data);

    expect(mcp.isError, mcp.text).toBe(false);
    expect(unstamped(parsed(mcp.text))).toEqual(unstamped(api.body));
  },
);

Then(
  "the review MCP tool {string} refuses with the message {string} gives, given:",
  async ({ request, tokens }, tool: string, call: string, data: string) => {
    const api = await callApi(request, tokens.api, call, call.startsWith("GET") ? undefined : data);
    const mcp = await callMcp(request, tokens.mcp, tool, data);

    expect([mcp.isError, mcp.text]).toEqual([true, api.body.message]);
  },
);

Then(
  "the review MCP tool {string} refuses ending with the message {string} gives, given:",
  async ({ request, tokens }, tool: string, call: string, data: string) => {
    const api = await callApi(request, tokens.api, call, call.startsWith("GET") ? undefined : data);
    const mcp = await callMcp(request, tokens.mcp, tool, data);

    expect(mcp.isError).toBe(true);
    expect(mcp.text.endsWith(String(api.body.message)), mcp.text).toBe(true);
  },
);

Then("the review API answer names this week", ({}) => {
  const monday = thisMonday();
  const { from, period, to } = reviewAnswer.body;

  expect({ from, period, to }).toEqual({ from: iso(monday), period: "week", to: iso(shift(monday, 6)) });
});

When("I fill the review note with {string}", async ({ page }, body: string) => {
  await page.getByRole("textbox", { exact: true, name: "Review note" }).fill(body);
});

Then("the review has the link {string}", async ({ page }, name: string) => {
  await expect(page.getByRole("link", { exact: true, name, includeHidden: true }).first()).toBeAttached();
});
