import { createHash, randomBytes } from "node:crypto";
import { expect } from "@playwright/test";
import { answer, callApi, dig, fill, keep, recall } from "../support/api.ts";
import { Given, Then, When } from "../support/world.ts";

const mint = async (sql: import("postgres").Sql, scopes?: string[]) => {
  const value = randomBytes(32).toString("base64url");
  const token_digest = createHash("sha256").update(value).digest("hex");
  await sql`INSERT INTO api_tokens ${sql(scopes ? { name: "Features", scopes, token_digest } : { name: "Features", token_digest })}`;
  return value;
};

Given("an API token", async ({ app, tokens }) => {
  tokens.api = await mint(app.sql);
});

Given("an API token with the scopes {string}", async ({ app, tokens }, scopes: string) => {
  tokens.api = await mint(app.sql, scopes.split(/,\s*|\s+/));
});

Then("the API lists the post {string}", async ({ request, tokens }, title: string) => {
  const response = await request.get("/api/v1/posts", { headers: { Authorization: `Bearer ${tokens.api}` } });

  expect(response.status()).toBe(200);
  expect(await response.text()).toContain(title);
});

When("I {word} {string} through the API", async ({ http, request, tokens }, method: string, path: string) => {
  await callApi(request, http, tokens.api, method, path.replace(/^\//, ""));
});

When(
  "I {word} {string} through the API with:",
  async ({ http, request, tokens }, method: string, path: string, body: string) => {
    await callApi(request, http, tokens.api, method, path.replace(/^\//, ""), body);
  },
);

When("I call the API {word} {string} with no token", async ({ http, request }, method: string, path: string) => {
  await callApi(request, http, undefined, method, path);
});

When(
  "I call the API {word} {string} with the token {string}",
  async ({ http, request }, method: string, path: string, token: string) => {
    await callApi(request, http, token, method, path);
  },
);

When("I keep the answer's {string} as {string}", ({ http }, path: string, name: string) => {
  keep(http, name, dig(answer(http), path));
});

Then("the API answers {int}", ({ answer }, status: number) => {
  expect(answer.status, answer.body.slice(0, 1000)).toBe(status);
});

Then("the API answer holds {string}", ({ answer }, text: string) => {
  expect(answer.body).toContain(text);
});

Then("the API answer does not hold {string}", ({ answer }, text: string) => {
  expect(answer.body).not.toContain(text);
});

Then("the API answer holds:", ({ app, http }, expected: string) => {
  expect(answer(http)).toMatchObject(JSON.parse(fill(http, expected).replaceAll("SITE", app.url)));
});

Then("the API answer is:", ({ http }, expected: string) => {
  expect(answer(http)).toEqual(JSON.parse(fill(http, expected)));
});

Then("the API answer at {string} is {string}", ({ app, http }, path: string, value: string) => {
  expect(dig(answer(http), path)).toEqual(JSON.parse(fill(http, value).replaceAll("SITE", app.url)));
});

Then("the API answer at {string} matches:", ({ http }, path: string, expected: string) => {
  expect(dig(answer(http), path)).toMatchObject(JSON.parse(fill(http, expected)));
});

Then("the API answer at {string} holds {int} item(s)", ({ http }, path: string, count: number) => {
  expect(dig(answer(http), path)).toHaveLength(count);
});

Then("the API answer has no {string}", ({ http }, path: string) => {
  expect(dig(answer(http), path)).toBeUndefined();
});

const allScopes = ["read", "suggest", "write", "publish", "delete", "health", "mail", "agents", "notes", "contacts"];
const ownerTokens = new WeakMap<import("../support/http.ts").Http, string>();

const ownerToken = async (sql: import("postgres").Sql, http: import("../support/http.ts").Http) => {
  if (!ownerTokens.has(http)) ownerTokens.set(http, await mint(sql, allScopes));
  return ownerTokens.get(http) as string;
};

Given("the owner calls {word} {string}", async ({ app, http, request }, method: string, path: string) => {
  const response = await callApi(request, http, await ownerToken(app.sql, http), method, path);
  expect(response.status(), http.body.slice(0, 500)).toBeLessThan(300);
});

Given(
  "the owner calls {word} {string} with:",
  async ({ app, http, request }, method: string, path: string, body: string) => {
    const response = await callApi(request, http, await ownerToken(app.sql, http), method, path, body);
    expect(response.status(), http.body.slice(0, 500)).toBeLessThan(300);
  },
);

Given("an API token that may do all but {string}", async ({ app, tokens }, scope: string) => {
  tokens.api = await mint(
    app.sql,
    allScopes.filter((name) => name !== scope),
  );
});

Given("an API token named {string}", async ({ app, tokens }, name: string) => {
  tokens.api = randomBytes(32).toString("base64url");
  const token_digest = createHash("sha256").update(tokens.api).digest("hex");
  await app.sql`INSERT INTO api_tokens ${app.sql({ name, token_digest })}`;
});

When(
  "I call the API {word} {string} with the authorization {string}",
  async ({ http, request, tokens }, method: string, path: string, authorization: string) => {
    const url = `/api/v1/${fill(http, path)}`;
    const headers = { Authorization: authorization.replace("{token}", tokens.api ?? "") };
    http.last = await request.fetch(url, { headers, maxRedirects: 0, method });
    http.body = await http.last.text();
  },
);

Then("the API refuses for want of the {word} scope", ({ http }, scope: string) => {
  expect(http.last?.status(), http.body).toBe(403);
  expect(http.last?.headers()["www-authenticate"]).toBe(`Bearer error="insufficient_scope", scope="${scope}"`);
  expect(answer(http).error_description).toContain(`the ${scope} scope`);
});

Then("the API answer's {string} holds {string}", ({ http }, path: string, text: string) => {
  expect(String(dig(answer(http), path))).toContain(fill(http, text));
});

When("I call the API GET {string} with the MCP access token", async ({ http, request, tokens }, path: string) => {
  await callApi(request, http, tokens.mcp, "GET", path);
});

When("I call MCP with the API token", async ({ http, request, tokens }) => {
  http.last = await request.post("/mcp", {
    data: { id: 1, jsonrpc: "2.0", method: "tools/list" },
    headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${tokens.api}` },
  });
  http.body = await http.last.text();
});

Then("the API answer at {string} is the stored last use", async ({ app, http }, path: string) => {
  const [{ used }] = await app.sql`SELECT last_used_at AS used FROM api_tokens`;
  expect(dig(answer(http), path)).toBe((used as Date).toISOString().replace(/\.\d+Z$/, "Z"));
});

Then(
  "{word} {string} refuses a token with every scope but each of {string}, naming that scope",
  async ({ app, http, request }, method: string, path: string, scopes: string) => {
    const target = path.replaceAll(/\{\w+\}/g, "0").slice(1);
    const body = ["PATCH", "POST"].includes(method) ? "{}" : undefined;
    for (const scope of scopes.split(", ")) {
      const token = await mint(
        app.sql,
        allScopes.filter((name) => name !== scope),
      );
      const response = await callApi(request, http, token, method, target, body);
      expect(response.status(), `${scope}: ${http.body}`).toBe(403);
      expect(response.headers()["www-authenticate"]).toBe(`Bearer error="insufficient_scope", scope="${scope}"`);
    }
  },
);

Then("the API answer at {string} is the client's creation time", async ({ app, http }, path: string) => {
  const [{ created }] = await app.sql`SELECT created_at AS created FROM oauth_clients`;
  expect(dig(answer(http), path)).toBe((created as Date).toISOString().replace(/\.\d+Z$/, "Z"));
});

When(
  "I call the API {word} {string} as {string}",
  async ({ http, request, tokens }, method: string, path: string, userAgent: string) => {
    http.last = await request.fetch(`/api/v1/${fill(http, path)}`, {
      headers: { Accept: "application/json", Authorization: `Bearer ${tokens.api}`, "User-Agent": userAgent },
      maxRedirects: 0,
      method,
    });
    http.body = await http.last.text();
  },
);

Then("the API answer's errors are only {string}", ({ http }, fields: string) => {
  expect(Object.keys(answer(http).errors).join(", ")).toBe(fields);
});

Then("the API answer's errors under {string} are words", ({ http }, field: string) => {
  const reasons = answer(http).errors[field] as unknown[];
  expect(reasons.length).toBeGreaterThan(0);
  expect(reasons.every((reason) => typeof reason === "string")).toBe(true);
});

When(
  "I call the API {word} {string} with the body {string}",
  async ({ http, request, tokens }, method: string, path: string, body: string) => {
    await callApi(request, http, tokens.api, method, path.replace(/^\//, ""), body || undefined);
  },
);

Given("I keep the post's newest edit as {string}", async ({ app, http }, name: string) => {
  const [edit] = await app.sql`SELECT id FROM post_edits ORDER BY id DESC LIMIT 1`;
  keep(http, name, edit.id);
});

When("I keep the answer as {string}", ({ http }, name: string) => {
  keep(http, name, http.body);
});

Then("the API answer is the one kept as {string}", ({ http }, name: string) => {
  expect(answer(http)).toEqual(JSON.parse(String(recall(http, name))));
});

When(
  "I call the API POST {string} with a gotcha of {int} {string}s",
  async ({ http, request, tokens }, path: string, length: number, letter: string) => {
    const body = { agent: "claude-code", model: "claude-opus-5-5", text: letter.repeat(length), type: "gotcha" };
    await callApi(request, http, tokens.api, "POST", path, JSON.stringify(body));
  },
);

When(
  "I call the API PATCH {string} with a text of {int} {string}s",
  async ({ http, request, tokens }, path: string, length: number, letter: string) => {
    const body = { agent: "claude-code", model: "claude-opus-5-5", text: letter.repeat(length) };
    await callApi(request, http, tokens.api, "PATCH", path, JSON.stringify(body));
  },
);

Then(
  "the API answer's facts are {int} text(s) of {int} {string}s",
  ({ http }, count: number, length: number, letter: string) => {
    expect((answer(http).facts as { text: string }[]).map(({ text }) => text)).toEqual(
      Array.from({ length: count }, () => letter.repeat(length)),
    );
  },
);

Then("the API answer at {string} is:", ({ http }, path: string, expected: string) => {
  expect(dig(answer(http), path)).toEqual(JSON.parse(fill(http, expected)));
});

Then("the API answer at {string} is a time", ({ http }, path: string) => {
  expect(Number.isNaN(Date.parse(String(dig(answer(http), path))))).toBe(false);
});

Then(
  "the tags {word} holds for {word} are {string}",
  async ({ app, http }, table: string, owner: string, expected: string) => {
    const key = table.replace(/_tags$/, "_id");
    const rows = await app.sql.unsafe(`
    SELECT t.name, t.scope, t.project_id FROM ${table} held JOIN tags t ON t.id = held.tag_id
    WHERE held.${key} = ${Number(fill(http, owner))} ORDER BY t.name, t.project_id
  `);
    const shown = rows.map(({ name, scope, project_id }) => [name, scope, project_id].filter((part) => part !== null));
    expect(shown.map((parts) => parts.join(" ")).join(", ")).toBe(fill(http, expected));
  },
);

Then("the API answer holds {int} record(s) under each of {string}", ({ http }, count: number, kinds: string) => {
  const found = answer(http);
  for (const kind of kinds.split(", ")) expect(found[kind].records, kind).toHaveLength(count);
});

Then("the API answer leaves out {string} and their counts", ({ http }, kinds: string) => {
  const found = answer(http);
  for (const kind of kinds.split(", ")) {
    expect(Object.keys(found)).not.toContain(kind);
    expect(Object.keys(found.counts)).not.toContain(kind);
  }
});

Given("nothing more", () => {});

Given(
  "the owner calls {word} {string} with the body {string}",
  async ({ app, http, request }, method: string, path: string, body: string) => {
    const response = await callApi(request, http, await ownerToken(app.sql, http), method, path, body);
    expect(response.status(), http.body.slice(0, 500)).toBeLessThan(300);
  },
);

Then("the page {string} answers {int}", async ({ request }, path: string, status: number) => {
  expect((await request.get(path, { maxRedirects: 0 })).status()).toBe(status);
});

Then(
  "capturing a task into each of {string} is refused for want of the publish scope",
  async ({ http, request, tokens }, keys: string) => {
    for (const key of keys.split(",")) {
      await callApi(request, http, tokens.api, "POST", "tasks", JSON.stringify({ project: key, title: "Loud" }));
      expect(http.last?.status(), `${key}: ${http.body}`).toBe(403);
    }
  },
);

Then("the API answer at {string} is a word", ({ http }, path: string) => {
  const value = dig(answer(http), path);
  expect(typeof value).toBe("string");
  expect(String(value).length).toBeGreaterThan(0);
});

Then("the API answer at {string} is about now in seconds", ({ http }, path: string) => {
  expect(Math.abs(Number(dig(answer(http), path)) - Date.now() / 1000)).toBeLessThan(60);
});
