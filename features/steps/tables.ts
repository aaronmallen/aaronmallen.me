import { expect } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { insertRows } from "../support/sql.ts";
import { Given, Then } from "../support/world.ts";

Given("the table {word} holds:", async ({ app }, table: string, rows: DataTable) => {
  await insertRows(app.sql, table, rows.hashes());
});

Then("the table {word} holds {int} row(s)", async ({ app }, table: string, count: number) => {
  const [{ total }] = await app.sql.unsafe(`SELECT count(*)::int AS total FROM ${table}`);
  expect(total).toBe(count);
});
