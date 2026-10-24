import { expect } from "@playwright/test";
import { filled } from "../support/api.ts";
import { Then, When } from "../support/world.ts";
import { send } from "./api.ts";
import { call } from "./mcp.ts";

const trusted = (value: unknown): unknown => {
  if (Array.isArray(value)) return value.map(trusted);
  if (value && typeof value === "object") {
    const hash = value as Record<string, unknown>;
    if (hash.untrusted === true) return hash.text;
    return Object.fromEntries(Object.entries(hash).map(([key, inner]) => [key, trusted(inner)]));
  }
  return value;
};

Then(
  "the API answer to GET {string} matches the MCP tool {string} with:",
  async ({ answer, app, http, request, tokens }, path: string, tool: string, args: string) => {
    await send({ app, http, request, tokens }, "GET", path);
    expect(answer.status, answer.body).toBe(200);
    const api = JSON.parse(answer.body);
    await call({ answer, http, request, tokens }, tool, await filled(app.sql, args, http));
    expect(answer.error, answer.content).toBe(false);
    expect(trusted(JSON.parse(answer.content ?? "{}"))).toEqual(trusted(api));
  },
);

When("I post to {string} from the page", async ({ app, http, page }, path: string) => {
  const token = await page.locator("input[name='_csrf_token']").first().inputValue();
  http.last = await page.request.post(await filled(app.sql, path), { form: { _csrf_token: token }, maxRedirects: 0 });
  http.body = await http.last.text();
});
