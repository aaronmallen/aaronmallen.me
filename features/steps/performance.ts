import { expect } from "@playwright/test";
import { Given, Then, When } from "../support/world.ts";

When("a client posts a JSON-RPC tools list to {string}", async ({ answer, request }, path: string) => {
  const response = await request.post(path, {
    data: { id: 1, jsonrpc: "2.0", method: "tools/list" },
    headers: { Accept: "application/json" },
  });
  answer.status = response.status();
});

When("a visitor fetches {string}", async ({ answer, request }, path: string) => {
  const response = await request.get(path);
  answer.status = response.status();
  answer.body = await response.text();
});

When("the job {string} is pushed", async ({ app }, job: string) => {
  await app.pushJob(job);
});

Then("the {word} table has the columns {string}", async ({ app }, table: string, columns: string) => {
  const found = await app.sql`
    SELECT column_name FROM information_schema.columns WHERE table_name = ${table} ORDER BY column_name
  `;
  expect(found.map(({ column_name }) => column_name)).toEqual(columns.split(", ").sort());
});

When("the raw timing rows are deleted", async ({ app }) => {
  await app.sql`DELETE FROM performance_requests`;
  await app.sql`DELETE FROM performance_jobs`;
  await app.sql`DELETE FROM performance_pages`;
});

When("I follow the link {string}", async ({ page }, name: string) => {
  await page.getByRole("link", { exact: true, name }).first().click();
  await page.waitForLoadState();
});

Given("the timing rows of the sign in are cleared", async ({ app }) => {
  const count = async () => Number((await app.sql`SELECT count(*) FROM performance_requests`)[0].count);
  for (let settled = 0, last = -1; settled < 3; ) {
    const now = await count();
    settled = now === last ? settled + 1 : 0;
    last = now;
    await new Promise((done) => setTimeout(done, 200));
  }
  await app.sql`DELETE FROM performance_requests`;
});
