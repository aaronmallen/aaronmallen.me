import { type APIRequestContext, expect, type Page } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { connectGitHub, insertCommit, insertPullRequest, linkTask } from "../support/commits.ts";
import { settle } from "../support/mail_sync.ts";
import { Before, Given, Then, When } from "../support/world.ts";

const ids: Record<string, number> = {};

Before(() => {
  for (const name of Object.keys(ids)) delete ids[name];
});
const pathFor = (kind: string, name: string) => `/${kind === "commit" ? "commits" : "pull_requests"}/${ids[name]}`;
const pagePathFor = (kind: string, name: string) =>
  `/admin/${kind === "commit" ? "commits" : "pull-requests"}/${ids[name]}`;

const animations = (page: Page) =>
  page.evaluate(() =>
    document
      .getAnimations()
      .filter((animation) => animation.constructor.name === "CSSAnimation")
      .map((animation) => (animation as CSSAnimation).animationName),
  );

const trusted = (value: unknown): unknown => {
  if (Array.isArray(value)) return value.map(trusted);
  if (value && typeof value === "object") {
    const hash = value as Record<string, unknown>;
    if (hash.untrusted === true) return hash.text;
    return Object.fromEntries(Object.entries(hash).map(([key, inner]) => [key, trusted(inner)]));
  }
  return value;
};

const mcpText = (body: string) => {
  const json = body.trimStart().startsWith("{") ? body : (body.match(/^data: (.*)$/m)?.[1] ?? "{}");
  return JSON.parse(JSON.parse(json).result.content[0].text);
};

Given("a commit {string} with:", async ({ app }, name: string, table: DataTable) => {
  ids[name] = await insertCommit(app.sql, table.rowsHash());
});

Given("a pull request {string} with:", async ({ app }, name: string, table: DataTable) => {
  ids[name] = await insertPullRequest(app.sql, table.rowsHash());
});

Given("the commit {string} links to the task {string}", async ({ app }, name: string, task: string) => {
  await linkTask(app.sql, "commit", ids[name], task);
});

Given("the pull request {string} links to the task {string}", async ({ app }, name: string, task: string) => {
  await linkTask(app.sql, "pull_request", ids[name], task);
});

Given("GitHub holds a token for the commit import", async ({ app }) => {
  await connectGitHub(app.sql);
});

When("I open the commit page for {string}", async ({ page }, name: string) => {
  await page.goto(pagePathFor("commit", name));
});

When("I open the pull request page for {string}", async ({ page }, name: string) => {
  await page.goto(pagePathFor("pull_request", name));
});

async function readThroughApi(request: APIRequestContext, token: string | undefined, path: string) {
  const response = await request.get(`/api/v1${path}`, { headers: { Authorization: `Bearer ${token}` } });
  return { body: await response.text(), status: response.status() };
}

async function readBoth(
  request: APIRequestContext,
  tokens: { api?: string; mcp?: string },
  path: string,
  id: number,
  tool: string,
) {
  const api = await readThroughApi(request, tokens.api, path);
  const mcp = await request.post("/mcp", {
    data: { id: 1, jsonrpc: "2.0", method: "tools/call", params: { arguments: { id }, name: tool } },
    headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${tokens.mcp}` },
  });
  expect(trusted(mcpText(await mcp.text()))).toEqual(JSON.parse(api.body));
}

When("I read the commit {string} through the API", async ({ answer, request, tokens }, name: string) => {
  Object.assign(answer, await readThroughApi(request, tokens.api, pathFor("commit", name)));
});

When("I read the pull request {string} through the API", async ({ answer, request, tokens }, name: string) => {
  Object.assign(answer, await readThroughApi(request, tokens.api, pathFor("pull_request", name)));
});

Then(
  "the API read of the commit {string} matches the MCP tool {string}, less the untrusted marks",
  ({ request, tokens }, name: string, tool: string) =>
    readBoth(request, tokens, pathFor("commit", name), ids[name], tool),
);

Then(
  "the API read of the pull request {string} matches the MCP tool {string}, less the untrusted marks",
  ({ request, tokens }, name: string, tool: string) =>
    readBoth(request, tokens, pathFor("pull_request", name), ids[name], tool),
);

Then("the GitHub record page at {string} answers with status {int}", async ({ page }, path: string, status: number) => {
  const response = await page.goto(path);

  expect(response?.status()).toBe(status);
});

Then("the GitHub record heads with {string}", async ({ page }, title: string) => {
  await expect(page.locator(".page-head h1")).toHaveText(title);
});

Then("the GitHub record kicker reads {string}", async ({ page }, text: string) => {
  await expect(page.locator(".page-head-kicker")).toHaveText(text);
});

Then("the GitHub record subline reads {string}", async ({ page }, text: string) => {
  await expect(page.locator(".page-head-sub")).toHaveText(text);
});

Then("the GitHub record stats read {string}", async ({ page }, text: string) => {
  const stats = await page
    .locator(".stat")
    .evaluateAll((nodes) =>
      nodes.map(
        (node) => `${node.querySelector(".stat-key")?.textContent} ${node.querySelector(".stat-value")?.textContent}`,
      ),
    );

  expect(stats.join(", ")).toBe(text);
});

Then("the GitHub record body shows the {word} items {string}", async ({ page }, tag: string, text: string) => {
  expect((await page.locator(`.commit-body ${tag}`).allTextContents()).join(", ")).toBe(text);
});

Then("the GitHub record body links {string} to {string}", async ({ page }, name: string, href: string) => {
  await expect(page.locator(".commit-body").getByRole("link", { name })).toHaveAttribute("href", href);
});

Then("the GitHub record body shows no image {string}", async ({ page }, src: string) => {
  await expect(page.locator(`.commit-body img[src="${src}"]`)).toHaveCount(0);
});

Then("the GitHub record body shows the image {string} as {string}", async ({ page }, src: string, alt: string) => {
  await expect(page.locator(`.commit-body img[src="${src}"][alt="${alt}"]`)).toHaveCount(1);
});

Then("the GitHub record says {string}", async ({ page }, text: string) => {
  await expect(page.locator(".g-main .empty")).toHaveText(text);
});

Then("the GitHub record links back to the activity", async ({ page }) => {
  await expect(page.getByRole("link", { name: "Activity" })).toHaveAttribute("href", "/admin/activity");
});

Then("the GitHub record links to {string}", async ({ page }, href: string) => {
  await expect(page.locator(`a[href="${href}"]`)).toHaveCount(1);
});

Then("the GitHub record lists the linked task {string} beside it", async ({ page }, title: string) => {
  await expect(page.locator(".g-main > .card + aside > .record-links")).toContainText(title);
});

When("I hold the commit import form", async ({ page }) => {
  await page.evaluate(() =>
    document.querySelector("[data-commits-import]")?.addEventListener("submit", (event) => event.preventDefault()),
  );
});

When("I force the disabled commit import", async ({ page }) => {
  await page.evaluate(() =>
    document.querySelectorAll<HTMLButtonElement>("[data-commits-import] button").forEach((button) => {
      button.disabled = false;
    }),
  );
  await page.getByRole("button", { name: "Import now" }).click();
});

Then("nothing on the page animates for the commit import", async ({ page }) => {
  await expect.poll(() => animations(page)).toEqual([]);
});

Then("only the commit import icon spins", async ({ page }) => {
  expect(await animations(page)).toEqual(["spin"]);
});

Then("the commit import button reads {string} and is disabled", async ({ page }, name: string) => {
  await expect(page.getByRole("button", { name })).toBeDisabled();
});

Then("the commit import button reads {string} and is enabled", async ({ page }, name: string) => {
  await expect(page.getByRole("button", { name })).toBeEnabled();
});

Then("no commit import button reads {string}", async ({ page }, name: string) => {
  await expect(page.getByRole("button", { name, exact: true })).toHaveCount(0);
});

Then("the commit card shows no commits", async ({ page }) => {
  await expect(page.locator(".commit-message")).toHaveCount(0);
});

Then("I am back on Today after the commit import", async ({ page }) => {
  await expect(page).toHaveURL(/\/admin\/?$/);
});

Then(
  "a commit import posted to {string} {word} answers with status {int}",
  async ({ page, request }, path: string, who: string, status: number) => {
    const response = await (who === "signed-in" ? page.request : request).post(path, { maxRedirects: 0 });

    expect(response.status()).toBe(status);
  },
);

Then("no commit import reaches GitHub", async ({ app, stub }) => {
  await settle(app);

  expect(stub.received("POST", "/github/api/graphql")).toEqual([]);
});
