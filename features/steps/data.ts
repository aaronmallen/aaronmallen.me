import { expect } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { cell, insertRows } from "../support/rows.ts";
import { Given, Then, When } from "../support/world.ts";

Given("the {word} table holds:", async ({ app }, table: string, rows: DataTable) => {
  await insertRows(app.sql, table, rows.hashes());
});

When("the job {string} runs with:", async ({ app }, job: string, args: string) => {
  await app.pushJob(job, ...JSON.parse(args));
});

Then("the {word} table has a row with:", async ({ app }, table: string, rows: DataTable) => {
  const [wanted] = rows.hashes();
  const columns = Object.keys(wanted);
  const found = async () =>
    (await app.sql`SELECT ${app.sql(columns)} FROM ${app.sql(table)}`).map((row) => shape(row, wanted));

  await expect.poll(found).toContainEqual(expected(wanted));
});

Then("the {word} table has no row with:", async ({ app }, table: string, rows: DataTable) => {
  const [unwanted] = rows.hashes();
  const columns = Object.keys(unwanted);
  const found = (await app.sql`SELECT ${app.sql(columns)} FROM ${app.sql(table)}`).map((row) => shape(row, unwanted));

  expect(found).not.toContainEqual(expected(unwanted));
});

const expected = (wanted: Record<string, string>) =>
  Object.fromEntries(
    Object.entries(wanted).map(([column, value]) => [column, value === "set" ? "set" : text(cell(value))]),
  );

const shape = (row: Record<string, unknown>, wanted: Record<string, string>) =>
  Object.fromEntries(
    Object.entries(wanted).map(([column, value]) => [
      column,
      value === "set" && row[column] !== null ? "set" : text(row[column]),
    ]),
  );

function text(value: unknown): string | null {
  if (value === null || value === undefined) return null;
  if (value instanceof Date) return value.toISOString();
  if (Array.isArray(value)) return `{${value.join(",")}}`;
  return String(value);
}
