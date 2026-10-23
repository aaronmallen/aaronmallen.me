import { createHash, randomBytes } from "node:crypto";
import { type APIRequestContext, expect, type Page } from "@playwright/test";
import { Then, When } from "../support/world.ts";

const redirectUri = "http://127.0.0.1/callback";

async function connect(page: Page, request: APIRequestContext, scope: string) {
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
  return (await granted.json()).access_token as string;
}

async function call(request: APIRequestContext, token: string | undefined, name: string, args: unknown) {
  const response = await request.post("/mcp", {
    data: { id: 1, jsonrpc: "2.0", method: "tools/call", params: { arguments: args, name } },
    headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${token}` },
  });
  return { body: await response.text(), status: response.status() };
}

When("an MCP client connects and I approve it", async ({ page, request, tokens }) => {
  tokens.mcp = await connect(page, request, "read");
});

When(
  "an MCP client connects with the scopes {string} and I approve it",
  async ({ page, request, tokens }, scope: string) => {
    tokens.mcp = await connect(page, request, scope);
  },
);

When("I call the MCP tool {string}", async ({ answer, request, tokens }, name: string) => {
  Object.assign(answer, await call(request, tokens.mcp, name, {}));
});

When("I call the MCP tool {string} with:", async ({ answer, request, tokens }, name: string, args: string) => {
  Object.assign(answer, await call(request, tokens.mcp, name, JSON.parse(args)));
});

Then("the MCP answer holds {string}", ({ answer }, text: string) => {
  expect(answer.status).toBe(200);
  expect(answer.body).toContain(text);
});

Then("the MCP answer does not hold {string}", ({ answer }, text: string) => {
  expect(answer.body).not.toContain(text);
});

Then("the MCP tool {string} answers with {string}", async ({ request, tokens }, name: string, text: string) => {
  const { body, status } = await call(request, tokens.mcp, name, {});

  expect(status).toBe(200);
  expect(body).toContain(text);
});
