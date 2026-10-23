import { createHash, randomBytes } from "node:crypto";
import { expect } from "@playwright/test";
import type postgres from "postgres";
import { Given, Then, When } from "../support/world.ts";

async function insertToken(sql: postgres.Sql, scopes?: string[]) {
  const token = randomBytes(32).toString("base64url");
  const digest = createHash("sha256").update(token).digest("hex");
  await sql`INSERT INTO api_tokens ${sql({ name: "Features", token_digest: digest, ...(scopes && { scopes }) })}`;
  return token;
}

Given("an API token", async ({ app, tokens }) => {
  tokens.api = await insertToken(app.sql);
});

Given("an API token with the scopes {string}", async ({ app, tokens }, scopes: string) => {
  tokens.api = await insertToken(app.sql, scopes.split(" "));
});

When("I call the API with {word} {string}", async ({ answer, request, tokens }, method: string, path: string) => {
  const response = await request.fetch(`/api/v1${path}`, {
    headers: { Authorization: `Bearer ${tokens.api}` },
    method,
  });
  Object.assign(answer, { body: await response.text(), status: response.status() });
});

When(
  "I call the API with {word} {string} and:",
  async ({ answer, request, tokens }, method: string, path: string, body: string) => {
    const response = await request.fetch(`/api/v1${path}`, {
      data: JSON.parse(body),
      headers: { Authorization: `Bearer ${tokens.api}` },
      method,
    });
    Object.assign(answer, { body: await response.text(), status: response.status() });
  },
);

Then("the API answers with status {int}", ({ answer }, status: number) => {
  expect(answer.status).toBe(status);
});

Then("the API answer holds {string}", ({ answer }, text: string) => {
  expect(answer.body).toContain(text);
});

Then("the API answer does not hold {string}", ({ answer }, text: string) => {
  expect(answer.body).not.toContain(text);
});

Then("the API lists the post {string}", async ({ request, tokens }, title: string) => {
  const response = await request.get("/api/v1/posts", { headers: { Authorization: `Bearer ${tokens.api}` } });

  expect(response.status()).toBe(200);
  expect(await response.text()).toContain(title);
});
