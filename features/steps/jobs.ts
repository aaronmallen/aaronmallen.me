import { deflateSync } from "node:zlib";
import { expect, type Page } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import {
  addProcess,
  addToSet,
  addWork,
  enqueue,
  failed,
  type Job,
  job,
  type Redis,
  realProcesses,
} from "../support/sidekiq.ts";
import { Given, Then, When } from "../support/world.ts";

const sets: Record<string, string> = { dead: "dead", retry: "retry", retries: "retry", scheduled: "schedule" };

const parse = (cell: string) => (cell ? JSON.parse(cell) : []);

Given(
  "a worker process {string} that is {int} busy of {int}, beating {int} seconds ago",
  async ({ app }, identity: string, busy: number, concurrency: number, beat: number) => {
    await addProcess(app.redis.client, identity, { beat, busy, concurrency });
  },
);

Given(
  "a worker process {string} on {string} running {string} for {int} seconds with the args {string}",
  async ({ app }, identity: string, hostname: string, name: string, seconds: number, args: string) => {
    await addProcess(app.redis.client, identity, { busy: 1, concurrency: 5, hostname, queues: ["default", "mailers"] });
    await addWork(app.redis.client, identity, seconds, job(name, parse(args), { queue: "default" }));
  },
);

Given("an idle worker process {string} on {string}", async ({ app }, identity: string, hostname: string) => {
  await addProcess(app.redis.client, identity, { concurrency: 5, hostname, queues: ["default", "mailers"] });
});

Given("a stopping worker process {string} finishing {string}", async ({ app }, identity: string, name: string) => {
  await addProcess(app.redis.client, identity, { busy: 1, concurrency: 5, quiet: true });
  await addWork(app.redis.client, identity, 5, job(name));
});

Given(
  "the queue {string} holds {int} {string} job(s) waiting since {int} seconds ago",
  async ({ app }, queue: string, count: number, name: string, waited: number) => {
    const now = Date.now() / 1000;
    for (let position = 1; position <= count; position++) {
      await enqueue(app.redis.client, queue, job(name, [position], { enqueued_at: now - waited + position }));
    }
  },
);

Given("the {word} set holds:", async ({ app }, set: string, table: DataTable) => {
  for (const row of table.hashes()) {
    const extra: Job = row.jid ? { jid: row.jid } : {};
    if (row.error) [extra.error_class, extra.error_message] = row.error.split(": ");
    if (row["retry count"]) extra.retry_count = Number(row["retry count"]);
    if ("error" in row && !row.error) {
      delete extra.error_class;
      delete extra.error_message;
    }
    if (row.backtrace)
      extra.error_backtrace = deflateSync(JSON.stringify(row.backtrace.split(" | "))).toString("base64");
    const entry =
      set === "scheduled" ? job(row.class, parse(row.args), extra) : failed(row.class, parse(row.args), extra);
    if ("error" in row && !row.error) for (const key of ["error_class", "error_message"]) delete entry[key];
    if (set === "scheduled") delete entry.created_at;
    await addToSet(app.redis.client, sets[set], Number(row.at), entry);
  }
});

Given(
  "the {word} set holds {int} {string} jobs, {int} second(s) apart",
  async ({ app }, set: string, count: number, prefix: string, gap: number) => {
    const sign = set === "dead" ? -1 : 1;
    for (let index = 0; index < count; index++) {
      await addToSet(app.redis.client, sets[set], sign * (index + 1) * gap, failed(`${prefix}${index}`));
    }
  },
);

Given(
  "Sidekiq processed {int} and failed {int} today and processed {int} yesterday",
  async ({ app }, processed: number, failedToday: number, yesterday: number) => {
    const day = (shift: number) => new Date(Date.now() - shift * 86_400_000).toISOString().slice(0, 10);
    await app.redis.client.set(`stat:processed:${day(0)}`, String(processed));
    await app.redis.client.set(`stat:failed:${day(0)}`, String(failedToday));
    await app.redis.client.set(`stat:processed:${day(1)}`, String(yesterday));
  },
);

Given("the cron entry {string} runs next in {int} seconds", async ({ app }, name: string, seconds: number) => {
  const at = new Date(Date.now() + seconds * 1000)
    .toISOString()
    .replace("T", " ")
    .replace(/\.\d+Z$/, " UTC");
  await app.redis.client.hSet("sidekiq-scheduler:next_times", name, at);
});

Given("the cron entry {string} is paused", async ({ app }, name: string) => {
  await app.redis.client.hSet("sidekiq-scheduler:states", name, JSON.stringify({ enabled: false }));
});

Given("Redis is down", ({ app }) => {
  app.redis.stop();
});

Then("the jobs counts read:", async ({ app, page }, table: DataTable) => {
  let total = 0;
  if (table.raw().some(([, value]) => value.includes("{total concurrency}"))) {
    for (const identity of await app.redis.client.sMembers("processes")) {
      total += Number(await app.redis.client.hGet(identity, "concurrency"));
    }
  }
  const counts = page.locator(".jobs-count");
  for (const [name, value] of table.raw()) {
    const count = counts.filter({ has: page.locator("span", { hasText: name }) });
    await expect(count.locator("b")).toHaveText(value.replace("{total concurrency}", String(total)));
  }
});

Then("the jobs tab reads {string}", async ({ page }, label: string) => {
  await expect(page.locator("nav[aria-label='Settings tabs'] a", { hasText: "jobs" })).toHaveText(label);
});

Then("the worker health reads {string}", async ({ page }, status: string) => {
  await expect(page.locator(".jobs-health h2")).toContainText(status);
});

Then("the worker health says {string}", async ({ page }, text: string) => {
  await expect(page.locator(".jobs-health .jobs-status-meta")).toContainText(text);
});

Then("the jobs page warns {string}", async ({ page }, text: string) => {
  await expect(page.locator(".jobs-banner").first()).toContainText(text);
});

Then("the jobs page shows no warning", async ({ page }) => {
  await expect(page.locator(".jobs-banner")).toHaveCount(0);
});

Then("the cron entries list in this order, first:", async ({ page }, table: DataTable) => {
  const names = await page.locator("#jobs-cron .jobs-cron-name").allTextContents();
  expect(names.slice(0, table.raw().length)).toEqual(table.raw().map(([name]) => name));
});

Then("the cron entries are only {string}", async ({ page }, names: string) => {
  expect((await page.locator("#jobs-cron .jobs-cron-name").allTextContents()).join(", ")).toBe(names);
});

Then("the cron schedule lists every entry of config\\/sidekiq.yml.erb", async ({ page }) => {
  const { readFile } = await import("node:fs/promises");
  const { root } = await import("../support/shell.ts");
  const config = await readFile(`${root}/config/sidekiq.yml.erb`, "utf8");
  const names = [...config.matchAll(/^ {4}(\w+):$/gm)].map(([, name]) => name);
  const shown = await page.locator("#jobs-cron .jobs-cron-name").allTextContents();
  expect(shown.sort()).toEqual(names.sort());
});

const entry = (page: Page, name: string) => page.locator(`#jobs-cron-${name}`);

Then("the cron entry {string} says {string}", async ({ page }, name: string, text: string) => {
  await expect(entry(page, name)).toContainText(text);
});

Then("the cron entry {string} shows the pill {string}", async ({ page }, name: string, pill: string) => {
  await expect(entry(page, name).locator(".pill", { hasText: pill })).toHaveCount(1);
});

Then("the cron entry {string} shows no pill", async ({ page }, name: string) => {
  await expect(entry(page, name).locator(".pill")).toHaveCount(0);
});

Then(
  "the cron entry {string} shows the code {string}, the class {string} and {string}",
  async ({ page }, name: string, code: string, klass: string, text: string) => {
    await expect(entry(page, name).locator(".jobs-cron-code")).toHaveText(code);
    await expect(entry(page, name).locator(".jobs-cron-class")).toHaveText(klass);
    await expect(entry(page, name)).toContainText(text);
  },
);

Then("the cron entry {string} shows the error {string}", async ({ page }, name: string, error: string) => {
  await expect(entry(page, name).locator(".jobs-cron-error")).toHaveText(error);
});

Then("the cron entry {string} links to {string}", async ({ page }, name: string, href: string) => {
  await expect(entry(page, name).locator(`a[href="${href}"]`)).toHaveCount(1);
});

Then("the cron entry {string} links nowhere", async ({ page }, name: string) => {
  await expect(entry(page, name).locator("a")).toHaveCount(0);
});

Then("the cron filter reads {string}", async ({ page }, labels: string) => {
  expect((await page.locator("#jobs-cron .seg-option").allTextContents()).map((text) => text.trim()).join(", ")).toBe(
    labels,
  );
});

Then("the cron schedule says {string}", async ({ page }, text: string) => {
  await expect(page.locator("#jobs-cron .empty")).toContainText(text);
});

Then("the times of the cron entry {string} are the last run and the next run", async ({ app, page }, name: string) => {
  const stamps = await entry(page, name)
    .locator("time")
    .evaluateAll((times) => times.map((time) => Date.parse(time.getAttribute("datetime") ?? "")));
  const [{ last }] = await app.sql`SELECT max(occurred_at) AS last FROM performance_jobs`;
  const next = Date.parse((await app.redis.client.hGet("sidekiq-scheduler:next_times", name)) ?? "");
  expect(stamps.map((stamp) => Math.floor(stamp / 1000))).toEqual(
    [last, new Date(next)].map((time) => Math.floor(time.getTime() / 1000)),
  );
});

When("I run the cron entry {string} from the jobs page", async ({ page }, name: string) => {
  await entry(page, name)
    .getByRole("button", { name: `Run ${name} now` })
    .click();
});

Then("the {string} card lists the processes and running jobs:", async ({ page }, title: string, table: DataTable) => {
  const running = page.locator(".card", { hasText: title });
  for (const [selector, text] of table.raw()) {
    await expect(running.locator(selector).filter({ hasText: text }).first()).toBeVisible();
  }
});

Then("the {word} card of the jobs page lists:", async ({ page }, set: string, table: DataTable) => {
  await expect(page.locator(`#jobs-${set} .li-title`)).toHaveText(table.raw().map(([title]) => title));
});

Then("the {word} card of the jobs page lists {int} jobs", async ({ page }, set: string, count: number) => {
  await expect(page.locator(`#jobs-${set} .li-title`)).toHaveCount(count);
});

Then("the {word} card of the jobs page says {string}", async ({ page }, set: string, text: string) => {
  await expect(page.locator(`#jobs-${set}`)).toContainText(text);
});

Then(
  "the first row of the {word} card shows {string} in {string}",
  async ({ page }, set: string, text: string, selector: string) => {
    await expect(page.locator(`#jobs-${set} .li`).first().locator(selector)).toHaveText(text);
  },
);

Then(
  "the first row of the {word} card stamps {int} seconds from now",
  async ({ page }, set: string, seconds: number) => {
    const stamps = await page
      .locator(`#jobs-${set} .li`)
      .first()
      .locator("time")
      .evaluateAll((times) => times.map((time) => Date.parse(time.getAttribute("datetime") ?? "") / 1000));
    const near = stamps.filter((stamp) => Math.abs(stamp - (Date.now() / 1000 + seconds)) < 5);
    expect(near).toHaveLength(1);
  },
);

When("I open the jobs tab", async ({ app, page }) => {
  const real = await realProcesses(app.redis.client);
  if (real.length) await app.redis.client.sRem("processes", real);
  await page.goto("/admin/settings/jobs");
});

When("I post the hover form of the first row of the {word} card", async ({ http, page }, set: string) => {
  const form = page.locator(`#jobs-${set} .li .hov form`).first();
  const action = (await form.getAttribute("action")) ?? "";
  const back = await form.locator("input[name=return_to]").inputValue();
  await http.send("POST", action, { form: { _csrf_token: await http.csrf(), return_to: back } });
});

Then("every return_to in the job drawer is {string}", async ({ page }, back: string) => {
  const values = await page
    .locator("dialog#jobs-job input[name=return_to]")
    .evaluateAll((inputs) => [...new Set(inputs.map((input) => (input as HTMLInputElement).value))]);
  expect(values).toEqual([back]);
});

Then("the page has a link to {string}", async ({ page }, href: string) => {
  await expect(page.locator(`a[href="${href}"]`)).toHaveCount(1);
});

Then(
  "the {word} card of the jobs page links {string} to {string}",
  async ({ page }, set: string, name: string, href: string) => {
    await expect(page.locator(`#jobs-${set}`).getByRole("link", { name, exact: true })).toHaveAttribute("href", href);
  },
);

Then("the {word} card of the jobs page shows no error", async ({ page }, set: string) => {
  await expect(page.locator(`#jobs-${set} .jobs-error`)).toHaveCount(0);
});

Then("the {word} card's next page link reads {string}", async ({ page }, set: string, text: string) => {
  await expect(page.locator(`#jobs-${set} .pager-link[rel='next']`)).toHaveText(text);
});

Then("the Queues card lists {int} queues", async ({ page }, count: number) => {
  await expect(page.locator("aside.card .li")).toHaveCount(count);
});

Then(
  "the queue {string} reads {string} with the class {string} and says {string}",
  async ({ page }, queue: string, size: string, klass: string, text: string) => {
    const row = page.locator("aside.card .li", { hasText: queue });
    await expect(row.locator(".jobs-queue-size")).toHaveText(size);
    await expect(row.locator(".jobs-queue-size")).toHaveClass(new RegExp(klass));
    await expect(row).toContainText(text);
  },
);

Then("the queue {string} says {string} and links nowhere", async ({ page }, queue: string, text: string) => {
  const row = page.locator("aside.card .li", { hasText: queue });
  await expect(row).toContainText(text);
  await expect(row.getByRole("link", { name: queue })).toHaveCount(0);
});

Then("the queue drawer says {string}", async ({ page }, text: string) => {
  await expect(page.locator("dialog#jobs-queue")).toContainText(text);
});

Then("the queue drawer lists the args {int} to {int}", async ({ page }, first: number, last: number) => {
  const expected = Array.from({ length: last - first + 1 }, (_, index) => String(first + index));
  await expect(page.locator("dialog#jobs-queue .jobs-args")).toHaveText(expected);
});

Then("the queue drawer's page links read:", async ({ page }, table: DataTable) => {
  for (const [rel, text, href] of table.raw()) {
    const link = page.locator(`dialog#jobs-queue .pager-link[rel='${rel}']`);
    await expect(link).toHaveText(text);
    await expect(link).toHaveAttribute("href", href);
  }
});

Then("no {word} drawer opens", async ({ page }, kind: string) => {
  await expect(page.locator(`dialog#jobs-${kind}`)).toHaveCount(0);
});

Then("the job drawer shows the facts:", async ({ page }, table: DataTable) => {
  const drawer = page.locator("dialog#jobs-job");
  for (const [term, value] of table.raw()) {
    const dt = drawer.locator(".jobs-facts dt", { hasText: new RegExp(`^${term}$`) });
    await expect(dt).toHaveCount(1);
    if (value) await expect(dt.locator("xpath=following-sibling::dd[1]")).toHaveText(value);
  }
});

Then("the job drawer shows the name {string}", async ({ page }, name: string) => {
  await expect(page.locator("dialog#jobs-job .jobs-job-name")).toHaveText(name);
});

Then(
  "the job drawer shows the error {string}, the args and a backtrace of {string} ending {string}",
  async ({ page }, error: string, lines: string, last: string) => {
    const drawer = page.locator("dialog#jobs-job");
    await expect(drawer.locator(".jobs-error")).toHaveText(error);
    await expect(drawer.locator(".jobs-pre").first()).toHaveText(JSON.stringify([42, { thread: true }], null, 2));
    await expect(drawer.locator(".jobs-backtrace")).toContainText(lines);
    await expect(drawer.locator(".jobs-backtrace")).toContainText(last);
  },
);

Then(
  "the jobs bars draw {int} days, today last with its failures, labelled {string}",
  async ({ page }, days: number, label: string) => {
    const bars = page.locator(".jobs-bar");
    await expect(bars).toHaveCount(days);
    await expect(bars.last()).toHaveClass(/jobs-bar-today/);
    await expect(bars.last().locator("i.jobs-bar-failed")).toHaveCount(1);
    await expect(page.locator(".jobs-bars")).toHaveAttribute("aria-label", new RegExp(`^${label}`));
  },
);

Given("the queue {string} is empty", async ({ app }, queue: string) => {
  await app.redis.client.sAdd("queues", queue);
});

When("I follow {string} in the {word} card", async ({ page }, name: string, set: string) => {
  await page.locator(`#jobs-${set}`).getByRole("link", { name, exact: true }).first().click();
});

const jobsIn = async (redis: Redis, key: string) => (await redis.zRange(key, 0, -1)).map((value) => JSON.parse(value));

const queued = async (redis: Redis, queue: string) =>
  (await redis.lRange(`queue:${queue}`, 0, -1)).map((value) => JSON.parse(value));

Then("the {word} set holds no job", async ({ app }, set: string) => {
  expect(await jobsIn(app.redis.client, sets[set])).toEqual([]);
});

Then("the {word} set holds the job {string}", async ({ app }, set: string, id: string) => {
  expect((await jobsIn(app.redis.client, sets[set])).map((entry) => entry.jid)).toEqual([id]);
});

Then("the queue {string} holds no job", async ({ app }, queue: string) => {
  expect(await queued(app.redis.client, queue)).toEqual([]);
});

Then("the queue {string} holds the job {string}", async ({ app }, queue: string, id: string) => {
  expect((await queued(app.redis.client, queue)).map((entry) => entry.jid)).toEqual([id]);
});

Then(
  "the queue {string} holds the job {string} with {int} retry",
  async ({ app }, queue: string, id: string, retries: number) => {
    expect((await queued(app.redis.client, queue)).map((entry) => [entry.jid, entry.retry_count])).toEqual([
      [id, retries],
    ]);
  },
);

Then("Redis holds the state {string} for the cron entry {string}", async ({ app }, state: string, name: string) => {
  expect(JSON.parse((await app.redis.client.hGet("sidekiq-scheduler:states", name)) ?? "null")).toEqual(
    JSON.parse(state),
  );
});

When("I press {string} on the cron entry {string}", async ({ page }, button: string, name: string) => {
  await entry(page, name).getByRole("button", { exact: true, name: button }).click();
  await page.waitForLoadState();
});

Then("the cron entry {string} offers {string}", async ({ page }, name: string, button: string) => {
  await expect(entry(page, name).getByRole("button", { exact: true, name: button })).toHaveCount(1);
});

Then("the cron entry {string} opens its menu from {string}", async ({ page }, name: string, menu: string) => {
  await expect(entry(page, name)).toHaveAttribute("data-menu", menu);
});

Then("every button of the cron entry {string} returns to {string}", async ({ page }, name: string, back: string) => {
  const values = await entry(page, name)
    .locator("input[name=return_to]")
    .evaluateAll((inputs) => [...new Set(inputs.map((input) => (input as HTMLInputElement).value))]);
  expect(values).toEqual([back]);
});

Then("the buttons of the cron entry {string} are {string}", async ({ page }, name: string, labels: string) => {
  const found = await entry(page, name)
    .locator("button")
    .evaluateAll((buttons) => buttons.map((button) => button.getAttribute("aria-label")));
  expect(found.join(", ")).toBe(labels);
});

Then("every button of the menu is off", async ({ page }) => {
  const off = await page
    .locator("[data-context-menu] button")
    .evaluateAll((buttons) => buttons.map((button) => (button as HTMLButtonElement).disabled));
  expect(off.length).toBeGreaterThan(0);
  expect(off.every(Boolean)).toBe(true);
});

Then("every return_to on the page is {string}", async ({ page }, back: string) => {
  const values = await page
    .locator("input[name=return_to]")
    .evaluateAll((inputs) => [...new Set(inputs.map((input) => (input as HTMLInputElement).value))]);
  expect(values).toEqual([back]);
});

Then("the first row of the {word} card opens its menu from {string}", async ({ page }, set: string, menu: string) => {
  await expect(page.locator(`#jobs-${set} .li`).first()).toHaveAttribute("data-menu", menu);
});

When("I press {string} in the first row of the {word} card", async ({ page }, button: string, set: string) => {
  const row = page.locator(`#jobs-${set} .li`).first();
  await row.hover();
  await row.getByRole("button", { exact: true, name: button }).click();
  await page.waitForLoadState();
});

Then("the first row of the {word} card offers {string}", async ({ page }, set: string, button: string) => {
  await expect(page.locator(`#jobs-${set} .li .hov`).first().getByRole("button", { name: button })).toHaveCount(1);
});

Then("the menu asks {string} before {string}", async ({ page }, question: string, verb: string) => {
  await expect(page.locator(`form[action$='/${verb}'] button`)).toHaveAttribute("data-confirm-inline", question);
});

Then("the menu asks nothing before {string}", async ({ page }, verb: string) => {
  await expect(page.locator(`form[action$='/${verb}'] button`)).not.toHaveAttribute("data-confirm-inline");
});

Then("the job drawer's buttons are {string}", async ({ page }, labels: string) => {
  const found = await page.locator("dialog#jobs-job .dialog-foot button").allTextContents();
  expect(found.map((label) => label.trim()).join(", ")).toBe(labels);
});

Then("the job drawer asks {string} before {string}", async ({ page }, question: string, verb: string) => {
  await expect(page.locator(`dialog#jobs-job .dialog-foot form[action$='/${verb}']`)).toHaveAttribute(
    "data-confirm",
    question,
  );
});

Then("the job drawer asks nothing before {string}", async ({ page }, verb: string) => {
  await expect(page.locator(`dialog#jobs-job .dialog-foot form[action$='/${verb}']`)).not.toHaveAttribute(
    "data-confirm",
  );
});

Then("the worker health shows the heartbeat of {int} seconds ago", async ({ page }, seconds: number) => {
  const stamp = await page.locator(".jobs-health .jobs-status-meta time").getAttribute("datetime");
  expect(Math.abs(Date.parse(stamp ?? "") / 1000 - (Date.now() / 1000 - seconds))).toBeLessThan(3);
});
