import { createCipheriv, createDecipheriv, hkdfSync, randomBytes } from "node:crypto";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { expect } from "@playwright/test";
import type postgres from "postgres";
import { root, run } from "../support/shell.ts";
import { Given, Then, When } from "../support/world.ts";

const previousKey = "p".repeat(64);

const derive = (key: string) => Buffer.from(hkdfSync("sha256", key, "", "blog-encryptor", 32));

function seal(text: string, key: string) {
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", derive(key), iv);
  const body = Buffer.concat([cipher.update(text), cipher.final()]);
  return Buffer.concat([iv, cipher.getAuthTag(), body]).toString("base64");
}

function open(sealed: string, key: string) {
  const raw = Buffer.from(sealed, "base64");
  const decipher = createDecipheriv("aes-256-gcm", derive(key), raw.subarray(0, 12));
  decipher.setAuthTag(raw.subarray(12, 28));
  return Buffer.concat([decipher.update(raw.subarray(28)), decipher.final()]).toString();
}

async function dataKey() {
  const file = await readFile(join(root, "config/settings/test.yml"), "utf8");
  return file.match(/^data_key: (.+)$/m)?.[1] ?? "";
}

const credentials = async (sql: postgres.Sql) =>
  (await sql`SELECT credentials FROM service_connections ORDER BY id`).map((row) => row.credentials as string);

let before: string[] = [];

async function connect(sql: postgres.Sql, sealed: string) {
  const [{ count }] = await sql`SELECT count(*)::int AS count FROM service_connections`;
  await sql`
    INSERT INTO service_connections ${sql({ account_id: `me-${count}`, credentials: sealed, label: "Me", provider: "google" })}
  `;
  before = await credentials(sql);
}

Given("the previous data key is set", ({ shell }) => {
  shell.env.PREVIOUS_DATA_KEY = previousKey;
});

Given(
  "a service connection whose credentials say {string} sealed under the previous data key",
  async ({ app }, text: string) => {
    await connect(app.sql, seal(text, previousKey));
  },
);

Given(
  "a service connection whose credentials say {string} sealed under the data key",
  async ({ app }, text: string) => {
    await connect(app.sql, seal(text, await dataKey()));
  },
);

Given("a service connection whose credentials are {string} sealed under another key", async ({ app }, text: string) => {
  await connect(app.sql, seal(text, "o".repeat(64)));
});

Given("a service connection whose credentials are {string} sealed and then changed", async ({ app }, text: string) => {
  const raw = Buffer.from(seal(text, previousKey), "base64");
  raw[raw.length - 1] ^= 1;
  await connect(app.sql, raw.toString("base64"));
});

Given("a service connection whose credentials are not sealed", async ({ app }) => {
  await connect(app.sql, "hunter2");
});

When("I reseal the credentials", async ({ shell }) => {
  Object.assign(shell, await run("scripts/db/reseal", { env: shell.env }));
});

Then("the credentials open to {string} under the data key alone", async ({ app }, text: string) => {
  const [sealed] = await credentials(app.sql);

  expect(open(sealed, await dataKey())).toBe(text);
  expect(() => open(sealed, previousKey)).toThrow();
});

Then("the credentials do not hold {string} in plain text", async ({ app }, text: string) => {
  const [sealed] = await credentials(app.sql);

  expect(sealed).not.toContain(text);
  expect(Buffer.from(sealed, "base64").toString()).not.toContain(text);
});

Then("the credentials have not changed", async ({ app }) => {
  expect(await credentials(app.sql)).toEqual(before);
});

Then("no two credentials match", async ({ app }) => {
  const sealed = await credentials(app.sql);

  expect(new Set(sealed).size).toBe(sealed.length);
});
