import { chmodSync, mkdirSync, readdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { expect } from "@playwright/test";
import { createBdd, type DataTable } from "playwright-bdd";
import type postgres from "postgres";
import { chicago, countryDatabase, dayOf, fill, iso, sha, tarball, today, unique, when } from "../support/analytics.ts";
import { ownerEmail } from "../support/stub.ts";
import { countryFolder, Given, removeCountryFolder, Then, test, When } from "../support/world.ts";

type Row = Record<string, unknown>;

const { After } = createBdd(test);

const agents: Record<string, string> = {
  Chrome: "Mozilla/5.0 (Macintosh) AppleWebKit/537.36 Chrome/141.0.0.0 Safari/537.36",
  Firefox: "Mozilla/5.0 (X11; Linux x86_64) Firefox/140.0",
  Googlebot: "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
  "an iPhone": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Safari/604.1",
  NetNewsWire: "NetNewsWire (RSS Reader; https://netnewswire.com/)",
};

const hashes = new Set(["address_hash", "month_visitor_hash", "reader_hash", "visitor_hash"]);
const stamps = new Set(["occurred_at", "published_at", "received_at", "held_at"]);
const rollups: Record<string, string> = {
  analytics: "analytics_rollups",
  performance: "performance_rollups",
};

const defaults: Record<string, () => Row> = {
  analytics_events: () => ({
    address_hash: sha(unique()),
    country_code: "US",
    occurred_at: new Date(),
    path: `/writing/post-${unique()}`,
    read_seconds: 42,
    referrer_host: "news.example",
    view_token: sha(unique()).slice(0, 32),
    visitor_hash: sha(unique()),
  }),
  feed_reader_hashes: () => ({ path: "/writing.atom", reader_hash: sha(unique()) }),
  feed_readers: () => ({ day: today(), path: "/writing.atom", readers: 1 }),
  feed_subscribers: () => ({ aggregator: "feedly", day: today(), path: "/writing.atom", subscribers: 42 }),
  performance_jobs: () => ({ job: "Spec::Job", outcome: "succeeded", query_count: 3, query_time: 1.5 }),
  performance_pages: () => ({ device_class: "desktop", dom_content_loaded: 20, route: "/", ttfb: 10 }),
  performance_requests: () => ({ query_count: 2, route: "/writing/:slug", status: 200, verb: "GET" }),
  post_reader_hashes: () => ({ path: "/writing/hello", reader_hash: sha(unique()) }),
  webmentions: () => ({ source_url: `https://203.0.113.9/${unique()}`, type: "reply" }),
};

function cell(column: string, value: string): unknown {
  if (value === "none") return null;
  const filled = when(value) ?? fill(value);
  if (hashes.has(column)) return /^[0-9a-f]{64}$/.test(filled) ? filled : sha(filled);
  if (column === "view_token") return sha(filled).slice(0, 32);
  if (stamps.has(column) && /^\d{4}-\d\d-\d\d$/.test(filled)) return chicago(filled);
  if (stamps.has(column) && filled === "now") return new Date();
  return /^-?\d+(\.\d+)?$/.test(filled) ? Number(filled) : filled;
}

async function rowsOf(sql: postgres.Sql, table: string, data: DataTable) {
  const made: Row[] = [];
  for (const given of data.hashes()) {
    const row: Row = {};
    for (const [column, value] of Object.entries(given)) {
      if (value === "" || ["times", "visitor", "view", "post"].includes(column)) continue;
      row[column] = cell(column, value);
    }
    if (given.visitor) {
      const at = row.occurred_at ?? new Date();
      const seen = dayOf(at instanceof Date ? at : new Date(String(at)));
      row.visitor_hash = sha(`${given.visitor} ${seen}`);
      row.month_visitor_hash = sha(`${given.visitor} ${seen.slice(0, 7)}`);
    }
    if (given.view) {
      const [event] = await sql`SELECT id FROM analytics_events WHERE view_token = ${sha(given.view).slice(0, 32)}`;
      row.event_id = event.id;
    }
    if (given.post) {
      const [post] = await sql`SELECT id FROM posts WHERE title = ${given.post}`;
      row.post_id = post.id;
    }
    for (let copy = 0; copy < Number(given.times || 1); copy++) made.push({ ...(defaults[table]?.() ?? {}), ...row });
  }
  return made;
}

async function insert(sql: postgres.Sql, table: string, data: DataTable) {
  const rows = await rowsOf(sql, table, data);
  const parent = rollups[table.split("_rollup_")[0]];
  if (table.includes("_rollup_") && parent) {
    for (const row of rows) {
      const key = parent === "analytics_rollups" && table === "analytics_rollup_reach" ? undefined : row.day;
      if (key) await sql`INSERT INTO ${sql(parent)} ${sql({ day: key })} ON CONFLICT DO NOTHING`;
    }
  }
  for (const row of rows) await sql`INSERT INTO ${sql(table)} ${sql(row)}`;
}

function shown(value: unknown): string {
  if (value === null || value === undefined) return "none";
  if (value instanceof Date) return iso(value);
  if (typeof value === "number") return String(Math.round(value * 1_000_000) / 1_000_000);
  if (Array.isArray(value)) return value.join(" ");
  return String(value);
}

function expected(value: string) {
  if (value === "none") return "none";
  return when(value) ?? fill(value);
}

async function stored(sql: postgres.Sql, table: string, columns: string[], where?: string) {
  const found = await sql.unsafe(
    `SELECT ${columns.map((column) => `"${column}"`).join(", ")} FROM "${table}"${where ? ` WHERE ${fill(where)}` : ""}`,
  );
  return found
    .map((row) =>
      columns.map((column) => {
        const value = row[column];
        if (value instanceof Date && /^(day|month)$/.test(column)) {
          return value.toISOString().slice(0, 10);
        }
        return shown(value);
      }),
    )
    .map((row) => row.join(" | "))
    .sort();
}

const wanted = (data: DataTable) =>
  data
    .hashes()
    .map((row) => Object.values(row).map(expected).join(" | "))
    .sort();

async function rpc(request: World["request"], token: string | undefined, method: string, params: object) {
  const response = await request.post("/mcp", {
    data: { id: 1, jsonrpc: "2.0", method, params },
    headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${token}` },
  });
  expect(response.status()).toBe(200);
  return (await response.json()).result;
}

type World = Parameters<Parameters<typeof When>[1]>[0];

const trusted = (value: unknown): unknown => {
  if (Array.isArray(value)) return value.map(trusted);
  if (value && typeof value === "object") {
    const object = value as Row;
    if (object.untrusted === true) return object.text;
    return Object.fromEntries(Object.entries(object).map(([key, inner]) => [key, trusted(inner)]));
  }
  return value;
};

function dig(value: unknown, path: string) {
  return path
    .split(".")
    .filter(Boolean)
    .reduce<unknown>(
      (found, key) =>
        (found as Row)?.[
          /^-?\d+$/.test(key) && Array.isArray(found)
            ? Number(key) < 0
              ? found.length + Number(key)
              : Number(key)
            : key
        ],
      value,
    );
}

Given("these {word} rows:", async ({ app }, table: string, data: DataTable) => {
  await insert(app.sql, table, data);
});

Given("these analytics posts:", async ({ app }, data: DataTable) => {
  for (const given of data.hashes()) {
    const title = given.title ?? given.slug;
    const body = `A post called ${title}.`;
    const [post] = await app.sql`
      INSERT INTO posts ${app.sql({
        body,
        body_html: `<p>${body}</p>`,
        published_at: given.published ? cell("published_at", given.published) : null,
        read_time: 1,
        slug: given.slug ?? title.toLowerCase().replaceAll(/\W+/g, "-"),
        status: given.status ?? (given.published ? "published" : "draft"),
        title,
        webmentions_enabled: true,
        word_count: body.split(" ").length,
      })}
      RETURNING id
    `;
    for (const name of (given.tags ?? "").split(" ").filter(Boolean)) {
      const [tag] = await app.sql`
        INSERT INTO tags ${app.sql({ color: "mk-blue", name, scope: "public" })}
        ON CONFLICT DO NOTHING RETURNING id
      `;
      const id = tag?.id ?? (await app.sql`SELECT id FROM tags WHERE name = ${name}`)[0].id;
      await app.sql`INSERT INTO post_tags ${app.sql({ post_id: post.id, tag_id: id })}`;
    }
  }
});

Given("the post {string} moved to the slug {string}", async ({ app }, slug: string, renamed: string) => {
  await app.sql`UPDATE posts SET status = 'draft' WHERE slug = ${slug}`;
  await app.sql`UPDATE posts SET slug = ${renamed} WHERE slug = ${slug}`;
  await app.sql`UPDATE posts SET status = 'published' WHERE slug = ${renamed}`;
});

Given("the database refuses to {word} {word} rows", async ({ app }, verb: string, table: string) => {
  const name = `features_refuse_${table}_${verb}`;
  await app.sql.unsafe(`
    CREATE OR REPLACE FUNCTION features_refuse() RETURNS trigger LANGUAGE plpgsql AS
    $$ BEGIN RAISE EXCEPTION 'features refused it'; END $$;
    CREATE TRIGGER ${name} BEFORE ${verb.toUpperCase()} ON "${table}"
    FOR EACH STATEMENT EXECUTE FUNCTION features_refuse();
  `);
});

After(async ({ app }) => {
  const found = await app.sql`
    SELECT tgname, relname FROM pg_trigger JOIN pg_class ON pg_class.oid = tgrelid WHERE tgname LIKE 'features_refuse_%'
  `;
  for (const { tgname, relname } of found) await app.sql.unsafe(`DROP TRIGGER "${tgname}" ON "${relname}"`);
});

When("the job {string} runs", async ({ app }, job: string) => {
  await runJob(app, job, []);
});

When("the job {string} runs with {string}", async ({ app }, job: string, argument: string) => {
  await runJob(app, job, [argument]);
});

When("the job {string} runs {int} times", async ({ app }, job: string, count: number) => {
  for (let run = 0; run < count; run++) await runJob(app, job, []);
});

async function runJob(app: World["app"], job: string, args: unknown[]) {
  const count = async () => Number((await app.sql`SELECT count(*) FROM performance_jobs WHERE job = ${job}`)[0].count);
  const before = await count();
  await app.pushJob(job, ...args);
  await expect.poll(count, { timeout: 60_000 }).toBeGreaterThan(before);
}

Then("the {word} rows are:", async ({ app }, table: string, data: DataTable) => {
  await expect.poll(() => stored(app.sql, table, Object.keys(data.hashes()[0] ?? {}))).toEqual(wanted(data));
});

Then("the {word} rows where {string} are:", async ({ app }, table: string, where: string, data: DataTable) => {
  await expect.poll(() => stored(app.sql, table, Object.keys(data.hashes()[0] ?? {}), where)).toEqual(wanted(data));
});

Then("the {word} table holds {int} rows", async ({ app }, table: string, count: number) => {
  await expect.poll(async () => (await stored(app.sql, table, ["ctid"])).length).toBe(count);
});

Then(
  "the {word} table holds {int} rows where {string}",
  async ({ app }, table: string, count: number, where: string) => {
    await expect.poll(async () => (await stored(app.sql, table, ["ctid"], where)).length).toBe(count);
  },
);

When("I read the analytics through MCP with:", async ({ answer, request, tokens }, args: string) => {
  const result = await rpc(request, tokens.mcp, "tools/call", {
    arguments: JSON.parse(fill(args)),
    name: "read_analytics",
  });
  answer.error = result.isError ?? false;
  answer.body = result.content[0].text;
  answer.content = answer.body;
});

When("I read the performance through MCP with:", async ({ answer, request, tokens }, args: string) => {
  const result = await rpc(request, tokens.mcp, "tools/call", {
    arguments: JSON.parse(fill(args)),
    name: "read_performance",
  });
  answer.error = result.isError ?? false;
  answer.body = result.content[0].text;
  answer.content = answer.body;
});

When("I get {string} from the API", async ({ answer, request, tokens }, path: string) => {
  const response = await request.get(`/api/v1${fill(path)}`, { headers: { Authorization: `Bearer ${tokens.api}` } });
  answer.status = response.status();
  answer.body = await response.text();
});

Then("the read_analytics tool describes {string}", async ({ request, tokens }, text: string) => {
  const { tools } = await rpc(request, tokens.mcp, "tools/list", {});
  expect(tools.find((tool: Row) => tool.name === "read_analytics").description).toContain(text);
});

Then("the answer holds:", ({ answer }, json: string) => {
  expect(JSON.parse(answer.body)).toMatchObject(JSON.parse(fill(json)));
});

Then("the answer at {string} is:", ({ answer }, path: string, json: string) => {
  expect(dig(JSON.parse(answer.body), path)).toEqual(JSON.parse(fill(json)));
});

Then("the answer at {string} counts {int} items", ({ answer }, path: string, count: number) => {
  expect(dig(JSON.parse(answer.body), path)).toHaveLength(count);
});

Then("the answer leaves out {string}", ({ answer }, keys: string) => {
  const found = JSON.parse(answer.body);
  for (const key of keys.split(", ")) expect(found, key).not.toHaveProperty([key]);
});

Then("the answer has the keys {string}", ({ answer }, keys: string) => {
  expect(Object.keys(JSON.parse(answer.body))).toEqual(keys.split(", "));
});

Then("the answer says {string}", ({ answer }, text: string) => {
  expect(answer.body).toBe(text);
});

Then(
  "the answer is what read_analytics answers with {string}, less the untrusted marks",
  async ({ answer, request, tokens }, args: string) => {
    const result = await rpc(request, tokens.mcp, "tools/call", {
      arguments: JSON.parse(fill(args)),
      name: "read_analytics",
    });
    expect(JSON.parse(answer.body)).toEqual(trusted(JSON.parse(result.content[0].text)));
  },
);

Then("the answer is what read_performance answers with {string}", async ({ answer, request, tokens }, args: string) => {
  const result = await rpc(request, tokens.mcp, "tools/call", {
    arguments: JSON.parse(fill(args)),
    name: "read_performance",
  });
  expect(JSON.parse(answer.body)).toEqual(JSON.parse(result.content[0].text));
});

When("{string} sends the beacon:", async ({ answer, page }, agent: string, visit: string) => {
  const response = await page.request.post("/pulse", {
    data: fill(visit),
    headers: { "Content-Type": "application/json", "User-Agent": agents[agent] ?? agent },
  });
  answer.status = response.status();
  answer.body = await response.text();
});

When("{string} fetches the feed {string}", async ({ answer, page }, agent: string, path: string) => {
  const response = await page.request.get(path, { headers: { "User-Agent": agents[agent] ?? agent }, maxRedirects: 0 });
  answer.headers = response.headers();
  answer.status = response.status();
  answer.body = await response.text();
});

When("{string} fetches the feed {string} again unchanged", async ({ answer, page }, agent: string, path: string) => {
  const response = await page.request.get(path, {
    headers: { "If-None-Match": answer.headers?.etag ?? "", "User-Agent": agents[agent] ?? agent },
  });
  answer.status = response.status();
});

When("{string} follows the feed move", async ({ answer, page }, agent: string) => {
  const response = await page.request.get(answer.headers?.location ?? "", {
    headers: { "User-Agent": agents[agent] ?? agent },
  });
  answer.status = response.status();
});

Then("the server answered {int}", ({ answer }, status: number) => {
  expect(answer.status).toBe(status);
});

When("I visit {string} in the admin", async ({ page }, path: string) => {
  await page.goto(fill(path));
});

Then("the screen parts {string} read:", async ({ page }, selector: string, data: DataTable) => {
  await expect(page.locator(fill(selector))).toHaveText(data.raw().map(([text]) => fill(text)));
});

Then("the screen parts {string} are styled:", async ({ page }, selector: string, data: DataTable) => {
  const styles = await page
    .locator(fill(selector))
    .evaluateAll((found) => found.map((part) => part.getAttribute("style")));
  expect(styles).toEqual(data.raw().map(([style]) => style));
});

Then("the screen part {string} reads {string}", async ({ page }, selector: string, text: string) => {
  await expect(page.locator(fill(selector)).first()).toHaveText(fill(text));
});

Then("the screen part {string} mentions {string}", async ({ page }, selector: string, text: string) => {
  await expect(page.locator(fill(selector)).first()).toContainText(fill(text));
});

Then("the screen part {string} does not mention {string}", async ({ page }, selector: string, text: string) => {
  await expect(page.locator(fill(selector)).first()).not.toContainText(fill(text));
});

Then("the screen holds {string}", async ({ page }, selector: string) => {
  await expect(page.locator(fill(selector)).first()).toBeAttached();
});

Then("the screen holds no {string}", async ({ page }, selector: string) => {
  await expect(page.locator(fill(selector))).toHaveCount(0);
});

Then("the screen holds {int} of {string}", async ({ page }, count: number, selector: string) => {
  await expect(page.locator(fill(selector))).toHaveCount(count);
});

Then(
  "the screen part {string} has {string} set to {string}",
  async ({ page }, selector: string, name: string, value: string) => {
    await expect(page.locator(fill(selector)).first()).toHaveAttribute(name, fill(value));
  },
);

Then("the server log mentions {string}", async ({ app }, text: string) => {
  await expect.poll(() => readFileSync(app.log, "utf8")).toContain(text);
});

Then("the page title is {string}", async ({ page }, title: string) => {
  await expect(page).toHaveTitle(title);
});

type Kept = { kept?: unknown; months?: number };

When("I keep the answer", ({ answer }) => {
  (answer as Kept).kept = JSON.parse(answer.body);
});

Then("the answer at {string} is the kept one", ({ answer }, path: string) => {
  expect(dig(JSON.parse(answer.body), path)).toEqual(dig((answer as Kept).kept, path));
});

const weekdays = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"];

Then("the weekday grid counts {int} readers in all", ({ answer }, count: number) => {
  const hours = JSON.parse(answer.body).weekday_hours.hours as Row[];
  expect(hours.reduce((sum, hour) => sum + weekdays.reduce((inner, name) => inner + Number(hour[name]), 0), 0)).toBe(
    count,
  );
});

Then(
  "the weekday grid counts {int} at hour {int} on {word}",
  ({ answer }, count: number, hour: number, name: string) => {
    expect(JSON.parse(answer.body).weekday_hours.hours[hour][name.toLowerCase()]).toBe(count);
  },
);

Given(
  "every month from {string} to {string} rolled up a reach of {int}",
  async ({ answer, app }, from: string, to: string, reach: number) => {
    let month = `${String(when(from)).slice(0, 7)}-01`;
    const last = `${String(when(to)).slice(0, 7)}-01`;
    let count = 0;
    while (month <= last) {
      await app.sql`INSERT INTO analytics_rollup_reach ${app.sql({ month, reach })}`;
      count++;
      const [year, number] = month.split("-").map(Number);
      month = new Date(Date.UTC(year, number, 1)).toISOString().slice(0, 10);
    }
    (answer as Kept).months = count;
  },
);

Then("the answer reach is {int} for each of those months plus {int}", ({ answer }, each: number, more: number) => {
  expect(JSON.parse(answer.body).totals.reach).toBe(each * Number((answer as Kept).months) + more);
});

Given(
  "{int} rolled up paths and referrers on {string}, each bigger than the last",
  async ({ app }, count: number, day: string) => {
    const date = String(when(day));
    await app.sql`INSERT INTO analytics_rollups ${app.sql({ day: date, views: 1000, visitors: 500 })}`;
    for (let n = 0; n < count; n++) {
      await app.sql`
      INSERT INTO analytics_rollup_paths ${app.sql({ bounces: 0, day: date, path: `/writing/rolled-${n}`, views: n + 2, visitors: 1 })}
    `;
      await app.sql`
      INSERT INTO analytics_rollup_referrers ${app.sql({ day: date, host: `rolled-${n}.example`, views: n + 2, visitors: n + 2 })}
    `;
    }
  },
);

Then("the screen rows {string} read:", async ({ page }, selector: string, data: DataTable) => {
  const rows = await page
    .locator(fill(selector))
    .evaluateAll((found) =>
      found.map((row) => [...row.querySelectorAll("th, td")].map((part) => part.textContent?.trim())),
    );
  expect(rows).toEqual(data.raw().map((row) => row.map(fill)));
});

Then("the screen parts {string} add up to {int}", async ({ page }, selector: string, total: number) => {
  const texts = await page.locator(fill(selector)).allTextContents();
  expect(texts.reduce((sum, text) => sum + Number.parseInt(text, 10), 0)).toBe(total);
});

Then("the screen part {string} draws {int} points", async ({ page }, selector: string, count: number) => {
  const points = await page.locator(fill(selector)).first().getAttribute("points");
  expect(points?.trim().split(/\s+/)).toHaveLength(count);
});

When("I hover over the analytics bar {int}", async ({ page }, place: number) => {
  await page
    .locator(".chart-bar")
    .nth(place - 1)
    .hover();
});

When("I pick the range {string}", async ({ page }, range: string) => {
  await page.locator(".seg-option", { hasText: range }).click();
});

Given("the sync {string} failed with {string}", async ({ app }, sync: string, reason: string) => {
  await app.sql`
    INSERT INTO sync_states ${app.sql({
      failing_since: new Date(),
      failure_count: 1,
      failure_reason: reason,
      kind: "failure",
      sync,
      synced_at: new Date(),
    })}
  `;
});

async function failure(sql: postgres.Sql, sync: string) {
  const [found] = await sql`SELECT * FROM sync_states WHERE kind = 'failure' AND sync = ${sync}`;
  return found;
}

Then(
  "the sync failure of {string} is {string} with a message holding {string}",
  async ({ app }, sync: string, reason: string, message: string) => {
    await expect.poll(async () => (await failure(app.sql, sync))?.failure_reason).toBe(reason);
    expect((await failure(app.sql, sync)).failure_message).toContain(message);
  },
);

Then("the sync failure of {string} is {string}", async ({ app }, sync: string, reason: string) => {
  await expect.poll(async () => (await failure(app.sql, sync))?.failure_reason).toBe(reason);
});

Then("the sync failure of {string} counts {int} runs", async ({ app }, sync: string, count: number) => {
  await expect.poll(async () => (await failure(app.sql, sync))?.failure_count).toBe(count);
});

Then("no sync failure of {string} is left", async ({ app }, sync: string) => {
  expect(await failure(app.sql, sync)).toBeUndefined();
});

async function cellsOf(page: World["page"], selector: string) {
  return page
    .locator(fill(selector))
    .evaluateAll((found) =>
      found.map((row) => [...row.querySelectorAll("th, td")].map((part) => part.textContent?.trim())),
    );
}

Then("the screen rows {string} start with:", async ({ page }, selector: string, data: DataTable) => {
  const wanted = data.raw().map((row) => row.map(fill));
  expect((await cellsOf(page, selector)).map((row, index) => row.slice(0, wanted[index]?.length ?? 0))).toEqual(wanted);
});

Then("the screen rows {string} end with:", async ({ page }, selector: string, data: DataTable) => {
  const wanted = data.raw().map((row) => row.map(fill));
  expect((await cellsOf(page, selector)).map((row, index) => row.slice(-(wanted[index]?.length ?? 1)))).toEqual(wanted);
});

Then(
  "the screen part {string} has {string} holding {string}",
  async ({ page }, selector: string, name: string, text: string) => {
    expect(await page.locator(fill(selector)).first().getAttribute(name)).toContain(fill(text));
  },
);

Given("the feed reader hashes are dated {string}", async ({ app }, day: string) => {
  await app.sql`UPDATE feed_reader_hashes SET day = ${String(when(day))}`;
});

When("{string} sends {int} view beacons for {string}", async ({ page }, agent: string, count: number, path: string) => {
  for (let sent = 0; sent < count; sent++) {
    await page.request.post("/pulse", {
      data: JSON.stringify({ kind: "view", path }),
      headers: { "Content-Type": "application/json", "User-Agent": agents[agent] ?? agent },
    });
  }
});

const countryFile = (parallelIndex: number) => resolve(countryFolder(parallelIndex), "GeoLite2-City.mmdb");

function writeCountries(parallelIndex: number, bytes: Buffer) {
  const path = countryFile(parallelIndex);
  mkdirSync(countryFolder(parallelIndex), { recursive: true });
  writeFileSync(`${path}.written`, bytes);
  renameSync(`${path}.written`, path);
}

const download = "/maxmind/geoip/databases/GeoLite2-City/download";

After(({ $testInfo }) => removeCountryFolder($testInfo.parallelIndex));

Given("the country database holds the test networks", ({ $testInfo }) => {
  writeCountries($testInfo.parallelIndex, countryDatabase());
});

Given("the country database holds {string} as {string}", ({ $testInfo }, network: string, country: string) => {
  writeCountries($testInfo.parallelIndex, countryDatabase({ [network]: { country } }));
});

Given("the country database file holds {string}", ({ $testInfo }, text: string) => {
  writeCountries($testInfo.parallelIndex, Buffer.from(text));
});

Given("the country database cannot be read", ({ $testInfo }) => {
  chmodSync(countryFolder($testInfo.parallelIndex), 0o000);
});

Given("the country database folder cannot be written", ({ $testInfo }) => {
  chmodSync(countryFolder($testInfo.parallelIndex), 0o500);
});

Given("the country database folder is empty", ({ $testInfo }) => {
  mkdirSync(countryFolder($testInfo.parallelIndex), { recursive: true });
});

const archives: Record<string, () => Buffer> = {
  "an archive cut short": () => tarball(countryDatabase()).subarray(0, 50),
  "an archive that holds no database": () => tarball(countryDatabase(), "GeoLite2-City_20260928/COPYRIGHT.txt"),
  "an archive of something not a database": () => tarball(Buffer.from("not a database")),
  "something not an archive": () => Buffer.from("not an archive"),
  "the test networks": () => tarball(countryDatabase()),
};

Given("MaxMind answers the download with {string}", ({ stub }, archive: string) => {
  stub.reply("GET", download, { body: archives[archive](), status: 200 });
});

Given("MaxMind answers the download with {string} as {string}", ({ stub }, network: string, country: string) => {
  stub.reply("GET", download, { body: tarball(countryDatabase({ [network]: { country } })), status: 200 });
});

Given("MaxMind answers the download with status {int}", ({ stub }, status: number) => {
  stub.reply("GET", download, { body: "", status });
});

Given("MaxMind sends the download on to {string}", ({ stub }, location: string) => {
  stub.reply("GET", download, { body: "", headers: { Location: location }, status: 302 });
});

Given(
  "MaxMind sends the download on to a mirror on another host that answers with the test networks archive",
  ({ stub }) => {
    stub.reply("GET", download, {
      body: "",
      headers: { Location: `${stub.url.replace("127.0.0.1", "localhost")}/mirror/GeoLite2-City.tar.gz` },
      status: 302,
    });
    stub.reply("GET", "/mirror/GeoLite2-City.tar.gz", { body: tarball(countryDatabase()), status: 200 });
  },
);

Then("the country database file is the test networks", ({ $testInfo }) => {
  expect(readFileSync(countryFile($testInfo.parallelIndex)).equals(countryDatabase())).toBe(true);
});

Then("the country database folder holds nothing", ({ $testInfo }) => {
  expect(readdirSync(countryFolder($testInfo.parallelIndex))).toEqual([]);
});

Then("MaxMind got {int} download request(s) with the account and key", ({ stub }, count: number) => {
  const sent = stub.requests().filter((request) => request.url.pathname === download);
  expect(sent).toHaveLength(count);
  for (const request of sent) {
    expect(request.headers.authorization).toBe(`Basic ${Buffer.from("stub-account:stub-license").toString("base64")}`);
  }
});

Then("the mirror got the download with no credentials", ({ stub }) => {
  const sent = stub.requests().filter((request) => request.url.pathname === "/mirror/GeoLite2-City.tar.gz");
  expect(sent).toHaveLength(1);
  expect(sent[0].headers.authorization).toBeUndefined();
});

When(
  "{string} from {string} sends the beacon:",
  async ({ answer, page }, agent: string, address: string, visit: string) => {
    const response = await page.request.post("/pulse", {
      data: fill(visit),
      headers: { "Content-Type": "application/json", "User-Agent": agents[agent] ?? agent, "X-Forwarded-For": address },
    });
    answer.status = response.status();
  },
);

When("the owner signs in from {string}", async ({ app, browser }, address: string) => {
  await app.sql`INSERT INTO owner_identities ${app.sql({ email: ownerEmail })} ON CONFLICT DO NOTHING`;
  const context = await browser.newContext({
    baseURL: app.url,
    bypassCSP: true,
    extraHTTPHeaders: { "X-Forwarded-For": address },
  });
  const page = await context.newPage();
  await page.goto("/admin/sign-in");
  await page.getByRole("button", { name: /GitHub/ }).click();
  await page.waitForURL(/\/admin\/?$/);
  await context.close();
});
