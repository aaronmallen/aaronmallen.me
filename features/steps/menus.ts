import { expect, type Page } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { Before, Given, Then, When } from "../support/world.ts";

const zone = "America/Chicago";
const today = `(now() AT TIME ZONE '${zone}')::date`;
const contactForm = `
  INSERT INTO mail_accounts (provider, name)
  SELECT 'contact_form', 'Contact form' WHERE NOT EXISTS (SELECT 1 FROM mail_accounts WHERE provider = 'contact_form');
`;
const message = (subject: string) => `
  WITH thread AS (
    INSERT INTO mail_threads (mail_account_id, subject)
    SELECT id, '${subject}' FROM mail_accounts WHERE provider = 'contact_form' RETURNING id
  )
  INSERT INTO mail_messages (mail_thread_id, subject, body, reply_to)
  SELECT id, '${subject}', 'Hello.', 'ada@example.com' FROM thread;
`;
const task = (title: string, extra = "") => `
  INSERT INTO tasks (title, list, position${extra ? ", carried_count" : ""})
  VALUES ('${title}', 'next', (SELECT coalesce(max(position), 0) + 1 FROM tasks)${extra ? `, ${extra}` : ""});
`;
const draft = (title: string, updated = "now()") => `
  INSERT INTO posts (title, slug, body, body_html, webmentions_enabled, read_time, word_count, updated_at)
  VALUES ('${title}', '${title.toLowerCase().replaceAll(/\W+/g, "-")}', 'A draft.', '<p>A draft.</p>', false, 1, 2,
          ${updated});
`;
const published = `
  INSERT INTO posts (title, slug, status, published_at, body, body_html, webmentions_enabled, read_time, word_count)
  VALUES ('Target', 'target', 'published', now() - interval '1 day', 'A post.', '<p>A post.</p>', true, 1, 2);
`;
const webmention = (author: string) => `
  INSERT INTO webmentions (post_id, source_url, author_name, author_url, type, excerpt)
  SELECT id, 'https://${author.toLowerCase()}.example/note', '${author}', 'https://${author.toLowerCase()}.example/',
          'mention', 'A note from ${author}.'
  FROM posts WHERE slug = 'target';
`;
const tag = (name: string, scope = "public") =>
  `INSERT INTO tags (name, color, scope) VALUES ('${name}', 'mk-blue', '${scope}');`;
const rule = (name: string) => `
  ${tag(name, "private")}
  INSERT INTO task_rules (pattern, provider) VALUES ('aaronmallen/*', 'github');
  INSERT INTO task_rule_tags (task_rule_id, tag_id) SELECT r.id, t.id FROM task_rules r, tags t WHERE t.name = '${name}';
`;
const project = `INSERT INTO projects (name, visibility, key) VALUES ('Hanami', 'public', 'HAN');`;

const seeds: Record<string, string> = {
  "a carried task": task("Carried task", "4"),
  "a client": `
    INSERT INTO oauth_clients (client_id, client_name, redirect_uris, grant_types, response_types, visitor_hash)
    VALUES ('desk', 'Desk', '{http://127.0.0.1/callback}', '{authorization_code}', '{code}', repeat('a', 64));
    INSERT INTO oauth_tokens (oauth_client_id, type, token_digest, expires_at)
    SELECT id, 'access', 'digest', now() + interval '1 hour' FROM oauth_clients;
  `,
  "a commit today": `
    INSERT INTO commits (sha, repo, branch, message, commit_date, commit_time)
    VALUES (repeat('ab', 20), 'aaronmallen/blog', 'main', 'add the view', ${today}, '09:00');
  `,
  "a calendar event today": `
    INSERT INTO calendars (account, google_id, name, writable) VALUES ('me@example.com', 'me@example.com', 'Aaron', true);
    INSERT INTO calendar_events (calendar_id, google_id, title, starts_on, ends_on, starts_at, ends_at)
    SELECT id, 'coffee', 'Coffee', ${today}, ${today}, (${today} + time '09:00') AT TIME ZONE '${zone}',
            (${today} + time '10:00') AT TIME ZONE '${zone}'
    FROM calendars;
  `,
  "a decision": `INSERT INTO decisions (title, problem) VALUES ('Pick a queue', 'It came up');`,
  "a decision comment": `
    INSERT INTO decisions (title, problem) VALUES ('Pick a queue', 'It came up');
    INSERT INTO decision_comments (decision_id, body) SELECT id, 'Go with A' FROM decisions;
  `,
  "a decision option": `
    INSERT INTO decisions (title, problem) VALUES ('Pick a queue', 'It came up');
    INSERT INTO decision_options (decision_id, title) SELECT id, 'Sidekiq' FROM decisions;
  `,
  "a file": `
    INSERT INTO short_codes (code) VALUES ('a-talk');
    INSERT INTO share_group_files (key, filename, content_type, byte_size, short_code_id)
    SELECT repeat('a', 32), 'talk.txt', 'text/plain', 5, id FROM short_codes;
  `,
  "a journal entry": `
    INSERT INTO journal_entries (entry_date, entry_time, body, body_html)
    VALUES (${today}, '09:00', 'shipped it', '<p>shipped it</p>');
  `,
  "a link": `
    INSERT INTO short_codes (code) VALUES ('a-talk');
    INSERT INTO short_links (short_code_id, destination, title) SELECT id, 'https://example.com/talk', 'A talk' FROM short_codes;
  `,
  "a note": `INSERT INTO notes (title) VALUES ('Plan');`,
  "a note in a folder": `
    INSERT INTO note_folders (name) VALUES ('work');
    INSERT INTO notes (title, folder_id) SELECT 'Plan', id FROM note_folders;
  `,
  "a person": `INSERT INTO people (name, key) VALUES ('Matz', 'matz');`,
  "a project": project,
  "a queued social post": `
    INSERT INTO social_posts (targets, status, posted_at) VALUES ('{mastodon,bluesky}', 'scheduled', now() + interval '1 day');
    INSERT INTO social_post_parts (social_post_id, position, body) SELECT id, 1, 'Out soon.' FROM social_posts;
  `,
  "a sprint in two days": `
    INSERT INTO sprints (id, sprint_date) VALUES (90, ${today} + 2) ON CONFLICT DO NOTHING;
    INSERT INTO tasks (title, sprint_id, position) VALUES ('Plan ahead', 90, 1);
  `,
  "a tag": tag("ruby"),
  "a task": task("Write the brief"),
  "a task comment": `${task("Write the brief")} INSERT INTO task_comments (task_id, body) SELECT id, 'First try' FROM tasks;`,
  "a task rule": rule("ruby"),
  "a task rule for projects": rule("projects"),
  "a token": `INSERT INTO api_tokens (name, token_digest) VALUES ('Terminal', 'digest');`,
  "a work entry": `INSERT INTO work_entries (org, role, from_year, position) VALUES ('Rackspace', 'Engineer', 2018, 1);`,
  "a work session": `
    ${task("Write the brief")}
    INSERT INTO work_sessions (task_id, started_at, ended_at) SELECT id, now() - interval '1 hour', now() FROM tasks;
  `,
  "an old draft": draft("Old draft", "now() - interval '60 days'"),
  "nothing more": "",
  "two drafts": `${draft("one draft")} ${draft("two draft")}`,
  "two messages": `${contactForm} ${message("Newer")} ${message("Older")}`,
  "two tasks": `${task("first")} ${task("second")}`,
  "two webmentions": `${published} ${webmention("Ada")} ${webmention("Grace")}`,
};

Given("the menu screens hold {string}", async ({ app }, name: string) => {
  if (!(name in seeds)) throw new Error(`no menu seed ${name}`);
  if (seeds[name]) await app.sql.unsafe(seeds[name]).simple();
});

When("a {word} arrives for bulk select", async ({ app }, kind: string) => {
  await app.sql.unsafe(kind === "task" ? task("arrived") : `${contactForm} ${message("Arrived")}`).simple();
});

const norm = (text: string | null) => (text ?? "").replace(/\s+/g, " ").trim();
const list = (text: string) => (text ? text.split(", ") : []);
const escaped = (text: string) => text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const exact = (text: string) => new RegExp(`^\\s*${escaped(text)}\\s*$`);
const lines = (text: string) => text.replaceAll("\\n", "\n");
const menu = (page: Page) => page.locator("[data-context-menu]");
const labels = async (page: Page) => (await page.locator(".ctx-label").allTextContents()).map(norm);
const item = (page: Page, label: string) =>
  menu(page)
    .locator(".ctx-item")
    .filter({ has: page.locator(".ctx-label", { hasText: exact(label) }) })
    .first();
const box = async (page: Page, selector = "[data-context-menu]") =>
  page
    .locator(selector)
    .first()
    .evaluate((node) => JSON.parse(JSON.stringify(node.getBoundingClientRect())));

const fields = (form: ReturnType<Page["locator"]>) =>
  form
    .locator("input")
    .evaluateAll((inputs) => inputs.map((input) => [input.getAttribute("name"), (input as HTMLInputElement).value]));

const holdsFields = async (form: ReturnType<Page["locator"]>, table: DataTable) => {
  const found = (await fields(form)).map((pair) => pair.join("="));

  for (const [name, value] of table.raw()) expect(found).toContain(`${name}=${value}`);
};

const formFor = (page: Page, label: string, within = page.locator("body")) =>
  within
    .locator(".ctx-item")
    .filter({ hasText: exact(label) })
    .first()
    .locator("xpath=ancestor::form[1]");

const submenu = (page: Page, label: string) =>
  page.locator("[aria-haspopup]", { hasText: label }).first().locator("xpath=following-sibling::*[@role='menu'][1]");

Then("the menu head reads {string}", async ({ page }, text: string) => {
  await expect(page.locator("[data-context-menu] > .ctx-head").first()).toHaveText(exact(text));
});

Then("the menu head holds {string}", async ({ page }, text: string) => {
  await expect(page.locator("[data-context-menu] > .ctx-head").first()).toContainText(text);
});

Then("the menu items read {string}", async ({ page }, items: string) => {
  await expect.poll(async () => (await labels(page)).join(", ")).toBe(items);
});

Then("the menu items include {string}", async ({ page }, items: string) => {
  await expect(page.locator(".ctx-label").first()).toBeAttached();
  const found = await labels(page);

  for (const label of list(items)) expect(found).toContain(label);
});

Then("the menu items leave out {string}", async ({ page }, items: string) => {
  await expect(page.locator(".ctx-label").first()).toBeAttached();
  const found = await labels(page);

  for (const label of list(items)) expect(found).not.toContain(label);
});

const copied = (page: Page, label: string) =>
  page
    .locator("[data-copy]")
    .filter({ has: page.locator(".ctx-label", { hasText: exact(label) }) })
    .first()
    .getAttribute("data-copy");

Then("the menu copies {string} as {string}", async ({ page }, label: string, value: string) => {
  expect(await copied(page, label)).toBe(lines(value));
});

Then("the menu copies {string} ending with {string}", async ({ page }, label: string, value: string) => {
  expect(await copied(page, label)).toMatch(new RegExp(`${escaped(value)}$`));
});

Then("every menu form returns to {string}", async ({ page }, path: string) => {
  const found = await page
    .locator("[data-context-menu] form")
    .evaluateAll((forms) =>
      forms.map((form) => (form.querySelector("input[name=return_to]") as HTMLInputElement | null)?.value ?? null),
    );

  expect(found.length).toBeGreaterThan(0);
  expect([...new Set(found)]).toEqual([path]);
});

Then("a menu form {string} holds the fields:", async ({ page }, selector: string, table: DataTable) => {
  const all = await Promise.all((await page.locator(selector).all()).map((form) => fields(form)));
  const wanted = table.raw().map((pair) => pair.join("="));

  expect(all.some((found) => wanted.every((pair) => found.map((it) => it.join("=")).includes(pair)))).toBe(true);
});

Then("the menu form {string} holds only the fields:", async ({ page }, selector: string, table: DataTable) => {
  const found = (await fields(page.locator(selector).first())).filter(([name]) => name !== "_csrf_token");

  expect(found.map((pair) => pair.join("=")).sort()).toEqual(
    table
      .raw()
      .map((pair) => pair.join("="))
      .sort(),
  );
});

Then("the menu form for {string} holds the fields:", async ({ page }, label: string, table: DataTable) => {
  await holdsFields(formFor(page, label), table);
});

Then(
  "the menu form for {string} under {string} holds the fields:",
  async ({ page }, label: string, parent: string, table: DataTable) => {
    await holdsFields(formFor(page, label, submenu(page, parent)), table);
  },
);

Then("the {string} submenu leaves out {string}", async ({ page }, parent: string, text: string) => {
  expect(await submenu(page, parent).textContent()).not.toContain(text);
});

When("I visit the admin calendar {int} day(s) from today", async ({ app, page }, days: number) => {
  const [{ day }] = await app.sql`SELECT to_char(${app.sql.unsafe(today)} + ${days}::int, 'YYYY-MM-DD') AS day`;
  await page.goto(`/admin/calendar?day=${day}`);
});

When("I set {string} to the date {int} day(s) from today", async ({ app, page }, label: string, days: number) => {
  const [{ day }] = await app.sql`SELECT to_char(${app.sql.unsafe(today)} + ${days}::int, 'YYYY-MM-DD') AS day`;
  await page.getByLabel(label, { exact: true }).fill(day);
});

const keep = (page: Page) => page.evaluate(() => Object.assign(window, { kept: true }));

When("I keep the row page", async ({ page }) => {
  await keep(page);
});

When("I open the row menu on {string}", async ({ page }, selector: string) => {
  const target = page.locator(selector).first();
  await target.scrollIntoViewIfNeeded();
  const found = await target.boundingBox();
  await keep(page);
  await target.click({ button: "right", position: { x: 2, y: (found?.height ?? 4) / 2 } });
  await expect(menu(page)).toBeVisible();
});

When(
  "I right-click the {word} row whose menu matches {string} at {string}",
  async ({ page }, which: string, pattern: string, target: string) => {
    const index = await page.evaluate(
      ({ pattern, picked }) => {
        const rows = [...document.querySelectorAll<HTMLElement>("[data-menu]")];
        const found = rows.findIndex(
          (row) =>
            new RegExp(pattern).test(row.dataset.menu ?? "") &&
            (!picked || row.querySelector("input[name='ids[]']:checked")),
        );
        const closed = rows[found]?.closest("details:not([open])");
        if (closed) closed.setAttribute("open", "");
        return found;
      },
      { pattern, picked: which === "picked" },
    );
    expect(index).toBeGreaterThanOrEqual(0);
    const row = page.locator("[data-menu]").nth(index);
    const spot = target ? row.locator(target).first() : row;
    await spot.scrollIntoViewIfNeeded();
    await spot.click({ button: "right" });
    await expect(menu(page).locator(".ctx-item").first()).toBeVisible();
  },
);

When("I tick every row box", async ({ page }) => {
  const toggle = page.locator("button[data-bulk-toggle][aria-pressed='false']");
  if (await toggle.isVisible()) await toggle.click();
  const boxes = page.locator("input[name='ids[]']:visible");
  await expect(boxes.first()).toBeVisible();
  for (const one of await boxes.all()) await one.check();
});

When("I tick the {string} rows holding {string}", async ({ page }, row: string, texts: string) => {
  for (const text of list(texts)) await page.locator(row, { hasText: text }).locator("input[name='ids[]']").check();
});

When("I untick the {string} rows holding {string}", async ({ page }, row: string, texts: string) => {
  for (const text of list(texts)) await page.locator(row, { hasText: text }).locator("input[name='ids[]']").uncheck();
});

Then("no row box is ticked", async ({ page }) => {
  await expect(page.locator("input[name='ids[]']:checked")).toHaveCount(0);
});

When("I pick {string} in the row menu", async ({ page }, label: string) => {
  await item(page, label).click();
});

When("I pick {string} under {string} in the row menu", async ({ page }, label: string, parent: string) => {
  await submenu(page, parent)
    .locator(".ctx-item")
    .filter({ hasText: exact(label) })
    .first()
    .click();
});

When("I point at {string} in the row menu", async ({ page }, label: string) => {
  await item(page, label).hover();
});

Then("the row menu offers {string}", async ({ page }, label: string) => {
  await expect(item(page, label)).toBeVisible();
});

Then("the row menu is shut", async ({ page }) => {
  await expect(menu(page)).toHaveCount(0);
});

Then("the row menu holds {string}", async ({ page }, selector: string) => {
  await expect(menu(page).locator(selector).first()).toBeVisible();
});

Then("the row menu does not mention {string}", async ({ page }, text: string) => {
  await expect(menu(page)).not.toContainText(text);
});

Then("the row page stayed", async ({ page }) => {
  await expect.poll(() => page.evaluate(() => document.documentElement.dataset.fetch ?? null)).toBeNull();
  await expect.poll(() => page.evaluate(() => (window as unknown as { kept?: boolean }).kept ?? false)).toBe(true);
});

Then("the row page loaded again", async ({ page }) => {
  await expect.poll(() => page.evaluate(() => (window as unknown as { kept?: boolean }).kept ?? false)).toBe(false);
});

Then("a row toast says {string}", async ({ page }, text: string) => {
  await expect(page.locator(".toast:not(.toast-failed)", { hasText: text }).first()).toBeVisible();
});

Then("a failed row toast says {string}", async ({ page }, text: string) => {
  await expect(page.locator(".toast-failed", { hasText: text }).first()).toBeVisible();
});

When("I watch the row menu clipboard", async ({ page }) => {
  await page.evaluate(() => {
    const copiedKeys: string[] = [];
    Object.assign(window, { copiedKeys });
    Object.defineProperty(navigator, "clipboard", {
      configurable: true,
      value: { writeText: (text: string) => Promise.resolve(copiedKeys.push(text)) },
    });
  });
});

Then("the row menu clipboard holds {string}", async ({ page }, text: string) => {
  await expect
    .poll(() => page.evaluate(() => (window as unknown as { copiedKeys: string[] }).copiedKeys))
    .toEqual([text]);
});

When("I watch the context menu events", async ({ page }) => {
  await page.evaluate(() => {
    const prevented: boolean[] = [];
    Object.assign(window, { pointer: [], prevented });
    window.addEventListener("contextmenu", (event) => {
      prevented.push(event.defaultPrevented);
      Object.assign(window, { pointer: [event.clientX, event.clientY] });
    });
  });
});

const prevented = (page: Page) => page.evaluate(() => (window as unknown as { prevented: boolean[] }).prevented);

Then("the browser's own menu was held back", async ({ page }) => {
  expect(await prevented(page)).toEqual([true]);
});

Then("the browser's own menu was let through", async ({ page }) => {
  expect(await prevented(page)).toEqual([false]);
});

When("I right-click the row part {string}", async ({ page }, selector: string) => {
  await page.locator(selector).first().click({ button: "right" });
});

When("I shift and right-click the row part {string}", async ({ page }, selector: string) => {
  await page
    .locator(selector)
    .first()
    .click({ button: "right", modifiers: ["Shift"] });
});

When("I right-click the row part {string} near the bottom right of the window", async ({ page }, selector: string) => {
  await page
    .locator(selector)
    .first()
    .evaluate((row) =>
      row.dispatchEvent(
        new MouseEvent("contextmenu", {
          bubbles: true,
          button: 2,
          cancelable: true,
          clientX: innerWidth - 4,
          clientY: innerHeight - 4,
        }),
      ),
    );
  await expect(menu(page)).toBeVisible();
});

Given("the menu window is {int} by {int}", async ({ page }, width: number, height: number) => {
  await page.setViewportSize({ height, width });
});

Then("the row menu sits at the pointer", async ({ page }) => {
  const { left, top } = await box(page);

  expect([left, top]).toEqual(await page.evaluate(() => (window as unknown as { pointer: number[] }).pointer));
});

Then("the row menu sits {int} pixels into the row {string}", async ({ page }, offset: number, row: string) => {
  const { left } = await box(page);
  const target = await box(page, row);

  expect(Math.abs(left - (target.left + offset))).toBeLessThanOrEqual(1);
});

Then("the row menu stays inside the window", async ({ page }) => {
  const { bottom, right } = await box(page);
  const size = await page.evaluate(() => [innerWidth, innerHeight]);

  expect(right).toBeLessThanOrEqual(size[0]);
  expect(bottom).toBeLessThanOrEqual(size[1]);
});

Then("the row menu items stand at least {int} pixels tall", async ({ page }, height: number) => {
  expect((await box(page, ".ctx-item")).height).toBeGreaterThanOrEqual(height);
});

When("I focus the task title {string}", async ({ page }, title: string) => {
  await page.locator(".task-title", { hasText: exact(title) }).focus();
});

const active = (page: Page) => page.evaluate(() => document.activeElement?.textContent?.trim() ?? "");

Then("the row menu focus holds {string}", async ({ page }, text: string) => {
  await expect.poll(() => active(page)).toContain(text);
});

When("I step down the row menu until the focus holds {string}", async ({ page }, text: string) => {
  for (let step = 0; step < 20 && !(await active(page)).includes(text); step += 1) {
    await page.keyboard.press("ArrowDown");
  }
  expect(await active(page)).toContain(text);
});

Then("the focus is back on the task row {string}", async ({ page }, title: string) => {
  await expect
    .poll(() => page.evaluate(() => document.activeElement?.closest(".task")?.textContent ?? ""))
    .toContain(title);
});

When("I click the page heading", async ({ page }) => {
  await page.locator("h1, .page-head").first().click();
});

When("I type {string} in the row menu tag box", async ({ page }, text: string) => {
  await menu(page).locator(".ctx-input").pressSequentially(text);
});

Then("the row menu suggestions read {string}", async ({ page }, names: string) => {
  const suggestions = menu(page).locator(".ctx-suggest [role=menuitem]");

  await expect.poll(async () => (await suggestions.allTextContents()).map(norm).join(", ")).toBe(names);
});

When("I pick the row menu suggestion {string}", async ({ page }, name: string) => {
  await menu(page)
    .locator(".ctx-suggest [role=menuitem]", { hasText: exact(name) })
    .click();
});

Then("the focus is in the row menu tag box", async ({ page }) => {
  await expect(menu(page).locator(".ctx-input")).toBeFocused();
});

When("I click {string} on the row {string}", async ({ page }, name: string, row: string) => {
  const found = page.locator(row).first();
  await found.hover();
  await found.getByRole("button", { exact: true, name }).click();
});

When("I click {string} in the open dialog", async ({ page }, name: string) => {
  await page.locator("dialog[open]").getByRole("button", { exact: true, name }).click();
});

When("I set {string} in the open dialog to a day from now", async ({ page }, label: string) => {
  const at = new Intl.DateTimeFormat("sv-SE", {
    dateStyle: "short",
    timeStyle: "short",
    timeZone: zone,
  }).format(new Date(Date.now() + 86_400_000));
  await page.locator("dialog[open]").getByLabel(label, { exact: true }).fill(at.replace(" ", "T"));
});

When("I click the first button {string}", async ({ page }, name: string) => {
  await page.getByRole("button", { exact: true, name }).first().click();
});

When("I click the first {string} reading {string}", async ({ page }, selector: string, text: string) => {
  await page.locator(selector, { hasText: text }).first().click();
});

When("I accept the row confirm", async ({ page }) => {
  await page.locator("[data-confirm-accept]").click();
});

const actions = (page: Page, row: string) => page.locator(row).first().locator(".hov").first();
const opacity = (page: Page, row: string) =>
  actions(page, row).evaluate((node) => Number(getComputedStyle(node).opacity));

Then("the actions of the first {string} are hidden", async ({ page }, row: string) => {
  await expect.poll(() => opacity(page, row)).toBe(0);
});

Then("the actions of the first {string} show", async ({ page }, row: string) => {
  await expect.poll(() => opacity(page, row)).toBe(1);
});

When("I hover the first {string}", async ({ page }, row: string) => {
  await page.locator(row).first().hover();
});

When("I move focus into the actions of the first {string}", async ({ page }, row: string) => {
  await actions(page, row).evaluate((node) => {
    const control = node.querySelector<HTMLElement>(":is(button, a[href], summary):not([hidden])");
    (control ?? node.parentElement?.querySelector<HTMLElement>("input"))?.focus();
  });
});

When("I visit {string} on a touch screen", async ({ page }, path: string) => {
  const cdp = await page.context().newCDPSession(page);
  await cdp.send("Emulation.setTouchEmulationEnabled", { enabled: true, maxTouchPoints: 1 });
  await page.goto(path);
});

const shown = (page: Page, row: string) =>
  actions(page, row).evaluate((node) =>
    [...node.querySelectorAll<HTMLElement>(".bt")]
      .filter((button) => button.checkVisibility())
      .map((button) => ({
        height: button.getBoundingClientRect().height,
        label: button.getAttribute("aria-label") || (button.textContent ?? "").trim(),
      })),
  );

Then("each shown action on the first {string} has a label", async ({ page }, row: string) => {
  const found = await shown(page, row);

  expect(found.length).toBeGreaterThan(0);
  expect(found.filter(({ label }) => !/\S/.test(label))).toEqual([]);
});

Then("each shown action on the first {string} stands {int} pixels tall", async ({ page }, row: string, px: number) => {
  const found = await shown(page, row);

  expect(found.length).toBeGreaterThan(0);
  expect(found.map(({ height }) => height)).toEqual(found.map(() => px));
});

Then("the first {string} wears the green bar", async ({ page }, row: string) => {
  await expect
    .poll(() =>
      page
        .locator(row)
        .first()
        .evaluate((node) => getComputedStyle(node).boxShadow),
    )
    .toContain("-12px 0px 0px -9px");
});

const breakSetup = () => {
  const query = Document.prototype.querySelectorAll;
  Document.prototype.querySelectorAll = function (this: Document, selector: string) {
    if (selector === "[data-social-picker]") throw new Error("a broken setup step");
    return query.call(this, selector);
  } as typeof query;
};

Given("an admin setup step throws on load", async ({ page }) => {
  await page.addInitScript(breakSetup);
});

When("an admin setup step throws from now on", async ({ page }) => {
  await page.evaluate(breakSetup);
});

Then("select mode is off for {string}", async ({ page }, form: string) => {
  await expect(page.locator("button[data-bulk-toggle][aria-pressed='false']", { hasText: "Select" })).toBeVisible();
  await expect(page.locator(`form${form}[data-bulk-off]`)).toBeAttached();
  await expect(page.locator("input[name='ids[]']:visible")).toHaveCount(0);
});

Then("select mode is on for {string}", async ({ page }, form: string) => {
  await expect(page.locator("button[data-bulk-toggle][aria-pressed='true']", { hasText: "Select" })).toBeVisible();
  await expect(page.locator(`form${form}[data-bulk-off]`)).toHaveCount(0);
});

let picked = "";

Before(() => {
  picked = "";
});

When("I tick the first {string} row", async ({ page }, row: string) => {
  const one = page.locator(row).first().locator("input[name='ids[]']");
  await one.check();
  picked = await one.inputValue();
});

Then("only that row stays ticked", async ({ page }) => {
  const ticked = await page
    .locator("input[name='ids[]']:checked")
    .evaluateAll((boxes) => boxes.map((one) => (one as HTMLInputElement).value));

  expect(ticked).toEqual([picked]);
});
