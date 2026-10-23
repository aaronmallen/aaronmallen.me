import { createHash, randomBytes } from "node:crypto";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { expect } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { dig, fill, keep, recall } from "../support/api.ts";
import type { Http } from "../support/http.ts";
import { authorize, type Connection, redirectUri as claudeRedirect, connect, rpc } from "../support/mcp.ts";
import { root } from "../support/shell.ts";
import { ownerEmail } from "../support/stub.ts";
import { Given, Then, type test, When } from "../support/world.ts";
import { signIn } from "./admin.ts";

type World = Parameters<Parameters<typeof test>[2]>[0];

const toolText = (answer: World["answer"], http: Http) => answer.content ?? toolResult(http).content[0].text;

export const toolResult = (http: Http) =>
  JSON.parse(http.body).result as { content: { text: string }[]; isError?: boolean };

const redirectUri = "http://127.0.0.1/callback";

async function connectInBrowser({ page, request, tokens }: Pick<World, "page" | "request" | "tokens">, scope: string) {
  const registered = await request.post("/oauth/register", {
    data: { client_name: "Features", redirect_uris: [redirectUri] },
  });
  const { client_id } = await registered.json();
  const verifier = randomBytes(32).toString("base64url");
  const authorize = new URLSearchParams({
    client_id,
    code_challenge: createHash("sha256").update(verifier).digest("base64url"),
    code_challenge_method: "S256",
    redirect_uri: redirectUri,
    response_type: "code",
    scope,
    state: randomBytes(8).toString("hex"),
  });

  await page.route(`${redirectUri}?*`, (route) => route.fulfill({ body: "" }));
  await page.goto(`/oauth/authorize?${authorize}`);
  const callback = page.waitForRequest((sent) => sent.url().startsWith(redirectUri));
  await page.getByRole("button", { name: "Approve" }).click();
  const code = new URL((await callback).url()).searchParams.get("code") ?? "";

  const granted = await request.post("/oauth/token", {
    form: { client_id, code, code_verifier: verifier, grant_type: "authorization_code", redirect_uri: redirectUri },
  });
  expect(granted.status()).toBe(200);
  tokens.mcp = (await granted.json()).access_token;
}

async function rpcResult({ request, tokens }: Pick<World, "request" | "tokens">, method: string, params: object) {
  const response = await request.post("/mcp", {
    data: { id: 1, jsonrpc: "2.0", method, params },
    headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${tokens.mcp}` },
  });
  const body = await response.text();
  return { body, result: response.ok() ? JSON.parse(body).result : undefined, status: response.status() };
}

async function call(
  { answer, http, request, tokens }: Pick<World, "answer" | "http" | "request" | "tokens">,
  name: string,
  args: string,
) {
  http.last = await rpc(request, tokens.mcp, "tools/call", { arguments: JSON.parse(fill(http, args)), name });
  http.body = await http.last.text();
  const result = http.last.ok() ? JSON.parse(http.body).result : undefined;
  answer.content = result?.content?.[0]?.text ?? http.body;
  answer.error = result?.isError ?? false;
}

When("an MCP client connects and I approve it", ({ page, request, tokens }) =>
  connectInBrowser({ page, request, tokens }, "read"),
);

When("I call the MCP tool {string}", ({ answer, http, request, tokens }, name: string) =>
  call({ answer, http, request, tokens }, name, "{}"),
);

When("I call the MCP tool {string} with:", ({ answer, http, request, tokens }, name: string, args: string) =>
  call({ answer, http, request, tokens }, name, args),
);

Then(
  "the MCP tool {string} answers with {string}",
  async ({ answer, http, request, tokens }, tool: string, text: string) => {
    await call({ answer, http, request, tokens }, tool, "{}");
    expect(answer.status).toBe(200);
    expect(answer.content).toContain(text);
  },
);

Then("the MCP answer holds {string}", ({ answer }, text: string) => {
  expect(answer.status).toBe(200);
  expect(answer.body).toContain(text);
});

Then("the MCP answer does not hold {string}", ({ answer }, text: string) => {
  expect(answer.body).not.toContain(text);
});

Then("the MCP answer holds:", ({ answer, http }, expected: string) => {
  expect(answer.error ?? toolResult(http).isError ?? false, http.body).toBe(false);
  expect(JSON.parse(toolText(answer, http))).toMatchObject(JSON.parse(fill(http, expected)));
});

Then("the MCP tool refuses with {string}", ({ answer, http }, message: string) => {
  expect(toolText(answer, http)).toBe(fill(http, message));
});

async function toolNames({ request, tokens }: Pick<World, "request" | "tokens">) {
  const { result } = await rpcResult({ request, tokens }, "tools/list", {});
  return result.tools.map((tool: { name: string }) => tool.name);
}

Then("the MCP tools hold {string}", async ({ request, tokens }, name: string) => {
  expect(await toolNames({ request, tokens })).toContain(name);
});

Then("the MCP tools leave out {string}", async ({ request, tokens }, name: string) => {
  expect(await toolNames({ request, tokens })).not.toContain(name);
});

Then("the MCP answer has no {string}", ({ answer, http }, path: string) => {
  expect(dig(JSON.parse(toolText(answer, http)), path)).toBeUndefined();
});

const connections = new WeakMap<Http, Connection>();

Given(
  "an MCP client connected with the scopes {string}",
  async ({ app, context, http, owner, request, tokens }, scope: string) => {
    await signIn({ app, context, owner });
    const connection = await connect(request, http, scope);
    connections.set(http, connection);
    tokens.mcp = connection.access;
    keep(http, "access", connection.access);
    keep(http, "refresh", connection.refresh);
    keep(http, "clientid", connection.clientId);
  },
);

When("the MCP client connects a second pair", async ({ app, http, request }) => {
  const connection = connections.get(http) as Connection;
  const verifier = randomBytes(32).toString("base64url");
  const code = await authorize(http, connection.clientId, verifier, "read", { resource: `${app.url}/mcp` });
  const granted = await request.post("/oauth/token", {
    form: {
      client_id: connection.clientId,
      code,
      code_verifier: verifier,
      grant_type: "authorization_code",
      redirect_uri: claudeRedirect,
    },
  });
  keep(http, "secondaccess", (await granted.json()).access_token);
});

When("the MCP client spends its refresh token", async ({ app, http, request }) => {
  const connection = connections.get(http) as Connection;
  const rotated = await request.post("/oauth/token", {
    form: {
      client_id: connection.clientId,
      grant_type: "refresh_token",
      refresh_token: connection.refresh,
      resource: `${app.url}/mcp`,
    },
  });
  keep(http, "newaccess", (await rotated.json()).access_token);
});

When(
  "I ask MCP for {string} with the authorization {string}",
  async ({ http, request }, method: string, authorization: string) => {
    http.last = await request.post("/mcp", {
      data: { id: 1, jsonrpc: "2.0", method },
      headers: { Accept: "application/json, text/event-stream", Authorization: fill(http, authorization) },
    });
    http.body = await http.last.text();
  },
);

When("I ask MCP for {string} with no token", async ({ http, request }, method: string) => {
  http.last = await rpc(request, undefined, method);
  http.body = await http.last.text();
});

When(
  "I ask MCP for {string} with no token and the forwarded host {string}",
  async ({ http, request }, method: string, host: string) => {
    http.last = await rpc(request, undefined, method, undefined, { "X-Forwarded-Host": host });
    http.body = await http.last.text();
  },
);

When("I post the body {string} to MCP", async ({ http, request, tokens }, body: string) => {
  http.last = await request.post("/mcp", {
    data: body.replaceAll("\\r", "\r").replaceAll("\\n", "\n").replaceAll("\\t", "\t"),
    headers: {
      Accept: "application/json, text/event-stream",
      Authorization: `Bearer ${tokens.mcp}`,
      "Content-Type": "application/json",
    },
  });
  http.body = await http.last.text();
});

When("I post the bare body {string} to MCP", async ({ http, request, tokens }, body: string) => {
  http.last = await request.post("/mcp", { data: body, headers: { Authorization: `Bearer ${tokens.mcp}` } });
  http.body = await http.last.text();
});

When("I post to MCP:", async ({ http, request, tokens }, body: string) => {
  http.last = await request.post("/mcp", {
    data: fill(http, body),
    headers: {
      Accept: "application/json, text/event-stream",
      Authorization: `Bearer ${tokens.mcp}`,
      "Content-Type": "application/json",
    },
  });
  http.body = await http.last.text();
});

When("I send MCP a notification {string}", async ({ http, request, tokens }, method: string) => {
  http.last = await request.post("/mcp", {
    data: { jsonrpc: "2.0", method },
    headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${tokens.mcp}` },
  });
  http.body = await http.last.text();
});

Then("the MCP tools offered are:", ({ http }, table: DataTable) => {
  const offered = (JSON.parse(http.body).result.tools as { name: string }[]).map(({ name }) => name).sort();
  expect(offered).toEqual(
    table
      .raw()
      .map(([name]) => name)
      .sort(),
  );
});

Then("the MCP instructions hold {string}", ({ http }, text: string) => {
  expect(JSON.parse(http.body).result.instructions).toContain(text);
});

Then("the MCP instructions name each of these kinds:", ({ http }, table: DataTable) => {
  const instructions = JSON.parse(http.body).result.instructions as string;
  expect(
    table
      .raw()
      .map(([, kind]) => kind)
      .filter((kind) => !instructions.includes(kind)),
  ).toEqual([]);
});

Then("the MCP server reports the version git describes", async ({ http }) => {
  const { run } = await import("../support/shell.ts");
  const described = await run("git describe --tags");
  expect(JSON.parse(http.body).result.serverInfo.version).toBe(
    described.status === 0 ? described.output.trim() : "unknown",
  );
});

Then("the MCP error code is {int}", ({ http }, code: number) => {
  expect(JSON.parse(http.body).error?.code, http.body).toBe(code);
});

When("I ask MCP for {string}", async ({ http, request, tokens }, method: string) => {
  http.last = await rpc(request, tokens.mcp, method);
  http.body = await http.last.text();
});

When("I ask MCP for {string} with:", async ({ http, request, tokens }, method: string, params: string) => {
  http.last = await rpc(request, tokens.mcp, method, JSON.parse(fill(http, params)));
  http.body = await http.last.text();
});

Then("the MCP tool answers without error", ({ http }) => {
  expect(toolResult(http).isError ?? false, http.body).toBe(false);
});

Then("the MCP tool's words hold {string}", ({ http }, text: string) => {
  expect(toolResult(http).content[0].text).toContain(fill(http, text));
});

Then("the MCP tool answer at {string} is {string}", ({ http }, path: string, value: string) => {
  expect(dig(JSON.parse(toolResult(http).content[0].text), path)).toEqual(JSON.parse(fill(http, value)));
});

Then("the MCP tool answer at {string} matches:", ({ http }, path: string, expected: string) => {
  expect(dig(JSON.parse(toolResult(http).content[0].text), path)).toMatchObject(JSON.parse(fill(http, expected)));
});

When("I keep the MCP tool answer's {string} as {string}", ({ http }, path: string, name: string) => {
  keep(http, name, dig(JSON.parse(toolResult(http).content[0].text), path));
});

Then("the MCP reply matches:", ({ http }, expected: string) => {
  expect(JSON.parse(http.body)).toMatchObject(JSON.parse(fill(http, expected)));
});

Then("the MCP reply at {string} is {string}", ({ http }, path: string, value: string) => {
  expect(dig(JSON.parse(http.body), path)).toEqual(JSON.parse(fill(http, value)));
});

const sendRegistration = async (
  http: Http,
  request: import("@playwright/test").APIRequestContext,
  body: string,
  headers = {},
) => {
  http.last = await request.post("/oauth/register", {
    data: body,
    headers: { "Content-Type": "application/json", ...headers },
  });
  http.body = await http.last.text();
};

When("a client registers with:", async ({ http, request }, body: string) => {
  await sendRegistration(http, request, body);
});

When("a client registers with the body {string}", async ({ http, request }, body: string) => {
  await sendRegistration(http, request, body);
});

When("{int} clients register with:", async ({ http, request }, count: number, body: string) => {
  for (let sent = 0; sent < count; sent++) await sendRegistration(http, request, body);
});

When(
  "{int} clients register forging the forwarded addresses 203.0.113.1 onward",
  async ({ http, request }, count: number) => {
    const body = JSON.stringify({ redirect_uris: ["https://claude.ai/api/mcp/auth_callback"] });
    for (let sent = 0; sent < count; sent++) {
      await sendRegistration(http, request, body, { "X-Forwarded-For": `203.0.113.${sent + 1}` });
    }
  },
);

When(
  "a client registers a {word} of {int} {string}s",
  async ({ http, request }, field: string, length: number, letter: string) => {
    const value = field === "client_name" ? letter.repeat(length) : `https://claude.ai/${letter.repeat(length)}`;
    await sendRegistration(http, request, JSON.stringify({ [field]: value, redirect_uris: [redirectUri] }));
  },
);

Then("the stored client keeps a daily visitor hash, not the address", async ({ app }) => {
  const [client] = await app.sql`SELECT visitor_hash FROM oauth_clients`;
  expect(client.visitor_hash).toMatch(/^[0-9a-f]{64}$/);
  expect(client.visitor_hash).not.toBe(createHash("sha256").update("127.0.0.1").digest("hex"));
});

Then("the scopes it names match the protected resource's", async ({ http, request }) => {
  const offered = JSON.parse(http.body).scopes_supported;
  const resource = await (await request.get("/.well-known/oauth-protected-resource/mcp")).json();
  expect(resource.scopes_supported).toEqual(offered);
});

Then("its registration endpoint registers a client", async ({ http, request }) => {
  const endpoint = new URL(JSON.parse(http.body).registration_endpoint).pathname;
  const registered = await request.post(endpoint, {
    data: { redirect_uris: ["https://claude.ai/api/mcp/auth_callback"] },
  });
  expect(registered.status()).toBe(201);
});

const descriptionOf = (http: Http, name: string) =>
  (JSON.parse(http.body).result.tools as { description: string; name: string }[]).find((tool) => tool.name === name)
    ?.description ?? "";

Then("the descriptions of {string} each hold {string}", ({ http }, names: string, text: string) => {
  for (const name of names.split(", ")) expect(descriptionOf(http, name), name).toContain(text);
});

Then("the description of {string} ends with {string}", ({ http }, name: string, text: string) => {
  expect(descriptionOf(http, name).endsWith(text), descriptionOf(http, name)).toBe(true);
});

Given(
  "an MCP client connected with {string} naming no resource",
  async ({ app, context, http, owner, request, tokens }, scope: string) => {
    await app.sql`INSERT INTO owner_identities ${app.sql({ email: ownerEmail })} ON CONFLICT DO NOTHING`;
    await app.sql`INSERT INTO devices ${app.sql(owner.device)} ON CONFLICT DO NOTHING`;
    await context.addCookies(owner.cookies);
    const clientId = (
      await (await request.post("/oauth/register", { data: { redirect_uris: [claudeRedirect] } })).json()
    ).client_id;
    const verifier = randomBytes(32).toString("base64url");
    const code = await authorize(http, clientId, verifier, scope);
    const granted = await request.post("/oauth/token", {
      form: {
        client_id: clientId,
        code,
        code_verifier: verifier,
        grant_type: "authorization_code",
        redirect_uri: claudeRedirect,
      },
    });
    tokens.mcp = (await granted.json()).access_token;
  },
);

Given("the owner revokes every MCP client from the admin", async ({ app, http }) => {
  for (const { id } of await app.sql`SELECT id FROM oauth_clients`) {
    await http.send("POST", `/admin/clients/${id}/revoke`, { form: { _csrf_token: await http.csrf() } });
  }
});

Then("every read tool search names for a kind is a tool it offers", ({ http }) => {
  const tools = JSON.parse(http.body).result.tools as { description: string; name: string }[];
  const search = tools.find(({ name }) => name === "search")?.description ?? "";
  const readers = [...search.matchAll(/\b\w+: (read_\w+)/g)].map(([, tool]) => tool);
  expect(readers.length).toBeGreaterThan(0);
  expect(readers.filter((tool) => !tools.some(({ name }) => name === tool))).toEqual([]);
});

Then("the MCP reply at {string} holds {string}", ({ http }, path: string, text: string) => {
  expect(JSON.stringify(dig(JSON.parse(http.body), path))).toContain(fill(http, text).replaceAll('"', '\\"'));
});

Then("the MCP reply at {string} names {string}", ({ http }, path: string, names: string) => {
  expect((dig(JSON.parse(http.body), path) as { name: string }[]).map(({ name }) => name).join(", ")).toBe(names);
});

const promptText = (http: Http) => JSON.parse(http.body).result.messages[0].content.text as string;

Then("the prompt holds {string}", ({ http }, text: string) => {
  expect(promptText(http)).toContain(text);
});

Then("the prompt names read_activity after summarize_activity", ({ http }) => {
  const text = promptText(http);
  expect(text.indexOf("read_activity")).toBeGreaterThan(text.indexOf("summarize_activity"));
});

Then("the prompt names the tools {string}", ({ http }, names: string) => {
  for (const name of names.split(", ")) expect(promptText(http)).toContain(name);
});

Then("every tool the prompt names is a tool the server offers", async ({ http, request, tokens }) => {
  const named = [...new Set(promptText(http).match(/\b(?:list|read|summarize)_[a-z_]+\b/g) ?? [])];
  const listed = await (await rpc(request, tokens.mcp, "tools/list")).json();
  const offered = (listed.result.tools as { name: string }[]).map(({ name }) => name);
  expect(named.filter((name) => !offered.includes(name))).toEqual([]);
});

Then("the MCP tool answer's task titles are {string}", ({ http }, titles: string) => {
  const found = JSON.parse(JSON.parse(http.body).result.content[0].text).tasks as { title: unknown }[];
  const plain = found.map(({ title }) =>
    typeof title === "object" && title ? (title as { text: string }).text : title,
  );
  expect(plain.join(", ")).toBe(titles);
});

Then("the input schema of {string} takes only {string}", ({ http }, tool: string, names: string) => {
  const tools = JSON.parse(http.body).result.tools as {
    inputSchema: { properties: Record<string, unknown> };
    name: string;
  }[];
  const schema = tools.find(({ name }) => name === tool)?.inputSchema;
  expect(
    Object.keys(schema?.properties ?? {})
      .sort()
      .join(", "),
  ).toBe(names);
});

Given("I keep the row of the post {string}", async ({ app, http }, id: string) => {
  const [row] = await app.sql`SELECT * FROM posts WHERE id = ${Number(fill(http, id))}`;
  keep(http, "postrow", JSON.stringify(row));
});

Then("the post {string} changed nothing since it was kept", async ({ app, http }, id: string) => {
  const [row] = await app.sql`SELECT * FROM posts WHERE id = ${Number(fill(http, id))}`;
  expect(JSON.parse(JSON.stringify(row))).toEqual(JSON.parse(String(recall(http, "postrow"))));
});

Then(
  "the post {string} changed nothing but its card and its time since it was kept",
  async ({ app, http }, id: string) => {
    const [row] = await app.sql`SELECT * FROM posts WHERE id = ${Number(fill(http, id))}`;
    const kept = JSON.parse(String(recall(http, "postrow")));
    const now = JSON.parse(JSON.stringify(row));
    for (const field of ["og_title", "og_image_url", "updated_at", "search_vector"]) {
      delete kept[field];
      delete now[field];
    }
    expect(now).toEqual(kept);
  },
);

Then("the MCP reply at {string} is:", ({ http }, path: string, expected: string) => {
  expect(dig(JSON.parse(http.body), path)).toEqual(JSON.parse(fill(http, expected)));
});

Then("the MCP tool's words do not hold {string}", ({ http }, text: string) => {
  expect(JSON.parse(http.body).result.content[0].text).not.toContain(fill(http, text));
});

Then("the MCP tool answer at {string} is:", ({ http }, path: string, expected: string) => {
  expect(dig(JSON.parse(toolResult(http).content[0].text), path)).toEqual(JSON.parse(fill(http, expected)));
});

const answerOf = (http: Http) => JSON.parse(toolResult(http).content[0].text);

const day = (shift: number) =>
  new Intl.DateTimeFormat("en-CA", { timeZone: "America/Chicago" }).format(new Date(Date.now() - shift * 86_400_000));

When(
  "I call the MCP tool {string} over the days {int} to {int} days ago",
  async ({ http, request, tokens }, tool: string, from: number, to: number) => {
    http.last = await rpc(request, tokens.mcp, "tools/call", {
      arguments: { from: day(from), to: day(to) },
      name: tool,
    });
    http.body = await http.last.text();
  },
);

When(
  "I call the MCP tool {string} from {int} days ago",
  async ({ http, request, tokens }, tool: string, from: number) => {
    http.last = await rpc(request, tokens.mcp, "tools/call", { arguments: { from: day(from) }, name: tool });
    http.body = await http.last.text();
  },
);

When(
  "I call the MCP tool {string} up to {int} days ago",
  async ({ http, request, tokens }, tool: string, to: number) => {
    http.last = await rpc(request, tokens.mcp, "tools/call", { arguments: { to: day(to) }, name: tool });
    http.body = await http.last.text();
  },
);

Then("the listed posts are {string}", ({ http }, titles: string) => {
  expect((answerOf(http).posts as { title: string }[]).map(({ title }) => title).join(", ")).toBe(titles);
});

Then("the listed posts' draft marks read {string}", ({ http }, marks: string) => {
  const posts = answerOf(http).posts as { draft: boolean; title: string }[];
  const shown = Object.fromEntries(posts.map(({ draft, title }) => [title, draft]));
  for (const pair of marks.split(", ")) {
    const [title, mark] = [pair.slice(0, pair.lastIndexOf(" ")), pair.slice(pair.lastIndexOf(" ") + 1)];
    expect(shown[title], title).toBe(mark === "true");
  }
});

Then("the listed post {string} is:", async ({ app, http }, title: string, expected: string) => {
  const post = (answerOf(http).posts as { title: string }[]).find((found) => found.title === title) as Record<
    string,
    unknown
  >;
  const [row] = await app.sql`SELECT updated_at FROM posts WHERE title = ${title}`;
  expect(post).toEqual({
    ...JSON.parse(fill(http, expected)),
    updated_at: (row.updated_at as Date).toISOString().replace(/\.\d+Z$/, "Z"),
  });
});

Then("the listed post {string} carries the time it went out", async ({ app, http }, title: string) => {
  const post = (answerOf(http).posts as { published_at: string; title: string }[]).find(
    (found) => found.title === title,
  );
  const [row] = await app.sql`SELECT published_at FROM posts WHERE title = ${title}`;
  expect(post?.published_at).toBe((row.published_at as Date).toISOString().replace(/\.\d+Z$/, "Z"));
});

Then("the listed social posts' statuses are {string}", ({ http }, statuses: string) => {
  expect(
    (answerOf(http).social_posts as { status: string }[])
      .map(({ status }) => status)
      .sort()
      .join(", "),
  ).toBe(statuses);
});

Then("the MCP tool answer at {string} holds {int} item(s)", ({ http }, path: string, count: number) => {
  expect(dig(answerOf(http), path)).toHaveLength(count);
});

Then("the suggested edits are {string}", async ({ app }, expected: string) => {
  const rows =
    await app.sql`SELECT status, original, replacement, reason FROM suggestion_edits ORDER BY status::text, id`;
  expect(
    rows
      .map(({ status, original, replacement, reason }) => `${status} ${original} ${replacement} ${reason}`)
      .join(", "),
  ).toBe(expected);
});

Given("the edit {string} is accepted", async ({ app }, original: string) => {
  await app.sql`UPDATE suggestion_edits SET status = 'accepted' WHERE original = ${original}`;
});

Then("the MCP reply has no error", ({ http }) => {
  expect(JSON.parse(http.body).error).toBeUndefined();
});

When(
  "I call the MCP tool {string} with {int} typo edits to the post {string}",
  async ({ http, request, tokens }, tool: string, count: number, id: string) => {
    const edits = Array.from({ length: count }, () => ({ original: "teh", reason: "typo", replacement: "the" }));
    http.last = await rpc(request, tokens.mcp, "tools/call", {
      arguments: { edits, id: Number(fill(http, id)), target: "post" },
      name: tool,
    });
    http.body = await http.last.text();
  },
);

const everyScope = ["read", "suggest", "write", "publish", "delete", "health", "mail", "agents", "notes", "contacts"];

Given(
  "an MCP client connected with every scope but {string}",
  async ({ app, context, http, owner, request, tokens }, scope: string) => {
    await app.sql`INSERT INTO owner_identities ${app.sql({ email: ownerEmail })} ON CONFLICT DO NOTHING`;
    await app.sql`INSERT INTO devices ${app.sql(owner.device)} ON CONFLICT DO NOTHING`;
    await context.addCookies(owner.cookies);
    const connection = await connect(request, http, everyScope.filter((name) => name !== scope).join(" "));
    tokens.mcp = connection.access;
  },
);

Then("the tools offered are exactly those the scopes below guard:", ({ http }, table: DataTable) => {
  const all = [...new Set(table.hashes().flatMap(({ tools }) => tools.split(" ")))].sort();
  const offered = (JSON.parse(http.body).result.tools as { name: string }[]).map(({ name }) => name).sort();
  expect(offered).toEqual(all);
});

Then(
  "the tools offered leave out {string} and keep the rest of every guarded tool",
  async ({ http }, tools: string) => {
    const feature = await readFile(join(root, "features/mcp/scopes.feature"), "utf8");
    const section = feature.slice(feature.indexOf("| scope    | tools |"), feature.indexOf("Scenario Outline"));
    const all = [
      ...new Set(
        [...section.matchAll(/^\s*\| \w+\s+\| ([a-z_ ]+) \|$/gm)].flatMap(([, names]) => names.trim().split(" ")),
      ),
    ].filter((name) => name !== "tools");
    const offered = (JSON.parse(http.body).result.tools as { name: string }[]).map(({ name }) => name).sort();
    const withheld = tools.split(" ");
    expect(offered).toEqual(all.filter((name) => !withheld.includes(name)).sort());
  },
);

Then("the MCP reply at {string} starts with {string}", ({ http }, path: string, text: string) => {
  expect(String(dig(JSON.parse(http.body), path))).toMatch(new RegExp(`^${RegExp.escape(text)}`));
});
