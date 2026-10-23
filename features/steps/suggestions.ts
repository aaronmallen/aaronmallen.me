import { expect, type Page } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import type postgres from "postgres";
import { insertRows } from "../support/rows.ts";
import { Given, Then, When } from "../support/world.ts";

const hour = 3_600_000;

const expand = (text: string, site: string) =>
  text
    .replaceAll(/\{(.)\*(\d+)\}/g, (_, letter: string, count: string) => letter.repeat(Number(count)))
    .replaceAll("{site}", site)
    .replaceAll("{newline}", "\n")
    .replaceAll("{em space}", " ")
    .replaceAll("{nbsp}", " ");

const postedAt: Record<string, Date | null> = {
  draft: null,
  due: new Date(),
  posted: new Date(Date.now() - hour),
  published: new Date(Date.now() - hour),
  scheduled: new Date(Date.now() + hour),
};

function chicagoDay(daysAgo: number) {
  const day = new Date(Date.now() - daysAgo * 24 * hour);
  return new Intl.DateTimeFormat("en-CA", { timeZone: "America/Chicago" }).format(day);
}

const days: Record<string, number> = { "a week ago": 7, today: 0, yesterday: 1 };

async function nextPostNumber(sql: postgres.Sql) {
  const [{ count }] = await sql`SELECT count(*)::int AS count FROM posts`;
  return count + 1;
}

Given("a {word} post that reads {string}", async ({ app }, status: string, body: string) => {
  const title = `Post ${await nextPostNumber(app.sql)}`;
  const published_at = { draft: "null", published: "1 hour ago", scheduled: "in 1 hour" }[status] ?? "null";
  await insertRows(app.sql, "posts", [{ body: expand(body, app.url), published_at, status, title }]);
});

async function composeSocialPost(sql: postgres.Sql, status: string, targets: string, parts: string[]) {
  const [{ id }] = await sql`
    INSERT INTO social_posts ${sql({
      posted_at: postedAt[status],
      status: status === "due" ? "scheduled" : status,
      targets: `{${targets.split(" and ").join(",")}}`,
    })}
    RETURNING id
  `;
  for (const [index, body] of parts.entries()) {
    await sql`INSERT INTO social_post_parts ${sql({ body, position: index + 1, social_post_id: id })}`;
  }
}

Given(
  "a {word} social post to {string} that reads {string}",
  async ({ app }, status: string, targets: string, body: string) => {
    await composeSocialPost(app.sql, status, targets, [expand(body, app.url)]);
  },
);

Given(
  "a {word} social post to {string} with the parts:",
  async ({ app }, status: string, targets: string, parts: DataTable) => {
    await composeSocialPost(
      app.sql,
      status,
      targets,
      parts.raw().map(([body]) => expand(body, app.url)),
    );
  },
);

Given("a person {string} on Bluesky as {string}", async ({ app }, key: string, handle: string) => {
  await app.sql`INSERT INTO people ${app.sql({ bluesky_did: `did:plc:${key}`, bluesky_handle: handle, key, name: key })}`;
});

async function suggest(sql: postgres.Sql, site: string, target: Record<string, number>, edits: DataTable) {
  const [{ id }] = await sql`INSERT INTO suggestions ${sql(target)} RETURNING id`;
  for (const [index, edit] of edits.hashes().entries()) {
    await sql`
      INSERT INTO suggestion_edits ${sql({
        original: expand(edit.original, site),
        part: edit.part ? Number(edit.part) : null,
        position: index + 1,
        reason: edit.reason || "typo",
        replacement: expand(edit.replacement, site),
        status: edit.status || "pending",
        suggestion_id: id,
      })}
    `;
  }
}

Given("the suggested edits for post {int}:", async ({ app }, id: number, edits: DataTable) => {
  await suggest(app.sql, app.url, { post_id: id }, edits);
});

Given("the suggested edits for social post {int}:", async ({ app }, id: number, edits: DataTable) => {
  await suggest(app.sql, app.url, { social_post_id: id }, edits);
});

async function csrfToken(page: Page) {
  const html = await (await page.request.get("/admin/posts/new")).text();
  const input = html.match(/<input[^>]*name="_csrf_token"[^>]*>/)?.[0] ?? "";
  return input.match(/value="([^"]+)"/)?.[1] ?? "";
}

type Answered = { answer: { body: string; status: number }; page: Page };

async function postForm({ answer, page }: Answered, path: string, form: string, csrf = true) {
  const fields = new URLSearchParams(form);
  if (csrf) fields.set("_csrf_token", await csrfToken(page));
  const response = await page.request.post(path, {
    data: fields.toString(),
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    maxRedirects: 0,
  });
  const location = response.headers().location ?? "";
  Object.assign(answer, { body: location, status: response.status() });
}

const paths: Record<string, string> = { post: "/admin/posts", "social post": "/admin/social" };

for (const target of ["post", "social post"]) {
  When(`I {word} every suggested edit on ${target} {int}`, ({ answer, page }, decision: string, id: number) =>
    postForm({ answer, page }, `${paths[target]}/${id}/suggestions/${decision}`, ""),
  );

  When(
    `I {word} suggested edit {string} on ${target} {int}`,
    ({ answer, page }, decision: string, editId: string, id: number) =>
      postForm(
        { answer, page },
        `${paths[target]}/${id}/suggestions/${decision}`,
        `edit_id=${encodeURIComponent(editId)}`,
      ),
  );

  Then(`the edits on ${target} {int} stand as {string}`, async ({ app }, id: number, statuses: string) => {
    const column = target === "post" ? "post_id" : "social_post_id";
    const rows = await app.sql`
      SELECT suggestion_edits.status FROM suggestion_edits
      JOIN suggestions ON suggestions.id = suggestion_edits.suggestion_id
      WHERE suggestions.${app.sql(column)} = ${id}
      ORDER BY suggestion_edits.id
    `;
    expect(rows.map((row) => row.status).join(" ")).toBe(statuses);
  });
}

When(
  "I {word} every suggested edit on social post {int} from the {string} filter",
  ({ answer, page }, decision: string, id: number, filter: string) =>
    postForm({ answer, page }, `/admin/social/${id}/suggestions/${decision}`, `filter=${filter}`),
);

When("I send the suggestion form {string} to {string}", ({ answer, page }, form: string, path: string) =>
  postForm({ answer, page }, path, form),
);

When("I send the suggestion form to {string} without a CSRF token", ({ answer, page }, path: string) =>
  postForm({ answer, page }, path, "", false),
);

When("a visitor sends a suggestion decision to {string}", async ({ answer, request }, path: string) => {
  const response = await request.post(path, { maxRedirects: 0 });
  Object.assign(answer, { body: "", status: response.status() });
});

Then("the suggestion decision answers {int}", ({ answer }, status: number) => {
  expect(answer.status).toBe(status);
});

Then("the suggestion decision sends me to {string}", ({ answer }, path: string) => {
  expect(answer.status).toBe(302);
  const location = new URL(answer.body ?? "", "http://site");
  expect(`${location.pathname}${location.search}`).toBe(path);
});

When("I follow the suggestion decision", async ({ answer, page }) => {
  await page.goto(answer.body ?? "/");
});

Then("the suggestion toast says {string}", async ({ page }, text: string) => {
  await expect(page.locator("[data-toast] .toast")).toHaveText(text);
});

Then("no suggestion toast shows", async ({ page }) => {
  await expect(page.locator("[data-toast] .toast")).toHaveCount(0);
});

When("I write the post body {string} and save the draft", async ({ app, page }, body: string) => {
  await page.getByLabel("Body", { exact: true }).fill(expand(body, app.url));
  await page.getByRole("button", { exact: true, name: "Save draft" }).click();
  await page.waitForLoadState();
});

Then("post {int} reads {string}", async ({ app }, id: number, body: string) => {
  const [post] = await app.sql`SELECT body FROM posts WHERE id = ${id}`;
  expect(post.body).toBe(expand(body, app.url));
});

Then("social post {int} has the parts:", async ({ app }, id: number, parts: DataTable) => {
  const rows = await app.sql`SELECT body FROM social_post_parts WHERE social_post_id = ${id} ORDER BY position`;
  expect(rows.map((row) => row.body)).toEqual(parts.raw().map(([body]) => expand(body, app.url)));
});

Then("no suggestion is stored for social post {int}", async ({ app }, id: number) => {
  expect(await app.sql`SELECT id FROM suggestions WHERE social_post_id = ${id}`).toHaveLength(0);
});

const drawer = (page: Page) => page.locator("dialog#post-suggestions");

Then("the editor shows no suggestions", async ({ page }) => {
  await expect(drawer(page)).toHaveCount(0);
});

Then("the editor holds the suggestions drawer headed {string}", async ({ page }, head: string) => {
  await expect(page.locator("dialog#post-suggestions[role='dialog'] .dialog-head")).toContainText(head);
});

Then("the suggestions banner says {string}", async ({ page }, text: string) => {
  await expect(page.locator(".post-banner")).toContainText(text);
});

Then("no suggestions banner shows", async ({ page }) => {
  await expect(page.locator(".post-banner")).toHaveCount(0);
});

Then("the suggestions drawer is open", async ({ page }) => {
  await expect(page.locator("dialog#post-suggestions[open]")).toBeVisible();
});

Then("the suggestions drawer is shut", async ({ page }) => {
  await expect(page.locator("dialog#post-suggestions[open]")).toHaveCount(0);
});

When("I review the suggestions", async ({ page }) => {
  await page.locator(".post-banner").getByRole("button", { name: "Review" }).click();
});

const suggestionsBox = (page: Page) => page.locator("dialog#post-suggestions[open], [data-social-suggestions]").first();

When("I press {string} on the first suggestion", async ({ page }, name: string) => {
  await suggestionsBox(page).locator(".sg-actions").first().getByRole("button", { exact: true, name }).click();
});

When("I press {string} for every suggestion", async ({ page }, name: string) => {
  await suggestionsBox(page).getByRole("button", { exact: true, name }).click();
});

Then("the suggestions show {int} edit(s)", async ({ page }, count: number) => {
  await expect(suggestionsBox(page).locator(".sg-edit")).toHaveCount(count);
});

Then("the suggestions read:", async ({ page }, rows: DataTable) => {
  const wanted = rows.hashes();
  await expect(page.locator(".sg-diff del")).toHaveText(wanted.map((row) => row.before));
  await expect(page.locator(".sg-diff ins")).toHaveText(wanted.map((row) => row.after).filter(Boolean));
  if ("reason" in wanted[0]) await expect(page.locator(".sg-reason")).toHaveText(wanted.map((row) => row.reason));
});

Then("the suggested edits offer {string}", async ({ page }, buttons: string) => {
  await expect(page.locator(".sg-actions button")).toHaveText(buttons.split(" "));
});

Then("the suggestions offer {string} for every edit", async ({ page }, buttons: string) => {
  const bulk = page.locator("#post-suggestions .dialog-foot button, [data-social-suggestions] .card-side button");
  await expect(bulk).toHaveText(buttons.split(", "));
});

Then("the suggested edit is marked {string}", async ({ page }, text: string) => {
  await expect(page.locator(".sg-edit .tone-text").first()).toContainText(text);
});

Then("the accepted text fills the body field as {string}", async ({ page }, body: string) => {
  await expect(page.getByLabel("Body", { exact: true })).toHaveValue(body);
});

Then("the accepted text shows in the preview as {string}", async ({ page }, text: string) => {
  await expect(page.locator(".preview .prose p")).toHaveText(text);
});

Then("the toast shows above the suggestions drawer", async ({ page }) => {
  await expect(page.locator(".toast")).toBeVisible();
  const onTop = await page.evaluate(() => {
    const toast = document.querySelector(".toast");
    if (!toast) return false;
    const box = toast.getBoundingClientRect();
    return toast.contains(document.elementFromPoint(box.x + box.width / 2, box.y + box.height / 2));
  });
  expect(onTop).toBe(true);
});

Then("the editor keeps the edit note box and dialog", async ({ page }) => {
  await expect(
    page.locator(".editor-main > [data-markdown-editor]:has(#post-body[data-post-body]) + .card"),
  ).toHaveCount(1);
  await expect(page.locator("form[data-post-editor] dialog[data-edit-note-dialog]")).toHaveCount(1);
});

Then("the editor offers no suggestion decisions for post {int}", async ({ page }, id: number) => {
  await expect(page.locator(`form[action^='/admin/posts/${id}/suggestions']`)).toHaveCount(0);
});

When(
  "I press Accept on the first suggestion with an unsaved title, noting what the browser sends",
  async ({ answer, page }) => {
    await page.locator("#post-title").fill("Unsaved title");
    const sent = page.waitForRequest((request) => request.method() === "POST");
    await drawerOrBanner(page);
    await page.locator(".sg-actions").first().getByRole("button", { exact: true, name: "Accept" }).click();
    const body = (await sent).postData() ?? "";
    Object.assign(answer, { body, status: 0 });
  },
);

async function drawerOrBanner(page: Page) {
  if (!(await page.locator("dialog#post-suggestions[open]").count())) {
    await page.locator(".post-banner").getByRole("button", { name: "Review" }).click();
  }
}

Then("the browser sent only the edit and the CSRF token", ({ answer }) => {
  const fields = [...new URLSearchParams(answer.body).keys()].sort();
  expect(fields).toEqual(["_csrf_token", "edit_id"]);
});

Then("the social queue item counts {string}", async ({ page }, text: string) => {
  await expect(page.locator(".sq-suggestions").first()).toContainText(text);
});

Then("the social queue item counts no suggestions", async ({ page }) => {
  await expect(page.locator(".sq-suggestions", { hasText: "suggestion" })).toHaveCount(0);
});

Then("the social suggestions card shows", async ({ page }) => {
  await expect(page.locator(".card-label", { hasText: "Suggestions" })).toHaveCount(1);
});

Then("no social suggestions card shows", async ({ page }) => {
  await expect(page.locator(".card-label", { hasText: "Suggestions" })).toHaveCount(0);
});

Then("the social suggestions card sits above the composer", async ({ page }) => {
  await expect(page.locator(".side-stack > form:first-child .card-label", { hasText: "Suggestions" })).toHaveCount(1);
});

Then("the social suggestions name the parts {string}", async ({ page }, parts: string) => {
  await expect(page.locator(".sg-part")).toHaveText(parts.split(", "));
});

Then("the social suggestions name no part", async ({ page }) => {
  await expect(page.locator(".sg-part")).toHaveCount(0);
});

async function listOver(
  { answer, request, tokens }: { answer: Answered["answer"]; request: Page["request"]; tokens: { mcp?: string } },
  from: string,
  to: string,
) {
  const response = await request.post("/mcp", {
    data: {
      id: 1,
      jsonrpc: "2.0",
      method: "tools/call",
      params: { arguments: { from: chicagoDay(days[from]), to: chicagoDay(days[to]) }, name: "list_suggestions" },
    },
    headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${tokens.mcp}` },
  });
  const body = await response.text();
  const result = response.ok() ? JSON.parse(body).result : undefined;
  const mcp = {
    body,
    content: result?.content?.[0]?.text ?? body,
    error: result?.isError ?? false,
    status: response.status(),
  };
  Object.assign(answer, mcp);
  return JSON.parse(body);
}

When(
  "I ask MCP for the suggestions from {string} to {string}",
  ({ answer, request, tokens }, from: string, to: string) => listOver({ answer, request, tokens }, from, to),
);

When(
  "I ask the API for the suggestions from {string} to {string}",
  async ({ answer, request, tokens }, from: string, to: string) => {
    const query = new URLSearchParams({ from: chicagoDay(days[from]), to: chicagoDay(days[to]) });
    const response = await request.get(`/api/v1/suggestions?${query}`, {
      headers: { Accept: "application/json", Authorization: `Bearer ${tokens.api}` },
    });
    const body = await response.text();
    Object.assign(answer, { body, status: response.status() });
  },
);

const trusted = (value: unknown): unknown => {
  if (Array.isArray(value)) return value.map(trusted);
  if (value && typeof value === "object") {
    const record = value as Record<string, unknown>;
    if (record.untrusted === true && "text" in record) return record.text;
    return Object.fromEntries(Object.entries(record).map(([key, inner]) => [key, trusted(inner)]));
  }
  return value;
};

Then("the API answer is what MCP lists for today, unmarked", async ({ answer, request, tokens }) => {
  const api = JSON.parse(answer.body);
  const mcp = await listOver({ answer, request, tokens }, "today", "today");
  expect(api).toEqual(trusted(JSON.parse(mcp.result.content[0].text)));
});
