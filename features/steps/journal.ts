import { type APIRequestContext, expect, type Page } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import type postgres from "postgres";
import { Before, Given, Then, When } from "../support/world.ts";

const zone = "America/Chicago";

const dayOf = (offset: number) => {
  const today = new Intl.DateTimeFormat("en-CA", { timeZone: zone }).format(new Date());
  const day = new Date(`${today}T00:00:00Z`);
  day.setUTCDate(day.getUTCDate() + offset);
  return day.toISOString().slice(0, 10);
};

const dated = (text: string) =>
  text.replaceAll(/\{today([+-]\d+)?\}/g, (_, shift: string | undefined) => dayOf(Number(shift ?? 0)));

const unescaped = (text: string) => dated(text).replaceAll("\\n", "\n").replaceAll("\\t", "\t");

const cell = (text: string) => unescaped(text.replace(/^"(.*)"$/s, "$1"));

const tagId = async (sql: postgres.Sql, name: string, color = "mk-green") => {
  const [found] = await sql`SELECT id FROM tags WHERE name = ${name} AND scope = 'private'`;
  if (found) return found.id;
  const [made] = await sql`INSERT INTO tags ${sql({ color, name, scope: "private" })} RETURNING id`;
  return made.id;
};

Given("the private tag {string} is coloured {string}", async ({ app }, name: string, color: string) => {
  await tagId(app.sql, name, color);
});

Given("the journal holds:", async ({ app }, table: DataTable) => {
  for (const row of table.hashes()) {
    const body = unescaped(row.body);
    const entry = {
      body,
      body_html: row.html ?? `<p>${body}</p>`,
      entry_date: dated(row.day || "{today}"),
      entry_time: row.time || "12:00",
      ...(row.written ? { created_at: row.written } : {}),
      ...(row.changed ? { updated_at: row.changed } : {}),
    };
    const [{ id }] = await app.sql`INSERT INTO journal_entries ${app.sql(entry)} RETURNING id`;
    for (const name of (row.tags ?? "").split(", ").filter(Boolean)) {
      await app.sql`INSERT INTO journal_entry_tags ${app.sql({ journal_entry_id: id, tag_id: await tagId(app.sql, name) })}`;
    }
  }
});

Given("the journal holds numbered entries:", async ({ app }, table: DataTable) => {
  for (const row of table.hashes()) {
    const back = Number(row["days back"]);
    const prefix = `d${back}e`;
    await app.sql`
      INSERT INTO journal_entries (entry_date, entry_time, body, body_html)
      SELECT ${dayOf(-back)}::date, '12:00', ${prefix}::text || n, '<p>' || ${prefix}::text || n || '</p>'
      FROM generate_series(0, ${Number(row.count) - 1}::int) AS n
    `;
  }
});

Given("the journal entry {string} links to the post {string}", async ({ app }, body: string, title: string) => {
  const [{ id: entry }] = await app.sql`SELECT id FROM journal_entries WHERE body = ${body}`;
  const [{ id: post }] = await app.sql`SELECT id FROM posts WHERE title = ${title}`;
  await app.sql`
    INSERT INTO record_links ${app.sql({ left_id: post, left_kind: "post", right_id: entry, right_kind: "journal_entry" })}
  `;
});

let posted = { location: "", status: 0 };

const postJournalForm = async (page: Page, action: string, rows: string[][]) => {
  const token = page.locator("input[name='_csrf_token']").first();
  if (!new URL(page.url(), "http://x").pathname.startsWith("/admin") || !(await token.count())) {
    await page.goto("/admin/journal");
  }
  const fields = [["_csrf_token", await token.inputValue()], ...rows.map(([name, value]) => [name, cell(value)])];
  const response = page.waitForResponse(
    (sent) => sent.request().method() === "POST" && new URL(sent.url()).pathname === action,
  );
  const navigated = page.waitForNavigation();
  await page.evaluate(
    ({ action, fields }) => {
      const form = document.createElement("form");
      form.method = "post";
      form.action = action;
      for (const [name, value] of fields) {
        const input = document.createElement("textarea");
        input.name = name;
        input.value = value;
        form.append(input);
      }
      document.body.append(form);
      form.submit();
    },
    { action, fields },
  );
  const answer = await response;
  posted = { location: answer.headers().location ?? "", status: answer.status() };
  await navigated;
};

When("I post the journal form to {string}", ({ page }, action: string) => postJournalForm(page, action, []));

When("I post the journal form to {string} with:", ({ page }, action: string, table: DataTable) =>
  postJournalForm(page, action, table.raw()),
);

When(
  "I post the journal form to {string} without a CSRF token, with:",
  async ({ page }, action: string, table: DataTable) => {
    const response = await page.request.post(action, {
      form: Object.fromEntries(table.raw().map(([name, value]) => [name, cell(value)])),
      maxRedirects: 0,
    });
    posted = { location: response.headers().location ?? "", status: response.status() };
  },
);

Then("the journal post answers {int}", ({}, status: number) => {
  expect(posted.status).toBe(status);
});

Then("the journal post sends me to {string}", ({}, path: string) => {
  const literal = dated(path).replaceAll(/[.*+?^${}()|[\]\\]/g, "\\$&");
  expect(posted.location).toMatch(new RegExp(`^(https?://[^/]+)?${literal}$`));
});

Then("the journal page holds {string}", async ({ page }, selector: string) => {
  await expect(page.locator(dated(selector)).first()).toBeAttached();
});

Then("the journal page holds {int} of {string}", async ({ page }, count: number, selector: string) => {
  await expect(page.locator(dated(selector))).toHaveCount(count);
});

Then("the journal page lacks {string}", async ({ page }, selector: string) => {
  await expect(page.locator(dated(selector))).toHaveCount(0);
});

Then("the journal page shows {string} reading {string}", async ({ page }, selector: string, text: string) => {
  await expect(page.locator(dated(selector)).first()).toHaveText(unescaped(text));
});

Then("the journal page shows {string} holding {string}", async ({ page }, selector: string, text: string) => {
  await expect(page.locator(dated(selector)).first()).toContainText(unescaped(text));
});

const textsOf = (page: Page, selector: string) =>
  page.locator(dated(selector)).evaluateAll((nodes) => nodes.map((node) => (node.textContent ?? "").trim()));

const listed = (text: string) => (text ? unescaped(text).split(" | ") : []);

Then("the journal texts of {string} read {string}", async ({ page }, selector: string, text: string) => {
  await expect.poll(() => textsOf(page, selector)).toEqual(listed(text));
});

Then("the journal entries read {string}", async ({ page }, text: string) => {
  await expect.poll(() => textsOf(page, ".journal-entry-body")).toEqual(listed(text));
});

Then("the journal entries read {string} in any order", async ({ page }, text: string) => {
  await expect.poll(async () => (await textsOf(page, ".journal-entry-body")).sort()).toEqual(listed(text).sort());
});

Then("the journal entries on {string} read {string}", async ({ page }, day: string, text: string) => {
  const selector = `.journal-day:has(time[datetime='${dated(day)}']) .journal-entry-body`;
  await expect.poll(() => textsOf(page, selector)).toEqual(listed(text));
});

const dayDates = (page: Page) =>
  page.locator(".day-date").evaluateAll((nodes) => nodes.map((node) => node.getAttribute("datetime") ?? ""));

Then("the journal shows the days {string}", async ({ page }, days: string) => {
  await expect.poll(() => dayDates(page)).toEqual(dated(days).split(", "));
});

Then(
  "the journal attribute {string} of {string} is {string}",
  async ({ page }, name: string, selector: string, value: string) => {
    await expect(page.locator(dated(selector)).first()).toHaveAttribute(name, unescaped(value));
  },
);

Then("the journal field {string} holds {string}", async ({ page }, label: string, value: string) => {
  await expect(page.getByLabel(label, { exact: true }).first()).toHaveValue(unescaped(value));
});

const template = (page: Page, selector: string) =>
  page.evaluate(
    (selector) =>
      document.querySelector("template[data-journal-edit-template]")?.content.querySelectorAll(selector).length ?? 0,
    dated(selector),
  );

Then("the journal edit template holds {string}", async ({ page }, selector: string) => {
  expect(await template(page, selector)).toBeGreaterThan(0);
});

Then("the journal edit template lacks {string}", async ({ page }, selector: string) => {
  expect(await template(page, selector)).toBe(0);
});

const pagerLink = (page: Page, which: string) =>
  page.locator(`nav.pager a[rel='${which === "newer" ? "prev" : "next"}']`);

Then("the journal's {word} link goes to {string}", async ({ page }, which: string, path: string) => {
  await expect(pagerLink(page, which)).toHaveAttribute("href", dated(path));
});

Then("the journal has no {word} link", async ({ page }, which: string) => {
  await expect(pagerLink(page, which)).toHaveCount(0);
});

const follow = async (page: Page, which: string) => {
  const link = pagerLink(page, which);
  if (!(await link.count())) return false;
  await page.goto((await link.getAttribute("href")) ?? "");
  return true;
};

const here = (page: Page) => {
  const url = new URL(page.url());
  return url.pathname + url.search;
};

When("I follow the journal's {word} link", async ({ page }, which: string) => {
  expect(await follow(page, which)).toBe(true);
});

let olderPages: string[] = [];

When("I follow the journal's older links to the end", async ({ page }) => {
  olderPages = [];
  await page.goto("/admin/journal");
  while (await follow(page, "older")) {
    olderPages.push(here(page));
    expect(olderPages.length, "older pages").toBeLessThan(20);
  }
});

Then("each older journal page comes back after paging newer then older", async ({ page }) => {
  expect(olderPages.length).toBeGreaterThan(1);
  for (const path of olderPages) {
    await page.goto(path);
    expect(await follow(page, "newer"), `newer link on ${path}`).toBe(true);
    expect(await follow(page, "older"), `older link back to ${path}`).toBe(true);
    expect(here(page)).toBe(path);
  }
});

Then("paging newer from the oldest journal page shows the days {string}", async ({ page }, days: string) => {
  const seen = new Set<string>();
  await page.goto(olderPages.at(-1) ?? "/admin/journal");
  let pages = 0;
  do {
    for (const day of await dayDates(page)) seen.add(day);
    pages += 1;
    expect(pages, "newer pages").toBeLessThan(20);
  } while (await follow(page, "newer"));
  expect([...seen].sort()).toEqual(dated(days).split(", ").sort());
});

Then("the journal toast reads {string}", async ({ page }, text: string) => {
  await expect(page.locator("[data-toast] .toast").first()).toHaveText(text);
});

let scriptless = "";

When("I delete the journal entry {string} with scripts off", async ({ app, browser, owner }, body: string) => {
  const context = await browser.newContext({ baseURL: app.url, javaScriptEnabled: false });
  await context.addCookies(owner.cookies);
  const page = await context.newPage();
  await page.goto("/admin/journal");
  const navigated = page.waitForNavigation();
  await page
    .locator(".journal-entry", { hasText: body })
    .locator(".journal-entry-actions")
    .getByRole("button", { exact: true, name: "Delete" })
    .click();
  await navigated;
  expect(new URL(page.url()).pathname).toBe("/admin/journal");
  scriptless = ((await page.locator("[data-toast] .toast").first().textContent()) ?? "").trim();
  await context.close();
});

Then("the scripts-off journal page showed the toast {string}", ({}, text: string) => {
  expect(scriptless).toBe(text);
});

let editing = "";

const entry = (page: Page) => page.locator(`.journal-entry[data-journal-scope='${editing}']`);

When("I edit the journal entry {string}", async ({ page }, text: string) => {
  const item = page.locator(".journal-entry", { hasText: text }).first();
  editing = (await item.getAttribute("data-journal-scope")) ?? "";
  await item.hover();
  await item.getByRole("button", { exact: true, name: "Edit" }).click();
});

When("I hover the journal entry {string}", async ({ page }, text: string) => {
  const item = page.locator(".journal-entry", { hasText: text }).first();
  editing = (await item.getAttribute("data-journal-scope")) ?? "";
  await item.hover();
});

When("I click {string} in the journal entry", async ({ page }, name: string) => {
  const item = entry(page);
  await item.hover();
  await item
    .getByRole("button", { exact: true, name })
    .or(item.getByRole("link", { exact: true, name }))
    .click();
});

When("I write {string} in the journal entry's {string}", async ({ page }, text: string, label: string) => {
  await entry(page).getByLabel(label, { exact: true }).fill(unescaped(text));
});

When("I write {string} in the journal field {string}", async ({ page }, text: string, label: string) => {
  const field = label.startsWith("#") ? page.locator(label) : page.getByLabel(label, { exact: true });
  await field.fill(unescaped(text));
});

When("I type {string} into the journal page", async ({ page }, text: string) => {
  await page.keyboard.type(text);
});

When("I pick {string} as the journal entry date", async ({ page }, day: string) => {
  await page.locator("#journal-entry-date").fill(dated(day));
});

Then("the journal entry's {string} holds {string}", async ({ page }, label: string, text: string) => {
  await expect(entry(page).getByLabel(label, { exact: true })).toHaveValue(unescaped(text));
});

Then("the journal entry holds {string}", async ({ page }, selector: string) => {
  await expect(entry(page).locator(selector).first()).toBeVisible();
});

Then("the journal entry shows {string} reading {string}", async ({ page }, selector: string, text: string) => {
  await expect(entry(page).locator(selector).first()).toHaveText(unescaped(text));
});

Then("the journal entry lacks {string}", async ({ page }, selector: string) => {
  await expect(entry(page).locator(`${selector} >> visible=true`)).toHaveCount(0);
});

Then("the journal entry holds {int} of {string}", async ({ page }, count: number, selector: string) => {
  await expect(entry(page).locator(selector)).toHaveCount(count);
});

Then("the journal entry has the button {string} {word}", async ({ page }, name: string, state: string) => {
  const button = entry(page).getByRole("button", { exact: true, name });
  await (state === "disabled" ? expect(button).toBeDisabled() : expect(button).toBeEnabled());
});

Then("the journal button {string} is {word}", async ({ page }, name: string, state: string) => {
  const button = page.getByRole("button", { exact: true, name }).first();
  await (state === "disabled" ? expect(button).toBeDisabled() : expect(button).toBeEnabled());
});

Then("the focused journal field is {string}", async ({ page }, name: string) => {
  await expect.poll(() => page.evaluate(() => (document.activeElement as HTMLTextAreaElement | null)?.name)).toBe(name);
});

When("I click the journal composer's {string} tool", async ({ page }, label: string) => {
  await page.locator(`#journal-entry [role='toolbar'] button[aria-label='${label}']`).click();
});

const editorOf = (page: Page, where: string) =>
  (where === "composer" ? page.locator("#journal-entry") : entry(page)).locator(
    ".journal-editor [data-markdown-editor]",
  );

When("I switch the journal {word} to {string}", async ({ page }, where: string, tab: string) => {
  await editorOf(page, where).locator(".seg-option", { hasText: tab }).click();
});

Then(
  "the journal {word} preview shows {string} reading {string}",
  async ({ page }, where: string, selector: string, text: string) => {
    await expect(editorOf(page, where).locator(`.preview ${selector}`).first()).toHaveText(text);
  },
);

let preview = { font: "", html: "" };

const look = (page: Page, selector: string) =>
  page
    .locator(selector)
    .first()
    .evaluate((node) => ({ font: getComputedStyle(node).fontFamily, html: node.innerHTML }));

When("I note the journal composer's preview", async ({ page }) => {
  const body = page.locator("#journal-entry .journal-editor .preview .post-body");
  await expect(body).toBeVisible();
  preview = await look(page, "#journal-entry .journal-editor .preview .post-body");
});

Then("the saved journal entry shows the noted preview's markup", async ({ page }) => {
  expect((await look(page, ".journal-entry-body")).html).toBe(preview.html);
});

Then("the saved journal entry is set in the noted preview's typeface", async ({ page }) => {
  expect((await look(page, ".journal-entry-body")).font).toBe(preview.font);
});

const box = (page: Page, selector: string) =>
  page.evaluate((selector) => {
    const rect = document.querySelector(selector)?.getBoundingClientRect();
    return { bottom: rect?.bottom ?? Number.NaN, top: rect?.top ?? Number.NaN };
  }, selector);

When("I scroll the journal to {int}", async ({ page }, y: number) => {
  await page.evaluate((y) => window.scrollTo(0, y), y);
});

Then("the journal window is scrolled to {int}", async ({ page }, y: number) => {
  await expect.poll(() => page.evaluate(() => window.scrollY)).toBe(y);
});

Then("{string} sits at or below {string} on the journal page", async ({ page }, lower: string, upper: string) => {
  expect((await box(page, lower)).top).toBeGreaterThanOrEqual((await box(page, upper)).bottom);
});

Then(
  "{string} starts within {int} pixels of the top of the journal window",
  async ({ page }, selector: string, y: number) => {
    expect((await box(page, selector)).top).toBeLessThan(y);
  },
);

When("I scroll into the fourth journal day", async ({ page }) => {
  await page.evaluate(() => {
    const day = document.querySelectorAll<HTMLElement>(".journal-day")[3];
    const bar = document.querySelector(".top-bar")?.getBoundingClientRect().bottom ?? 0;
    window.scrollBy(0, day.getBoundingClientRect().top + day.offsetHeight / 2 - bar);
  });
});

Then("a journal day heading sits right below the top bar", async ({ page }) => {
  await expect
    .poll(() =>
      page.evaluate(() => {
        const bar = document.querySelector(".top-bar")?.getBoundingClientRect().bottom ?? 0;
        return [...document.querySelectorAll(".day-head")].some(
          (head) => Math.abs(head.getBoundingClientRect().top - bar) < 1,
        );
      }),
    )
    .toBe(true);
});

Then("the journal tags span the width of {string}", async ({ page }, selector: string) => {
  const spans = await page.evaluate((selector) => {
    const foot = document.querySelector(selector);
    if (!foot) return false;
    const style = getComputedStyle(foot);
    const width = foot.clientWidth - Number.parseFloat(style.paddingLeft) - Number.parseFloat(style.paddingRight);
    return Math.abs((foot.querySelector(".tag-pick")?.getBoundingClientRect().width ?? 0) - width) < 1;
  }, selector);

  expect(spans).toBe(true);
});

Then("the journal modal's head names today", async ({ page }) => {
  const short = new Intl.DateTimeFormat("en-US", { day: "numeric", month: "short", timeZone: zone }).format(new Date());
  await expect(page.locator("dialog#journal-write .dialog-head")).toContainText(`journal · private · ${short}`);
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

const journalApi = async (request: APIRequestContext, token: string | undefined, call: string, data: string) => {
  const [method, path] = dated(call).split(" ");
  const { id: _, ...body } = JSON.parse(dated(data));
  const response = await request.fetch(path, {
    data: method === "GET" || method === "DELETE" ? undefined : body,
    headers: { Authorization: `Bearer ${token}` },
    method,
  });
  expect(response.status(), `${call} answered ${response.status()}`).toBeLessThan(400);
  return trusted(await response.json()) as Record<string, unknown>;
};

const journalMcp = async (request: APIRequestContext, token: string | undefined, name: string, data: string) => {
  const response = await request.post("/mcp", {
    data: { id: 1, jsonrpc: "2.0", method: "tools/call", params: { arguments: JSON.parse(dated(data)), name } },
    headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${token}` },
  });
  const reply = await response.json();
  expect(reply.error ?? reply.result?.isError ?? false, JSON.stringify(reply)).toBeFalsy();
  return trusted(JSON.parse(reply.result.content[0].text)) as Record<string, unknown>;
};

const without = (record: Record<string, unknown>, keys: string[]) =>
  Object.fromEntries(Object.entries(record).filter(([key]) => !keys.includes(key)));

Then(
  "the journal MCP tool {string} answers as {string} does, given:",
  async ({ request, tokens }, tool: string, call: string, data: string) => {
    const api = await journalApi(request, tokens.api, call, data);

    expect(await journalMcp(request, tokens.mcp, tool, data)).toEqual(api);
  },
);

Then(
  "the journal MCP tool {string} answers as {string} does but for {string}, given:",
  async ({ request, tokens }, tool: string, call: string, keys: string, data: string) => {
    const api = await journalApi(request, tokens.api, call, data);
    const mcp = await journalMcp(request, tokens.mcp, tool, data);

    expect(without(mcp, keys.split(", "))).toEqual(without(api, keys.split(", ")));
  },
);

Then(
  "the journal API sends the header {string} as {string} for {string}",
  async ({ request, tokens }, name: string, value: string, call: string) => {
    const [method, path] = call.split(" ");
    const response = await request.fetch(path, { headers: { Authorization: `Bearer ${tokens.api}` }, method });

    expect(response.headers()[name.toLowerCase()]).toBe(value);
  },
);

Then("the public page {string} answers 200 without {string}", async ({ request }, path: string, text: string) => {
  const response = await request.get(path);

  expect(response.status()).toBe(200);
  expect(await response.text()).not.toContain(text);
});

When("I open the journal page {string}", async ({ page }, path: string) => {
  await page.goto(dated(path));
});

Then("the journal field at {string} holds {string}", async ({ page }, selector: string, value: string) => {
  await expect(page.locator(dated(selector)).first()).toHaveValue(unescaped(value));
});

When("I remove a tag from the journal entry and add {string}", async ({ page }, tag: string) => {
  const item = entry(page);
  await item.locator(".tag-pick-remove").first().click();
  await item.locator("[data-tag-field-input]").fill(tag);
  await item.locator("[data-tag-field-input]").press("Enter");
});

When("I submit the journal entry's edit with {string}", async ({ page }, body: string) => {
  const navigated = page.waitForNavigation();
  await entry(page)
    .locator("[data-journal-edit-form]")
    .evaluate((form: HTMLFormElement, body) => {
      const area = form.querySelector("textarea");
      if (area) area.value = body;
      form.submit();
    }, body);
  await navigated;
});

When("I accept the journal confirm", async ({ page }) => {
  const navigated = page.waitForNavigation();
  await page.locator("[data-confirm-accept]").click();
  await navigated;
});

Then("the journal address is {string}", async ({ page }, path: string) => {
  await expect.poll(() => here(page)).toBe(dated(path));
});

When("I click {string} in the journal modal", async ({ page }, name: string) => {
  await page.evaluate(() => (document.activeElement as HTMLElement | null)?.blur());
  await page.locator("dialog#journal-write").getByRole("button", { exact: true, name }).click();
});

let raw = { body: undefined as unknown, status: 0 };

Before(() => {
  posted = { location: "", status: 0 };
  olderPages = [];
  scriptless = "";
  editing = "";
  preview = { font: "", html: "" };
  raw = { body: undefined, status: 0 };
});

When(
  "I send the journal API {string} the raw body {string}",
  async ({ request, tokens }, call: string, body: string) => {
    const [method, path] = call.split(" ");
    const response = await request.fetch(path, {
      data: body,
      headers: { Authorization: `Bearer ${tokens.api}`, "Content-Type": "application/json" },
      method,
    });
    raw = { body: await response.json(), status: response.status() };
  },
);

Then("the journal API answers {int} with:", ({}, status: number, json: string) => {
  expect(raw.status).toBe(status);
  expect(raw.body).toMatchObject(JSON.parse(json));
});
