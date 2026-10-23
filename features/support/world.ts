import { type ChildProcess, execFileSync, spawn } from "node:child_process";
import { randomBytes } from "node:crypto";
import { mkdirSync, openSync } from "node:fs";
import { resolve } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import { type Cookie, expect } from "@playwright/test";
import { test as base, createBdd } from "playwright-bdd";
import postgres from "postgres";
import { createClient } from "redis";
import { ownerEmail, type Stub, startStub } from "./stub.ts";

type App = {
  pushJob: (job: string, ...args: unknown[]) => Promise<void>;
  reset: () => Promise<void>;
  sql: postgres.Sql;
  stub: Stub;
  url: string;
};

type Owner = { cookies: Cookie[]; device: postgres.Row };

const root = resolve(import.meta.dirname, "../..");
const workspace = Number(process.env.WORKSPACE_ID ?? 0);
const firstPort = 20000 + (workspace % 2000) * 20;

async function until(ready: () => Promise<unknown>, what: string) {
  const deadline = Date.now() + 60_000;
  for (;;) {
    try {
      return await ready();
    } catch (error) {
      if (Date.now() > deadline) throw new Error(`${what} did not come up`, { cause: error });
      await sleep(250);
    }
  }
}

function start(name: string, command: string, args: string[], env: NodeJS.ProcessEnv) {
  mkdirSync(resolve(root, "tmp"), { recursive: true });
  const log = openSync(resolve(root, `tmp/features-ws${workspace}-${name}.log`), "w");
  return spawn(command, args, { cwd: root, detached: true, env, stdio: ["ignore", log, log] });
}

async function stop(child: ChildProcess) {
  if (child.exitCode !== null || !child.pid) return;
  const exited = new Promise((done) => child.once("exit", done));
  process.kill(-child.pid, "SIGTERM");
  await exited;
}

export const test = base.extend<
  { reset: undefined; stub: Stub; tokens: { api?: string; mcp?: string } },
  { app: App; owner: Owner }
>({
  app: [
    async ({}, use, { parallelIndex }) => {
      const port = firstPort + parallelIndex * 2;
      const redisPort = port + 1;
      const redisContainer = `aaronmallen.me-features-ws${workspace}-w${parallelIndex}`;
      const password = randomBytes(16).toString("hex");
      const stub = await startStub();
      const url = `http://127.0.0.1:${port}`;
      const env = {
        ...process.env,
        DATABASE_NAME: "blog_features",
        HANAMI_ENV: "test",
        HANAMI_HOST: "127.0.0.1",
        HANAMI_PORT: String(port),
        REDIS_PASSWORD: password,
        REDIS_PORT: String(redisPort),
        REDIS_USER: "default",
        SITE_URL: url,
        STUB_URL: stub.url,
        http_proxy: stub.url,
        https_proxy: stub.url,
        no_proxy: "127.0.0.1,localhost",
        TEST_ENV_NUMBER: String(parallelIndex + 1),
      };

      execFileSync("docker", ["rm", "--force", redisContainer], { stdio: "ignore" });
      execFileSync("docker", [
        "run",
        "--detach",
        "--rm",
        "--name",
        redisContainer,
        "--publish",
        `127.0.0.1:${redisPort}:6379`,
        "redis:8",
        "redis-server",
        "--requirepass",
        password,
        "--save",
        "",
      ]);
      const redis = createClient({ url: `redis://default:${password}@127.0.0.1:${redisPort}/2` });
      redis.on("error", () => {});
      const children: ChildProcess[] = [];
      const sql = postgres({
        database: `blog_features_test${workspace ? `_${workspace}` : ""}_w${parallelIndex + 1}`,
        onnotice: () => {},
        password: process.env.DATABASE_PASSWORD,
        port: Number(process.env.DATABASE_PORT ?? 5432),
        username: process.env.DATABASE_USER ?? "postgres",
      });

      try {
        await until(() => redis.connect(), "Redis");
        execFileSync("bundle", ["exec", "hanami", "db", "prepare"], {
          cwd: root,
          env: { ...env, HANAMI_CLI_DB_COMMAND_RE_RUN_IN_TEST: "true" },
        });
        const [{ tables }] = await sql`
          SELECT string_agg(format('%I', tablename), ', ') AS tables
          FROM pg_tables
          WHERE schemaname = 'public' AND tablename <> 'schema_migrations'
        `;

        children.push(
          start(`w${parallelIndex}-server`, "bundle", ["exec", "puma", "--config", "config/puma.rb"], env),
          start(
            `w${parallelIndex}-sidekiq`,
            "bundle",
            ["exec", "sidekiq", "-e", "test", "-r", "./config/sidekiq.rb", "-C", "features/sidekiq.yml", "-t", "1"],
            env,
          ),
        );
        await until(() => fetch(url, { method: "HEAD" }), "The server");
        await use({
          pushJob: async (job, ...args) => {
            const now = Date.now();
            const payload = { args, class: job, created_at: now, enqueued_at: now, queue: "default", retry: false };
            await redis.sAdd("queues", "default");
            await redis.lPush("queue:default", JSON.stringify({ ...payload, jid: randomBytes(12).toString("hex") }));
          },
          reset: async () => {
            await sql.unsafe(`TRUNCATE ${tables} RESTART IDENTITY CASCADE`);
            await redis.flushDb();
          },
          sql,
          stub,
          url,
        });
      } finally {
        await Promise.all(children.map(stop));
        await sql.end();
        if (redis.isOpen) redis.destroy();
        execFileSync("docker", ["stop", redisContainer], { stdio: "ignore" });
        await stub.stop();
      }
    },
    { scope: "worker", timeout: 180_000 },
  ],
  owner: [
    async ({ app, browser }, use) => {
      await app.sql`INSERT INTO owner_identities ${app.sql({ email: ownerEmail })} ON CONFLICT DO NOTHING`;
      const context = await browser.newContext({ baseURL: app.url, bypassCSP: true });
      const page = await context.newPage();
      await page.goto("/admin/sign-in");
      await page.getByRole("button", { name: /GitHub/ }).click();
      await page.waitForURL(/\/admin\/?$/);
      const { cookies } = await context.storageState();
      const [device] = await app.sql`SELECT * FROM devices`;
      await context.close();
      await use({ cookies, device });
    },
    { scope: "worker" },
  ],
  baseURL: async ({ app }, use) => use(app.url),
  reset: [async ({ app }, use) => use(await app.reset()), { auto: true }],
  stub: [
    async ({ app, context }, use) => {
      const away: string[] = [];
      await context.route(
        (url) => !["127.0.0.1", "localhost"].includes(url.hostname),
        (route) => {
          away.push(`${route.request().method()} ${route.request().url()}`);
          return route.abort();
        },
      );
      app.stub.reset();
      await use(app.stub);
      expect([...app.stub.misses(), ...away], "requests no Given step set a reply for").toEqual([]);
    },
    { auto: true },
  ],
  tokens: async ({}, use) => use({}),
});

export const { Given, When, Then } = createBdd(test);
