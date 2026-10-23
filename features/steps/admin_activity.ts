import { expect, type Page } from "@playwright/test";
import { defineParameterType } from "playwright-bdd";
import { Given, Then, When } from "../support/world.ts";

defineParameterType({
  name: "activityDay",
  regexp: /today|yesterday|\d+ days ago/,
  transformer: (day: string) => (day === "today" ? 0 : day === "yesterday" ? 1 : Number.parseInt(day, 10)),
});

const zone = "America/Chicago";

const isoDay = (daysAgo: number) => {
  const day = new Date(`${new Date().toLocaleDateString("en-CA", { timeZone: zone })}T00:00:00Z`);
  day.setUTCDate(day.getUTCDate() - daysAgo);
  return day.toISOString().slice(0, 10);
};

const dayLabel = (daysAgo: number) =>
  new Date(`${isoDay(daysAgo)}T00:00:00Z`).toLocaleDateString("en-US", {
    day: "numeric",
    month: "short",
    timeZone: "UTC",
    year: "numeric",
  });

const withDays = (text: string) =>
  text.replaceAll(/\{today(?:([+-])(\d+))?\}/g, (_, sign: string, count: string) =>
    isoDay(sign === "+" ? -Number(count) : Number(count ?? 0)),
  );

const list = (text: string) =>
  text
    ? text.split(" | ").flatMap((item) => {
        const repeated = item.match(/^(.*) × (\d+)$/);
        return repeated ? Array<string>(Number(repeated[2])).fill(repeated[1]) : [item];
      })
    : [];

const pagerLink = (which: string) => {
  const rel = { newer: "prev", older: "next" }[which];
  if (!rel) throw new Error(`Name the older or newer link, not ${which}`);
  return `a.pager-link[rel='${rel}']`;
};

const onDay = (page: Page, daysAgo: number) => page.locator(`.activity-day:has(time[datetime='${isoDay(daysAgo)}'])`);

const texts = async (page: Page, selector: string) =>
  (await page.locator(selector).allTextContents()).map((text) => text.replaceAll(/\s+/g, " ").trim());

const typeCount = (page: Page, label: string) =>
  page
    .locator(".activity-type")
    .filter({ has: page.locator("span", { hasText: new RegExp(`^${label}$`) }) })
    .locator(".activity-type-count");

const trusted = (value: unknown): unknown => {
  if (Array.isArray(value)) return value.map(trusted);
  if (value && typeof value === "object") {
    const record = value as Record<string, unknown>;
    if (record.untrusted === true && "text" in record) return record.text;
    return Object.fromEntries(Object.entries(record).map(([key, inner]) => [key, trusted(inner)]));
  }
  return value;
};

Given("the activity data holds:", async ({ app }, statement: string) => {
  await app.sql.begin(async (sql) => {
    await sql.unsafe(`SET LOCAL timezone = '${zone}'`);
    await sql.unsafe(statement).simple();
  });
});

Given(
  "{int} activity commits {string} on {activityDay}",
  async ({ app }, count: number, message: string, daysAgo: number) => {
    await app.sql`
      INSERT INTO commits (sha, repo, branch, message, commit_date, commit_time)
      SELECT md5(random()::text || n), 'aaronmallen/aaronmallen.me', 'main', ${message},
        ${isoDay(daysAgo)}::date, '09:00'
      FROM generate_series(1, ${count}) AS n
    `;
  },
);

When("I open the activity", async ({ page }) => {
  await page.goto("/admin/activity");
});

When("I open the activity with {string}", async ({ page }, query: string) => {
  await page.goto(`/admin/activity?${withDays(query)}`);
});

When("I follow the activity's {word} link", async ({ page }, which: string) => {
  const href = await page.locator(pagerLink(which)).getAttribute("href");
  await page.goto(href ?? "");
});

When("I follow the activity row {string}", async ({ page }, name: string) => {
  const href = await page.locator("a.activity-event", { hasText: name }).getAttribute("href");
  await page.goto((href ?? "").split("#")[0]);
});

When("I mark the activity page", async ({ page }) => {
  await page.evaluate(() => Object.assign(window, { stayed: true }));
});

When("I toggle the activity type {string}", async ({ page }, label: string) => {
  await page
    .locator(".activity-type")
    .filter({ has: page.locator("span", { hasText: new RegExp(`^${label}$`) }) })
    .click();
});

When("I search the activity for {string} in place", async ({ page }, text: string) => {
  await page.getByLabel("Contains").fill(text);
  await page.getByLabel("Contains").press("Enter");
});

When("I reload the activity", async ({ page }) => {
  await page.reload();
});

When("I go back from the activity", async ({ page }) => {
  await page.goBack();
});

When("I save the activity filters as the view {string}", async ({ page }, name: string) => {
  await page.locator(".saved-views summary", { hasText: "Save view" }).click();
  const panel = page.locator(".saved-views details[open] > .saved-view-panel");
  await panel.getByLabel("Name").fill(name);
  await panel.getByRole("button", { name: "Save view" }).click();
});

When("I open the activity row {string} in the task panel", async ({ page }, name: string) => {
  await page.locator(".activity-event", { hasText: name }).click();
  await expect(page.locator("dialog#task-panel[open] h1")).toBeVisible();
});

Then("the activity page stayed", async ({ page }) => {
  expect(await page.evaluate(() => (window as unknown as { stayed?: boolean }).stayed)).toBe(true);
});

Then("the activity address matches {string}", async ({ page }, pattern: string) => {
  await expect(page).toHaveURL(new RegExp(pattern));
});

Then(
  "the task panel over the activity shows the task {string} with {string} in view",
  async ({ page }, title: string, selector: string) => {
    await expect(page.locator("dialog#task-panel[open] h1")).toHaveText(title);
    await expect
      .poll(() =>
        page.evaluate((target) => {
          const body = document.querySelector("[data-task-panel-body]")?.getBoundingClientRect();
          const item = document.querySelector(target)?.getBoundingClientRect();
          return Boolean(body && item && item.top >= body.top && item.top < body.bottom);
        }, selector),
      )
      .toBe(true);
  },
);

Then("the activity rows read {string}", async ({ page }, names: string) => {
  await expect(page.locator(".activity-event-name")).toHaveText(list(names));
});

Then("the activity rows read {string} in any order", async ({ page }, names: string) => {
  await expect.poll(async () => (await texts(page, ".activity-event-name")).sort()).toEqual(list(names).sort());
});

Then("the activity rows include {string}", async ({ page }, names: string) => {
  await expect.poll(() => texts(page, ".activity-event-name")).toEqual(expect.arrayContaining(list(names)));
});

Then("the activity rows leave out {string}", async ({ page }, name: string) => {
  await expect(page.locator(".activity-event-name").first()).toBeAttached();
  expect(await texts(page, ".activity-event-name")).not.toContain(name);
});

Then("the activity shows no rows", async ({ page }) => {
  await expect(page.locator(".activity-event-name")).toHaveCount(0);
});

Then("the activity shows {int} rows", async ({ page }, count: number) => {
  await expect(page.locator(".activity-event-name")).toHaveCount(count);
});

Then("the activity rows on {activityDay} read {string}", async ({ page }, daysAgo: number, names: string) => {
  await expect(onDay(page, daysAgo).locator(".activity-event-name")).toHaveText(list(names));
});

Then("the first activity row runs to at most {int} characters", async ({ page }, length: number) => {
  expect((await texts(page, ".activity-event-name"))[0].length).toBeLessThanOrEqual(length);
});

Then("the first activity row on {activityDay} ends with {string}", async ({ page }, daysAgo: number, end: string) => {
  const [first] = await texts(page, `.activity-day:has(time[datetime='${isoDay(daysAgo)}']) .activity-event-name`);
  expect(first.endsWith(end), first).toBe(true);
});

Then("the first activity row starts with {string}", async ({ page }, start: string) => {
  const [first] = await texts(page, ".activity-event-name");
  expect(first.startsWith(start), first).toBe(true);
});

Then("the first activity row's markup reads {string}", async ({ page }, html: string) => {
  expect(await page.locator(".activity-event-name").first().innerHTML()).toBe(html);
});

Then("the first activity row's markup ends with {string}", async ({ page }, end: string) => {
  const html = await page.locator(".activity-event-name").first().innerHTML();
  expect(html.endsWith(end), html).toBe(true);
});

Then("the activity sub-lines read {string}", async ({ page }, subs: string) => {
  await expect(page.locator(".activity-event-sub")).toHaveText(list(subs));
});

Then("the activity sub-lines read {string} in any order", async ({ page }, subs: string) => {
  await expect.poll(async () => (await texts(page, ".activity-event-sub")).sort()).toEqual(list(subs).sort());
});

Then("the first activity sub-line reads {string}", async ({ page }, sub: string) => {
  await expect(page.locator(".activity-event-sub").first()).toHaveText(sub);
});

Then("the activity days read {string}", async ({ page }, days: string) => {
  const dates = days.split(" | ").map((day) => {
    const ago = day.match(/^(\d+) days ago$/);
    return isoDay(day === "today" ? 0 : day === "yesterday" ? 1 : Number(ago?.[1]));
  });
  await expect
    .poll(() => page.locator(".day-date").evaluateAll((times) => times.map((time) => time.getAttribute("datetime"))))
    .toEqual(dates);
});

Then("the activity counts {int} for {string}", async ({ page }, count: number, label: string) => {
  await expect(typeCount(page, label)).toHaveText(String(count));
});

Then("the activity health on {activityDay} reads {string}", async ({ page }, daysAgo: number, figures: string) => {
  await expect(onDay(page, daysAgo).locator(".activity-health span")).toHaveText(list(figures));
});

Then("the activity names the range from {activityDay} to {activityDay}", async ({ page }, from: number, to: number) => {
  await expect(page.locator(".page-head-sub")).toContainText(`${dayLabel(from)} → ${dayLabel(to)}`);
});

Then("the activity search box holds {string}", async ({ page }, text: string) => {
  await expect(page.getByLabel("Contains")).toHaveValue(text);
});

Then("the activity photos read {string}", async ({ page }, photos: string) => {
  const shown = await page
    .locator(".activity-event .sq-photo")
    .evaluateAll((images) => images.map((image) => `${image.getAttribute("src")} ${image.getAttribute("alt")}`));
  expect(shown).toEqual(list(photos));
});

Then("the activity page has {string}", async ({ page }, selector: string) => {
  await expect(page.locator(withDays(selector)).first()).toBeAttached();
});

Then("the activity page has {string} reading {string}", async ({ page }, selector: string, text: string) => {
  await expect(page.locator(withDays(selector)).filter({ hasText: text }).first()).toBeAttached();
});

Then("the activity page has {int} of {string}", async ({ page }, count: number, selector: string) => {
  await expect(page.locator(withDays(selector))).toHaveCount(count);
});

Then("the activity page has no {string}", async ({ page }, selector: string) => {
  await expect(page.locator(withDays(selector))).toHaveCount(0);
});

Then("the activity page has no {string} reading {string}", async ({ page }, selector: string, text: string) => {
  await expect(page.locator(withDays(selector)).filter({ hasText: text })).toHaveCount(0);
});

Then("the activity's {word} link holds {string}", async ({ page }, which: string, text: string) => {
  const href = await page.locator(pagerLink(which)).getAttribute("href");
  expect(href).toContain(withDays(text));
});

Then("the activity's {word} link leaves out {string}", async ({ page }, which: string, text: string) => {
  const href = await page.locator(pagerLink(which)).getAttribute("href");
  expect(href).not.toContain(text);
});

Then("the page the activity row opened shows {string}", async ({ page }, text: string) => {
  await expect(page.locator("body")).toContainText(text);
});

Then(
  "the MCP tool {string} with {string} answers as the API does for {string}",
  async ({ request, tokens }, tool: string, args: string, path: string) => {
    const api = await request.get(path, { headers: { Authorization: `Bearer ${tokens.api}` } });
    const response = await request.post("/mcp", {
      data: { id: 1, jsonrpc: "2.0", method: "tools/call", params: { arguments: JSON.parse(args), name: tool } },
      headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${tokens.mcp}` },
    });
    const reply = JSON.parse(await response.text());

    expect(api.status(), await api.text()).toBe(200);
    expect(trusted(JSON.parse(reply.result.content[0].text))).toEqual(await api.json());
  },
);
