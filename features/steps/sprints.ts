import { expect } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { dayOf } from "../support/calendar.ts";
import { settle } from "../support/mail_sync.ts";
import { sprintId } from "../support/tasks.ts";
import { Given, When } from "../support/world.ts";

Given("the sprints:", async ({ app }, table: DataTable) => {
  for (const row of table.hashes()) {
    const id = await sprintId(app.sql, row.day);
    if (row.carried_in) await app.sql`UPDATE sprints SET carried_in = ${Number(row.carried_in)} WHERE id = ${id}`;
  }
});

Given("{int} sprints planned from tomorrow", async ({ app }, count: number) => {
  await app.sql`
    INSERT INTO sprints (sprint_date)
    SELECT ${dayOf("today")}::date + day FROM generate_series(1, ${count}) AS day
  `;
});

When("the sprint roll over runs", async ({ app }) => {
  await app.pushJob("Tasks::Jobs::RollOverSprint");
  await settle(app);
});

When(
  "two reads of the current sprint wait on another session's sprint lock, then run",
  async ({ app, request, tokens }) => {
    const other = await app.sql.reserve();
    try {
      await other`SELECT pg_advisory_lock(hashtext('sprints'))`;
      const reads = [0, 1].map(() =>
        request.get("/api/v1/sprints/current", { headers: { Authorization: `Bearer ${tokens.api}` } }),
      );
      await expect
        .poll(
          async () =>
            (
              await app.sql`
                SELECT count(*)::int AS waiting FROM pg_stat_activity WHERE wait_event_type = 'Lock'
              `
            )[0].waiting,
        )
        .toBe(2);
      await other`SELECT pg_advisory_unlock(hashtext('sprints'))`;
      const answers = await Promise.all(reads);
      for (const answer of answers) expect(answer.status(), await answer.text()).toBe(200);
    } finally {
      other.release();
    }
  },
);
