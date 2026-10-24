import { createHash, randomBytes } from "node:crypto";
import { type APIRequestContext, expect } from "@playwright/test";
import type postgres from "postgres";
import { Then } from "../support/world.ts";

type Operation = {
  operationId: string;
  parameters?: { name: string; schema: Record<string, unknown> }[];
  requestBody?: Record<string, unknown>;
  responses: Record<string, unknown>;
};
type Document = { paths: Record<string, Record<string, Operation>> } & Record<string, unknown>;

const scopes = ["read", "suggest", "write", "publish", "delete", "health", "mail", "agents", "notes", "contacts"];

async function tokenFor(sql: postgres.Sql, granted = scopes) {
  const value = randomBytes(32).toString("base64url");
  const token_digest = createHash("sha256").update(value).digest("hex");
  await sql`INSERT INTO api_tokens ${sql({ name: "Document", scopes: granted, token_digest })}`;
  return value;
}

async function documentFrom(request: APIRequestContext, sql: postgres.Sql) {
  const response = await request.get("/api/v1/openapi.json", {
    headers: { Authorization: `Bearer ${await tokenFor(sql)}` },
  });
  return (await response.json()) as Document;
}

const operations = (document: Document) =>
  Object.entries(document.paths).flatMap(([path, verbs]) =>
    Object.entries(verbs).map(([verb, operation]) => ({ operation, path, verb })),
  );

const send = (request: APIRequestContext, token: string | undefined, verb: string, path: string, query = "") =>
  request.fetch(`/api/v1${path.replaceAll(/\{\w+\}/g, "0")}${query}`, {
    data: ["patch", "post"].includes(verb) ? "{}" : undefined,
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    maxRedirects: 0,
    method: verb.toUpperCase(),
  });

Then("every operation the API document names refuses a request with no token", async ({ app, request }) => {
  const document = await documentFrom(request, app.sql);
  const unguarded: string[] = [];
  for (const { path, verb } of operations(document)) {
    const response = await send(request, undefined, verb, path);
    if (response.status() !== 401 || response.headers()["www-authenticate"] !== "Bearer") {
      unguarded.push(`${verb.toUpperCase()} ${path} answered ${response.status()}`);
    }
  }
  expect(unguarded).toEqual([]);
});

Then("every operation the API document names answers with a status it documents", async ({ app, request }) => {
  const document = await documentFrom(request, app.sql);
  const token = await tokenFor(app.sql);
  const wrong: string[] = [];
  for (const { operation, path, verb } of operations(document)) {
    const response = await send(request, token, verb, path);
    const documented = Object.keys(operation.responses);
    if (!documented.includes(String(response.status()))) {
      wrong.push(`${verb.toUpperCase()} ${path} answered ${response.status()}, documents ${documented.join(" ")}`);
    }
    if (!(response.headers()["content-type"] ?? "").startsWith("application/json")) {
      wrong.push(`${verb.toUpperCase()} ${path} answered ${response.headers()["content-type"]}`);
    }
  }
  expect(wrong).toEqual([]);
});

Then(
  "the API document is OpenAPI 3.1, each operation has one ID, and every reference in it resolves",
  async ({ app, request }) => {
    const document = await documentFrom(request, app.sql);
    expect(String(document.openapi)).toMatch(/^3\.1\./);
    const ids = operations(document).map(({ operation }) => operation.operationId);
    expect(ids.filter((id, index) => ids.indexOf(id) !== index)).toEqual([]);
    expect(ids.every(Boolean)).toBe(true);
    const refs = [...JSON.stringify(document).matchAll(/"\$ref":"([^"]+)"/g)].map(([, ref]) => ref);
    const missing = [...new Set(refs)].filter((ref) => {
      const found = ref
        .replace(/^#\//, "")
        .split("/")
        .map((part) => decodeURIComponent(part).replaceAll("~1", "/").replaceAll("~0", "~"))
        .reduce<unknown>((value, key) => (value as Record<string, unknown> | undefined)?.[key], document);
      return found === undefined;
    });
    expect(missing).toEqual([]);
  },
);

Then(
  "the API document bounds each repeat field of a new task as the cadence contract does",
  async ({ app, request }) => {
    const document = await documentFrom(request, app.sql);
    const body = document.paths["/tasks"].post.requestBody as Record<string, Record<string, Record<string, unknown>>>;
    const recur = (body.content["application/json"].schema as Record<string, Record<string, Record<string, unknown>>>)
      .properties.recur.properties as Record<string, Record<string, unknown>>;
    const bounds = Object.fromEntries(
      ["every", "weekday", "day", "month"].map((field) => [field, [recur[field].minimum, recur[field].maximum]]),
    );
    expect(bounds).toEqual({ day: [1, 31], every: [1, 365], month: [1, 12], weekday: [0, 6] });
    expect(recur.week.enum).toEqual([-1, 1, 2, 3, 4]);
  },
);

const marker = "zephyr";

const guarded = ["workout", "message", "mail_thread", "note", "note_folder"];

const guardedRows = (value: unknown): unknown[] => {
  if (Array.isArray(value)) return value.flatMap(guardedRows);
  if (value && typeof value === "object") {
    const row = value as Record<string, unknown>;
    return [...Object.values(row).flatMap(guardedRows), ...(guarded.includes(String(row.kind)) ? [row] : [])];
  }
  return [];
};

Then(
  "no operation the API document names shows a workout, mail or note row to a token with only read",
  async ({ app, request }) => {
    const document = await documentFrom(request, app.sql);
    const token = await tokenFor(app.sql, ["read"]);
    const [view] = await app.sql`SELECT id FROM saved_views LIMIT 1`;
    const day = (shift: number) => new Date(Date.now() + shift * 86_400_000).toISOString().slice(0, 10);
    const query = `?${new URLSearchParams({ from: day(-7), name: marker, query: marker, to: day(0) })}`;
    const leaked: string[] = [];
    for (const { path, verb } of operations(document)) {
      const filled = path.replaceAll(/\{\w+\}/g, String(view.id));
      const response = await send(request, token, verb, filled, ["get", "delete"].includes(verb) ? query : "");
      const body = await response.text();
      let rows: unknown[] = [];
      try {
        rows = guardedRows(JSON.parse(body));
      } catch {}
      if (body.includes(marker) || rows.length) leaked.push(`${verb.toUpperCase()} ${path}`);
    }
    expect(leaked).toEqual([]);
  },
);

Then("a token with read, health, mail and notes sees the workout, mail and note rows", async ({ app, request }) => {
  const token = await tokenFor(app.sql, ["read", "health", "mail", "notes"]);
  const day = (shift: number) => new Date(Date.now() + shift * 86_400_000).toISOString().slice(0, 10);
  const response = await request.get(`/api/v1/activity?from=${day(-7)}&to=${day(0)}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const searched = await request.get(`/api/v1/search?query=${marker}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const rows = [...guardedRows(await response.json()), ...guardedRows(await searched.json())];
  const kinds = new Set(rows.map((row) => (row as Record<string, unknown>).kind));
  expect([...kinds].sort()).toEqual(expect.arrayContaining(["note", "workout"]));
  expect([...kinds].some((kind) => ["message", "mail_thread"].includes(String(kind)))).toBe(true);
});

const idSchemas = (schema: unknown, parent = ""): Record<string, unknown>[] => {
  if (!schema || typeof schema !== "object") return [];
  return Object.entries(schema as Record<string, unknown>).flatMap(([key, value]) => {
    if (!value || typeof value !== "object") return [];
    const isId = key.endsWith("id") || (key === "items" && parent.endsWith("ids"));
    return [...(isId ? [value as Record<string, unknown>] : []), ...idSchemas(value, key)];
  });
};

Then(
  "every ID the API document and the MCP tools take runs from 1 to {int}",
  async ({ app, request, tokens }, largest: number) => {
    const document = await documentFrom(request, app.sql);
    const inputs = operations(document).flatMap(({ operation }) => [
      Object.fromEntries((operation.parameters ?? []).map((parameter) => [parameter.name, parameter.schema])),
      operation.requestBody ?? {},
    ]);
    const listed = await request.post("/mcp", {
      data: { id: 1, jsonrpc: "2.0", method: "tools/list" },
      headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${tokens.mcp}` },
    });
    const tools = (await listed.json()).result.tools as { inputSchema: unknown }[];
    const bounds = [...inputs, ...tools.map((tool) => tool.inputSchema)]
      .flatMap((schema) => idSchemas(schema))
      .map((schema) => JSON.stringify({ maximum: schema.maximum, minimum: schema.minimum }));
    expect([...new Set(bounds)]).toEqual([JSON.stringify({ maximum: largest, minimum: 1 })]);
  },
);

Then(
  "the API document lists the status {int} for {word} {string}",
  async ({ app, request }, status: number, verb: string, path: string) => {
    const document = await documentFrom(request, app.sql);
    expect(Object.keys(document.paths[path]?.[verb.toLowerCase()]?.responses ?? {})).toContain(String(status));
  },
);
