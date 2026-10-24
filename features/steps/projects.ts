import { readFileSync } from "node:fs";
import { join } from "node:path";
import { expect } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { iso } from "../support/calendar.ts";
import { github } from "../support/issue_sync.ts";
import { settle } from "../support/mail_sync.ts";
import { insertProjectTask } from "../support/projects.ts";
import { root } from "../support/shell.ts";
import { marked } from "../support/task_api.ts";
import { projectId } from "../support/tasks.ts";
import { Given, Then, type test, When } from "../support/world.ts";
import { call } from "./mcp.ts";

type World = Parameters<Parameters<typeof test>[2]>[0];

Given(
  "GitHub reports {string} with {int} stars and the release {string}",
  ({ answer, app }, repo: string, stars: number, release: string) => {
    const fake = github(app.stub, answer);
    fake.rest[repo] = { body: JSON.stringify({ full_name: repo, stargazers_count: stars }), status: 200 };
    fake.rest[`${repo}/releases/latest`] = { body: JSON.stringify({ tag_name: release }), status: 200 };
  },
);

Given("GitHub answers the REST path {string} with a page that isn't JSON", ({ answer, app }, path: string) => {
  github(app.stub, answer).rest[path] = {
    body: "<html>maintenance</html>",
    headers: { "Content-Type": "text/html" },
    status: 200,
  };
});

Given("GitHub rate limits the REST path {string}", ({ answer, app }, path: string) => {
  github(app.stub, answer).rest[path] = {
    body: '{"message":"API rate limit exceeded"}',
    headers: { "X-RateLimit-Remaining": "0", "X-RateLimit-Reset": String(Math.floor(Date.now() / 1000) + 3600) },
    status: 403,
  };
});

When("the nightly project refresh runs", async ({ answer, app }) => {
  github(app.stub, answer);
  await app.pushJob("Projects::Jobs::RefreshProjects");
  await settle(app);
});

When("the project refresh for {string} runs", async ({ answer, app }, name: string) => {
  github(app.stub, answer);
  await app.pushJob("Projects::Jobs::RefreshProject", await projectId(app.sql, name));
  await settle(app);
});

When("the queued project refreshes run", async ({ app }) => {
  await settle(app);
});

Then(
  "the project {string} holds {int} stars and the release {string}",
  async ({ app }, name: string, stars: number, release: string) => {
    const [row] = await app.sql`SELECT stars, coalesce(release, 'none') AS release FROM projects WHERE name = ${name}`;
    expect({ release: row.release, stars: row.stars }).toEqual({ release, stars });
  },
);

Then("GitHub was asked for {string} {int} time(s)", ({ app }, path: string, count: number) => {
  expect(app.stub.received("GET", `/github/api/repos/${path}`)).toHaveLength(count);
});

Then("GitHub was asked for no repo", ({ app }) => {
  const asked = app.stub.requests().filter((sent) => sent.url.pathname.startsWith("/github/api/repos/"));
  expect(asked).toHaveLength(0);
});

Given("the project {string} last changed a day ago", async ({ app }, name: string) => {
  await app.sql`UPDATE projects SET updated_at = now() - interval '1 day' WHERE name = ${name}`;
});

Then("the project {string} has not changed since", async ({ app }, name: string) => {
  const [row] = await app.sql`SELECT updated_at < now() - interval '1 hour' AS old FROM projects WHERE name = ${name}`;
  expect(row.old).toBe(true);
});

// Saves the project form with sai's fields unless the table names others; a row "project" names a saved project
// to edit in place of a new one.
async function saveProject({ answer, app, page }: Pick<World, "answer" | "app" | "page">, table?: DataTable) {
  await postProject({ answer, app, page }, table?.raw() ?? []);
}

async function postProject(
  { answer, app, page }: Pick<World, "answer" | "app" | "page">,
  pairs: string[][],
  start: [string, string][] = [],
) {
  const fields = new Map([
    ["project[name]", "sai"],
    ["project[tagline]", "Terminal colors"],
    ["project[repo]", "aaronmallen/sai"],
    ["project[visibility]", "public"],
    ...start,
  ]);
  let path = "/admin/projects";
  for (const [key, value] of pairs) {
    if (key === "project") path = `/admin/projects/${/^\d+$/.test(value) ? value : await projectId(app.sql, value)}`;
    else fields.set(key, value);
  }
  await page.goto("/admin/settings/tagging");
  const token = await page.locator("input[name='_csrf_token']").first().inputValue();
  const form = new URLSearchParams({ _csrf_token: token });
  for (const [key, value] of fields) form.append(key, await marked(app.sql, value.replace(/^"(.*)"$/, "$1")));
  const response = await page.request.post(path, {
    data: form.toString(),
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    maxRedirects: 0,
  });
  answer.status = response.status();
  answer.body = await response.text();
  answer.headers = response.headers();
}

When("I save a project in the admin", ({ answer, app, page }) => saveProject({ answer, app, page }));

When("I save a project in the admin with:", ({ answer, app, page }, table: DataTable) =>
  saveProject({ answer, app, page }, table),
);

Then("the project {string} reads:", async ({ app }, name: string, table: DataTable) => {
  const [row] = await app.sql`
    SELECT id, name, key, repo, url, tagline, visibility, og_image_url, board_published, stars, release,
      started_on::text AS started_on, archived_on::text AS archived_on,
      (SELECT string_agg(tags.name, ' ' ORDER BY tags.name) FROM project_tags JOIN tags ON tags.id = tag_id
        WHERE project_tags.project_id = projects.id) AS tags
    FROM projects WHERE name = ${name} OR repo = ${name} ORDER BY id LIMIT 1
  `;
  expect(row, name).toBeTruthy();
  for (const [column, value] of table.raw()) {
    const wanted = value === "none" ? null : await marked(app.sql, value);
    expect(row[column] === null ? null : String(row[column]), column).toBe(wanted);
  }
});

Then("the schedule runs {string} {string}", ({}, job: string, when: string) => {
  const schedule = readFileSync(join(root, "config/sidekiq.yml.erb"), "utf8");
  const entry = new RegExp(`\\n\\s+${job}:\\n\\s+description: "([^"]+)"\\n\\s+cron: "([^"]+)"`).exec(schedule);
  expect(entry?.[1]).toBe(when);
});

Then("the tags suggested for {string} are {string}", async ({ page }, field: string, names: string) => {
  const data = await page.locator(`[name='${field}'] + [data-tag-field]`).first().getAttribute("data-tag-field");
  expect(
    JSON.parse(data ?? "[]")
      .map((tag: { name: string }) => tag.name)
      .join(", "),
  ).toBe(names);
});

Then("the task rules read {string}", async ({ app }, wanted: string) => {
  const rows = await app.sql`
    SELECT provider, pattern,
      (SELECT string_agg(name, ' ') FROM task_rule_projects JOIN projects ON projects.id = project_id
        WHERE task_rule_id = task_rules.id) AS projects
    FROM task_rules ORDER BY id
  `;
  expect(rows.map((row) => [row.provider, row.pattern, row.projects].filter(Boolean).join(" ")).join(" / ")).toBe(
    wanted,
  );
});

async function refuses(world: Pick<World, "answer" | "app" | "page">, table: DataTable, project?: string) {
  const start: [string, string][] = [];
  if (project) {
    const [row] = await world.app
      .sql`SELECT id, name, coalesce(repo, '') AS repo FROM projects WHERE name = ${project}`;
    start.push(["project[name]", row.name], ["project[repo]", row.repo]);
  }
  for (const { error, field, value } of table.hashes()) {
    await postProject(world, [...(project ? [["project", project]] : []), [field, value]], start);
    expect(world.answer.status, `${field} ${value}`).toBe(422);
    await world.page.setContent(world.answer.body);
    await expect(world.page.locator(".field-error").filter({ hasText: error }).first()).toBeAttached();
  }
}

Then("the admin project form refuses:", ({ answer, app, page }, table: DataTable) =>
  refuses({ answer, app, page }, table),
);

Then("the admin project form for {string} refuses:", ({ answer, app, page }, project: string, table: DataTable) =>
  refuses({ answer, app, page }, table, project),
);

Then("the admin project form stores:", async ({ answer, app, page }, table: DataTable) => {
  for (const row of table.hashes()) {
    await app.sql`DELETE FROM task_rules`;
    await app.sql`DELETE FROM projects`;
    await postProject({ answer, app, page }, [
      ["project[repo]", row.repo],
      ["project[url]", row.url],
    ]);
    expect(answer.status, `${row.repo} ${row.url}: ${answer.body.slice(0, 200)}`).toBe(302);
    const [saved] = await app.sql`SELECT coalesce(repo, 'none') AS repo, coalesce(url, 'none') AS url FROM projects`;
    expect(saved, `${row.repo} ${row.url}`).toEqual({ repo: row["stored repo"], url: row["stored url"] });
  }
});

Given("the project tasks:", async ({ app }, table: DataTable) => {
  for (const row of table.hashes()) await insertProjectTask(app.sql, row);
});

Given("{int} more tasks in {string} tagged {string}", async ({ app }, count: number, project: string, tag: string) => {
  for (let made = 1; made <= count; made += 1) {
    await insertProjectTask(app.sql, { project, tags: tag, title: `More ${made}` });
  }
});

Then("the filter bar suggests:", async ({ page }, table: DataTable) => {
  const data = JSON.parse((await page.locator("[data-task-filter]").first().getAttribute("data-task-filter")) ?? "{}");
  for (const [key, wanted] of table.raw()) {
    const pairs = data[key] as unknown[][];
    for (const item of wanted.split(" | ")) {
      const values = pairs.map((pair) => (item.includes(" = ") ? pair.join(" = ") : String(pair[0])));
      expect(values, key).toContain(item);
    }
  }
});

Then("the project filter tags are {string}", async ({ page }, names: string) => {
  const data = JSON.parse((await page.locator("[data-task-filter]").first().getAttribute("data-task-filter")) ?? "{}");
  expect((data.tags as string[][]).map(([name]) => name).join(", ")).toBe(names);
});

Then(
  "the page parts {string} include one starting {string} and one starting {string}",
  async ({ page }, selector: string, first: string, second: string) => {
    await expect
      .poll(() => page.locator(selector).allTextContents())
      .toContainEqual(expect.stringMatching(`^${RegExp.escape(first)}`));
    const texts = await page.locator(selector).allTextContents();
    expect(texts.some((text) => text.startsWith(second))).toBe(true);
  },
);

When("I type {string} in {string}", async ({ page }, text: string, selector: string) => {
  await page.locator(selector).first().pressSequentially(text);
});

Then("the board columns read {string}", async ({ page }, wanted: string) => {
  const columns = ["backlog", "ready", "in_progress", "done", "canceled"];
  const read = [];
  for (const name of columns) {
    read.push(
      (await page.locator(`section.kcol.k-${name} .kc-title`).allTextContents()).map((text) => text.trim()).join(", "),
    );
  }
  expect(read.join(" / ")).toBe(wanted);
});

Given(
  "{int} tasks in {string} in the column {string}",
  async ({ app }, count: number, project: string, column: string) => {
    for (let made = 1; made <= count; made += 1) {
      await insertProjectTask(app.sql, {
        project,
        stage: column === "ready" ? "ready" : "",
        title: `${column} ${made}`,
      });
    }
  },
);

When(
  "a bulk board move of {int} cards to {string} goes to {string}",
  async ({ answer, app, page }, count: number, to: string, project: string) => {
    const id = await projectId(app.sql, project);
    await page.goto("/admin/settings/tagging");
    const token = await page.locator("input[name='_csrf_token']").first().inputValue();
    const form = new URLSearchParams({ _csrf_token: token, act: "move", to });
    for (let at = 1; at <= count; at += 1) form.append("ids[]", String(at));
    const response = await page.request.post(`/admin/projects/${id}/tasks/bulk`, {
      data: form.toString(),
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      maxRedirects: 0,
    });
    answer.status = response.status();
    answer.body = await response.text();
    answer.headers = response.headers();
  },
);

const card = (page: World["page"], title: string) => page.locator(".kc").filter({ hasText: title }).first();

When("I right-click the card {string} away from its title", async ({ page }, title: string) => {
  const box = await card(page, title).boundingBox();
  if (!box) throw new Error(`no card ${title}`);
  await page.mouse.click(box.x + 8, box.y + box.height - 6, { button: "right" });
});

When("I hover {string} in the menu", async ({ page }, name: string) => {
  await page.locator(".ctx-item:visible").filter({ hasText: name }).first().hover();
});

When("I drag the card {string} onto the column {string}", async ({ page }, title: string, column: string) => {
  const from = await card(page, title).boundingBox();
  const to = await page.locator(`.kcol.k-${column}`).first().boundingBox();
  if (!from || !to) throw new Error(`no card ${title} or column ${column}`);
  const start = { x: from.x + from.width / 2, y: from.y + from.height / 2 };
  await page.mouse.move(start.x, start.y);
  await page.mouse.down();
  for (let step = 1; step <= 6; step += 1) {
    await page.mouse.move(
      start.x + ((to.x + to.width / 2 - start.x) * step) / 6,
      start.y + ((to.y + to.height / 2 - start.y) * step) / 6,
    );
  }
  await page.mouse.up();
});

Then("the board view shows {word}", async ({ page }, shown: string) => {
  const board = page.locator("[data-board-shows='board']").first();
  const list = page.locator("[data-board-shows='list']").first();
  await expect(shown === "list" ? list : board).toBeVisible();
  await expect(shown === "list" ? board : list).toBeHidden();
});

When("the page forgets the board view it picked", async ({ page }) => {
  await page.evaluate(() => document.querySelector("[data-board-views]")?.removeAttribute("data-board-view"));
});

When("the browser forgets the saved board view", async ({ page }) => {
  await page.evaluate(() => localStorage.clear());
});

When("I drag {string} onto {string}", async ({ page }, from: string, onto: string) => {
  const start = await page.locator(from).first().boundingBox();
  const end = await page.locator(onto).first().boundingBox();
  if (!start || !end) throw new Error(`no ${from} or ${onto}`);
  const [x, y] = [start.x + start.width / 2, start.y + start.height / 2];
  await page.mouse.move(x, y);
  await page.mouse.down();
  for (let step = 1; step <= 6; step += 1) {
    await page.mouse.move(x + ((end.x + end.width / 2 - x) * step) / 6, y + ((end.y + end.height / 2 - y) * step) / 6);
  }
  await page.mouse.up();
});

Given(
  "{int} tasks in {string} carry its tag {string}",
  async ({ app }, count: number, project: string, tag: string) => {
    for (let made = 1; made <= count; made += 1) {
      await insertProjectTask(app.sql, { project, tags: tag, title: `Bug ${made}` });
    }
  },
);

Then("the project tag form for {string} says:", async ({ answer, app, page }, project: string, table: DataTable) => {
  const id = await projectId(app.sql, project);
  for (const { name, toast } of table.hashes()) {
    await page.goto("/admin/settings/tagging");
    const token = await page.locator("input[name='_csrf_token']").first().inputValue();
    const form = new URLSearchParams({ _csrf_token: token, "tag[name]": name.replace(/^"(.*)"$/, "$1") });
    const response = await page.request.post(`/admin/projects/${id}/project_tags`, {
      data: form.toString(),
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      maxRedirects: 0,
    });
    answer.status = response.status();
    await page.goto(response.headers().location ?? `/admin/projects/${id}`);
    await expect(page.locator(".toast").filter({ hasText: toast }).first()).toBeVisible();
  }
});

Then("the project tag pages answer:", async ({ page }, table: DataTable) => {
  for (const { path, status } of table.hashes()) {
    expect((await page.goto(path))?.status(), path).toBe(Number(status));
  }
});

Then("the API answer has the project's stamps as the database does", async ({ answer, app }) => {
  const { created_at, id, updated_at } = JSON.parse(answer.body);
  const [row] = await app.sql`SELECT created_at, updated_at FROM projects WHERE id = ${id}`;
  expect({ created_at, updated_at }).toEqual({ created_at: iso(row.created_at), updated_at: iso(row.updated_at) });
});

Then(
  "the MCP tool {string} refuses:",
  async ({ answer, app, http, request, tokens }, tool: string, table: DataTable) => {
    for (const { args, message } of table.hashes()) {
      await call({ answer, http, request, tokens }, tool, await marked(app.sql, args));
      expect(answer.error, `${args}: ${answer.content}`).toBe(true);
      expect(answer.content, args).toBe(message);
    }
  },
);

Then("the MCP work entries read:", async ({ answer, http, request, tokens }, table: DataTable) => {
  for (const { from, orgs, to } of table.hashes()) {
    await call({ answer, http, request, tokens }, "list_work_entries", JSON.stringify({ from, to }));
    const found = JSON.parse(answer.content ?? "{}").work_entries.map((entry: { org: unknown }) =>
      typeof entry.org === "object" ? (entry.org as { text: string }).text : entry.org,
    );
    expect(found.join(", "), `${from} ${to}`).toBe(orgs);
  }
});

Given("GitHub answers the REST path {string} after the client gives up", ({ answer, app }, path: string) => {
  const late = new Promise((done) => setTimeout(() => done({ body: "{}", status: 200 }), 12_000));
  (github(app.stub, answer).rest as Record<string, unknown>)[path] = late;
});
