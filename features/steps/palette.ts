import { type APIResponse, expect, type Page } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { ownerEmail } from "../support/stub.ts";
import { Before, Given, Then, When } from "../support/world.ts";

type Hit = Record<string, unknown>;

const unsearched = () => ({ headers: {} as Record<string, string>, hits: [] as Hit[], status: 0, text: "" });

let searched = unsearched();

Before(() => {
  searched = unsearched();
});

const keep = async (response: APIResponse) => {
  const text = await response.text();
  let hits: Hit[] = [];
  try {
    hits = JSON.parse(text).hits ?? [];
  } catch {}
  searched = { headers: response.headers(), hits, status: response.status(), text };
};

const searchPath = (text: string) => `/admin/search/palette?${new URLSearchParams({ q: text })}`;

const hitsOf = (kind: string) => searched.hits.filter((hit) => hit.kind === kind);

const query = (page: Page) => page.locator("[data-palette-query]");

const picked = (page: Page) =>
  page.evaluate(() => document.querySelector("[data-palette-option][aria-selected='true']")?.id ?? null);

const shut = async (page: Page) => {
  await expect(page.locator("dialog#command-palette[open]")).toHaveCount(0);
  await page.evaluate(() => new Promise((done) => requestAnimationFrame(() => setTimeout(done))));
};

const theme = (page: Page) =>
  page.evaluate(
    () =>
      document.documentElement.dataset.siteTheme ??
      (matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"),
  );

const near = (values: number[], to = values[0]) => values.every((value) => Math.abs(value - to) <= 1);

const box = (page: Page, selector: string) =>
  page
    .locator(selector)
    .first()
    .evaluate((node) => {
      const { height, width } = node.getBoundingClientRect();
      return { height, width };
    });

const switcherColumns = (page: Page) =>
  page.locator("#nav-switcher > .switcher-side").evaluateAll((sides) =>
    sides.map((side) =>
      [...side.querySelectorAll(".switcher-column")].map((column) => {
        const { bottom, left, top, width } = column.getBoundingClientRect();
        return { bottom, left, top, width };
      }),
    ),
  );

Given("a palette task {string} in progress", async ({ app }, title: string) => {
  await app.sql`
    INSERT INTO sprints (sprint_date) VALUES ((now() AT TIME ZONE 'America/Chicago')::date) ON CONFLICT DO NOTHING
  `;
  const [{ id }] = await app.sql`
    INSERT INTO tasks (title, position, sprint_id, status)
    SELECT ${title}, coalesce(max(position), 0) + 1, (SELECT max(id) FROM sprints), 'in_progress' FROM tasks
    RETURNING id
  `;
  await app.sql`INSERT INTO work_sessions (task_id, started_at) VALUES (${id}, now() - interval '10 minutes')`;
});

When("I search the palette for {string}", async ({ context }, text: string) => {
  await keep(await context.request.get(searchPath(text), { headers: { Accept: "application/json" }, maxRedirects: 0 }));
});

When("I search the palette for {string} with only the API token", async ({ app, playwright, tokens }, text: string) => {
  const request = await playwright.request.newContext({ baseURL: app.url });
  await keep(
    await request.get(searchPath(text), {
      headers: { Accept: "application/json", Authorization: `Bearer ${tokens.api}` },
      maxRedirects: 0,
    }),
  );
  await request.dispose();
});

When("I sign in to the admin through GitHub", async ({ app, page }) => {
  await app.sql`INSERT INTO owner_identities (email) VALUES (${ownerEmail}) ON CONFLICT DO NOTHING`;
  await page.goto("/admin/sign-in");
  await page.getByRole("button", { name: /GitHub/ }).click();
  await page.waitForURL((url) => url.pathname !== "/admin/sign-in" && !url.pathname.includes("/auth/"));
});

Then("the palette search answers {int}", ({}, status: number) => {
  expect(searched.status, searched.text).toBe(status);
});

Then("the palette search answers JSON that no cache keeps", ({}) => {
  expect(searched.headers["content-type"]).toMatch(/^application\/json/);
  expect(searched.headers["cache-control"]).toBe("private, no-store");
});

Then("the palette search finds nothing", ({}) => {
  expect(searched.hits).toEqual([]);
});

Then("the palette search finds {int} hits", ({}, count: number) => {
  expect(searched.hits).toHaveLength(count);
});

Then("the palette search finds the kinds {string}, in any order", ({}, kinds: string) => {
  expect(searched.hits.map((hit) => hit.kind).sort()).toEqual(kinds.split(", ").sort());
});

Then("the palette search finds hits of each kind {string}", ({}, kinds: string) => {
  for (const kind of kinds.split(", ")) expect(hitsOf(kind).length, kind).toBeGreaterThan(0);
});

Then("the palette search finds one {word} hit holding:", ({}, kind: string, json: string) => {
  expect(hitsOf(kind)).toHaveLength(1);
  expect(hitsOf(kind)[0]).toMatchObject(JSON.parse(json));
});

Then("the palette search's {word} hit leads to {string}", ({}, kind: string, href: string) => {
  expect(hitsOf(kind)).toHaveLength(1);
  expect(hitsOf(kind)[0].href).toBe(href);
});

Then("the palette search's {word} hit quotes {string}", ({}, kind: string, text: string) => {
  expect(String(hitsOf(kind)[0]?.match)).toContain(text);
});

Then("the palette search's first hit holds:", ({}, json: string) => {
  expect(searched.hits[0]).toMatchObject(JSON.parse(json));
});

Then("the palette search answer leaves out {string}", ({}, text: string) => {
  expect(searched.text).not.toContain(text);
});

Then("the palette rows under {string} have the ids:", async ({ page }, selector: string, table: DataTable) => {
  const ids = await page.locator(`${selector} [data-palette-option]`).evaluateAll((rows) => rows.map((row) => row.id));

  expect(ids).toEqual(table.raw().map(([id]) => id));
});

Then("the palette carries the page's CSRF token", async ({ page }) => {
  const token = await page.locator("input[name='_csrf_token']").first().inputValue();

  expect(token).not.toBe("");
  expect(await page.locator("dialog#command-palette").getAttribute("data-palette-token")).toBe(token);
});

Then("the palette templates fetch from:", async ({ page }, table: DataTable) => {
  const sources = await page
    .locator("template[data-palette-from]")
    .evaluateAll((nodes) => nodes.map((node) => node.getAttribute("data-palette-from")));

  expect(sources).toEqual(table.raw().map(([source]) => source));
});

Then("the palette templates draw the rows:", async ({ page }, table: DataTable) => {
  const rows = await page.locator("template[data-palette-from]").evaluateAll((nodes) =>
    nodes.map((node) => {
      const row = (node as HTMLTemplateElement).content.querySelector("[data-palette-option]");
      return [
        row?.id ?? "",
        row?.querySelector(".pal-r-label")?.textContent?.trim() ?? "",
        row?.getAttribute("data-palette-text") ?? "",
        row?.hasAttribute("data-palette-post") ? "posts" : "links",
        row?.getAttribute("data-palette-needs") ?? "",
      ];
    }),
  );

  expect(rows).toEqual(table.rows());
});

When("I type {string} in the palette", async ({ page }, text: string) => {
  await expect(page.locator("dialog#command-palette[open]")).toHaveCount(1);
  await query(page).pressSequentially(text);
});

When("I click the palette row {string}", async ({ page }, id: string) => {
  await page.locator(`#${id}`).click();
});

When("I click the palette row reading {string}", async ({ page }, text: string) => {
  await page.locator(".pal-r", { hasText: text }).click();
});

When("I hover the palette row {string} once the palette settles", async ({ page }, id: string) => {
  await expect(page.locator("[data-palette-list][aria-busy]")).toHaveCount(0);
  await page.locator(`#${id}`).hover();
});

When("I click the admin window at {int}, {int}", async ({ page }, x: number, y: number) => {
  await page.mouse.click(x, y);
});

When("I tap the top bar search button", async ({ page }) => {
  await page.locator("button.top-bar-search").click();
});

When("the palette closes", async ({ page }) => {
  await expect(page.locator("dialog[data-palette][open]")).toHaveCount(0);
});

Then("the palette picks {string}", async ({ page }, id: string) => {
  await expect.poll(() => picked(page)).toBe(id);
});

Then("the palette query box has the focus", async ({ page }) => {
  await expect(query(page)).toBeFocused();
  await expect(query(page)).toHaveAttribute("role", "combobox");
});

Then("the palette query box shows a ring", async ({ page }) => {
  const ringed = await query(page).evaluate((node) => {
    const style = getComputedStyle(node);
    return style.outlineStyle !== "none" && Number.parseFloat(style.outlineWidth) > 0;
  });

  expect(ringed).toBe(true);
});

Then("the palette query box stands at least {int}px tall", async ({ page }, height: number) => {
  expect((await box(page, "[data-palette-query]")).height).toBeGreaterThanOrEqual(height);
});

Then("the palette groups run:", async ({ page }, table: DataTable) => {
  const names = await page
    .locator("#command-palette [data-palette-group]")
    .evaluateAll((groups) =>
      groups.map((group) =>
        (group.getAttribute("aria-labelledby") ?? "")
          .replace(/^command-palette-(group-)?/, "")
          .replace(/^kind-.+/, "records"),
      ),
    );

  expect([...new Set(names)]).toEqual(table.raw().map(([name]) => name));
});

Then("the palette lists {string} above {string}", async ({ page }, first: string, second: string) => {
  await expect(page.locator(".pal-r", { hasText: second }).first()).toBeVisible();
  const rows = await page.locator(".pal-r").allTextContents();

  expect(rows.findIndex((row) => row.includes(first))).toBeGreaterThan(-1);
  expect(rows.findIndex((row) => row.includes(first))).toBeLessThan(rows.findIndex((row) => row.includes(second)));
});

Then("the palette shows {int} rows reading {string}", async ({ page }, count: number, text: string) => {
  await expect(page.locator(".pal-r", { hasText: text })).toHaveCount(count);
});

Then("the last two palette rows are {string} and {string}", async ({ page }, first: string, second: string) => {
  const ids = await page.locator(".pal-r").evaluateAll((rows) => rows.map((row) => row.id));

  expect(ids.slice(-2)).toEqual([first, second]);
});

Then("the palette row {string} is labelled {string}", async ({ page }, title: string, sub: string) => {
  await expect(page.locator(".pal-r", { hasText: title }).locator(".pal-r-sub")).toHaveText(sub);
});

Then("the create task dialog's title holds {string}", async ({ page }, title: string) => {
  await expect(page.locator("dialog#task-create[open] [name='task[title]']")).toHaveValue(title);
});

When(
  "I save the create task dialog as {string} on the {string} list",
  async ({ page }, title: string, list: string) => {
    const dialog = page.locator("dialog#task-create");
    await dialog.locator("[name='task[title]']").fill(title);
    await dialog.locator("[name='task[list]']").selectOption({ label: list });
    await dialog.getByRole("button", { exact: true, name: "Create task" }).click();
  },
);

Then("running Toggle theme from the palette flips the theme each time", async ({ page }) => {
  const run = async () => {
    await page.keyboard.press("Meta+/");
    await expect(page.locator("dialog#command-palette[open]")).toHaveCount(1);
    await query(page).pressSequentially("toggle theme");
    await page.keyboard.press("Enter");
    await shut(page);
    return theme(page);
  };
  const start = await theme(page);
  const first = await run();
  const second = await run();

  expect(first).not.toBe(start);
  expect(second).not.toBe(first);
});

Then("the top bar search button measures at least {int}px each way", async ({ page }, size: number) => {
  const { height, width } = await box(page, ".top-bar-search");

  expect(width).toBeGreaterThanOrEqual(size);
  expect(height).toBeGreaterThanOrEqual(size);
});

Then("the top bar search button is {int}px wide", async ({ page }, width: number) => {
  expect(near([(await box(page, ".top-bar-search")).width], width)).toBe(true);
});

Given("the admin window is {int} by {int}", async ({ page }, width: number, height: number) => {
  await page.setViewportSize({ height, width });
});

When("I open the switcher", async ({ page }) => {
  await page.locator("button.switcher").click();
  await expect(page.locator("#nav-switcher:popover-open")).toHaveCount(1);
});

Then("the switcher panel is shut", async ({ page }) => {
  await expect(page.locator("#nav-switcher:popover-open")).toHaveCount(0);
});

Then("the switcher reports itself {word}", async ({ page }, state: string) => {
  const cdp = await page.context().newCDPSession(page);
  const { root } = await cdp.send("DOM.getDocument");
  const { nodeId } = await cdp.send("DOM.querySelector", { nodeId: root.nodeId, selector: "button.switcher" });
  const { nodes } = await cdp.send("Accessibility.getPartialAXTree", { fetchRelatives: false, nodeId });
  const expanded = nodes[0].properties?.find(({ name }) => name === "expanded")?.value.value;
  await cdp.detach();

  expect(expanded).toBe(state === "open");
});

Then("the top bar stands {int}px tall", async ({ page }, height: number) => {
  expect(near([(await box(page, ".top-bar")).height], height)).toBe(true);
});

Then("the wordmark reads {string}", async ({ page }, text: string) => {
  expect((await page.locator("a.wordmark").innerText()).split(/\s+/).join("")).toBe(text);
});

Then("the wordmark's font size is {string}", async ({ page }, size: string) => {
  expect(await page.locator("a.wordmark").evaluate((node) => getComputedStyle(node).fontSize)).toBe(size);
});

Then("each switcher side keeps one column", async ({ page }) => {
  const sides = await switcherColumns(page);

  expect(sides).toHaveLength(2);
  expect(sides.map((side) => near(side.map(({ left }) => left)))).toEqual([true, true]);
});

Then("each switcher group sits {int}px under the one above it", async ({ page }, gap: number) => {
  const sides = await switcherColumns(page);
  const gaps = sides.flatMap((side) => side.slice(1).map((below, at) => below.top - side[at].bottom));

  expect(gaps.length).toBeGreaterThan(0);
  expect(near(gaps, gap), gaps.join(", ")).toBe(true);
});

Then("today is as wide as the switcher groups under it", async ({ page }) => {
  const [left] = await switcherColumns(page);

  expect(near(left.map(({ width }) => width))).toBe(true);
});

Then(
  "with scripts off at {int} by {int}, the switcher opens and follows {string} to {string}",
  async ({ app, browser, owner }, width: number, height: number, link: string, path: string) => {
    const context = await browser.newContext({
      baseURL: app.url,
      bypassCSP: true,
      javaScriptEnabled: false,
      viewport: { height, width },
    });
    await context.addCookies(owner.cookies);
    const page = await context.newPage();
    await page.goto("/admin");
    await page.locator("button.switcher").click();
    await expect(page.locator("#nav-switcher:popover-open")).toHaveCount(1);
    await page.locator("#nav-switcher").getByRole("link", { exact: true, name: link }).click();
    await expect.poll(() => new URL(page.url()).pathname).toBe(path);
    await context.close();
  },
);

When("I follow {string} in the switcher", async ({ page }, name: string) => {
  await page.locator("#nav-switcher").getByRole("link", { exact: true, name }).click();
});

When("I open the palette again", async ({ page }) => {
  await page.keyboard.press("Escape");
  await shut(page);
  await page.keyboard.press("Meta+/");
  await expect(page.locator("dialog#command-palette[open]")).toHaveCount(1);
});

Then("the switcher sides name the groups:", async ({ page }, table: DataTable) => {
  const sides = await page.locator("#nav-switcher > .switcher-side").evaluateAll((nodes) =>
    nodes.map((side) =>
      [...side.querySelectorAll(".switcher-column")]
        .map((column) => {
          const heading = column.querySelector(".switcher-heading");
          return ((heading ? heading.firstChild : column)?.textContent ?? "").trim();
        })
        .join(", "),
    ),
  );

  expect(sides).toEqual(table.raw().map(([side]) => side));
});
