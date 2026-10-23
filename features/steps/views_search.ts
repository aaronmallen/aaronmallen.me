import { type APIRequestContext, expect, type Page } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import type postgres from "postgres";
import { Before, Given, Then, When } from "../support/world.ts";

let posted = { location: "", status: 0 };

const texts = async (page: Page, selector: string) =>
  (await page.locator(selector).allTextContents()).map((text) => text.replaceAll(/\s+/g, " ").trim());

const savedView = (page: Page, name: string) => page.locator(".saved-view", { hasText: name });

const manage = async (page: Page, name: string) => {
  await savedView(page, name).locator("summary").click();
  return savedView(page, name).locator(".saved-view-panel");
};

Given(
  "a saved view {string} on the {word} screen with the filters:",
  async ({ app }, name: string, screen: string, filters: string) => {
    await app.sql`INSERT INTO saved_views ${app.sql({ filters: JSON.parse(filters), name, screen })}`;
  },
);

Given("a saved view {string} on the {word} screen", async ({ app }, name: string, screen: string) => {
  await app.sql`INSERT INTO saved_views ${app.sql({ name, screen })}`;
});

When("I save the view {string} from the saved views bar", async ({ page }, name: string) => {
  const bar = page.locator(".saved-views");
  await bar.locator("summary", { hasText: "Save view" }).click();
  const panel = bar.locator("details[open] > .saved-view-panel");
  await panel.getByLabel("Name").fill(name);
  await panel.getByRole("button", { name: "Save view" }).click();
  await expect(page.locator(".saved-view-link", { hasText: name })).toBeVisible();
});

When("I rename the saved view {string} to {string}", async ({ page }, name: string, renamed: string) => {
  const panel = await manage(page, name);
  await panel.getByLabel("Name").fill(renamed);
  await panel.getByRole("button", { name: "Rename" }).click();
});

When("I point the saved view {string} at the filters on screen", async ({ page }, name: string) => {
  await (await manage(page, name)).getByRole("button", { name: "Use current filters" }).click();
});

When("I delete the saved view {string} and confirm", async ({ page }, name: string) => {
  await (await manage(page, name)).getByRole("button", { name: "Delete" }).click();
  await page.locator("[data-confirm-accept]").click();
});

const csrfToken = async (page: Page) => {
  if (!new URL(page.url(), "http://x").pathname.startsWith("/admin")) await page.goto("/admin/tasks");
  return page.locator("input[name=_csrf_token]").first().inputValue();
};

When("I post to the saved views admin at {string} with:", async ({ page }, path: string, table: DataTable) => {
  const body = new URLSearchParams([["_csrf_token", await csrfToken(page)], ...table.raw()]);
  const response = await page.request.post(path, {
    data: body.toString(),
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    maxRedirects: 0,
  });
  posted = { location: response.headers().location ?? "", status: response.status() };
});

const screens: Record<string, string> = {
  activity: "/admin/activity",
  journal: "/admin/journal",
  posts: "/admin/posts",
  tasks: "/admin/tasks",
};

const postSaveForm = async (page: Page, screen: string, name: string, query: string, extra = "") => {
  const filters = [...new URLSearchParams(`${query}&${extra}`)]
    .filter(([key]) => key)
    .map(([key, value]) => [`filters[${key.replace(/^([^[]+)/, "$1]")}`, value]);
  const fields = [
    ["screen", screen],
    ["saved_view[name]", name],
    ["return_to", `${screens[screen]}?${query}`],
  ];
  const body = new URLSearchParams([["_csrf_token", await csrfToken(page)], ...fields, ...filters]);
  const response = await page.request.post("/admin/saved-views", {
    data: body.toString(),
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    maxRedirects: 0,
  });
  posted = { location: response.headers().location ?? "", status: response.status() };
};

When(
  "I post the Save view form on the {word} screen named {string} for {string}",
  ({ page }, screen: string, name: string, query: string) => postSaveForm(page, screen, name, query),
);

When(
  "I post the Save view form on the {word} screen named {string} for {string} adding {string}",
  ({ page }, screen: string, name: string, query: string, extra: string) =>
    postSaveForm(page, screen, name, query, extra),
);

When("I follow the saved views admin post", async ({ page }) => {
  await page.goto(posted.location);
});

Then("the saved views admin post answers {int}", ({}, status: number) => {
  expect(posted.status).toBe(status);
});

Then("the saved views admin post sends me to {string}", ({}, path: string) => {
  expect(posted.status).toBe(302);
  expect(posted.location).toBe(path);
});

Then("the saved views bar lists {string}", async ({ page }, names: string) => {
  await expect.poll(async () => (await texts(page, ".saved-view-link")).join(", ")).toBe(names);
});

Then("the saved view {string} links to {string}", async ({ page }, name: string, href: string) => {
  await expect(page.locator(".saved-view-link", { hasText: name })).toHaveAttribute("href", href);
});

Then("the saved views page shows {string}", async ({ page }, selector: string) => {
  await expect(page.locator(selector).first()).toBeAttached();
});

Then("the saved views page shows {string} reading {string}", async ({ page }, selector: string, text: string) => {
  await expect.poll(() => texts(page, selector)).toContainEqual(text);
});

Then("the saved views page's {string} holds {string}", async ({ page }, selector: string, value: string) => {
  await expect(page.locator(selector).first()).toHaveValue(value);
});

Then("the saved views page's {string} begins with {string}", async ({ page }, selector: string, text: string) => {
  const [first] = await texts(page, selector);

  expect(first?.toLowerCase()).toMatch(new RegExp(`^${text.toLowerCase()}`));
});

Then("the saved views toast says {string}", async ({ page }, text: string) => {
  await expect.poll(() => texts(page, "[data-toast] .toast")).toContainEqual(expect.stringContaining(text));
});

Then("the saved views page is at {string}", async ({ page }, path: string) => {
  await expect.poll(() => new URL(page.url()).pathname + new URL(page.url()).search).toBe(path);
});

Then("the stored saved views are:", async ({ app }, json: string) => {
  const rows = await app.sql`SELECT name, screen, filters FROM saved_views ORDER BY id`;

  expect(rows.map((row) => ({ ...row }))).toEqual(JSON.parse(json));
});

type Fetched = { body: unknown; headers: Record<string, string>; status: number };

let fetched: Fetched = { body: null, headers: {}, status: 0 };

const fetchJson = async (request: APIRequestContext, path: string) => {
  const response = await request.get(path, { headers: { Accept: "application/json" }, maxRedirects: 0 });
  const text = await response.text();
  const body = response.ok() ? JSON.parse(text) : text;
  fetched = { body, headers: response.headers(), status: response.status() };
};

When("I fetch the saved views list for the palette", ({ page }) =>
  fetchJson(page.request, "/admin/saved-views/palette"),
);

When("I fetch the saved views list for the palette signed out", ({ request }) =>
  fetchJson(request, "/admin/saved-views/palette"),
);

Then("the saved views list answers {int} with the type {string}", ({}, status: number, type: string) => {
  expect(fetched.status).toBe(status);
  expect(fetched.headers["content-type"]?.split(";")[0]).toBe(type);
});

Then("the saved views list answers {int} without sending me anywhere", ({}, status: number) => {
  expect(fetched.status).toBe(status);
  expect(fetched.headers.location).toBeUndefined();
});

Then("the saved views list's header {string} is {string}", ({}, name: string, value: string) => {
  expect(fetched.headers[name.toLowerCase()]).toBe(value);
});

Then("the saved views list's rows are:", ({}, json: string) => {
  expect((fetched.body as { rows: unknown }).rows).toEqual(JSON.parse(json));
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

const apiAnswer = async (request: APIRequestContext, token: string | undefined, call: string, data?: string) => {
  const [method, path] = call.split(" ");
  const { id: _, ...body } = data === undefined ? {} : JSON.parse(data);
  const response = await request.fetch(path, {
    data: method === "GET" || data === undefined ? undefined : body,
    headers: { Authorization: `Bearer ${token}` },
    method,
  });
  return response.json();
};

const mcpAnswer = async (request: APIRequestContext, token: string | undefined, name: string, data: string) => {
  const response = await request.post("/mcp", {
    data: { id: 1, jsonrpc: "2.0", method: "tools/call", params: { arguments: JSON.parse(data), name } },
    headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${token}` },
  });
  const reply = await response.json();
  const text = reply.result.content[0].text;
  try {
    return { error: reply.result.isError === true, json: JSON.parse(text), text };
  } catch {
    return { error: reply.result.isError === true, json: null, text };
  }
};

Then(
  "the saved views MCP tool {string} answers as {string} does, given:",
  async ({ request, tokens }, tool: string, call: string, data: string) => {
    const api = await apiAnswer(request, tokens.api, call, data);

    expect(trusted((await mcpAnswer(request, tokens.mcp, tool, data)).json)).toEqual(api);
  },
);

Then(
  "the saved views MCP tool {string} answers as {string} does but for the ID, given:",
  async ({ request, tokens }, tool: string, call: string, data: string) => {
    const { id: _, ...api } = await apiAnswer(request, tokens.api, call, data);
    const { id: _mcpId, ...mcp } = (await mcpAnswer(request, tokens.mcp, tool, data)).json;

    expect(mcp).toEqual(api);
  },
);

Then(
  "the saved views MCP tool {string} refuses with the message {string} gives, given:",
  async ({ request, tokens }, tool: string, call: string, data: string) => {
    const api = await apiAnswer(request, tokens.api, call, data);
    const mcp = await mcpAnswer(request, tokens.mcp, tool, data);

    expect(mcp.error).toBe(true);
    expect(mcp.text).toBe(api.message);
  },
);

Then(
  "the saved views API refuses {string} on {string} alone, given:",
  async ({ request, tokens }, call: string, field: string, data: string) => {
    const [method, path] = call.split(" ");
    const response = await request.fetch(path, {
      data: method === "GET" ? undefined : JSON.parse(data),
      headers: { Authorization: `Bearer ${tokens.api}` },
      method,
    });

    expect(response.status()).toBe(422);
    expect(Object.keys((await response.json()).errors)).toEqual([field]);
  },
);

const isoDay = (daysAgo: number) => {
  const day = new Date(`${new Date().toLocaleDateString("en-CA", { timeZone: "America/Chicago" })}T00:00:00Z`);
  day.setUTCDate(day.getUTCDate() - daysAgo);
  return day.toISOString().slice(0, 10);
};

const withDays = (text: string) =>
  text.replaceAll(/\{today(?:([+-])(\d+))?\}/g, (_, sign: string, count: string) =>
    isoDay(sign === "+" ? -Number(count) : Number(count ?? 0)),
  );

const dig = (body: unknown, path: string) =>
  path
    ? path.split(".").reduce<unknown>((value, key) => (value as Record<string, unknown> | undefined)?.[key], body)
    : body;

type Records = { continue_to?: string; records: Record<string, unknown>[] } & Record<string, unknown>;

let records: Records = { records: [] };
let recordsStatus = 0;

const runWithDays = async (sql: postgres.Sql, statement: string) => {
  await sql.unsafe(withDays(statement)).simple();
};

Given("the saved views database runs:", ({ app }, statement: string) => runWithDays(app.sql, statement));

Given("the search database runs:", ({ app }, statement: string) => runWithDays(app.sql, statement));

const readRecords = async (request: APIRequestContext, token: string | undefined, id: number, query = "") => {
  const response = await request.get(`/api/v1/saved_views/${id}/records${withDays(query)}`, {
    headers: { Accept: "application/json", Authorization: `Bearer ${token}` },
  });
  recordsStatus = response.status();
  records = await response.json();
  return records;
};

When("I read the records of saved view {int}", ({ request, tokens }, id: number) =>
  readRecords(request, tokens.api, id),
);

When("I read the records of saved view {int} with {string}", ({ request, tokens }, id: number, query: string) =>
  readRecords(request, tokens.api, id, query),
);

When("I read the next window of saved view {int}", ({ request, tokens }, id: number) =>
  readRecords(request, tokens.api, id, `?continue_to=${records.continue_to}`),
);

Then("the saved view records answer {int}", ({}, status: number) => {
  expect(recordsStatus).toBe(status);
});

Then("the saved view records' {string} is {string}", ({}, path: string, value: string) => {
  expect(String(dig(records, path))).toBe(withDays(value));
});

Then("the saved view records' {string} is:", ({}, path: string, json: string) => {
  expect(dig(records, path)).toEqual(JSON.parse(withDays(json)));
});

Then("the saved view records' {string} holds:", ({}, path: string, json: string) => {
  expect(dig(records, path)).toMatchObject(JSON.parse(withDays(json)));
});

Then("the saved view records give the {word}s {string}", ({}, field: string, values: string) => {
  expect(records.records.map((record) => String(record[field])).join(", ")).toBe(withDays(values));
});

Then(
  "the saved view records are the tasks {string} as read_task gives them, less its note, comments, record links and timeline",
  async ({ request, tokens }, ids: string) => {
    const tasks = [];
    for (const id of ids.split(", ")) {
      const response = await request.get(`/api/v1/tasks/${id}`, { headers: { Authorization: `Bearer ${tokens.api}` } });
      const { note, comments, record_links, timeline, ...task } = await response.json();
      tasks.push(task);
    }

    expect(records.records).toEqual(tasks);
  },
);

Then(
  "the saved view records are the entries {string} as read_journal_entry gives them, less their record links",
  async ({ request, tokens }, ids: string) => {
    const entries = [];
    for (const id of ids.split(", ")) {
      const headers = { Authorization: `Bearer ${tokens.api}` };
      const { record_links, ...entry } = await (await request.get(`/api/v1/journal_entries/${id}`, { headers })).json();
      entries.push(entry);
    }

    expect(trusted(records.records)).toEqual(trusted(entries));
  },
);

let tagged: unknown[] = [];

When(
  "I tag the post {string} with {string} through the bulk tag endpoint",
  async ({ app, request, tokens }, title: string, tag: string) => {
    const [{ id }] = await app.sql`SELECT id FROM posts WHERE title = ${title}`;
    const response = await request.post("/api/v1/posts/bulk/tag", {
      data: { ids: [id], tag },
      headers: { Authorization: `Bearer ${tokens.api}` },
    });
    tagged = (await response.json()).posts;
  },
);

Then("the saved view records are the posts the bulk tag endpoint answered", ({}) => {
  expect(records.records).toEqual(tagged);
});

Then(
  "the read_saved_view tool answers saved view {int} as the endpoint does, given:",
  async ({ request, tokens }, id: number, data: string) => {
    const page = JSON.parse(data).page;
    const api = await readRecords(request, tokens.api, id, page ? `?page=${page}` : "");

    expect(trusted((await mcpAnswer(request, tokens.mcp, "read_saved_view", data)).json)).toEqual(trusted(api));
  },
);

Then(
  "the read_saved_view tool refuses saved view {int} with the message the endpoint gives",
  async ({ request, tokens }, id: number) => {
    const api = await readRecords(request, tokens.api, id);
    const mcp = await mcpAnswer(request, tokens.mcp, "read_saved_view", JSON.stringify({ id }));

    expect(mcp.error).toBe(true);
    expect(mcp.text).toBe(String(api.message));
  },
);

Then(
  "the read_saved_view tool gives saved view {int} the {word}s {string}",
  async ({ request, tokens }, id: number, field: string, values: string) => {
    const answer = trusted((await mcpAnswer(request, tokens.mcp, "read_saved_view", JSON.stringify({ id }))).json);

    expect((answer as Records).records.map((record) => String(record[field])).join(", ")).toBe(values);
  },
);

Then(
  "the activity screen and saved view {int} both show:",
  async ({ app, page, request, tokens }, id: number, table: DataTable) => {
    const [{ filters }] = await app.sql`SELECT filters FROM saved_views WHERE id = ${id}`;
    const query = new URLSearchParams();
    for (const [key, value] of Object.entries(filters as Record<string, unknown>)) {
      if (typeof value === "object" && value) {
        for (const [inner, flag] of Object.entries(value)) query.append(`${key}[${inner}]`, String(flag));
      } else {
        query.append(key, String(value));
      }
    }
    await page.goto(`/admin/activity?${query}`);
    const shown = [];
    for (const day of await page.locator(".activity-day").all()) {
      const date = await day.locator(".day-date").getAttribute("datetime");
      for (const name of await day.locator(".activity-event-name").allTextContents()) shown.push([date, name.trim()]);
    }
    const answer = trusted((await mcpAnswer(request, tokens.mcp, "read_saved_view", JSON.stringify({ id }))).json);
    const saved = (answer as Records).records.map((record) => [record.date, record.name]);
    const expected = table.raw().map(([day, name]) => [withDays(day), name]);

    expect([shown, saved]).toEqual([expected, expected]);
  },
);

Then("the admin search lists {string}", async ({ page }, titles: string) => {
  expect((await texts(page, ".li-title")).join(", ")).toBe(titles);
});

Then("the admin search lists {string} in any order", async ({ page }, titles: string) => {
  expect((await texts(page, ".li-title")).sort()).toEqual(titles.split(", ").sort());
});

Then("the admin search lists {int} results", async ({ page }, count: number) => {
  await expect(page.locator(".li-title")).toHaveCount(count);
});

Then("the admin search lists {string} under {string}", async ({ page }, title: string, heading: string) => {
  await expect(page.locator(".card", { hasText: heading }).locator(".li-title", { hasText: title })).toBeVisible();
});

Then("the admin search kinds read {string}", async ({ page }, kinds: string) => {
  const pills = await page.locator(".search-kind").evaluateAll((links) =>
    links.map((link) => {
      const text = link.textContent?.replaceAll(/\s+/g, " ").trim();
      return link.getAttribute("aria-current") ? `${text} (current)` : text;
    }),
  );

  expect(pills.join(", ")).toBe(kinds);
});

Then("the admin search kinds include {string}", async ({ page }, kind: string) => {
  expect(await texts(page, ".search-kind")).toContain(kind);
});

Then("the admin search links {string} to {string}", async ({ page }, name: string, href: string) => {
  await expect(page.getByRole("link", { exact: true, name }).first()).toHaveAttribute("href", href);
});

Then("the admin search links {int} time(s) to {string}", async ({ page }, count: number, name: string) => {
  await expect(page.getByRole("link", { exact: true, name })).toHaveCount(count);
});

Then("the admin search shows {string}", async ({ page }, selector: string) => {
  await expect(page.locator(selector).first()).toBeAttached();
});

Then("the admin search shows no {string}", async ({ page }, selector: string) => {
  await expect(page.locator(selector)).toHaveCount(0);
});

Then("the admin search shows {string} reading {string}", async ({ page }, selector: string, text: string) => {
  await expect.poll(() => texts(page, selector)).toContainEqual(text);
});

Then("the admin search labels the tasks {string} in any order", async ({ page }, labels: string) => {
  const found = await page
    .locator(".card .li")
    .evaluateAll((rows) => rows.map((row) => row.querySelector(".li-side span")?.textContent?.trim() ?? ""));

  expect(found.sort()).toEqual(labels.split(", ").sort());
});

Then("the admin search's {string} holds {string}", async ({ page }, selector: string, value: string) => {
  await expect(page.locator(selector).first()).toHaveValue(value);
});

Then("the admin search lists {string} last", async ({ page }, title: string) => {
  expect((await texts(page, ".li-title")).at(-1)).toBe(title);
});

Then(
  "the admin search for {string} signed out does not hold {string}",
  async ({ request }, query: string, text: string) => {
    const response = await request.get(`/admin/search?q=${encodeURIComponent(query)}`);

    expect(await response.text()).not.toContain(text);
  },
);

type Found = { results: Record<string, unknown>[] } & Record<string, unknown>;

let found: Found = { results: [] };
let foundStatus = 0;

const searchApi = async (request: APIRequestContext, token: string | undefined, query: string) => {
  const response = await request.get(`/api/v1/search${query}`, {
    headers: { Accept: "application/json", Authorization: `Bearer ${token}` },
  });
  foundStatus = response.status();
  found = await response.json();
  return found;
};

const field = (results: Record<string, unknown>[], name: string) =>
  results.map((result) => (result[name] === null ? "none" : String(result[name])));

When("I search the API with {string}", async ({ request, tokens }, query: string) => {
  await searchApi(request, tokens.api, query);
});

Then("the API search answers {int}", ({}, status: number) => {
  expect(foundStatus, JSON.stringify(found)).toBe(status);
});

Then("the API search gives the {word}s {string}", ({}, name: string, values: string) => {
  expect(field(found.results, name).join(", ")).toBe(withDays(values));
});

Then("the API search gives the {word}s {string} in any order", ({}, name: string, values: string) => {
  expect(field(found.results, name).sort()).toEqual(values.split(", ").sort());
});

Then("the API search gives nothing", ({}) => {
  expect(found.results).toEqual([]);
});

Then("the API search's {string} is {string}", ({}, path: string, value: string) => {
  expect(String(dig(found, path))).toBe(withDays(value));
});

Then("the API search's {string} is:", ({}, path: string, json: string) => {
  expect(dig(found, path)).toEqual(JSON.parse(withDays(json)));
});

Then("the API search has no {string}", ({}, key: string) => {
  expect(found).not.toHaveProperty(key);
});

Then("every API search result has the fields {string} in that order", ({}, names: string) => {
  expect([...new Set(found.results.map((result) => Object.keys(result).join(", ")))]).toEqual([names]);
});

Then("each API search match runs to {int} words or fewer", ({}, count: number) => {
  for (const result of found.results) expect(String(result.match).split(/\s+/).length).toBeLessThanOrEqual(count);
});

Then("the API search's first match holds {string}", ({}, text: string) => {
  expect(String(found.results[0]?.match)).toContain(text);
});

Then("the API search lists the titles the admin search lists for {string}", async ({ page }, query: string) => {
  await page.goto(`/admin/search${query}`);

  expect(field(found.results, "title")).toEqual(await texts(page, ".li-title"));
});

Then("the API search's first id reads as the task {string}", async ({ request, tokens }, title: string) => {
  const response = await request.get(`/api/v1/tasks/${found.results[0]?.id}`, {
    headers: { Authorization: `Bearer ${tokens.api}` },
  });

  expect((await response.json()).title).toBe(title);
});

Then("the MCP search answers as the API search does, given:", async ({ request, tokens }, data: string) => {
  const args = JSON.parse(data);
  const query = new URLSearchParams(Object.entries(args).map(([key, value]) => [key, String(value)]));
  const api = await searchApi(request, tokens.api, `?${query}`);

  expect(trusted((await mcpAnswer(request, tokens.mcp, "search", data)).json)).toEqual(api);
});

When("I search with the MCP tool, given:", async ({ request, tokens }, data: string) => {
  found = (await mcpAnswer(request, tokens.mcp, "search", data)).json;
});

Then("the API search's {string} holds the text {string}", ({}, path: string, text: string) => {
  expect(String(dig(found, path))).toContain(text);
});

Then(
  "the API search lists fewer titles than the admin search lists for {string}, leaving out {string}",
  async ({ page }, query: string, title: string) => {
    await page.goto(`/admin/search${query}`);

    expect(await texts(page, ".li-title")).toContain(title);
    expect(field(found.results, "title")).not.toContain(title);
  },
);

When("the search attempts reaper runs", async ({ app }) => {
  await app.pushJob("Search::Jobs::ReapSearchAttempts");
});

Before(() => {
  posted = { location: "", status: 0 };
  fetched = { body: null, headers: {}, status: 0 };
  records = { records: [] };
  recordsStatus = 0;
  tagged = [];
  found = { results: [] };
  foundStatus = 0;
});
