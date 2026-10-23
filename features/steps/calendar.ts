import { connect, type Socket } from "node:net";
import { expect, type Page } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import type postgres from "postgres";
import {
  dayOf,
  expand,
  insertCalendar,
  insertDatedPost,
  insertEvent,
  insertSocialPost,
  insertSprintTask,
  iso,
  minutesFromNow,
  today,
  zoned,
} from "../support/calendar.ts";
import { settle } from "../support/mail_sync.ts";
import { seal } from "../support/seal.ts";
import { After, Before, Given, Then, When } from "../support/world.ts";

const lines = (text: string) =>
  text
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);

const squish = (text: string | null) => (text ?? "").replaceAll(/\s+/g, " ").trim();

const cell = (page: Page, day: string) => page.locator(`.cal-day:has(time[datetime='${dayOf(day)}'])`);

const panel = (page: Page) => page.locator("[data-calendar-panel]");

// The records a calendar day holds.

Given("the calendar {string} of {string}", async ({ app }, name: string, account: string) => {
  await insertCalendar(app.sql, { account, name });
});

Given("the read-only calendar {string} of {string}", async ({ app }, name: string, account: string) => {
  await insertCalendar(app.sql, { account, name, writable: false });
});

Given("the hidden calendar {string} of {string}", async ({ app }, name: string, account: string) => {
  await insertCalendar(app.sql, { account, hidden: true, name });
});

Given(
  "the calendar event {string} in {string} on {string} from {string} to {string}",
  async ({ app }, title: string, calendar: string, day: string, starts: string, ends: string) => {
    const on = dayOf(day);
    await insertEvent(app.sql, {
      calendar,
      ends_at: zoned(on, ends),
      ends_on: on,
      starts_at: zoned(on, starts),
      starts_on: on,
      title,
    });
  },
);

Given(
  "the calendar event {string} in {string} from {string} at {string} to {string} at {string}",
  async ({ app }, title: string, calendar: string, first: string, starts: string, last: string, ends: string) => {
    await insertEvent(app.sql, {
      calendar,
      ends_at: zoned(dayOf(last), ends),
      ends_on: dayOf(last),
      starts_at: zoned(dayOf(first), starts),
      starts_on: dayOf(first),
      title,
    });
  },
);

Given(
  "the all-day calendar event {string} in {string} from {string} to {string}",
  async ({ app }, title: string, calendar: string, first: string, last: string) => {
    await insertEvent(app.sql, { calendar, ends_on: dayOf(last), starts_on: dayOf(first), title });
  },
);

// Events built around now that would cross midnight in the owner's zone are left out, and the checks
// that lean on them pass over them, so the today card scenarios hold at any hour.
const outOfDay = new Set<string>();

Before(() => outOfDay.clear());

const localDay = (at: Date) => new Intl.DateTimeFormat("en-CA", { timeZone: "America/Chicago" }).format(at);

Given(
  "the calendar event {string} in {string} runs from {int} to {int} minutes from now",
  async ({ app }, title: string, calendar: string, starts: number, ends: number) => {
    const startsAt = minutesFromNow(starts);
    const endsAt = minutesFromNow(ends);
    if (localDay(startsAt) !== today() || localDay(new Date(endsAt.getTime() - 1)) !== today()) {
      outOfDay.add(title);
      return;
    }
    await insertEvent(app.sql, {
      calendar,
      ends_at: endsAt,
      ends_on: today(),
      starts_at: startsAt,
      starts_on: today(),
      title,
    });
  },
);

Given("the calendar event {string} has:", async ({ app }, title: string, table: DataTable) => {
  for (const [field, value] of Object.entries(table.rowsHash())) {
    const stored = field === "attendees" ? value.split(", ") : value;
    await app.sql`UPDATE calendar_events SET ${app.sql({ [field]: stored })} WHERE title = ${title}`;
  }
});

Given(
  "the {word} post {string} lands on the calendar on {string} at {string}",
  async ({ app }, status: string, title: string, day: string, clock: string) => {
    await insertDatedPost(app.sql, title, status, zoned(dayOf(day), clock));
  },
);

Given(
  "the {word} social post {string} lands on the calendar on {string} at {string}",
  async ({ app }, status: string, body: string, day: string, clock: string) => {
    await insertSocialPost(app.sql, body, status, zoned(dayOf(day), clock));
  },
);

Given(
  "the sprint on the calendar day {string} holds the {word} task {string}",
  async ({ app }, day: string, status: string, title: string) => {
    await insertSprintTask(app.sql, dayOf(day), title, status);
  },
);

Given("an empty sprint lands on the calendar on {string}", async ({ app }, day: string) => {
  await app.sql`INSERT INTO sprints (sprint_date) VALUES (${dayOf(day)})`;
});

Given("a journal entry lands on the calendar on {string}", async ({ app }, day: string) => {
  await app.sql`
    INSERT INTO journal_entries ${app.sql({
      body: "A day to note.",
      body_html: "<p>A day to note.</p>",
      entry_date: dayOf(day),
      entry_time: "09:00",
    })}
  `;
});

// Visiting and sending.

When("I open the calendar", async ({ page }) => {
  await page.goto("/admin/calendar");
});

When("I open the calendar on {string}", async ({ page }, day: string) => {
  await page.goto(`/admin/calendar?day=${dayOf(day)}`);
});

When("I open the calendar month {string}", async ({ page }, month: string) => {
  await page.goto(`/admin/calendar?month=${month}`);
});

When("I mark the calendar page", async ({ page }) => {
  await page.evaluate(() => Object.assign(window, { calendarKept: true }));
});

Then("the calendar page is still the one I marked", async ({ page }) => {
  expect(await page.evaluate(() => (window as unknown as { calendarKept?: boolean }).calendarKept)).toBe(true);
});

async function sendForm(page: Page, path: string, fields: string[][]) {
  if (!(await page.locator("input[name=_csrf_token]").count())) await page.goto("/admin/calendar");

  const responded = page.waitForResponse(
    (response) => response.request().method() === "POST" && new URL(response.url()).pathname === path,
  );
  const navigated = page.waitForNavigation();
  await page.evaluate(
    ({ fields, path }) => {
      const form = document.createElement("form");
      const token = document.querySelector<HTMLInputElement>("input[name=_csrf_token]")?.value ?? "";
      Object.assign(form, { action: path, method: "post" });
      for (const [name, value] of [["_csrf_token", token], ...fields]) {
        form.append(Object.assign(document.createElement("input"), { name, type: "hidden", value }));
      }
      document.body.append(form);
      HTMLFormElement.prototype.submit.call(form);
    },
    { fields, path },
  );
  const [response] = await Promise.all([responded, navigated]);
  return response.status();
}

When("I send the calendar form {string} with:", async ({ answer, app, page }, path: string, table: DataTable) => {
  const fields = await Promise.all(table.raw().map(async ([name, value]) => [name, await expand(app.sql, value)]));
  answer.status = await sendForm(page, await expand(app.sql, path), fields);
});

When("I send the calendar form {string}", async ({ answer, app, page }, path: string) => {
  answer.status = await sendForm(page, await expand(app.sql, path), []);
});

When("a visitor sends the calendar form {string} with:", async ({ app, request }, path: string, table: DataTable) => {
  const form: Record<string, string> = {};
  for (const [name, value] of table.raw()) form[name] = await expand(app.sql, value);
  await request.post(await expand(app.sql, path), { form, maxRedirects: 0 });
});

Then("the calendar form answers with status {int}", ({ answer }, status: number) => {
  expect(answer.status).toBe(status);
});

Then("the calendar answers GET {string} with status {int}", async ({ app, page }, path: string, status: number) => {
  const response = await page.request.get(await expand(app.sql, path), { maxRedirects: 0 });
  expect(response.status()).toBe(status);
});

Then("I see the calendar toast {string}", async ({ app, page }, text: string) => {
  await expect(
    page
      .locator(".toast")
      .filter({ hasText: await expand(app.sql, text) })
      .first(),
  ).toBeAttached();
});

Then("I see the calendar failure toast {string}", async ({ page }, text: string) => {
  await expect(page.locator(".toast-failed").filter({ hasText: text }).first()).toBeAttached();
});

Then("the calendar shows the address {string}", async ({ app, page }, path: string) => {
  const url = new URL(page.url());
  expect(`${url.pathname}${url.search}`).toBe(await expand(app.sql, path));
});

// The month grid.

Then("the calendar cell for {string} shows the marks:", async ({ app, page }, day: string, marks: string) => {
  const expected = await Promise.all(lines(marks).map((mark) => expand(app.sql, mark)));
  await expect
    .poll(async () => (await cell(page, day).locator(".cal-mark").allTextContents()).map(squish))
    .toEqual(expected);
});

Then("the calendar cell for {string} shows no marks", async ({ page }, day: string) => {
  await expect(cell(page, day).locator(".cal-mark")).toHaveCount(0);
});

Then("the calendar cell for {string} shows the mark {string}", async ({ page }, day: string, text: string) => {
  await expect(cell(page, day).locator(".cal-mark", { hasText: text })).not.toHaveCount(0);
});

Then("the calendar cell for {string} does not show the mark {string}", async ({ page }, day: string, text: string) => {
  await expect(cell(page, day).locator(".cal-mark", { hasText: text })).toHaveCount(0);
});

Then("the calendar cell for {string} shows a {word} mark", async ({ page }, day: string, kind: string) => {
  await expect(cell(page, day).locator(`.cal-mark.${kind}`)).not.toHaveCount(0);
});

Then("the calendar cell for {string} tints its events:", async ({ page }, day: string, tones: string) => {
  const styles = await cell(page, day)
    .locator(".cal-mark.event")
    .evaluateAll((marks) => marks.map((mark) => mark.getAttribute("style")));
  expect(styles).toEqual(lines(tones));
});

Then("the calendar cell for {string} reads {string} to screen readers", async ({ page }, day: string, text: string) => {
  await expect(cell(page, day).locator("time.cal-date .sr-only")).toHaveText(text);
});

Then("the calendar cell for {string} links to {string}", async ({ app, page }, day: string, href: string) => {
  await expect(cell(page, day).locator("a.cal-link")).toHaveAttribute("href", await expand(app.sql, href));
});

Then("the calendar heading names {string}", async ({ app, page }, text: string) => {
  await expect(page.locator(".page-head-sub")).toContainText(await expand(app.sql, text));
});

Then("the calendar marks only {string} as today", async ({ page }, day: string) => {
  const marked = await page
    .locator("[aria-current='date'] time")
    .evaluateAll((times) => times.map((time) => time.getAttribute("datetime")));
  expect(marked).toEqual([dayOf(day)]);
});

Then("the calendar marks only {string} as picked", async ({ page }, day: string) => {
  await expect
    .poll(() =>
      page.locator(".cal-picked time").evaluateAll((times) => times.map((time) => time.getAttribute("datetime"))),
    )
    .toEqual([dayOf(day)]);
});

Then("the calendar pager marks this month", async ({ page }) => {
  await expect(page.locator(".seg-option.current", { hasText: "This month" })).toHaveCount(1);
});

Then("the calendar pager does not mark this month", async ({ page }) => {
  await expect(page.locator(".seg-option.current", { hasText: "This month" })).toHaveCount(0);
});

Then("the calendar arrows point each way with an icon", async ({ page }) => {
  await expect(page.locator("a.seg-option[rel='prev'] i.fa-chevron-left")).toHaveCount(1);
  await expect(page.locator("a.seg-option[rel='next'] i.fa-chevron-right")).toHaveCount(1);
});

Then("the calendar links {string} to {string}", async ({ page }, name: string, href: string) => {
  await expect(page.getByRole("link", { name, exact: true })).toHaveAttribute("href", href);
});

Then("the calendar draws whole weeks from Monday through the month of {string}", async ({ page }, day: string) => {
  const dates = await page
    .locator(".cal-day time")
    .evaluateAll((times) => times.map((time) => time.getAttribute("datetime") ?? ""));
  const weekday = (iso: string) => new Date(`${iso}T12:00:00Z`).getUTCDay();
  const month = dayOf(day).slice(0, 7);
  const days = new Date(Date.UTC(Number(month.slice(0, 4)), Number(month.slice(5)), 0)).getUTCDate();
  const wanted = Array.from({ length: days }, (_, index) => `${month}-${String(index + 1).padStart(2, "0")}`);

  expect([weekday(dates[0]), weekday(dates.at(-1) ?? ""), dates.length % 7]).toEqual([1, 0, 0]);
  expect(dates).toEqual(expect.arrayContaining(wanted));
});

Then("the calendar group tabs link {string}", async ({ page }, hrefs: string) => {
  const tabs = page.locator(".page-head + .screen-tabs a.screen-tab");
  expect(await tabs.evaluateAll((links) => links.map((link) => link.getAttribute("href")))).toEqual(hrefs.split(" "));
  await expect(page.locator(".screen-tab[aria-current='page']")).toHaveText(/calendar/i);
});

Then("the command palette lists the calendar with its icon", async ({ page }) => {
  await expect(page.locator("#command-palette-calendar i.fa-calendar-days")).toHaveCount(1);
});

// The day panel.

Then("the calendar day panel is for {string}", async ({ page }, day: string) => {
  await expect(panel(page)).toHaveAttribute("data-calendar-panel", dayOf(day));
});

Then("the calendar day panel shows {string}", async ({ app, page }, text: string) => {
  await expect(panel(page)).toContainText(await expand(app.sql, text));
});

Then("the calendar day panel does not show {string}", async ({ page }, text: string) => {
  await expect(panel(page)).not.toContainText(text);
});

Then("the calendar day panel links {string} to {string}", async ({ app, page }, name: string, href: string) => {
  await expect(panel(page).getByRole("link", { name, exact: true }).first()).toHaveAttribute(
    "href",
    await expand(app.sql, href),
  );
});

Then("the calendar day panel says when each item goes out:", async ({ page }, times: string) => {
  const said = await panel(page).locator(".li-sub", { hasText: "·" }).allTextContents();
  expect(said.map(squish)).toEqual(lines(times));
});

Then(
  "the calendar day panel puts the times {string} of {string} in time tags",
  async ({ page }, clocks: string, day: string) => {
    const stamps = await panel(page)
      .locator(".li-sub time")
      .evaluateAll((times) => times.map((time) => time.getAttribute("datetime") ?? ""));
    expect(stamps.map((stamp) => new Date(stamp).getTime())).toEqual(
      clocks.split(", ").map((clock) => zoned(dayOf(day), clock).getTime()),
    );
  },
);

Then("the calendar sprint names the statuses {string}", async ({ page }, statuses: string) => {
  const named = await panel(page).locator(".cal-group", { hasText: "Sprint" }).locator(".li-sub").allTextContents();
  expect(named.map(squish).sort()).toEqual(statuses.split(", ").sort());
});

Then("the calendar day panel links the social posts to:", async ({ app, page }, hrefs: string) => {
  const links = panel(page).locator(".cal-group", { hasText: "Social posts" }).locator("a.li-title");
  const found = await links.evaluateAll((all) => all.map((link) => link.getAttribute("href")));
  expect(found).toEqual(await Promise.all(lines(hrefs).map((href) => expand(app.sql, href))));
});

const eventRow = (page: Page, title: string) => panel(page).locator(".cal-event", { hasText: title }).first();

const linkIn = (scope: ReturnType<Page["locator"]>, name: string) =>
  scope
    .locator("a")
    .filter({ hasText: name })
    .or(scope.locator(`a[aria-label="${name}"]`))
    .first();

Then("the calendar day panel lists the event times:", async ({ page }, times: string) => {
  expect((await panel(page).locator(".cal-event .cal-event-time").allTextContents()).map(squish)).toEqual(lines(times));
});

Then(
  "the calendar event {string} reads {string} in the day panel",
  async ({ app, page }, title: string, meta: string) => {
    await expect(eventRow(page, title).locator(".cal-event-meta")).toHaveText(await expand(app.sql, meta));
  },
);

Then("the calendar event {string} opens to {string}", async ({ page }, title: string, text: string) => {
  await expect(eventRow(page, title).locator(".cal-event-more")).toContainText(text);
});

Then(
  "the calendar event {string} links {string} to {string}",
  async ({ app, page }, title: string, name: string, href: string) => {
    await expect(linkIn(eventRow(page, title), name)).toHaveAttribute("href", await expand(app.sql, href));
  },
);

// The calendar picker.

Given("the calendar account {string} is a work account", async ({ app }, account: string) => {
  await app.sql`UPDATE service_connections SET work = true WHERE account_id = ${account}`;
});

When("I open the calendar picker", async ({ page }) => {
  await page.locator(".saved-view-menu summary", { hasText: "Calendars" }).click();
});

When("I untick the calendar {string}", async ({ page }, name: string) => {
  await page.locator(".cal-picker-row", { hasText: name }).locator("input").uncheck();
});

When("I untick every calendar", async ({ page }) => {
  for (const box of await page.locator(".cal-picker input[type=checkbox]").all()) await box.uncheck();
});

When("I press {string} in the calendar picker", async ({ page }, name: string) => {
  await page.locator(".cal-picker").getByRole("button", { name, exact: true }).click();
  await page.waitForLoadState();
});

Then("the calendar picker lists the accounts {string}", async ({ page }, accounts: string) => {
  const legends = await page.locator(".cal-picker-account legend").allTextContents();
  expect(legends.map(squish)).toEqual(accounts.split(", "));
});

Then("the calendar picker ticks:", async ({ page }, table: DataTable) => {
  const rows = await page
    .locator(".cal-picker-row")
    .evaluateAll((labels) =>
      labels.map((label) => [label.textContent ?? "", String(label.querySelector("input")?.checked)]),
    );
  expect(rows).toEqual(table.raw());
});

Then("the calendar picker reads {string}", async ({ page }, label: string) => {
  await expect(page.locator(".saved-view-menu summary", { hasText: "Calendars" })).toHaveText(label);
});

Then("the calendar page shows no calendar picker", async ({ page }) => {
  await expect(page.locator(".cal-picker")).toHaveCount(0);
});

Then("the stored calendars are hidden as:", async ({ app }, table: DataTable) => {
  const rows = await app.sql`SELECT name, hidden FROM calendars ORDER BY name`;
  expect(rows.map(({ hidden, name }) => [name, String(hidden)])).toEqual(table.raw());
});

Given("the calendar {string} is gone", async ({ app }, name: string) => {
  await app.sql`DELETE FROM calendars WHERE name = ${name}`;
});

// Google Calendar writes.

const google = "/google/calendar";

async function calendarPath(sql: Parameters<typeof expand>[0], name: string) {
  const [found] = await sql`SELECT google_id FROM calendars WHERE name = ${name}`;
  if (!found) throw new Error(`no calendar called ${name}`);
  return `${google}/calendars/${encodeURIComponent(found.google_id)}/events`;
}

// Replies to every write on the calendar's events, and turns the sync each write queues away at the
// calendar list, so it leaves the mirror as the scenario built it.
Given("Google Calendar takes writes to the calendar {string}", async ({ app, stub }, name: string) => {
  const events = await calendarPath(app.sql, name);
  const ids = await app.sql`
    SELECT google_id, recurring_id FROM calendar_events
    WHERE calendar_id = (SELECT id FROM calendars WHERE name = ${name})
  `;
  const ok = { body: "{}", status: 200 };

  stub.reply("POST", events, ok);
  for (const id of ids.flatMap((row) => [row.google_id, row.recurring_id]).filter(Boolean)) {
    for (const method of ["PATCH", "DELETE"]) stub.reply(method, `${events}/${encodeURIComponent(id)}`, ok);
  }
  stub.reply("GET", `${google}/users/me/calendarList`, { body: "", status: 503 });
});

Given(
  "Google Calendar holds the series {string} in {string} from {string} at {string}",
  async ({ app, stub }, id: string, name: string, day: string, clock: string) => {
    const start = { dateTime: zoned(dayOf(day), clock).toISOString(), timeZone: "America/Chicago" };
    stub.reply("GET", `${await calendarPath(app.sql, name)}/${id}`, { body: JSON.stringify({ start }), status: 200 });
  },
);

Given(
  "Google Calendar turns away {word} to the event {string} in {string}",
  async ({ app, stub }, method: string, id: string, name: string) => {
    stub.reply(method, `${await calendarPath(app.sql, name)}/${id}`, { body: "{}", status: 403 });
  },
);

const instants = (value: unknown): unknown => {
  if (Array.isArray(value)) return value.map(instants);
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value).map(([key, inner]) => [
        key,
        key === "dateTime" && typeof inner === "string" ? iso(new Date(inner)) : instants(inner),
      ]),
    );
  }
  return value;
};

async function sentTo(
  app: { sql: Parameters<typeof expand>[0] },
  stub: { received: (m: string, p: string) => string[] },
  method: string,
  path: string,
  name: string,
) {
  const full = path ? `${await calendarPath(app.sql, name)}/${path}` : await calendarPath(app.sql, name);
  return stub.received(method, full).map((body) => instants(JSON.parse(body || "{}")));
}

Then(
  "Google Calendar got {word} {string} in {string} with the event:",
  async ({ app, stub }, method: string, path: string, name: string, json: string) => {
    const wanted = JSON.parse(await expand(app.sql, json));
    await expect.poll(async () => (await sentTo(app, stub, method, path, name)).at(-1)).toMatchObject(wanted);
  },
);

Then(
  "Google Calendar got {word} {string} in {string} with only:",
  async ({ app, stub }, method: string, path: string, name: string, json: string) => {
    const wanted = JSON.parse(await expand(app.sql, json));
    await expect.poll(async () => (await sentTo(app, stub, method, path, name)).at(-1)).toEqual(wanted);
  },
);

Then(
  "Google Calendar got {word} {string} in {string}",
  async ({ app, stub }, method: string, path: string, name: string) => {
    await expect.poll(async () => (await sentTo(app, stub, method, path, name)).length).toBeGreaterThan(0);
  },
);

Then(
  "Google Calendar got no {word} {string} in {string}",
  async ({ app, stub }, method: string, path: string, name: string) => {
    expect(await sentTo(app, stub, method, path, name)).toEqual([]);
  },
);

Then("Google Calendar heard no event write", async ({ app, stub }) => {
  const calendars = await app.sql`SELECT name FROM calendars`;
  const ids = await app.sql`SELECT google_id, recurring_id FROM calendar_events`;
  const heard: string[] = [];

  for (const { name } of calendars) {
    const events = await calendarPath(app.sql, name);
    heard.push(...stub.received("POST", events));
    for (const id of ids.flatMap((row) => [row.google_id, row.recurring_id]).filter(Boolean)) {
      for (const method of ["PATCH", "DELETE"]) heard.push(...stub.received(method, `${events}/${id}`));
    }
  }
  expect(heard).toEqual([]);
});

Then("the calendar sync was queued", async ({ stub }) => {
  await expect.poll(() => stub.received("GET", `${google}/users/me/calendarList`).length).toBeGreaterThan(0);
});

Then(
  "the calendar event {string} starts on {string} at {string}",
  async ({ app }, title: string, day: string, clock: string) => {
    const [row] = await app.sql`
      SELECT starts_on::text AS starts_on, starts_at FROM calendar_events WHERE title = ${title}
    `;
    expect([row.starts_on, row.starts_at?.toISOString()]).toEqual([dayOf(day), zoned(dayOf(day), clock).toISOString()]);
  },
);

Then("the calendar event {string} starts on {string}", async ({ app }, title: string, day: string) => {
  const [row] = await app.sql`SELECT starts_on::text AS starts_on FROM calendar_events WHERE title = ${title}`;
  expect(row.starts_on).toBe(dayOf(day));
});

// The new event form and the edit forms the day panel opens again after a refusal.

const eventForm = (page: Page, form: string) => page.locator(`form#${form}-form`);

async function formId(sql: Parameters<typeof expand>[0], form: string) {
  return expand(sql, form);
}

Then(
  "the calendar form {string} says {string} under {string}",
  async ({ app, page }, form: string, text: string, field: string) => {
    const id = await formId(app.sql, form);
    await expect(eventForm(page, id).locator(`#${id}-${field}-error`)).toHaveText(text);
  },
);

Then(
  "the calendar form {string} holds {string} in {string}",
  async ({ app, page }, form: string, value: string, field: string) => {
    const id = await formId(app.sql, form);
    await expect(eventForm(page, id).locator(`#${id}-${field}`)).toHaveValue(await expand(app.sql, value));
  },
);

Then("the calendar form {string} marks {string} wrong", async ({ app, page }, form: string, field: string) => {
  const id = await formId(app.sql, form);
  await expect(eventForm(page, id).locator(`#${id}-${field}`)).toHaveAttribute("aria-invalid", "true");
});

Then("the calendar form {string} ticks {string}", async ({ app, page }, form: string, value: string) => {
  const id = await formId(app.sql, form);
  await expect(
    eventForm(page, id).locator(`input[value='${value}']:checked, input[name='${value}']:checked`),
  ).toHaveCount(1);
});

Then("the new calendar event form is open", async ({ page }) => {
  await expect(page.locator("details.cal-new-event[open]")).toHaveCount(1);
});

Then("the calendar day panel offers no new event", async ({ page }) => {
  await expect(page.locator(".cal-new-event")).toHaveCount(0);
});

Then("the edit form of the calendar event {string} is open", async ({ page }, title: string) => {
  await expect(eventRow(page, title).locator("details.cal-event-edit[open]")).toHaveCount(1);
});

Then("the new calendar event form offers the calendars:", async ({ page }, table: DataTable) => {
  const groups = await page
    .locator(".cal-new-event optgroup")
    .evaluateAll((all) =>
      all.map((group) => [
        group.getAttribute("label") ?? "",
        [...group.querySelectorAll("option")].map((option) => option.textContent).join(", "),
      ]),
    );
  expect(groups).toEqual(table.raw());
});

Then("the new calendar event form hints {string}", async ({ page }, text: string) => {
  await expect(page.locator(".cal-event-form .hint")).toHaveText(text);
});

Then("the calendar event {string} can be edited and deleted", async ({ app, page }, title: string) => {
  const row = eventRow(page, title);
  await expect(
    row.locator(`form[action='/admin/calendar/events/${await expand(app.sql, `<event ${title}>`)}']`),
  ).toHaveCount(1);
  await expect(row.locator("button", { hasText: "Delete" })).not.toHaveCount(0);
});

Then("the calendar event {string} asks {string}", async ({ page }, title: string, choices: string) => {
  const options = await eventRow(page, title).locator(".seg-option").allTextContents();
  expect(options.map(squish)).toEqual(choices.split(", "));
});

Then("the calendar event {string} takes no change", async ({ page }, title: string) => {
  await expect(eventRow(page, title).locator("form")).toHaveCount(0);
  await expect(eventRow(page, title)).toContainText("Read-only here");
});

Then("the calendar event {string} moves through {string}", async ({ app, page }, title: string, action: string) => {
  await expect(eventRow(page, title).locator("form.cal-move")).toHaveAttribute("action", await expand(app.sql, action));
});

Then("the calendar event {string} has no move form", async ({ page }, title: string) => {
  await expect(eventRow(page, title).locator("form.cal-move")).toHaveCount(0);
});

Then("the services settings hint {string}", async ({ page }, text: string) => {
  await expect(page.locator("#services .settings-side .hint", { hasText: text })).toHaveCount(1);
});

When("I fill in the new calendar event with:", async ({ app, page }, table: DataTable) => {
  const form = page.locator(".cal-new-event");
  if (!(await form.getAttribute("open"))) await form.locator("summary").click();
  for (const [label, value] of table.raw()) {
    const field = form.getByLabel(label, { exact: true });
    const filled = await expand(app.sql, value);
    if ((await field.evaluate((element) => element.tagName)) === "SELECT") await field.selectOption({ label: filled });
    else await field.fill(filled);
  }
});

When("I add the calendar event", async ({ page }) => {
  await page.locator(".cal-new-event").getByRole("button", { name: "Add event" }).click();
  await page.waitForLoadState();
});

When("I open the services settings for the calendar account {string}", async ({ app, page }, account: string) => {
  await page.goto(`/admin/settings/services?selected=${await expand(app.sql, `<connection ${account}>`)}`);
});

// Moving posts, social posts and sprint tasks.

Given("the calendar social post {string} has started sending", async ({ app }, body: string) => {
  const id = await expand(app.sql, `<social ${body}>`);
  await app.sql`INSERT INTO social_post_deliveries (social_post_id, network) VALUES (${id}, 'mastodon')`;
});

Then("the calendar day panel offers the move forms:", async ({ app, page }, actions: string) => {
  const found = await panel(page)
    .locator("form.cal-move")
    .evaluateAll((forms) => forms.map((form) => form.getAttribute("action")));
  expect(found).toEqual(await Promise.all(lines(actions).map((action) => expand(app.sql, action))));
});

Then("the calendar day panel offers no move form", async ({ page }) => {
  await expect(panel(page).locator("form.cal-move")).toHaveCount(0);
});

Then(
  "the calendar move field {string} starts on {string} no earlier than {string}",
  async ({ page }, label: string, day: string, floor: string) => {
    const field = panel(page).getByLabel(label, { exact: true });
    await expect(field).toHaveAttribute("type", "date");
    await expect(field).toHaveValue(dayOf(day));
    await expect(field).toHaveAttribute("min", dayOf(floor));
  },
);

Then(
  "the calendar post {string} goes out on {string} at {string}",
  async ({ app }, title: string, day: string, clock: string) => {
    const [row] = await app.sql`SELECT published_at FROM posts WHERE title = ${title}`;
    expect(row.published_at.toISOString()).toBe(zoned(dayOf(day), clock).toISOString());
  },
);

Then("the calendar post {string} is still {word}", async ({ app }, title: string, status: string) => {
  const [row] = await app.sql`SELECT status::text AS status FROM posts WHERE title = ${title}`;
  expect(row.status).toBe(status);
});

Then(
  "the calendar social post {string} goes out on {string} at {string}",
  async ({ app }, body: string, day: string, clock: string) => {
    const [row] = await app.sql`
      SELECT posted_at FROM social_posts WHERE id = (SELECT social_post_id FROM social_post_parts WHERE body = ${body})
    `;
    expect(row.posted_at.toISOString()).toBe(zoned(dayOf(day), clock).toISOString());
  },
);

Then("the calendar task {string} sits in the sprint on {string}", async ({ app }, title: string, day: string) => {
  await expect
    .poll(async () => {
      const [row] = await app.sql`
        SELECT sprints.sprint_date::text AS day FROM tasks JOIN sprints ON sprints.id = tasks.sprint_id
        WHERE tasks.title = ${title}
      `;
      return row?.day;
    })
    .toBe(dayOf(day));
});

Then("one sprint lands on the calendar on {string}", async ({ app }, day: string) => {
  const rows = await app.sql`SELECT id FROM sprints WHERE sprint_date = ${dayOf(day)}`;
  expect(rows.length).toBe(1);
});

When("I open the calendar task {string}", async ({ app, page }, title: string) => {
  await page.goto(`/admin/tasks/${await expand(app.sql, `<task ${title}>`)}?filter=next`);
});

Then("the task timeline reads {string}", async ({ app, page }, text: string) => {
  await expect(page.locator(".timeline-event", { hasText: await expand(app.sql, text) })).not.toHaveCount(0);
});

// The calendar card on the admin's today page.

const todayCard = (page: Page) =>
  page.locator("section.card").filter({ has: page.locator("h2.card-title", { hasText: /^Calendar$/ }) });

const todayRow = (page: Page, title: string) => todayCard(page).locator(".today-event", { hasText: title }).first();

Then("the today calendar lists {string}", async ({ page }, titles: string) => {
  if (outOfDay.size) return;
  const shown = await todayCard(page).locator(".card-body > .today-event .cal-event-name").allTextContents();
  expect(shown).toEqual(titles.split(", "));
});

Then("the today calendar folds {string} under {string}", async ({ page }, titles: string, summary: string) => {
  if (outOfDay.size) return;
  const earlier = todayCard(page).locator("details.today-more");
  await expect(earlier.locator(":scope > summary")).toHaveText(summary);
  expect(await earlier.locator(".cal-event-name").allTextContents()).toEqual(titles.split(", "));
});

Then("the today calendar marks {string} as {word}", async ({ page }, title: string, state: string) => {
  if (outOfDay.has(title)) return;
  await expect(todayRow(page, title)).toHaveAttribute("data-state", state);
});

Then("the today calendar tally reads {string}", async ({ page }, text: string) => {
  if (outOfDay.size) return;
  await expect(todayCard(page).locator("[data-today-calendar-left]")).toHaveText(text);
});

Then("the today calendar shows {string} as running now", async ({ page }, title: string) => {
  if (outOfDay.has(title)) return;
  await expect(todayRow(page, title).locator("[data-today-now] .pill.blue")).toHaveText("now");
  await expect(todayRow(page, title).locator("[data-today-now]")).toBeVisible();
});

Then("the today calendar does not show {string} as running now", async ({ page }, title: string) => {
  if (outOfDay.has(title)) return;
  await expect(todayRow(page, title).locator("[data-today-now]")).toBeHidden();
});

Then("the today calendar counts down {string} for {string}", async ({ page }, text: string, title: string) => {
  if (outOfDay.has(title)) return;
  await expect(todayRow(page, title).locator("[data-today-soon]")).toHaveText(text);
});

Then("the today calendar counts down nothing for {string}", async ({ page }, title: string) => {
  if (outOfDay.has(title)) return;
  await expect(todayRow(page, title).locator("[data-today-soon]")).toHaveText("");
});

Then("the today calendar times {string} as {string}", async ({ page }, title: string, text: string) => {
  await expect(todayRow(page, title).locator(".cal-event-time")).toHaveText(text);
});

Then("the today calendar says {string}", async ({ page }, text: string) => {
  if (outOfDay.size) return;
  await expect(todayCard(page).locator(".empty, .today-para")).toHaveText(text);
});

Then("the today calendar event {string} reads {string}", async ({ app, page }, title: string, meta: string) => {
  await expect(todayRow(page, title).locator(".cal-event-meta")).toHaveText(await expand(app.sql, meta));
});

Then("the today calendar event {string} joins at {string}", async ({ page }, title: string, href: string) => {
  await expect(todayRow(page, title).locator("a.today-event-join")).toHaveAttribute("href", href);
});

Then("the today calendar event {string} opens to:", async ({ page }, title: string, text: string) => {
  const said = await todayRow(page, title).locator(".cal-event-more p").allTextContents();
  expect(said.map(squish)).toEqual(lines(text));
});

Then("the today calendar event {string} offers the buttons:", async ({ page }, title: string, table: DataTable) => {
  const buttons = await todayRow(page, title)
    .locator(".cal-event-more a.bt")
    .evaluateAll((links) => links.map((link) => [link.textContent?.trim() ?? "", link.getAttribute("href") ?? ""]));
  expect(buttons).toEqual(table.raw());
});

When("I prep a task from the today calendar event {string}", async ({ page }, title: string) => {
  // Late at night the event has ended and sits folded under the earlier events.
  if (!(await todayRow(page, title).isVisible())) await todayCard(page).locator("details.today-more > summary").click();
  await todayRow(page, title).locator("summary").click();
  await todayRow(page, title).getByRole("link", { name: "Prep task" }).click();
});

Then("the new task dialog holds the title {string}", async ({ page }, title: string) => {
  await expect(page.locator("#task-create [name='task[title]']")).toHaveValue(title);
});

Then("the new task page holds the title {string}", async ({ page }, title: string) => {
  await expect(page.locator("[name='task[title]']").first()).toHaveValue(title);
});

Then("the today calendar links {string} to {string}", async ({ page }, text: string, href: string) => {
  await expect(todayCard(page).locator("a.today-link", { hasText: text })).toHaveAttribute("href", href);
});

// The event menu and the in-place panel.

const menu = (page: Page) => page.locator("[data-context-menu]");

When("I open the menu of the calendar event {string}", async ({ page }, title: string) => {
  await eventRow(page, title).locator(".cal-event-time").click({ button: "right" });
  await expect(menu(page)).toBeVisible();
});

Then("the calendar event menu is headed {string}", async ({ page }, title: string) => {
  await expect(menu(page).locator(":scope > .ctx-head")).toHaveText(title);
});

Then("the calendar event menu holds:", async ({ page }, labels: string) => {
  await expect
    .poll(async () => (await menu(page).locator(".ctx-label").allTextContents()).map(squish))
    .toEqual(lines(labels));
});

Then("the calendar event menu opens {string} in a new tab", async ({ page }, href: string) => {
  await expect(menu(page).locator(`a.ctx-item[href='${href}'][target=_blank]`)).toHaveCount(1);
});

When("I pick {string} in the calendar event menu", async ({ page }, label: string) => {
  await menu(page).locator(".ctx-item", { hasText: label }).first().click();
});

When("I retitle the calendar event to {string}", async ({ page }, title: string) => {
  const dialog = page.locator("dialog[open]");
  await dialog.getByLabel("Title", { exact: true }).fill(title);
  await dialog.getByRole("button", { name: "Save" }).click();
});

When("I open the calendar day {string} in place", async ({ page }, day: string) => {
  await cell(page, day).locator("a.cal-link").click();
});

When("I ask to delete the calendar event {string}", async ({ page }, title: string) => {
  await panel(page).locator(".cal-event-title", { hasText: title }).click();
  await eventRow(page, title).getByRole("button", { name: "Delete", exact: true }).click();
});

Then("the calendar asks {string}", async ({ page }, text: string) => {
  await expect(page.locator("[data-confirm-ask] [data-confirm-message]")).toHaveText(text);
});

Then("the calendar day panel has focus", async ({ page }) => {
  await expect(panel(page)).toBeFocused();
});

// One held request at a time: each worker runs one scenario at a time.
const held: { arrived?: Promise<void>; release?: () => void } = {};

When("the calendar holds back the panel for {string}", async ({ page }, day: string) => {
  const gate = new Promise<void>((release) => Object.assign(held, { release }));
  held.arrived = new Promise<void>((done) => {
    const wanted = (url: URL) => url.pathname === "/admin/calendar" && url.searchParams.get("day") === dayOf(day);
    page.route(wanted, async (route) => {
      done();
      await gate;
      await route.continue();
    });
  });
});

When("the calendar asks for the held panel", async () => {
  await held.arrived;
});

When("the held calendar panel arrives", async ({ page }) => {
  held.release?.();
  await page.waitForLoadState("networkidle");
});

Then("the calendar event menu offers {string}", async ({ page }, label: string) => {
  await expect(menu(page).locator(".ctx-item", { hasText: label }).first()).toBeVisible();
});

// Dragging records from the day panel onto another day.

const grip = (page: Page, title: string) =>
  panel(page).locator(".li, .cal-event", { hasText: title }).first().locator("[data-calendar-grip]");

const dayLink = (page: Page, day: string) => page.locator(`a[data-calendar-day='${dayOf(day)}']`);

async function centre(locator: ReturnType<Page["locator"]>) {
  const box = await locator.boundingBox();
  if (!box) throw new Error("nothing to drag");
  return { x: box.x + box.width / 2, y: box.y + box.height / 2 };
}

const stroke = (from: { x: number; y: number }, to: { x: number; y: number }) =>
  [1, 2, 3, 4, 5, 6].map((step) => ({
    x: from.x + ((to.x - from.x) * step) / 6,
    y: from.y + ((to.y - from.y) * step) / 6,
  }));

// A tall window keeps the whole month and the panel in view, since a mouse cannot drag past the edge.
const tall = (page: Page) => page.setViewportSize({ height: 1400, width: 1280 });

When("I drag {string} onto the calendar day {string}", async ({ page }, title: string, day: string) => {
  await tall(page);
  const from = await centre(grip(page, title));
  const to = await centre(dayLink(page, day));

  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  for (const point of stroke(from, to)) await page.mouse.move(point.x, point.y);
  await page.mouse.up();
});

When(
  "I drag {string} toward the calendar day {string} and the browser cancels it",
  async ({ page }, title: string, day: string) => {
    await tall(page);
    const from = await centre(grip(page, title));
    const to = await centre(dayLink(page, day));
    const cdp = await page.context().newCDPSession(page);
    const touch = (type: string, point?: { x: number; y: number }) =>
      cdp.send("Input.dispatchTouchEvent", { touchPoints: point ? [point] : [], type });

    await touch("touchStart", from);
    for (const point of stroke(from, to)) await touch("touchMove", point);
    await touch("touchCancel");
  },
);

When("I point the move of {string} at a post that is gone", async ({ page }, title: string) => {
  await grip(page, title).evaluate((button) => {
    const form = button.closest("form");
    if (form) form.action = "/admin/calendar/posts/0/move";
  });
});

Given("the calendar post {string} has gone out", async ({ app }, title: string) => {
  await app.sql`UPDATE posts SET status = 'published' WHERE title = ${title}`;
});

Then("the calendar shows no drag leftovers", async ({ page }) => {
  await expect(page.locator(".cal-ghost, .cal-dragging, .cal-target")).toHaveCount(0);
});

Then("the calendar day panel offers no grip", async ({ page }) => {
  await expect(panel(page).locator("[data-calendar-grip]")).toHaveCount(0);
});

// The admin event stream that tells open pages what changed.

const streams: Socket[] = [];

After(() => {
  for (const socket of streams.splice(0)) socket.destroy();
});

function openStream(url: string, cookie: string) {
  const { hostname, port } = new URL(url);
  const socket = connect(Number(port), hostname);
  const heard = { text: "" };
  socket.on("data", (chunk) => {
    heard.text += chunk.toString();
  });
  socket.write(`GET /admin/events HTTP/1.1\r\nHost: ${hostname}\r\nCookie: ${cookie}\r\n\r\n`);
  streams.push(socket);
  return heard;
}

const heardOn: { text: string }[] = [];

async function hear(heard: { text: string }, text: string) {
  await expect.poll(() => heard.text, { timeout: 5000 }).toContain(text);
}

When("{int} admin event streams open", async ({ app, owner }, count: number) => {
  const cookie = owner.cookies.map(({ name, value }) => `${name}=${value}`).join("; ");
  heardOn.length = 0;
  for (let index = 0; index < count; index += 1) {
    const heard = openStream(app.url, cookie);
    await hear(heard, "retry:");
    heardOn.push(heard);
  }
});

When("a visitor opens the admin event stream", async ({ app }) => {
  heardOn.length = 0;
  heardOn.push(openStream(app.url, ""));
});

Then("the admin event stream answers as an event stream", async () => {
  await expect.poll(() => heardOn[0].text).toMatch(/content-type: text\/event-stream\r\n/i);
});

Then("the admin event stream answers with status 401", async () => {
  await expect.poll(() => heardOn[0].text).toMatch(/^HTTP\/1\.1 401 /);
});

When("a task lands in the backlog beside the calendar", async ({ app }) => {
  await app.sql`INSERT INTO tasks (title, list, position) VALUES ('Synced', 'next', 1)`;
});

When("a mail thread arrives beside the calendar", async ({ app }) => {
  const [{ id }] = await app.sql`INSERT INTO mail_accounts (provider, name) VALUES ('gmail', 'Mail') RETURNING id`;
  await app.sql`INSERT INTO mail_threads (mail_account_id, subject) VALUES (${id}, 'Engines')`;
});

When("a webmention arrives beside the calendar", async ({ app }) => {
  await insertDatedPost(app.sql, "Engines", "published", new Date());
  await app.sql`
    INSERT INTO webmentions (post_id, source_url, type)
    VALUES ((SELECT id FROM posts WHERE title = 'Engines'), 'http://203.0.113.7/reply', 'mention')
  `;
});

Then("every admin event stream hears a change to {string}", async ({ answer: _ }, table: string) => {
  for (const heard of heardOn) await hear(heard, `event: change\ndata: ${table}\n\n`);
});

When("I listen for admin changes in the browser", async ({ page }) => {
  await page.goto("/admin/inbox");
  await page.evaluate(() => {
    const changes: string[] = [];
    const events = new EventSource("/admin/events");
    events.addEventListener("open", () => {
      document.body.dataset.stream = "open";
    });
    events.addEventListener("change", (event) => changes.push((event as MessageEvent).data));
    Object.assign(window, { changes });
  });
  await expect(page.locator("body[data-stream='open']")).toHaveCount(1);
});

Then("the browser hears a change to {string}", async ({ page }, table: string) => {
  await expect.poll(() => page.evaluate(() => (window as unknown as { changes: string[] }).changes)).toContain(table);
});

Then("the admin inbox still loads", async ({ page }) => {
  await page.goto("/admin/inbox");
  await expect(page.locator("h1", { hasText: "Inbox" })).toBeVisible();
});

// The calendar sync job and the mirror it keeps.

Given("Google Calendar lists the calendars:", async ({ stub }, items: string) => {
  stub.reply("GET", `${google}/users/me/calendarList`, {
    body: JSON.stringify({ items: JSON.parse(items) }),
    status: 200,
  });
});

Given("Google Calendar lists the events of {string}:", async ({ app, stub }, id: string, body: string) => {
  stub.reply("GET", `${google}/calendars/${encodeURIComponent(id)}/events`, {
    body: await expand(app.sql, body),
    status: 200,
  });
});

Given("the calendar account {string} holds an expired token", async ({ app }, account: string) => {
  const credentials = { access_token: `ya29.${account}`, expires_at: 1, refresh_token: `1//${account}` };
  await app.sql`
    UPDATE service_connections SET credentials = ${seal(JSON.stringify(credentials))} WHERE account_id = ${account}
  `;
});

Given("the calendar account {string} no longer grants Calendar", async ({ app }, account: string) => {
  await app.sql`DELETE FROM service_connections WHERE account_id = ${account}`;
});

Given("the calendar account {string} was revoked", async ({ app }, account: string) => {
  await app.sql`UPDATE service_connections SET revoked_at = now() WHERE account_id = ${account}`;
});

Given("I hide every calendar", async ({ app }) => {
  await app.sql`UPDATE calendars SET hidden = true`;
});

Given("a calendar sync failed with {string}", async ({ app }, reason: string) => {
  await app.sql`
    INSERT INTO sync_states (kind, sync, synced_at, failure_reason, failure_count, failing_since)
    VALUES ('failure', 'calendar', now(), ${reason}, 1, now())
  `;
});

const waiting = "features_waiting";

// A run that succeeds clears the failure row and one that fails rewrites it, so a row the step
// marks shows when the run is over.
When("the calendar sync runs", async ({ app }) => {
  const [failed] = await app.sql`SELECT id FROM sync_states WHERE kind = 'failure' AND sync = 'calendar'`;
  if (failed) await app.sql`UPDATE sync_states SET failure_reason = ${waiting} WHERE id = ${failed.id}`;
  else {
    await app.sql`
      INSERT INTO sync_states (kind, sync, synced_at, failure_reason, failure_count, failing_since)
      VALUES ('failure', 'calendar', now(), ${waiting}, 1, now())
    `;
  }
  await app.pushJob("Calendar::Jobs::SyncCalendar");
  await expect
    .poll(
      async () => {
        const [row] =
          await app.sql`SELECT failure_reason FROM sync_states WHERE kind = 'failure' AND sync = 'calendar'`;
        return row?.failure_reason;
      },
      { timeout: 15000 },
    )
    .not.toBe(waiting);
});

const locks: { release?: () => Promise<void> } = {};

After(async () => {
  await locks.release?.();
  locks.release = undefined;
});

Given("another calendar sync holds the lock", async ({ app }) => {
  const held = await app.sql.reserve();
  await held`SELECT pg_try_advisory_lock(hashtext('calendar sync'))`;
  locks.release = async () => {
    await held`SELECT pg_advisory_unlock(hashtext('calendar sync'))`;
    held.release();
  };
});

When("the calendar sync runs beside it", async ({ app }) => {
  await app.pushJob("Calendar::Jobs::SyncCalendar");
  await settle(app);
});

Then("the calendar sync records no failure", async ({ app }) => {
  expect(await app.sql`SELECT failure_reason FROM sync_states WHERE kind = 'failure' AND sync = 'calendar'`).toEqual(
    [],
  );
});

Then(
  "the calendar sync records the failure {string} saying {string}",
  async ({ app }, reason: string, message: string) => {
    const [row] = await app.sql`
      SELECT failure_reason, failure_message FROM sync_states WHERE kind = 'failure' AND sync = 'calendar'
    `;
    expect([row?.failure_reason, row?.failure_message]).toEqual([reason, message]);
  },
);

Then("the calendar sync records the failure {string} once", async ({ app }, reason: string) => {
  const [row] = await app.sql`
    SELECT failure_reason, failure_count FROM sync_states WHERE kind = 'failure' AND sync = 'calendar'
  `;
  expect([row?.failure_reason, row?.failure_count]).toEqual([reason, 1]);
});

Then("the calendar mirror holds the calendars:", async ({ app }, table: DataTable) => {
  const rows = await app.sql`SELECT account, name, writable FROM calendars ORDER BY account, name`;
  expect(rows.map(({ account, name, writable }) => [account, name, String(writable)])).toEqual(table.raw());
});

Then("the calendar mirror holds no calendars", async ({ app }) => {
  expect(await app.sql`SELECT id FROM calendars`).toEqual([]);
});

Then("the calendar mirror holds no events", async ({ app }) => {
  expect(await app.sql`SELECT id FROM calendar_events`).toEqual([]);
});

Then("every calendar in the mirror is hidden", async ({ app }) => {
  expect((await app.sql`SELECT hidden FROM calendars`).map(({ hidden }) => hidden)).toEqual(
    expect.arrayContaining([true]),
  );
  expect(await app.sql`SELECT id FROM calendars WHERE NOT hidden`).toEqual([]);
});

Then("the calendar {string} holds the sync token {string}", async ({ app }, id: string, token: string) => {
  const [row] = await app.sql`SELECT sync_token FROM calendars WHERE google_id = ${id}`;
  expect(row?.sync_token).toBe(token);
});

const moments = /^(.*) at (\d{1,2}:\d{2})$/;

Then("the calendar mirror holds the events:", async ({ app }, table: DataTable) => {
  const wanted = table.hashes();
  const columns = Object.keys(wanted[0]);
  const rows = await app.sql`
    SELECT *, starts_on::text AS starts_on, ends_on::text AS ends_on FROM calendar_events ORDER BY google_id
  `;
  const read = (value: unknown) => {
    if (value === null) return "";
    if (value instanceof Date) return iso(value);
    if (Array.isArray(value)) return value.join(", ");
    return String(value);
  };
  const want = (column: string, value: string) => {
    if (!value) return "";
    if (column === "starts_on" || column === "ends_on") return dayOf(value);
    const moment = moments.exec(value);
    if ((column === "starts_at" || column === "ends_at") && moment) return iso(zoned(dayOf(moment[1]), moment[2]));
    return value;
  };

  expect(rows.map((row) => columns.map((column) => read(row[column])))).toEqual(
    wanted.map((row) => columns.map((column) => want(column, row[column]))),
  );
});

const noted: { rows?: postgres.Row[] } = {};

When("I note the calendar event rows", async ({ app }) => {
  noted.rows = await app.sql`SELECT id, google_id, updated_at FROM calendar_events ORDER BY google_id`;
});

Then("the calendar event rows are as I noted them", async ({ app }) => {
  expect(await app.sql`SELECT id, google_id, updated_at FROM calendar_events ORDER BY google_id`).toEqual(noted.rows);
});

Then("the calendar event {string} keeps the row I noted", async ({ app }, id: string) => {
  const [row] = await app.sql`SELECT id FROM calendar_events WHERE google_id = ${id}`;
  expect(row?.id).toBe(noted.rows?.find((found) => found.google_id === id)?.id);
});

const notices: { tables: string[]; stop?: () => Promise<void> } = { tables: [] };

After(async () => {
  await notices.stop?.();
  notices.stop = undefined;
});

When("I listen for admin changes from the calendar sync", async ({ app }) => {
  notices.tables = [];
  const { unlisten } = await app.sql.listen("admin_changes", (table) => notices.tables.push(table));
  notices.stop = unlisten;
});

Then("the calendar sync told the admin of no calendar change", () => {
  expect(notices.tables.filter((table) => table.startsWith("calendar"))).toEqual([]);
});

// The calendar through the API and MCP.

type CalendarDay = { date: string; [key: string]: unknown };

const answerJson = (answer: { body: string }) => JSON.parse(answer.body);

const days = (answer: { body: string }) => answerJson(answer).days as CalendarDay[];

When(
  "I call the calendar API with {word} {string}",
  async ({ answer, app, request, tokens }, method: string, path: string) => {
    const response = await request.fetch(`/api/v1${await expand(app.sql, path)}`, {
      headers: { Authorization: `Bearer ${tokens.api}` },
      method,
    });
    Object.assign(answer, { body: await response.text(), status: response.status() });
  },
);

When(
  "I call the calendar API with {word} {string} and:",
  async ({ answer, app, request, tokens }, method: string, path: string, body: string) => {
    const response = await request.fetch(`/api/v1${await expand(app.sql, path)}`, {
      data: JSON.parse(await expand(app.sql, body)),
      headers: { Authorization: `Bearer ${tokens.api}` },
      method,
    });
    Object.assign(answer, { body: await response.text(), status: response.status() });
  },
);

Then("the calendar API answer is:", async ({ answer, app }, json: string) => {
  expect(answerJson(answer)).toEqual(JSON.parse(await expand(app.sql, json)));
});

Then("the calendar API answer holds:", async ({ answer, app }, json: string) => {
  expect(answerJson(answer)).toMatchObject(JSON.parse(await expand(app.sql, json)));
});

Then("the API calendar runs from {string} to {string}", ({ answer }, from: string, to: string) => {
  const found = answerJson(answer);
  const wanted: string[] = [];
  for (let day = dayOf(from); day <= dayOf(to); day = dayOf(`${day} + 1`)) wanted.push(day);
  expect([found.from, found.to, days(answer).map(({ date }) => date)]).toEqual([dayOf(from), dayOf(to), wanted]);
});

Then("the API calendar lists {int} days", ({ answer }, count: number) => {
  expect(days(answer).length).toBe(count);
});

Then("the API calendar day {string} holds:", async ({ answer, app }, day: string, json: string) => {
  expect(days(answer).find(({ date }) => date === dayOf(day))).toMatchObject(JSON.parse(await expand(app.sql, json)));
});

Then("the API calendar day {string} is empty", ({ answer }, day: string) => {
  expect(days(answer).find(({ date }) => date === dayOf(day))).toEqual({
    date: dayOf(day),
    events: [],
    journal: false,
    posts: [],
    social_posts: [],
    sprint: null,
  });
});

Then("every API calendar day is empty", ({ answer }) => {
  for (const { date, ...rest } of days(answer)) {
    expect([date, rest]).toEqual([date, { events: [], journal: false, posts: [], social_posts: [], sprint: null }]);
  }
});

Then("the API calendar marks a journal on {string} alone", ({ answer }, day: string) => {
  expect(
    days(answer)
      .filter(({ journal }) => journal)
      .map(({ date }) => date),
  ).toEqual([dayOf(day)]);
});

Then("the API calendar titles the events per day:", ({ answer }, table: DataTable) => {
  const titled = (date: string) =>
    ((days(answer).find((found) => found.date === dayOf(date))?.events ?? []) as { title: unknown }[])
      .map(({ title }) => (typeof title === "object" && title ? (title as { text: string }).text : title))
      .join(", ");
  for (const [date, titles] of table.raw()) expect([date, titled(date)]).toEqual([date, titles]);
});

Then("the API calendar lists the posts and social posts the calendar page shows", async ({ answer, page }) => {
  for (const found of days(answer)) {
    const listed = [
      ...(found.posts as { id: number }[]).map(({ id }) => `post-${id}`),
      ...(found.social_posts as { id: number }[]).map(({ id }) => `social-${id}`),
    ];
    await page.goto(`/admin/calendar?day=${found.date}`);
    const shown = await panel(page)
      .locator("[data-calendar-item]")
      .evaluateAll((items) => items.map((item) => item.getAttribute("data-calendar-item") ?? ""));
    expect([found.date, shown.filter((item) => /^(post|social)-/.test(item))]).toEqual([found.date, listed]);
  }
});

function rpcReply(body: string) {
  const data = body
    .split("\n")
    .filter((line) => line.startsWith("data:"))
    .at(-1);
  return JSON.parse(data ? data.slice(5) : body);
}

const trusted = (value: unknown): unknown => {
  if (Array.isArray(value)) return value.map(trusted);
  if (value && typeof value === "object") {
    const record = value as Record<string, unknown>;
    if (record.untrusted === true) return record.text;
    return Object.fromEntries(Object.entries(record).map(([key, inner]) => [key, trusted(inner)]));
  }
  return value;
};

async function rpc(request: Page["request"], token: string | undefined, method: string, params: unknown) {
  const response = await request.post("/mcp", {
    data: { id: 1, jsonrpc: "2.0", method, params },
    headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${token}` },
  });
  return rpcReply(await response.text());
}

const mcpReply: { last?: { error?: { data?: string }; result?: { content: { text: string }[]; isError?: boolean } } } =
  {};

When("I call the calendar MCP tool {string} with:", async ({ app, request, tokens }, name: string, args: string) => {
  mcpReply.last = await rpc(request, tokens.mcp, "tools/call", {
    arguments: JSON.parse(await expand(app.sql, args)),
    name,
  });
});

const mcpText = () => mcpReply.last?.result?.content[0].text ?? "";

Then("the calendar MCP tool answers:", async ({ app }, json: string) => {
  expect([mcpReply.last?.result?.isError ?? false, JSON.parse(mcpText())]).toEqual([
    false,
    JSON.parse(await expand(app.sql, json)),
  ]);
});

Then("the calendar MCP tool refuses with {string}", ({ answer: _ }, text: string) => {
  expect([mcpReply.last?.result?.isError, mcpText()]).toEqual([true, text]);
});

Then("the calendar MCP tool refuses", () => {
  expect(mcpReply.last?.result?.isError).toBe(true);
});

Then("the calendar MCP tool says {string}", ({ answer: _ }, text: string) => {
  expect(mcpText()).toBe(text);
});

Then("the calendar MCP call fails with {string}", ({ answer: _ }, text: string) => {
  expect(mcpReply.last?.error?.data ?? "").toMatch(new RegExp(`^${text.replaceAll(/[.*+?^${}()|[\]\\]/g, "\\$&")}`));
});

Then(
  "the MCP tool list_calendar answers as the API does from {string} to {string}",
  async ({ request, tokens }, from: string, to: string) => {
    const range = { from: dayOf(from), to: dayOf(to) };
    const api = await request.get(`/api/v1/calendar?from=${range.from}&to=${range.to}`, {
      headers: { Authorization: `Bearer ${tokens.api}` },
    });
    const reply = await rpc(request, tokens.mcp, "tools/call", { arguments: range, name: "list_calendar" });
    expect(trusted(JSON.parse(reply.result.content[0].text))).toEqual(await api.json());
  },
);

Then("the MCP server tells the client {string}", async ({ request, tokens }, text: string) => {
  const reply = await rpc(request, tokens.mcp, "initialize", {
    capabilities: {},
    clientInfo: { name: "Claude", version: "1" },
    protocolVersion: "2025-06-18",
  });
  expect(reply.result.instructions).toContain(text);
});

Then("the calendar API answer names errors on {string}", ({ answer }, fields: string) => {
  expect([answer.status, Object.keys(answerJson(answer).errors).sort()]).toEqual([422, fields.split(", ")]);
});

Given("the last calendar sync ran a day ago", async ({ app }) => {
  await app.sql`UPDATE calendars SET synced_from = synced_from - 1`;
});
