import { createHash, randomBytes } from "node:crypto";
import { expect } from "@playwright/test";
import type postgres from "postgres";
import { Given, Then, type test, When } from "../support/world.ts";

type World = Parameters<Parameters<typeof test>[2]>[0];

async function insertToken(sql: postgres.Sql, scopes?: string[]) {
  const token = randomBytes(32).toString("base64url");
  const digest = createHash("sha256").update(token).digest("hex");
  await sql`INSERT INTO api_tokens ${sql({ name: "Features", token_digest: digest, ...(scopes && { scopes }) })}`;
  return token;
}

async function send(
  { answer, request, tokens }: Pick<World, "answer" | "request" | "tokens">,
  method: string,
  path: string,
  data?: string,
) {
  const response = await request.fetch(`/api/v1${path}`, {
    data: data && JSON.parse(data),
    headers: { Authorization: `Bearer ${tokens.api}` },
    method,
  });
  answer.status = response.status();
  answer.body = await response.text();
}

Given("an API token", async ({ app, tokens }) => {
  tokens.api = await insertToken(app.sql);
});

Given("an API token with the scopes {string}", async ({ app, tokens }, scopes: string) => {
  tokens.api = await insertToken(app.sql, scopes.split(" "));
});

When("I {word} {string} through the API", ({ answer, request, tokens }, method: string, path: string) =>
  send({ answer, request, tokens }, method, path),
);

When(
  "I {word} {string} through the API with:",
  ({ answer, request, tokens }, method: string, path: string, data: string) =>
    send({ answer, request, tokens }, method, path, data),
);

Then("the API answers {int}", ({ answer }, status: number) => {
  expect(answer.status, answer.body).toBe(status);
});

Then("the API answer holds {string}", ({ answer }, text: string) => {
  expect(answer.body).toContain(text);
});

Then("the API answer does not hold {string}", ({ answer }, text: string) => {
  expect(answer.body).not.toContain(text);
});

Then("the API answer holds:", ({ answer }, expected: string) => {
  expect(JSON.parse(answer.body)).toMatchObject(JSON.parse(expected));
});

Then("the API lists the post {string}", async ({ request, tokens }, title: string) => {
  const response = await request.get("/api/v1/posts", { headers: { Authorization: `Bearer ${tokens.api}` } });

  expect(response.status()).toBe(200);
  expect(await response.text()).toContain(title);
});
