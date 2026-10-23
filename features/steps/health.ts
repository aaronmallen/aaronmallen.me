import { createCipheriv, createDecipheriv, createHash, hkdfSync, randomBytes } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { type DataTable, expect, type Page } from "@playwright/test";
import type postgres from "postgres";
import type { Stub } from "../support/stub.ts";
import { Given, Then, When } from "../support/world.ts";

const zone = "America/Chicago";

function today() {
  return new Intl.DateTimeFormat("en-CA", { timeZone: zone }).format(new Date());
}

function shifted(date: string, days: number) {
  const moved = new Date(`${date}T12:00:00Z`);
  moved.setUTCDate(moved.getUTCDate() + days);
  return moved.toISOString().slice(0, 10);
}

export function healthDay(ago: string | number) {
  return /^\d{4}-/.test(String(ago)) ? String(ago) : shifted(today(), -Number(ago));
}

export function chicago(date: string, clock: string) {
  const guess = new Date(`${date}T${clock.padStart(5, "0")}:00Z`);
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat("en-US", {
      day: "2-digit",
      hour: "2-digit",
      hourCycle: "h23",
      minute: "2-digit",
      month: "2-digit",
      timeZone: zone,
      year: "numeric",
    })
      .formatToParts(guess)
      .map(({ type, value }) => [type, value]),
  );
  const seen = Date.UTC(+parts.year, +parts.month - 1, +parts.day, +parts.hour, +parts.minute);
  return new Date(guess.getTime() + (guess.getTime() - seen));
}

function number(value: string | undefined) {
  return value === undefined || value === "" ? null : Number(value);
}

async function insertTask(sql: postgres.Sql, row: Record<string, unknown>) {
  const [{ next }] = await sql`SELECT coalesce(max(number), 0) + 1 AS next FROM tasks`;
  const [task] = await sql`
    INSERT INTO tasks ${sql({ list: "next", number: next, position: next, title: `Task ${next}`, ...row })} RETURNING id
  `;
  return task.id as number;
}

Given("the health days:", async ({ app }, table: DataTable) => {
  for (const row of table.hashes()) {
    const day = healthDay(row.day);
    await app.sql`
      INSERT INTO health_days ${app.sql({
        active_zone_minutes: number(row.zone),
        bed_at: row.bed ? chicago(shifted(day, -1), row.bed) : null,
        day,
        hrv: number(row.hrv),
        minutes_asleep: number(row.asleep),
        resting_heart_rate: number(row.resting),
        steps: number(row.steps),
        woke_at: row.woke ? chicago(day, row.woke) : null,
      })}
    `;
  }
});

Given("the workouts:", async ({ app }, table: DataTable) => {
  for (const row of table.hashes()) {
    await app.sql`
      INSERT INTO workouts ${app.sql({
        average_heart_rate: number(row.heart),
        device: row.device || null,
        distance_meters: number(row.distance),
        google_id: `users/me/dataTypes/exercise/dataPoints/${row.name || randomBytes(4).toString("hex")}`,
        kcal: number(row.kcal),
        kind: row.kind || "RUNNING",
        minutes: number(row.minutes) ?? 30,
        started_at: chicago(healthDay(row.day), row.at),
        zone_minutes: number(row.zone),
      })}
    `;
  }
});

Given("the commits:", async ({ app }, table: DataTable) => {
  for (const [index, row] of table.hashes().entries()) {
    await app.sql`
      INSERT INTO commits ${app.sql({
        branch: "main",
        commit_date: healthDay(row.day),
        commit_time: row.at,
        message: "Change things",
        repo: "aaronmallen/aaronmallen.me",
        sha: createHash("sha1").update(`${index}`).digest("hex"),
      })}
    `;
  }
});

Given("a task done on the health day {string} at {string}", async ({ app }, day: string, clock: string) => {
  await insertTask(app.sql, { completed_at: chicago(healthDay(day), clock), status: "done" });
});

Given("a task canceled on the health day {string} at {string}", async ({ app }, day: string, clock: string) => {
  await insertTask(app.sql, { completed_at: chicago(healthDay(day), clock), status: "canceled" });
});

Given("the work sessions:", async ({ app }, table: DataTable) => {
  for (const row of table.hashes()) {
    const started = chicago(healthDay(row.day), row.from);
    const ended = chicago(healthDay(row.until_day || row.day), row.until);
    const [found] = row.task ? await app.sql`SELECT id FROM tasks WHERE title = ${row.task}` : [];
    const done = row.done ? { completed_at: chicago(healthDay(row.done), "11:00"), status: "done" } : {};
    const task =
      found?.id ??
      (await insertTask(app.sql, {
        status: "in_progress",
        worked_seconds: number(row.worked) ?? (ended.getTime() - started.getTime()) / 1000,
        ...(row.task ? { title: row.task } : {}),
        ...done,
      }));
    await app.sql`INSERT INTO work_sessions ${app.sql({ ended_at: ended, started_at: started, task_id: task })}`;
  }
});

Given(
  "a pull request opened on the health day {string} at {string} and merged on {string} at {string}",
  async ({ app }, opened: string, at: string, merged: string, mergedAt: string) => {
    await app.sql`
      INSERT INTO pull_requests ${app.sql({
        merged_at: chicago(healthDay(merged), mergedAt),
        number: 1,
        opened_at: chicago(healthDay(opened), at),
        ready_at: chicago(healthDay(opened), at),
        repo: "aaronmallen/aaronmallen.me",
        title: "Merged",
        url: "https://github.com/aaronmallen/aaronmallen.me/pull/1",
      })}
    `;
  },
);

Given("a pull request ready on the health day {string} at {string}", async ({ app }, day: string, at: string) => {
  await app.sql`
    INSERT INTO pull_requests ${app.sql({
      number: 2,
      opened_at: chicago(healthDay(day), at),
      ready_at: chicago(healthDay(day), at),
      repo: "aaronmallen/aaronmallen.me",
      title: "Ready",
      url: "https://github.com/aaronmallen/aaronmallen.me/pull/2",
    })}
  `;
});

Given("a journal entry on the health day {string}", async ({ app }, day: string) => {
  await app.sql`
    INSERT INTO journal_entries ${app.sql({
      body: "A day.",
      body_html: "<p>A day.</p>",
      entry_date: healthDay(day),
      entry_time: "20:00",
    })}
  `;
});

Given("the MCP client {string} holding {string}", async ({ app }, name: string, scopes: string) => {
  const [client] = await app.sql`
    INSERT INTO oauth_clients ${app.sql({
      client_id: randomBytes(8).toString("hex"),
      client_name: name === "no name" ? null : name,
      grant_types: ["authorization_code"],
      redirect_uris: ["https://claude.ai/api/mcp/auth_callback"],
      response_types: ["code"],
      visitor_hash: randomBytes(32).toString("hex"),
    })}
    RETURNING id
  `;
  const revoked = scopes.endsWith(", revoked");
  await app.sql`
    INSERT INTO oauth_tokens (oauth_client_id, type, token_digest, scopes, expires_at, revoked_at)
    VALUES (
      ${client.id}, 'access', ${randomBytes(32).toString("hex")}, ${`{${scopes.replace(", revoked", "").split(" ").join(",")}}`},
      ${new Date(Date.now() + 3_600_000)}, ${revoked ? new Date() : null}
    )
  `;
});

Given("the API token {string} holding {string}", async ({ app }, name: string, scopes: string) => {
  await app.sql`
    INSERT INTO api_tokens (name, token_digest, scopes)
    VALUES (${name}, ${randomBytes(32).toString("hex")}, ${`{${scopes.split(" ").join(",")}}`})
  `;
});

When("I open the health page", async ({ page }) => {
  await page.goto("/admin/health");
});

When("I open the health page with span {string}", async ({ page }, span: string) => {
  await page.goto(`/admin/health?span=${span}`);
});

When(
  "I open the health page with span {string} on the day {int} days ago",
  async ({ page }, span: string, ago: number) => {
    await page.goto(`/admin/health?span=${span}&day=${healthDay(ago)}`);
  },
);

When(
  "I read the health days from {string} to {string} through the API",
  async ({ answer, request, tokens }, from: string, to: string) => {
    const response = await request.get("/api/v1/health/days", {
      headers: { Authorization: `Bearer ${tokens.api}` },
      params: { from: healthDay(from), to: healthDay(to) },
    });
    answer.status = response.status();
    answer.body = await response.text();
  },
);

When(
  "I read the health days from {string} to {string} through MCP",
  async ({ answer, request, tokens }, from: string, to: string) => {
    const response = await request.post("/mcp", {
      data: {
        id: 1,
        jsonrpc: "2.0",
        method: "tools/call",
        params: { arguments: { from: healthDay(from), to: healthDay(to) }, name: "read_health_days" },
      },
      headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${tokens.mcp}` },
    });
    const reply = await response.json();
    answer.error = reply.error ? true : (reply.result?.isError ?? false);
    answer.body = reply.error ? reply.error.data : reply.result.content[0].text;
    answer.content = answer.body;
  },
);

async function cells(page: Page, row: number) {
  return page.locator(".health-grid-row").nth(row).locator("a");
}

Then("the health grid draws {int} columns", async ({ page }, count: number) => {
  await expect(await cells(page, 0)).toHaveCount(count);
});

Then(
  "the health grid flags row {int} only on the day(s) {string} days ago",
  async ({ page }, row: number, agos: string) => {
    const flagged = (await cells(page, row)).filter({ has: page.locator("i.lo") });
    const days = await flagged.evaluateAll((links) =>
      links.map((link) => /day=([\d-]+)/.exec(link.getAttribute("href") ?? "")?.[1]),
    );
    expect(days).toEqual(agos.split(" ").map((ago) => healthDay(ago)));
  },
);

Then("the health grid marks the day {int} days ago", async ({ page }, ago: number) => {
  await expect(page.locator(".health-grid-row").first().locator("a.on")).toHaveAttribute(
    "href",
    new RegExp(healthDay(ago)),
  );
});

Then("the health day is titled {string}", async ({ page }, title: string) => {
  await expect(page.locator(".health-day-title")).toHaveText(title);
});

Then("the health day offers no {string}", async ({ page }, label: string) => {
  await expect(page.locator(".health-day-head span.seg-option[aria-disabled]", { hasText: label })).toHaveCount(1);
});

Then(
  "the health day links the days {int} and {int} days ago with span {int}",
  async ({ page }, before: number, after: number, span: number) => {
    await expect(page.locator("a[rel='prev']")).toHaveAttribute(
      "href",
      `/admin/health?span=${span}&day=${healthDay(before)}`,
    );
    await expect(page.locator("a[rel='next']")).toHaveAttribute(
      "href",
      `/admin/health?span=${span}&day=${healthDay(after)}`,
    );
  },
);

Then(
  "the health spans offered are {string} with {string} current",
  async ({ page }, spans: string, current: string) => {
    await expect(page.locator(".health-bar .seg-option")).toHaveText(spans.split(" "));
    await expect(page.locator(".seg-option.current[aria-current='page']")).toHaveText(current);
  },
);

Then("the health rows under {string} read:", async ({ page }, key: string, table: DataTable) => {
  const rows = page
    .locator(".health-day-key", { hasText: key })
    .locator("xpath=following-sibling::*[contains(@class,'health-rows')][1]");
  await expect(rows.locator(".health-row")).toHaveText(table.raw().map(([text]) => text));
});

Then("the health value {string} is marked low", async ({ page }, value: string) => {
  await expect(page.locator(".health-row-value.lo", { hasText: value })).toHaveCount(1);
});

Then("the health workout reads {string}", async ({ page }, text: string) => {
  await expect(page.locator(".health-workout")).toHaveText(text);
});

Then("the health card {string} says {string}", async ({ page }, card: string, text: string) => {
  await expect(page.locator(".card", { hasText: card }).locator(".empty")).toContainText(text);
});

Then("the health card {string} lists:", async ({ page }, card: string, table: DataTable) => {
  const items = page.locator(".card", { hasText: card }).locator(".li");
  const seen = await items.evaluateAll((rows) =>
    rows.map((row) => [
      row.querySelector(".li-title")?.textContent?.trim(),
      row.querySelector(".li-sub")?.textContent?.trim(),
    ]),
  );
  expect(seen).toEqual(table.raw());
});

Then("the health pattern reads {string}", async ({ page }, text: string) => {
  await expect(page.locator(".health-pattern").first()).toContainText(text);
});

Then("the health hint under the bar reads {string}", async ({ page }, text: string) => {
  await expect(page.locator(".health-bar .hint")).toHaveText(text);
});

Then("the health patterns card hint reads {string}", async ({ page }, text: string) => {
  await expect(page.locator(".card", { hasText: "Patterns" }).locator(".hint")).toHaveText(text);
});

Then(
  "the resting heart rate averages on the patterns card match read_health_days from {int} days ago",
  async ({ page, request, tokens }, ago: number) => {
    const shown = (
      await page.locator(".card", { hasText: "Patterns" }).locator(".health-pattern", { hasText: "bpm" }).innerText()
    )
      .match(/[\d.]+(?= bpm)/g)
      ?.map(Number);
    const response = await request.post("/mcp", {
      data: {
        id: 1,
        jsonrpc: "2.0",
        method: "tools/call",
        params: { arguments: { from: healthDay(ago), to: today() }, name: "read_health_days" },
      },
      headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${tokens.mcp}` },
    });
    const rest = JSON.parse((await response.json()).result.content[0].text).patterns.resting_heart_rate;
    expect(shown).toEqual([rest.subject.averages.resting_heart_rate, rest.rest.averages.resting_heart_rate]);
  },
);

Then("the health days answer holds:", ({ answer }, expected: string) => {
  expect(answer.error ?? false, answer.body).toBe(false);
  expect(JSON.parse(answer.body)).toMatchObject(JSON.parse(expected));
});

Then("the health days answer lists the days {string} to {string}", ({ answer }, from: string, to: string) => {
  const days = JSON.parse(answer.body).days.map((row: { day: string }) => row.day);
  const wanted: string[] = [];
  for (let day = healthDay(from); day <= healthDay(to); day = shifted(day, 1)) wanted.push(day);
  expect(days).toEqual(wanted);
});

Then("the health days answer has no patterns", ({ answer }) => {
  expect(Object.values(JSON.parse(answer.body).patterns)).toEqual([null, null, null, null]);
});

Then("the health days are refused with {string}", ({ answer }, message: string) => {
  expect(answer.body).toContain(message);
});

Then("the health page sits among the Insights tabs", async ({ page }) => {
  await expect(page.locator("a.pill-nav-link[aria-current='page']")).toHaveText("Insights");
  await expect(page.locator("a.screen-tab")).toHaveText(["analytics", "activity", "health", "time report"]);
  await expect(page.locator(".screen-tab[aria-current='page']")).toHaveText("health");
});

const root = resolve(import.meta.dirname, "../..");
const healthScopes = ["sleep", "activity_and_fitness", "health_metrics_and_measurements"].map(
  (name) => `https://www.googleapis.com/auth/googlehealth.${name}.readonly`,
);
const googleScopes: Record<string, string[]> = {
  calendar: ["https://www.googleapis.com/auth/calendar"],
  health: healthScopes,
  mail: ["https://mail.google.com/"],
  openid: ["openid"],
};

function dataKey() {
  const settings = readFileSync(resolve(root, "config/settings/test.yml"), "utf8");
  const key = /^data_key: (.+)$/m.exec(settings)?.[1] ?? "";
  return Buffer.from(hkdfSync("sha256", key, "", "blog-encryptor", 32));
}

function seal(text: string) {
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", dataKey(), iv);
  const body = Buffer.concat([cipher.update(text), cipher.final()]);
  return Buffer.concat([iv, cipher.getAuthTag(), body]).toString("base64");
}

function unseal(sealed: string) {
  const raw = Buffer.from(sealed, "base64");
  const decipher = createDecipheriv("aes-256-gcm", dataKey(), raw.subarray(0, 12));
  decipher.setAuthTag(raw.subarray(12, 28));
  return Buffer.concat([decipher.update(raw.subarray(28)), decipher.final()]).toString();
}

async function connectGoogle(
  sql: postgres.Sql,
  account: string,
  scopes: string,
  { revoked = false, token = "ya29.token" } = {},
) {
  const credentials = {
    access_token: token,
    expires_at: Math.floor(Date.now() / 1000) + 3600,
    refresh_token: `1//${randomBytes(8).toString("hex")}`,
  };
  await sql`
    INSERT INTO service_connections (provider, account_id, label, credentials, scopes, revoked_at)
    VALUES (
      'google', ${account}, ${account}, ${seal(JSON.stringify(credentials))},
      ${`{${scopes
        .split(" ")
        .flatMap((name) => googleScopes[name])
        .join(",")}}`}, ${revoked ? new Date() : null}
    )
  `;
}

Given("Google Health is connected", async ({ app }) => {
  await connectGoogle(app.sql, "aaron@example.com", "health");
});

Given("Google is connected as {string} with the scopes {string}", async ({ app }, account: string, scopes: string) => {
  await connectGoogle(app.sql, account, scopes);
});

Given(
  "Google is connected as {string} with the scopes {string} and the token {string}",
  async ({ app }, account: string, scopes: string, token: string) => {
    await connectGoogle(app.sql, account, scopes, { token });
  },
);

Given("Google Health is connected but needs a reconnect", async ({ app }) => {
  await connectGoogle(app.sql, "aaron@example.com", "health", { revoked: true });
});

type Point = { at?: string; body: object; day: string; page: number };
type Fake = {
  points: Record<string, Point[]>;
  refusals: { type: string; status: number; firstOnly: boolean; oneOnly: boolean; seen: number }[];
};

const fakes = new WeakMap<object, Fake>();

function civil(day: string) {
  const [year, month, date] = day.split("-").map(Number);
  return { year, month, day: date };
}

function point(row: Record<string, string>): [string, Point] {
  const day = healthDay(row.day);
  const value = row.value;
  const page = Number(row.page || 1);
  switch (row.type) {
    case "sleep": {
      const bedDay = (row.from ?? "") > (row.until ?? "") ? shifted(day, -1) : day;
      const bed = chicago(bedDay, row.from).toISOString();
      const woke = chicago(day, row.until).toISOString();
      return [
        "sleep",
        {
          at: woke,
          body: { sleep: { interval: { endTime: woke, startTime: bed }, summary: { minutesAsleep: value } } },
          day,
          page,
        },
      ];
    }
    case "broken sleep":
      return ["sleep", { at: new Date().toISOString(), body: { sleep: {} }, day, page }];
    case "resting":
      return [
        "daily-resting-heart-rate",
        { body: { daily_resting_heart_rate: { beatsPerMinute: value, date: civil(day) } }, day, page },
      ];
    case "hrv":
      return [
        "daily-heart-rate-variability",
        {
          body: {
            daily_heart_rate_variability: { averageHeartRateVariabilityMilliseconds: Number(value), date: civil(day) },
          },
          day,
          page,
        },
      ];
    case "steps":
      return [
        "steps",
        { body: { civilStartTime: { date: civil(day) }, ...(value ? { steps: { countSum: value } } : {}) }, day, page },
      ];
    case "zones":
      return [
        "active-zone-minutes",
        {
          body: { activeZoneMinutes: { sumInFatBurnHeartZone: value }, civilStartTime: { date: civil(day) } },
          day,
          page,
        },
      ];
    default: {
      const [clock, offset] = (row.from ?? "").split(/(?=[+-]\d\d:\d\d$)/);
      const start = offset ? new Date(`${day}T${clock}:00${offset}`) : chicago(day, clock);
      const end = new Date(start.getTime() + 1900 * 1000);
      return [
        "exercise",
        {
          body: {
            dataSource: { device: { displayName: "Pixel Watch 3" } },
            exercise: {
              activeDuration: "1800s",
              exerciseType: "RUNNING",
              interval: { endTime: end.toISOString(), startTime: start.toISOString() },
              metricsSummary: {
                activeZoneMinutes: "24",
                averageHeartRateBeatsPerMinute: "152",
                caloriesKcal: 410.4,
                distanceMillimeters: 5_000_000,
              },
            },
            name: `users/me/dataTypes/exercise/dataPoints/${row.name}`,
          },
          day,
          page,
        },
      ];
    }
  }
}

function within(found: Point, bounds: [string, string][]) {
  return bounds.every(([sign, edge]) => {
    const value = edge.length === 10 ? found.day : (found.at ?? found.day);
    return sign === "<" ? value < edge : value >= edge;
  });
}

function fakeGoogleHealth(stub: Stub, scenario: object) {
  const fake: Fake = fakes.get(scenario) ?? { points: {}, refusals: [] };
  if (fakes.has(scenario)) return fake;
  fakes.set(scenario, fake);
  let tokens = 0;
  stub.reply("POST", "/google/oauth/token", () => ({
    body: JSON.stringify({ access_token: `ya29.health-${++tokens}`, expires_in: 3600, scope: healthScopes.join(" ") }),
    status: 200,
  }));
  stub.reply("GET", "/google/health/*", ({ url }) => {
    const type = /dataTypes\/([^/]+)\/dataPoints$/.exec(url.pathname)?.[1] ?? "";
    const one = url.searchParams.get("page_size") === "1";
    const refusal = fake.refusals.find((refused) => refused.type === type && (!refused.oneOnly || one));
    if (refusal && !(refusal.firstOnly && refusal.seen++ > 0)) return { body: "", status: refusal.status };
    const bounds = [...(url.searchParams.get("filter") ?? "").matchAll(/(>=|<) "([^"]+)"/g)].map(
      ([, sign, edge]) => [sign, edge] as [string, string],
    );
    const found = (fake.points[type] ?? []).filter((each) => within(each, bounds));
    const page = Number(url.searchParams.get("page_token")?.replace("page-", "") ?? 1);
    const more = found.some((each) => each.page > page);
    const dataPoints = found.filter((each) => each.page === page).map((each) => each.body);
    return {
      body: JSON.stringify({ dataPoints, ...(more ? { nextPageToken: `page-${page + 1}` } : {}) }),
      status: 200,
    };
  });
  stub.reply("POST", "/google/health/*", ({ body, url }) => {
    const type = /dataTypes\/([^/]+)\/dataPoints:dailyRollUp$/.exec(url.pathname)?.[1] ?? "";
    const { range } = JSON.parse(body.toString());
    const day = ({ date: { year, month, day: date } }: { date: { year: number; month: number; day: number } }) =>
      `${year}-${String(month).padStart(2, "0")}-${String(date).padStart(2, "0")}`;
    const rollupDataPoints = (fake.points[type] ?? [])
      .filter((each) => each.day >= day(range.start) && each.day < day(range.end))
      .map((each) => each.body);
    return { body: JSON.stringify({ rollupDataPoints }), status: 200 };
  });
  return fake;
}

Given("Google Health holds nothing", ({ $testInfo, app }) => {
  fakeGoogleHealth(app.stub, $testInfo).points = {};
});

Given("Google Health holds:", ({ $testInfo, app }, table: DataTable) => {
  const fake = fakeGoogleHealth(app.stub, $testInfo);
  fake.points = {};
  for (const row of table.hashes()) {
    const [type, found] = point(row);
    fake.points[type] = [...(fake.points[type] ?? []), found];
  }
});

Given("Google Health answers {int} for {word}", ({ $testInfo, app }, status: number, type: string) => {
  fakeGoogleHealth(app.stub, $testInfo).refusals.push({ firstOnly: false, oneOnly: false, seen: 0, status, type });
});

Given(
  "Google Health answers {int} for {word} when asked for one point",
  ({ $testInfo, app }, status: number, type: string) => {
    fakeGoogleHealth(app.stub, $testInfo).refusals.push({ firstOnly: false, oneOnly: true, seen: 0, status, type });
  },
);

Given(
  "Google Health turns the first {word} read away with {int}",
  ({ $testInfo, app }, type: string, status: number) => {
    fakeGoogleHealth(app.stub, $testInfo).refusals.push({ firstOnly: true, oneOnly: false, seen: 0, status, type });
  },
);

Given("the health sync failed with {string} since {int} days ago", async ({ app }, reason: string, ago: number) => {
  const since = chicago(healthDay(ago), "00:00");
  await app.sql`
    INSERT INTO sync_states (kind, sync, synced_at, failure_reason, failing_since, failure_count)
    VALUES ('failure', 'health', ${since}, ${reason}, ${since}, 1)
  `;
});

function sidekiqLog(parallelIndex: number) {
  const path = resolve(root, `tmp/features-ws${Number(process.env.WORKSPACE_ID ?? 0)}-w${parallelIndex}-sidekiq.log`);
  return existsSync(path) ? readFileSync(path, "utf8") : "";
}

function jobLines(parallelIndex: number) {
  const log = sidekiqLog(parallelIndex);
  return {
    ended: (log.match(/: (done|fail)\b/g) ?? []).length,
    failed: (log.match(/class=Health::\S+ .*: fail\b/g) ?? []).length,
    started: (log.match(/: start\b/g) ?? []).length,
  };
}

export async function runJobs(
  app: { pushJob: (job: string, ...args: unknown[]) => Promise<void> },
  parallelIndex: number,
  job: string,
  ...args: unknown[]
) {
  const before = jobLines(parallelIndex).ended;
  await app.pushJob(job, ...args);
  let quiet = 0;
  await expect
    .poll(
      () => {
        const now = jobLines(parallelIndex);
        quiet = now.ended > before && now.started === now.ended ? quiet + 1 : 0;
        return quiet;
      },
      { intervals: [250], timeout: 30_000 },
    )
    .toBeGreaterThanOrEqual(6);
}

When("the health sync runs", async ({ $testInfo, app }) => {
  await runJobs(app, $testInfo.parallelIndex, "Health::Jobs::SyncHealth");
});

When("the health backfill runs from {int} days ago", async ({ $testInfo, app }, ago: number) => {
  await runJobs(app, $testInfo.parallelIndex, "Health::Jobs::BackfillHealth", healthDay(ago));
});

When("the held health backfills are queued", async ({ $testInfo, app }) => {
  $testInfo.setTimeout($testInfo.timeout + 30_000);
  await runJobs(app, $testInfo.parallelIndex, "Health::Jobs::QueueHeldBackfills");
});

When("another health sync holds the lock while the health sync runs", async ({ $testInfo, app }) => {
  const elsewhere = await app.sql.reserve();
  await elsewhere`SELECT pg_try_advisory_lock(hashtext('health sync'))`;
  try {
    await runJobs(app, $testInfo.parallelIndex, "Health::Jobs::SyncHealth");
  } finally {
    await elsewhere`SELECT pg_advisory_unlock(hashtext('health sync'))`;
    elsewhere.release();
  }
});

Then("the health sync sends the admin no notice when it runs again", async ({ $testInfo, app }) => {
  const notices: string[] = [];
  const { unlisten } = await app.sql.listen("admin_changes", (payload) => notices.push(payload));
  await runJobs(app, $testInfo.parallelIndex, "Health::Jobs::SyncHealth");
  await unlisten();
  expect(notices).toEqual([]);
});

Then("the health days stored are:", async ({ app }, table: DataTable) => {
  const rows = await app.sql`
    SELECT day::text, minutes_asleep, bed_at, woke_at, resting_heart_rate, hrv, steps, active_zone_minutes
    FROM health_days ORDER BY day
  `;
  expect(
    rows.map((row) => ({
      asleep: String(row.minutes_asleep ?? ""),
      bed: row.bed_at ? row.bed_at.toISOString() : "",
      day: row.day,
      hrv: String(row.hrv ?? ""),
      resting: String(row.resting_heart_rate ?? ""),
      steps: String(row.steps ?? ""),
      woke: row.woke_at ? row.woke_at.toISOString() : "",
      zone: String(row.active_zone_minutes ?? ""),
    })),
  ).toEqual(
    table.hashes().map((row) => {
      const day = healthDay(row.day);
      const bedDay = (row.bed ?? "") > (row.woke ?? "") ? shifted(day, -1) : day;
      return {
        asleep: row.asleep ?? "",
        bed: row.bed ? chicago(bedDay, row.bed).toISOString() : "",
        day,
        hrv: row.hrv ?? "",
        resting: row.resting ?? "",
        steps: row.steps ?? "",
        woke: row.woke ? chicago(day, row.woke).toISOString() : "",
        zone: row.zone ?? "",
      };
    }),
  );
});

Then("no health day is stored", async ({ app }) => {
  expect(await app.sql`SELECT day FROM health_days`).toHaveLength(0);
});

Then("the workouts stored are {string}", async ({ app }, names: string) => {
  const rows = await app.sql`SELECT google_id FROM workouts ORDER BY google_id`;
  expect(rows.map((row) => String(row.google_id).split("/").pop()).join(" ")).toBe(names);
});

Then(
  "the workout {string} is stored as a {int} minute run at {string} on the health day {string}",
  async ({ app }, name: string, minutes: number, clock: string, day: string) => {
    const [row] = await app.sql`SELECT * FROM workouts WHERE google_id LIKE ${`%/${name}`}`;
    expect({ ...row, created_at: undefined, id: undefined, updated_at: undefined }).toEqual({
      average_heart_rate: 152,
      created_at: undefined,
      device: "Pixel Watch 3",
      distance_meters: 5000,
      google_id: `users/me/dataTypes/exercise/dataPoints/${name}`,
      id: undefined,
      kcal: 410,
      kind: "RUNNING",
      minutes,
      started_at: chicago(healthDay(day), clock),
      updated_at: undefined,
      zone_minutes: 24,
    });
  },
);

Then(
  "the health sync failure reads {string} with {string} counted {int}",
  async ({ app }, reason: string, message: string, count: number) => {
    const rows =
      await app.sql`SELECT failure_reason, failure_message, failure_count FROM sync_states WHERE kind = 'failure' AND sync = 'health'`;
    expect(rows.map((row) => [row.failure_reason, row.failure_message, row.failure_count])).toEqual([
      [reason, message, count],
    ]);
  },
);

Then("the health sync failure reads {string}", async ({ app }, reason: string) => {
  const rows = await app.sql`SELECT failure_reason FROM sync_states WHERE kind = 'failure' AND sync = 'health'`;
  expect(rows.map((row) => row.failure_reason)).toEqual([reason]);
});

Then("no health sync failure is recorded", async ({ app }) => {
  expect(await app.sql`SELECT id FROM sync_states WHERE kind = 'failure' AND sync = 'health'`).toHaveLength(0);
});

Then("a health job failed with {string}", async ({ $testInfo }, message: string) => {
  expect(jobLines($testInfo.parallelIndex).failed).toBeGreaterThan(0);
  expect(sidekiqLog($testInfo.parallelIndex)).toContain(message);
});

function sent(stub: Stub, prefix: string) {
  return stub.requests().filter((each) => each.url.pathname.startsWith(prefix));
}

Then("Google was asked nothing about health", ({ app }) => {
  expect(sent(app.stub, "/google/").map((each) => `${each.method} ${each.url}`)).toEqual([]);
});

Then("Google Health was asked for {word} with the filter:", ({ app }, type: string, filter: string) => {
  const filters = sent(app.stub, `/google/health/users/me/dataTypes/${type}/`).map((each) =>
    each.url.searchParams.get("filter"),
  );
  const wanted = filter
    .trim()
    .replace(/\{(\d+) ago\}/g, (_, days) => healthDay(Number(days)))
    .replace(/\{(\d+) ahead\}/g, (_, days) => healthDay(-Number(days)))
    .replace(/\{today\}/g, () => healthDay(0));
  expect(filters).toContain(wanted);
});

Then(
  "Google Health was asked for the {word} rollup ending on the health day {string}",
  ({ app }, type: string, day: string) => {
    const ends = sent(app.stub, `/google/health/users/me/dataTypes/${type}/`).map(
      (each) => JSON.parse(each.body.toString()).range.end,
    );
    expect(ends).toContainEqual({ date: civil(healthDay(day)) });
  },
);

Then(
  "Google Health was not asked for the {word} rollup ending on the health day {string}",
  ({ app }, type: string, day: string) => {
    const ends = sent(app.stub, `/google/health/users/me/dataTypes/${type}/`).map(
      (each) => JSON.parse(each.body.toString()).range.end,
    );
    expect(ends).not.toContainEqual({ date: civil(healthDay(day)) });
  },
);

Then("Google was asked for {int} narrowed health token(s)", ({ app }, count: number) => {
  const asked = sent(app.stub, "/google/oauth/token").map((each) =>
    new URLSearchParams(each.body.toString()).get("scope"),
  );
  expect(asked).toEqual(Array(count).fill(healthScopes.join(" ")));
});

Then("Google Health never saw the token {string}", ({ app }, token: string) => {
  const used = sent(app.stub, "/google/health/").map((each) => each.headers.authorization);
  expect(used.length).toBeGreaterThan(0);
  expect(used).not.toContain(`Bearer ${token}`);
});

Then("the stored Google token for {string} is still {string}", async ({ app }, account: string, token: string) => {
  const [row] = await app.sql`SELECT credentials FROM service_connections WHERE account_id = ${account}`;
  expect(JSON.parse(unseal(row.credentials)).access_token).toBe(token);
});

When("I connect Google Health as {string} in the admin", async ({ $testInfo, app, page }, account: string) => {
  fakeGoogleHealth(app.stub, $testInfo);
  app.stub.reply("GET", "/google/openid/userinfo", { body: JSON.stringify({ email: account }), status: 200 });
  await page.goto("/admin/settings/services");
  const token = await page.locator("input[name='_csrf_token']").first().inputValue();
  const started = await page.request.post("/admin/services/google/connect", {
    form: { _csrf_token: token, "scopes[]": healthScopes[0] },
    maxRedirects: 0,
  });
  const state = new URL(started.headers().location ?? "").searchParams.get("state") ?? "";
  const back = await page.request.get(`/admin/auth/google/callback?code=code&state=${state}`, { maxRedirects: 0 });
  expect(back.status()).toBe(302);
});

Then("the held health backfills start from the health day(s) {string}", async ({ app }, days: string) => {
  const rows = await app.sql`SELECT last_day::text FROM held_health_backfills ORDER BY last_day`;
  expect(rows.map((row) => row.last_day).join(" ")).toBe(
    days
      .split(" ")
      .filter(Boolean)
      .map((day) => healthDay(day))
      .join(" "),
  );
});
