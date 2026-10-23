import { spawn } from "node:child_process";
import { rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import { expect } from "@playwright/test";
import { createClient } from "redis";
import { root } from "../support/shell.ts";
import { Given, Then, When } from "../support/world.ts";

const refresh = "Analytics::Jobs::RefreshCountryDatabase";

Given("MaxMind credentials are {word}", ({ shell }, state: string) => {
  shell.env.MAXMIND_ACCOUNT_ID = state === "set" ? "1" : "";
  shell.env.MAXMIND_LICENSE_KEY = state === "set" ? "stub-key" : "";
  shell.env.MAXMIND_DATABASE_PATH = join(shell.dir, "GeoLite2-City.mmdb");
});

Given("the country database file is {word}", async ({ shell }, state: string) => {
  if (state === "present") await writeFile(join(shell.dir, "GeoLite2-City.mmdb"), "database");
});

When("a worker boots", async ({ app, shell }) => {
  const [{ name }] = await app.sql`SELECT current_database() AS name`;
  const env = { ...shell.env, DATABASE_NAME: name, HANAMI_ENV: "development" };
  const args = ["exec", "sidekiq", "-e", "development", "-r", "./config/sidekiq.rb", "-q", "boot", "-t", "1"];
  const child = spawn("bundle", args, { cwd: root, detached: true, env, stdio: "ignore" });
  shell.children.push(child);
  const redis = createClient({
    url: `redis://default:${shell.env.REDIS_PASSWORD}@127.0.0.1:${shell.env.REDIS_PORT}/1`,
  });
  await redis.connect();
  try {
    await expect.poll(() => redis.sCard("processes"), { timeout: 60_000 }).toBeGreaterThan(0);
    const queued = await redis.lRange("queue:default", 0, -1);
    shell.output = String(queued.filter((job) => JSON.parse(job).class === refresh).length);
    await redis.flushDb();
  } finally {
    redis.destroy();
  }
});

When("the worker is told to stop", async ({ shell }) => {
  const [child] = shell.children;
  const exited = new Promise<number | null>((done) => child.once("exit", done));
  child.kill("SIGTERM");
  shell.status = await exited;
});

Then("the worker has queued {int} country database downloads", ({ shell }, count: number) => {
  expect(shell.output).toBe(String(count));
});

Given("a short link to {string} with no title", async ({ app }, destination: string) => {
  const [code] = await app.sql`INSERT INTO short_codes ${app.sql({ code: "the-page" })} RETURNING id`;
  await app.sql`INSERT INTO short_links ${app.sql({ destination, short_code_id: code.id })}`;
});

Given("the maintenance flag is up", async ({ app }) => {
  await writeFile(app.env.MAINTENANCE_FLAG_PATH ?? "", "");
});

When("the maintenance flag comes down", async ({ app }) => {
  await rm(app.env.MAINTENANCE_FLAG_PATH ?? "", { force: true });
});

When("the short link title job runs", async ({ app }) => {
  const [{ id }] = await app.sql`SELECT id FROM short_links`;
  await app.pushJob("Shares::Jobs::FetchShortLinkTitle", id);
});

Then("the worker puts the job off for later", async ({ app }) => {
  const later = Date.now() / 1000 + 250;
  await expect.poll(() => app.redis.client.zRangeWithScores("schedule", 0, -1)).toHaveLength(1);
  const [{ score }] = await app.redis.client.zRangeWithScores("schedule", 0, -1);

  expect(score).toBeGreaterThan(later);
});

When("the put off job comes due", async ({ app }) => {
  const [{ value }] = await app.redis.client.zRangeWithScores("schedule", 0, -1);
  await app.redis.client.zAdd("schedule", { score: Date.now() / 1000, value });
});

Then("the short link has no title", async ({ app }) => {
  const [{ title }] = await app.sql`SELECT title FROM short_links`;

  expect(title).toBeNull();
});

Then("the short link's title is {string}", async ({ app }, title: string) => {
  await expect
    .poll(async () => (await app.sql`SELECT title FROM short_links`)[0].title, { timeout: 30_000 })
    .toBe(title);
});

Then("the worker drops the job", async ({ app }) => {
  await expect.poll(() => app.redis.client.lLen("queue:default")).toBe(0);
  await sleep(1000);

  expect(await app.redis.client.zCard("schedule")).toBe(0);
});

Then("the post {string} is still scheduled", async ({ app }, title: string) => {
  const [{ status }] = await app.sql`SELECT status FROM posts WHERE title = ${title}`;

  expect(status).toBe("scheduled");
});

When("Redis goes down", ({ app }) => {
  app.redis.stop();
});

When("Redis comes back", async ({ app }) => {
  await app.redis.start();
});
