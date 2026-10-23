import { createHash } from "node:crypto";
import { expect, type Page } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import type postgres from "postgres";
import type { Http } from "../support/http.ts";
import { csrfIn, formValue } from "../support/http.ts";
import { Given, Then, When } from "../support/world.ts";

const verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk";
const challenge = createHash("sha256").update(verifier).digest("base64url");
const decided = new WeakMap<Http, string>();

async function clientOf(sql: postgres.Sql, name: string) {
  const [client] = await sql`
    SELECT client_id, redirect_uris FROM oauth_clients WHERE coalesce(client_name, '') = ${name} ORDER BY id LIMIT 1
  `;
  return client as { client_id: string; redirect_uris: string[] };
}

async function pathFor(sql: postgres.Sql, url: string, name: string, overrides: Record<string, string> = {}) {
  const client = await clientOf(sql, name);
  const params: Record<string, string | undefined> = {
    client_id: client?.client_id,
    code_challenge: challenge,
    code_challenge_method: "S256",
    redirect_uri: client?.redirect_uris[0],
    resource: `${url}/mcp`,
    response_type: "code",
    scope: "read suggest",
    state: "state-from-claude",
  };
  const extra: [string, string][] = [];
  for (const [key, value] of Object.entries(overrides)) {
    if (value === "(none)") delete params[key];
    else if (key.endsWith("[]")) extra.push([key, value]);
    else {
      params[key] = formValue(value.replace("SITE", url).replaceAll("(space)", " "))
        .replaceAll("\\0", "\u0000")
        .replaceAll("\\n", "\n");
    }
  }
  const query = new URLSearchParams([
    ...(Object.entries(params).filter(([, value]) => value !== undefined) as [string, string][]),
    ...extra.flatMap(([key, value]) => value.split(",").map((part) => [key, part] as [string, string])),
  ]);
  return `/oauth/authorize?${query}`;
}

const overridesOf = (table?: DataTable) => (table ? table.rowsHash() : {});

const fieldsIn = (html: string) =>
  Object.fromEntries(
    [...html.matchAll(/<input[^>]*type="hidden"[^>]*>/g)].map(([input]) => [
      input.match(/name="([^"]+)"/)?.[1] ?? "",
      (input.match(/value="([^"]*)"/)?.[1] ?? "").replaceAll("&amp;", "&").replaceAll("&quot;", '"'),
    ]),
  );

async function decide(http: Http, path: string, decision: string, change: Record<string, string | null> = {}) {
  const agent = await http.agent();
  const form = await (await agent.get(path)).text();
  const fields: Record<string, string> = { ...fieldsIn(form), decision };
  if (!fields._csrf_token) fields._csrf_token = csrfIn(form);
  for (const [key, value] of Object.entries(change)) {
    if (value === null) delete fields[key];
    else fields[key] = value;
  }
  await http.send("POST", "/oauth/authorize", { form: fields });
  decided.set(http, http.last?.headers().location ?? "");
}

When("the client {string} asks to be authorized", async ({ app, http }, name: string) => {
  await http.send("GET", await pathFor(app.sql, app.url, name));
});

When("the client {string} asks to be authorized with:", async ({ app, http }, name: string, table: DataTable) => {
  await http.send("GET", await pathFor(app.sql, app.url, name, overridesOf(table)));
});

When("I open the authorization the client {string} asks for", async ({ app, page }, name: string) => {
  await page.goto(await pathFor(app.sql, app.url, name));
});

When(
  "I open the authorization the client {string} asks for with:",
  async ({ app, page }, name: string, table: DataTable) => {
    await page.goto(await pathFor(app.sql, app.url, name, overridesOf(table)));
  },
);

When("I approve the authorization the client {string} asks for", async ({ app, http }, name: string) => {
  await decide(http, await pathFor(app.sql, app.url, name), "approve");
});

When(
  "I approve the authorization the client {string} asks for with:",
  async ({ app, http }, name: string, table: DataTable) => {
    await decide(http, await pathFor(app.sql, app.url, name, overridesOf(table)), "approve");
  },
);

When("I cancel the authorization the client {string} asks for", async ({ app, http }, name: string) => {
  await decide(http, await pathFor(app.sql, app.url, name), "cancel");
});

When(
  "I approve the authorization the client {string} asks for, swapping in:",
  async ({ app, http }, name: string, table: DataTable) => {
    const change = Object.fromEntries(
      Object.entries(table.rowsHash()).map(([key, value]) => [
        key,
        value === "(none)" ? null : value.replaceAll("\\0", "\u0000").replaceAll("\\n", "\n"),
      ]),
    );
    await decide(http, await pathFor(app.sql, app.url, name), "approve", change);
  },
);

When(
  "a stranger posts an approval for the client {string} that was never shown",
  async ({ app, http }, name: string) => {
    const client = await clientOf(app.sql, name);
    await http.send("POST", "/oauth/authorize", {
      form: { client_id: client.client_id, decision: "approve", redirect_uri: client.redirect_uris[0] },
    });
  },
);

Then("the callback goes to the client's redirect URI {string}", ({ http }, uri: string) => {
  expect(decided.get(http) ?? http.last?.headers().location).toMatch(new RegExp(`^${RegExp.escape(uri)}\\?`));
});

Then("the callback carries:", ({ app, http }, table: DataTable) => {
  const params = new URL(decided.get(http) ?? "").searchParams;
  for (const [key, value] of table.raw()) {
    if (value === "(none)") expect(params.has(key), key).toBe(false);
    else if (value === "(a code)") expect(params.get(key)?.length ?? 0).toBeGreaterThan(20);
    else expect(params.get(key), key).toBe(value.replace("SITE", app.url));
  }
});

Then(
  "the code is stored hashed and tied to the client, the redirect URI, the challenge, the resource and {string}",
  async ({ app, http }, scopes: string) => {
    const code = new URL(decided.get(http) ?? "").searchParams.get("code") ?? "";
    const [row] = await app.sql`
    SELECT o.*, c.client_name, array_to_string(o.scopes, ' ') AS granted,
      o.expires_at BETWEEN now() AND now() + interval '61 seconds' AS soon
    FROM oauth_codes o JOIN oauth_clients c ON c.id = o.oauth_client_id
  `;
    expect(row.code_digest).toBe(createHash("sha256").update(code).digest("hex"));
    expect(Object.values(row).map(String)).not.toContain(code);
    expect([row.client_name, row.code_challenge, row.resource, row.granted]).toEqual([
      "Claude",
      challenge,
      `${app.url}/mcp`,
      scopes,
    ]);
    expect(row.redirect_uri).toBe("https://claude.ai/api/mcp/auth_callback");
    expect(row.soon).toBe(true);
    expect(row.used_at).toBeNull();
  },
);

Then("the code grants {string}", async ({ app }, scopes: string) => {
  const [row] = await app.sql`SELECT array_to_string(scopes, ' ') AS granted FROM oauth_codes`;
  expect(row?.granted).toBe(scopes);
});

Then("the code is tied to the resource {string}", async ({ app }, resource: string) => {
  const [row] = await app.sql`SELECT resource, redirect_uri FROM oauth_codes`;
  expect(row.resource).toBe(resource.replace("SITE", app.url));
});

Then("the code is tied to the redirect URI {string}", async ({ app }, uri: string) => {
  const [row] = await app.sql`SELECT redirect_uri FROM oauth_codes`;
  expect(row.redirect_uri).toBe(uri);
});

Then("no code is issued", async ({ app }) => {
  const [{ count }] = await app.sql`SELECT count(*)::int AS count FROM oauth_codes`;
  expect(count).toBe(0);
});

const backLink = (page: Page) => page.getByRole("link", { name: /^Go back to / });

Then("the page links back to {string} carrying:", async ({ page }, uri: string, table: DataTable) => {
  const href = (await backLink(page).getAttribute("href")) ?? "";
  expect(href).toMatch(new RegExp(`^${RegExp.escape(uri)}\\?`));
  const params = new URL(href).searchParams;
  for (const [key, value] of table.raw()) {
    if (value === "(none)") expect(params.has(key), key).toBe(false);
    else if (value === "(words)") expect(params.get(key)?.length ?? 0).toBeGreaterThan(0);
    else expect(params.get(key), key).toBe(value);
  }
});

Then("the page names the error its link carries", async ({ page }) => {
  const params = new URL((await backLink(page).getAttribute("href")) ?? "").searchParams;
  await expect(page.locator("main")).toContainText(`${params.get("error_description")} (${params.get("error")}).`);
});

Then("the page's link back names the error {string}", async ({ page }, error: string) => {
  expect(new URL((await backLink(page).getAttribute("href")) ?? "").searchParams.get("error")).toBe(error);
});

Then("the page's link back describes the error as {string}", async ({ page }, text: string) => {
  expect(new URL((await backLink(page).getAttribute("href")) ?? "").searchParams.get("error_description")).toBe(text);
});

Then("the page's content security policy holds directives starting:", async ({ page }, table: DataTable) => {
  const response = await page.request.get(page.url(), { maxRedirects: 0 });
  const policy = (response.headers()["content-security-policy"] ?? "").split(";").map((part) => part.trim());
  for (const [prefix] of table.raw())
    expect(
      policy.some((part) => part.startsWith(prefix)),
      prefix,
    ).toBe(true);
});

Given("I signed out but keep a copy of my session cookie", async ({ context, http }) => {
  const cookie = (await context.cookies()).find(({ name }) => name === "admin.session");
  await http.send("POST", "/admin/sign-out", { form: { _csrf_token: await http.csrf() } });
  await context.clearCookies();
  if (cookie) await context.addCookies([cookie]);
});

Then("the answer sends me to the authorization the client {string} asks for", async ({ app, http }, name: string) => {
  const expected = await pathFor(app.sql, app.url, name);
  expect(http.last?.headers().location).toMatch(new RegExp(`(^|//[^/]+)${RegExp.escape(expected)}$`));
});

When("I press {string} on the authorization page", async ({ page }, button: string) => {
  await page.getByRole("button", { exact: true, name: button }).click();
  await page.waitForURL(/\/callback\?/);
});

When("I Tab to {string} on the authorization page and press Enter", async ({ page }, label: string) => {
  let ringed = false;
  for (let step = 0; step < 10; step++) {
    await page.keyboard.press("Tab");
    const focused = await page.evaluate(() => {
      const active = document.activeElement as HTMLElement;
      const style = getComputedStyle(active);
      const outline = style.outlineStyle !== "none" && Number.parseFloat(style.outlineWidth) > 0;
      return { ring: outline || style.boxShadow !== "none", text: active.textContent?.trim() };
    });
    if (focused.text === label) {
      ringed = focused.ring;
      break;
    }
  }
  expect(ringed, `${label} shows a focus ring`).toBe(true);
  await page.keyboard.press("Enter");
  await page.waitForURL(/\/callback\?/);
});

Then("the browser lands on the redirect URI with {string}", async ({ page }, param: string) => {
  expect(page.url()).toMatch(new RegExp(`/callback\\?.*\\b${RegExp.escape(param)}`));
});

When("I submit the authorization page with a forged CSRF token", async ({ page }) => {
  await page.evaluate(() => {
    const form = document.querySelector<HTMLFormElement>("form[method='post'][action='/oauth/authorize']");
    const token = form?.querySelector<HTMLInputElement>("input[name='_csrf_token']");
    if (token) token.value = "forged";
    form?.submit();
  });
  await page.getByRole("heading", { name: "Form expired" }).waitFor();
});
