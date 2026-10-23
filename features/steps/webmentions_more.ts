import { execFileSync, spawnSync } from "node:child_process";
import { setTimeout as sleep } from "node:timers/promises";
import { expect, type Locator, type Page, type TestInfo } from "@playwright/test";
import { createBdd, type DataTable } from "playwright-bdd";
import { heard } from "../support/delivery.ts";
import { cell, slugFor } from "../support/rows.ts";
import {
  expand,
  lastRun,
  postId,
  runCount,
  runJob,
  stubKey,
  submitForm,
  unwrap,
  verifyJob,
  waitForRuns,
} from "../support/webmentions_more.ts";
import { Given, Then, test, When } from "../support/world.ts";

const { After } = createBdd(test);

async function pressAndLand(page: Page, button: Locator) {
  const posted = page.waitForResponse(
    (response) =>
      response.request().method() === "POST" && new URL(response.url()).pathname.startsWith("/admin/webmentions"),
  );
  await button.click();
  await posted;
  await page.waitForURL((url) => url.pathname.startsWith("/admin/"));
  await page.waitForLoadState();
}

type State = { statuses: number[]; verifies: number };

const states = new WeakMap<TestInfo, State>();
const state = (info: TestInfo) => {
  if (!states.has(info)) states.set(info, { statuses: [], verifies: 0 });
  return states.get(info) as State;
};

const sendJob = "Social::Jobs::SendWebmentions";

// Data

Given("the webmention setting {word} is {word}", async ({ app }, name: string, value: string) => {
  await app.sql`
    INSERT INTO webmention_settings ${app.sql({ id: 1, [name]: value === "on" })}
    ON CONFLICT (id) DO UPDATE SET ${app.sql({ [name]: value === "on" })}
  `;
});

Given("the webmention single-author hosts are {string}", async ({ app }, hosts: string) => {
  const list = `{${hosts}}`;
  await app.sql`
    INSERT INTO webmention_settings ${app.sql({ id: 1, single_author_hosts: list })}
    ON CONFLICT (id) DO UPDATE SET single_author_hosts = ${list}
  `;
});

Given("a published post {string} taking webmentions", async ({ app }, title: string) => {
  const body = `A post called ${title}.`;
  await app.sql`
    INSERT INTO posts ${app.sql({
      body,
      body_html: `<p>${body}</p>`,
      published_at: new Date(Date.now() - 3_600_000),
      read_time: 1,
      slug: slugFor(title),
      status: "published",
      title,
      webmentions_enabled: true,
      word_count: 5,
    })}
  `;
});

Given("these webmentions on the post {string}:", async ({ app }, title: string, table: DataTable) => {
  const post_id = await postId(app, title);
  let count = (await app.sql`SELECT count(*)::int AS count FROM webmentions`)[0].count;
  for (const row of table.hashes()) {
    count += 1;
    const values = Object.fromEntries(Object.entries(row).map(([column, value]) => [column, cell(value)]));
    await app.sql`
      INSERT INTO webmentions ${app.sql({
        author_name: `Author ${count}`,
        author_url: `http://203.0.113.${100 + (count % 100)}/about-${count}`,
        excerpt: `Note ${count}`,
        post_id,
        source_url: `http://203.0.113.${100 + (count % 100)}/notes/${count}`,
        type: "mention",
        ...values,
      })}
    `;
  }
});

Given(
  "{int} {word} webmentions on the post {string}",
  async ({ app }, count: number, status: string, title: string) => {
    const post_id = await postId(app, title);
    const rows = Array.from({ length: count }, (_, index) => ({
      author_name: `Author ${index + 1}`,
      author_url: `http://203.0.113.50/author-${index + 1}`,
      post_id,
      received_at: new Date(Date.now() - (index + 1) * 60_000),
      source_url: `http://203.0.113.50/notes/${index + 1}`,
      status,
      type: "mention",
    }));
    await app.sql`INSERT INTO webmentions ${app.sql(rows)}`;
  },
);

Given("the trusted author {string}", async ({ app }, url: string) => {
  await app.sql`INSERT INTO trusted_authors ${app.sql({ author_url: url })}`;
});

Given("the trusted author {string} added {string}", async ({ app }, url: string, when: string) => {
  await app.sql`INSERT INTO trusted_authors ${app.sql({ author_url: url, created_at: cell(when) })}`;
});

Given("the post {string} turns webmentions off", async ({ app }, title: string) => {
  await app.sql`UPDATE posts SET webmentions_enabled = false WHERE title = ${title}`;
});

Given("the webmention from {string} is {word}", async ({ app }, source: string, status: string) => {
  await app.sql`UPDATE webmentions SET status = ${status} WHERE source_url = ${expand(source, app.url)}`;
});

Given("the webmention by {string} was {word} before", async ({ app }, author: string, status: string) => {
  const body = "Another post.";
  const [post] = await app.sql`
    INSERT INTO posts ${app.sql({
      body,
      body_html: `<p>${body}</p>`,
      published_at: new Date(),
      read_time: 1,
      slug: "another",
      status: "published",
      title: "Another",
      webmentions_enabled: true,
      word_count: 2,
    })}
    RETURNING id
  `;
  await app.sql`
    INSERT INTO webmentions ${app.sql({ author_url: author, post_id: post.id, source_url: `${author}/old`, status, type: "mention" })}
  `;
});

Given("the trusted author {string} with auto-approve off", async ({ app }, url: string) => {
  await app.sql`INSERT INTO trusted_authors ${app.sql({ author_url: url })}`;
  await app.sql`INSERT INTO webmention_settings ${app.sql({ auto_approve_known_authors: false, id: 1 })}`;
});

Given("the trusted author {string} was removed", async ({ app }, url: string) => {
  await app.sql`INSERT INTO trusted_authors ${app.sql({ author_url: url })}`;
  await app.sql`DELETE FROM trusted_authors WHERE author_url = ${url}`;
});

Given("the source page {string} stops linking", ({ app, stub }, url: string) => {
  stub.reply("GET", stubKey(expand(url, app.url)), { body: "<p>nothing here</p>", status: 200 });
});

When("the webmention check runs for {string} on the post {string}", async ({ app }, source: string, title: string) => {
  const id = await postId(app, title);
  await runJob(app, verifyJob, expand(source, app.url), `${app.url}/writing/${slugFor(title)}`, id);
});

When("the held webmentions are queued", async ({ app }) => {
  await runJob(app, "Social::Jobs::QueueHeldWebmentions");
});

When("the webmention receipts are reaped", async ({ app }) => {
  await runJob(app, "Social::Jobs::ReapWebmentionReceipts");
});

Then("no webmention check has run", async ({ app }) => {
  await sleep(3000);
  expect(await runCount(app, verifyJob)).toBe(0);
});

// The outside web

Given("the source page {string} reads:", ({ app, stub }, url: string, html: string) => {
  stub.reply("GET", stubKey(expand(url, app.url)), { body: expand(html, app.url), status: 200 });
});

Given("the source page {string} answers {int}", ({ app, stub }, url: string, status: number) => {
  stub.reply("GET", stubKey(expand(url, app.url)), { body: "gone", status });
});

Given("the source page {string} redirects to {string}", ({ app, stub }, url: string, location: string) => {
  stub.reply("GET", stubKey(expand(url, app.url)), { body: "", headers: { Location: location }, status: 302 });
});

Given("the source page {string} moves for good to {string}", ({ app, stub }, url: string, location: string) => {
  stub.reply("GET", stubKey(expand(url, app.url)), { body: "", headers: { Location: location }, status: 301 });
});

Given(
  "the source page {string} redirects to {string} after {int} seconds",
  ({ app, stub }, url: string, location: string, seconds: number) => {
    stub.reply("GET", stubKey(expand(url, app.url)), {
      body: "",
      delay: seconds * 1000,
      headers: { Location: location },
      status: 302,
    });
  },
);

Given(
  "the source page {string} reads after {int} seconds:",
  ({ app, stub }, url: string, seconds: number, html: string) => {
    stub.reply("GET", stubKey(expand(url, app.url)), {
      body: expand(html, app.url),
      delay: seconds * 1000,
      status: 200,
    });
  },
);

Given(
  "the source page {string} sends the Link header {string} and reads:",
  ({ app, stub }, url: string, link: string, html: string) => {
    stub.reply("GET", stubKey(expand(url, app.url)), {
      body: expand(html, app.url),
      headers: { Link: link },
      status: 200,
    });
  },
);

Given("the source page {string} claims a body of {int} bytes", ({ app, stub }, url: string, bytes: number) => {
  stub.reply("GET", stubKey(expand(url, app.url)), {
    body: "x",
    headers: { "Content-Length": String(bytes) },
    status: 200,
  });
});

Given("the endpoint {string} answers after {int} seconds", ({ stub }, url: string, seconds: number) => {
  stub.reply("POST", stubKey(url), { body: "", delay: seconds * 1000, status: 202 });
});

Then(
  "the endpoint {string} was told about the post {string} for {string}",
  async ({ app, stub }, url: string, title: string, target: string) => {
    const told = () =>
      heard(stub)
        .filter((it) => it.method === "POST" && stubKey(it.url.href) === stubKey(url))
        .map((it) => Object.fromEntries(new URLSearchParams(it.body)));
    await expect.poll(told).toContainEqual({ source: `${app.url}/writing/${slugFor(title)}`, target });
  },
);

Then("the endpoint {string} was told {int} time(s)", ({ stub }, url: string, times: number) => {
  expect(heard(stub).filter((it) => it.method === "POST" && stubKey(it.url.href) === stubKey(url)).length).toBe(times);
});

Then("the web did not hear from the server at {string}", ({ stub }, url: string) => {
  expect(heard(stub).filter((it) => stubKey(it.url.href) === stubKey(url))).toEqual([]);
});

Then("the page {string} was read as the webmention agent asking for HTML", ({ app, stub }, url: string) => {
  const [read] = heard(stub).filter((it) => it.method === "GET" && stubKey(it.url.href) === stubKey(url));
  const site = new URL(app.url);
  expect([read?.headers["user-agent"], read?.headers.accept]).toEqual([
    `${site.hostname} webmention (+${app.url})`,
    "text/html, text/*;q=0.9, */*;q=0.8",
  ]);
});

Given("the endpoint {string} answers {int}", ({ stub }, url: string, status: number) => {
  stub.reply("POST", stubKey(url), { body: "", status });
});

Then("the stub was asked for {string}", ({ stub }, requests: string) => {
  expect(stub.misses().sort()).toEqual(requests ? requests.split(", ").sort() : []);
});

// Receiving

async function notify(
  { app, request }: { app: { url: string }; request: import("@playwright/test").APIRequestContext },
  source: string,
  target: string,
) {
  const response = await request.post("/webmention", {
    form: { source: expand(source, app.url), target: expand(target, app.url) },
    maxRedirects: 0,
  });
  return response.status();
}

When(
  "a webmention arrives from {string} for {string}",
  async ({ $testInfo, app, request }, source: string, target: string) => {
    const now = state($testInfo);
    if (!now.statuses.length) now.verifies = await runCount(app, verifyJob);
    now.statuses.push(await notify({ app, request }, source, target));
  },
);

When(
  "{int} webmentions arrive at once from {string} for {string}",
  async ({ $testInfo, app, request, stub }, count: number, source: string, target: string) => {
    const now = state($testInfo);
    now.verifies = await runCount(app, verifyJob);
    const sources = Array.from({ length: count }, (_, index) => `${expand(source, app.url)}/${index + 1}`);
    for (const url of sources) stub.reply("GET", stubKey(url), { body: "gone", status: 410 });
    now.statuses = await Promise.all(sources.map((url) => notify({ app, request }, url, target)));
  },
);

Then("the webmention endpoint answers {int}", ({ $testInfo }, status: number) => {
  expect(state($testInfo).statuses.at(-1)).toBe(status);
});

Then("{int} of them are taken and {int} are turned away", async ({ $testInfo }, taken: number, refused: number) => {
  const { statuses } = state($testInfo);
  expect([statuses.filter((it) => it === 202).length, statuses.filter((it) => it === 429).length]).toEqual([
    taken,
    refused,
  ]);
});

Then("the webmention checks finish", async ({ $testInfo, app }) => {
  const now = state($testInfo);
  await waitForRuns(app, verifyJob, now.verifies + now.statuses.filter((it) => it === 202).length);
});

Given("the webmention queue is down", async ({ $testInfo }) => {
  execFileSync("docker", ["pause", redisContainer($testInfo)]);
  paused.add(redisContainer($testInfo));
});

Given("the webmention queue is back", async ({ $testInfo }) => {
  execFileSync("docker", ["unpause", redisContainer($testInfo)]);
  paused.delete(redisContainer($testInfo));
});

const paused = new Set<string>();

After(() => {
  for (const container of paused) spawnSync("docker", ["unpause", container], { stdio: "ignore" });
  paused.clear();
});

const redisContainer = (info: TestInfo) =>
  `aaronmallen.me-features-ws${Number(process.env.WORKSPACE_ID ?? 0)}-w${info.parallelIndex}`;

// Verifying

When("the webmention check runs for {string}", async ({ app }, source: string) => {
  await runJob(app, verifyJob, expand(source, app.url), `${app.url}/writing/hello`, await postId(app, "Hello"));
});

When("the webmention check runs for {string} on a post that is gone", async ({ app }, source: string) => {
  await runJob(app, verifyJob, expand(source, app.url), `${app.url}/writing/hello`, 999_999);
});

Then("the check gives up quietly", async ({ app }) => {
  expect(await lastRun(app, verifyJob)).toMatchObject({ outcome: "succeeded" });
});

Then("the check fails so Sidekiq tries again", async ({ app }) => {
  expect(await lastRun(app, verifyJob)).toMatchObject({
    error_class: "Social::Jobs::VerifyWebmention::SourceUnreachable",
    outcome: "failed",
  });
});

Then("no webmention from {string} is stored", async ({ app }, source: string) => {
  const url = expand(source, app.url);
  expect(await app.sql`SELECT id FROM webmentions WHERE source_url = ${url}`).toEqual([]);
});

Then("the webmention from {string} has:", async ({ app }, source: string, table: DataTable) => {
  const url = expand(source, app.url);
  const [wanted] = table.hashes();
  const [row] = await app.sql`SELECT * FROM webmentions WHERE source_url = ${url}`;
  expect(row, `a webmention from ${url}`).toBeTruthy();
  const found = Object.fromEntries(
    Object.keys(wanted).map((column) => [column, row[column] === null ? "null" : String(row[column])]),
  );
  expect(found).toEqual(
    Object.fromEntries(Object.entries(wanted).map(([key, value]) => [key, expand(value, app.url)])),
  );
});

Then("the stored author name is {int} characters ending in {string}", async ({ app }, length: number, end: string) => {
  const [row] = await app.sql`SELECT author_name FROM webmentions`;
  expect([row.author_name.length, row.author_name.endsWith(end)]).toEqual([length, true]);
});

Then(
  "the stored {word} is {string} repeated {int} times then {string}",
  async ({ app }, column: string, chunk: string, times: number, tail: string) => {
    const [row] = await app.sql`SELECT ${app.sql(column)} AS value FROM webmentions`;
    expect(row.value).toBe(`${chunk.repeat(times)}${tail}`);
  },
);

Then(
  "the stored excerpt is at most {int} characters ending in {string}",
  async ({ app }, length: number, end: string) => {
    const [row] = await app.sql`SELECT excerpt FROM webmentions`;
    expect(row.excerpt.length).toBeLessThanOrEqual(length);
    expect(row.excerpt.endsWith(end)).toBe(true);
  },
);

// Sending

async function insertLinkingPost(app: { sql: import("postgres").Sql; url: string }, title: string, body: string) {
  await app.sql`
    INSERT INTO posts ${app.sql({
      body,
      body_html: `<p>${body}</p>`,
      published_at: new Date(Date.now() - 3_600_000),
      read_time: 1,
      slug: slugFor(title),
      status: "published",
      title,
      webmentions_enabled: true,
      word_count: body.split(" ").length,
    })}
  `;
}

Given("the post {string} links to {string}", async ({ app }, title: string, links: string) => {
  await insertLinkingPost(
    app,
    title,
    links
      .split(", ")
      .map((link) => `See [a note](${link}).`)
      .join("\n\n"),
  );
});

Given("the post {string} has the body {string}", async ({ app }, title: string, body: string) => {
  await insertLinkingPost(app, title, expand(body, app.url));
});

Given("the post {string} once linked to {string}", async ({ app }, title: string, links: string) => {
  await app.sql`UPDATE posts SET webmention_targets = ${`{${links}}`} WHERE title = ${title}`;
});

When("the webmention sender runs for the post {string}", async ({ app }, title: string) => {
  await runJob(app, sendJob, await postId(app, title));
});

When("the webmention sender runs for a post that is gone", async ({ app }) => {
  await runJob(app, sendJob, 999_999);
});

Then("the sender finishes", async ({ app }) => {
  expect(await lastRun(app, sendJob)).toMatchObject({ outcome: "succeeded" });
});

Then("the sender fails so Sidekiq tries again", async ({ app }) => {
  expect(await lastRun(app, sendJob)).toMatchObject({
    error_class: "Social::Jobs::SendWebmentions::EndpointUnreachable",
    outcome: "failed",
  });
});

Then("the post {string} remembers the targets {string}", async ({ app }, title: string, targets: string) => {
  const [row] = await app.sql`SELECT webmention_targets FROM posts WHERE title = ${title}`;
  expect(row.webmention_targets).toEqual(targets ? targets.split(", ") : []);
});

// Admin

When("I press {string} on the webmention from {string}", async ({ page }, button: string, author: string) => {
  await pressAndLand(
    page,
    page.locator(".wm-card", { hasText: author }).getByRole("button", { exact: true, name: button }),
  );
});

When(
  "I mark the webmention from {string} as spam saying {string}",
  async ({ page }, author: string, reason: string) => {
    const card = page.locator(".wm-card", { hasText: author });
    await card
      .locator("input[name='reason']")
      .fill(reason.replaceAll(/\\u([0-9a-f]{4})/gi, (_, code) => String.fromCharCode(Number.parseInt(code, 16))));
    await pressAndLand(page, card.getByRole("button", { exact: true, name: "Spam" }));
  },
);

When("I tick the webmention from {string}", async ({ page }, author: string) => {
  await page.locator(".wm-card", { hasText: author }).locator("input[name='ids[]']").check();
});

When("I tick every webmention on the page", async ({ page }) => {
  await page.locator("[data-bulk-all] input").check();
});

When("I press {string} on the webmention bar", async ({ page }, button: string) => {
  await pressAndLand(page, page.locator("form#webmention-bulk").getByRole("button", { name: button }));
});

When("I post to the admin {string} with:", async ({ answer, page }, path: string, table: DataTable) => {
  const fields = table.raw().flatMap(([name, value]): [string, string][] => {
    const range = value.match(/^(\d+)\.\.(\d+)$/);
    if (!range) return [[name, value]];
    const [from, to] = [Number(range[1]), Number(range[2])];
    return Array.from({ length: to - from + 1 }, (_, index) => [name, String(from + index)]);
  });
  const status = await submitForm(page, path, fields);
  Object.assign(answer, { body: await page.content(), status });
});

When("I post to the admin {string}", async ({ answer, page }, path: string) => {
  const status = await submitForm(page, path, []);
  Object.assign(answer, { body: await page.content(), status });
});

Then("the admin answers {int}", ({ answer }, status: number) => {
  expect(answer.status).toBe(status);
});

Then("the webmentions listed are {string}", async ({ page }, authors: string) => {
  await expect(page.locator(".wm-author")).toHaveText(authors ? authors.split(", ") : []);
});

Then("{int} webmentions are listed", async ({ page }, count: number) => {
  await expect(page.locator(".wm-card")).toHaveCount(count);
});

Then("the webmention head says {string}", async ({ page }, text: string) => {
  await expect(page.locator(".page-head-sub")).toHaveText(text);
});

Then("the {string} filter is checked", async ({ page }, status: string) => {
  await expect(page.locator(`.seg input[name='status'][value='${status}']`)).toBeChecked();
});

Then("the filters run {string}", async ({ page }, statuses: string) => {
  const values = await page
    .locator(".seg input[name='status']")
    .evaluateAll((inputs) => inputs.map((input) => (input as HTMLInputElement).value));
  expect(values).toEqual(statuses.split(", "));
});

Then("the webmention from {string} offers {string}", async ({ page }, author: string, buttons: string) => {
  const card = page.locator(".wm-card", { hasText: author });
  await expect(card.locator(".wm-acts button")).toHaveText(buttons.split(", "));
});

Then(
  "the webmention from {string} shows a {string} label colored {word}",
  async ({ page }, author: string, kind: string, color: string) => {
    await expect(page.locator(".wm-card", { hasText: author }).locator(`.wm-kind.${color}`)).toHaveText(kind);
  },
);

Then("the webmention bar offers {string}", async ({ page }, labels: string) => {
  const values = await page
    .locator("form#webmention-bulk button[name='act']")
    .evaluateAll((buttons) => buttons.map((button) => (button as HTMLButtonElement).value));
  expect(values).toEqual(labels.split(", "));
});

Then("the webmention bar is hidden", async ({ page }) => {
  await expect(page.locator("[data-bulk-acts]")).toBeHidden();
});

Then("the webmention bar is shown", async ({ page }) => {
  await expect(page.locator("[data-bulk-acts]")).toBeVisible();
});

Then("there is no webmention bar", async ({ page }) => {
  await expect(page.locator("form#webmention-bulk")).toHaveCount(0);
});

Then("the webmention settings switch {string} is {word}", async ({ page }, label: string, value: string) => {
  const box = page.getByRole("switch", { name: label });
  await (value === "on" ? expect(box).toBeChecked() : expect(box).not.toBeChecked());
});

Then("the trusted authors read {string}", async ({ page }, urls: string) => {
  await expect(page.locator("#trusted-authors .li-title")).toHaveText(urls.split(", "));
});

Then("the per post card reads {string} as {string}", async ({ page }, title: string, pill: string) => {
  await expect(page.locator(".li", { hasText: title }).locator(".li-side .pill")).toHaveText(pill);
});

Then("the per post card lists {string}", async ({ page }, titles: string) => {
  await expect(page.locator(".card", { hasText: "Per post" }).locator(".li-title")).toHaveText(titles.split(", "));
});

Then("the pager links {string} to {string}", async ({ page }, label: string, href: string) => {
  await expect(page.locator("nav.pager a", { hasText: label })).toHaveAttribute("href", href);
});

Then("the webmention from {string} shows {string}", async ({ page }, author: string, text: string) => {
  await expect(page.locator(".wm-card", { hasText: author })).toContainText(text);
});

Then("the webmention from {string} arrived at {string}", async ({ page }, author: string, at: string) => {
  await expect(page.locator(".wm-card", { hasText: author }).locator(".inbox-meta time")).toHaveAttribute(
    "datetime",
    at,
  );
});

Then("the author {string} links to {string} in a new tab", async ({ page }, author: string, href: string) => {
  const link = page.locator("a.wm-author", { hasText: author });
  await expect(link).toHaveAttribute("href", href);
  await expect(link).toHaveAttribute("target", "_blank");
  await expect(link).toHaveAttribute("rel", "noopener noreferrer");
});

Then("the webmention page has the element {string}", async ({ page }, selector: string) => {
  expect(await page.locator(selector).count()).toBeGreaterThan(0);
});

Then("the webmention page has no element {string}", async ({ page }, selector: string) => {
  await expect(page.locator(selector)).toHaveCount(0);
});

Then("the webmentions page is headed {string}", async ({ page }, heading: string) => {
  await expect(page.locator(".page-head h1")).toHaveText(heading);
});

Then("the webmentions screen tab {string} is current", async ({ page }, tab: string) => {
  await expect(page.locator(".screen-tab[aria-current='page']")).toHaveText(tab);
});

Then("GET {string} in the admin answers {int}", async ({ page }, path: string, status: number) => {
  expect((await page.request.get(path, { maxRedirects: 0 })).status()).toBe(status);
});

Then("GET {string} in the admin redirects to {string}", async ({ page }, path: string, location: string) => {
  const response = await page.request.get(path, { maxRedirects: 0 });
  expect([response.status(), response.headers().location]).toEqual([302, location]);
});

Then("I see the link {string} to {string}", async ({ page }, name: string, href: string) => {
  await expect(page.getByRole("link", { exact: true, name }).first()).toHaveAttribute("href", href);
});

Then("I see the spam note field {string}", async ({ page }, placeholder: string) => {
  await expect(page.locator(`form.wm-spam input[name='reason'][placeholder='${placeholder}']`).first()).toBeVisible();
});

Then("the webmention buttons wear:", async ({ page }, table: DataTable) => {
  for (const [label, icon] of table.raw()) {
    const found = page.locator(".wm-acts button", { hasText: label }).first().locator("i");
    await (icon === "none" ? expect(found).toHaveCount(0) : expect(found).toHaveAttribute("class", icon));
  }
});

When("I turn off the webmention switch {string}", async ({ page }, label: string) => {
  await page.getByRole("switch", { name: label }).uncheck();
});

When("I save the webmention settings with the hosts:", async ({ page }, hosts: string) => {
  const toggles = [
    "receive",
    "send_on_publish",
    "auto_approve_known_authors",
    "auto_approve_likes",
    "auto_approve_reposts",
    "enable_on_new_posts",
    "accept_bridgy",
  ].map((name): [string, string] => [`settings[${name}]`, "1"]);
  await submitForm(page, "/admin/webmentions/settings", [
    ...toggles,
    ["settings[single_author_hosts]", hosts.replaceAll("\n", "\r\n")],
  ]);
});

Then("the webmention hosts read {string}", async ({ page }, hosts: string) => {
  await expect(page.locator("textarea[name='settings[single_author_hosts]']")).toHaveValue(
    hosts.replaceAll("\\n", "\n"),
  );
});

Then("the address ends with {string}", ({ page }, end: string) => {
  expect(page.url().endsWith(end), page.url()).toBe(true);
});

When("I remove the trusted author {string}", async ({ page }, url: string) => {
  const row = page.locator("#trusted-authors .li", { hasText: url });
  await row.getByRole("button", { name: "Remove" }).click();
  await pressAndLand(page, row.locator("[data-confirm-accept]"));
});

Then("the bar actions show in the page as served, so they work with scripts off", async ({ page }) => {
  const html = await (await page.request.get(page.url())).text();
  expect(html).toMatch(/<[^>]*data-bulk-acts(?![^>]*\bhidden\b)[^>]*>/);
});

Then("the bar's buttons wear:", async ({ page }, table: DataTable) => {
  for (const [value, icon] of table.raw()) {
    await expect(page.locator(`form#webmention-bulk button[name='act'][value='${value}'] i`)).toHaveAttribute(
      "class",
      icon,
    );
  }
});

When("I post the webmention {int} to the bar {int} times", async ({ page }, id: number, times: number) => {
  const ids = Array.from({ length: times }, (): [string, string] => ["ids[]", String(id)]);
  await submitForm(page, "/admin/webmentions/bulk", [["act", "approved"], ["status", "pending"], ...ids]);
});

// API and MCP

function apiJson(answer: { body: string; content?: string }) {
  try {
    return JSON.parse(answer.body);
  } catch {
    return JSON.parse(answer.content ?? "");
  }
}

When(
  "I send {word} {string} to the webmention API with:",
  async ({ answer, request, tokens }, method: string, path: string, body: string) => {
    const data = body.replaceAll(/"\{ids:(\d+)\.\.(\d+)\}"/g, (_, from, to) =>
      JSON.stringify(Array.from({ length: Number(to) - Number(from) + 1 }, (_, index) => Number(from) + index)),
    );
    const response = await request.fetch(path, {
      data: JSON.parse(data),
      headers: { Accept: "application/json", Authorization: `Bearer ${tokens.api}` },
      method,
    });
    const text = await response.text();
    Object.assign(answer, {
      body: `${response.headers()["www-authenticate"] ?? ""}\n${text}`,
      content: text,
      status: response.status(),
    });
  },
);

Then(
  "the MCP tool {string} answers the same as the API with:",
  async ({ answer, request, tokens }, name: string, args: string) => {
    const api = apiJson(answer);
    const response = await request.post("/mcp", {
      data: { id: 1, jsonrpc: "2.0", method: "tools/call", params: { arguments: JSON.parse(args), name } },
      headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${tokens.mcp}` },
    });
    const { result } = await response.json();
    expect(unwrap(JSON.parse(result.content[0].text))).toEqual(api);
  },
);

Then(
  "the MCP tool {string} refuses as the API did with:",
  async ({ answer, request, tokens }, name: string, args: string) => {
    const message = apiJson(answer).message;
    const response = await request.post("/mcp", {
      data: { id: 1, jsonrpc: "2.0", method: "tools/call", params: { arguments: JSON.parse(args), name } },
      headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${tokens.mcp}` },
    });
    const { result } = await response.json();
    expect([result.isError, result.content[0].text]).toEqual([true, message]);
  },
);
