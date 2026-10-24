import { expect, type Page } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import type postgres from "postgres";
import { fill } from "../support/analytics.ts";
import { filled } from "../support/api.ts";
import { dayOf, zoned } from "../support/calendar.ts";
import { sprintId } from "../support/tasks.ts";
import { Given, Then, type test, When } from "../support/world.ts";

type World = Parameters<Parameters<typeof test>[2]>[0];

const marked = async (sql: postgres.Sql, text: string) => fill(await filled(sql, text));

const spaced = (text: string | null | undefined) => (text ?? "").replaceAll(/\s+/g, " ").trim();

// Reads a table cell as a column value: none is null, now is this instant, "now - 90" is 90 seconds back,
// "2026-10-03 09:00" is that wall clock in the owner's zone, and {task:Title} names a task's ID.
async function cell(sql: postgres.Sql, text: string) {
  if (text === "none") return null;
  const value = await marked(sql, text);
  const ago = /^now(?:\s*-\s*(\d+))?$/.exec(value);
  if (ago) return new Date(Date.now() - Number(ago[1] ?? 0) * 1000);
  const clock = /^(\d{4}-\d\d-\d\d) (\d\d:\d\d)$/.exec(value);
  if (clock) return zoned(clock[1], clock[2]);
  return value;
}

Given("the {word} table holds the rows:", async ({ app }, table: string, data: DataTable) => {
  for (const given of data.hashes()) {
    const row: Record<string, unknown> = {};
    for (const [column, value] of Object.entries(given)) if (value !== "") row[column] = await cell(app.sql, value);
    await app.sql`INSERT INTO ${app.sql(table)} ${app.sql(row)}`;
  }
});

async function token(page: Page) {
  const field = page.locator("input[name='_csrf_token']").first();
  if (!(await field.count())) await page.goto("/admin/tasks?filter=next");
  return field.inputValue();
}

async function send(
  { app, http, page }: Pick<World, "app" | "http" | "page">,
  path: string,
  pairs: string[][],
  headers: Record<string, string> = {},
) {
  const form = new URLSearchParams({ _csrf_token: await token(page) });
  for (const [key, value] of pairs) form.append(key, (await marked(app.sql, value)).replace(/^"(.*)"$/, "$1"));
  const response = await page.request.post(await marked(app.sql, path), {
    data: form.toString(),
    headers: { "Content-Type": "application/x-www-form-urlencoded", ...headers },
    maxRedirects: 0,
  });
  http.last = response;
  http.body = await response.text();
}

async function fetchPage(
  { app, http, page }: Pick<World, "app" | "http" | "page">,
  path: string,
  headers: Record<string, string> = {},
) {
  const response = await page.request.get(await marked(app.sql, path), { headers, maxRedirects: 0 });
  http.last = response;
  http.body = await response.text();
}

When("I send the admin form {string}", ({ app, http, page }, path: string) => send({ app, http, page }, path, []));

When("I send the admin form {string} with:", ({ app, http, page }, path: string, data: DataTable) =>
  send({ app, http, page }, path, data.raw()),
);

When("I send the admin form {string} from the drawer with:", ({ app, http, page }, path: string, data: DataTable) =>
  send({ app, http, page }, path, data.raw(), { "X-Drawer": "1" }),
);

When("I fetch the admin page {string}", ({ app, http, page }, path: string) => fetchPage({ app, http, page }, path));

When("I fetch the admin page {string} as JSON", ({ app, http, page }, path: string) =>
  fetchPage({ app, http, page }, path, { Accept: "application/json" }),
);

When("I fetch the admin page {string} for the drawer", ({ app, http, page }, path: string) =>
  fetchPage({ app, http, page }, path, { "X-Drawer": "1" }),
);

When("I follow the admin answer", async ({ answer, page }) => {
  answer.status = (await page.goto(answer.headers?.location ?? ""))?.status() ?? 0;
});

When("I look at the admin answer", async ({ answer, page }) => {
  await page.route("**/__answer", (route) =>
    route.fulfill({ body: answer.body.replaceAll(/<script\b[\s\S]*?<\/script>/g, ""), contentType: "text/html" }),
  );
  await page.goto("/__answer");
});

Then("the admin answer goes to {string}", async ({ answer, app }, path: string) => {
  expect(answer.status, answer.body).toBe(302);
  expect(answer.headers?.location).toBe(await marked(app.sql, path));
});

Then("the admin answer goes to a page starting {string}", async ({ answer, app }, path: string) => {
  expect(answer.headers?.location).toMatch(new RegExp(`^${RegExp.escape(await marked(app.sql, path))}`));
});

Then("the answer does not show {string}", ({ answer }, text: string) => {
  expect(answer.body).not.toContain(text);
});

Then("the answer header {string} is {string}", ({ answer }, name: string, value: string) => {
  expect(answer.headers?.[name.toLowerCase()]).toBe(value);
});

Then("the admin answer holds:", async ({ answer, app }, json: string) => {
  expect(JSON.parse(answer.body)).toMatchObject(JSON.parse(await marked(app.sql, json)));
});

Then("the admin answer is:", async ({ answer, app }, json: string) => {
  expect(JSON.parse(answer.body)).toEqual(JSON.parse(await marked(app.sql, json)));
});

const part = async ({ app, page }: Pick<World, "app" | "page">, selector: string) =>
  page.locator(await marked(app.sql, selector));

Then("the page shows the part {string}", async ({ app, page }, selector: string) => {
  await expect((await part({ app, page }, selector)).first()).toBeVisible();
});

Then("the page hides {string}", async ({ app, page }, selector: string) => {
  await expect((await part({ app, page }, selector)).first()).toBeHidden();
});

Then("the page part {string} reads {string}", async ({ app, page }, selector: string, text: string) => {
  const found = (await part({ app, page }, selector)).first();
  await expect.poll(async () => spaced(await found.textContent())).toBe(await marked(app.sql, text));
});

Then("the page part {string} holds {string}", async ({ app, page }, selector: string, text: string) => {
  const found = (await part({ app, page }, selector)).first();
  await expect.poll(async () => spaced(await found.textContent())).toContain(await marked(app.sql, text));
});

Then("the page parts {string} read {string}", async ({ app, page }, selector: string, texts: string) => {
  const found = await part({ app, page }, selector);
  const wanted = texts ? (await marked(app.sql, texts)).split(" | ") : [];
  await expect
    .poll(async () => (await found.evaluateAll((nodes) => nodes.map((node) => node.textContent))).map(spaced))
    .toEqual(wanted);
});

Then(
  "the page part {string} has {string} set to {string}",
  async ({ app, page }, selector: string, name: string, value: string) => {
    await expect((await part({ app, page }, selector)).first()).toHaveAttribute(name, await marked(app.sql, value));
  },
);

Then("the page parts {string} have {string} set to {string}", async ({ app, page }, selector, name, values: string) => {
  const found = await part({ app, page }, selector);
  const wanted = values ? (await marked(app.sql, values)).split(" | ") : [];
  await expect
    .poll(() => found.evaluateAll((nodes, key) => nodes.map((node) => node.getAttribute(key)), name))
    .toEqual(wanted);
});

Then("the page field {string} holds {string}", async ({ app, page }, selector: string, value: string) => {
  await expect((await part({ app, page }, selector)).first()).toHaveValue(await marked(app.sql, value));
});

Then("the page box {string} is ticked", async ({ app, page }, selector: string) => {
  await expect((await part({ app, page }, selector)).first()).toBeChecked();
});

Then("the page box {string} is not ticked", async ({ app, page }, selector: string) => {
  await expect((await part({ app, page }, selector)).first()).not.toBeChecked();
});

When("I keep the page", async ({ page }) => {
  await page.evaluate(() => {
    (window as unknown as { kept: boolean }).kept = true;
  });
});

Then("the page did not load again", async ({ page }) => {
  expect(await page.evaluate(() => (window as unknown as { kept?: boolean }).kept === true)).toBe(true);
});

Then("the page loaded again", async ({ page }) => {
  await expect.poll(() => page.evaluate(() => (window as unknown as { kept?: boolean }).kept === true)).toBe(false);
});

When("I click {string} in {string}", async ({ app, page }, name: string, selector: string) => {
  const scope = (await part({ app, page }, selector)).first();
  await scope.hover();
  await scope.getByRole("button", { name }).or(scope.getByRole("link", { name })).first().click();
});

When("I click the page part {string}", async ({ app, page }, selector: string) => {
  await (await part({ app, page }, selector)).first().click();
});

When("I hover the page part {string}", async ({ app, page }, selector: string) => {
  await (await part({ app, page }, selector)).first().hover();
});

When("I say yes to the question", async ({ page }) => {
  await page.locator("[data-confirm-accept]").click();
});

When("I say no to the question", async ({ page }) => {
  await page.locator("[data-confirm-decline]").click();
});

Then("the question reads {string}", async ({ app, page }, text: string) => {
  await expect(page.locator("[data-confirm-ask]")).toContainText(await marked(app.sql, text));
});

Then("the database soon holds {string} for:", async ({ app }, wanted: string, query: string) => {
  await expect
    .poll(async () => {
      const rows = await app.sql.unsafe(await filled(app.sql, query)).values();
      return rows.map((row) => row.join(", ")).join("\n");
    })
    .toBe((await marked(app.sql, wanted)).replaceAll("\\n", "\n"));
});

When("I set the page field {string} to {string}", async ({ app, page }, selector: string, value: string) => {
  await (await part({ app, page }, selector)).first().fill(await marked(app.sql, value));
});

When("I tick the page box {string}", async ({ app, page }, selector: string) => {
  await (await part({ app, page }, selector)).first().check();
});

When("I untick the page box {string}", async ({ app, page }, selector: string) => {
  await (await part({ app, page }, selector)).first().uncheck();
});

When("I pick {string} in the page select {string}", async ({ app, page }, label: string, selector: string) => {
  await (await part({ app, page }, selector)).first().selectOption({ label });
});

const row = (page: Page, title: string) =>
  page
    .locator(".task")
    .filter({ has: page.locator(".task-title", { hasText: new RegExp(`^${RegExp.escape(title)}$`) }) })
    .first();

Given("the window is {int} by {int}", async ({ page }, width: number, height: number) => {
  await page.setViewportSize({ height, width });
});

When("I open the task {string} in the drawer", async ({ page }, title: string) => {
  await page
    .locator(".task-title", { hasText: new RegExp(`^${RegExp.escape(title)}$`) })
    .first()
    .click();
  const panel = page.locator("dialog#task-panel[open]");
  await expect(panel.locator("h1")).toHaveText(title);
  await panel.evaluate((node) => Promise.all(node.getAnimations({ subtree: true }).map((run) => run.finished)));
});

When("I scroll {string} to {int}", async ({ app, page }, selector: string, top: number) => {
  await (await part({ app, page }, selector)).first().evaluate((node, to) => node.scrollTo(0, to), top);
});

When("I scroll {string} to the bottom", async ({ app, page }, selector: string) => {
  await (await part({ app, page }, selector)).first().evaluate((node) => node.scrollTo(0, node.scrollHeight));
});

When("I scroll the window to {int}", async ({ page }, top: number) => {
  await page.evaluate((to) => window.scrollTo(0, to), top);
});

const edge = async (page: Page, selector: string, side: "bottom" | "top") =>
  selector === "the window"
    ? side === "top"
      ? 0
      : page.evaluate(() => window.innerHeight)
    : page
        .locator(selector)
        .first()
        .evaluate((node, key) => node.getBoundingClientRect()[key], side);

Then(
  /^the (top|bottom) of "([^"]+)" lines up with the (top|bottom) of "([^"]+)"$/,
  async ({ page }, side: string, selector: string, otherSide: string, other: string) => {
    const wanted = await edge(page, other, otherSide as "bottom" | "top");
    expect(Math.abs((await edge(page, selector, side as "bottom" | "top")) - wanted)).toBeLessThanOrEqual(1);
  },
);

async function controls(page: Page, selector: string, within: string) {
  return page
    .locator(`${within} :is(${selector})`)
    .evaluateAll((nodes) =>
      nodes
        .filter((node) => (node as HTMLElement).checkVisibility())
        .map((node) => [node.getBoundingClientRect().width, node.getBoundingClientRect().height]),
    );
}

Then("every visible control in {string} is at least {int} pixels square", async ({ page }, within: string, side) => {
  const found = await controls(page, "a, button, summary", within);
  expect(found.length).toBeGreaterThan(0);
  for (const [width, height] of found) expect(Math.min(width, height)).toBeGreaterThanOrEqual(side);
});

Then(
  "at least {int} visible controls in {string} stand at least {int} pixels tall",
  async ({ page }, count: number, within: string, tall: number) => {
    const found = await controls(page, "a, button, summary", within);
    expect(found.length).toBeGreaterThanOrEqual(count);
    for (const [, height] of found) expect(height).toBeGreaterThanOrEqual(tall);
  },
);

Then("{string} does not scroll sideways", async ({ page }, selector: string) => {
  const node = selector === "the page" ? page.locator("html") : page.locator(selector).first();
  expect(await node.evaluate((found) => found.scrollWidth > found.clientWidth)).toBe(false);
});

When("I click {string} on the task row {string}", async ({ page }, name: string, title: string) => {
  const found = row(page, title);
  await found.hover();
  await found.getByRole("button", { exact: true, name }).first().click();
});

When("I complete the task row {string}", async ({ page }, title: string) => {
  const found = row(page, title);
  await found.hover();
  await found.locator("summary[aria-keyshortcuts='x']").click();
  await found.getByRole("button", { exact: true, name: "Done" }).click();
});

When("I press the keys {string}", async ({ page }, keys: string) => {
  for (const key of keys.split(" ")) await page.keyboard.press(key);
});

When("I press {string} on the task row {string}", async ({ page }, key: string, title: string) => {
  await row(page, title).locator(".task-title").focus();
  await page.keyboard.press(key);
});

Then("the task row {string} offers {string}", async ({ page }, title: string, name: string) => {
  const found = row(page, title);
  await found.hover();
  await expect(found.getByRole("button", { exact: true, name }).first()).toBeAttached();
});

Then("the task rows read {string}", async ({ page }, titles: string) => {
  await expect(page.locator(".task-title")).toHaveText(titles ? titles.split(", ") : []);
});

When("I tick the task {string}", async ({ page }, title: string) => {
  await row(page, title).locator("input[name='ids[]']").check();
});

When("I untick the task {string}", async ({ page }, title: string) => {
  await row(page, title).locator("input[name='ids[]']").uncheck();
});

type Gate = { answerHeld?: boolean; answered: number; arrived: number; held?: Promise<void>; release?: () => void };

const gates = new WeakMap<Page, Map<string, Gate>>();

async function gate(page: Page, path: string) {
  const all = gates.get(page) ?? new Map<string, Gate>();
  gates.set(page, all);
  const found = all.get(path) ?? { answered: 0, arrived: 0 };
  if (!all.has(path)) {
    all.set(path, found);
    await page.route(
      (url) => url.pathname === path,
      async (route) => {
        if (route.request().resourceType() === "eventsource") return route.continue();
        found.arrived += 1;
        if (!found.answerHeld) await found.held;
        const response = await route.fetch({ maxRedirects: 0 }).catch(() => null);
        if (!response) return route.abort().catch(() => {});
        if (found.answerHeld) await found.held;
        found.answered += 1;
        await route.fulfill({ response }).catch(() => {});
      },
    );
  }
  return found;
}

When("I count the requests to {string}", async ({ app, page }, path: string) => {
  await gate(page, await filled(app.sql, path));
});

When("I hold the requests to {string}", async ({ app, page }, path: string) => {
  const found = await gate(page, await filled(app.sql, path));
  found.held = new Promise((done) => {
    found.release = done;
  });
});

When("I let the held requests to {string} go", async ({ app, page }, path: string) => {
  const found = await gate(page, await filled(app.sql, path));
  found.release?.();
  found.held = undefined;
});

When("a request to {string} arrives", async ({ app, page }, path: string) => {
  const found = await gate(page, await filled(app.sql, path));
  await expect.poll(() => found.arrived).toBeGreaterThan(0);
});

Then(/^(\d+) requests? to "([^"]+)" came back$/, async ({ app, page }, count: string, path: string) => {
  const found = await gate(page, await filled(app.sql, path));
  await expect.poll(() => found.answered).toBe(Number(count));
});

Then(/^at least (\d+) requests? to "([^"]+)" came back$/, async ({ app, page }, count: string, path: string) => {
  const found = await gate(page, await filled(app.sql, path));
  await expect.poll(() => found.answered).toBeGreaterThanOrEqual(Number(count));
});

When("a live change to {string} reaches the page", async ({ app, page }, table: string) => {
  const heard = () => page.evaluate(() => Number(document.documentElement.dataset.liveHeard) || 0);
  const before = await heard();
  await expect
    .poll(
      async () => {
        await app.sql`SELECT pg_notify('admin_changes', ${table})`;
        return heard();
      },
      { intervals: [500], timeout: 15_000 },
    )
    .toBeGreaterThan(before);
});

When("the page settles", async ({ page }) => {
  await expect.poll(() => page.evaluate(() => document.documentElement.dataset.fetch ?? null)).toBeNull();
});

async function strokeOf(page: Page, title: string, below: string) {
  const grip = row(page, title).locator("[data-task-grip]");
  await row(page, title).hover();
  await grip.scrollIntoViewIfNeeded();
  const from = await grip.boundingBox();
  const to = await page.locator(".task", { hasText: below }).first().boundingBox();
  if (!from || !to) throw new Error("no box to drag between");
  const start = { x: from.x + from.width / 2, y: from.y + from.height / 2 };
  const end = to.y + to.height / 2 + 10;
  return Array.from({ length: 7 }, (_, step) => ({ x: start.x, y: start.y + ((end - start.y) * step) / 6 }));
}

When("I drag the task {string} below {string}", async ({ page }, title: string, below: string) => {
  const [start, ...steps] = await strokeOf(page, title, below);
  await page.mouse.move(start.x, start.y);
  await page.mouse.down();
  for (const point of steps) await page.mouse.move(point.x, point.y);
  await page.mouse.up();
});

When(
  /^I drag the task "([^"]+)" below "([^"]+)" with a finger(, and the browser cancels it)?$/,
  async ({ page }, title: string, below: string, canceled?: string) => {
    const [start, ...steps] = await strokeOf(page, title, below);
    const cdp = await page.context().newCDPSession(page);
    const touch = (type: string, point?: { x: number; y: number }) =>
      cdp.send("Input.dispatchTouchEvent", { touchPoints: point ? [point] : [], type });
    await touch("touchStart", start);
    for (const point of steps) await touch("touchMove", point);
    await touch(canceled ? "touchCancel" : "touchEnd");
  },
);

When(
  "I press {string} with the page scrolled and the button focused on the task row {string}",
  async ({ page }, name: string, title: string) => {
    const button = row(page, title).getByRole("button", { exact: true, name });
    await button.evaluate((node) => {
      (node as HTMLElement).focus();
      window.scrollTo(0, 120);
      Object.assign(window, { scrolled: window.scrollY });
      (node as HTMLElement).click();
    });
  },
);

Then("the page kept its scroll", async ({ page }) => {
  const kept = () =>
    page.evaluate(() => {
      const { scrolled } = window as unknown as { scrolled: number };
      return scrolled > 0 && window.scrollY === scrolled;
    });
  expect(await kept()).toBe(true);
});

Then("the focus sits in the task row {string}", async ({ page }, title: string) => {
  expect(await page.evaluate(() => document.activeElement?.closest(".task")?.textContent ?? "")).toContain(title);
});

When("the start form of the first task row submits", async ({ page }) => {
  await page
    .locator(".task form[data-task-act='start']")
    .first()
    .evaluate((form) => (form as HTMLFormElement).requestSubmit());
});

Then(
  "every page part {string} has {string} set to {string}",
  async ({ app, page }, selector: string, name: string, value: string) => {
    const found = await (await part({ app, page }, selector)).evaluateAll(
      (nodes, key) => nodes.map((node) => node.getAttribute(key)),
      name,
    );
    expect(found.length).toBeGreaterThan(0);
    expect(new Set(found)).toEqual(new Set([await marked(app.sql, value)]));
  },
);

Given("{int} more tasks on {word} called {string}", async ({ app }, count: number, list: string, title: string) => {
  const sprint = list === "today" ? await sprintId(app.sql, "today") : null;
  await app.sql`
    INSERT INTO tasks (title, list, sprint_id, number, position)
    SELECT ${title} || ' ' || n, ${sprint ? null : list}::task_list, ${sprint}::int, base.number + n, base.position + n
    FROM generate_series(1, ${count}) AS n,
      (SELECT coalesce(max(number), 0) AS number, coalesce(max(position), 0) AS position FROM tasks WHERE project_id IS NULL) AS base
  `;
});

Then("the page part {string} has a filled background", async ({ app, page }, selector: string) => {
  const fill = await (await part({ app, page }, selector))
    .first()
    .evaluate((node) => getComputedStyle(node).backgroundColor);
  expect(fill).not.toBe("rgba(0, 0, 0, 0)");
});

Then("the page part {string} is partly ticked", async ({ app, page }, selector: string) => {
  const found = (await part({ app, page }, selector)).first();
  expect(await found.evaluate((node) => (node as HTMLInputElement).indeterminate)).toBe(true);
});

When(
  "I send the admin form {string} for the tasks on {word} with:",
  async ({ app, http, page }, path: string, list: string, data: DataTable) => {
    const ids = await app.sql`SELECT id FROM tasks WHERE list = ${list} ORDER BY position`;
    await send({ app, http, page }, path, [...data.raw(), ...ids.map(({ id }) => ["ids[]", String(id)])]);
  },
);

When(
  "I send the admin form {string} with the task {string} ticked {int} times and:",
  async ({ app, http, page }, path: string, title: string, times: number, data: DataTable) => {
    const id = await filled(app.sql, `{task:${title}}`);
    await send({ app, http, page }, path, [...data.raw(), ...Array.from({ length: times }, () => ["ids[]", id])]);
  },
);

Given("the task {string} has the note:", async ({ app }, title: string, note: string) => {
  await app.sql`INSERT INTO tasks ${app.sql({
    list: "next",
    note,
    number: (await app.sql`SELECT coalesce(max(number), 0) + 1 AS n FROM tasks WHERE project_id IS NULL`)[0].n,
    position: (await app.sql`SELECT coalesce(max(position), 0) + 1 AS n FROM tasks`)[0].n,
    title,
  })}`;
});

Given(
  "the task {string} has a note linking the image {string} on the site and on its full address",
  async ({ app }, title: string, path: string) => {
    await app.sql`INSERT INTO tasks ${app.sql({
      list: "next",
      note: `![one](${path}) ![two](${app.url}${path})`,
      number: (await app.sql`SELECT coalesce(max(number), 0) + 1 AS n FROM tasks WHERE project_id IS NULL`)[0].n,
      position: (await app.sql`SELECT coalesce(max(position), 0) + 1 AS n FROM tasks`)[0].n,
      title,
    })}`;
  },
);

Then("the note shows the image {string} on the site and on its full address", async ({ app, page }, path: string) => {
  await expect(page.locator(`.markdown-body img[src='${path}'][alt='one']`)).toBeAttached();
  await expect(page.locator(`.markdown-body img[src='${app.url}${path}'][alt='two']`)).toBeAttached();
});

Then("the meta parts of {string} are {string}", async ({ app, page }, selector: string, wanted: string) => {
  const parts = await (await part({ app, page }, `${selector} .task-meta > *`)).evaluateAll((nodes) =>
    nodes.map((node) => [...node.classList].find((name) => name !== "task-mark")),
  );
  expect(parts.join(" ")).toBe(wanted);
});

Then("the page part {string} has no {string}", async ({ app, page }, selector: string, name: string) => {
  await expect((await part({ app, page }, selector)).first()).not.toHaveAttribute(name);
});

Then(
  "the page parts {string} have {string} starting with {string}",
  async ({ app, page }, selector: string, name: string, values: string) => {
    const wanted = (await marked(app.sql, values)).split(" | ");
    const found = await (await part({ app, page }, selector)).evaluateAll(
      (nodes, key) => nodes.map((node) => node.getAttribute(key)),
      name,
    );
    expect(found.slice(0, wanted.length)).toEqual(wanted);
  },
);

When(
  "I save the task form of {string} from {string} with:",
  async ({ app, http, page }, title: string, filter: string, data: DataTable) => {
    const id = await filled(app.sql, `{task:${title}}`);
    await page.goto(`/admin/tasks/${id}/edit?filter=${filter}`);
    const held: string[][] = await page
      .locator(`#task-${id}-form [name^='task[']`)
      .evaluateAll((nodes) =>
        nodes
          .filter((node) => !(node instanceof HTMLInputElement && node.type === "checkbox" && !node.checked))
          .map((node) => [node.getAttribute("name") ?? "", (node as HTMLInputElement).value]),
      );
    const changed = new Map(data.raw().map(([key, value]) => [key, value]));
    const pairs = held.map(([key, value]) => [key, changed.has(key) ? (changed.get(key) ?? "") : value]);
    for (const [key, value] of changed) if (!held.some(([name]) => name === key)) pairs.push([key, value]);
    await send({ app, http, page }, `/admin/tasks/${id}`, [["filter", filter], ...pairs]);
  },
);

When(
  "I send the admin form {string} with a forged token and:",
  async ({ answer, app, page }, path: string, data: DataTable) => {
    const form = new URLSearchParams({ _csrf_token: "forged" });
    for (const [key, value] of data.raw()) form.append(key, await marked(app.sql, value));
    const response = await page.request.post(await marked(app.sql, path), {
      data: form.toString(),
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      maxRedirects: 0,
    });
    answer.status = response.status();
    answer.body = await response.text();
  },
);

When("I open the editor of the task {string}", async ({ app, page }, title: string) => {
  const [{ id }] = await app.sql`SELECT id FROM tasks WHERE title = ${title}`;
  await page.goto(`/admin/tasks/${id}/edit?filter=next`);
});

Then("the page part {string} has a {string}", async ({ app, page }, selector: string, name: string) => {
  await expect((await part({ app, page }, selector)).first()).toHaveAttribute(name);
});

Then("every {string} holds an {string}", async ({ app, page }, selector: string, inner: string) => {
  const forms = await (await part({ app, page }, selector)).evaluateAll(
    (nodes, wanted) => nodes.map((node) => Boolean(node.querySelector(wanted))),
    inner,
  );
  expect(forms.length).toBeGreaterThan(0);
  expect(forms.every(Boolean)).toBe(true);
});

Then("the page field {string} by label holds {string}", async ({ page }, label: string, value: string) => {
  await expect(page.getByLabel(label, { exact: true }).first()).toHaveValue(value);
});

Given("the tasks finished at:", async ({ app }, data: DataTable) => {
  for (const { at, title } of data.hashes()) {
    const [, day, clock] = /^(.+?)\s+(\d\d:\d\d)$/.exec(at) ?? [];
    await app.sql`UPDATE tasks SET completed_at = ${zoned(dayOf(day), clock)} WHERE title = ${title}`;
  }
});

Then(
  /^every page part "([^"]+)" has an? "([^"]+)" (holding|without) "([^"]+)"$/,
  async ({ app, page }, selector: string, name: string, how: string, text: string) => {
    const found = await (await part({ app, page }, selector)).evaluateAll(
      (nodes, key) => nodes.map((node) => node.getAttribute(key) ?? ""),
      name,
    );
    expect(found.length).toBeGreaterThan(0);
    for (const value of found) expect(value.includes(text)).toBe(how === "holding");
  },
);

When("I click the page at {int}, {int}", async ({ page }, x: number, y: number) => {
  await page.mouse.click(x, y);
});

Then("the focus is on the text {string}", async ({ page }, text: string) => {
  await expect.poll(() => page.evaluate(() => document.activeElement?.textContent?.trim())).toBe(text);
});

Then("the focus is on the control named {string}", async ({ page }, name: string) => {
  await expect.poll(() => page.evaluate(() => document.activeElement?.getAttribute("aria-label"))).toBe(name);
});

Then("the focus is on the field {string}", async ({ page }, name: string) => {
  await expect.poll(() => page.evaluate(() => document.activeElement?.getAttribute("name"))).toBe(name);
});

When("I press {string} in {string}", async ({ app, page }, key: string, selector: string) => {
  await (await part({ app, page }, selector)).first().press(key);
});

Then("the page part {string} is {int} pixels wide against the right edge", async ({ app, page }, selector, width) => {
  const box = await (await part({ app, page }, selector))
    .first()
    .evaluate((node) => ({ edge: window.innerWidth, ...node.getBoundingClientRect().toJSON() }));
  expect([box.width, box.right]).toEqual([width, box.edge]);
});

Then(
  "the page part {string} sits inline, shorter than {int} pixels",
  async ({ app, page }, selector: string, tall: number) => {
    const found = (await part({ app, page }, selector)).first();
    const [display, height] = await found.evaluate((node) => [
      getComputedStyle(node).display,
      node.getBoundingClientRect().height,
    ]);
    expect(display).toBe("inline");
    expect(height).toBeLessThan(tall);
  },
);

Then("the page part {string} is at least {int} pixels square", async ({ app, page }, selector: string, side) => {
  const box = await (await part({ app, page }, selector))
    .first()
    .evaluate((node) => node.getBoundingClientRect().toJSON());
  expect(Math.min(box.width, box.height)).toBeGreaterThanOrEqual(side);
});

Then("the page part {string} ends within {int} pixels", async ({ app, page }, selector: string, right: number) => {
  const box = await (await part({ app, page }, selector))
    .first()
    .evaluate((node) => node.getBoundingClientRect().toJSON());
  expect(box.right).toBeLessThanOrEqual(right);
});

When("I create the task {string} on {word} from the dialog", async ({ page }, title: string, list: string) => {
  await page.getByRole("link", { name: "Create Task" }).first().click();
  const dialog = page.locator("dialog#task-create[open]");
  await dialog.locator("[name='task[title]']").fill(title);
  await dialog.locator("select[name='task[list]']").selectOption({ label: list });
  await dialog.getByRole("button", { name: "Create task" }).click();
});

When("I fill in {string} in {string} with {string}", async ({ app, page }, label: string, selector, text: string) => {
  const value = (await marked(app.sql, text)).replaceAll("\\n", "\n");
  await (await part({ app, page }, selector)).first().getByLabel(label, { exact: true }).first().fill(value);
});

Then("the script in the page did not run", async ({ page }) => {
  expect(await page.evaluate(() => (window as unknown as { ran?: boolean }).ran)).toBeUndefined();
});

When("the page part {string} gets the value {string}", async ({ app, page }, selector: string, value: string) => {
  const filledValue = await marked(app.sql, value);
  await (await part({ app, page }, selector)).first().evaluate((node, text) => {
    (node as HTMLInputElement).value = text;
  }, filledValue);
});

When("I scroll the pools into view", async ({ page }) => {
  await page.evaluate(() => {
    document.querySelector("[data-pools] .seg")?.scrollIntoView({ block: "center" });
    Object.assign(window, { scrolled: window.scrollY });
  });
});

Given("I sign out of the browser", async ({ context }) => {
  await context.clearCookies();
});

Then("the page parts {string} read in any order {string}", async ({ app, page }, selector: string, texts: string) => {
  const found = await part({ app, page }, selector);
  const wanted = (await marked(app.sql, texts)).split(" | ").sort();
  await expect
    .poll(async () => (await found.evaluateAll((nodes) => nodes.map((node) => node.textContent))).map(spaced).sort())
    .toEqual(wanted);
});

const loads = new WeakMap<Page, Map<string, number>>();

When("I count the pages loaded from {string}", async ({ page }, path: string) => {
  const counts = loads.get(page) ?? new Map<string, number>();
  loads.set(page, counts);
  counts.set(path, 0);
  page.on("response", (response) => {
    const url = new URL(response.url());
    if (url.pathname === path && response.request().method() === "GET" && response.status() < 300) {
      counts.set(path, (counts.get(path) ?? 0) + 1);
    }
  });
});

Then(/^(\d+) pages? loaded from "([^"]+)"$/, async ({ page }, count: string, path: string) => {
  await expect.poll(() => loads.get(page)?.get(path) ?? 0).toBe(Number(count));
});

When("I hold the answer to {string}", async ({ app, page }, path: string) => {
  const found = await gate(page, await filled(app.sql, path));
  found.held = new Promise((done) => {
    found.release = done;
  });
  found.answerHeld = true;
});
