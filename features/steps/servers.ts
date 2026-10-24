import { type ChildProcess, spawn } from "node:child_process";
import { mkdirSync, openSync, readFileSync } from "node:fs";
import { type AddressInfo, createServer } from "node:net";
import { join } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import { createBdd } from "playwright-bdd";
import { createClient } from "redis";
import { root } from "../support/shell.ts";
import { Given, test } from "../support/world.ts";

const { Before } = createBdd(test);

import { useSite } from "./http.ts";

const secrets = ["ANALYTICS_SALT", "APP_SECRET", "DATA_KEY", "READER_SALT"];
let server: { child: ChildProcess; key: string; secret?: string; url: string } | undefined;

export const serverSecret = () => server?.secret;

function halt() {
  if (server?.child.pid && server.child.exitCode === null) process.kill(-server.child.pid);
  server = undefined;
}

process.on("exit", halt);

async function freePort() {
  const probe = createServer();
  await new Promise<void>((done) => probe.listen(0, "127.0.0.1", done));
  const { port } = probe.address() as AddressInfo;
  await new Promise((done) => probe.close(done));
  return port;
}

async function boot(environment: string, env: NodeJS.ProcessEnv, appPort: string) {
  const port = await freePort();
  const url = `http://127.0.0.1:${port}`;
  mkdirSync(join(root, "tmp"), { recursive: true });
  const log = openSync(join(root, `tmp/features-${environment}-${appPort}.log`), "w");
  const child = spawn("bundle", ["exec", "puma", "--config", "config/puma.rb"], {
    cwd: root,
    detached: true,
    env: { ...env, HANAMI_PORT: String(port), SITE_URL: url },
    stdio: ["ignore", log, log],
  });
  const deadline = Date.now() + 120_000;
  for (;;) {
    if (child.exitCode !== null) throw new Error(`The ${environment} server exited`);
    try {
      await fetch(url, { method: "HEAD" });
      return { child, url };
    } catch (error) {
      if (Date.now() > deadline) throw new Error(`The ${environment} server did not come up`, { cause: error });
      await sleep(250);
    }
  }
}

Before(() => {
  usingServer = false;
});

let usingServer = false;

export const onServer = () => (usingServer ? server?.secret : undefined);

Given("the site runs in {word}", async ({ app, shell }, environment: string) => {
  usingServer = true;
  const [{ name }] = await app.sql`SELECT current_database() AS name`;
  const env: NodeJS.ProcessEnv = {
    ...shell.env,
    DATABASE_NAME: name,
    HANAMI_ENV: environment,
    HANAMI_WEB_CONCURRENCY: "0",
    HONEYBADGER_API_KEY: "",
    HONEYBADGER_REPORT_DATA: "false",
    PREVIOUS_DATA_KEY: "",
  };
  const committed = readFileSync(join(root, "config/settings/test.yml"), "utf8");
  for (const secret of secrets) {
    env[secret] =
      environment === "production"
        ? `${secret.toLowerCase()}-`.padEnd(64, "x")
        : committed.match(new RegExp(`^${secret.toLowerCase()}: (.+)$`, "m"))?.[1];
  }
  const key = JSON.stringify([environment, ...Object.entries(shell.env).filter(([n, v]) => app.env[n] !== v)]);
  if (server && (server.key !== key || server.child.exitCode !== null)) halt();
  const files = readFileSync(join(root, `config/settings/${environment}.yml`), "utf8");
  const secret = files.match(/^app_secret: (.+)$/m)?.[1] ?? env.APP_SECRET;
  server ??= { ...(await boot(environment, env, new URL(app.url).port)), key, secret };
  const db = environment === "development" ? 1 : 0;
  const redis = createClient({
    url: `redis://default:${app.env.REDIS_PASSWORD}@127.0.0.1:${app.env.REDIS_PORT}/${db}`,
  });
  await redis.connect();
  await redis.flushDb();
  redis.destroy();
  useSite(server.url);
});
