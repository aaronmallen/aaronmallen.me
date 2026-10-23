import { createHash, randomBytes } from "node:crypto";
import { expect } from "@playwright/test";
import { Then, When } from "../support/world.ts";

const redirectUri = "http://127.0.0.1/callback";

When("an MCP client connects and I approve it", async ({ page, request, tokens }) => {
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
    scope: "read",
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
});

Then("the MCP tool {string} answers with {string}", async ({ request, tokens }, tool: string, text: string) => {
  const response = await request.post("/mcp", {
    data: { id: 1, jsonrpc: "2.0", method: "tools/call", params: { arguments: {}, name: tool } },
    headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${tokens.mcp}` },
  });

  expect(response.status()).toBe(200);
  expect(await response.text()).toContain(text);
});
