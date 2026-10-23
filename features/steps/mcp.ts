import { createHash, randomBytes } from "node:crypto";
import { expect } from "@playwright/test";
import { Given, Then, type test, When } from "../support/world.ts";
import { signIn } from "./admin.ts";

type World = Parameters<Parameters<typeof test>[2]>[0];

const redirectUri = "http://127.0.0.1/callback";

async function connect({ page, request, tokens }: Pick<World, "page" | "request" | "tokens">, scope: string) {
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

async function rpc({ request, tokens }: Pick<World, "request" | "tokens">, method: string, params: object) {
  const response = await request.post("/mcp", {
    data: { id: 1, jsonrpc: "2.0", method, params },
    headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${tokens.mcp}` },
  });
  const body = await response.text();
  return { body, result: response.ok() ? JSON.parse(body).result : undefined, status: response.status() };
}

async function call(
  { answer, request, tokens }: Pick<World, "answer" | "request" | "tokens">,
  name: string,
  args: string,
) {
  const { body, result, status } = await rpc({ request, tokens }, "tools/call", { arguments: JSON.parse(args), name });
  answer.status = status;
  answer.body = body;
  answer.content = result?.content?.[0]?.text ?? body;
  answer.error = result?.isError ?? false;
}

When("an MCP client connects and I approve it", ({ page, request, tokens }) =>
  connect({ page, request, tokens }, "read"),
);

Given(
  "an MCP client connected with the scopes {string}",
  async ({ app, context, owner, page, request, tokens }, scope: string) => {
    await signIn({ app, context, owner });
    await connect({ page, request, tokens }, scope);
  },
);

When("I call the MCP tool {string}", ({ answer, request, tokens }, name: string) =>
  call({ answer, request, tokens }, name, "{}"),
);

When("I call the MCP tool {string} with:", ({ answer, request, tokens }, name: string, args: string) =>
  call({ answer, request, tokens }, name, args),
);

Then("the MCP tool {string} answers with {string}", async ({ answer, request, tokens }, tool: string, text: string) => {
  await call({ answer, request, tokens }, tool, "{}");
  expect(answer.status).toBe(200);
  expect(answer.content).toContain(text);
});

Then("the MCP answer holds {string}", ({ answer }, text: string) => {
  expect(answer.status).toBe(200);
  expect(answer.body).toContain(text);
});

Then("the MCP answer does not hold {string}", ({ answer }, text: string) => {
  expect(answer.body).not.toContain(text);
});

Then("the MCP answer holds:", ({ answer }, expected: string) => {
  expect(answer.error, answer.content).toBe(false);
  expect(JSON.parse(answer.content ?? "")).toMatchObject(JSON.parse(expected));
});

Then("the MCP tool refuses with {string}", ({ answer }, message: string) => {
  expect(answer.content).toBe(message);
});

async function toolNames({ request, tokens }: Pick<World, "request" | "tokens">) {
  const { result } = await rpc({ request, tokens }, "tools/list", {});
  return result.tools.map((tool: { name: string }) => tool.name);
}

Then("the MCP tools hold {string}", async ({ request, tokens }, name: string) => {
  expect(await toolNames({ request, tokens })).toContain(name);
});

Then("the MCP tools leave out {string}", async ({ request, tokens }, name: string) => {
  expect(await toolNames({ request, tokens })).not.toContain(name);
});

Then("the MCP answer has no {string}", ({ answer }, path: string) => {
  const found = path.split(".").reduce((value, key) => value?.[key], JSON.parse(answer.content ?? ""));
  expect(found).toBeUndefined();
});
