import { createHash } from "node:crypto";
import { setTimeout as sleep } from "node:timers/promises";
import { type APIRequestContext, expect } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { csrfIn, type Http } from "../support/http.ts";
import { Given, Then, When } from "../support/world.ts";

const day = 24 * 60 * 60;
const started = new WeakMap<Http, Record<string, URLSearchParams[]>>();
const sessionCookie = "admin.session";
const deviceCookie = "admin.device";

type Cookie = Awaited<ReturnType<APIRequestContext["storageState"]>>["cookies"][number];

type Context = import("@playwright/test").BrowserContext;
const copies = new WeakMap<Context, Cookie | undefined>();
const notes = new WeakMap<Context, string | undefined>();

const sent = (http: Http, as = "") => started.get(http)?.[as] ?? [];

async function cookies(agent: APIRequestContext) {
  return (await agent.storageState()).cookies;
}

async function startSignIn(http: Http, provider: string, from = "/admin", as = "") {
  const agent = await http.agent(as);
  await agent.get(from, { maxRedirects: 0 });
  const form = await (await agent.get("/admin/sign-in")).text();
  const token = csrfIn(form.slice(form.indexOf(`action="/admin/sign-in/${provider}"`)));
  await http.send("POST", `/admin/sign-in/${provider}`, { as, form: { _csrf_token: token } });
  const query = new URL(http.last?.headers().location ?? "", "http://stub").searchParams;
  started.set(http, { ...started.get(http), [as]: [...sent(http, as), query] });
  return query;
}

async function callBack(http: Http, params: Record<string, string>, as = "", provider = "github") {
  await http.send("GET", `/admin/auth/${provider}/callback?${new URLSearchParams(params)}`, { as });
}

async function signIn(http: Http, as = "", from = "/admin") {
  const query = await startSignIn(http, "github", from, as);
  await callBack(http, { code: "code", state: query.get("state") ?? "" }, as);
}

async function signedOut(http: Http, as = "") {
  const response = await (await http.agent(as)).get("/admin", { maxRedirects: 0 });
  return (response.headers().location ?? "").endsWith("/admin/sign-in");
}

async function signOut(http: Http, as = "", token?: string, headers?: Record<string, string>) {
  const form = token === undefined ? { _csrf_token: await http.csrf(as) } : token ? { _csrf_token: token } : undefined;
  await http.send("POST", "/admin/sign-out", { as, form, headers });
}

const verifierMatches = (body: string, challenge: string | null) =>
  createHash("sha256")
    .update(new URLSearchParams(body).get("code_verifier") ?? "")
    .digest("base64url") === challenge;

Given("{string} is an owner", async ({ app }, email: string) => {
  await app.sql`INSERT INTO owner_identities ${app.sql({ email })} ON CONFLICT DO NOTHING`;
});

Given("there are no owners", async ({ app }) => {
  await app.sql`DELETE FROM owner_identities`;
});

Given("GitHub says the account's email is {string}", ({ stub }, email: string) => {
  const body = JSON.stringify([{ email, primary: true, verified: true }]);
  stub.reply("GET", "/github/api/user/emails", { body, status: 200 });
});

Given("my browser holds the device cookie {string}", async ({ context }, value: string) => {
  await context.addCookies([{ domain: "127.0.0.1", name: deviceCookie, path: "/admin", value }]);
});

When("I start a {word} sign-in", async ({ http }, provider: string) => {
  await startSignIn(http, provider.toLowerCase());
});

When("I start a GitHub sign-in from {string}", async ({ http }, from: string) => {
  await startSignIn(http, "github", from);
});

When("I start {int} GitHub sign-ins", async ({ http }, count: number) => {
  for (let tab = 0; tab < count; tab++) await startSignIn(http, "github");
});

When("I sign in with GitHub", async ({ http }) => {
  await signIn(http);
});

When("I sign in with GitHub from {string}", async ({ http }, from: string) => {
  await signIn(http, "", from);
});

When("I sign in with GitHub on {string}", async ({ http }, as: string) => {
  await signIn(http, as);
});

When("GitHub calls back to the last sign-in", async ({ http }) => {
  await callBack(http, { code: "code", state: sent(http).at(-1)?.get("state") ?? "" });
});

When("GitHub calls back to sign-in {int}", async ({ http }, tab: number) => {
  await callBack(http, { code: "code", state: sent(http)[tab - 1]?.get("state") ?? "" });
});

When("GitHub calls back with the state {string}", async ({ http }, state: string) => {
  await callBack(http, { code: "code", state });
});

When("GitHub calls back with no state", async ({ http }) => {
  await callBack(http, { code: "code" });
});

When("GitHub calls back to the last sign-in with no code", async ({ http }) => {
  await callBack(http, { code: "", state: sent(http).at(-1)?.get("state") ?? "" });
});

When("GitHub calls back to the last sign-in denied", async ({ http }) => {
  await callBack(http, { error: "access_denied", state: sent(http).at(-1)?.get("state") ?? "" });
});

Given("{string} sends the user agent {string}", async ({ http }, as: string, userAgent: string) => {
  await http.agent(as, userAgent);
});

Given("{string} sends a user agent of {int} characters", async ({ http }, as: string, length: number) => {
  await http.agent(as, "a".repeat(length));
});

When("I start a GitHub sign-in on {string}", async ({ http }, as: string) => {
  await startSignIn(http, "github", "/admin", as);
});

When("GitHub calls back to {string}'s last sign-in denied", async ({ http }, as: string) => {
  await callBack(http, { error: "access_denied", state: sent(http, as).at(-1)?.get("state") ?? "" }, as);
});

When("GitHub calls back to {string} with the state {string}", async ({ http }, as: string, state: string) => {
  await callBack(http, { code: "code", state }, as);
});

When("GitHub calls back with the state {string} {int} time(s)", async ({ http }, state: string, count: number) => {
  for (let time = 0; time < count; time++) await callBack(http, { code: "code", state });
});

When("Google calls back with the state {string}", async ({ http }, state: string) => {
  await callBack(http, { code: "code", state }, "", "google");
});

When("I sign out", async ({ http }) => {
  await signOut(http);
});

When("I sign out on {string}", async ({ http }, as: string) => {
  await signOut(http, as);
});

When("I sign out without a CSRF token", async ({ http }) => {
  await signOut(http, "", "");
});

When("I sign out with the CSRF token {string}", async ({ http }, token: string) => {
  await signOut(http, "", token);
});

When("I sign out with the CSRF token in a header", async ({ http }) => {
  await signOut(http, "", "", { "X-CSRF-Token": await http.csrf() });
});

When("I sign out with the CSRF token {string} holds", async ({ http }, as: string) => {
  await signOut(http, "", await http.csrf(as));
});

When("I keep a copy of my session cookie", async ({ context }) => {
  copies.set(
    context,
    (await context.cookies()).find(({ name }) => name === sessionCookie),
  );
});

When("my browser puts the copy back", async ({ context }) => {
  const copied = copies.get(context);
  expect(copied, "a kept session cookie").toBeTruthy();
  await context.addCookies([copied as Cookie]);
});

When("{string} signs out my browser's device from the security tab", async ({ context, http }, as: string) => {
  const device = (await context.cookies()).find(({ name }) => name === deviceCookie)?.value;
  await http.send("POST", `/admin/settings/security/devices/${device}/sign-out`, {
    as,
    form: { _csrf_token: await http.csrf(as) },
  });
});

When("I sign out {string}'s device from the security tab", async ({ http }, as: string) => {
  const device = (await cookies(await http.agent(as))).find(({ name }) => name === deviceCookie)?.value;
  await http.send("POST", `/admin/settings/security/devices/${device}/sign-out`, {
    form: { _csrf_token: await http.csrf() },
  });
});

When("I sign out my own device from the security tab", async ({ context, http }) => {
  const device = (await context.cookies()).find(({ name }) => name === deviceCookie)?.value;
  await http.send("POST", `/admin/settings/security/devices/${device}/sign-out`, {
    form: { _csrf_token: await http.csrf() },
  });
});

When("a second passes", async () => {
  await sleep(1100);
});

When("every device is deleted", async ({ app }) => {
  await app.sql`DELETE FROM devices`;
});

Then("I am signed out", async ({ http }) => {
  expect(await signedOut(http)).toBe(true);
});

Then("I am still signed in", async ({ http }) => {
  expect(await signedOut(http)).toBe(false);
});

Then("{string} is signed out", async ({ http }, as: string) => {
  expect(await signedOut(http, as)).toBe(true);
});

Then("{string} is still signed in", async ({ http }, as: string) => {
  expect(await signedOut(http, as)).toBe(false);
});

Then("the sign-in went to {string}", ({ app, http }, url: string) => {
  expect(http.last?.headers().location).toMatch(new RegExp(`^${RegExp.escape(url.replace("STUB", app.stub.url))}\\?`));
});

Then("the sign-in asked for:", ({ app, http }, table: DataTable) => {
  const query = sent(http).at(-1);
  for (const [name, value] of Object.entries(table.rowsHash())) {
    expect(query?.get(name), name).toBe(value.replace("SITE", app.url));
  }
});

Then("the sign-in sent a state of at least {int} characters", ({ http }, length: number) => {
  expect(sent(http).at(-1)?.get("state")?.length).toBeGreaterThanOrEqual(length);
});

Then("the sign-in sent an S256 code challenge", ({ http }) => {
  const query = sent(http).at(-1);
  expect(query?.get("code_challenge_method")).toBe("S256");
  expect(query?.get("code_challenge")).toMatch(/^[\w-]{43}$/);
});

Then("{word} was asked for {int} token(s)", ({ stub }, provider: string, count: number) => {
  const path = provider === "Google" ? "/google/oauth/token" : "/github/login/oauth/access_token";
  expect(stub.received("POST", path)).toHaveLength(count);
});

Then("GitHub got the verifier behind sign-in {int}'s challenge", ({ http, stub }, tab: number) => {
  const [request] = stub.received("POST", "/github/login/oauth/access_token").slice(-1);
  expect(verifierMatches(request, sent(http)[tab - 1].get("code_challenge"))).toBe(true);
});

Then("GitHub did not get the verifier behind sign-in {int}'s challenge", ({ http, stub }, tab: number) => {
  const [request] = stub.received("POST", "/github/login/oauth/access_token").slice(-1);
  expect(verifierMatches(request, sent(http)[tab - 1].get("code_challenge"))).toBe(false);
});

Then("my session cookie expires in {int} days", async ({ context }, days: number) => {
  const cookie = (await context.cookies()).find(({ name }) => name === sessionCookie);
  expect(Math.abs((cookie?.expires ?? 0) - (Date.now() / 1000 + days * day))).toBeLessThan(60);
});

Then("I hold no live session cookie", async ({ context }) => {
  const cookie = (await context.cookies()).find(({ name }) => name === sessionCookie);
  expect(cookie === undefined || (cookie.expires > 0 && cookie.expires < Date.now() / 1000)).toBe(true);
});

Then(
  "my device cookie names the only device, reads only under {string} and hides from scripts",
  async ({ app, context }, path: string) => {
    const cookie = (await context.cookies()).find(({ name }) => name === deviceCookie);
    const devices = await app.sql`SELECT id FROM devices`;
    expect(devices.map(({ id }) => id)).toEqual([cookie?.value]);
    expect(cookie?.path).toBe(path);
    expect(cookie?.httpOnly).toBe(true);
  },
);

Then("my device cookie expires in {int} days", async ({ context }, days: number) => {
  const cookie = (await context.cookies()).find(({ name }) => name === deviceCookie);
  expect(Math.abs((cookie?.expires ?? 0) - (Date.now() / 1000 + days * day))).toBeLessThan(60);
});

When("I note my device cookie", async ({ context }) => {
  notes.set(context, (await context.cookies()).find(({ name }) => name === deviceCookie)?.value);
});

Then("my device cookie is the one I noted", async ({ context }) => {
  expect((await context.cookies()).find(({ name }) => name === deviceCookie)?.value).toBe(notes.get(context));
});

Then("my device cookie is not {string}", async ({ context }, value: string) => {
  expect((await context.cookies()).find(({ name }) => name === deviceCookie)?.value).not.toBe(value);
});

Then("there {word} {int} device(s)", async ({ app }, _: string, count: number) => {
  const [{ total }] = await app.sql`SELECT count(*)::int AS total FROM devices`;
  expect(total).toBe(count);
});

Then("the answer sets no device cookie", ({ http }) => {
  expect(http.last?.headers()["set-cookie"] ?? "").not.toContain(deviceCookie);
});

Then("the answer sets no cookie", ({ http }) => {
  expect(http.last?.headers()["set-cookie"]).toBeUndefined();
});

Then("the answer carries a CSRF token of 64 hex digits in the sign-out form", ({ http }) => {
  const form = http.body.slice(http.body.indexOf('action="/admin/sign-out"'));
  expect(csrfIn(form)).toMatch(/^[0-9a-f]{64}$/);
});
