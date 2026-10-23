import { expect, type Page } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { chicagoDay, dayCell, hashOf, postId, seal, tagPost, writePost } from "../support/admin_posts.ts";
import { heard } from "../support/delivery.ts";
import { cell } from "../support/rows.ts";
import { Given, Then, When } from "../support/world.ts";

const fields = (table?: DataTable) =>
  table ? Object.fromEntries(table.raw().map(([name, value]) => [name, expand(value)])) : {};

function expand(value: string, site = "") {
  return value
    .replaceAll(/\{(\d+) (.)\}/g, (_, count, letter) => letter.repeat(Number(count)))
    .replaceAll("{link}", `${site}/writing/hello`)
    .replaceAll("{space}", " ")
    .replaceAll("\\r", "\r")
    .replaceAll("\\n", "\n")
    .replaceAll(/\\u([0-9a-f]{4})/g, (_, code) => String.fromCharCode(Number.parseInt(code, 16)));
}

Given("I wrote a {word} post {string}", async ({ app }, status: string, title: string) => {
  await writePost(app.sql, status, title);
});

Given("I wrote a {word} post {string} with:", async ({ app }, status: string, title: string, table: DataTable) => {
  await writePost(app.sql, status, title, fields(table));
});

Given("I wrote {int} {word} posts", async ({ app }, count: number, status: string) => {
  for (let index = 1; index <= count; index++) {
    await writePost(app.sql, status, `${status} ${index}`, {
      ...(status === "published" && { published_at: `${count - index + 1} days ago` }),
      ...(status === "draft" && { updated_at: `${count - index + 1} days ago` }),
    });
  }
});

Given("the post {string} is tagged {string}", async ({ app }, title: string, tags: string) => {
  await tagPost(app.sql, await postId(app.sql, title), tags.split(/,\s*/));
});

Given("the post {string} has received webmentions:", async ({ app }, title: string, table: DataTable) => {
  const id = await postId(app.sql, title);
  for (const [index, row] of table.hashes().entries()) {
    await app.sql`
      INSERT INTO webmentions ${app.sql({
        author_name: row.author ?? `Reader ${index + 1}`,
        post_id: id,
        source_url: `http://203.0.113.${index + 10}/mention`,
        status: row.status ?? "pending",
        type: row.type ?? "reply",
      })}
    `;
  }
});

Given("the post {string} has the edit notes:", async ({ app }, title: string, table: DataTable) => {
  const id = await postId(app.sql, title);
  for (const row of table.hashes()) {
    await app.sql`
      INSERT INTO post_edits ${app.sql({
        created_at: cell(row.written ?? "now"),
        note: row.note,
        note_html: `<p>${row.note.replaceAll(/`([^`]+)`/g, "<code>$1</code>")}</p>`,
        post_id: id,
      })}
    `;
  }
});

Given("the post {string} has a social post {word}", async ({ app }, title: string, status: string) => {
  const id = await postId(app.sql, title);
  const [social] = await app.sql`
    INSERT INTO social_posts ${app.sql({
      post_id: id,
      posted_at: status === "draft" ? null : new Date(),
      status,
      targets: "{mastodon}",
    })}
    RETURNING id
  `;
  await app.sql`INSERT INTO social_post_parts ${app.sql({ body: "Out in the world", position: 1, social_post_id: social.id })}`;
});

Given("webmentions start {word} on new posts", async ({ app }, state: string) => {
  const on = state === "on";
  await app.sql`
    INSERT INTO webmention_settings (id, enable_on_new_posts) VALUES (1, ${on})
    ON CONFLICT (id) DO UPDATE SET enable_on_new_posts = ${on}
  `;
});

Given("Mastodon and Bluesky are connected for cross-posts", async ({ app }) => {
  await app.sql`
    INSERT INTO service_connections ${app.sql([
      {
        account_id: "1",
        credentials: seal({ access_token: "token" }),
        host: "203.0.113.9",
        label: "@aaronmallen@203.0.113.9",
        provider: "mastodon",
        scopes: "{write:statuses,write:media,read:accounts,read:search,read:statuses}",
      },
      {
        account_id: "did:plc:ada",
        credentials: seal({ app_password: "secret", handle: "ada.example" }),
        host: null,
        label: "@ada.example",
        provider: "bluesky",
        scopes: "{}",
      },
    ])}
  `;
});

Given("the post analytics table {word} holds:", async ({ app }, table: string, rows: DataTable) => {
  for (const row of rows.hashes()) {
    const values = Object.fromEntries(
      Object.entries(row).map(([column, value]) => {
        if (column === "day") return [column, dayCell(value)];
        if (column.endsWith("_hash")) return [column, hashOf(value)];
        return [column, cell(value)];
      }),
    );
    const insert =
      table === "analytics_rollups"
        ? app.sql`INSERT INTO analytics_rollups ${app.sql(values)} ON CONFLICT DO NOTHING`
        : app.sql`INSERT INTO ${app.sql(table)} ${app.sql(values)}`;
    await insert;
  }
});

Given(
  "the post analytics rolled up {string} for {string}:",
  async ({ app }, when: string, path: string, rows: DataTable) => {
    const day = dayCell(when);
    await app.sql`INSERT INTO analytics_rollups (day) VALUES (${day}) ON CONFLICT DO NOTHING`;
    for (const row of rows.hashes()) {
      await app.sql`INSERT INTO analytics_rollup_paths ${app.sql({ day, path, ...row })}`;
    }
  },
);

When("I open a new post", async ({ page }) => {
  await page.goto("/admin/posts/new");
});

When("I open the editor for {string}", async ({ app, page }, title: string) => {
  await page.goto(`/admin/posts/${await postId(app.sql, title)}/edit`);
});

When("I open the analytics for {string}", async ({ app, page }, title: string) => {
  await page.goto(`/admin/posts/${await postId(app.sql, title)}/analytics`);
});

When("I open the analytics for {string} over {int} days", async ({ app, page }, title: string, days: number) => {
  await page.goto(`/admin/posts/${await postId(app.sql, title)}/analytics?range=${days}`);
});

async function details(page: Page) {
  const drawer = page.locator("dialog#post-details");
  if (!(await drawer.evaluate((dialog: HTMLDialogElement) => dialog.open))) {
    await page.getByRole("button", { exact: true, name: "Details" }).click();
  }
  await expect(drawer).toBeVisible();
  return drawer;
}

When("I open the post details", async ({ page }) => {
  await details(page);
});

When("I fill in the post details {string} with {string}", async ({ app, page }, label: string, value: string) => {
  await (await details(page)).getByLabel(label, { exact: true }).first().fill(expand(value, app.url));
});

When("I fill in the post details {string} with:", async ({ page }, label: string, value: string) => {
  await (await details(page)).getByLabel(label, { exact: true }).first().fill(value);
});

When("I fill in the post body with:", async ({ page }, value: string) => {
  await page.getByLabel("Body", { exact: true }).fill(value);
});

When("I turn {word} {string} in the post details", async ({ page }, state: string, label: string) => {
  await (await details(page)).getByLabel(label, { exact: true }).setChecked(state === "on", { force: true });
});

When("I pick the {string} network in the post details", async ({ page }, name: string) => {
  if (name === "none") return;
  await (await details(page)).locator(".compose-target", { hasText: name }).click();
});

When("I pick the {string} editor tab", async ({ page }, name: string) => {
  await page.locator(".edit > .edit-pane-head .seg-option", { hasText: name }).first().click();
});

When("I press the {string} editor tool", async ({ page }, label: string) => {
  await page.locator(`#main [role='toolbar'] button[aria-label='${label}']`).first().click();
});

When("I put the body cursor from {int} to {int}", async ({ page }, start: number, end: number) => {
  await page
    .locator("#post-body")
    .evaluate((box: HTMLTextAreaElement, [from, to]) => box.setSelectionRange(from, to), [start, end]);
});

When("I type {string} into the post field {string}", async ({ page }, text: string, label: string) => {
  await field(page, label).pressSequentially(text);
});

When("I save the post", async ({ page }) => {
  await closeDetails(page);
  await page.getByRole("button", { exact: true, name: "Save" }).first().click();
});

async function closeDetails(page: Page) {
  const drawer = page.locator("dialog#post-details");
  if (await drawer.evaluate((dialog: HTMLDialogElement) => dialog.open)) {
    await drawer.getByRole("button", { exact: true, name: "Done" }).click();
  }
}

const field = (page: Page, label: string) =>
  label === "Tags"
    ? page.locator("[name='post[tags]']").first()
    : page.getByLabel(label, { exact: true }).and(page.locator("input, textarea, select")).first();

const escaped = (text: string) => text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

const postRow = (page: Page, title: string) =>
  page.locator(".li", { has: page.locator(".li-title", { hasText: new RegExp(`^${escaped(title)}$`) }) });

When("I confirm the post action", async ({ page }) => {
  await page.locator("[data-confirm-accept]").click();
});

When("I decline the post action", async ({ page }) => {
  await page.locator("[data-confirm-decline]").click();
});

When("I send the post form to {string} with:", async ({ answer, app, page }, path: string, table: DataTable) => {
  const target = path.replace(/\{(.+?)\}/g, (_, title) => `__${title}__`);
  let resolved = target;
  for (const [, title] of target.matchAll(/__(.+?)__/g)) {
    resolved = resolved.replace(`__${title}__`, String(await postId(app.sql, title)));
  }
  if (!page.url().startsWith(app.url)) await page.goto("/admin/posts");
  const rows = table.raw();
  const token = rows.find(([name]) => name === "_csrf_token");
  const pairs = (token ? rows : [["_csrf_token", "page"], ...rows]).map(([name, value]) => [name, expand(value)]);
  const response = page.waitForResponse((sent) => sent.request().method() === "POST");
  await page.evaluate(
    ({ action, pairs }) => {
      const form = document.createElement("form");
      form.method = "post";
      form.action = action;
      const csrf = document.querySelector<HTMLInputElement>("input[name='_csrf_token']")?.value ?? "";
      for (const [name, value] of pairs) {
        if (name === "_csrf_token" && value === "none") continue;
        const input = document.createElement("input");
        input.type = "hidden";
        input.name = name;
        input.value = name === "_csrf_token" && value === "page" ? csrf : value;
        form.append(input);
      }
      document.body.append(form);
      HTMLFormElement.prototype.submit.call(form);
    },
    { action: resolved, pairs },
  );
  const sent = await response;
  Object.assign(answer, { body: "", status: sent.status() });
  await page.waitForLoadState();
});

When("I ask the admin to preview {string} with:", async ({ answer, page }, kind: string, table: DataTable) => {
  if (!page.url().includes("/admin")) await page.goto("/admin/posts/new");
  const rows = table.raw();
  const token = await page.locator("input[name='_csrf_token']").first().inputValue();
  const sendToken = !rows.some(([name, value]) => name === "_csrf_token" && value === "none");
  const form = Object.fromEntries(
    rows.filter(([name]) => name !== "_csrf_token").map(([name, value]) => [`post[${name}]`, expand(value)]),
  );
  const response = await page.request.post(
    kind === "the cross-post" ? "/admin/posts/preview/syndication" : "/admin/posts/preview",
    {
      form,
      headers: sendToken ? { "X-CSRF-Token": token } : {},
    },
  );
  const body = await response.text();
  Object.assign(answer, { body, status: response.status(), headers: response.headers() });
});

Then("the post admin answers {int}", ({ answer }, status: number) => {
  expect(answer.status).toBe(status);
});

Then("the preview answer is:", ({ answer }, text: string) => {
  expect(answer.body).toBe(text);
});

Then("the preview answer is empty", ({ answer }) => {
  expect(answer.body).toBe("");
});

Then("the preview answer has type {word}", ({ answer }, type: string) => {
  expect(answer.headers?.["content-type"]).toContain(type);
});

Then("the post field {string} holds {string}", async ({ page }, label: string, value: string) => {
  await expect(field(page, label)).toHaveValue(value);
});

Then("the post field {string} holds:", async ({ page }, label: string, value: string) => {
  await expect(field(page, label)).toHaveValue(value);
});

Then("the post field {string} suggests {string}", async ({ page }, label: string, value: string) => {
  await expect(field(page, label)).toHaveAttribute("placeholder", value);
});

Then("the post field {string} suggests:", async ({ page }, label: string, value: string) => {
  await expect(field(page, label)).toHaveAttribute("placeholder", value);
});

Then("the post field {string} is {word}", async ({ page }, label: string, state: string) => {
  const box = field(page, label);
  if (state === "ticked") await expect(box).toBeChecked();
  else if (state === "unticked") await expect(box).not.toBeChecked();
  else if (state === "missing") await expect(box).toBeHidden();
  else if (state === "read-only") await expect(box).not.toBeEditable();
  else throw new Error(`unknown field state ${state}`);
});

Then("the {string} network is {word} in the post details", async ({ page }, name: string, state: string) => {
  const box = (await details(page)).locator(`[data-social-target='${name.toLowerCase()}']`);
  if (state === "ticked") await expect(box).toBeChecked();
  else if (state === "unticked") await expect(box).not.toBeChecked();
  else if (state === "disabled") await expect(box).toBeDisabled();
});

Then("the post body holds:", async ({ page }, value: string) => {
  await expect(page.locator("#post-body")).toHaveValue(value);
});

Then("the post body holds {string}", async ({ page }, value: string) => {
  await expect(page.locator("#post-body")).toHaveValue(expand(value));
});

Then("the post body has {string} picked", async ({ page }, text: string) => {
  const body = page.locator("#post-body");
  const value = await body.inputValue();
  const at = value.indexOf(text);
  await expect(page.locator("#post-body:focus")).toHaveCount(1);
  expect(await body.evaluate((box: HTMLTextAreaElement) => [box.selectionStart, box.selectionEnd])).toEqual([
    at,
    at + text.length,
  ]);
});

Then("the editor sub-line reads {string}", async ({ page }, text: string) => {
  await expect(page.locator(".page-head-sub")).toHaveText(text);
});

Then("the cross-post counts read {string}", async ({ page }, text: string) => {
  const drawer = await details(page);
  await expect(drawer.locator("[data-social-count-text]")).toHaveText(text.split(", "));
});

Then("the cross-post count for {word} is {word}", async ({ page }, name: string, state: string) => {
  const drawer = await details(page);
  const count = drawer.locator(".compose-count", { hasText: name });
  await expect(count).toHaveClass(new RegExp(`\\b${state}\\b`));
});

Then("the cross-post count for {word} is not over", async ({ page }, name: string) => {
  const drawer = await details(page);
  await expect(drawer.locator(".compose-count", { hasText: name })).not.toHaveClass(/\bover\b/);
});

Then("the post preview shows {string} as the {word}", async ({ page }, text: string, part: string) => {
  const selector = { body: ".prose", emphasis: ".prose em", heading: ".prose h2", title: ".post-title" }[part];
  await expect(page.locator(`[data-post-editor] .preview ${selector}`).first()).toHaveText(text);
});

Then("the editor shows {word}", async ({ page }, view: string) => {
  const body = page.getByLabel("Body", { exact: true });
  if (view === "Preview") {
    await expect(page.locator("[data-post-editor] .preview")).toBeVisible();
    await expect(body).toBeHidden();
    await expect(page.locator("#main [role='toolbar']").first()).toBeHidden();
  } else {
    await expect(body).toBeVisible();
    await expect(page.locator("[data-post-editor] .preview")).toBeHidden();
    await expect(page.locator("#main [role='toolbar']").first()).toBeVisible();
  }
});

Then("the post previews asked for number {int}", async ({ page }, count: number) => {
  const asked = await page.evaluate(() => (window as unknown as { previewsAsked?: number }).previewsAsked ?? 0);
  expect(asked).toBe(count);
});

When("I count the post previews asked for", async ({ page }) => {
  await page.route("**/admin/posts/preview", async (route) => {
    await page.evaluate(() => {
      const counted = window as unknown as { previewsAsked?: number };
      counted.previewsAsked = (counted.previewsAsked ?? 0) + 1;
    });
    await route.continue();
  });
});

When(
  "I hold the next post preview while I retitle the post {string} then {string}",
  async ({ page }, stale: string, fresh: string) => {
    let release: () => void = () => {};
    const held = new Promise<void>((done) => {
      release = done;
    });
    let first = true;
    await page.route("**/admin/posts/preview", async (route) => {
      if (first) {
        first = false;
        await held;
      }
      await route.continue();
    });
    const title = field(page, "Title");
    await title.fill(stale);
    await page.waitForTimeout(500);
    await title.fill(fresh);
    await expect(page.locator("[data-post-editor] .preview .post-title")).toHaveText(fresh);
    release();
    await page.waitForLoadState("networkidle");
  },
);

Then("the post {string} has the edit notes {string}", async ({ app }, title: string, notes: string) => {
  const id = await postId(app.sql, title);
  await expect
    .poll(async () =>
      (await app.sql`SELECT note FROM post_edits WHERE post_id = ${id} ORDER BY id`).map((row) => row.note),
    )
    .toEqual(notes === "" ? [] : notes.split(" | "));
});

Then("the post {string} has no edit notes", async ({ app }, title: string) => {
  const id = await postId(app.sql, title);
  expect(await app.sql`SELECT id FROM post_edits WHERE post_id = ${id}`).toHaveLength(0);
});

Then("the post {string} carries the tags {string}", async ({ app }, title: string, names: string) => {
  const id = await postId(app.sql, title);
  const rows = await app.sql`
    SELECT tags.name FROM post_tags JOIN tags ON tags.id = post_tags.tag_id WHERE post_id = ${id} ORDER BY tags.name
  `;
  expect(rows.map((row) => row.name).join(", ")).toBe(names);
});

Then("the post {string} was touched since {string}", async ({ app }, title: string, since: string) => {
  const [row] = await app.sql`SELECT updated_at FROM posts WHERE title = ${title}`;
  expect(row.updated_at.getTime()).toBeGreaterThan(moment(since).getTime() + 1000);
});

Then("the post {string} was not touched since {string}", async ({ app }, title: string, since: string) => {
  const [row] = await app.sql`SELECT updated_at FROM posts WHERE title = ${title}`;
  expect(Math.abs(row.updated_at.getTime() - moment(since).getTime())).toBeLessThan(5000);
});

Then("the post {string} went live just now", async ({ app }, title: string) => {
  const [row] = await app.sql`SELECT status, published_at FROM posts WHERE title = ${title}`;
  expect(row.status).toBe("published");
  expect(Math.abs(row.published_at.getTime() - Date.now())).toBeLessThan(60_000);
});

Then("the post {string} goes live at {string}", async ({ app }, title: string, at: string) => {
  const [row] = await app.sql`SELECT published_at FROM posts WHERE title = ${title}`;
  expect(row.published_at.toISOString()).toBe(new Date(at).toISOString());
});

Then("the post {string} is gone", async ({ app }, title: string) => {
  expect(await app.sql`SELECT id FROM posts WHERE title = ${title}`).toHaveLength(0);
});

Then("{int} cross-post(s) wait(s) to go out for {string}", async ({ app }, count: number, title: string) => {
  const id = await postId(app.sql, title);
  await expect
    .poll(
      async () => (await app.sql`SELECT id FROM social_posts WHERE post_id = ${id} AND status = 'scheduled'`).length,
    )
    .toBe(count);
});

Then("no cross-post waits to go out after {int} syndication run(s)", async ({ app }, runs: number) => {
  await expect
    .poll(
      async () =>
        (
          await app.sql`SELECT count(*)::int AS count FROM performance_jobs WHERE job = 'Social::Jobs::SyndicatePost'`
        )[0].count,
    )
    .toBe(runs);
  expect(await app.sql`SELECT id FROM social_posts WHERE status = 'scheduled'`).toHaveLength(0);
});

Then(
  "the queued cross-post for {string} reads {string} to {string}",
  async ({ app }, title: string, text: string, targets: string) => {
    const id = await postId(app.sql, title);
    await expect
      .poll(async () =>
        (
          await app.sql`
          SELECT social_posts.targets::text AS targets, social_post_parts.body
          FROM social_posts JOIN social_post_parts ON social_post_parts.social_post_id = social_posts.id
          WHERE post_id = ${id} AND status = 'scheduled'
        `
        ).map((row) => `${row.body} to ${row.targets}`),
      )
      .toEqual([`${text} to ${targets}`]);
  },
);

Then("the cross-post for {string} went out at its publish time", async ({ app }, title: string) => {
  await expect
    .poll(async () => {
      const [row] = await app.sql`
        SELECT abs(extract(epoch FROM social_posts.posted_at - posts.published_at)) AS gap
        FROM social_posts JOIN posts ON posts.id = social_posts.post_id
        WHERE posts.title = ${title} AND social_posts.status = 'scheduled'
      `;
      return row ? Number(row.gap) <= 1 : false;
    })
    .toBe(true);
});

Then("the stat {string} reads {string}", async ({ page }, name: string, value: string) => {
  await expect(stat(page, name).locator(".stat-value")).toHaveText(value);
});

Then("the stat {string} notes {string}", async ({ page }, name: string, note: string) => {
  await expect(stat(page, name).locator(".stat-change")).toHaveText(note);
});

Then("the stats read {string}", async ({ page }, values: string) => {
  await expect(page.locator(".stat-value")).toHaveText(values.split(", "));
});

Then("the card {string} lists {string}", async ({ page }, title: string, names: string) => {
  await expect(page.locator(".card", { hasText: title }).locator(".meter-name")).toHaveText(names.split(", "));
});

Then("the card {string} counts {string}", async ({ page }, title: string, counts: string) => {
  await expect(page.locator(".card", { hasText: title }).locator(".meter-count")).toHaveText(counts.split(", "));
});

Then("the card {string} fills its meters to {string}", async ({ page }, title: string, widths: string) => {
  const fills = page.locator(".card", { hasText: title }).locator(".meter-fill");
  expect(await fills.evaluateAll((all) => all.map((fill) => (fill as HTMLElement).style.width))).toEqual(
    widths.split(", "),
  );
});

Then("the card {string} says {string}", async ({ page }, title: string, text: string) => {
  await expect(page.locator(".card", { hasText: title }).locator(".empty")).toHaveText(text);
});

Then("the first 30 days read:", async ({ page }, table: DataTable) => {
  const card = page.locator(".card", { hasText: "First 30 days" });
  const rows = await card
    .locator("tbody tr")
    .evaluateAll((all) =>
      all.map((row) => [...row.querySelectorAll("th, td")].map((cellNode) => cellNode.textContent?.trim() ?? "")),
    );
  const wanted = table.raw();
  expect(rows.map((row) => row.slice(0, wanted[0].length))).toEqual(wanted);
});

Then("the first 30 days draw {int} point(s) for the {word}", async ({ page }, count: number, curve: string) => {
  const points = await page.locator(`.card polyline.curve-${curve}`).getAttribute("points");
  expect(points?.trim().split(/\s+/)).toHaveLength(count);
});

Then("the post list shows {string}", async ({ page }, titles: string) => {
  await expect(page.locator(".li-title")).toHaveText(titles.split(", "));
});

Then("the post list shows {string} in any order", async ({ page }, titles: string) => {
  const shown = await page.locator(".li-title").allTextContents();
  expect(shown.sort()).toEqual(titles.split(", ").sort());
});

Then("the post row {string} reads {string}", async ({ page }, title: string, text: string) => {
  const row = postRow(page, title);
  await expect(row.locator(".li-sub")).toHaveText(text.replace("{today}", dayText(0)));
});

Then(
  "the post row {string} reads {string} with the date {int} days ago",
  async ({ page }, title: string, text: string, days: number) => {
    const row = postRow(page, title);
    await expect(row.locator(".li-sub")).toHaveText(text.replace("{date}", dayText(days)));
  },
);

Then("the post row {string} shows {string}", async ({ page }, title: string, text: string) => {
  const row = postRow(page, title);
  await expect(row).toContainText(text);
});

Then("the post row {string} does not show {string}", async ({ page }, title: string, text: string) => {
  const row = postRow(page, title);
  await expect(row).not.toContainText(text);
});

When("I tick the post {string}", async ({ page }, title: string) => {
  await postRow(page, title).locator("input[name='ids[]']").check();
});

When("I tick every post on the page", async ({ page }) => {
  await page.locator("[data-bulk-all] input").check();
});

Then("the bulk actions are {word}", async ({ page }, state: string) => {
  const acts = page.locator("[data-bulk-acts]");
  if (state === "shown") await expect(acts).toBeVisible();
  else await expect(acts).toBeHidden();
});

Then("{int} posts are ticked", async ({ page }, count: number) => {
  await expect(page.locator("input[name='ids[]']:checked")).toHaveCount(count);
});

When("I tag the ticked posts {string} with Enter", async ({ page }, tag: string) => {
  const field = page.locator("form#post-bulk input[name='tag']");
  await field.fill(tag);
  await field.press("Enter");
});

When("I delete the ticked posts", async ({ page }) => {
  await page.locator("form#post-bulk").getByRole("button", { name: "Delete" }).click();
});

Then("there is no bulk bar", async ({ page }) => {
  await expect(page.locator("form#post-bulk")).toHaveCount(0);
});

Then("the post toast says {string}", async ({ page }, text: string) => {
  await expect(page.locator(".toast", { hasText: new RegExp(`^\\s*${escaped(text)}\\s*$`) })).not.toHaveCount(0);
});

Then("the post links drawer lists {string}", async ({ page }, urls: string) => {
  const drawer = page.locator("dialog#post-links");
  const shown = await drawer.locator(".li .li-sub").evaluateAll((all) => all.map((node) => node.textContent ?? ""));
  const wanted = urls.split(", ");
  expect(wanted.map((url) => shown.findIndex((text) => text.includes(url)))).toEqual(
    [...wanted.keys()].map((index) => shown.findIndex((text) => text.includes(wanted[index]))).sort((a, b) => a - b),
  );
});

Then("the post link {string} shows {string}", async ({ page }, url: string, text: string) => {
  const row = page.locator("dialog#post-links .li", { has: page.locator(".li-sub", { hasText: url }) });
  await expect(row.first()).toContainText(text);
});

Then("the post links drawer shows {string}", async ({ page }, text: string) => {
  await expect(page.locator("dialog#post-links")).toContainText(text);
});

Then("the post links drawer is open", async ({ page }) => {
  await expect(page.locator("dialog#post-links")).toBeVisible();
});

When("I open the post links", async ({ page }) => {
  await page.locator("button[data-dialog-open='post-links']").click();
  await expect(page.locator("dialog#post-links")).toBeVisible();
});

When("I find {string} in the post", async ({ page }, url: string) => {
  await page.locator(`dialog#post-links [data-find-link='${url}']`).click();
});

When("I check the post link {string} again", async ({ page }, url: string) => {
  await page.locator(`dialog#post-links button[name='url'][value='${url}']`).click();
});

When("I check every post link again", async ({ page }) => {
  await page.locator("dialog#post-links .dialog-foot button[form='post-links-check']").click();
});

Then("the post links button says {string}", async ({ page }, text: string) => {
  await expect(page.locator("button[data-dialog-open='post-links']")).toContainText(text);
});

Then("the posts filter is on {string}", async ({ page }, status: string) => {
  await expect(page.locator(`.seg input[name='status'][value='${status}']`)).toBeChecked();
});

When("I filter the posts to {string}", async ({ page }, label: string) => {
  await page.evaluate(() => {
    (window as unknown as { stayed: boolean }).stayed = true;
  });
  await page.locator(".seg-option", { hasText: label }).click();
});

Then("the posts list redrew without a page load", async ({ page }) => {
  expect(await page.evaluate(() => (window as unknown as { stayed?: boolean }).stayed)).toBe(true);
});

Then("the editor's slug preview turns each title into its slug:", async ({ page }, table: DataTable) => {
  const titles = table.hashes().map((row) => row.title);
  const slugs = await page.evaluate((all) => {
    const title = document.querySelector<HTMLInputElement>("[data-editor-title]");
    const path = document.querySelector<HTMLElement>("[data-editor-path]");
    if (!title || !path) return [];
    return all.map((text) => {
      title.value = text;
      title.dispatchEvent(new Event("input"));
      return (path.textContent ?? "").slice((path.dataset.editorPath ?? "").length);
    });
  }, titles);
  expect(slugs).toEqual(table.hashes().map((row) => row.slug));
});

Then("the post page {string} shows {string}", async ({ page }, path: string, text: string) => {
  await page.goto(path);
  await expect(page.locator("body")).toContainText(text);
});

Then("the post page {string} is not found", async ({ page }, path: string) => {
  const response = await page.goto(path);
  expect(response?.status()).toBe(404);
});

Then("the post page {string} has a {string} tag in its head", async ({ page }, path: string, selector: string) => {
  await page.goto(path);
  await expect(page.locator(`head ${selector}`)).toHaveCount(1);
});

Then("the post page {string} has no {string} tag in its head", async ({ page }, path: string, selector: string) => {
  await page.goto(path);
  await expect(page.locator(`head ${selector}`)).toHaveCount(0);
});

Then(
  "the post page {string} heads with {string} as {string}",
  async ({ page }, path: string, selector: string, value: string) => {
    await page.goto(path);
    const tag = page.locator(`head ${selector}`);
    const attribute = selector.startsWith("link") ? "href" : "content";
    await expect(tag).toHaveAttribute(attribute, new RegExp(value));
  },
);

Then("the post feed shows {string}", async ({ request }, text: string) => {
  expect(await (await request.get("/writing.atom")).text()).toContain(text);
});

Then("the post field error reads {string}", async ({ page }, text: string) => {
  await expect(page.locator(".field-error").first()).toHaveText(text);
});

Then("the post details drawer is {word}", async ({ page }, state: string) => {
  const open = await page.locator("dialog#post-details").evaluate((dialog: HTMLDialogElement) => dialog.open);
  expect(open).toBe(state === "open");
});

Then("the focus is on the post's Save button", async ({ page }) => {
  expect(await page.evaluate(() => (document.activeElement as HTMLButtonElement | null)?.value)).toBe("save");
});

Then("the post page {string} renders the body as the editor preview did", async ({ page }, path: string) => {
  const preview = await page.locator("[data-post-editor] .preview .prose").innerHTML();
  await page.goto(path);
  expect((await page.locator(".post .e-content").innerHTML()).trim()).toBe(preview.trim());
});

Then("the editor preview sets type as the post page {string} does", async ({ page }, path: string) => {
  const styles = (prefix: string) =>
    page.evaluate((prefix) => {
      return [".post-title", ".prose p", ".prose h2"].map((selector) => {
        const node = document.querySelector(`${prefix}${selector}`);
        if (!node) return null;
        const style = getComputedStyle(node);
        return [style.fontFamily, style.fontSize, style.fontWeight];
      });
    }, prefix);
  await expect(page.locator("[data-post-editor] .preview .prose h2")).toBeVisible();
  const previewed = await styles("[data-post-editor] .preview ");
  await page.goto(path);
  expect(await styles("")).toEqual(previewed);
});

Then("today is the date on the post preview", ({ answer }) => {
  const today = new Date(`${chicagoDay()}T12:00:00Z`).toLocaleDateString("en-US", {
    day: "numeric",
    month: "short",
    timeZone: "UTC",
    year: "numeric",
  });
  expect(answer.body).toContain(today);
});

function dayText(daysAgo: number) {
  return new Date(`${chicagoDay(daysAgo)}T12:00:00Z`).toLocaleDateString("en-US", {
    day: "numeric",
    month: "short",
    timeZone: "UTC",
    year: "numeric",
  });
}

Then("the post admin shows {string}", async ({ page }, text: string) => {
  await expect(page.getByText(text).filter({ visible: true }).first()).toBeVisible();
});

Then("the post admin does not show {string}", async ({ page }, text: string) => {
  await expect(page.getByText(text).filter({ visible: true })).toHaveCount(0);
});

When("I fill in the post {string} with {string}", async ({ page }, label: string, value: string) => {
  await page.getByLabel(label, { exact: true }).first().fill(expand(value));
});

Then("the post admin page is titled {string}", async ({ page }, title: string) => {
  await expect(page).toHaveTitle(`${title} | Admin | Aaron Allen`);
});

When("I press the post button {string}", async ({ page }, name: string) => {
  await closeDetails(page);
  await page.getByRole("button", { exact: true, name }).first().click();
});

Then("the post editor offers {string}", async ({ page }, name: string) => {
  const main = page.locator("main");
  await expect(
    main
      .getByRole("button", { exact: true, name })
      .or(main.getByRole("link", { exact: true, name }))
      .first(),
  ).toBeVisible();
});

Then("the post editor does not offer {string}", async ({ page }, name: string) => {
  const main = page.locator("main");
  await expect(
    main.getByRole("button", { exact: true, name }).or(main.getByRole("link", { exact: true, name })),
  ).toHaveCount(0);
});

Then("the post tag field suggests {string}", async ({ page }, names: string) => {
  const json = await page.locator("[name='post[tags]'] + [data-tag-field]").getAttribute("data-tag-field");
  expect(JSON.parse(json ?? "[]").map((tag: { name: string }) => tag.name)).toEqual(names.split(", "));
});

When("I fill in the post note with {string}", async ({ page }, note: string) => {
  await page.locator("dialog[data-edit-note-dialog]").getByLabel("What changed and why", { exact: true }).fill(note);
});

When("I save the post note", async ({ page }) => {
  await page.locator("dialog[data-edit-note-dialog]").getByRole("button", { exact: true, name: "Save" }).click();
});

When("I cancel the post note", async ({ page }) => {
  await page.locator("dialog[data-edit-note-dialog]").getByRole("button", { exact: true, name: "Cancel" }).click();
});

Then("the post note dialog asks {string}", async ({ page }, label: string) => {
  await expect(page.locator("dialog[data-edit-note-dialog]").getByLabel(label, { exact: true })).toBeVisible();
});

Then("no post dialog is open", async ({ page }) => {
  await expect(page.locator("dialog[open]")).toHaveCount(0);
});

Then("the post {string} has a {int} character edit note", async ({ app }, title: string, size: number) => {
  const id = await postId(app.sql, title);
  const rows = await app.sql`SELECT char_length(note) AS size FROM post_edits WHERE post_id = ${id}`;
  expect(rows.map((row) => row.size)).toEqual([size]);
});

Then("the body of the post {string} is {string}", async ({ app }, title: string, body: string) => {
  const [row] = await app.sql`SELECT body FROM posts WHERE title = ${title}`;
  expect(row.body).toBe(expand(body));
});

When("a webmention for {string} comes in", async ({ answer, app, request }, path: string) => {
  const response = await request.post("/webmention", {
    form: { source: "http://203.0.113.20/notes/1", target: `${app.url}${path}` },
  });
  Object.assign(answer, { body: await response.text(), status: response.status() });
});

Then("the webmention answer is {int}", ({ answer }, status: number) => {
  expect(answer.status).toBe(status);
});

Given("Bluesky is not connected for cross-posts", async ({ app }) => {
  await app.sql`DELETE FROM service_connections WHERE provider = 'bluesky'`;
});

Given("the cross-post of {string} ends with its link", async ({ app }, title: string) => {
  await app.sql`UPDATE posts SET syndication_body = syndication_body || ' ' || ${app.url} || '/writing/' || slug WHERE title = ${title}`;
});

Then("the cross-post text of the editor is the title and link of {string}", async ({ app, page }, slug: string) => {
  const [row] = await app.sql`SELECT title FROM posts WHERE slug = ${slug}`;
  await expect((await details(page)).getByLabel("Cross-post text", { exact: true })).toHaveValue(
    `${row.title}\n\n${app.url}/writing/${slug}`,
  );
});

Then("the post list links {string} to its {word}", async ({ app, page }, title: string, where: string) => {
  const id = await postId(app.sql, title);
  const path = where === "editor" ? `/admin/posts/${id}/edit` : `/admin/posts/${id}/analytics`;
  const row = postRow(page, title);
  await expect(row.locator(`a[href='${path}']`).first()).toBeVisible();
});

Then("the posts filters read {string}", async ({ page }, labels: string) => {
  await expect(page.locator("form[action='/admin/posts'] .seg-option")).toHaveText(labels.split(", "));
});

Then("the posts filter sends no token", async ({ page }) => {
  const form = page.locator("form[action='/admin/posts'][method='get']");
  await expect(form).toHaveCount(1);
  await expect(form.locator("input[name='_csrf_token']")).toHaveCount(0);
});

Then("the post list has {int} rows starting with {string}", async ({ page }, count: number, first: string) => {
  await expect(page.locator(".li-title")).toHaveCount(count);
  await expect(page.locator(".li-title").first()).toHaveText(first);
});

Then("the post list pages to {string} as {string}", async ({ page }, href: string, label: string) => {
  await expect(page.locator(`nav.pager a[href='${href}']`)).toHaveText(label);
});

Then("the post list has no pager", async ({ page }) => {
  await expect(page.locator("nav.pager")).toHaveCount(0);
});

Then(
  "the post row {string} links the tags {string} to {string}",
  async ({ page }, title: string, names: string, hrefs: string) => {
    const tags = postRow(page, title).locator("a.tag");
    await expect(tags).toHaveText(names.split(", "));
    expect(await tags.evaluateAll((all) => all.map((tag) => tag.getAttribute("href")))).toEqual(hrefs.split(", "));
  },
);

Given("the post {string} has {int} open suggestion(s)", async ({ app }, title: string, count: number) => {
  const id = await postId(app.sql, title);
  const [suggestion] = await app.sql`INSERT INTO suggestions (post_id) VALUES (${id}) RETURNING id`;
  for (let position = 1; position <= count; position++) {
    await app.sql`
      INSERT INTO suggestion_edits ${app.sql({ original: "teh", position, reason: "typo", replacement: "the", suggestion_id: suggestion.id })}
    `;
  }
});

Then("the post list has {int} publish button(s)", async ({ page }, count: number) => {
  await expect(page.locator("form[action$='/publish'] button[data-key='p']")).toHaveCount(count);
});

Then(
  "the post row {string} offers {string} on the p key, labelled {string}",
  async ({ page }, title: string, name: string, label: string) => {
    const row = postRow(page, title);
    const button = row.getByRole("button", { exact: true, name });
    await expect(button).toHaveAttribute("aria-keyshortcuts", "p");
    await expect(button).toHaveAttribute("data-key-label", label);
  },
);

When("I publish {string} from the list", async ({ page }, title: string) => {
  const row = postRow(page, title);
  await row.getByRole("button", { exact: true, name: `Publish ${title}` }).click();
  await page.waitForLoadState();
});

Then("the post toast starts {string}", async ({ page }, text: string) => {
  await expect(page.locator(".toast", { hasText: text })).not.toHaveCount(0);
});

Then("the publish form keeps the page {int}", async ({ page }, number: number) => {
  await expect(page.locator(`form[action$='/publish'] input[name='page'][value='${number}']`).first()).toHaveCount(1);
});

Then("the post bulk boxes are named {string} in any order", async ({ page }, names: string) => {
  const labels = await page
    .locator(".li input[type='checkbox'][name='ids[]'][form='post-bulk']")
    .evaluateAll((all) => all.map((box) => box.getAttribute("aria-label") ?? ""));
  expect(labels.sort()).toEqual(names.split(", ").sort());
});

async function bulkIds(sql: import("postgres").Sql, titles: string) {
  const ids: string[] = [];
  for (const title of titles.split(", "))
    ids.push(title.startsWith("#") ? title.slice(1) : String(await postId(sql, title)));
  return ids;
}

async function sendBulk(page: Page, act: string, ids: string[], rows: string[][]) {
  const pairs = [
    ["act", act],
    ["status", "all"],
    ...ids.map((id) => ["ids[]", id]),
    ...rows.map(([name, value]) => [name, expand(value)]),
  ];
  const seen = new Set<string>();
  const unique = pairs
    .reverse()
    .filter(([name]) => name === "ids[]" || (!seen.has(name) && seen.add(name)))
    .reverse();
  await page.evaluate((pairs) => {
    const form = document.createElement("form");
    form.method = "post";
    form.action = "/admin/posts/bulk";
    const csrf = document.querySelector<HTMLInputElement>("input[name='_csrf_token']")?.value ?? "";
    for (const [name, value] of [["_csrf_token", csrf], ...pairs]) {
      const input = document.createElement("input");
      input.type = "hidden";
      input.name = name;
      input.value = value;
      form.append(input);
    }
    document.body.append(form);
    HTMLFormElement.prototype.submit.call(form);
  }, unique);
  await page.waitForURL(/\/admin\/posts/);
  await page.waitForLoadState();
}

When(
  "I send the post bulk form with {string} on {string} and:",
  async ({ app, page }, act: string, titles: string, table: DataTable) => {
    await sendBulk(page, act, await bulkIds(app.sql, titles), table.raw());
  },
);

When("I send the post bulk form with {string} on every post", async ({ app, page }, act: string) => {
  const ids = (await app.sql`SELECT id FROM posts`).map((row) => String(row.id));
  await sendBulk(page, act, ids, []);
});

Then(
  "the post bulk bar keeps {string} as {string} and {string} as {string}",
  async ({ page }, one: string, first: string, two: string, second: string) => {
    const bar = page.locator("form#post-bulk");
    await expect(bar.locator(`input[name='${one}'][value='${first}']`)).toHaveCount(1);
    await expect(bar.locator(`input[name='${two}'][value='${second}']`)).toHaveCount(1);
  },
);

When("I set the post body to {string} by script", async ({ page }, value: string) => {
  await page.locator("#post-body").evaluate((box: HTMLTextAreaElement, text) => {
    box.value = text;
  }, expand(value));
});

Then("the post note dialog offers Write, Preview and the toolbar", async ({ page }) => {
  const dialog = page.locator("dialog[data-edit-note-dialog]");
  await expect(dialog.locator(".seg-option", { hasText: "Write" })).toBeVisible();
  await expect(dialog.locator(".seg-option", { hasText: "Preview" })).toBeVisible();
  await expect(dialog.locator("[role='toolbar']")).toBeVisible();
});

When("I leave the post note dialog by {}", async ({ page }, way: string) => {
  const dialog = page.locator("dialog[data-edit-note-dialog]");
  await expect(dialog).toBeVisible();
  if (way === "Cancel") await dialog.getByRole("button", { exact: true, name: "Cancel" }).click();
  else if (way === "Escape") await page.keyboard.press("Escape");
  else await page.mouse.click(5, 5);
});

Then("there is no post note dialog", async ({ page }) => {
  await expect(page.locator("[data-edit-note-dialog]")).toHaveCount(0);
});

Then("the post edit notes read {string}", async ({ page }, notes: string) => {
  await expect(page.locator(".card", { hasText: "Edit notes" }).locator(".edit-note .post-body")).toHaveText(
    notes.split(", "),
  );
});

Then("the post edit note {string} is dated {string}", async ({ page }, note: string, at: string) => {
  const item = page.locator(".card", { hasText: "Edit notes" }).locator("li", { hasText: note });
  await expect(item.locator("time")).toHaveAttribute("datetime", at);
});

Then("the post edit note {string} shows {string} as code", async ({ page }, note: string, code: string) => {
  const item = page.locator(".card", { hasText: "Edit notes" }).locator("li", { hasText: note });
  await expect(item.locator(".post-body code")).toHaveText(code);
});

Given("the posts row {string} is stamped {string}", async ({ app }, title: string, at: string) => {
  await app.sql`UPDATE posts SET updated_at = ${new Date(at)} WHERE title = ${title}`;
});

When("I reword the post edit note {string} to {string}", async ({ page }, note: string, wording: string) => {
  const item = page.locator(".card", { hasText: "Edit notes" }).locator("li", { hasText: note });
  await item.locator("summary", { hasText: "Edit" }).click();
  const id = await item.getAttribute("id");
  await page.locator(`textarea[name='edit[note]'][form='${id}-form']`).fill(wording);
  await page.locator(`button[type='submit'][form='${id}-form']`).click();
  await page.waitForLoadState();
});

Then("the post edit note error reads {string}", async ({ page }, text: string) => {
  const error = page.locator("[id^='post-edit-'][id$='-note-error']");
  await expect(error).toHaveText(text);
  const box = page.locator("[id^='post-edit-'][id$='-note']").first();
  await expect(box).toHaveAttribute("aria-describedby", (await error.getAttribute("id")) ?? "");
  await expect(page.locator(".card", { hasText: "Edit notes" }).locator("details[open]")).toHaveCount(1);
});

Then("the post word count reads {string}", async ({ page }, text: string) => {
  await expect(page.locator("[data-editor-words]")).toHaveText(text);
});

Then("the post read time reads {string}", async ({ page }, text: string) => {
  await expect(page.locator("[data-editor-read-time]")).toHaveText(text);
});

When("I fill in the post body with {int} words", async ({ page }, count: number) => {
  await page.locator("#post-body").fill(Array(count).fill("word").join(" "));
});

When("I fill in the post body with {string} exactly", async ({ page }, text: string) => {
  await page.locator("#post-body").fill(text);
});

Then("the post summary label reads {string}", async ({ page }, text: string) => {
  const label = page.locator("label[for='post-summary']");
  await expect(label).toBeVisible();
  expect(await label.evaluate((node) => (node as HTMLElement).innerText)).toBe(text);
});

Then("the post body stays in the form", async ({ page }) => {
  await expect(page.locator("[data-post-editor] textarea[name='post[body]']")).toHaveCount(1);
});

When("I press the right arrow on the editor tabs", async ({ page }) => {
  await page.locator(".edit .seg input[value='write']").first().focus();
  await page.keyboard.press("ArrowRight");
});

Then(
  "the cross-post box suggests the title {string} and the link {string}",
  async ({ app, page }, title: string, slug: string) => {
    const box = (await details(page)).getByLabel("Cross-post text", { exact: true });
    await expect(box).toHaveAttribute("placeholder", `${title}\n\n${app.url}/writing/${slug}`);
  },
);

When("I ask the admin to preview {string} with words:", async ({ answer, page }, _kind: string, table: DataTable) => {
  const token = await page.locator("input[name='_csrf_token']").first().inputValue();
  const [[, count]] = table.raw();
  const response = await page.request.post("/admin/posts/preview", {
    form: { "post[body]": Array(Number(count)).fill("word").join(" ") },
    headers: { "X-CSRF-Token": token },
  });
  Object.assign(answer, { body: await response.text(), status: response.status() });
});

Then("the preview answer starts with {string}", ({ answer }, text: string) => {
  expect(answer.body.startsWith(text)).toBe(true);
});

Then("the preview answer links the tags {string} to their pages", ({ answer }, names: string) => {
  const links = [
    ...(answer.body ?? "").matchAll(
      /<a[^>]*class="post-tag"[^>]*>([^<]*)<\/a>|<a[^>]*href="(\/writing\/tags\/[^"]+)"[^>]*>([^<]*)<\/a>/g,
    ),
  ];
  const found = links.map((link) => link[0]);
  expect(found.length).toBe(names.split(", ").length);
  for (const name of names.split(", ")) expect(found.join(" ")).toContain(`/writing/tags/${name}`);
});

Then(
  "the preview answer is the title {string} and the link {string}",
  ({ answer, app }, title: string, slug: string) => {
    expect(answer.body).toBe(`${title}\n\n${app.url}/writing/${slug}`);
  },
);

When(
  "I ask the admin to preview {string} from the sign-in page with:",
  async ({ answer, page }, _kind: string, table: DataTable) => {
    await page.goto("/admin/sign-in");
    const token =
      (await page
        .locator("input[name='_csrf_token']")
        .first()
        .inputValue()
        .catch(() => "")) || "";
    const form = Object.fromEntries(table.raw().map(([name, value]) => [`post[${name}]`, value]));
    const response = await page.request.post("/admin/posts/preview", { form, headers: { "X-CSRF-Token": token } });
    Object.assign(answer, { body: await response.text(), status: response.status() });
  },
);

Given(
  "the post {string} has rolled up breakdowns from {int} day(s) ago",
  async ({ app }, title: string, days: number) => {
    const [post] = await app.sql`SELECT slug FROM posts WHERE title = ${title}`;
    const path = `/writing/${post.slug}`;
    const day = chicagoDay(days);
    await app.sql`INSERT INTO analytics_rollups (day) VALUES (${day}) ON CONFLICT DO NOTHING`;
    await app.sql`INSERT INTO analytics_rollup_page_referrers ${app.sql([
      { day, host: "news.example", path, views: 3, visitors: 2 },
      { day, host: null, path, views: 5, visitors: 3 },
    ])}`;
    await app.sql`INSERT INTO analytics_rollup_page_countries ${app.sql([
      { country_code: "US", country_name: "United States", day, path, views: 6, visitors: 4 },
      { country_code: null, country_name: null, day, path, views: 2, visitors: 1 },
      { country_code: "JP", country_name: null, day, path, views: 1, visitors: 1 },
    ])}`;
    await app.sql`INSERT INTO analytics_rollup_devices ${app.sql([
      { day, device_class: "mobile", path, views: 5, visitors: 3 },
      { day, device_class: "desktop", path, views: 3, visitors: 2 },
      { day, device_class: "tablet", path: null, views: 9, visitors: 9 },
    ])}`;
    await app.sql`INSERT INTO analytics_rollup_sources ${app.sql({ day, path, source: "mastodon", views: 4, visitors: 3 })}`;
    for (const [scroll_depth, views] of [
      [0, 2],
      [25, 2],
      [50, 2],
      [75, 1],
      [100, 3],
    ]) {
      await app.sql`INSERT INTO analytics_rollup_scroll_depths ${app.sql({ day, path, scroll_depth, views, visitors: 1 })}`;
    }
  },
);

Given(
  "the post {string} had outbound clicks {int} and {int} days ago",
  async ({ app }, title: string, first: number, second: number) => {
    const [post] = await app.sql`SELECT slug FROM posts WHERE title = ${title}`;
    for (const days of [first, second]) {
      const day = chicagoDay(days);
      await app.sql`INSERT INTO analytics_rollups (day) VALUES (${day}) ON CONFLICT DO NOTHING`;
      await app.sql`INSERT INTO analytics_rollup_clicks ${app.sql([
        { clicks: 2, day, link_host: "docs.example", link_path: "/guide", path: `/writing/${post.slug}` },
        { clicks: 5, day, link_host: "code.example", link_path: "/guide", path: `/writing/${post.slug}` },
        { clicks: 9, day, link_host: "docs.example", link_path: "/guide", path: "/writing/other" },
      ])}`;
    }
  },
);

Then("the post analytics range is {string}", async ({ page }, days: string) => {
  await expect(page.locator(`input[name='range'][value='${days}']`)).toBeChecked();
});

Then("the post analytics ranges read {string}", async ({ page }, labels: string) => {
  await expect(page.locator("form[action$='/analytics'] .seg-option")).toHaveText(labels.split(", "));
});

When("I pick the {int} day range", async ({ page }, days: number) => {
  await page.locator("form[action$='/analytics'] .seg-option", { hasText: `${days}d` }).click();
  await page.waitForURL(new RegExp(`range=${days}`));
});

Then("the median of the first 30 days reads {string}", async ({ page }, values: string) => {
  const card = page.locator(".card", { hasText: "First 30 days" });
  const last = await card
    .locator("tbody tr")
    .evaluateAll((all) => all.map((row) => [...row.querySelectorAll("th, td")].at(-1)?.textContent?.trim() ?? ""));
  expect(last).toEqual(values.split(", "));
});

Then("the post link {string} is marked {word}", async ({ page }, url: string, color: string) => {
  const row = page.locator("dialog#post-links .li", { has: page.locator(".li-sub", { hasText: url }) });
  await expect(row.first().locator(`.pill.${color}`)).toHaveCount(1);
});

Then("the post links drawer folds {string}", async ({ page }, text: string) => {
  await expect(page.locator("dialog#post-links details.post-links-fine summary")).toContainText(text);
});

Then("the post link {string} offers Find in post, Check again and Open link", async ({ page }, url: string) => {
  const row = page.locator("dialog#post-links .li", { has: page.locator(".li-sub", { hasText: url }) }).first();
  await expect(row.locator(`[data-find-link='${url}']`)).toHaveCount(1);
  await expect(row.locator(`button[name='url'][value='${url}']`)).toHaveCount(1);
  await expect(row.locator(`a[href='${url}'][target='_blank']`)).toHaveCount(1);
});

Then("the post links drawer offers no check", async ({ page }) => {
  await expect(page.locator("dialog#post-links button[form='post-links-check']")).toHaveCount(0);
});

Then("the post links drawer is shut", async ({ page }) => {
  await expect(page.locator("dialog#post-links")).toBeHidden();
});

Then("the editor tabs are labelled {string}", async ({ page }, label: string) => {
  await expect(page.locator(`.edit .seg[role='radiogroup'][aria-label='${label}']`).first()).toHaveCount(1);
});

Then("the admin nav marks {string} as current", async ({ page }, name: string) => {
  await expect(page.locator("[aria-current='page']", { hasText: name })).not.toHaveCount(0);
});

Then(
  "the post row {string} colours the tags {string} as text, not pills",
  async ({ page }, title: string, colors: string) => {
    const tags = postRow(page, title).locator(".post-row-meta a.tag");
    const classes = await tags.evaluateAll((all) => all.map((tag) => tag.className));
    for (const [index, color] of colors.split(", ").entries()) expect(classes[index]).toContain(color);
    await expect(postRow(page, title).locator(".post-row-meta .pill")).toHaveCount(0);
  },
);

Then(
  "the post row {string} marks its webmention count in pink with an at sign readers skip",
  async ({ page }, title: string) => {
    const count = postRow(page, title).locator(".post-row-meta .tone-text.pink");
    await expect(count.locator("i.fa-at[aria-hidden='true']")).toHaveCount(1);
    await expect(count.locator(".sr-only")).toHaveCount(1);
  },
);

const stat = (page: Page, name: string) => page.locator(".stat").filter({ has: page.getByText(name, { exact: true }) });

Given("the post {string} is a draft again", async ({ app }, title: string) => {
  await app.sql`UPDATE posts SET status = 'draft', published_at = NULL WHERE title = ${title}`;
});

function moment(value: string) {
  const at = cell(value);
  return at instanceof Date ? at : new Date(value);
}

Given("LinkedIn takes the cross-post as {string}", ({ stub }, id: string) => {
  stub.reply("POST", "/linkedin/api/rest/posts", { body: "", headers: { "x-restli-id": id }, status: 201 });
});

Then("Bluesky got the cross-post text {string}", async ({ stub }, text: string) => {
  const written = () =>
    heard(stub)
      .filter(({ method, url }) => method === "POST" && url.pathname.endsWith("/com.atproto.repo.putRecord"))
      .map(({ body }) => JSON.parse(body).record?.text);
  await expect.poll(written).toEqual([expand(text)]);
});
