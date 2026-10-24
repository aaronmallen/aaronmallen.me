import { type ChildProcess, execFileSync, spawn } from "node:child_process";
import { randomBytes } from "node:crypto";
import { chmodSync, existsSync, mkdirSync, openSync, rmSync } from "node:fs";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import { type Cookie, expect } from "@playwright/test";
import { test as base, createBdd } from "playwright-bdd";
import postgres from "postgres";
import { createClient } from "redis";
import { type Http, http } from "./http.ts";
import { root, type Shell } from "./shell.ts";
import { ownerEmail, type Stub, startStub } from "./stub.ts";

type App = {
  env: NodeJS.ProcessEnv;
  pushJob: (job: string, ...args: unknown[]) => Promise<void>;
  redis: { client: ReturnType<typeof createClient>; start: () => Promise<void>; stop: () => void };
  reset: () => Promise<void>;
  sql: postgres.Sql;
  stub: Stub;
  url: string;
  log: string;
};

type Answer = { body: string; content?: string; error?: boolean; headers?: Record<string, string>; status: number };

type Owner = { cookies: Cookie[]; device: postgres.Row };

const workspace = Number(process.env.WORKSPACE_ID ?? 0);
const firstPort = 20000 + (workspace % 2000) * 20;

export const countryFolder = (parallelIndex: number) =>
  join(root, `tmp/features-ws${workspace}-w${parallelIndex + 1}-maxmind`);

export function removeCountryFolder(parallelIndex: number) {
  const folder = countryFolder(parallelIndex);
  if (!existsSync(folder)) return;
  chmodSync(folder, 0o700);
  rmSync(folder, { force: true, recursive: true });
}

async function settle(redis: ReturnType<typeof createClient>) {
  const deadline = Date.now() + 30_000;
  while (Date.now() < deadline) {
    const processed = Number((await redis.get("stat:processed")) ?? 0);
    const queued = await redis.lLen("queue:default");
    const workers = await redis.sMembers("processes");
    const busy = await Promise.all(workers.map(async (name) => Number((await redis.hGet(name, "busy")) ?? 0)));
    if (processed > 0 && queued === 0 && workers.length > 0 && busy.every((count) => count === 0)) return;
    await sleep(250);
  }
  console.warn("Sidekiq did not settle after its startup jobs; going on");
}

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

const logPath = (name: string) => join(root, `tmp/features-ws${workspace}-${name}.log`);

function start(name: string, command: string, args: string[], env: NodeJS.ProcessEnv) {
  mkdirSync(join(root, "tmp"), { recursive: true });
  const log = openSync(logPath(name), "w");
  return spawn(command, args, {
    cwd: root,
    detached: true,
    env: { ...env, LOG_TO_STDOUT: "true" },
    stdio: ["ignore", log, log],
  });
}

async function stop(child: ChildProcess) {
  if (child.exitCode !== null || !child.pid) return;
  const exited = new Promise((done) => child.once("exit", done));
  process.kill(-child.pid, "SIGTERM");
  await exited;
}

export const test = base.extend<
  {
    answer: Answer;
    http: Http;
    reset: undefined;
    shell: Shell;
    stub: Stub;
    tokens: { api?: string; mcp?: string };
  },
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
        MAINTENANCE_FLAG_PATH: join(root, `tmp/features-ws${workspace}-w${parallelIndex}-maintenance`),
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

      const stopRedis = () => execFileSync("docker", ["rm", "--force", redisContainer], { stdio: "ignore" });
      const startRedis = async () => {
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
        await until(() => redis.isReady || redis.connect(), "Redis");
        await until(() => redis.ping(), "Redis");
      };
      const redis = createClient({ url: `redis://default:${password}@127.0.0.1:${redisPort}/2` });
      redis.on("error", () => {});
      stopRedis();
      const children: ChildProcess[] = [];
      const sql = postgres({
        database: `blog_features_test${workspace ? `_${workspace}` : ""}_w${parallelIndex + 1}`,
        onnotice: () => {},
        password: process.env.DATABASE_PASSWORD,
        port: Number(process.env.DATABASE_PORT ?? 5432),
        username: process.env.DATABASE_USER ?? "postgres",
      });

      try {
        removeCountryFolder(parallelIndex);
        await startRedis();
        execFileSync("bundle", ["exec", "hanami", "db", "prepare"], {
          cwd: root,
          env: { ...env, HANAMI_CLI_DB_COMMAND_RE_RUN_IN_TEST: "true" },
        });
        const [{ tables }] = await sql`
          SELECT string_agg(format('%I', tablename), ', ') AS tables
          FROM pg_tables
          WHERE schemaname = 'public' AND tablename <> 'schema_migrations'
        `;
        const truncate = () => until(() => sql.unsafe(`TRUNCATE ${tables} RESTART IDENTITY CASCADE`), "The truncate");
        await truncate();

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
        await settle(redis);
        await use({
          env,
          pushJob: async (job, ...args) => {
            const now = Date.now();
            const payload = { args, class: job, created_at: now, enqueued_at: now, queue: "default", retry: false };
            await redis.sAdd("queues", "default");
            await redis.lPush("queue:default", JSON.stringify({ ...payload, jid: randomBytes(12).toString("hex") }));
          },
          redis: { client: redis, start: startRedis, stop: stopRedis },
          reset: async () => {
            if (!redis.isReady) await startRedis();
            rmSync(env.MAINTENANCE_FLAG_PATH, { force: true, recursive: true });
            await truncate();
            await redis.flushDb();
          },
          sql,
          log: logPath(`w${parallelIndex}-server`),
          stub,
          url,
        });
      } finally {
        await Promise.all(children.map(stop));
        await sql.end();
        if (redis.isOpen) redis.destroy();
        stopRedis();
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
  answer: async ({}, use) => use({ body: "", status: 0 }),
  baseURL: async ({ app }, use) => use(app.url),
  http: async ({ answer, app, page, playwright }, use) => {
    const { dispose, state } = http(
      page,
      (userAgent) => playwright.request.newContext({ baseURL: app.url, userAgent }),
      answer,
    );
    await use(state);
    await dispose();
  },
  reset: [async ({ app }, use) => use(await app.reset()), { auto: true }],
  shell: async ({ app }, use) => {
    const dir = await mkdtemp(join(tmpdir(), "features-"));
    const shell: Shell = { children: [], dir, env: { ...app.env, ROOT: root, SCRATCH: dir }, output: "", status: null };
    await use(shell);
    await Promise.all(shell.children.map(stop));
    await rm(dir, { force: true, recursive: true });
  },
  stub: [
    async ({ app, context }, use) => {
      const away: string[] = [];
      await context.route(
        (url) => !["127.0.0.1", "localhost"].includes(url.hostname) && !url.hostname.endsWith(".localhost"),
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

export const { After, Before, Given, When, Then } = createBdd(test);
