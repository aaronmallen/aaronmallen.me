import { type APIRequestContext, expect, type Page } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import type postgres from "postgres";
import { insertPost } from "../support/rows.ts";
import { Before, Given, Then, When } from "../support/world.ts";

let posted = 0;

Before(() => {
  posted = 0;
});

const decisionId = async (sql: postgres.Sql, title: string) => {
  const [{ id }] = await sql`SELECT id FROM decisions WHERE title = ${title} ORDER BY id DESC LIMIT 1`;
  return id;
};

const cell = (value: string) => {
  const repeated = value.match(/^(\d+) × (.)$/);
  if (repeated) return repeated[2].repeat(Number(repeated[1]));
  return value.replace(/^"(.*)"$/, "$1");
};

const postForm = async (page: Page, action: string, rows: string[][]) => {
  const token = page.locator("input[name='_csrf_token']").first();
  if (!(await token.count())) await page.goto("/admin/decisions/new");
  const fields = [["_csrf_token", await token.inputValue()], ...rows.map(([name, value]) => [name, cell(value)])];
  const path = new URL(action, page.url()).pathname;
  const response = page.waitForResponse(
    (sent) => sent.request().method() === "POST" && new URL(sent.url()).pathname === path,
  );
  const committed = page.waitForEvent("framenavigated", { predicate: (frame) => frame === page.mainFrame() });
  await page.evaluate(
    ({ action, fields }) => {
      const form = document.createElement("form");
      form.method = "post";
      form.action = action;
      for (const [name, value] of fields) {
        const input = document.createElement("input");
        input.type = "hidden";
        input.name = name;
        input.value = value;
        form.append(input);
      }
      document.body.append(form);
      form.submit();
    },
    { action, fields },
  );
  posted = (await response).status();
  await committed;
  await page.waitForLoadState("domcontentloaded");
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

const callApi = async (request: APIRequestContext, token: string | undefined, call: string, data?: string) => {
  const [method, path] = call.split(" ");
  const response = await request.fetch(path, {
    data: method === "GET" || data === undefined ? undefined : JSON.parse(data),
    headers: { Authorization: `Bearer ${token}` },
    method,
  });
  const text = await response.text();
  expect(response.ok(), text).toBe(true);
  return trusted(JSON.parse(text)) as Record<string, unknown>;
};

const callMcp = async (request: APIRequestContext, token: string | undefined, name: string, data: string) => {
  const response = await request.post("/mcp", {
    data: { id: 1, jsonrpc: "2.0", method: "tools/call", params: { arguments: JSON.parse(data), name } },
    headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${token}` },
  });
  const reply = await response.json();
  return trusted(JSON.parse(reply.result.content[0].text)) as Record<string, unknown>;
};

const withoutStamps = ({ created_at, id, updated_at, ...rest }: Record<string, unknown>) => rest;

Given("a decision {string} with the problem {string}", async ({ app }, title: string, problem: string) => {
  await app.sql`INSERT INTO decisions ${app.sql({ problem, title })}`;
});

Given(
  "a(n) {word} decision {string} opened {int} hour(s) ago",
  async ({ app }, status: string, title: string, hours: number) => {
    await app.sql`
      INSERT INTO decisions (title, problem, status, created_at)
      VALUES (${title}, 'It came up', ${status}, now() - make_interval(hours => ${hours}))
    `;
  },
);

Given("the decision {string} has the option {string}", async ({ app }, title: string, option: string) => {
  const id = await decisionId(app.sql, title);
  await app.sql`INSERT INTO decision_options ${app.sql({ decision_id: id, title: option })}`;
});

Given(
  "the decision {string} has the option {string} with the body {string}",
  async ({ app }, title: string, option: string, body: string) => {
    const id = await decisionId(app.sql, title);
    await app.sql`INSERT INTO decision_options ${app.sql({ body, decision_id: id, title: option })}`;
  },
);

Given("the decision {string} carries the tag(s) {string}", async ({ app }, title: string, names: string) => {
  const id = await decisionId(app.sql, title);
  for (const name of names.split(/,\s*/)) {
    let [tag] = await app.sql`SELECT id FROM tags WHERE name = ${name} AND scope = 'private'`;
    tag ??= (
      await app.sql`INSERT INTO tags (name, color, scope) VALUES (${name}, 'mk-blue', 'private') RETURNING id`
    )[0];
    await app.sql`INSERT INTO decision_tags (decision_id, tag_id) VALUES (${id}, ${tag.id})`;
  }
});

Given("the decision {string} has the comment {string}", async ({ app }, title: string, body: string) => {
  const id = await decisionId(app.sql, title);
  await app.sql`INSERT INTO decision_comments ${app.sql({ body, decision_id: id })}`;
});

Given("a published post {string} linked to the decision {string}", async ({ app }, post: string, title: string) => {
  await insertPost(app.sql, { publishedAt: new Date(Date.now() - 3_600_000), status: "published", title: post });
  const id = await decisionId(app.sql, title);
  await app.sql`
    INSERT INTO record_links (left_kind, left_id, right_kind, right_id)
    SELECT 'post', id, 'decision', ${id} FROM posts WHERE title = ${post}
  `;
});

When("I post to the decisions admin at {string}", async ({ page }, action: string) => {
  await postForm(page, action, []);
});

When("I post to the decisions admin at {string} with:", async ({ page }, action: string, table: DataTable) => {
  await postForm(page, action, table.raw());
});

Then("the decisions admin answers {int}", ({}, status: number) => {
  expect(posted).toBe(status);
});

Then("the decisions admin lands on {string}", ({ page }, path: string) => {
  const url = new URL(page.url());

  expect(`${url.pathname}${url.search}`).toBe(path);
});

Then("the decisions admin shows {string}", async ({ page }, css: string) => {
  await expect(page.locator(css).first()).toBeAttached();
});

Then("the decisions admin shows {string} reading {string}", async ({ page }, css: string, text: string) => {
  await expect(page.locator(css).filter({ hasText: text }).first()).toBeAttached();
});

Then("the decisions admin shows no {string}", async ({ page }, css: string) => {
  await expect(page.locator(css)).toHaveCount(0);
});

Then("the decisions admin lists {string} as {string}", async ({ page }, css: string, texts: string) => {
  await expect(page.locator(css)).toHaveText(texts.split(", "));
});

Then("the decisions admin lists {string} holding {string}", async ({ page }, css: string, texts: string) => {
  const escaped = texts.split(", ").map((text) => new RegExp(text.replaceAll(/[.*+?^${}()|[\]\\]/g, "\\$&")));

  await expect(page.locator(css)).toHaveText(escaped);
});

Then(
  "the decisions admin lists the {word} of {string} as {string}",
  async ({ page }, attribute: string, css: string, values: string) => {
    const found = await page
      .locator(css)
      .evaluateAll((elements, name) => elements.map((element) => element.getAttribute(name) ?? "none"), attribute);

    expect(found.join(", ")).toBe(values);
  },
);

Then(
  "the decisions admin's {string} has the {word} {string}",
  async ({ page }, css: string, attribute: string, value: string) => {
    await expect(page.locator(css).first()).toHaveAttribute(attribute, value);
  },
);

Then("the decisions admin's {string} holds {string}", async ({ page }, css: string, value: string) => {
  await expect(page.locator(css).first()).toHaveValue(value);
});

When("I watch the decisions clipboard", async ({ page }) => {
  await page.evaluate(() => {
    const copied: string[] = [];
    Object.assign(window, { copiedKeys: copied });
    Object.defineProperty(navigator, "clipboard", {
      value: { writeText: (text: string) => Promise.resolve(copied.push(text)) },
    });
  });
});

When("I click the decision key in {string}", async ({ page }, css: string) => {
  await page.locator(css).locator(".record-key").first().click();
});

Then("the decisions clipboard holds {string}", async ({ page }, key: string) => {
  await expect
    .poll(() => page.evaluate(() => (window as unknown as { copiedKeys: string[] }).copiedKeys))
    .toEqual([key]);
});

When("I fill the decision field {string} with {string}", async ({ page }, label: string, value: string) => {
  await page.getByRole("textbox", { exact: true, name: label }).first().fill(value);
});

When("I rename the decision option {string} to {string}", async ({ page }, title: string, renamed: string) => {
  const option = page.locator(".decision-option", { hasText: title });
  await option.hover();
  await option.locator("summary", { hasText: "Edit" }).click();
  await option.getByRole("textbox", { exact: true, name: "Option" }).fill(renamed);
  await option.getByRole("button", { exact: true, name: "Save option" }).click();
});

Then("the decision edit note dialog asks what changed", async ({ page }) => {
  await expect(page.locator("dialog[data-edit-note-dialog][open]").getByLabel("What changed and why")).toBeVisible();
});

When("I note {string} in the decision edit note dialog", async ({ page }, note: string) => {
  const dialog = page.locator("dialog[data-edit-note-dialog][open]");
  await dialog.getByLabel("What changed and why").fill(note);
  await dialog.getByRole("button", { exact: true, name: "Save" }).click();
});

Then(
  "the decision MCP tool {string} answers as {string} does, given:",
  async ({ request, tokens }, tool: string, call: string, data: string) => {
    const api = await callApi(request, tokens.api, call, data);

    expect(await callMcp(request, tokens.mcp, tool, data)).toEqual(api);
  },
);

Then(
  "the decision MCP tool {string} answers as {string} does but for its stamps, given:",
  async ({ request, tokens }, tool: string, call: string, data: string) => {
    const api = await callApi(request, tokens.api, call, data);

    expect(withoutStamps(await callMcp(request, tokens.mcp, tool, data))).toEqual(withoutStamps(api));
  },
);

Then(
  "the decisions API's {string} for {string} falls within a minute of now",
  async ({ request, tokens }, path: string, call: string) => {
    const answer = await callApi(request, tokens.api, call);
    const value = path.split(".").reduce<unknown>((inner, key) => (inner as Record<string, unknown>)?.[key], answer);

    expect(Math.abs(Date.parse(String(value)) - Date.now())).toBeLessThan(60_000);
  },
);
