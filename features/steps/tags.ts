import { expect, type Page } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import type postgres from "postgres";
import { Before, Given, Then, When } from "../support/world.ts";

let posted = 0;

Before(() => {
  posted = 0;
});

const cell = (value: string) => {
  const repeated = value.match(/^(\d+) × (.)$/);
  if (repeated) return repeated[2].repeat(Number(repeated[1]));
  return value
    .replace(/^"(.*)"$/s, "$1")
    .replaceAll(/\\u([0-9a-f]{4})/g, (_, code: string) => String.fromCharCode(Number.parseInt(code, 16)));
};

const projectId = async (sql: postgres.Sql, key: string) => {
  const [{ id }] = await sql`SELECT id FROM projects WHERE key = ${key}`;
  return id as number;
};

const projectNamed = async (sql: postgres.Sql, name: string, archived = false) => {
  const [found] = await sql`SELECT id FROM projects WHERE name = ${name}`;
  if (found) return found.id as number;
  const key = `${name.toUpperCase().replaceAll(/[^A-Z0-9]/g, "")}XX`.slice(0, 6);
  const [{ id }] = await sql`
    INSERT INTO projects (name, key, visibility, archived_on)
    VALUES (${name}, ${key}, 'public', ${archived ? new Date() : null}) RETURNING id
  `;
  return id as number;
};

const tagRef = async (sql: postgres.Sql, ref: string, scope: string) => {
  const [name, key] = ref.split("@");
  const owner = key ? await projectId(sql, key) : null;
  const tagScope = key ? "project" : scope;
  const [found] = await sql`
    SELECT id FROM tags WHERE name = ${name} AND scope = ${tagScope} AND project_id IS NOT DISTINCT FROM ${owner}
  `;
  if (found) return { id: found.id as number, scope: tagScope };
  const [{ id }] = await sql`
    INSERT INTO tags (name, color, scope, project_id) VALUES (${name}, 'mk-blue', ${tagScope}, ${owner}) RETURNING id
  `;
  return { id: id as number, scope: tagScope };
};

const expand = async (sql: postgres.Sql, text: string) => {
  let out = text;
  for (const [whole, kind, name] of text.matchAll(/\{(\w+):([^}]+)\}/g)) {
    const id =
      kind === "project"
        ? await projectId(sql, name)
        : ["public", "private"].includes(kind)
          ? (await sql`SELECT id FROM tags WHERE name = ${name} AND scope = ${kind}`)[0].id
          : (await sql`SELECT id FROM tags WHERE name = ${name} AND project_id = ${await projectId(sql, kind)}`)[0].id;
    out = out.replace(whole, String(id));
  }
  return out;
};

const mailAccount = async (sql: postgres.Sql) => {
  const [found] = await sql`SELECT id FROM mail_accounts LIMIT 1`;
  if (found) return found.id as number;
  const [{ id }] = await sql`
    INSERT INTO mail_accounts (provider, name) VALUES ('contact_form', 'Contact form') RETURNING id
  `;
  return id as number;
};

const kinds: Record<string, { join: string; owner: string; scope: string }> = {
  decision: { join: "decision_tags", owner: "decision_id", scope: "private" },
  "journal entry": { join: "journal_entry_tags", owner: "journal_entry_id", scope: "private" },
  message: { join: "mail_thread_tags", owner: "mail_thread_id", scope: "private" },
  post: { join: "post_tags", owner: "post_id", scope: "public" },
  project: { join: "project_tags", owner: "project_id", scope: "public" },
  task: { join: "task_tags", owner: "task_id", scope: "private" },
};

const insertRecord = async (sql: postgres.Sql, kind: string, title: string) => {
  const [state, ...rest] = kind.split(" ");
  const base = ["draft", "published", "archived", "done", "canceled", "dropped"].includes(state)
    ? rest.join(" ")
    : kind;
  const status = base === kind ? "" : state;
  if (base === "post") {
    const [{ id }] = await sql`
      INSERT INTO posts ${sql({
        body: "A post.",
        body_html: "<p>A post.</p>",
        published_at: status === "draft" ? null : new Date(Date.now() - 3_600_000),
        read_time: 1,
        slug: title.toLowerCase().replaceAll(/\W+/g, "-"),
        status: status || "published",
        title,
        updated_at: new Date(Date.now() - 86_400_000),
        webmentions_enabled: false,
        word_count: 2,
      })} RETURNING id
    `;
    return id as number;
  }
  if (base === "project") return projectNamed(sql, title, status === "archived");
  if (base === "task") {
    const closed = ["done", "canceled"].includes(status);
    const [{ id }] = await sql`
      INSERT INTO tasks (title, list, position, status, completed_at)
      VALUES (${title}, 'next', 1, ${status || "open"}, ${closed ? new Date() : null}) RETURNING id
    `;
    return id as number;
  }
  if (base === "journal entry") {
    const [{ id }] = await sql`
      INSERT INTO journal_entries (entry_date, entry_time, body, body_html)
      VALUES ('2026-09-07', '09:00', ${title}, ${`<p>${title}</p>`}) RETURNING id
    `;
    return id as number;
  }
  if (base === "decision") {
    const [{ id }] = await sql`
      INSERT INTO decisions (title, problem, status) VALUES (${title}, 'It came up', ${status || "open"}) RETURNING id
    `;
    return id as number;
  }
  const [{ id }] = await sql`
    INSERT INTO mail_threads (mail_account_id, subject) VALUES (${await mailAccount(sql)}, ${title}) RETURNING id
  `;
  return id as number;
};

const postForm = async (page: Page, action: string, rows: string[][]) => {
  const fields = rows.map(([name, value]) => [name, cell(value)]);
  if (page.url() === "about:blank") await page.goto("/admin/settings/tagging");
  if (!fields.some(([name]) => name === "_csrf_token")) {
    const token = page.locator("input[name='_csrf_token']").first();
    if (await token.count()) fields.unshift(["_csrf_token", await token.inputValue()]);
  }
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
  await navigated;
};

Given("the tag manager holds these tags:", async ({ app }, table: DataTable) => {
  for (const row of table.hashes()) {
    const owner = row.project ? await projectNamed(app.sql, row.project) : null;
    await app.sql`
      INSERT INTO tags ${app.sql({
        color: row.color || "mk-blue",
        description: row.description || null,
        name: row.name,
        project_id: owner,
        scope: owner ? "project" : row.scope || "public",
      })}
    `;
  }
});

Given("the tag manager holds the {word} tags {string}", async ({ app }, scope: string, names: string) => {
  for (const name of names.split(", ")) {
    await app.sql`INSERT INTO tags (name, color, scope) VALUES (${name}, 'mk-blue', ${scope})`;
  }
});

Given(
  "the tag manager holds {int} public filler tags from {string}",
  async ({ app }, count: number, prefix: string) => {
    await app.sql`
    INSERT INTO tags (name, color, scope)
    SELECT ${prefix}::text || lpad(n::text, 3, '0'), 'mk-blue', 'public' FROM generate_series(1, ${count}::int) AS n
  `;
  },
);

Given("the tag manager has the project {string} keyed {string}", async ({ app }, name: string, key: string) => {
  await app.sql`INSERT INTO projects (name, key, visibility) VALUES (${name}, ${key}, 'public')`;
});

Given("these records carry tags for the tag manager:", async ({ app }, table: DataTable) => {
  for (const row of table.hashes()) {
    const kind = kinds[row.kind.replace(/^(draft|published|archived|done|canceled|dropped) /, "")];
    const id = await insertRecord(app.sql, row.kind, cell(row.title));
    for (const ref of (row.tags ?? "").split(", ").filter(Boolean)) {
      const tag = await tagRef(app.sql, ref, kind.scope);
      await app.sql`
        INSERT INTO ${app.sql(kind.join)} ${app.sql({ [kind.owner]: id, tag_id: tag.id, tag_scope: tag.scope })}
      `;
    }
  }
});

Given("{int} tasks for the tag manager carry the tag {string}", async ({ app }, count: number, ref: string) => {
  const tag = await tagRef(app.sql, ref, "private");
  await app.sql`
    WITH made AS (
      INSERT INTO tasks (title, list, position)
      SELECT 'Chore ' || n, 'next', n FROM generate_series(1, ${count}::int) AS n RETURNING id
    )
    INSERT INTO task_tags (task_id, tag_id, tag_scope) SELECT id, ${tag.id}, ${tag.scope} FROM made
  `;
});

Given("the tag manager has a task rule {string} tagged {string}", async ({ app }, pattern: string, refs: string) => {
  const [{ id }] = await app.sql`
    INSERT INTO task_rules (pattern, provider) VALUES (${pattern}, 'github') RETURNING id
  `;
  for (const ref of refs.split(", ").filter(Boolean)) {
    const tag = await tagRef(app.sql, ref, "private");
    await app.sql`INSERT INTO task_rule_tags (task_rule_id, tag_id, tag_scope) VALUES (${id}, ${tag.id}, ${tag.scope})`;
  }
});

Given(
  "the tag manager's task rule {string} files into the project {string}",
  async ({ app }, pattern: string, key: string) => {
    await app.sql`
      INSERT INTO task_rule_projects (task_rule_id, project_id)
      SELECT id, ${await projectId(app.sql, key)} FROM task_rules WHERE pattern = ${pattern}
    `;
  },
);

When("I post to the tag manager at {string}", async ({ app, page }, action: string) => {
  await postForm(page, await expand(app.sql, action), []);
});

When("I post to the tag manager at {string} with:", async ({ app, page }, action: string, table: DataTable) => {
  await postForm(page, await expand(app.sql, action), table.raw());
});

Then("the tag manager answers {int}", ({}, status: number) => {
  expect(posted).toBe(status);
});

Then("the tag manager lands on {string}", ({ page }, path: string) => {
  const url = new URL(page.url());

  expect(`${url.pathname}${url.search}${url.hash}`).toBe(path);
});

Then("the tag manager sends {string} to {string}", async ({ page }, path: string, location: string) => {
  const response = await page.request.get(path, { maxRedirects: 0 });

  expect([response.status(), response.headers().location]).toEqual([302, location]);
});

Then("the tag manager shows {string}", async ({ app, page }, css: string) => {
  await expect(page.locator(await expand(app.sql, css)).first()).toBeAttached();
});

Then("the tag manager shows {string} reading {string}", async ({ app, page }, css: string, text: string) => {
  await expect(
    page
      .locator(await expand(app.sql, css))
      .filter({ hasText: text })
      .first(),
  ).toBeAttached();
});

Then("the tag manager shows {string} reading exactly {string}", async ({ app, page }, css: string, text: string) => {
  await expect(page.locator(await expand(app.sql, css)).first()).toHaveText(text, { useInnerText: false });
});

Then("the tag manager shows no {string}", async ({ app, page }, css: string) => {
  await expect(page.locator(await expand(app.sql, css))).toHaveCount(0);
});

Then("the tag manager shows no {string} reading {string}", async ({ app, page }, css: string, text: string) => {
  await expect(page.locator(await expand(app.sql, css)).filter({ hasText: text })).toHaveCount(0);
});

Then("the tag manager lists {string} as {string}", async ({ app, page }, css: string, texts: string) => {
  await expect(page.locator(await expand(app.sql, css))).toHaveText(texts ? texts.split(", ") : []);
});

Then(
  "the tag manager lists the {word} of {string} as {string}",
  async ({ app, page }, attribute: string, css: string, values: string) => {
    const found = await page
      .locator(await expand(app.sql, css))
      .evaluateAll((elements, name) => elements.map((element) => element.getAttribute(name) ?? "none"), attribute);

    expect(found.join(", ")).toBe(values);
  },
);

Then(
  "the tag manager's {string} has the {word} {string}",
  async ({ app, page }, css: string, attribute: string, value: string) => {
    await expect(page.locator(await expand(app.sql, css)).first()).toHaveAttribute(attribute, value);
  },
);

Then("the tag manager's {string} has no {word}", async ({ app, page }, css: string, attribute: string) => {
  await expect(page.locator(await expand(app.sql, css)).first()).not.toHaveAttribute(attribute);
});

Then("the tag manager's {string} holds {string}", async ({ app, page }, css: string, value: string) => {
  await expect(page.locator(await expand(app.sql, css)).first()).toHaveValue(value);
});

Then("the tag manager's {string} is enabled", async ({ app, page }, css: string) => {
  await expect(page.locator(await expand(app.sql, css)).first()).toBeEnabled();
});

Then("the tag manager's page source lacks {string}", async ({ page }, text: string) => {
  expect(await page.content()).not.toContain(text);
});

Then("the tag summary's {string} card lists {string}", async ({ page }, kind: string, titles: string) => {
  const card = page.locator(".card").filter({ has: page.getByText(kind, { exact: true }) });

  await expect(card.locator(".li-title")).toHaveText(titles.split(" | "));
});

Then("the tag summary's {string} card lists {int} items", async ({ page }, kind: string, count: number) => {
  const card = page.locator(".card").filter({ has: page.getByText(kind, { exact: true }) });

  await expect(card.locator(".li-title")).toHaveCount(count);
});

Then(
  "the tag summary's {string} card shows {string} reading {string}",
  async ({ page }, kind: string, css: string, text: string) => {
    const card = page.locator(".card").filter({ has: page.getByText(kind, { exact: true }) });

    await expect(card.locator(css).filter({ hasText: text }).first()).toBeAttached();
  },
);

Then(
  "the tag summary's {string} card marks {string} as {string}",
  async ({ page }, kind: string, title: string, status: string) => {
    const card = page.locator(".card").filter({ has: page.getByText(kind, { exact: true }) });

    await expect(card.locator(".li").filter({ hasText: title }).filter({ hasText: status }).first()).toBeAttached();
  },
);

Then("the tag summary's {string} card shows no {string}", async ({ page }, kind: string, css: string) => {
  const card = page.locator(".card").filter({ has: page.getByText(kind, { exact: true }) });

  await expect(card.locator(css)).toHaveCount(0);
});

Then("the tag summary has no {string} card", async ({ page }, kind: string) => {
  await expect(page.locator(".card").filter({ has: page.getByText(kind, { exact: true }) })).toHaveCount(0);
});

When("I open the tag editor for {string}", async ({ page }, name: string) => {
  await page
    .locator(".tag-row")
    .filter({ hasText: `#${name}` })
    .locator(".tag-pen")
    .click();
});

When("I fill the tag editor's name with {string}", async ({ page }, name: string) => {
  await page.locator(".tag-editor:visible input[type='text'][name='tag[name]']").fill(name);
});

When("I click {string} in the tag editor", async ({ page }, name: string) => {
  await page
    .locator(".tag-editor:visible")
    .getByRole("button", { exact: true, name })
    .or(page.locator(".tag-editor:visible").getByRole("link", { exact: true, name }))
    .click();
});

When("I click the {word} swatch in the tag editor", async ({ page }, color: string) => {
  await page.locator(`.tag-editor:visible .swatch.${color}`).click();
});

When("I type {string} in the tag filter", async ({ page }, query: string) => {
  const field = page.locator("input[name='q']");
  await field.fill(query);
  await field.dispatchEvent("change");
});

Then("the open tag editor's name holds {string}", async ({ page }, name: string) => {
  const field = page.locator(".tag-editor:visible input[type='text'][name='tag[name]']");
  await expect(field).toHaveCount(1);
  await expect(field).toHaveValue(name);
});

Then("the tag manager shows {string} visibly", async ({ page }, css: string) => {
  await expect(page.locator(css).first()).toBeVisible();
});

Then("the tag manager shows {string} visibly, reading {string}", async ({ page }, css: string, text: string) => {
  await expect(page.locator(css).filter({ hasText: text }).first()).toBeVisible();
});

Then("the tag manager shows no visible {string}", async ({ page }, css: string) => {
  await expect(page.locator(`${css}:visible`)).toHaveCount(0);
});

When("I type {string} in the tag field {string}", async ({ page }, text: string, css: string) => {
  await page.locator(css).first().pressSequentially(text);
});

When("I press {string} in the tag field {string}", async ({ page }, key: string, css: string) => {
  await page.locator(css).first().press(key);
});

When("I fill {string} beside the tag field with {string}", async ({ page }, css: string, value: string) => {
  await page.locator(css).first().fill(value);
});

When("I click {string} beside the tag field", async ({ page }, css: string) => {
  await page.locator(css).first().click();
});

Then("the tag field chips read {string}", async ({ page }, chips: string) => {
  await expect(page.locator(".tag-pick-chip")).toHaveText(chips ? chips.split(", ") : []);
});

Then("the tag field suggests {string}", async ({ page }, results: string) => {
  await expect(page.locator(".tag-pick-result")).toHaveText(results ? results.split(", ") : []);
});

When("the tag field's page swaps its main and hears two morphs", async ({ page }) => {
  await page.evaluate(() => {
    const main = document.querySelector("main");
    if (main) main.replaceWith(main.cloneNode(true));
    document.dispatchEvent(new Event("admin:morphed"));
    document.dispatchEvent(new Event("admin:morphed"));
  });
});

When("the tag field's page hears two morphs", async ({ page }) => {
  await page.evaluate(() => {
    document.dispatchEvent(new Event("admin:morphed"));
    document.dispatchEvent(new Event("admin:morphed"));
  });
});

When("I open the tag field in the task drawer of {string}", async ({ page }, title: string) => {
  await page.goto("/admin/tasks?filter=next");
  await page.locator(".task-title", { hasText: title }).click();
  await page.locator("dialog#task-panel[open]").getByRole("link", { exact: true, name: "Edit" }).click();
  await expect(page.locator("dialog#task-panel[open] [data-task-edit] [data-tag-field-input]")).toBeVisible();
});

Then("{int} tag editor(s) is/are open", async ({ page }, count: number) => {
  await expect(page.locator(".tag-editor:visible")).toHaveCount(count);
});
