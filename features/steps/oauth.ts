import { createHash, randomBytes } from "node:crypto";
import { expect } from "@playwright/test";
import { Given, Then, When } from "../support/world.ts";
import { ask, sendHeader } from "./http.ts";

const clientId = "11111111-0000-4000-8000-000000000001";
const redirectUri = "https://claude.ai/api/mcp/auth_callback";
export const digestOf = (value: string) => createHash("sha256").update(value).digest("hex");
const digest = digestOf;

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

Then("the MCP tool refuses", ({ answer }) => {
  expect(answer.error).toBe(true);
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
