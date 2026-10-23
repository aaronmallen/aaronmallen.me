import { execFileSync } from "node:child_process";
import { createHash, randomBytes } from "node:crypto";
import { request as httpRequest } from "node:http";
import { setTimeout as sleep } from "node:timers/promises";
import { inflateRawSync } from "node:zlib";
import { type DataTable, expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import type postgres from "postgres";
import { Given, Then, test, When } from "../support/world.ts";

type World = Parameters<Parameters<typeof test>[2]>[0];

const { After } = createBdd(test);
const browserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 Safari/605.1.15";
const workspace = Number(process.env.WORKSPACE_ID ?? 0);
let lastBody = Buffer.alloc(0);
let pausedRedis: string | undefined;

async function shareApi(
  { app, request, tokens }: Pick<World, "app" | "request" | "tokens">,
  method: string,
  path: string,
  data?: unknown,
) {
  if (!tokens.api) {
    tokens.api = randomBytes(32).toString("base64url");
    const digest = createHash("sha256").update(tokens.api).digest("hex");
    await app.sql`INSERT INTO api_tokens ${app.sql({ name: "Share steps", token_digest: digest })}`;
  }
  const response = await request.fetch(`/api/v1${path}`, {
    data,
    headers: { Authorization: `Bearer ${tokens.api}` },
    method,
  });
  const text = await response.text();
  expect(response.ok(), text).toBe(true);
  return JSON.parse(text);
}

async function bytesFor({ page }: Pick<World, "page">, body: string | undefined) {
  const image = /^a (\d+) by (\d+) (jpeg|png)$/.exec(body ?? "");
  const size = /^(\d+) bytes$/.exec(body ?? "");
  if (size) return Buffer.alloc(Number(size[1]), "x");
  if (!image) return Buffer.from(body ?? "0123456789");
  const encoded = await page.evaluate(async ([width, height, type]) => {
    const canvas = new OffscreenCanvas(Number(width), Number(height));
    const context = canvas.getContext("2d") as OffscreenCanvasRenderingContext2D;
    context.fillRect(0, 0, canvas.width, canvas.height);
    const blob = await canvas.convertToBlob({ type: `image/${type}` });
    const bytes = new Uint8Array(await blob.arrayBuffer());
    return btoa(Array.from(bytes, (byte) => String.fromCharCode(byte)).join(""));
  }, image.slice(1));
  return Buffer.from(encoded, "base64");
}

async function upload({ page }: Pick<World, "page">, row: Record<string, string>) {
  const data = (await bytesFor({ page }, row.body)).toString("base64");
  return { content_type: row.type, data, filename: row.filename };
}

async function fileRow(sql: postgres.Sql, filename: string) {
  const [file] = await sql`
    SELECT f.*, c.code FROM share_group_files f LEFT JOIN short_codes c ON c.id = f.short_code_id
    WHERE f.filename = ${filename} ORDER BY f.id DESC LIMIT 1
  `;
  expect(file, `the shared file ${filename}`).toBeTruthy();
  return file;
}

async function groupRow(sql: postgres.Sql) {
  const [group] = await sql`
    SELECT g.*, c.code FROM share_groups g JOIN short_codes c ON c.id = g.short_code_id ORDER BY g.id DESC LIMIT 1
  `;
  expect(group, "a share group").toBeTruthy();
  return group;
}

async function linkRow(sql: postgres.Sql, destination: string) {
  const [link] = await sql`
    SELECT l.*, c.code FROM short_links l JOIN short_codes c ON c.id = l.short_code_id
    WHERE l.destination = ${destination} ORDER BY l.id DESC LIMIT 1
  `;
  expect(link, `the short link to ${destination}`).toBeTruthy();
  return link;
}

async function expand(sql: postgres.Sql, text: string) {
  let expanded = text;
  for (const [whole, what, name] of text.matchAll(/\[(code of|id of|link of|group code|group id)\s*([^\]]*)\]/g)) {
    const value = {
      "code of": async () => (await fileRow(sql, name)).code,
      "group code": async () => (await groupRow(sql)).code,
      "group id": async () => (await groupRow(sql)).id,
      "id of": async () => (await fileRow(sql, name)).id,
      "link of": async () => `http://shares.localhost/${(await fileRow(sql, name)).code}`,
    }[what];
    expanded = expanded.replace(whole, String(await value()));
  }
  return expanded;
}

async function hostFetch(
  { answer, app, request }: Pick<World, "answer" | "app" | "request">,
  method: string,
  path: string,
  headers: Record<string, string> = {},
) {
  const response = await request.fetch(`${app.url}${await expand(app.sql, path)}`, {
    headers: { Host: "shares.localhost", "User-Agent": "", ...headers },
    maxRedirects: 0,
    method,
  });
  lastBody = await response.body();
  answer.headers = response.headers();
  answer.status = response.status();
  answer.body = lastBody.toString();
}

function unzip(zip: Buffer) {
  const end = zip.lastIndexOf(Buffer.from([0x50, 0x4b, 0x05, 0x06]));
  const entries: Record<string, string> = {};
  let at = zip.readUInt32LE(end + 16);
  for (let index = 0; index < zip.readUInt16LE(end + 10); index++) {
    const method = zip.readUInt16LE(at + 10);
    const size = zip.readUInt32LE(at + 20);
    const name = zip.subarray(at + 46, at + 46 + zip.readUInt16LE(at + 28)).toString();
    const local = zip.readUInt32LE(at + 42);
    const start = local + 30 + zip.readUInt16LE(local + 26) + zip.readUInt16LE(local + 28);
    const data = zip.subarray(start, start + size);
    entries[name] = (method === 8 ? inflateRawSync(data) : data).toString();
    at += 46 + zip.readUInt16LE(at + 28) + zip.readUInt16LE(at + 30) + zip.readUInt16LE(at + 32);
  }
  return entries;
}

function redisContainer(parallelIndex: number) {
  return `aaronmallen.me-features-ws${workspace}-w${parallelIndex}`;
}

After(async () => {
  if (pausedRedis) execFileSync("docker", ["unpause", pausedRedis], { stdio: "ignore" });
  pausedRedis = undefined;
});

Given(
  "the share {string} of type {string}",
  async ({ answer, app, page, request, tokens }, filename: string, type: string) => {
    await shareApi(
      { answer, app, page, request, tokens },
      "POST",
      "/shares",
      await upload({ answer, app, page, request, tokens }, { filename, type }),
    );
  },
);

Given(
  "the share {string} of type {string} holding {string}",
  async ({ answer, app, page, request, tokens }, filename: string, type: string, body: string) => {
    await shareApi(
      { answer, app, page, request, tokens },
      "POST",
      "/shares",
      await upload({ answer, app, page, request, tokens }, { body, filename, type }),
    );
  },
);

Given("the shares:", async ({ answer, app, page, request, tokens }, table: DataTable) => {
  for (const row of table.hashes())
    await shareApi(
      { answer, app, page, request, tokens },
      "POST",
      "/shares",
      await upload({ answer, app, page, request, tokens }, row),
    );
});

Given("the share group of:", async ({ answer, app, page, request, tokens }, table: DataTable) => {
  const files = [];
  for (const row of table.hashes()) files.push(await upload({ answer, app, page, request, tokens }, row));
  await shareApi({ answer, app, page, request, tokens }, "POST", "/share_groups", { files });
});

Given("the share group is named {string}", async ({ answer, app, page, request, tokens }, name: string) => {
  await shareApi({ answer, app, page, request, tokens }, "PATCH", `/share_groups/${(await groupRow(app.sql)).id}`, {
    name,
  });
});

Given(
  "the shared file {string} is renamed {string} in the group",
  async ({ answer, app, page, request, tokens }, from: string, to: string) => {
    const file = await fileRow(app.sql, from);
    await shareApi(
      { answer, app, page, request, tokens },
      "PATCH",
      `/share_groups/${file.share_group_id}/files/${file.id}`,
      { filename: to },
    );
  },
);

Given("the shared file {string} is stored under the name {string}", async ({ app }, from: string, to: string) => {
  await app.sql`UPDATE share_group_files SET filename = ${to} WHERE id = ${(await fileRow(app.sql, from)).id}`;
});

Given("the shared file {string} is stored as the type {string}", async ({ app }, filename: string, type: string) => {
  await app.sql`UPDATE share_group_files SET content_type = ${type} WHERE id = ${(await fileRow(app.sql, filename)).id}`;
});

Given("the shared file {string} has the alt text {string}", async ({ app }, filename: string, text: string) => {
  await app.sql`UPDATE share_group_files SET alt_text = ${text} WHERE id = ${(await fileRow(app.sql, filename)).id}`;
});

Given("the shared file {string} has {int} download(s)", async ({ app }, filename: string, count: number) => {
  await app.sql`UPDATE share_group_files SET download_count = ${count} WHERE id = ${(await fileRow(app.sql, filename)).id}`;
});

Given("the share group has {int} views and {int} zip downloads", async ({ app }, views: number, zips: number) => {
  await app.sql`
    UPDATE share_groups SET view_count = ${views}, zip_download_count = ${zips} WHERE id = ${(await groupRow(app.sql)).id}
  `;
});

Given("the shared file {string} has the code {string}", async ({ app }, filename: string, code: string) => {
  await app.sql`UPDATE short_codes SET code = ${code} WHERE id = ${(await fileRow(app.sql, filename)).short_code_id}`;
});

Given("the share group has the code {string}", async ({ app }, code: string) => {
  await app.sql`UPDATE short_codes SET code = ${code} WHERE id = ${(await groupRow(app.sql)).short_code_id}`;
});

Given("the share store lost the shared file {string}", async ({ app }, filename: string) => {
  app.stub.objects.delete(`shares/${(await fileRow(app.sql, filename)).key}`);
});

Given("the share store lost the preview of {string}", async ({ app }, filename: string) => {
  app.stub.objects.delete(`shares/${(await fileRow(app.sql, filename)).preview_key}`);
});

Given("the shared file {string} has no preview", async ({ app }, filename: string) => {
  await app.sql`UPDATE share_group_files SET preview_key = NULL WHERE id = ${(await fileRow(app.sql, filename)).id}`;
});

Given("the short code {string} is taken", async ({ app }, code: string) => {
  await app.sql`INSERT INTO short_codes ${app.sql({ code })}`;
});

Given("the short link {string} to {string}", async ({ app }, code: string, destination: string) => {
  const [{ id }] = await app.sql`INSERT INTO short_codes ${app.sql({ code })} RETURNING id`;
  await app.sql`INSERT INTO short_links ${app.sql({ destination, short_code_id: id, title: "A short link" })}`;
});

Given("the short link to {string} is deleted", async ({ app }, destination: string) => {
  await app.sql`DELETE FROM short_codes WHERE id = ${(await linkRow(app.sql, destination)).short_code_id}`;
});

Given("the queue is down", async ({ $testInfo }) => {
  pausedRedis = redisContainer($testInfo.parallelIndex);
  execFileSync("docker", ["pause", pausedRedis], { stdio: "ignore" });
});

When("the queue is back", () => {
  if (pausedRedis) execFileSync("docker", ["unpause", pausedRedis], { stdio: "ignore" });
  pausedRedis = undefined;
});

When("I fetch {string} from the share host", ({ answer, app, page, request, tokens }, path: string) =>
  hostFetch({ answer, app, page, request, tokens }, "GET", path),
);

When("a browser fetches {string} from the share host", ({ answer, app, page, request, tokens }, path: string) =>
  hostFetch({ answer, app, page, request, tokens }, "GET", path, { "User-Agent": browserAgent }),
);

When(
  "a browser fetches {string} from the share host with the range {string}",
  ({ answer, app, page, request, tokens }, path: string, range: string) =>
    hostFetch({ answer, app, page, request, tokens }, "GET", path, { Range: range, "User-Agent": browserAgent }),
);

When(
  "the agent {string} fetches {string} from the share host",
  ({ answer, app, page, request, tokens }, agent: string, path: string) =>
    hostFetch({ answer, app, page, request, tokens }, "GET", path, { "User-Agent": agent }),
);

When("a browser asks the share host for the head of {string}", ({ answer, app, page, request, tokens }, path: string) =>
  hostFetch({ answer, app, page, request, tokens }, "HEAD", path, { "User-Agent": browserAgent }),
);

When("I post to {string} on the share host", ({ answer, app, page, request, tokens }, path: string) =>
  hostFetch({ answer, app, page, request, tokens }, "POST", path),
);

When(
  "I fetch {string} from the share host with the header {string} set to {string}",
  ({ answer, app, page, request, tokens }, path: string, name: string, value: string) =>
    hostFetch({ answer, app, page, request, tokens }, "GET", path, { [name]: value }),
);

When(
  "I fetch {string} from the blog host with the header {string} set to {string}",
  ({ answer, app, page, request, tokens }, path: string, name: string, value: string) =>
    hostFetch({ answer, app, page, request, tokens }, "GET", path, { Host: "aaronmallen.me", [name]: value }),
);

When("I fetch {string} from the blog host", ({ answer, app, page, request, tokens }, path: string) =>
  hostFetch({ answer, app, page, request, tokens }, "GET", path, { Host: "aaronmallen.me" }),
);

When("I open {string} on the share host", async ({ app, page }, path: string) => {
  await page.goto(`${app.url.replace("127.0.0.1", "shares.localhost")}${await expand(app.sql, path)}`);
});

Then("the share host answers {int}", ({ answer }, status: number) => {
  expect(answer.status, answer.body).toBe(status);
});

Then("the share host answers {int} with {string}", ({ answer }, status: number, text: string) => {
  expect([answer.status, answer.body]).toEqual([status, text]);
});

Then("the share host answers {int} with nothing", ({ answer }, status: number) => {
  expect([answer.status, answer.body]).toEqual([status, ""]);
});

Then("the share host header {string} is {string}", async ({ answer, app }, name: string, value: string) => {
  expect(answer.headers?.[name.toLowerCase()]).toBe(await expand(app.sql, value));
});

Then("the share host header {string} is:", async ({ answer, app }, name: string, value: string) => {
  expect(answer.headers?.[name.toLowerCase()]).toBe(await expand(app.sql, value));
});

Then("the share host header {string} starts with {string}", ({ answer }, name: string, value: string) => {
  expect(answer.headers?.[name.toLowerCase()]).toMatch(new RegExp(`^${RegExp.escape(value)}`));
});

Then("the share host header {string} holds {string}", ({ answer }, name: string, value: string) => {
  expect(answer.headers?.[name.toLowerCase()]).toContain(value);
});

Then("the share host header {string} is not {string}", ({ answer }, name: string, value: string) => {
  expect(answer.headers?.[name.toLowerCase()]).not.toBe(value);
});

Then("the share host sends a preview {int} pixels wide", ({ answer }, width: number) => {
  expect(answer.headers?.["content-type"]).toBe("image/jpeg");
  let at = 2;
  while (at < lastBody.length && !(lastBody[at + 1] >= 0xc0 && lastBody[at + 1] <= 0xc2)) {
    at += 2 + lastBody.readUInt16BE(at + 2);
  }
  expect(lastBody.readUInt16BE(at + 7)).toBe(width);
});

Then("the share host sends the original {string}", async ({ answer, app }, filename: string) => {
  const stored = app.stub.objects.get(`shares/${(await fileRow(app.sql, filename)).key}`);
  expect(answer.status).toBe(200);
  expect(lastBody.equals(stored?.body ?? Buffer.alloc(1))).toBe(true);
});

Then("the share zip holds:", ({ answer }, table: DataTable) => {
  expect(answer.status).toBe(200);
  expect(Object.entries(unzip(lastBody))).toEqual(table.raw().map(([name, body]) => [name, body]));
});

Then("the shared file {string} counts {int} download(s)", async ({ app }, filename: string, count: number) => {
  expect((await fileRow(app.sql, filename)).download_count).toBe(count);
});

Then("the share group counts {int} view(s) and {int} zip download(s)", async ({ app }, views: number, zips: number) => {
  const group = await groupRow(app.sql);
  expect([group.view_count, group.zip_download_count]).toEqual([views, zips]);
});

Then("the share store holds {int} file(s)", ({ app }, count: number) => {
  expect([...app.stub.objects.keys()].filter((key) => key.startsWith("shares/"))).toHaveLength(count);
});

Then("the share store holds the file {string} as {string}", async ({ app }, filename: string, body: string) => {
  const file = await fileRow(app.sql, filename);
  const stored = app.stub.objects.get(`shares/${file.key}`);
  expect([stored?.body.toString(), stored?.type]).toEqual([body, file.content_type]);
});

Then(
  "the share store holds a preview {int} pixels wide for {string}",
  async ({ app }, width: number, filename: string) => {
    const file = await fileRow(app.sql, filename);
    const preview = app.stub.objects.get(`shares/${file.preview_key}`);
    expect(preview?.type).toBe("image/jpeg");
    lastBody = preview?.body ?? Buffer.alloc(0);
    let at = 2;
    while (at < lastBody.length && !(lastBody[at + 1] >= 0xc0 && lastBody[at + 1] <= 0xc2)) {
      at += 2 + lastBody.readUInt16BE(at + 2);
    }
    expect(lastBody.readUInt16BE(at + 7)).toBe(width);
  },
);

Then("the shared file {string} has no preview stored", async ({ app }, filename: string) => {
  expect((await fileRow(app.sql, filename)).preview_key).toBeNull();
});

Then("no shares or share groups are left", async ({ app }) => {
  const [{ files, groups, codes }] = await app.sql`
    SELECT (SELECT count(*) FROM share_group_files)::int AS files, (SELECT count(*) FROM share_groups)::int AS groups,
      (SELECT count(*) FROM short_codes)::int AS codes
  `;
  expect([files, groups, codes]).toEqual([0, 0, 0]);
});

Then("the short link to {string} counts {int} click(s)", async ({ app }, destination: string, count: number) => {
  expect((await linkRow(app.sql, destination)).click_count).toBe(count);
});

Then("the short link to {string} has a last click time", async ({ app }, destination: string) => {
  expect((await linkRow(app.sql, destination)).last_clicked_at).not.toBeNull();
});

Then("the short link to {string} has no last click time", async ({ app }, destination: string) => {
  expect((await linkRow(app.sql, destination)).last_clicked_at).toBeNull();
});

Then("the short link to {string} has no retarget time", async ({ app }, destination: string) => {
  expect((await linkRow(app.sql, destination)).retargeted_at).toBeNull();
});

Then("the short link to {string} is titled {string}", async ({ app }, destination: string, title: string) => {
  await expect.poll(async () => (await linkRow(app.sql, destination)).title, { timeout: 15_000 }).toBe(title);
});

Then("the short link to {string} title starts with {string}", async ({ app }, destination: string, start: string) => {
  await expect
    .poll(async () => (await linkRow(app.sql, destination)).title ?? "", { timeout: 15_000 })
    .toMatch(new RegExp(`^${RegExp.escape(start)}`));
});

Then(
  "the short link to {string} title ends with {string} and runs {int} characters at most",
  async ({ app }, destination: string, end: string, most: number) => {
    const { title } = await linkRow(app.sql, destination);
    expect(title.endsWith(end) && title.length <= most, title).toBe(true);
  },
);

Then("the short link to {string} has no title once the fetch is done", async ({ app }, destination: string) => {
  await sleep(3000);
  expect((await linkRow(app.sql, destination)).title).toBeNull();
});

Then("the short link to {string} has a held title fetch", async ({ app }, destination: string) => {
  const link = await linkRow(app.sql, destination);
  expect(await app.sql`SELECT short_link_id FROM held_title_fetches`).toEqual([{ short_link_id: link.id }]);
});

Then("no title fetch is held", async ({ app }) => {
  await expect.poll(async () => (await app.sql`SELECT id FROM held_title_fetches`).length).toBe(0);
});

When("the nightly link check runs", async ({ app }) => {
  const [{ before }] = await app.sql`SELECT coalesce(max(checked_at), 'epoch') AS before FROM short_link_checks`;
  await app.pushJob("Posts::Jobs::CheckPostLinks");
  await expect
    .poll(async () => (await app.sql`SELECT id FROM short_link_checks WHERE checked_at > ${before}`).length, {
      timeout: 30_000,
    })
    .toBeGreaterThan(0);
  await sleep(500);
});

When("the held title fetches job runs", async ({ app }) => {
  await app.pushJob("Shares::Jobs::QueueHeldTitleFetches");
});

When("the short link check job runs for the short link {int}", async ({ app }, id: number) => {
  await app.pushJob("Shares::Jobs::CheckShortLinkAgain", id);
  await sleep(2000);
});

Then(
  "the check of {string} counts {int} failure(s) with the reason {string}",
  async ({ app }, url: string, failures: number, reason: string) => {
    await expect
      .poll(async () => {
        const [check] = await app.sql`SELECT failures, reason FROM short_link_checks WHERE url = ${url}`;
        return check && [check.failures, check.reason];
      })
      .toEqual([failures, reason]);
  },
);

Then("the check of {string} counts no failures", async ({ app }, url: string) => {
  await expect
    .poll(async () => {
      const [check] = await app.sql`SELECT failures, reason, first_failed_at FROM short_link_checks WHERE url = ${url}`;
      return check && [check.failures, check.reason, check.first_failed_at];
    })
    .toEqual([0, null, null]);
});

Then("the check of {string} keeps the time of its first failure", async ({ app }, url: string) => {
  const [check] = await app.sql`SELECT checked_at, first_failed_at FROM short_link_checks WHERE url = ${url}`;
  expect(check.first_failed_at.getTime()).toBeLessThan(check.checked_at.getTime());
});

Then("the link checks cover only {string}", async ({ app }, urls: string) => {
  await expect
    .poll(async () => (await app.sql`SELECT url FROM short_link_checks ORDER BY url`).map((row) => row.url))
    .toEqual(urls ? urls.split(", ") : []);
});

When("I open the files", async ({ page }) => {
  await page.goto("/admin/files");
});

When("I open the files at {string}", async ({ page }, query: string) => {
  await page.goto(`/admin/files${query}`);
});

When("I open the edit page of the shared file {string}", async ({ app, page }, filename: string) => {
  await page.goto(`/admin/files/${(await fileRow(app.sql, filename)).id}/edit`);
});

When("I open the edit page of the share group", async ({ app, page }) => {
  await page.goto(`/admin/files/groups/${(await groupRow(app.sql)).id}/edit`);
});

When("I drop the files on the file drop:", async ({ page }, table: DataTable) => {
  const files = [];
  for (const row of table.hashes()) {
    const size = /^(\d+) bytes$/.exec(row.body ?? "")?.[1] ?? "";
    files.push([row.filename, size ? "" : (await bytesFor({ page }, row.body)).toString("base64"), row.type, size]);
  }
  await page.evaluate((dropped) => {
    const transfer = new DataTransfer();
    for (const [name, data, type, size] of dropped) {
      const bytes = size ? new Uint8Array(Number(size)).fill(120) : Uint8Array.from(atob(data), (c) => c.charCodeAt(0));
      transfer.items.add(new File([bytes], name, { type }));
    }
    document
      .querySelector("[data-file-drop]")
      ?.dispatchEvent(new DragEvent("drop", { bubbles: true, cancelable: true, dataTransfer: transfer }));
  }, files);
});

When("I choose the file {string} in the file picker", async ({ page }, filename: string) => {
  await page
    .getByLabel(/Drop files here/)
    .first()
    .setInputFiles({
      buffer: await bytesFor({ page }, "a 30 by 30 png"),
      mimeType: "image/png",
      name: filename,
    });
});

When("I watch the clipboard", async ({ page }) => {
  await page.evaluate(() => {
    const copied: string[] = [];
    Object.assign(window, { copiedKeys: copied });
    navigator.clipboard.writeText = async (text) => {
      copied.push(text);
    };
    navigator.clipboard.write = async (items) => {
      for (const item of items) copied.push(await (await item.getType("text/plain")).text());
    };
  });
});

Then("the clipboard got {string}", async ({ app, page }, text: string) => {
  const wanted = text ? await Promise.all(text.split(" then ").map((part) => expand(app.sql, part))) : [];
  await expect
    .poll(() => page.evaluate(() => (window as unknown as { copiedKeys: string[] }).copiedKeys))
    .toEqual(wanted);
});

When("I open the file card {string}", async ({ page }, name: string) => {
  await page.locator(".file-card", { hasText: name }).first().click();
});

When("I set the file drawer field {string} to {string}", async ({ page }, label: string, text: string) => {
  await page.locator("dialog[open]").getByLabel(label, { exact: true }).fill(text);
});

When("I click {string} in the file drawer", async ({ page }, name: string) => {
  await page.locator("dialog[open]").getByRole("button", { exact: true, name }).click();
});

When("I close the file drawer", async ({ page }) => {
  await page.keyboard.press("Escape");
});

When("I tick the file card {string}", async ({ page }, name: string) => {
  await page.getByLabel(`Tick ${name}`, { exact: true }).check();
});

When("I click {string} on the grouped file {string}", async ({ page }, label: string, name: string) => {
  const item = page.locator("dialog[open] .file-group-item", { hasText: name });
  await item.hover();
  await item.getByLabel(label, { exact: true }).click();
});

When("I confirm in the file drawer", async ({ page }) => {
  await page.locator("dialog[open] [data-confirm-accept]").click();
});

When("I pick the share group {string} to add to", async ({ app, page }, code: string) => {
  await page.locator("form#files-bulk select[name='group_id']").selectOption({ label: await expand(app.sql, code) });
});

Then("the file cards read {string}", async ({ page }, names: string) => {
  await expect(page.locator(".file-card-name")).toHaveText(names ? names.split(", ") : []);
});

Then("the file card {string} reads {string}", async ({ app, page }, name: string, text: string) => {
  await expect(page.locator(".file-card", { hasText: name }).first()).toContainText(await expand(app.sql, text));
});

Then("the file drawer reads {string}", async ({ app, page }, text: string) => {
  await expect(page.locator("dialog[open]")).toContainText(await expand(app.sql, text));
});

Then("the file drawer field {string} holds {string}", async ({ app, page }, label: string, text: string) => {
  await expect(page.locator("dialog[open]").getByLabel(label, { exact: true })).toHaveValue(
    await expand(app.sql, text),
  );
});

Then("the file drawer has no field {string}", async ({ page }, label: string) => {
  await expect(page.locator("dialog[open]").getByLabel(label, { exact: true })).toHaveCount(0);
});

Then("the file card thumbnail of {string} shows {string}", async ({ app, page }, name: string, source: string) => {
  const thumb = page.locator(".file-card", { hasText: name }).first().locator("img.file-card-thumb");
  await expect(thumb).toHaveAttribute("src", await expand(app.sql, source));
});

Then("the shared file {string} is named {string}", async ({ app }, from: string, to: string) => {
  const [file] = await app.sql`SELECT filename FROM share_group_files WHERE filename IN (${from}, ${to})`;
  expect(file.filename).toBe(to);
});

Then("the shared file {string} has the alt text {string} stored", async ({ app }, filename: string, text: string) => {
  expect((await fileRow(app.sql, filename)).alt_text).toBe(text || null);
});

Then("the shared file {string} sits in the share group", async ({ app }, filename: string) => {
  const file = await fileRow(app.sql, filename);
  expect([file.share_group_id, file.short_code_id]).toEqual([(await groupRow(app.sql)).id, null]);
});

Then("the shared file {string} stands alone", async ({ app }, filename: string) => {
  const file = await fileRow(app.sql, filename);
  expect(file.share_group_id).toBeNull();
  expect(file.code).toBeTruthy();
});

Then("there is/are {int} share group(s)", async ({ app }, count: number) => {
  expect((await app.sql`SELECT id FROM share_groups`).length).toBe(count);
});

Then("the share group is named {string} in the store", async ({ app }, name: string) => {
  expect((await groupRow(app.sql)).name).toBe(name || null);
});

Then("the short code {string} is free", async ({ app }, code: string) => {
  expect(await app.sql`SELECT id FROM short_codes WHERE code = ${code}`).toEqual([]);
});

Then("the share page is titled {string}", async ({ page }, title: string) => {
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(title);
  await expect(page).toHaveTitle(new RegExp(`^${RegExp.escape(title)} \\|`));
});

Then("the share page carousel shows the images {string}", async ({ page }, alts: string) => {
  const images = page.locator(".carousel img");
  await expect(images).toHaveCount(alts.split(", ").length);
  expect(await images.evaluateAll((all) => all.map((image) => image.getAttribute("alt")))).toEqual(alts.split(", "));
});

Then("the share page carousel links {string} as {word}", async ({ app, page }, paths: string, what: string) => {
  const [selector, attribute] = what === "sources" ? [".carousel img", "src"] : [".carousel a", "href"];
  const found = await page
    .locator(selector)
    .evaluateAll((all, name) => all.map((one) => one.getAttribute(name)), attribute);
  expect(found).toEqual(await Promise.all(paths.split(", ").map((path) => expand(app.sql, path))));
});

Then("the share page lists the files {string}", async ({ app, page }, files: string) => {
  const found = await page
    .locator(".files a")
    .evaluateAll((all) => all.map((link) => `${link.textContent?.trim()} ${link.getAttribute("href")}`));
  expect(found).toEqual(await Promise.all(files.split(", ").map((file) => expand(app.sql, file))));
});

Then("the share page offers {string} at {string}", async ({ app, page }, name: string, path: string) => {
  await expect(page.getByRole("link", { name })).toHaveAttribute("href", await expand(app.sql, path));
});

Given("the page {string} has a title that runs past 200 characters", ({ app }, url: string) => {
  app.stub.reply("GET", url, { body: `<title>bad&#7;bell ${"word ".repeat(100)}</title>`, status: 200 });
});

When("the title fetch job runs for the short link {int}", async ({ app }, id: number) => {
  await app.pushJob("Shares::Jobs::FetchShortLinkTitle", id);
  await sleep(2000);
});

Given("{int} shares stored straight in the database", async ({ app }, count: number) => {
  for (let index = 0; index < count; index++) {
    const [{ id }] = await app.sql`INSERT INTO short_codes ${app.sql({ code: `s${index}` })} RETURNING id`;
    const file = { byte_size: 1, content_type: "text/plain", filename: `s${index}.txt`, short_code_id: id };
    await app.sql`INSERT INTO share_group_files ${app.sql({ ...file, key: randomBytes(16).toString("hex") })}`;
  }
});

Given("{int} share groups stored straight in the database", async ({ app }, count: number) => {
  for (let index = 0; index < count; index++) {
    const [{ id }] = await app.sql`INSERT INTO short_codes ${app.sql({ code: `g${index}` })} RETURNING id`;
    const [group] = await app.sql`INSERT INTO share_groups ${app.sql({ short_code_id: id })} RETURNING id`;
    const file = { byte_size: 1, content_type: "text/plain", filename: `g${index}.txt`, share_group_id: group.id };
    await app.sql`INSERT INTO share_group_files ${app.sql({ ...file, key: randomBytes(16).toString("hex") })}`;
  }
});

Then("the share tool refused", ({ answer }) => {
  expect(answer.error, answer.body).toBe(true);
});

Then("the share tool refuses with words {string}", ({ answer }, words: string) => {
  expect(answer.error).toBe(true);
  expect(answer.body).toContain(words);
});

Then("the files page tabs link {string}", async ({ page }, paths: string) => {
  const found = await page
    .locator(".screen-tabs a.screen-tab")
    .evaluateAll((all) => all.map((a) => a.getAttribute("href")));
  expect(found).toEqual(paths.split(", "));
});

Then("the file card {string} opens {string} in a new tab", async ({ app, page }, name: string, link: string) => {
  const opener = page.getByRole("link", { name: `Open ${name}` });
  await expect(opener).toHaveAttribute("href", await expand(app.sql, link));
  await expect(opener).toHaveAttribute("target", "_blank");
});

Then("the file card thumbnail of {string} reads the alt text {string}", async ({ page }, name: string, alt: string) => {
  const thumb = page.locator(".file-card", { hasText: name }).first().locator("img.file-card-thumb");
  await expect(thumb).toHaveAttribute("alt", alt);
});

Then("the file filter keeps the search {string}", async ({ page }, search: string) => {
  await expect(page.locator("form:has([type=radio][name=kind]) input[type=hidden][name=search]")).toHaveValue(search);
});

Then("the files box {string} is unticked", async ({ page }, label: string) => {
  await expect(page.getByLabel(label, { exact: true })).not.toBeChecked();
});

When("I tick the files box {string}", async ({ page }, label: string) => {
  await page.getByLabel(label, { exact: true }).check();
});

When("I post to {string} from the files page with:", async ({ answer, app, page }, path: string, table: DataTable) => {
  const form: Record<string, string> = {};
  for (const [name, value] of table.raw()) {
    const text = (await expand(app.sql, value)).replace(/\\u([0-9a-f]{4})/g, (_, hex) =>
      String.fromCharCode(Number.parseInt(hex, 16)),
    );
    form[await expand(app.sql, name)] = text;
  }
  const token = await page.locator("input[name=_csrf_token]").first().inputValue();
  const response = await page.request.post(await expand(app.sql, path), { form: { ...form, _csrf_token: token } });
  answer.status = response.status();
  answer.body = await response.text();
});

When("I post to {string} from the files page", async ({ answer, app, page }, path: string) => {
  const token = await page.locator("input[name=_csrf_token]").first().inputValue();
  const response = await page.request.post(await expand(app.sql, path), { form: { _csrf_token: token } });
  answer.status = response.status();
  answer.body = await response.text();
});

When("I upload no file to the files page", async ({ answer, page }) => {
  const token = await page.locator("input[name=_csrf_token]").first().inputValue();
  const response = await page.request.post("/admin/files", {
    headers: { Accept: "application/json", "X-CSRF-Token": token },
    multipart: { group: "0" },
  });
  answer.status = response.status();
  answer.body = await response.text();
});

When("I send the files page an upload that claims {int} bytes", async ({ answer, app, context }, size: number) => {
  const cookie = (await context.cookies()).map(({ name, value }) => `${name}=${value}`).join("; ");
  answer.status = await new Promise<number>((done, fail) => {
    const url = new URL("/admin/files", app.url);
    const sent = httpRequest(url, {
      headers: { "Content-Length": size, "Content-Type": "multipart/form-data; boundary=x", Cookie: cookie },
      method: "POST",
    });
    sent.on("response", (response) => done(response.statusCode ?? 0));
    sent.on("error", fail);
    sent.write("--x\r\n");
  });
});

Then("the files page answers {int}", ({ answer }, status: number) => {
  expect(answer.status, answer.body.slice(0, 500)).toBe(status);
});

Then("the files page says {string}", async ({ answer, app }, text: string) => {
  expect(answer.body.replaceAll("&#39;", "'")).toContain(await expand(app.sql, text));
});

Then("the file drawer asks {string}", async ({ page }, text: string) => {
  await expect(page.locator("[data-confirm-message]")).toHaveText(text);
});

Then("the shared file {string} is {int} bytes", async ({ app }, filename: string, size: number) => {
  await expect
    .poll(async () =>
      Number((await app.sql`SELECT byte_size FROM share_group_files WHERE filename = ${filename}`)[0]?.byte_size),
    )
    .toBe(size);
});

Then("the file field {string} is marked wrong", async ({ page }, label: string) => {
  await expect(page.getByLabel(label, { exact: true }).first()).toHaveAttribute("aria-invalid", "true");
});

When(
  "I set the {string} of the grouped file {string} to {string}",
  async ({ page }, label: string, name: string, text: string) => {
    await page
      .locator("dialog[open] .file-group-item", { hasText: name })
      .getByLabel(label, { exact: true })
      .fill(text);
  },
);

Then("the grouped file {string} reads {string}", async ({ page }, name: string, text: string) => {
  await expect(page.locator("dialog[open] .file-group-item", { hasText: name })).toContainText(text);
});

Then(
  "the file drawer for the group has {int} name field(s) and {int} alt text field(s)",
  async ({ page }, names: number, alts: number) => {
    const drawer = page.locator("dialog[open]");
    await expect(drawer.getByLabel("File name", { exact: true })).toHaveCount(names);
    await expect(drawer.getByLabel("Alt text", { exact: true })).toHaveCount(alts);
  },
);

Then("the shared file {string} has the code {string} still", async ({ app }, filename: string, code: string) => {
  expect((await fileRow(app.sql, filename)).code).toBe(code);
});

async function bulkPost({ answer, page }: Pick<World, "answer" | "page">, act: string, ids: string, group?: string) {
  const token = await page.locator("input[name=_csrf_token]").first().inputValue();
  const form = new URLSearchParams({ _csrf_token: token, act });
  for (const id of ids.split(", ").filter(Boolean)) form.append("ids[]", id);
  if (group !== undefined) form.append("group_id", group);
  const response = await page.request.post("/admin/files/bulk", {
    data: form.toString(),
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
  });
  answer.status = response.status();
  answer.body = await response.text();
}

async function addToGroup(
  { answer, page }: Pick<World, "answer" | "page">,
  filename: string,
  body: string,
  id: string,
) {
  const token = await page.locator("input[name=_csrf_token]").first().inputValue();
  const response = await page.request.post("/admin/files", {
    headers: { "X-CSRF-Token": token },
    multipart: { "files[]": { buffer: Buffer.from(body), mimeType: "application/pdf", name: filename }, group_id: id },
  });
  answer.status = response.status();
  answer.body = await response.text();
}

When("I post the bulk form to group the files {string}", ({ answer, page }, ids: string) =>
  bulkPost({ answer, page }, "group", ids),
);

When(
  "I post the bulk form to add the files {string} to the group {string}",
  ({ answer, page }, ids: string, group: string) => bulkPost({ answer, page }, "add", ids, group),
);

When(
  "I add the file {string} holding {string} to the share group",
  async ({ answer, app, page }, filename: string, body: string) =>
    addToGroup({ answer, page }, filename, body, String((await groupRow(app.sql)).id)),
);

When(
  "I add the file {string} holding {string} to the share group {int}",
  ({ answer, page }, filename: string, body: string, id: number) =>
    addToGroup({ answer, page }, filename, body, String(id)),
);

Then("the bulk form offers the share group {string}", async ({ app, page }, code: string) => {
  await expect(page.locator("select[name='group_id'] option", { hasText: await expand(app.sql, code) })).toHaveCount(1);
});

Then(
  "the share store holds the file {string} as the base64 {string}",
  async ({ app }, filename: string, data: string) => {
    const stored = app.stub.objects.get(`shares/${(await fileRow(app.sql, filename)).key}`);
    expect(stored?.body.toString("base64")).toBe(data);
  },
);

Then("the share upload left the photo store and the photos table alone", async ({ app }) => {
  expect([...app.stub.objects.keys()].filter((key) => key.startsWith("photos/"))).toEqual([]);
  expect(await app.sql`SELECT id FROM photos`).toEqual([]);
});

Then("the short link to {string} has the code {string}", async ({ app }, destination: string, code: string) => {
  expect((await linkRow(app.sql, destination)).code).toBe(code);
});

Then(
  "the open icon of the file card {string} turns the accent color when I hover it",
  async ({ page }, name: string) => {
    const opener = page.getByRole("link", { name: `Open ${name}` });
    await opener.hover();
    const accent = await page.evaluate(() => {
      const probe = document.body.appendChild(document.createElement("span"));
      probe.style.color = "var(--color-accent-text)";
      const color = getComputedStyle(probe).color;
      probe.remove();
      return color;
    });
    await expect(opener.locator("i")).toHaveCSS("color", accent);
  },
);

Then("the grouped file {string} offers {string}", async ({ page }, name: string, label: string) => {
  await expect(
    page.locator("dialog[open] .file-group-item", { hasText: name }).getByLabel(label, { exact: true }),
  ).toHaveCount(1);
});

const storeDown = { body: "", status: 500 };

Given("the share store fails every {word}", ({ app }, method: string) => {
  app.stub.reply(method, "/s3/shares/*", storeDown);
});

Given("the share store fails every {word} after the first", ({ app }, method: string) => {
  let seen = 0;
  app.stub.reply(method, "/s3/shares/*", () => (seen++ ? storeDown : undefined) as unknown as typeof storeDown);
});

Given(
  "the share store fails the {word} of the shared file {string}",
  async ({ app }, method: string, filename: string) => {
    app.stub.reply(method, `/s3/shares/${(await fileRow(app.sql, filename)).key}`, storeDown);
  },
);

Then("the share group holds {int} file(s)", async ({ app }, count: number) => {
  const group = await groupRow(app.sql);
  expect(await app.sql`SELECT id FROM share_group_files WHERE share_group_id = ${group.id}`).toHaveLength(count);
});
