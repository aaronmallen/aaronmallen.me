import { createHash, randomBytes } from "node:crypto";
import { expect } from "@playwright/test";
import { Given, Then } from "../support/world.ts";

Given("an API token", async ({ app, tokens }) => {
  tokens.api = randomBytes(32).toString("base64url");
  const digest = createHash("sha256").update(tokens.api).digest("hex");
  await app.sql`INSERT INTO api_tokens ${app.sql({ name: "Features", token_digest: digest })}`;
});

Then("the API lists the post {string}", async ({ request, tokens }, title: string) => {
  const response = await request.get("/api/v1/posts", { headers: { Authorization: `Bearer ${tokens.api}` } });

  expect(response.status()).toBe(200);
  expect(await response.text()).toContain(title);
});
