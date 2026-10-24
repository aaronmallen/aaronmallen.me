import { expect } from "@playwright/test";
import { type DataTable, defineParameterType } from "playwright-bdd";
import { services } from "../support/stub.ts";
import { Given, Then, When } from "../support/world.ts";

defineParameterType({
  name: "service",
  regexp: new RegExp(
    Object.keys(services)
      .sort((one, other) => other.length - one.length)
      .join("|"),
  ),
  transformer: (name: string) => services[name],
});

Given(
  "{service} answers {word} {string} with:",
  ({ stub }, prefix: string, method: string, path: string, body: string) => {
    stub.reply(method, `${prefix}${path}`, { body, status: 200 });
  },
);

Given(
  "{service} answers {word} {string} with status {int}",
  ({ stub }, prefix: string, method: string, path: string, status: number) => {
    stub.reply(method, `${prefix}${path}`, { body: "", status });
  },
);

const types: Record<string, string> = { HTML: "text/html", JSON: "application/json", XML: "application/xml" };

Given(
  "{service} answers {word} {string} with {string}",
  ({ stub }, prefix: string, method: string, path: string, body: string) => {
    stub.reply(method, `${prefix}${path}`, { body, status: 200 });
  },
);

Given(
  "{service} answers {word} {string} as {word} with {string}",
  ({ stub }, prefix: string, method: string, path: string, type: string, body: string) => {
    stub.reply(method, `${prefix}${path}`, { body, headers: { "Content-Type": types[type] }, status: 200 });
  },
);

Given("{service} never answers {word} {string}", ({ stub }, prefix: string, method: string, path: string) => {
  stub.reply(method, `${prefix}${path}`, { body: "", delay: 600_000, status: 200 });
});

Given(
  "{service} answers {word} {string} next with:",
  ({ stub }, prefix: string, method: string, path: string, body: string) => {
    stub.replyThen(method, `${prefix}${path}`, { body, status: 200 });
  },
);

Given(
  "{service} answers {word} {string} next with status {int}",
  ({ stub }, prefix: string, method: string, path: string, status: number) => {
    stub.replyThen(method, `${prefix}${path}`, { body: "", status });
  },
);

Given(
  "{service} answers {word} {string} with status {int} and the headers:",
  ({ stub }, prefix: string, method: string, path: string, status: number, table: DataTable) => {
    stub.reply(method, `${prefix}${path}`, { body: "", headers: Object.fromEntries(table.raw()), status });
  },
);

When("I connect Mastodon on {string}", async ({ page }, server: string) => {
  await page.goto("/admin/settings/services");
  await page.getByRole("button", { name: "Connect a service" }).click();
  await page.getByRole("button", { name: /Mastodon/ }).click();
  const dialog = page.getByRole("dialog", { name: "Connect Mastodon" });
  await dialog.getByLabel("Your server").fill(server);
  await dialog.getByRole("button", { name: "Continue to Mastodon" }).click();
});

When("the browser asks for {string}", async ({ page }, url: string) => {
  await page.goto(url).catch(() => {});
});

Then("I see {string}", async ({ page }, text: string) => {
  await expect(page.getByText(text).filter({ visible: true }).first()).toBeVisible();
});

Then("{service} received {word} {string}", async ({ stub }, prefix: string, method: string, path: string) => {
  await expect.poll(() => stub.received(method, `${prefix}${path}`).length).toBeGreaterThan(0);
});

Then("{service} received no {word} {string}", ({ stub }, prefix: string, method: string, path: string) => {
  expect(stub.received(method, `${prefix}${path}`)).toEqual([]);
});

Then(
  "{service} received {word} {string} holding {string}",
  async ({ stub }, prefix: string, method: string, path: string, text: string) => {
    await expect.poll(() => stub.received(method, `${prefix}${path}`).some((body) => body.includes(text))).toBe(true);
  },
);

function parsed(body: string) {
  try {
    return JSON.parse(body);
  } catch {
    return Object.fromEntries(new URLSearchParams(body));
  }
}

Then(
  "{service} received {word} {string} with:",
  async ({ stub }, prefix: string, method: string, path: string, body: string) => {
    await expect
      .poll(() => stub.received(method, `${prefix}${path}`).map(parsed))
      .toContainEqual(expect.objectContaining(JSON.parse(body)));
  },
);

Then(
  "{service} received {word} {string} with the headers:",
  async ({ stub }, prefix: string, method: string, path: string, table: DataTable) => {
    const wanted = Object.fromEntries(table.raw().map(([name, value]) => [name.toLowerCase(), value]));
    await expect
      .poll(() =>
        stub
          .requests()
          .filter((sent) => {
            const sentPath = path.includes("?") ? `${sent.url.pathname}${sent.url.search}` : sent.url.pathname;
            return sent.method === method && sentPath === `${prefix}${path}`;
          })
          .map((sent) => sent.headers),
      )
      .toContainEqual(expect.objectContaining(wanted));
  },
);
