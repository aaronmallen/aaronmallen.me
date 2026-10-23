import { request as httpRequest } from "node:http";
import { expect } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import type postgres from "postgres";
import { heard } from "../support/delivery.ts";
import { cell, slugFor } from "../support/rows.ts";
import { Given, Then, When } from "../support/world.ts";

async function postLinking(sql: postgres.Sql, site: string, title: string, urls: string, published: boolean) {
  const hrefs = urls
    .split("\n")
    .map((url) => url.trim().replace("{site}", site))
    .filter(Boolean);
  await sql`
    INSERT INTO posts ${sql({
      body: `A post called ${title}.`,
      body_html: hrefs.map((href) => `<p>See <a href="${href}">a note</a>.</p>`).join("\n"),
      published_at: published ? new Date(Date.now() - 86_400_000) : null,
      read_time: 1,
      slug: slugFor(title),
      status: published ? "published" : "draft",
      title,
      webmentions_enabled: false,
      word_count: 4,
    })}
  `;
}

function sharesHost(url: string, code: string) {
  return new Promise<{ location?: string; status?: number }>((done, fail) => {
    const { port } = new URL(url);
    httpRequest({ headers: { Host: "shares.localhost" }, host: "127.0.0.1", path: `/${code}`, port }, (response) => {
      response.resume();
      done({ location: response.headers.location, status: response.statusCode });
    })
      .on("error", fail)
      .end();
  });
}

Given("a published post {string} that links to:", async ({ app }, title: string, urls: string) => {
  await postLinking(app.sql, app.url, title, urls, true);
});

Given("a draft post {string} that links to:", async ({ app }, title: string, urls: string) => {
  await postLinking(app.sql, app.url, title, urls, false);
});

Given("these short links:", async ({ app }, table: DataTable) => {
  for (const row of table.hashes()) {
    const [code] = await app.sql`INSERT INTO short_codes ${app.sql({ code: row.code })} RETURNING id`;
    const link: Record<string, unknown> = {
      click_count: Number(row.clicks ?? 0),
      created_at: cell(row.made ?? "now"),
      destination: row.destination,
      short_code_id: code.id,
    };
    if (row.title) link.title = row.title;
    if (row.retargeted) link.retargeted_at = cell(row.retargeted);
    if (row.last_clicked) link.last_clicked_at = cell(row.last_clicked);
    await app.sql`INSERT INTO short_links ${app.sql(link)}`;
  }
});

Given("the clipboard is watched", async ({ page }) => {
  await page.addInitScript(() => {
    const copied: string[] = [];
    Object.assign(window, { copiedKeys: copied });
    Object.defineProperty(navigator, "clipboard", {
      value: {
        write: async (items: ClipboardItem[]) => {
          for (const item of items) copied.push(await (await item.getType("text/plain")).text());
        },
        writeText: async (text: string) => {
          copied.push(text);
        },
      },
    });
  });
});

When("I post to {string} from the admin", async ({ answer, page }, path: string) => {
  const token = await page.locator("input[name='_csrf_token']").first().inputValue();
  const response = await page.request.post(path, { headers: { "X-CSRF-Token": token }, maxRedirects: 0 });
  const result = { body: await response.text(), status: response.status() };
  Object.assign(answer, { ...result });
});

When("a script shortens {string} as {string}", async ({ answer, page }, destination: string, code: string) => {
  const result = await page.evaluate(
    async ([url, short]) => {
      const token = (document.querySelector("input[name='_csrf_token']") as HTMLInputElement).value;
      const body = new URLSearchParams({ "link[code]": short, "link[destination]": url });
      const response = await fetch("/admin/links", {
        body,
        headers: { Accept: "application/json", "X-CSRF-Token": token },
        method: "POST",
      });
      return { body: await response.text(), status: response.status };
    },
    [destination, code],
  );
  Object.assign(answer, { ...result });
});

Then("that answers {int}", ({ answer }, status: number) => {
  expect(answer.status, answer.body).toBe(status);
});

Then("the clipboard holds {string}", async ({ page }, text: string) => {
  await expect
    .poll(() => page.evaluate(() => (window as unknown as { copiedKeys: string[] }).copiedKeys))
    .toEqual([text]);
});

Then("nothing is copied", async ({ page }) => {
  expect(await page.evaluate(() => (window as unknown as { copiedKeys: string[] }).copiedKeys)).toEqual([]);
});

Then("a copy button holds {string}", async ({ page }, key: string) => {
  await expect(
    page.locator(`[data-record-key="${key.replaceAll("\\", "\\\\").replaceAll('"', '\\"')}"]`).first(),
  ).toBeAttached();
});

Then("the publish tabs read {string}", async ({ page }, hrefs: string) => {
  const found = await page
    .locator(".screen-tabs a.screen-tab")
    .evaluateAll((tabs) => tabs.map((tab) => tab.getAttribute("href")));
  expect(found.join(" ")).toBe(hrefs);
});

Then("the short link rows read {string}", async ({ page }, titles: string) => {
  await expect(page.locator(".link-row-title")).toHaveText(titles ? titles.split(", ") : []);
});

Then(
  "the short link row {string} shows a {word} pill reading {string}",
  async ({ page }, title: string, color: string, text: string) => {
    const row = page.locator(".link-row").filter({ has: page.locator(".link-row-title", { hasText: title }) });
    await expect(row.locator(`.pill${color === "plain" ? "" : `.${color}`}`)).toContainText(text);
  },
);

Then("the short link {string} sends visitors to {string}", async ({ app }, code: string, destination: string) => {
  const { location, status } = await sharesHost(app.url, code);
  expect([status, location]).toEqual([302, destination]);
});

Then("the short link {string} answers 404", async ({ app }, code: string) => {
  expect((await sharesHost(app.url, code)).status).toBe(404);
});

When("I close the link drawer with Escape", async ({ page }) => {
  await page.keyboard.press("Escape");
});

Then("the link field {string} holds {string}", async ({ page }, label: string, value: string) => {
  await expect(page.getByLabel(label, { exact: true }).locator("visible=true").first()).toHaveValue(value);
});

Then("the broken links filter is checked", async ({ page }) => {
  await expect(page.locator(".seg input[name='status'][value='broken']")).toBeChecked();
});

Then("the post list shows {string} and not {string}", async ({ page }, shown: string, hidden: string) => {
  await expect(page.locator(".post-list .li-title", { hasText: shown })).toHaveCount(1);
  await expect(page.locator(".post-list .li-title", { hasText: hidden })).toHaveCount(0);
});

Then("the failing links read {string}", async ({ page }, urls: string) => {
  const rows = page.locator(".post-broken-links .li");
  await expect(rows.locator(".li-sub").first()).toBeVisible();
  const found = await rows.evaluateAll((items) =>
    items.map((item) => item.querySelector(".li-sub")?.textContent?.trim()),
  );
  expect(found.join(", ")).toBe(urls);
});

Then(
  "the first failing link shows a pink pill reading {string}, the reason {string} and {string}",
  async ({ page }, pill: string, reason: string, first: string) => {
    const row = page.locator(".post-broken-links .li").first();
    await expect(row.locator(".pill.pink")).toContainText(pill);
    await expect(row.locator(".post-link-reason")).toContainText(reason);
    await expect(row).toContainText(first);
    await expect(row.locator("time").first()).toBeAttached();
  },
);

Then(
  "the first failing link offers to fix it at {string} and to open {string}",
  async ({ page }, fix: string, url: string) => {
    const row = page.locator(".post-broken-links .li").first();
    await expect(row.locator(`button[form='broken-links-check'][value='${url}']`)).toBeAttached();
    await expect(row.locator(`a[href='${fix}'][title='Fix in post: ${url}']`)).toBeAttached();
    await expect(row.locator(`a[href='${url}'][target='_blank']`)).toBeAttached();
  },
);

Then(
  "the post row {string} carries a(n) {word} tag {string}",
  async ({ page }, title: string, color: string, text: string) => {
    const row = page.locator(".post-list .li", { hasText: title });
    await expect(row.locator(`.post-row-meta .tone-text.${color}`)).toContainText(text);
  },
);

Then("the post row {string} carries no failing tag", async ({ page }, title: string) => {
  const row = page.locator(".post-list .li", { hasText: title });
  await expect(row).toBeVisible();
  await expect(row.getByText("failing")).toHaveCount(0);
});

Then("the short links card says {string} and lists {string} only", async ({ page }, side: string, url: string) => {
  const card = page.locator(".post-broken-short");
  await expect(card.locator(".card-side")).toContainText(side);
  await expect(card.locator(".li")).toHaveCount(1);
  await expect(card.locator(".li .li-sub").first()).toHaveText(url);
});

Then(
  "the short links card shows an orange pill reading {string} and the reason {string}",
  async ({ page }, pill: string, reason: string) => {
    const card = page.locator(".post-broken-short");
    await expect(card.locator(".pill.orange")).toContainText(pill);
    await expect(card.locator(".post-link-reason")).toContainText(reason);
  },
);

Then(
  "the short links card offers to change the destination at {string} and to open {string}",
  async ({ page }, edit: string, url: string) => {
    const card = page.locator(".post-broken-short");
    const id = edit.split("/")[3];
    await expect(
      card.locator(`button[form='broken-links-check'][formaction='/admin/links/${id}/check']`),
    ).toBeAttached();
    await expect(card.locator(`a[href='${edit}'][title='Change destination: ${url}']`)).toBeAttached();
    await expect(card.locator(`a[href='${url}'][target='_blank']`)).toBeAttached();
  },
);

Then("the link check banner comes back to {string}", async ({ page }, path: string) => {
  await expect(page.locator(".link-check-banner input[name=return_to]")).toHaveValue(path);
});

When("the post link check of {string} passes behind the page", async ({ app }, url: string) => {
  await app.sql`UPDATE post_link_checks SET failures = 0, reason = NULL, first_failed_at = NULL WHERE url = ${url}`;
});

When("the short link check of {string} passes behind the page", async ({ app }, url: string) => {
  await app.sql`UPDATE short_link_checks SET failures = 0, reason = NULL, first_failed_at = NULL WHERE url = ${url}`;
});

When("I press the check again button for {string}", async ({ page }, url: string) => {
  await page
    .getByRole("button", { exact: true, name: `Check again: ${url}` })
    .first()
    .click();
});

When("I press the first check again button for {string}", async ({ page }, url: string) => {
  await page
    .getByRole("button", { exact: true, name: `Check again: ${url}` })
    .first()
    .click();
});

When("I press the last check again button for {string}", async ({ page }, url: string) => {
  await page
    .getByRole("button", { exact: true, name: `Check again: ${url}` })
    .last()
    .click();
});

When("I fill in the link {string} with {string}", async ({ page }, label: string, value: string) => {
  await page.getByLabel(label, { exact: true }).locator("visible=true").first().fill(value);
});

When("I pick the {string} option", async ({ page }, name: string) => {
  await page.getByText(name, { exact: true }).locator("visible=true").first().click();
});

const bareRows: Record<string, [string, (n: number) => Record<string, unknown>]> = {
  artifact: ["artifacts", (n) => ({ title: `Artifact ${n}`, type: "plan" })],
  commit: [
    "commits",
    (n) => ({
      branch: "main",
      commit_date: "2026-10-01",
      commit_time: "09:00",
      message: `Commit ${n}`,
      repo: "o/r",
      sha: `sha${n}`,
    }),
  ],
  decision: ["decisions", (n) => ({ problem: "Which way?", title: `Decision ${n}` })],
  journal_entry: [
    "journal_entries",
    (n) => ({ body: `Entry ${n}`, body_html: `<p>Entry ${n}</p>`, entry_date: "2026-10-01", entry_time: "09:00" }),
  ],
  memory_file: ["memory_files", (n) => ({ description: "Facts", path: `facts-${n}.md`, scope: "global" })],
  note: ["notes", (n) => ({ title: `Note ${n}` })],
  note_folder: ["note_folders", (n) => ({ name: `Folder ${n}` })],
  post: [
    "posts",
    (n) => ({
      body: "",
      body_html: "",
      read_time: 1,
      slug: `post-${n}`,
      title: `Post ${n}`,
      webmentions_enabled: false,
      word_count: 0,
    }),
  ],
  project: ["projects", (n) => ({ key: `PR${n}`, name: `Project ${n}`, visibility: "private" })],
  pull_request: [
    "pull_requests",
    (n) => ({
      number: n,
      opened_at: new Date(),
      repo: "o/r",
      title: `PR ${n}`,
      url: `https://github.com/o/r/pull/${n}`,
    }),
  ],
  social_post: ["social_posts", () => ({ targets: "{mastodon}" })],
  task: ["tasks", (n) => ({ list: "next", number: n, position: n, title: `Task ${n}` })],
  work_entry: ["work_entries", (n) => ({ from_year: 2020, org: `Org ${n}`, position: n, role: "Engineer" })],
};

async function bareRow(sql: postgres.Sql, kind: string) {
  const [table, row] = bareRows[kind];
  if (kind === "mail_thread") {
    const [account] =
      await sql`INSERT INTO mail_accounts ${sql({ name: "Mail", provider: "contact_form" })} RETURNING id`;
    const [thread] =
      await sql`INSERT INTO mail_threads ${sql({ mail_account_id: account.id, subject: "Hello" })} RETURNING id`;
    return thread.id as number;
  }
  const [{ count }] = await sql`SELECT count(*)::int AS count FROM ${sql(table)}`;
  const [made] = await sql`INSERT INTO ${sql(table)} ${sql(row(count + 1))} RETURNING id`;
  return made.id as number;
}

bareRows.mail_thread = ["mail_threads", () => ({})];

Given("a bare {word} row", async ({ app }, kind: string) => {
  await bareRow(app.sql, kind);
});

Given("a bare {word} row linked to a bare decision and a bare post", async ({ app }, kind: string) => {
  const id = await bareRow(app.sql, kind);
  for (const other of ["decision", "post"].filter((name) => name !== kind)) {
    const otherId = await bareRow(app.sql, other);
    const [left, right] = [
      [kind, id],
      [other, otherId],
    ].sort(([one], [two]) => (kindOrder.indexOf(String(one)) < kindOrder.indexOf(String(two)) ? -1 : 1));
    await app.sql`
      INSERT INTO record_links ${app.sql({ left_id: left[1], left_kind: left[0], right_id: right[1], right_kind: right[0] })}
    `;
  }
});

const kindOrder = [
  "task",
  "post",
  "social_post",
  "journal_entry",
  "commit",
  "project",
  "work_entry",
  "decision",
  "pull_request",
  "mail_thread",
  "memory_file",
  "artifact",
  "note",
  "note_folder",
];

When("the {word} row {int} is deleted", async ({ app }, kind: string, id: number) => {
  await app.sql`DELETE FROM ${app.sql(bareRows[kind][0])} WHERE id = ${id}`;
});

When("I write a raw record_links row:", async ({ answer, app }, table: DataTable) => {
  try {
    await app.sql`INSERT INTO record_links ${app.sql(table.hashes()[0])}`;
    Object.assign(answer, { body: "", status: 0 });
  } catch (error) {
    Object.assign(answer, { body: String(error), status: 1 });
  }
});

Then("the database refuses it with {string}", ({ answer }, text: string) => {
  expect(answer.status).toBe(1);
  expect(answer.body).toContain(text);
});

Then("task {int} sits in project {int}", async ({ app }, task: number, project: number) => {
  await expect
    .poll(async () => (await app.sql`SELECT project_id FROM tasks WHERE id = ${task}`)[0].project_id)
    .toBe(project);
});

Then("task {int} sits in no project", async ({ app }, task: number) => {
  await expect
    .poll(async () => (await app.sql`SELECT project_id FROM tasks WHERE id = ${task}`)[0].project_id)
    .toBeNull();
});

Then("the links page holds {string}", async ({ page }, selector: string) => {
  await expect(page.locator(selector).first()).toBeAttached();
});

When("I follow the next page of short links", async ({ page }) => {
  await page.locator("nav.pager a[rel='next']").click();
});

Given("the web answers GET {string} with a redirect to {string}", ({ stub }, url: string, location: string) => {
  stub.reply("GET", url, { body: "", headers: { Location: location }, status: 301 });
});

Given("the web holds its answer to GET {string} for {int} seconds", ({ stub }, url: string, seconds: number) => {
  stub.reply("GET", url, { body: "<p>late</p>", delay: seconds * 1000, status: 200 });
});

Given(
  "the web answers GET {string} with status {int} and a long body still to come",
  ({ stub }, url: string, status: number) => {
    stub.reply("GET", url, { body: "x", headers: { "Content-Length": "5000000" }, status });
  },
);

Then(
  "the link check of {string} records {int} failure(s) with the reason {string}, waiting up to {int} seconds",
  async ({ app }, url: string, failures: number, reason: string, seconds: number) => {
    await expect
      .poll(async () => (await app.sql`SELECT failures, reason FROM post_link_checks WHERE url = ${url}`)[0], {
        timeout: seconds * 1000,
      })
      .toEqual({ failures, reason: reason === "null" ? null : reason });
  },
);

Then("the link check asked for {string} naming the site and the link check", async ({ app, stub }, url: string) => {
  await expect
    .poll(() => heard(stub).find((request) => request.url.href === url)?.headers["user-agent"])
    .toBe(`${new URL(app.url).hostname} link-check (+${app.url})`);
});

Then(
  "the link check of {string} records {int} failure(s) with a reason holding {string}",
  async ({ app }, url: string, failures: number, reason: string) => {
    await expect
      .poll(async () => (await app.sql`SELECT failures, reason FROM post_link_checks WHERE url = ${url}`)[0], {
        timeout: 15_000,
      })
      .toMatchObject({ failures, reason: expect.stringContaining(reason) });
  },
);
