import { execFile } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { promisify } from "node:util";
import { expect } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { Given, Then, test, When } from "../support/world.ts";

const root = resolve(import.meta.dirname, "../..");
const run = promisify(execFile);

const dumps = (objects: Map<string, { body: Buffer }>) =>
  [...objects.keys()]
    .filter((key) => key.startsWith("backups/"))
    .map((key) => key.slice("backups/".length))
    .sort();

Given("the backup store holds the dumps:", ({ app }, data: DataTable) => {
  for (const [name] of data.raw())
    app.stub.objects.set(`backups/${name}`, { body: Buffer.from("PGDMP"), type: "binary/octet-stream" });
});

Given("these backup key table rows: a post and a task", async ({ app }) => {
  await app.sql`INSERT INTO posts ${app.sql({ body: "", body_html: "", read_time: 1, slug: "kept", title: "Kept", webmentions_enabled: false, word_count: 0 })}`;
  await app.sql`INSERT INTO tasks ${app.sql({ list: "next", number: 1, position: 1, title: "Kept" })}`;
});

Given("only a post in the backup key tables", async ({ app }) => {
  await app.sql`INSERT INTO posts ${app.sql({ body: "", body_html: "", read_time: 1, slug: "kept", title: "Kept", webmentions_enabled: false, word_count: 0 })}`;
});

Then("the backup store holds {int} dumps", ({ app }, count: number) => {
  expect(dumps(app.stub.objects)).toHaveLength(count);
});

Then("the backup store keeps these older dumps:", ({ app }, data: DataTable) => {
  const older = dumps(app.stub.objects).filter((name) => name.startsWith("database-202609"));
  expect(older).toEqual(data.raw().map(([name]) => name));
});

Then("the newest backup is a custom format pg_dump of the database", ({ app }) => {
  const newest = dumps(app.stub.objects).at(-1) ?? "";
  expect(newest).toMatch(/^database-\d{8}T\d{6}Z\.dump$/);
  expect(app.stub.objects.get(`backups/${newest}`)?.body.subarray(0, 5).toString()).toBe("PGDMP");
});

async function restore(
  {
    answer,
    app,
    $testInfo,
  }: {
    answer: { body: string; status: number };
    app: { stub: { url: string } };
    $testInfo: { parallelIndex: number };
  },
  dump: string,
  store: boolean,
) {
  test.setTimeout(180_000);
  const env = {
    ...process.env,
    DATABASE_NAME: "blog_features",
    HANAMI_ENV: "test",
    TEST_ENV_NUMBER: String($testInfo.parallelIndex + 1),
    ...(store ? { STUB_URL: app.stub.url } : {}),
  };
  if (!store) delete env.STUB_URL;
  try {
    const { stderr, stdout } = await run("scripts/db/restore", [dump], { cwd: root, env, timeout: 120_000 });
    answer.status = 0;
    answer.body = stdout + stderr;
  } catch (error) {
    const failed = error as { code?: number; stderr?: string; stdout?: string };
    answer.status = failed.code ?? 1;
    answer.body = `${failed.stdout ?? ""}${failed.stderr ?? ""}`;
  }
}

When("I restore the newest backup by name", async ({ answer, app, $testInfo }) => {
  await restore({ answer, app, $testInfo }, dumps(app.stub.objects).at(-1) ?? "", true);
});

When("I restore the newest backup from a file", async ({ answer, app, $testInfo }) => {
  const newest = dumps(app.stub.objects).at(-1) ?? "";
  const path = join(mkdtempSync(join(tmpdir(), "features-restore-")), newest);
  writeFileSync(path, app.stub.objects.get(`backups/${newest}`)?.body ?? "");
  await restore({ answer, app, $testInfo }, path, true);
});

When("I restore a file that is not a dump", async ({ answer, app, $testInfo }) => {
  const path = join(mkdtempSync(join(tmpdir(), "features-restore-")), "not-a-dump");
  writeFileSync(path, "nothing");
  await restore({ answer, app, $testInfo }, path, true);
});

When("I restore the dump {string} by name", async ({ answer, app, $testInfo }, dump: string) => {
  await restore({ answer, app, $testInfo }, dump, true);
});

When("I restore the dump {string} with no backups bucket", async ({ answer, app, $testInfo }, dump: string) => {
  await restore({ answer, app, $testInfo }, dump, false);
});

Then("the restore succeeds and counts:", ({ answer }, data: DataTable) => {
  expect(answer.status, answer.body).toBe(0);
  for (const [line] of data.raw()) expect(answer.body).toMatch(new RegExp(`^${line}$`, "m"));
});

Then("the restore fails saying {string}", ({ answer }, text: string) => {
  expect(answer.status, answer.body).not.toBe(0);
  expect(answer.body).toContain(text);
});

Then("the restore fails saying one of {string}", ({ answer }, texts: string) => {
  expect(answer.status, answer.body).not.toBe(0);
  expect(
    texts.split(" | ").some((text) => answer.body.includes(text)),
    answer.body,
  ).toBe(true);
});

Then("no scratch restore database is left", async ({ app }) => {
  const [{ name }] = await app.sql`SELECT current_database() AS name`;
  const scratch = await app.sql`SELECT datname FROM pg_database WHERE datname LIKE ${`${name}_restore_%`}`;
  expect(scratch).toHaveLength(0);
});

Then("the backup store got no {word} requests", ({ app }, method: string) => {
  const sent = app.stub
    .requests()
    .filter((request) => request.method === method && request.url.pathname.startsWith("/s3/backups"));
  expect(sent).toHaveLength(0);
});

Then("the backup upload was signed with the backup access key", ({ app }) => {
  const upload = app.stub
    .requests()
    .find((request) => request.method === "PUT" && request.url.pathname.startsWith("/s3/backups/"));
  expect(String(upload?.headers.authorization)).toContain("Credential=stub/");
});
