import type { DataTable } from "playwright-bdd";
import { insertTask } from "../support/tasks.ts";
import { Given } from "../support/world.ts";

Given("the tasks:", async ({ app }, table: DataTable) => {
  for (const row of table.hashes()) await insertTask(app.sql, row);
});
