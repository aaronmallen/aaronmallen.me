import { createHash, randomBytes } from "node:crypto";
import { type APIRequestContext, expect } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { answer, fill, keep, recall } from "../support/api.ts";
import type { Http } from "../support/http.ts";
import { authorize, redirectUri, register } from "../support/mcp.ts";
import { ownerEmail } from "../support/stub.ts";
import { Given, Then, When } from "../support/world.ts";
import { ask, sendHeader } from "./http.ts";

type Client = { code: string; id: string; verifier: string };

const clients = new WeakMap<Http, Client>();
export const digestOf = (value: string) => createHash("sha256").update(value).digest("hex");
const digest = digestOf;
const resourceFor = (url: string) => `${url}/mcp`;

const signIn = async ({
  app,
  context,
  owner,
}: {
  app: { sql: import("postgres").Sql };
  context: import("@playwright/test").BrowserContext;
  owner: { cookies: import("@playwright/test").Cookie[]; device: import("postgres").Row };
}) => {
  await app.sql`INSERT INTO owner_identities ${app.sql({ email: ownerEmail })} ON CONFLICT DO NOTHING`;
  await app.sql`INSERT INTO devices ${app.sql(owner.device)} ON CONFLICT DO NOTHING`;
  await context.addCookies(owner.cookies);
};

const unset = (value: string) => (value === "(none)" ? undefined : value);

Given("an MCP client approved for {string}", async ({ app, context, http, owner, request }, scope: string) => {
  await signIn({ app, context, owner });
  const id = await register(request);
  const verifier = randomBytes(32).toString("base64url");
  const code = await authorize(http, id, verifier, scope, { resource: resourceFor(app.url) });
  clients.set(http, { code, id, verifier });
});

Given(
  "an MCP client approved for {string} without a redirect URI",
  async ({ app, context, http, owner, request }, scope: string) => {
    await signIn({ app, context, owner });
    const id = await register(request);
    const verifier = randomBytes(32).toString("base64url");
    const query = new URLSearchParams({
      client_id: id,
      code_challenge: createHash("sha256").update(verifier).digest("base64url"),
      code_challenge_method: "S256",
      resource: resourceFor(app.url),
      response_type: "code",
      scope,
    });
    const agent = await http.agent();
    const form = await (await agent.get(`/oauth/authorize?${query}`)).text();
    const fields = Object.fromEntries(
      [...form.matchAll(/<input[^>]*type="hidden"[^>]*>/g)].map(([input]) => [
        input.match(/name="([^"]+)"/)?.[1] ?? "",
        (input.match(/value="([^"]*)"/)?.[1] ?? "").replaceAll("&amp;", "&"),
      ]),
    );
    const decided = await agent.post("/oauth/authorize", { form: { ...fields, decision: "approve" }, maxRedirects: 0 });
    const code = new URL(decided.headers().location ?? "", "http://x").searchParams.get("code") ?? "";
    clients.set(http, { code, id, verifier });
  },
);

Given("the MCP client asks the owner again and is approved", async ({ app, http }) => {
  const client = clients.get(http) as Client;
  client.code = await authorize(http, client.id, client.verifier, "read suggest", { resource: resourceFor(app.url) });
});

Given(
  "the MCP client uses the verifier and challenge from RFC 7636",
  async ({ app, context, http, owner, request }) => {
    await signIn({ app, context, owner });
    const id = await register(request);
    const verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk";
    const query = new URLSearchParams({
      client_id: id,
      code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      code_challenge_method: "S256",
      redirect_uri: redirectUri,
      resource: resourceFor(app.url),
      response_type: "code",
      scope: "read",
    });
    const agent = await http.agent();
    const form = await (await agent.get(`/oauth/authorize?${query}`)).text();
    const fields = Object.fromEntries(
      [...form.matchAll(/<input[^>]*type="hidden"[^>]*>/g)].map(([input]) => [
        input.match(/name="([^"]+)"/)?.[1] ?? "",
        (input.match(/value="([^"]*)"/)?.[1] ?? "").replaceAll("&amp;", "&"),
      ]),
    );
    const decided = await agent.post("/oauth/authorize", { form: { ...fields, decision: "approve" }, maxRedirects: 0 });
    clients.set(http, {
      code: new URL(decided.headers().location ?? "", "http://x").searchParams.get("code") ?? "",
      id,
      verifier,
    });
  },
);

const exchangeFields = (client: Client, url: string, overrides: Record<string, string | undefined> = {}) => {
  const fields: Record<string, string | undefined> = {
    client_id: client.id,
    code: client.code,
    code_verifier: client.verifier,
    grant_type: "authorization_code",
    redirect_uri: redirectUri,
    resource: resourceFor(url),
    ...overrides,
  };
  return Object.fromEntries(Object.entries(fields).filter(([, value]) => value !== undefined)) as Record<
    string,
    string
  >;
};

const post = async (http: Http, request: APIRequestContext, form: Record<string, string> | string) => {
  http.last = await request.post(
    "/oauth/token",
    typeof form === "string"
      ? { data: form, headers: { "Content-Type": "application/x-www-form-urlencoded" } }
      : { form },
  );
  http.body = await http.last.text();
  return http.last;
};

When("the MCP client exchanges its code", async ({ app, http, request }) => {
  await post(http, request, exchangeFields(clients.get(http) as Client, app.url));
});

When("the MCP client exchanges its code with:", async ({ app, http, request }, table: DataTable) => {
  const overrides = Object.fromEntries(
    Object.entries(table.rowsHash()).map(([key, value]) => [key, unset(fill(http, value))]),
  );
  await post(http, request, exchangeFields(clients.get(http) as Client, app.url, overrides));
});

When("the MCP client exchanges its code sending {word} as a list", async ({ app, http, request }, field: string) => {
  const fields = exchangeFields(clients.get(http) as Client, app.url);
  const params = new URLSearchParams(Object.entries(fields).filter(([key]) => key !== field));
  params.append(`${field}[]`, randomBytes(32).toString("base64url"));
  await post(http, request, params.toString());
});

When("the MCP client exchanges its code twice at once", async ({ app, http, request }) => {
  const fields = exchangeFields(clients.get(http) as Client, app.url);
  const answers = await Promise.all([1, 2].map(() => request.post("/oauth/token", { form: fields })));
  keep(
    http,
    "statuses",
    answers
      .map((response) => response.status())
      .sort()
      .join(" "),
  );
  keep(
    http,
    "errors",
    (await Promise.all(answers.map((response) => response.json())))
      .map((body) => body.error ?? "")
      .sort()
      .join(" "),
  );
});

const refreshFields = (
  client: Client,
  url: string,
  token: string | undefined,
  overrides: Record<string, string | undefined> = {},
) =>
  Object.fromEntries(
    Object.entries({
      client_id: client.id,
      grant_type: "refresh_token",
      refresh_token: token,
      resource: resourceFor(url),
      ...overrides,
    }).filter(([, value]) => value !== undefined),
  ) as Record<string, string>;

When("the MCP client refreshes with the token kept as {string}", async ({ app, http, request }, name: string) => {
  await post(http, request, refreshFields(clients.get(http) as Client, app.url, String(recall(http, name))));
});

When(
  "the MCP client refreshes with the token kept as {string} and:",
  async ({ app, http, request }, name: string, table: DataTable) => {
    const overrides = Object.fromEntries(
      Object.entries(table.rowsHash()).map(([key, value]) => [key, unset(fill(http, value))]),
    );
    await post(
      http,
      request,
      refreshFields(clients.get(http) as Client, app.url, String(recall(http, name)), overrides),
    );
  },
);

When("the MCP client refreshes with the refresh token {string}", async ({ app, http, request }, token: string) => {
  await post(http, request, refreshFields(clients.get(http) as Client, app.url, unset(token)));
});

When(
  "the MCP client refreshes sending the token kept as {string} as a list",
  async ({ app, http, request }, name: string) => {
    const fields = refreshFields(clients.get(http) as Client, app.url, undefined);
    const params = new URLSearchParams(Object.entries(fields));
    params.append("refresh_token[]", String(recall(http, name)));
    await post(http, request, params.toString());
  },
);

When(
  "the MCP client refreshes with the token kept as {string} twice at once",
  async ({ app, http, request }, name: string) => {
    const fields = refreshFields(clients.get(http) as Client, app.url, String(recall(http, name)));
    const answers = await Promise.all([1, 2].map(() => request.post("/oauth/token", { form: fields })));
    keep(
      http,
      "statuses",
      answers
        .map((response) => response.status())
        .sort()
        .join(" "),
    );
  },
);

When("a stranger posts to the token endpoint with:", async ({ http, request }, table: DataTable) => {
  await post(http, request, table.rowsHash());
});

When("a stranger posts nothing to the token endpoint", async ({ http, request }) => {
  await post(http, request, {});
});

Then("the token kept as {string} is {word}", async ({ app, http }, name: string, state: string) => {
  const [token] =
    await app.sql`SELECT revoked_at FROM oauth_tokens WHERE token_digest = ${digest(String(recall(http, name)))}`;
  expect(token, name).toBeDefined();
  expect(token.revoked_at === null).toBe(state === "live");
});

Then("the OAuth error is {string}", ({ http }, error: string) => {
  expect(answer(http).error, http.body).toBe(error);
});

Then(
  "the stored tokens are tied to the client, the resource and the scopes {string}",
  async ({ app, http }, scopes: string) => {
    const client = clients.get(http) as Client;
    const rows = await app.sql`
    SELECT c.client_id, t.resource, array_to_string(t.scopes, ' ') AS scopes
    FROM oauth_tokens t JOIN oauth_clients c ON c.id = t.oauth_client_id
  `;
    expect(rows.length).toBe(2);
    for (const row of rows)
      expect([row.client_id, row.resource, row.scopes]).toEqual([client.id, resourceFor(app.url), scopes]);
  },
);

Then("the access token lasts an hour and the refresh token thirty days", async ({ app }) => {
  const rows = await app.sql`
    SELECT type, extract(epoch FROM expires_at - now())::int AS left FROM oauth_tokens ORDER BY type
  `;
  const left = Object.fromEntries(rows.map(({ type, left }) => [type, left]));
  expect(Math.abs(left.access - 3600)).toBeLessThan(60);
  expect(Math.abs(left.refresh - 30 * 86_400)).toBeLessThan(60);
});

Then("the access token is stored as its digest and never in plain text", async ({ app, http }) => {
  const value = String(answer(http).access_token);
  const rows = await app.sql`SELECT * FROM oauth_tokens`;
  expect(rows.some((row) => row.token_digest === digest(value))).toBe(true);
  expect(rows.flatMap((row) => Object.values(row).map(String))).not.toContain(value);
});

Then("the new refresh token is tied to the new access token", async ({ app, http }) => {
  const found = answer(http);
  const [access] = await app.sql`SELECT id FROM oauth_tokens WHERE token_digest = ${digest(found.access_token)}`;
  const [refresh] =
    await app.sql`SELECT access_token_id FROM oauth_tokens WHERE token_digest = ${digest(found.refresh_token)}`;
  expect(refresh.access_token_id).toBe(access.id);
});

When("the owner revokes the MCP client", async ({ app, http }) => {
  const client = clients.get(http) as Client;
  const [found] = await app.sql`SELECT id FROM oauth_clients WHERE client_id = ${client.id}`;
  await http.send("POST", `/admin/clients/${found.id}/revoke`, { form: { _csrf_token: await http.csrf() } });
});

When(
  "the owner revokes the MCP client while it refreshes with the token kept as {string}",
  async ({ app, http, request }, name: string) => {
    const client = clients.get(http) as Client;
    const [found] = await app.sql`SELECT id FROM oauth_clients WHERE client_id = ${client.id}`;
    const token = await http.csrf();
    await Promise.all([
      request.post("/oauth/token", { form: refreshFields(client, app.url, String(recall(http, name))) }),
      http.send("POST", `/admin/clients/${found.id}/revoke`, { form: { _csrf_token: token } }),
    ]);
  },
);

When("the owner revokes the MCP client while it exchanges its code", async ({ app, http, request }) => {
  const client = clients.get(http) as Client;
  const [found] = await app.sql`SELECT id FROM oauth_clients WHERE client_id = ${client.id}`;
  const token = await http.csrf();
  await Promise.all([
    request.post("/oauth/token", { form: exchangeFields(client, app.url) }),
    http.send("POST", `/admin/clients/${found.id}/revoke`, { form: { _csrf_token: token } }),
  ]);
});

Then("the answers kept are {string}", ({ http }, statuses: string) => {
  expect(recall(http, "statuses")).toBe(statuses);
});

Then("the errors kept hold {string}", ({ http }, error: string) => {
  expect(String(recall(http, "errors"))).toContain(error);
});

Given("another MCP client is registered", async ({ http, request }) => {
  keep(http, "otherclient", await register(request, "Other"));
});

When(
  "the MCP client refreshes with the token kept as {string} and the other client",
  async ({ app, http, request }, name: string) => {
    const client = clients.get(http) as Client;
    await post(
      http,
      request,
      refreshFields(client, app.url, String(recall(http, name)), { client_id: String(recall(http, "otherclient")) }),
    );
  },
);

const clientId = "11111111-0000-4000-8000-000000000001";

const approvalPath = () =>
  `/oauth/authorize?${new URLSearchParams({
    client_id: clientId,
    code_challenge: createHash("sha256").update(randomBytes(32).toString("base64url")).digest("base64url"),
    code_challenge_method: "S256",
    redirect_uri: redirectUri,
    response_type: "code",
    scope: "read",
  })}`;

Given("an MCP client", async ({ app }) => {
  await app.sql`
    INSERT INTO oauth_clients ${app.sql({
      client_id: clientId,
      client_name: "Features",
      grant_types: app.sql.array(["authorization_code", "refresh_token"]),
      redirect_uris: app.sql.array([redirectUri]),
      response_types: app.sql.array(["code"]),
      visitor_hash: digest("registrant"),
    })}
    ON CONFLICT DO NOTHING
  `;
});

When("I visit the MCP approval page", async ({ page }) => {
  await page.goto(approvalPath());
});

When("I request the MCP approval page", async ({ app, context }) => {
  await ask({ app, context }, "GET", approvalPath());
});

const dig = (value: unknown, path: string) =>
  path.split(".").reduce((at: unknown, part) => (at as Record<string, unknown>)?.[part], value);

Then("the MCP answer holds {string} as {string}", ({ answer }, path: string, value: string) => {
  const found = dig(JSON.parse(answer.content ?? "{}"), path);
  expect(typeof found === "string" ? found : JSON.stringify(found)).toBe(value);
});

Then("the MCP answer holds a list at {string}", ({ answer }, path: string) => {
  expect(Array.isArray(dig(JSON.parse(answer.content ?? "{}"), path))).toBe(true);
});

Then("the MCP tool refuses", ({ answer, http }) => {
  expect(answer.error ?? JSON.parse(http.body).result?.isError, http.body).toBe(true);
});

Given("my requests carry an API token", async ({ app }) => {
  const token = randomBytes(32).toString("base64url");
  await app.sql`INSERT INTO api_tokens ${app.sql({ name: "Requests", token_digest: digest(token) })}`;
  sendHeader("Authorization", `Bearer ${token}`);
});

export const today = () => new Intl.DateTimeFormat("en-CA", { timeZone: "America/Chicago" }).format(new Date());

When(
  "I call the MCP tool {string} for today with:",
  async ({ answer, request, tokens }, tool: string, args: string) => {
    const response = await request.post("/mcp", {
      data: {
        id: 1,
        jsonrpc: "2.0",
        method: "tools/call",
        params: { arguments: { from: today(), to: today(), ...JSON.parse(args) }, name: tool },
      },
      headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${tokens.mcp}` },
    });
    const body = await response.text();
    const result = response.ok() ? JSON.parse(body).result : undefined;
    Object.assign(answer, {
      body,
      content: result?.content?.[0]?.text ?? body,
      error: result?.isError ?? false,
      status: response.status(),
    });
  },
);
