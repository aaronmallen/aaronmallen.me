import { createHash, randomBytes } from "node:crypto";
import { readFile, stat } from "node:fs/promises";
import { expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import { Given, Then, test, When } from "../support/world.ts";
import { ask } from "./http.ts";

const { After, Before } = createBdd(test);

let mark = 0;
let noted: string[] = [];

const secret = () => randomBytes(12).toString("hex");

async function since({ app }: { app: { log: string } }) {
  const text = (await readFile(app.log)).subarray(mark).toString("utf8");
  return text
    .split("\n")
    .filter((line) => !line.includes("[DEBUG]"))
    .join("\n");
}

const hiddenFields = (body: string, action: string) => {
  const form = body.match(new RegExp(`<form[^>]*action="${action}"[^>]*>([\\s\\S]*?)</form>`))?.[1] ?? "";
  return [...form.matchAll(/<input[^>]*type="hidden"[^>]*>/g)].map(([input]) => [
    input.match(/name="([^"]*)"/)?.[1] ?? "",
    (input.match(/value="([^"]*)"/)?.[1] ?? "").replaceAll("&amp;", "&"),
  ]);
};

When("I note where the app log ends", async ({ app }) => {
  mark = (await stat(app.log)).size;
});

Then("the app log since then includes {string}", async ({ app }, text: string) => {
  await expect.poll(() => since({ app })).toContain(text);
});

Then("the app log since then includes {string} at least {int} times", async ({ app }, text: string, count: number) => {
  await expect.poll(async () => (await since({ app })).split(text).length - 1).toBeGreaterThanOrEqual(count);
});

Then("the app log since then matches {string}", async ({ app }, pattern: string) => {
  await expect.poll(() => since({ app })).toMatch(new RegExp(pattern));
});

Then("the app log since then does not include {string}", async ({ app }, text: string) => {
  expect(await since({ app })).not.toContain(text);
});

Then("the app log since then leaves out what I noted", async ({ app }) => {
  const text = await since({ app });
  expect(noted.length).toBeGreaterThan(0);
  expect(noted.filter((value) => text.includes(value))).toEqual([]);
});

Then("the timing rows leave out what I noted", async ({ app }) => {
  const rows = JSON.stringify(await app.sql`SELECT * FROM performance_requests`);
  expect(noted.filter((value) => rows.includes(value))).toEqual([]);
});

When("I sign in through GitHub", async ({ app, page }) => {
  await app.sql`INSERT INTO owner_identities (email) VALUES ('owner@example.com') ON CONFLICT DO NOTHING`;
  page.on("request", (request) => {
    const url = new URL(request.url());
    if (url.pathname.endsWith("/callback"))
      noted.push(...["code", "state"].map((key) => url.searchParams.get(key) ?? ""));
  });
  await page.goto("/admin/sign-in");
  await page.getByRole("button", { name: /GitHub/ }).click();
  await page.waitForURL(/\/admin\/?$/);
});

When("an MCP client is approved and trades its code for tokens", async ({ app, context }) => {
  const world = { app, context };
  const redirectUri = "https://claude.ai/api/mcp/auth_callback";
  const registered = await ask(world, "POST", "/oauth/register", {
    body: JSON.stringify({ client_name: "Logs", redirect_uris: [redirectUri] }),
    headers: { "Content-Type": "application/json" },
  });
  const clientId = JSON.parse(registered.body).client_id;
  const verifier = randomBytes(32).toString("base64url");
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  const state = secret();
  const query = new URLSearchParams({
    client_id: clientId,
    code_challenge: challenge,
    code_challenge_method: "S256",
    redirect_uri: redirectUri,
    response_type: "code",
    state,
  });
  const page = await ask(world, "GET", `/oauth/authorize?${query}`);
  const fields = hiddenFields(page.body, "/oauth/authorize");
  const token = fields.find(([name]) => name === "_csrf_token")?.[1] ?? "";
  const decided = await ask(world, "POST", "/oauth/authorize", {
    body: new URLSearchParams([...fields, ["decision", "approve"]]).toString(),
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
  });
  const code = new URL(decided.headers.location ?? "").searchParams.get("code") ?? "";
  const clientSecret = secret();
  const granted = await ask(world, "POST", "/oauth/token", {
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      code,
      code_verifier: verifier,
      grant_type: "authorization_code",
      redirect_uri: redirectUri,
    }).toString(),
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
  });
  const { access_token, refresh_token } = JSON.parse(granted.body);
  const refresh = secret();
  await ask(world, "POST", "/oauth/token", {
    body: new URLSearchParams({ client_id: clientId, grant_type: "refresh_token", refresh_token: refresh }).toString(),
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
  });
  expect([code, access_token, refresh_token].every(Boolean)).toBe(true);
  noted.push(challenge, state, token, code, verifier, clientSecret, access_token, refresh_token, refresh);
});

Given("a secret {string}", ({}, name: string) => {
  noted.push(`${name}-${secret()}`);
});

When(
  "I request {string} with the secrets I noted as {string}",
  async ({ app, context }, path: string, keys: string) => {
    const names = keys.split(", ");
    const query = new URLSearchParams(names.map((name, index) => [name, noted[index]])).toString();
    await ask({ app, context }, "GET", `${path}${path.includes("?") ? "&" : "?"}${query}`);
  },
);

When("I request {string} from the address {string}", async ({ app, context }, path: string, address: string) => {
  noted.push(address);
  await ask({ app, context }, "GET", path, { headers: { "X-Forwarded-For": address } });
});

When(
  "I post the form {string} with my token and the secrets I noted as {string}",
  async ({ app, context }, path: string, keys: string) => {
    const admin = await ask({ app, context }, "GET", "/admin");
    const token = admin.body.match(/<input[^>]*name="_csrf_token"[^>]*>/)?.[0].match(/value="([^"]+)"/)?.[1] ?? "";
    const names = keys.split(", ");
    const fields = names.map((name, index) => [
      name.replace("=", ""),
      name.includes("=") ? name.split("=")[1] : noted[index],
    ]);
    await ask({ app, context }, "POST", path, {
      body: new URLSearchParams([["_csrf_token", token], ...fields]).toString(),
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
    });
  },
);

let refusing = false;

Given("the timing table refuses every row", async ({ app }) => {
  refusing = true;
  await app.sql`ALTER TABLE performance_requests ADD CONSTRAINT features_refuse CHECK (false) NOT VALID`;
});

Before(() => {
  noted = [];
});

After(async ({ app }) => {
  if (!refusing) return;
  refusing = false;
  await app.sql`ALTER TABLE performance_requests DROP CONSTRAINT IF EXISTS features_refuse`;
});

Given("I note {string}", ({}, value: string) => {
  noted.push(value);
});

let holder: Awaited<ReturnType<import("postgres").Sql["reserve"]>> | undefined;

Given("another session holds a lock on the {word} table", async ({ app }, table: string) => {
  holder = await app.sql.reserve();
  await holder`SET idle_in_transaction_session_timeout = '45s'`;
  await holder`BEGIN`;
  await holder.unsafe(`LOCK TABLE ${table} IN ACCESS EXCLUSIVE MODE`);
});

When("the lock on the {word} table goes", async ({}, _table: string) => {
  await holder?.unsafe("ROLLBACK");
  holder?.release();
  holder = undefined;
});

After(async () => {
  await holder?.unsafe("ROLLBACK");
  holder?.release();
  holder = undefined;
});
