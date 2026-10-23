import { setTimeout as sleep } from "node:timers/promises";
import { expect } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import type postgres from "postgres";
import { run } from "../support/shell.ts";
import { Given, Then, When } from "../support/world.ts";

const codes: Record<string, string> = { check: "23514", unique: "23505" };

Given("the database runs:", async ({ app }, statement: string) => {
  await app.sql.unsafe(statement).simple();
});

Given("the database runs {string}", async ({ app }, statement: string) => {
  if (statement) await app.sql.unsafe(statement).simple();
});

When("the database runs {string} while the admin listens", async ({ app, shell }, statement: string) => {
  const heard: string[] = [];
  const { unlisten } = await app.sql.listen("admin_changes", (table) => heard.push(table));
  await app.sql.unsafe(statement).simple();
  await sleep(500);
  await unlisten();
  shell.output = heard.join(", ") || "nothing";
});

Then("the admin hears of {string}", ({ shell }, heard: string) => {
  expect(shell.output).toBe(heard);
});

Then("the database answers {string} for:", async ({ app }, answer: string, query: string) => {
  const rows = await app.sql.unsafe(query);

  expect(rows.map((row) => Object.values(row).join(", ")).join("\n")).toBe(answer);
});

Then("the database refuses, breaking a {word} constraint:", async ({ app }, kind: string, statement: string) => {
  await expect(app.sql.unsafe(statement)).rejects.toMatchObject({ code: codes[kind] });
});

Then("the output names this worker's database", async ({ app, shell }) => {
  const [{ name }] = await app.sql`SELECT current_database() AS name`;

  expect(shell.output).toContain(name);
});

Then("the task numbers in id order are {string}", async ({ app }, numbers: string) => {
  const rows = await app.sql`SELECT number FROM tasks ORDER BY id`;

  expect(rows.map(({ number }) => number).join(", ")).toBe(numbers);
});

Then("the task numbers are {string} in some order", async ({ app }, numbers: string) => {
  const rows = await app.sql`SELECT number FROM tasks ORDER BY number`;

  expect(rows.map(({ number }) => number).join(", ")).toBe(numbers);
});

const waiters = async (sql: postgres.Sql) => {
  const [{ count }] = await sql`
    SELECT count(*)::int AS count FROM pg_locks
    WHERE locktype = 'advisory' AND NOT granted AND database = (SELECT oid FROM pg_database WHERE datname = current_database())
  `;
  return count;
};

When("two tasks in the project {string} are created at once", async ({ app }, key: string) => {
  const [{ id }] = await app.sql`SELECT id FROM projects WHERE key = ${key}`;
  const holder = await app.sql.reserve();
  await holder`SELECT pg_advisory_lock(hashtext('tasks_next_number'), ${id})`;
  const task = { list: "next", position: 1, project_id: id, title: "task" };
  const inserts = [1, 2].map(() => app.sql`INSERT INTO tasks ${app.sql(task)}`.execute());
  await expect.poll(() => waiters(app.sql)).toBe(2);
  await holder`SELECT pg_advisory_unlock(hashtext('tasks_next_number'), ${id})`;
  holder.release();
  await Promise.all(inserts);
});

When("I capture the task {string} in the admin", async ({ page }, title: string) => {
  await page.goto("/admin/tasks/new");
  await page.getByRole("textbox", { exact: true, name: "Title" }).fill(title);
  await page.getByRole("button", { name: "Create task" }).click();
  await page.waitForURL(/\/admin\/tasks(\?|$)/);
});

let locker: postgres.ReservedSql | undefined;
let asked: Promise<{ seconds: number; status: number }> | undefined;
let counts: Record<string, number> = {};

const rowCounts = async (sql: postgres.Sql) => {
  const tables = await sql`SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename`;
  const pairs = await Promise.all(
    tables.map(async ({ tablename }) => {
      const [{ count }] = await sql`SELECT count(*)::int AS count FROM ${sql(tablename)}`;
      return [tablename, count] as const;
    }),
  );
  return Object.fromEntries(pairs);
};

Given("the database drops the app's connections", async ({ app }) => {
  await app.sql`
    SELECT pg_terminate_backend(pid) FROM pg_stat_activity
    WHERE datname = current_database() AND pid <> pg_backend_pid() AND application_name <> 'postgres.js'
  `;
});

Given("the database drops the admin hub's connection", async ({ app }) => {
  await app.sql`
    SELECT pg_terminate_backend(pid) FROM pg_stat_activity
    WHERE datname = current_database() AND application_name = 'admin_live_hub'
  `;
});

Given("another session locks the posts table", async ({ app }) => {
  locker = await app.sql.reserve();
  await locker`SET idle_in_transaction_session_timeout = '45s'`;
  await locker`BEGIN`;
  await locker`LOCK TABLE posts IN ACCESS EXCLUSIVE MODE`;
});

When("the other session lets the posts table go", async () => {
  await locker?.unsafe("ROLLBACK");
  locker?.release();
  locker = undefined;
});

When("I ask for {string}", ({ app }, path: string) => {
  const started = Date.now();
  asked = fetch(`${app.url}${path}`).then(({ status }) => ({ seconds: (Date.now() - started) / 1000, status }));
});

Then("it answers {int} after {int} seconds", async ({}, status: number, seconds: number) => {
  const answer = await asked;

  expect(answer?.status).toBe(status);
  expect(answer?.seconds).toBeGreaterThanOrEqual(seconds);
  expect(answer?.seconds).toBeLessThan(seconds + 5);
});

Then("the home page answers {int}", async ({ page }, status: number) => {
  const response = await page.goto("/");

  expect(response?.status()).toBe(status);
});

Then("the database soon answers {string} for:", async ({ app }, answer: string, query: string) => {
  await expect
    .poll(async () => (await app.sql.unsafe(query)).map((row) => Object.values(row).join(" ")).join("\n"))
    .toBe(answer);
});

When("I seed the database as development", async ({ app, shell }) => {
  const [{ name }] = await app.sql`SELECT current_database() AS name`;
  const env = { ...shell.env, DATABASE_NAME: name, HANAMI_ENV: "development" };
  Object.assign(shell, await run("scripts/db/seed", { env }));
});

Then("each of these tables holds a row:", async ({ app }, table: DataTable) => {
  const all = await rowCounts(app.sql);

  expect(table.hashes().filter(({ table: name }) => !all[name])).toEqual([]);
});

When("I count the rows in every table", async ({ app }) => {
  counts = await rowCounts(app.sql);
});

Then("every table holds the rows it did", async ({ app }) => {
  expect(await rowCounts(app.sql)).toEqual(counts);
});
