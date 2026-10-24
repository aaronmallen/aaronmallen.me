import { expect } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { dayOf, zoned } from "../support/calendar.ts";
import { insertTask, taskId } from "../support/tasks.ts";
import { Given, Then, When } from "../support/world.ts";

// Reads "2026-03-02 09:00", "today 09:00" or "20 minutes ago" as an instant.
function instant(text: string) {
  const ago = /^(\d+) minutes? ago$/.exec(text.trim());
  if (ago) return new Date(Date.now() - Number(ago[1]) * 60000);
  const [, day, clock] = /^(.+?)\s+(\d\d:\d\d)$/.exec(text.trim()) ?? [];
  if (!clock) throw new Error(`no instant reads ${text}`);

  return zoned(dayOf(day), clock);
}

// Reads one span: "2026-03-02 09:00-10:00", "2026-03-02 22:00 to 2026-03-03 02:00" or "20 minutes ago to" (running).
function span(text: string): [Date, Date | null] {
  const short = /^(\S+) (\d\d:\d\d)-(\d\d:\d\d)$/.exec(text.trim());
  if (short) return [instant(`${short[1]} ${short[2]}`), instant(`${short[1]} ${short[3]}`)];
  const [from, to] = `${text.trim()} `.split(" to ").map((part) => part.trim());

  return [instant(from), to ? instant(to) : null];
}

// Each row is a task with its work sessions, split by "; ". The total is the sessions' closed length unless given.
// A task with a running session is in progress; any other is done unless its status says otherwise.
Given("the worked tasks:", async ({ app }, table: DataTable) => {
  for (const row of table.hashes()) {
    const spans = (row.sessions ?? "")
      .split(";")
      .filter((text) => text.trim())
      .map(span);
    const closedLength = spans.reduce((sum, [from, to]) => sum + (to ? (to.getTime() - from.getTime()) / 1000 : 0), 0);
    const running = spans.some(([, to]) => !to);
    const status = row.status || (running ? "in_progress" : "done");
    const id = await insertTask(app.sql, {
      list: row.sprint ? undefined : "next",
      project: (row.projects ?? "").split(", ").filter(Boolean).at(-1),
      sprint: row.sprint,
      status,
      tags: row.tags,
      title: row.title,
      worked: row.total || String(Math.round(closedLength)),
    });
    if (row.closed && (status === "done" || status === "canceled")) {
      await app.sql`UPDATE tasks SET completed_at = ${instant(row.closed)} WHERE id = ${id}`;
    }
    for (const [from, to] of spans) {
      await app.sql`INSERT INTO work_sessions ${app.sql({ ended_at: to, started_at: from, task_id: id })}`;
    }
  }
});

Given(
  "the task {string} worked from {string} to {string}",
  async ({ app }, title: string, from: string, to: string) => {
    await app.sql`
    INSERT INTO work_sessions ${app.sql({ ended_at: instant(to), started_at: instant(from), task_id: await taskId(app.sql, title) })}
  `;
  },
);

When("I open the time report", async ({ page }) => {
  await page.goto("/admin/time");
});

When("I open the time report from {string} to {string} by {string}", async ({ page }, from, to, by: string) => {
  await page.goto(`/admin/time?${new URLSearchParams({ by, from, to })}`);
});

Then("the time rows read {string}", async ({ page }, rows: string) => {
  const found = page.locator(".time-row");
  await expect
    .poll(() =>
      found.evaluateAll((nodes) =>
        nodes.map(
          (node) =>
            `${node.querySelector(".meter-name")?.textContent?.trim()} ${node.querySelector(".meter-count")?.textContent?.trim()}`,
        ),
      ),
    )
    .toEqual(rows ? rows.split(" | ") : []);
});

Then("the time group {string} lists {string}", async ({ app, page }, group: string, lines: string) => {
  const items = page
    .locator(".time-group")
    .filter({ has: page.locator(".meter-name", { hasText: group }) })
    .locator(".li");
  const wanted = [];
  for (const line of lines.split(" | ")) {
    const [, title, hours] = /^(.*?) ((?:\d+h )?\d+m)$/.exec(line) ?? [];
    wanted.push(`${title} /admin/tasks/${await taskId(app.sql, title)} ${hours}`);
  }
  await expect
    .poll(() =>
      items.evaluateAll((nodes) =>
        nodes.map((node) => {
          const link = node.querySelector("a");
          return `${link?.textContent?.trim()} ${link?.getAttribute("href")} ${node.querySelector(".time-task-hours")?.textContent?.trim()}`;
        }),
      ),
    )
    .toEqual(wanted);
});

Then("the time group {string} flags the tasks {string} as shared", async ({ page }, group: string, titles: string) => {
  const items = page
    .locator(".time-group")
    .filter({ has: page.locator(".meter-name", { hasText: group }) })
    .locator(".li");
  const flagged = await items.evaluateAll((nodes) =>
    nodes
      .filter((node) => [...node.querySelectorAll(".tone-text")].some((mark) => mark.textContent?.includes("shared")))
      .map((node) => node.querySelector("a")?.textContent?.trim()),
  );
  expect(flagged).toEqual(titles ? titles.split(", ") : []);
});

Then("the time report flags no row as shared", async ({ page }) => {
  await expect(page.locator(".time-row .tone-text")).toHaveCount(0);
});

Then("the time hints read {string}", async ({ page }, hints: string) => {
  await expect(page.locator("#time-groups .hint")).toHaveText(hints ? hints.split(" | ") : []);
});

Then("the time range reads from {string} to {string}", async ({ page }, from: string, to: string) => {
  await expect(page.locator("#time-from")).toHaveValue(dayOf(from));
  await expect(page.locator("#time-to")).toHaveValue(dayOf(to));
});

Then("the time report total is about {int} seconds", ({ answer }, seconds: number) => {
  expect(Math.abs(JSON.parse(answer.body).seconds - seconds)).toBeLessThanOrEqual(5);
});

Then("the time report day {string} lists {string} in some order", async ({ answer }, day: string, tasks: string) => {
  const group = JSON.parse(answer.body).groups.find((found: { key: string }) => found.key === day);
  const listed = group.tasks.map((task: { title: string; seconds: number }) => `${task.title} ${task.seconds}`);
  expect(listed.sort()).toEqual(tasks.split(", ").sort());
});

Then(
  "the running figure {string} of {string} reads {string} and counts from its tracked start",
  async ({ app, page }, scope: string, title: string, text: string) => {
    const [{ since }] = await app.sql`
      SELECT floor((extract(epoch FROM min(started_at)) - tasks.worked_seconds) * 1000)::bigint AS since
      FROM tasks JOIN work_sessions ON task_id = tasks.id WHERE title = ${title} AND ended_at IS NULL
      GROUP BY tasks.worked_seconds
    `;
    await expect(page.locator(`${scope} [data-tracked-since='${since}']`).first()).toHaveText(text);
  },
);

When("the running figure on the tasks list began {int} minute(s) sooner", async ({ page }, minutes: number) => {
  await page
    .locator(".task-meta [data-tracked-since]")
    .first()
    .evaluate((node: HTMLElement, back) => {
      node.dataset.trackedSince = String(Number(node.dataset.trackedSince) - back * 60000);
    }, minutes);
});

When("the page draws the running figure again", async ({ page }) => {
  await page
    .locator(".task-meta [data-tracked-since]")
    .first()
    .evaluate((node) => {
      node.replaceWith(node.cloneNode(true));
    });
});

When(
  "two deletes of the closed session of {string} wait on a lock on the task, then run",
  async ({ answer, app, request, tokens }, title: string) => {
    const task = await taskId(app.sql, title);
    const [{ id: session }] = await app.sql`
      SELECT id FROM work_sessions WHERE task_id = ${task} AND ended_at IS NOT NULL ORDER BY id LIMIT 1
    `;
    const other = await app.sql.reserve();
    try {
      await other`BEGIN`;
      await other`SELECT id FROM tasks WHERE id = ${task} FOR UPDATE`;
      const deletes = [0, 1].map(() =>
        request.delete(`/api/v1/tasks/${task}/sessions/${session}`, {
          headers: { Authorization: `Bearer ${tokens.api}` },
        }),
      );
      await expect
        .poll(
          async () =>
            (await app.sql`SELECT count(*)::int AS waiting FROM pg_stat_activity WHERE wait_event_type = 'Lock'`)[0]
              .waiting,
        )
        .toBe(2);
      await other`COMMIT`;
      answer.body = (await Promise.all(deletes)).map((response) => response.status()).join(", ");
    } finally {
      other.release();
    }
  },
);

Then("the two deletes answered {string} in some order", ({ answer }, statuses: string) => {
  expect(answer.body.split(", ").sort()).toEqual(statuses.split(", ").sort());
});
