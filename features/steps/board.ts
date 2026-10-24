import { expect } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { Given, Then } from "../support/world.ts";
import { tagIds, when } from "./public.ts";

export const siteDay = (date: Date) =>
  new Intl.DateTimeFormat("en-US", {
    day: "numeric",
    month: "short",
    timeZone: "America/Chicago",
    year: "numeric",
  }).format(date);

Given("the tasks of the project {string}:", async ({ app }, name: string, table: DataTable) => {
  const [project] = await app.sql`SELECT id FROM projects WHERE name = ${name}`;
  for (const [index, row] of table.hashes().entries()) {
    const status = row.status || "open";
    const closed = ["done", "canceled"].includes(status);
    const [task] = await app.sql`
      INSERT INTO tasks ${app.sql({
        completed_at: closed ? when(row.closed || "1 hour ago") : null,
        list: "next",
        note: row.note || "",
        position: Number(row.position || index + 1),
        project_id: project?.id ?? null,
        stage: row.stage || "backlog",
        status,
        title: row.title || `Task ${index + 1}`,
        worked_seconds: Number(row.worked || 0),
      })}
      RETURNING id
    `;
    for (const id of await tagIds(app.sql, row.tags ?? "", "project", project?.id)) {
      await app.sql`INSERT INTO task_tags ${app.sql({ tag_id: id, tag_scope: "project", task_id: task.id })}`;
    }
    for (const id of await tagIds(app.sql, row["private tags"] ?? "", "private")) {
      await app.sql`INSERT INTO task_tags ${app.sql({ tag_id: id, tag_scope: "private", task_id: task.id })}`;
    }
  }
});

Given("{int} {word} tasks in the project {string}", async ({ app }, count: number, stage: string, name: string) => {
  const [project] = await app.sql`SELECT id FROM projects WHERE name = ${name}`;
  for (let index = 1; index <= count; index++) {
    await app.sql`
      INSERT INTO tasks ${app.sql({ list: "next", position: index, project_id: project.id, stage, title: `${stage} ${index}` })}
    `;
  }
});

Then("{string} reads {string} with the day {int} days ago", async ({ page }, selector: string, text: string, days) => {
  await expect(page.locator(selector).first()).toHaveText(
    `${text} ${siteDay(new Date(Date.now() - days * 86_400_000))}`,
  );
});

Then("{string} counts {int}", async ({ page }, selector: string, count: number) => {
  await expect(page.locator(selector)).toHaveCount(count);
});

Then("the open states of {string} are:", async ({ page }, selector: string, table: DataTable) => {
  const open = await page
    .locator(selector)
    .evaluateAll((nodes) => nodes.map((node) => String((node as HTMLDetailsElement).open)));
  expect(open).toEqual(table.raw().map(([state]) => state));
});

Then("the tags the filter bar offers are:", async ({ page }, table: DataTable) => {
  const choices = JSON.parse((await page.locator("[data-task-filter]").getAttribute("data-task-filter")) ?? "{}");
  expect(choices.tags.map(([name]: string[]) => name)).toEqual(table.raw().map(([name]) => name));
});

Then("the tag names of {string} are:", async ({ page }, selector: string, table: DataTable) => {
  const names = await page.locator(selector).evaluateAll((nodes) => nodes.map((node) => node.tagName.toLowerCase()));
  expect(names).toEqual(table.raw().map(([name]) => name));
});

Given(
  /^(\d+) tasks? (done|canceled) (.+) in the project "([^"]*)"$/,
  async ({ app }, count: string, status: string, closed: string, name: string) => {
    const [project] = await app.sql`SELECT id FROM projects WHERE name = ${name}`;
    for (let index = 1; index <= Number(count); index++) {
      await app.sql`
        INSERT INTO tasks ${app.sql({
          completed_at: new Date(when(closed).getTime() - index * 1000),
          list: "next",
          position: index,
          project_id: project.id,
          status,
          title: `${status} ${index}`,
        })}
      `;
    }
  },
);
