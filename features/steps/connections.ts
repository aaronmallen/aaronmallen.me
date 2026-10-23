import { createHash, randomBytes } from "node:crypto";
import { type APIResponse, expect, type Locator, type Page, type Response } from "@playwright/test";
import type postgres from "postgres";
import { connectionsFor, insertConnection } from "../support/connections.ts";
import { settle } from "../support/mail_sync.ts";
import { seal } from "../support/seal.ts";
import { Before, Given, Then, When } from "../support/world.ts";

const authorizePath = /\/(login\/oauth\/authorize|o\/oauth2\/v2\/auth|oauth\/authorization|oauth\/authorize)$/;
const did = "did:plc:ada";
const hour = 60 * 60 * 1000;
const day = 24 * hour;
const json = (body: unknown, status = 200) => ({ body: JSON.stringify(body), status });

let asked: URL | undefined;
let answered: Response | APIResponse | null = null;

Before(() => {
  asked = undefined;
  answered = null;
});

const providerOf = (name: string) => name.toLowerCase();
const list = (text: string) => (text ? text.split(", ") : []);

async function connectionId(sql: postgres.Sql, label: string) {
  const [row] = await sql`SELECT id FROM service_connections WHERE label = ${label}`;
  return row.id as number;
}

async function opened(sql: postgres.Sql, provider: string, label: string) {
  return (await connectionsFor(sql, provider)).find((row) => row.label === label || row.account_id === label);
}

const signInPaths: Record<string, string> = {
  GitHub: "/github/login/oauth/authorize",
  Google: "/google/accounts/o/oauth2/v2/auth",
  LinkedIn: "/linkedin/oauth/authorization",
};
const signInPage = { body: "<h1>Sign in to approve</h1>", status: 200 };

async function authorizeRequest(page: Page) {
  await expect.poll(() => authorizePath.test(new URL(page.url()).pathname)).toBe(true);
  asked = new URL(page.url());
  return asked;
}

async function comeBack(page: Page, answer: Record<string, string>) {
  const sent = await authorizeRequest(page);
  const callback = new URL(sent.searchParams.get("redirect_uri") ?? "");
  for (const [name, value] of Object.entries({ ...answer, state: sent.searchParams.get("state") ?? "" })) {
    callback.searchParams.set(name, value);
  }
  answered = await page.goto(callback.toString());
}

async function follow(page: Page, act: () => Promise<void>) {
  const before = page.url();
  await act();
  await page.waitForURL((url) => url.href !== before);
  await page.waitForLoadState();
  if (authorizePath.test(new URL(page.url()).pathname)) asked = new URL(page.url());
}

async function submit(page: Page, path: string, act: () => Promise<void>) {
  const response = page.waitForResponse(
    (sent) => sent.request().method() === "POST" && new URL(sent.url()).pathname === path,
  );
  await act();
  answered = await response;
  await page.waitForLoadState();
}

async function confirm(page: Page, name: string) {
  await page.getByRole("button", { exact: true, name }).first().click();
  await page.locator("[data-confirm-accept]").click();
}

async function openConnection(page: Page, sql: postgres.Sql, label: string) {
  await page.goto(`/admin/settings/services?selected=${await connectionId(sql, label)}`);
}

// Rows

Given("a Linear connection to {string} with the key {string}", async ({ app }, name: string, key: string) => {
  await insertConnection(app.sql, {
    accountId: `ws-${name.toLowerCase()}`,
    credentials: { api_key: key },
    label: name,
    provider: "linear",
  });
});

Given("a Linear connection to {string} used an hour ago", async ({ app }, name: string) => {
  await insertConnection(app.sql, {
    accountId: `ws-${name.toLowerCase()}`,
    credentials: { api_key: "lin_api_secret" },
    label: name,
    lastUsedAt: new Date(Date.now() - hour),
    provider: "linear",
  });
});

Given("a GitHub connection as {string} with the token {string}", async ({ app }, label: string, token: string) => {
  await insertConnection(app.sql, {
    accountId: label === "@someone" ? "1" : "931094",
    credentials: { access_token: token },
    label,
    provider: "github",
    scopes: ["repo"],
  });
});

Given(
  "a GitHub connection as {string} with the pasted token {string}",
  async ({ app }, label: string, token: string) => {
    await insertConnection(app.sql, {
      accountId: "931094",
      credentials: { access_token: token, auth: "credentials" },
      label,
      provider: "github",
    });
  },
);

Given("a Bluesky connection as {string}", async ({ app }, handle: string) => {
  await insertConnection(app.sql, {
    accountId: did,
    credentials: { app_password: "abcd-efgh", handle },
    label: `@${handle}`,
    provider: "bluesky",
  });
});

Given(
  "a Mastodon connection as {string} on {string} with the scopes {string}",
  async ({ app }, label: string, host: string, scopes: string) => {
    await insertConnection(app.sql, {
      accountId: "109",
      credentials: { access_token: "stale" },
      host,
      label,
      provider: "mastodon",
      scopes: scopes.split(" "),
    });
  },
);

Given("a LinkedIn connection to {string} that lapses in {int} day(s)", async ({ app }, name: string, days: number) => {
  await insertConnection(app.sql, {
    accountId: `member-${name.split(" ")[0].toLowerCase()}`,
    credentials: { access_token: "li-token", expires_at: Math.floor((Date.now() + days * day) / 1000) },
    label: name,
    lapsesAt: new Date(Date.now() + days * day),
    provider: "linkedin",
    scopes: ["openid", "profile", "w_member_social"],
  });
});

Given("a LinkedIn connection to {string} that lapsed a minute ago", async ({ app }, name: string) => {
  await insertConnection(app.sql, {
    accountId: `member-${name.split(" ")[0].toLowerCase()}`,
    credentials: { access_token: "li-token", expires_at: Math.floor(Date.now() / 1000) - 60 },
    label: name,
    lapsesAt: new Date(Date.now() - 60_000),
    provider: "linkedin",
  });
});

Given(
  "the LinkedIn connection to {string} lapses at {string} on the {int}th day from today",
  async ({ app }, name: string, time: string, days: number) => {
    await app.sql`
      UPDATE service_connections
      SET lapses_at = ((now() AT TIME ZONE 'America/Chicago')::date + ${days}::int + ${time}::time)
        AT TIME ZONE 'America/Chicago'
      WHERE label = ${name}
    `;
  },
);

Given("a sent LinkedIn post delivered through {string}", async ({ app }, label: string) => {
  const id = await connectionId(app.sql, label);
  const [post] = await app.sql`
      INSERT INTO social_posts ${app.sql({ posted_at: new Date(), status: "posted", targets: ["linkedin"] })}
      RETURNING id
    `;
  await app.sql`
      INSERT INTO social_post_deliveries ${app.sql({ connection_id: id, network: "linkedin", social_post_id: post.id })}
    `;
});

Given("a scheduled Mastodon post delivered through {string}", async ({ app }, label: string) => {
  const id = await connectionId(app.sql, label);
  const [post] = await app.sql`
      INSERT INTO social_posts ${app.sql({
        posted_at: new Date(Date.now() + hour),
        status: "scheduled",
        targets: ["mastodon"],
      })}
      RETURNING id
    `;
  await app.sql`
      INSERT INTO social_post_deliveries ${app.sql({ connection_id: id, network: "mastodon", social_post_id: post.id })}
    `;
});

Given("a connection to the unknown service {string} as {string}", async ({ app }, provider: string, label: string) => {
  await insertConnection(app.sql, { accountId: "tom", credentials: { token: "x" }, label, provider });
});

Given("the Linear issue sync is failing", async ({ app }) => {
  await app.sql`
    INSERT INTO sync_states ${app.sql({
      failing_since: new Date(),
      failure_count: 1,
      failure_reason: "unreachable",
      kind: "failure",
      sync: "linear_issues",
      synced_at: new Date(),
    })}
  `;
});

Given("the webmention settings turn Bridgy off", async ({ app }) => {
  await app.sql`
    INSERT INTO webmention_settings (id, accept_bridgy) VALUES (1, false)
    ON CONFLICT (id) DO UPDATE SET accept_bridgy = false
  `;
});

Given("the Google account {string} holds an expired token", async ({ app }, account: string) => {
  const [row] = await connectionsFor(app.sql, "google").then((rows) => rows.filter((r) => r.account_id === account));
  const credentials = { ...row.opened, expires_at: Math.floor(Date.now() / 1000) - 60 };
  await app.sql`UPDATE service_connections SET credentials = ${seal(JSON.stringify(credentials))} WHERE id = ${row.id}`;
});

Given("the Google account {string} needs a reconnect", async ({ app }, account: string) => {
  await app.sql`UPDATE service_connections SET revoked_at = now() WHERE provider = 'google' AND account_id = ${account}`;
});

Given(
  "the Mastodon server {string} holds an app with the scopes {string}",
  async ({ app }, host: string, scopes: string) => {
    await app.sql`
    INSERT INTO service_apps ${app.sql({
      credentials: seal(JSON.stringify({ client_id: "old-app", client_secret: "old-secret" })),
      host,
      provider: "mastodon",
      redirect_uri: `${app.url}/admin/auth/mastodon/callback`,
      scopes: scopes.split(" "),
    })}
  `;
  },
);

// Outside replies

Given("GitHub's token exchange grants {string}", ({ stub }, scope: string) => {
  stub.reply(
    "POST",
    "/github/login/oauth/access_token",
    json({ access_token: "gho_data", scope, token_type: "bearer" }),
  );
});

Given("GitHub's token exchange fails", ({ stub }) => {
  stub.reply("POST", "/github/login/oauth/access_token", { body: "", status: 500 });
});

Given("GitHub answers as the user {string}", ({ stub }, login: string) => {
  stub.reply("GET", "/github/api/user", json({ id: 931094, login }));
});

Given("GitHub refuses the token with {string}", ({ stub }, message: string) => {
  stub.reply("GET", "/github/api/user", json({ message }, 401));
});

Given("Linear answers as the workspace {string}", ({ stub }, name: string) => {
  stub.reply("POST", "/linear/graphql", json({ data: { organization: { id: `ws-${name.toLowerCase()}`, name } } }));
});

Given("Linear refuses the key with {string}", ({ stub }, message: string) => {
  stub.reply(
    "POST",
    "/linear/graphql",
    json({ errors: [{ extensions: { code: "AUTHENTICATION_ERROR" }, message }] }, 400),
  );
});

Given("Bluesky signs in {string}", ({ stub }, handle: string) => {
  stub.reply("POST", "/bluesky/pds/xrpc/com.atproto.server.createSession", json({ accessJwt: "jwt", did, handle }));
});

Given("Bluesky refuses the sign-in with {string}", ({ stub }, message: string) => {
  stub.reply(
    "POST",
    "/bluesky/pds/xrpc/com.atproto.server.createSession",
    json({ error: "AuthenticationRequired", message }, 401),
  );
});

Given("Google grants {string} the scopes {string}", ({ stub }, email: string, scopes: string) => {
  stub.reply(
    "POST",
    "/google/oauth/token",
    json({
      access_token: `ya29.${email}`,
      expires_in: 3599,
      refresh_token: `1//${email}`,
      scope: scopes,
      token_type: "Bearer",
    }),
  );
  stub.reply("GET", "/google/openid/userinfo", json({ email }));
});

Given("Google's token exchange refuses the code", ({ stub }) => {
  stub.reply("POST", "/google/oauth/token", json({ error: "invalid_grant" }, 400));
});

Given("Google refreshes the token as {string}", ({ stub }, token: string) => {
  stub.reply("POST", "/google/oauth/token", json({ access_token: token, expires_in: 3599, token_type: "Bearer" }));
});

Given("Google has no Health data for the connection", ({ stub }) => {
  for (const type of ["sleep", "daily-resting-heart-rate", "daily-heart-rate-variability", "exercise"]) {
    stub.reply("GET", `/google/health/users/me/dataTypes/${type}/dataPoints`, json({ dataPoints: [] }));
  }
  for (const type of ["steps", "active-zone-minutes"]) {
    stub.reply(
      "POST",
      `/google/health/users/me/dataTypes/${type}/dataPoints:dailyRollUp`,
      json({ rollupDataPoints: [] }),
    );
  }
});

Given("LinkedIn grants the member {string} named {string}", ({ stub }, sub: string, name: string) => {
  stub.reply(
    "POST",
    "/linkedin/oauth/accessToken",
    json({ access_token: `li-${sub}`, expires_in: 5_184_000, scope: "email,openid,profile,w_member_social" }),
  );
  stub.reply("GET", "/linkedin/api/v2/userinfo", json({ name, sub }));
});

Given("the Mastodon server {string} grants the account {string}", ({ stub }, host: string, username: string) => {
  const scope = "write:statuses write:media read:accounts read:search read:statuses";
  stub.reply("POST", `/mastodon/${host}/api/v1/apps`, json({ client_id: "app-id", client_secret: "app-secret" }));
  stub.reply("GET", `/mastodon/${host}/oauth/authorize`, signInPage);
  stub.reply(
    "POST",
    `/mastodon/${host}/oauth/token`,
    json({ access_token: "masto-token", scope, token_type: "Bearer" }),
  );
  stub.reply(
    "GET",
    `/mastodon/${host}/api/v1/accounts/verify_credentials`,
    json({ acct: username, id: "109", username }),
  );
});

// Sign-in pages

Given("{word} shows its sign-in page", ({ stub }, name: string) => {
  asked = undefined;
  stub.reply("GET", signInPaths[name], signInPage);
});

When("I approve the connection", async ({ page }) => {
  await comeBack(page, { code: "code" });
});

When("I decline the connection", async ({ page }) => {
  await comeBack(page, { error: "access_denied" });
});

// Actions

When("I connect {word}", async ({ page }, name: string) => {
  await page.goto("/admin/settings/services");
  await page.getByRole("button", { name: "Connect a service" }).click();
  await page
    .locator("#connect-service")
    .getByRole("button", { name: new RegExp(`^${name}`) })
    .click();
  const dialog = page.getByRole("dialog", { name: `Connect ${name}` });
  await follow(page, () => dialog.getByRole("button", { name: `Continue to ${name}` }).click());
});

async function connectGoogle(page: Page, pick: (dialog: Locator) => Promise<void>) {
  await page.goto("/admin/settings/services");
  await page.getByRole("button", { name: "Connect a service" }).click();
  await page
    .locator("#connect-service")
    .getByRole("button", { name: /^Google/ })
    .click();
  const dialog = page.getByRole("dialog", { name: "Connect Google" });
  await pick(dialog);
  await follow(page, () => dialog.getByRole("button", { name: "Continue to Google" }).click());
}

When("I connect Google without {string}", async ({ page }, scopes: string) => {
  await connectGoogle(page, async (dialog) => {
    for (const scope of list(scopes)) await dialog.getByRole("checkbox", { name: new RegExp(`^${scope}`) }).uncheck();
  });
});

When("I connect Google asking only for {string}", async ({ page }, scope: string) => {
  await connectGoogle(page, async (dialog) => {
    for (const box of await dialog.locator("input[type='checkbox']:enabled").all()) await box.uncheck();
    await dialog.getByRole("checkbox", { name: new RegExp(`^${scope}`) }).check();
  });
});

When("I connect Google with the extra scope {string}", async ({ page }, scope: string) => {
  await connectGoogle(page, (dialog) =>
    dialog.locator("form").evaluate((form, value) => {
      const input = document.createElement("input");
      Object.assign(input, { name: "scopes[]", type: "hidden", value });
      form.append(input);
    }, scope),
  );
});

When("I change Google access for {string} to add {string}", async ({ app, page }, account: string, scope: string) => {
  await openConnection(page, app.sql, account);
  await page.getByRole("button", { name: "Change access" }).click();
  const dialog = page.getByRole("dialog", { name: `Change access for ${account}` });
  await dialog.getByRole("checkbox", { name: new RegExp(`^${scope}`) }).check();
  await follow(page, () => dialog.getByRole("button", { name: "Continue to Google" }).click());
});

When("I reconnect the {word} connection {string}", async ({ app, page }, _name: string, label: string) => {
  await openConnection(page, app.sql, label);
  await follow(page, () => page.getByRole("button", { name: "Reconnect" }).click());
});

When("I come back from {word} with a state it never sent", async ({ page }, name: string) => {
  answered = await page.goto(`/admin/auth/${providerOf(name)}/callback?code=code&state=forged`);
});

When("I come back from {word} again with the same state", async ({ page }, name: string) => {
  const state = (asked ?? (await authorizeRequest(page))).searchParams.get("state");
  answered = await page.goto(`/admin/auth/${providerOf(name)}/callback?code=code&state=${state}`);
});

When("I sign out of the admin", async ({ page }) => {
  await page.goto("/admin");
  await follow(page, () =>
    page.locator("form[action='/admin/sign-out']").evaluate((form: HTMLFormElement) => form.requestSubmit()),
  );
});

When("I paste the GitHub token {string}", async ({ page }, token: string) => {
  await page.goto("/admin/settings/services?connect=github");
  const form = page.locator("#services .settings-side form");
  await form.getByLabel("Personal access token").fill(token);
  await submit(page, "/admin/services/github", () => form.getByRole("button", { name: "Connect GitHub" }).click());
});

When("I connect Linear with the key {string}", async ({ page }, key: string) => {
  await page.goto("/admin/settings/services?connect=linear");
  const form = page.locator("#services .settings-side form");
  await form.getByLabel("API key").fill(key);
  await submit(page, "/admin/services/linear", () => form.getByRole("button", { name: "Connect Linear" }).click());
});

When(
  "I connect Bluesky as {string} with the app password {string}",
  async ({ page }, handle: string, password: string) => {
    await page.goto("/admin/settings/services?connect=bluesky");
    const form = page.locator("#services .settings-side form");
    await form.getByLabel("Handle").fill(handle);
    await form.getByLabel("App password").fill(password);
    await submit(page, "/admin/services/bluesky", () => form.getByRole("button", { name: "Connect Bluesky" }).click());
  },
);

When("I open the connection {string}", async ({ app, page }, label: string) => {
  await openConnection(page, app.sql, label);
});

When("I test the connection {string}", async ({ app, page }, label: string) => {
  await openConnection(page, app.sql, label);
  await follow(page, () => page.getByRole("button", { name: "Test connection" }).click());
});

When("I disconnect the connection {string}", async ({ app, page }, label: string) => {
  await openConnection(page, app.sql, label);
  await follow(page, () => confirm(page, "Disconnect"));
});

When("I disconnect the connection {string} after it is gone", async ({ app, page }, label: string) => {
  await openConnection(page, app.sql, label);
  await app.sql`DELETE FROM service_connections WHERE label = ${label}`;
  const id = new URL(page.url()).searchParams.get("selected");
  await submit(page, `/admin/services/${id}/disconnect`, () => confirm(page, "Disconnect"));
});

When("I flip the work account switch on {string}", async ({ app, page }, label: string) => {
  await openConnection(page, app.sql, label);
  const id = await connectionId(app.sql, label);
  await submit(page, `/admin/services/${id}/work`, () => page.getByRole("switch", { name: "Work account" }).click());
});

// Checks

Then("the connection toast says {string}", async ({ page }, text: string) => {
  await expect(page.locator("[data-toast] .toast")).toContainText(text);
});

Then("the connection answer has status {int}", ({}, status: number) => {
  expect(answered?.status()).toBe(status);
});

Then("the site holds the {word} connections {string}", async ({ app }, name: string, labels: string) => {
  await expect
    .poll(async () => (await connectionsFor(app.sql, providerOf(name))).map((row) => row.label))
    .toEqual(list(labels));
});

Then("the site holds no {word} connection", async ({ app }, name: string) => {
  await expect.poll(async () => (await connectionsFor(app.sql, providerOf(name))).length).toBe(0);
});

Then(
  "the {word} connection {string} holds the credentials {string}",
  async ({ app }, name: string, label: string, credentials: string) => {
    await expect
      .poll(async () => (await opened(app.sql, providerOf(name), label))?.opened)
      .toMatchObject(JSON.parse(credentials));
  },
);

Then(
  "the {word} connection {string} has the account {string} and the scopes {string}",
  async ({ app }, name: string, label: string, account: string, scopes: string) => {
    const row = await opened(app.sql, providerOf(name), label);
    expect([row?.account_id, row?.scopes]).toEqual([account, scopes ? scopes.split(" ") : []]);
  },
);

Then("the {word} connection {string} sits on {string}", async ({ app }, name: string, label: string, host: string) => {
  expect((await opened(app.sql, providerOf(name), label))?.host).toBe(host);
});

Then(
  "the {word} connection {string} lapses in about {int} days",
  async ({ app }, name: string, label: string, days: number) => {
    const row = await opened(app.sql, providerOf(name), label);
    expect(Math.abs(row?.lapses_at.getTime() - (Date.now() + days * day))).toBeLessThan(60_000);
    expect(Math.abs(row?.opened.expires_at * 1000 - (Date.now() + days * day))).toBeLessThan(60_000);
  },
);

Then("the {word} connection {string} is a work account", async ({ app }, name: string, label: string) => {
  await expect.poll(async () => (await opened(app.sql, providerOf(name), label))?.work).toBe(true);
});

Then("the {word} connection {string} is not a work account", async ({ app }, name: string, label: string) => {
  await expect.poll(async () => (await opened(app.sql, providerOf(name), label))?.work).toBe(false);
});

Then("the {word} connection {string} needs no reconnect", async ({ app }, name: string, label: string) => {
  await expect.poll(async () => (await opened(app.sql, providerOf(name), label))?.revoked_at).toBeNull();
});

Then("the {word} connection {string} needs a reconnect", async ({ app }, name: string, label: string) => {
  await expect.poll(async () => (await opened(app.sql, providerOf(name), label))?.revoked_at).not.toBeNull();
});

Then("the stored {word} credentials do not hold {string}", async ({ app }, name: string, text: string) => {
  const rows = await app.sql`SELECT credentials FROM service_connections WHERE provider = ${providerOf(name)}`;
  expect(rows.length).toBeGreaterThan(0);
  for (const row of rows) expect(row.credentials).not.toContain(text);
});

Then(
  "the site holds one Mastodon app on {string} with the scopes {string}",
  async ({ app }, host: string, scopes: string) => {
    const rows = await app.sql`SELECT scopes FROM service_apps WHERE provider = 'mastodon' AND host = ${host}`;
    expect(rows.map((row) => row.scopes)).toEqual([scopes.split(" ")]);
  },
);

Then(
  "the social post deliveries point at the {word} connection {string}",
  async ({ app }, _name: string, label: string) => {
    const id = await connectionId(app.sql, label);
    const rows = await app.sql`SELECT connection_id FROM social_post_deliveries`;
    expect(rows.map((row) => row.connection_id)).toEqual([id]);
  },
);

Then("the {word} delivery is kept with no connection", async ({ app }, name: string) => {
  const rows = await app.sql`SELECT network, connection_id FROM social_post_deliveries`;
  expect(rows.map((row) => [row.network, row.connection_id])).toEqual([[providerOf(name), null]]);
});

Then("the authorize request went to {string}", async ({ page, stub }, path: string) => {
  await authorizeRequest(page);
  expect(`${asked?.origin}${asked?.pathname}`).toBe(`${stub.url}${path}`);
});

Then("the authorize request asked with {string} as {string}", async ({ page }, name: string, value: string) => {
  await authorizeRequest(page);
  expect(asked?.searchParams.get(name)).toBe(value);
});

Then("the authorize request asked for the scopes {string}", async ({ page }, scopes: string) => {
  await authorizeRequest(page);
  expect(asked?.searchParams.get("scope")?.split(" ").sort()).toEqual(scopes.split(" ").sort());
});

Then("the authorize request scope holds {string}", async ({ page }, scope: string) => {
  await authorizeRequest(page);
  expect(asked?.searchParams.get("scope")?.split(" ")).toContain(scope);
});

Then("the authorize request scope leaves out {string}", async ({ page }, text: string) => {
  await authorizeRequest(page);
  expect(asked?.searchParams.get("scope")).not.toContain(text);
});

Then("the authorize request sent a PKCE challenge and comes back to {string}", async ({ page }, path: string) => {
  await authorizeRequest(page);
  expect(asked?.searchParams.get("code_challenge_method")).toBe("S256");
  expect(asked?.searchParams.get("code_challenge")).toMatch(/^[\w-]{43}$/);
  expect(asked?.searchParams.get("redirect_uri")).toMatch(new RegExp(`${path}$`));
});

Then("GitHub's token exchange received the PKCE verifier and the callback", ({ stub }) => {
  const [body] = stub.received("POST", "/github/login/oauth/access_token");
  expect(body).toMatch(/code_verifier=[\w-]{64}/);
  expect(body).toMatch(/redirect_uri=[^&]*%2Fadmin%2Fauth%2Fgithub%2Fcallback(&|$)/);
});

Then("the services address is {string}", async ({ page }, path: string) => {
  await expect
    .poll(() => {
      const url = new URL(page.url());
      return `${url.pathname}${url.search}${url.hash}`;
    })
    .toBe(path);
});

Then("the services address opens the connection {string}", async ({ app, page }, label: string) => {
  const id = await connectionId(app.sql, label);
  await expect
    .poll(() => {
      const url = new URL(page.url());
      return `${url.pathname}${url.search}${url.hash}`;
    })
    .toBe(`/admin/settings/services?selected=${id}#services`);
});

Then("the services page lets forms post to {string}", async ({ page }, sources: string) => {
  const posted = answered && "request" in answered && answered.request().method() === "POST" ? answered : null;
  const here = page.url().split("#")[0];
  const response = posted && posted.url() === here ? posted : await page.request.get(here);
  expect(response.headers()["content-security-policy"]).toMatch(new RegExp(`form-action ${sources}(;|$)`));
});

Then("the services tab shows the sections {string}", async ({ page }, ids: string) => {
  expect(await page.locator(".settings-section").evaluateAll((all) => all.map((section) => section.id))).toEqual(
    ids.split(" "),
  );
});

Then("the connected services tab counts the services it lists", async ({ page }) => {
  await page.goto("/admin/settings/services");
  const shown = await page.locator(".svc-list .li").count();
  await expect(page.locator("a.screen-tab[aria-current='page']")).toContainText(`connected services ${shown}`);
  await page.goto("/admin/settings/security");
  await expect(page.locator("a.screen-tab", { hasText: "connected services" })).toContainText(
    `connected services ${shown}`,
  );
});

Then("the command palette opens the services tab", async ({ page }) => {
  await expect(page.locator("[data-palette-href='/admin/settings/services']")).not.toHaveCount(0);
});

Then("the services tab is titled {string} under {string}", async ({ page }, title: string, heading: string) => {
  await expect(page.locator(".page-head h1")).toHaveText(heading);
  await expect(page).toHaveTitle(new RegExp(`^${title} \\| Admin \\| `));
});

Then("the services group {string} lists {string}", async ({ page }, group: string, names: string) => {
  const titles = page.locator(".svc-group", { hasText: group }).locator(".li-title");
  await expect(titles).toHaveText(list(names));
});

Then("no services group is called {string}", async ({ page }, label: string) => {
  await expect(page.locator(".svc-group-label", { hasText: label })).toHaveCount(0);
});

Then("the service picker lists {string}", async ({ page }, names: string) => {
  const shown = await page.locator("#connect-service .svc-pick .svc-line-name").allTextContents();
  expect(shown.map((name) => name.trim())).toEqual(list(names));
});

Then("the service picker offers {string}", async ({ page }, name: string) => {
  expect(await page.locator("#connect-service .svc-pick .svc-line-name").allTextContents()).toContain(name);
});

Then("the service picker leaves out {string}", async ({ page }, name: string) => {
  expect(await page.locator("#connect-service .svc-pick .svc-line-name").allTextContents()).not.toContain(name);
});

Then("the service picker hints {string}", async ({ page }, text: string) => {
  await expect(page.locator("#connect-service .hint")).toContainText(text);
});

Then("the {string} pick in the service picker opens {string}", async ({ page }, name: string, href: string) => {
  await expect(page.locator("#connect-service a.svc-pick", { hasText: name })).toHaveAttribute("href", href);
});

Then("the Linear pick in the service picker shows the Linear mark", async ({ page }) => {
  const tile = page.locator("#connect-service a.svc-pick", { hasText: "Linear" }).locator(".svc-tile");
  await expect(tile.locator("i.linear-mark[aria-hidden='true']")).toHaveCount(1);
  await expect(tile.locator("i.fa-circle-nodes")).toHaveCount(0);
});

Then("the service row {string} shows {string}", async ({ page }, name: string, pill: string) => {
  await expect(page.locator(".svc-list .li", { hasText: name }).locator(".pill")).toHaveText(pill);
});

Then("the service row {string} reads {string}", async ({ page }, name: string, text: string) => {
  const sub = page.locator(".svc-list .li", { hasText: name }).locator(".li-sub");
  await expect(sub).toHaveText(new RegExp(`^${text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`));
});

Then("the service rows show the accounts {string}", async ({ page }, accounts: string) => {
  const shown = await page.locator(".svc-list .svc-account").allTextContents();
  expect(shown).toEqual(expect.arrayContaining(list(accounts)));
});

Then("the service line {string} shows {string}", async ({ page }, line: string, pill: string) => {
  await expect(page.locator(".svc-line", { hasText: line }).locator(".pill")).toHaveText(pill);
});

Then("the service line {string} reads {string}", async ({ page }, line: string, text: string) => {
  await expect(page.locator(".svc-line", { hasText: line })).toContainText(text);
});

Then("the service panel shows {string}", async ({ page }, text: string) => {
  await expect(page.locator("#services .settings-side")).toContainText(text);
});

Then("the service panel names the account {string}", async ({ page }, account: string) => {
  await expect(page.locator("#services .settings-side .svc-account")).toHaveText(account);
});

Then("the service panel shows the error {string}", async ({ page }, text: string) => {
  await expect(page.locator("#services .settings-side .field-error")).toContainText(text);
});

Then("the service panel shows a sync failure named for its job", async ({ page }) => {
  const job = (await page.locator(".svc-job").first().textContent()) ?? "";
  await expect(page.locator("#services .settings-side .sync-failure")).toHaveText(new RegExp(`^${job}`));
});

Then("the service panel lists the environment keys {string}", async ({ page }, keys: string) => {
  await expect(page.locator(".svc-env")).toHaveText(keys.split(" "));
});

Then("the service panel offers {string}", async ({ page }, name: string) => {
  await expect(page.locator("#services .settings-side").getByRole("button", { exact: true, name })).toBeVisible();
});

Then("the service panel offers no {string}", async ({ page }, name: string) => {
  await expect(page.locator("#services .settings-side").getByRole("button", { exact: true, name })).toHaveCount(0);
});

Then("the service panel links {string} to {string}", async ({ page }, name: string, href: string) => {
  await expect(page.locator("#services .settings-side").getByRole("link", { name })).toHaveAttribute("href", href);
});

Then("the service panel opens {string} in a new tab with no opener", async ({ page }, href: string) => {
  const link = page.locator(`#services .settings-side a[href='${href}']`);
  await expect(link).toHaveAttribute("target", "_blank");
  await expect(link).toHaveAttribute("rel", "noopener noreferrer");
});

Then("the service panel lists {string} under its powers", async ({ page }, power: string) => {
  await expect(page.locator("#services .settings-side .svc-powers li", { hasText: power })).toHaveCount(1);
});

Then("the service row {string} is open", async ({ page }, name: string) => {
  const title = page.locator(".svc-list .li", { hasText: name }).locator("a.li-title");
  await expect(title).toHaveAttribute("aria-current", "true");
  await expect(title).toHaveAttribute("href", "/admin/settings/services#services");
});

Then("the services count shows {string}", async ({ page }, text: string) => {
  await expect(page.locator(".svc-list .settings-count")).toContainText(text);
});

Then("the services glance names a sync failure", async ({ page }) => {
  await expect(page.locator("#services .settings-side .sync-failure")).not.toHaveCount(0);
});

Then("the {word} connect dialog hints {string}", async ({ page }, name: string, text: string) => {
  await expect(page.locator(`#connect-service-${providerOf(name)} .hint`, { hasText: text })).toHaveCount(1);
});

Then("the {word} connect dialog asks for no server", async ({ page }, name: string) => {
  await expect(page.locator(`#connect-service-${providerOf(name)} input[name='server']`)).toHaveCount(0);
});

Then("the Mastodon connect dialog asks for the server beside a cancel", async ({ page }) => {
  const dialog = page.locator("#connect-service-mastodon");
  await expect(dialog.locator("form#connect-service-mastodon-form input[name='server']")).toHaveCount(1);
  await expect(dialog.locator(".dialog-foot [type='submit'][form='connect-service-mastodon-form']")).toHaveCount(1);
  await expect(dialog.locator(".dialog-foot button[type='button'][data-dialog-close]")).toHaveText("Cancel");
});

Then("the GitHub connect dialog offers a token field", async ({ page }) => {
  const dialog = page.locator("#connect-service-github");
  await expect(dialog.locator("form[action='/admin/services/github/connect']")).toHaveCount(1);
  await expect(
    dialog.locator(
      "form[action='/admin/services/github#services'] input[type='password'][name='connection[access_token]']",
    ),
  ).toHaveCount(1);
});

Then("the Google scope {string} is ticked and locked on", async ({ page }, scope: string) => {
  const box = page.locator("#connect-service-google .svc-scope", { hasText: scope }).locator("input");
  await expect(box).toBeChecked();
  await expect(box).toBeDisabled();
});

Then("the Google scope {string} is ticked and free", async ({ page }, scope: string) => {
  const box = page.locator("#connect-service-google .svc-scope", { hasText: scope }).locator("input");
  await expect(box).toBeChecked();
  await expect(box).toBeEnabled();
});

Then(
  "the change access dialog for {string} ticks {string} and not {string}",
  async ({ app, page }, label: string, ticked: string, unticked: string) => {
    const dialog = page.locator(`#connect-service-google-${await connectionId(app.sql, label)}`);
    await expect(dialog.locator(`input[name='connection'][value='${await connectionId(app.sql, label)}']`)).toHaveCount(
      1,
    );
    await expect(dialog.locator(".svc-scope", { hasText: ticked }).locator("input")).toBeChecked();
    await expect(dialog.locator(".svc-scope", { hasText: unticked }).locator("input")).not.toBeChecked();
  },
);

Then("the service panel holds a reconnect for {string}", async ({ app, page }, label: string) => {
  const id = await connectionId(app.sql, label);
  await expect(
    page.locator(`.svc-actions form[action='/admin/services/google/connect'] input[value='${id}']`),
  ).toHaveCount(1);
});

Then("the work account switch is {word}", async ({ page }, state: string) => {
  const box = page.getByRole("switch", { name: "Work account" });
  await (state === "on" ? expect(box).toBeChecked() : expect(box).not.toBeChecked());
});

Then("the LinkedIn post target is {word} on the post form", async ({ page }, state: string) => {
  await page.goto("/admin/posts/new");
  const box = page.locator(".compose-target.linkedin input");
  await (state === "on" ? expect(box).toBeEnabled() : expect(box).toBeDisabled());
});

Then("the composer lists the LinkedIn accounts {string} beside Mastodon", async ({ page }, names: string) => {
  await page.goto("/admin/social");
  const handles = await page.locator(".compose-account-group.linkedin .compose-account-handle").allTextContents();
  expect(handles.sort()).toEqual(list(names).sort());
  await expect(page.locator(".compose-account-group.mastodon")).not.toHaveCount(0);
});

Then("the today page shows a lapsing connection", async ({ page }) => {
  await page.goto("/admin");
  await expect(page.getByText(/^Connection lapse/)).not.toHaveCount(0);
});

Then("the today page shows no lapsing connection", async ({ page }) => {
  await page.goto("/admin");
  await expect(page.getByText(/^Connection lapse/)).toHaveCount(0);
});

Then("{service} received {word} {string} once", ({ stub }, prefix: string, method: string, path: string) => {
  expect(stub.received(method, `${prefix}${path}`)).toHaveLength(1);
});

// API tokens and MCP clients

const digestOf = (text: string) => createHash("sha256").update(text).digest("hex");

Given(
  "the API token {string} was made on {string} and last used on {string}",
  async ({ app }, name: string, made: string, used: string) => {
    await app.sql`
      INSERT INTO api_tokens ${app.sql({
        created_at: new Date(made),
        last_used_at: used ? new Date(used) : null,
        name,
        token_digest: digestOf(`secret-${name}`),
      })}
    `;
  },
);

Given("the API token {string} was revoked", async ({ app }, name: string) => {
  await app.sql`
    INSERT INTO api_tokens ${app.sql({ name, revoked_at: new Date(), token_digest: digestOf(`secret-${name}`) })}
  `;
});

async function insertClient(
  sql: postgres.Sql,
  name: string | null,
  redirect: string,
  token?: { revoked?: boolean; scopes: string[] },
) {
  const [client] = await sql`
    INSERT INTO oauth_clients ${sql({
      client_id: randomBytes(8).toString("hex"),
      client_name: name,
      grant_types: ["authorization_code"],
      redirect_uris: [redirect],
      response_types: ["code"],
      visitor_hash: randomBytes(32).toString("hex"),
    })}
    RETURNING id
  `;
  if (token) {
    await sql`
      INSERT INTO oauth_tokens (oauth_client_id, type, token_digest, scopes, expires_at, revoked_at)
      VALUES (${client.id}, 'access', ${digestOf(`client-${client.id}`)}, ${`{${token.scopes.join(",")}}`}::oauth_scope[],
        ${new Date(Date.now() + hour)}, ${token.revoked ? new Date() : null})
    `;
  }
}

Given(
  "an MCP client named {string} holding a live token for {string}",
  async ({ app }, name: string, scopes: string) => {
    await insertClient(app.sql, name, "https://client.example/callback", { scopes: scopes.split(" ") });
  },
);

Given("an MCP client with no name that comes back to {string}", async ({ app }, redirect: string) => {
  await insertClient(app.sql, null, redirect, { scopes: ["read"] });
});

Given("an MCP client named {string} whose token was revoked", async ({ app }, name: string) => {
  await insertClient(app.sql, name, "https://client.example/callback", { revoked: true, scopes: ["read"] });
});

Given("an MCP client named {string} holding no token", async ({ app }, name: string) => {
  await insertClient(app.sql, name, "https://client.example/callback");
});

Then("the MCP answer lists {string} before {string}", ({ answer }, first: string, second: string) => {
  expect(answer.body.indexOf(first)).toBeGreaterThan(-1);
  expect(answer.body.indexOf(first)).toBeLessThan(answer.body.indexOf(second));
});

Then("the MCP answer holds no token or digest", async ({ answer, app, tokens }) => {
  const digests = await app.sql`
    SELECT token_digest FROM api_tokens UNION ALL SELECT token_digest FROM oauth_tokens
  `;
  for (const { token_digest } of digests) expect(answer.body).not.toContain(token_digest);
  expect(answer.body).not.toContain(tokens.mcp);
});

When("the site drops every {word} connection", async ({ app }, name: string) => {
  await app.sql`DELETE FROM service_connections WHERE provider = ${providerOf(name)}`;
});

When("the GitHub commit import runs on the new connection", async ({ app }) => {
  await app.pushJob("Record::Jobs::ImportCommits");
});

When("I start a GitHub connect from a stale tab", async ({ page }) => {
  await page.goto("/admin/settings/services");
  await follow(page, () =>
    page.evaluate(() => {
      const form = document.createElement("form");
      form.method = "post";
      form.action = "/admin/services/github/connect";
      const token = document.querySelector<HTMLInputElement>("input[name='_csrf_token']");
      if (token) form.append(token.cloneNode());
      document.body.append(form);
      form.submit();
    }),
  );
});

Then("the {word} connection {string} is still row {int}", async ({ app }, name: string, label: string, id: number) => {
  expect((await opened(app.sql, providerOf(name), label))?.id).toBe(id);
});

Given("the Mastodon connection {string} moves to {string}", async ({ app }, label: string, host: string) => {
  await app.sql`UPDATE service_connections SET host = ${host} WHERE label = ${label}`;
});

Then("the Mastodon connections sit on {string}", async ({ app }, hosts: string) => {
  await expect
    .poll(async () => (await connectionsFor(app.sql, "mastodon")).map((row) => row.host).sort())
    .toEqual(list(hosts).sort());
});

When("the Google calendar sync runs", async ({ app, stub }) => {
  stub.reply("GET", "/google/calendar/users/me/calendarList", json({ items: [] }));
  await app.pushJob("Calendar::Jobs::SyncCalendar");
});

When("the Google calendar sync runs again", async ({ app }) => {
  await app.pushJob("Calendar::Jobs::SyncCalendar");
  await settle(app);
});

Then("the authorize request comes back to {string}", async ({ page }, path: string) => {
  expect((await authorizeRequest(page)).searchParams.get("redirect_uri")).toMatch(new RegExp(`${path}$`));
});

type ListedClient = { current: boolean; last_used_at: string | null; name: { text: string }; scopes: string[] };

const listedClient = (body: string, name: string) => {
  const { clients } = JSON.parse(JSON.parse(body).result.content[0].text) as { clients: ListedClient[] };
  return clients.find((client) => client.name.text === name);
};

Then("the MCP client list shows {string} with the scopes {string}", ({ answer }, name: string, scopes: string) => {
  expect(listedClient(answer.body, name)).toMatchObject({ current: false, scopes: scopes.split(" ") });
});

Then("the MCP client list marks {string} as the caller with its last use", ({ answer }, name: string) => {
  const client = listedClient(answer.body, name);
  expect(client?.current).toBe(true);
  expect(client?.last_used_at).toMatch(/^\d{4}-\d\d-\d\dT/);
});

Given("Google's token exchange answers {string}", ({ stub }, body: string) => {
  stub.reply("POST", "/google/oauth/token", { body, status: 200 });
});

Given("LinkedIn's token exchange fails", ({ stub }) => {
  stub.reply("POST", "/linkedin/oauth/accessToken", json({ error: "invalid_request" }, 400));
});

Then("the Bluesky form asks for a handle and an app password", async ({ page }) => {
  const form = page.locator("#services .settings-side form[action='/admin/services/bluesky#services']");
  await expect(form.locator("input[name='connection[handle]']")).toHaveAttribute("type", "text");
  await expect(form.locator("input[name='connection[app_password]']")).toHaveAttribute("type", "password");
});

Then("the service panel offers no orange pill on {string}", async ({ page }, line: string) => {
  await expect(page.locator(".svc-line", { hasText: line }).locator(".pill.orange")).toHaveCount(0);
});

Then(
  "the {word} connection {string} has the scopes {string}",
  async ({ app }, name: string, label: string, scopes: string) => {
    await expect.poll(async () => (await opened(app.sql, providerOf(name), label))?.scopes).toEqual(scopes.split(" "));
  },
);

Given("my admin sign-in is over a minute old", async ({ app }) => {
  await app.sql`UPDATE devices SET last_signed_in_at = now() - interval '1 hour'`;
});

When("the queued connection jobs finish", async ({ app }) => {
  await settle(app);
});
