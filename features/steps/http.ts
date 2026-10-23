import { readFile } from "node:fs/promises";
import { type IncomingHttpHeaders, request } from "node:http";
import { join } from "node:path";
import { type BrowserContext, expect } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { createBdd, defineParameterType } from "playwright-bdd";
import { fill } from "../support/api.ts";
import { formValue } from "../support/http.ts";
import { root } from "../support/shell.ts";
import { Given, Then, test, When } from "../support/world.ts";

const { Before } = createBdd(test);

defineParameterType({ name: "verb", regexp: /get|post|put|patch|delete/, transformer: (verb: string) => verb });

type Reply = { body: string; headers: Record<string, string>; raw: Buffer; status: number };

let reply: Reply = { body: "", headers: {}, raw: Buffer.alloc(0), status: 0 };
let site = "";
let sent: Record<string, string | null> = {};
let asked = "";
let kept = "";

async function ask(
  { app, context }: { app: { url: string }; context: BrowserContext },
  method: string,
  path: string,
  { body, headers = {} }: { body?: string | Buffer; headers?: Record<string, string | null> } = {},
) {
  const base = site || app.url;
  const resolved = await assetPaths(base, path);
  asked = resolved;
  const url = new URL(resolved.startsWith("http") ? resolved : `${base}${resolved}`);
  const jar = (await context.cookies(url.href)).map(({ name, value }) => `${name}=${value}`).join("; ");
  const all: Record<string, string | null> = { Accept: "*/*", ...(jar ? { Cookie: jar } : {}), ...sent, ...headers };
  const chosen = Object.fromEntries(Object.entries(all).filter(([, value]) => value !== null)) as Record<
    string,
    string
  >;
  if (body !== undefined && !("Content-Length" in all)) chosen["Content-Length"] = String(Buffer.byteLength(body));
  let answered = false;
  const [status, received, raw] = await new Promise<[number, IncomingHttpHeaders, Buffer]>((done, fail) => {
    const sending = request(
      { headers: chosen, host: url.hostname, method, path: `${url.pathname}${url.search}`, port: url.port },
      (response) => {
        answered = true;
        const chunks: Buffer[] = [];
        response.on("data", (chunk) => chunks.push(chunk));
        response.on("end", () => done([response.statusCode ?? 0, response.headers, Buffer.concat(chunks)]));
      },
    );
    sending.on("error", (error) => answered || fail(error));
    sending.end(body);
  });
  for (const line of [received["set-cookie"] ?? []].flat()) await keepCookie(context, url, line);
  const flat = Object.fromEntries(Object.entries(received).map(([name, value]) => [name, [value].flat().join(", ")]));
  reply = { body: raw.toString("utf8"), headers: flat, raw, status };
  return reply;
}

async function keepCookie(context: BrowserContext, url: URL, line: string) {
  const [pair, ...attributes] = line.split(";").map((part) => part.trim());
  const [name, ...rest] = pair.split("=");
  const value = rest.join("=");
  const gone = !value || attributes.some((part) => /^max-age=0$/i.test(part) || /^expires=.*1970/i.test(part));
  if (gone) return context.clearCookies({ name });
  await context.addCookies([{ name, url: url.origin, value }]);
}

Before(() => {
  reply = { body: "", headers: {}, raw: Buffer.alloc(0), status: 0 };
  site = "";
  sent = {};
});

let manifest: Record<string, { url: string }> | undefined;

export async function assetPaths(base: string, text: string) {
  text = text.replaceAll("{site}", base);
  if (!text.includes("{asset:")) return text;
  manifest ??= await (await fetch(`${base}/assets/assets.json`)).json();
  return text.replaceAll(/\{asset:([^}]+)\}/g, (_, source: string) => manifest?.[source]?.url ?? `missing ${source}`);
}

export const sendHeader = (name: string, value: string) => {
  sent = { ...sent, [name]: value };
};

export const lastReply = () => reply;
export const useSite = (url: string) => {
  site = url;
};
export { ask };

Given("my requests send the header {string} as {string}", async ({ app }, name: string, value: string) => {
  sent = { ...sent, [name]: await assetPaths(site || app.url, value) };
});

Given("my requests send no {string} header", ({}, name: string) => {
  sent = { ...sent, [name]: null };
});

Given(/^my requests (?:send|carry) the cookie "([^"]*)"$/, ({}, cookie: string) => {
  sent = { ...sent, Cookie: cookie };
});

When("I request {string}", async ({ app, context }, path: string) => {
  await ask({ app, context }, "GET", path);
});

When("I request {string} with the header {string} set to {string}", async ({ app, context }, path, name, value) => {
  await ask({ app, context }, "GET", path, { headers: { [name]: value } });
});

When("I request {string} again with the ETag it gave", async ({ app, context }, path: string) => {
  await ask({ app, context }, "GET", path, { headers: { "If-None-Match": reply.headers.etag ?? "" } });
});

When(
  "I {verb} {string} with the {string} body:",
  async ({ app, context }, method: string, path, type, body: string) => {
    await ask({ app, context }, method.toUpperCase(), path, { body, headers: { "Content-Type": type } });
  },
);

When(
  "I {verb} {string} with the {string} body {string}",
  async ({ app, context }, method: string, path, type, text: string) => {
    const target = encodeURIComponent(`${site || app.url}/writing/hello`);
    const long = encodeURIComponent(`https://a.example/${"a".repeat(3000 - "https://a.example/".length)}`);
    const body = text
      .replace("TARGET", target)
      .replace("SITE", encodeURIComponent(site || app.url))
      .replace("LONG", long);
    await ask({ app, context }, method.toUpperCase(), path, { body, headers: { "Content-Type": type } });
  },
);

When("I {verb} the form {string}", async ({ app, context }, method: string, path: string) => {
  await ask({ app, context }, method.toUpperCase(), path, {
    body: "",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
  });
});

When("I {verb} the form {string} with:", async ({ app, context }, method: string, path: string, table: DataTable) => {
  const base = site || app.url;
  const values = await Promise.all(table.raw().map(async ([name, value]) => [name, await assetPaths(base, value)]));
  const body = new URLSearchParams(values).toString();
  await ask({ app, context }, method.toUpperCase(), path, {
    body,
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
  });
});

When(
  "I {verb} the form {string} with my token and:",
  async ({ app, context }, method: string, path, table: DataTable) => {
    const token = await csrfToken({ app, context });
    const body = new URLSearchParams([["_csrf_token", token], ...table.raw().map(([n, v]) => [n, v])]).toString();
    await ask({ app, context }, method.toUpperCase(), path, {
      body,
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
    });
  },
);

When(
  "I {verb} the form {string} with the token from {string} and:",
  async ({ app, context }, method: string, path: string, from: string, table: DataTable) => {
    const token = await csrfToken({ app, context }, from);
    const body = new URLSearchParams([...table.raw().map(([n, v]) => [n, v.replace("{token}", token)])]).toString();
    await ask({ app, context }, method.toUpperCase(), path, {
      body,
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
    });
  },
);

When("I {verb} the form {string} with my token", async ({ app, context }, method: string, path: string) => {
  const body = new URLSearchParams([["_csrf_token", await csrfToken({ app, context })]]).toString();
  await ask({ app, context }, method.toUpperCase(), path, {
    body,
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
  });
});

async function csrfToken({ app, context }: { app: { url: string }; context: BrowserContext }, from = "/admin") {
  const [before, beforeAsked] = [reply, asked];
  const { body } = await ask({ app, context }, "GET", from);
  [reply, asked] = [before, beforeAsked];
  return body.match(/<input[^>]*name="_csrf_token"[^>]*>/)?.[0].match(/value="([^"]+)"/)?.[1] ?? "";
}

Then("it answers {int}", ({}, status: number) => {
  expect(reply.status, reply.body.slice(0, 500)).toBe(status);
});

Then("it answers {int} or more", ({}, status: number) => {
  expect(reply.status, reply.body.slice(0, 500)).toBeGreaterThanOrEqual(status);
});

Then("it redirects to {string}", ({}, location: string) => {
  expect([301, 302, 303, 307, 308]).toContain(reply.status);
  expect(new URL(reply.headers.location ?? "", "http://site").href.replace("http://site", "")).toBe(
    location.startsWith("http") ? location : new URL(location, "http://site").href.replace("http://site", ""),
  );
});

Then("it redirects to a path ending in {string}", ({}, end: string) => {
  expect([301, 302, 303, 307, 308]).toContain(reply.status);
  expect(reply.headers.location ?? "").toMatch(new RegExp(`${end.replace(/[.?*+^$[\]\\(){}|-]/g, "\\$&")}$`));
});

Then("the {string} header is {string}", ({}, name: string, value: string) => {
  expect(reply.headers[name.toLowerCase()]).toBe(value);
});

Then("the {string} header starts with {string}", ({}, name: string, value: string) => {
  expect(reply.headers[name.toLowerCase()] ?? "").toMatch(
    new RegExp(`^${value.replace(/[.?*+^$[\]\\(){}|-]/g, "\\$&")}`),
  );
});

Then("the {string} header includes {string}", ({}, name: string, value: string) => {
  expect(reply.headers[name.toLowerCase()] ?? "").toContain(value);
});

Then("the {string} header does not include {string}", ({}, name: string, value: string) => {
  expect(reply.headers[name.toLowerCase()] ?? "").not.toContain(value);
});

Then("there is no {string} header", ({}, name: string) => {
  expect(reply.headers[name.toLowerCase()]).toBeUndefined();
});

Then("the body includes {string}", async ({ app }, text: string) => {
  expect(reply.body).toContain(await assetPaths(app.url, text));
});

Then("the body does not include {string}", ({}, text: string) => {
  expect(reply.body).not.toContain(text);
});

Then("the body includes:", ({}, text: string) => {
  expect(reply.body).toContain(text);
});

Then("the body is:", ({}, text: string) => {
  expect(reply.body).toBe(text);
});

const pattern = (text: string) => (text.startsWith("(?i)") ? new RegExp(text.slice(4), "i") : new RegExp(text));

Then("the body matches {string}", ({}, text: string) => {
  expect(reply.body).toMatch(pattern(text));
});

Then("the body does not match {string}", ({}, text: string) => {
  expect(reply.body).not.toMatch(pattern(text));
});

Then("the JSON answer holds {string} as {string}", async ({ app }, key: string, wanted: string) => {
  const value = await assetPaths(app.url, wanted);
  const found = key
    .split(".")
    .reduce((at: unknown, part) => (at as Record<string, unknown>)?.[part], JSON.parse(reply.body));
  expect(typeof found === "string" ? found : JSON.stringify(found)).toBe(value);
});

Then("the body is the file {string}", async ({}, path: string) => {
  expect(reply.raw.equals(await readFile(join(root, path)))).toBe(true);
});

Then("the path I asked for matches {string}", ({}, pattern: string) => {
  expect(asked).toMatch(new RegExp(pattern));
});

Then("the body carries my admin token", async ({ app, context }) => {
  const token = await csrfToken({ app, context });
  expect(token).not.toBe("");
  expect(reply.body).toContain(token);
});

When("I keep the body", () => {
  kept = reply.body;
});

Then("the body matches the one I kept", () => {
  expect(reply.body).toBe(kept);
});

Then(
  "each of these paths answers {int} with the {string} header {string}:",
  async ({ app, context }, status: number, name: string, value: string, table: DataTable) => {
    const seen = [];
    for (const [path] of table.raw()) {
      const { headers, status: got } = await ask({ app, context }, "GET", path);
      seen.push([path, got, headers[name.toLowerCase()]]);
    }
    expect(seen).toEqual(table.raw().map(([path]) => [path, status, value]));
  },
);

Then("every POST form on the page carries my admin token once", async ({ app, context, page }) => {
  const token = await csrfToken({ app, context });
  const forms = await page
    .locator("form[method='post']")
    .evaluateAll((all) =>
      all.map((form) =>
        [...form.querySelectorAll("input[name='_csrf_token']")].map((input) => (input as HTMLInputElement).value),
      ),
    );
  expect(forms.length).toBeGreaterThan(0);
  expect(forms).toEqual(forms.map(() => [token]));
});

async function signOutFromMenu(world: Parameters<typeof ask>[0], path: string, returnTo?: string) {
  const { body } = await ask(world, "GET", path);
  const form = body.match(/<form[^>]*action="\/admin\/sign-out"[^>]*>([\s\S]*?)<\/form>/)?.[1] ?? "";
  const fields = [...form.matchAll(/<input[^>]*>/g)].map(([input]) => [
    input.match(/name="([^"]*)"/)?.[1] ?? "",
    (input.match(/value="([^"]*)"/)?.[1] ?? "").replaceAll("&amp;", "&").replaceAll("&quot;", '"'),
  ]);
  const values = new URLSearchParams(fields);
  if (returnTo !== undefined) values.set("return_to", returnTo.replaceAll("\\r", "\r"));
  await ask(world, "POST", "/admin/sign-out", {
    body: values.toString(),
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
  });
}

When("I sign out from the menu on {string}", async ({ app, context }, path: string) => {
  await signOutFromMenu({ app, context }, path);
});

When("I sign out from the menu on {string} returning to {string}", async ({ app, context }, path, returnTo) => {
  await signOutFromMenu({ app, context }, path, returnTo);
});

When("I submit the form {string}", async ({ page }, selector: string) => {
  await Promise.all([
    page.waitForEvent("framenavigated"),
    page.locator(selector).evaluate((form) => (form as HTMLFormElement).requestSubmit()),
  ]);
});

When(
  "I post the file {string} of type {string} holding the bytes {string} as {string} to {string}",
  async ({ app, context }, filename: string, type: string, hex: string, field: string, path: string) => {
    const boundary = "featuresboundary";
    const body = Buffer.concat([
      Buffer.from(
        `--${boundary}\r\nContent-Disposition: form-data; name="${field}"; filename="${filename}"\r\nContent-Type: ${type}\r\n\r\n`,
      ),
      Buffer.from(hex.replaceAll(" ", ""), "hex"),
      Buffer.from(`\r\n--${boundary}--\r\n`),
    ]);
    await ask({ app, context }, "POST", path, {
      body,
      headers: { "Content-Type": `multipart/form-data; boundary=${boundary}` },
    });
  },
);

When(
  "I post a form field {string} of {int} bytes to {string}",
  async ({ app, context }, name: string, size: number, path) => {
    await ask({ app, context }, "POST", path, {
      body: `${name}=${"a".repeat(size)}`,
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
    });
  },
);

Then("it answers an error page for {int}", ({}, status: number) => {
  expect(reply.status).toBe(status);
  expect(reply.headers["content-type"]).toMatch(/^text\/html/);
  expect(reply.headers["cache-control"]).toBeUndefined();
  expect(reply.body).toMatch(/<title>[^<]*Aaron Allen<\/title>/);
  expect(reply.body).toMatch(/<header>\s*<a href="\/">Aaron Allen<\/a>/);
  expect(reply.body).toMatch(/<main>[\s\S]*<a href="\/">/);
  expect(reply.body).not.toMatch(/\ssrc=|<link[^>]*href=|<object|<iframe|url\(|@import/);
});

When(
  "I {verb} the form {string} with my token and the body {string}",
  async ({ app, context }, method: string, path, body) => {
    const token = await csrfToken({ app, context });
    await ask({ app, context }, method.toUpperCase(), path, {
      body: `_csrf_token=${encodeURIComponent(token)}&${body}`,
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
    });
  },
);

When("I request the task {string} with {string}", async ({ app, context }, title: string, query: string) => {
  const [task] = await app.sql`SELECT id FROM tasks WHERE title = ${title}`;
  await ask({ app, context }, "GET", `/admin/tasks/${task.id}${query}`);
});

Then("the JSON answer's {string} names only {string}", ({}, key: string, names: string) => {
  expect(Object.keys(JSON.parse(reply.body)[key] ?? {})).toEqual(names.split(", "));
});

When("I visit the task {string} with {string}", async ({ app, page }, title: string, query: string) => {
  const [task] = await app.sql`SELECT id FROM tasks WHERE title = ${title}`;
  await page.goto(`/admin/tasks/${task.id}${query}`);
});

const megabytes = (text: string) => {
  const [, count, extra] = text.match(/^([\d.]+) MB( and a byte| less a kilobyte)?$/) ?? [];
  return Math.floor(Number(count) * 1024 * 1024) + (extra === " and a byte" ? 1 : extra ? -1024 : 0);
};

const rpc = (size: number) =>
  JSON.stringify({ id: 1, jsonrpc: "2.0", method: "tools/list", params: { note: "a".repeat(Math.max(size, 0)) } });

When("I post a JSON body of {string} to {string}", async ({ app, context }, size: string, path: string) => {
  await ask({ app, context }, "POST", path, {
    body: rpc(megabytes(size)),
    headers: { "Content-Type": "application/json" },
  });
});

When("I post a form of {string} to {string} with no declared length", async ({ app, context }, size: string, path) => {
  await ask({ app, context }, "POST", path, {
    body: `message[body]=${"a".repeat(megabytes(size))}`,
    headers: { "Content-Length": null, "Content-Type": "application/x-www-form-urlencoded" },
  });
});

When(
  "I post a file of {string} as {string} to {string}",
  async ({ app, context }, size: string, field: string, path) => {
    const boundary = "featuresboundary";
    const body = Buffer.concat([
      Buffer.from(
        `--${boundary}\r\nContent-Disposition: form-data; name="${field}"; filename="a.jpg"\r\nContent-Type: image/jpeg\r\n\r\n`,
      ),
      Buffer.alloc(megabytes(size), "a"),
      Buffer.from(`\r\n--${boundary}--\r\n`),
    ]);
    await ask({ app, context }, "POST", path, {
      body,
      headers: { "Content-Type": `multipart/form-data; boundary=${boundary}` },
    });
  },
);

Then("every font face in the sheet loads from the site", () => {
  const sources = (reply.body.match(/@font-face\s*{[^}]*}/g) ?? []).flatMap((face) =>
    [...face.matchAll(/url\(\s*["']?([^"')]+)/g)].map(([, source]) => source),
  );
  expect(sources.length).toBeGreaterThan(0);
  expect(sources.filter((source) => !source.startsWith("../"))).toEqual([]);
});

Then("the JSON answer is:", async ({ app }, json: string) => {
  expect(JSON.parse(reply.body)).toEqual(JSON.parse(await assetPaths(app.url, json)));
});

Then("the body starts with:", async ({ app }, text: string) => {
  expect(reply.body.startsWith(await assetPaths(app.url, text))).toBe(true);
});

export const replyPage = (target: string, author = "Ada") => `
  <div class="h-entry">
    <a class="p-author h-card" href="http://203.0.113.5/about">${author}</a>
    <a class="u-in-reply-to" href="${target}">re</a>
    <p class="e-content">Nice post</p>
  </div>`;

const mention = (
  world: Parameters<typeof ask>[0] & { stub: import("../support/stub.ts").Stub },
  source: string,
  target: string,
  headers: Record<string, string> = {},
) => {
  world.stub.reply("GET", source.replace(/#.*$/, ""), { body: replyPage(target), status: 200 });
  return ask(world, "POST", "/webmention", {
    body: new URLSearchParams({ source, target }).toString(),
    headers: { "Content-Type": "application/x-www-form-urlencoded", ...headers },
  });
};

When(
  "I send a webmention to the post {string} from each of:",
  async ({ app, context, stub }, title: string, table: DataTable) => {
    const [post] = await app.sql`SELECT slug FROM posts WHERE title = ${title}`;
    for (const [source] of table.raw())
      await mention({ app, context, stub }, source, `${site || app.url}/writing/${post.slug}`);
  },
);

When(
  "I send {int} webmentions to the post {string}, each from a new browser",
  async ({ app, context, stub }, count: number, title: string) => {
    const [post] = await app.sql`SELECT slug FROM posts WHERE title = ${title}`;
    for (let index = 0; index < count; index++) {
      await mention(
        { app, context, stub },
        `http://203.0.113.5/notes/${index}`,
        `${site ? "https://aaronmallen.me" : app.url}/writing/${post.slug}`,
        {
          "User-Agent": `Mozilla/5.0 x${index}`,
        },
      );
    }
  },
);

When(
  "I send {int} webmentions to the post {string} from the addresses {string} in production",
  async ({ app, context, stub }, count: number, title: string, pattern: string) => {
    const [post] = await app.sql`SELECT slug FROM posts WHERE title = ${title}`;
    for (let index = 0; index < count; index++) {
      await mention(
        { app, context, stub },
        `http://203.0.113.5/notes/${index}`,
        `https://aaronmallen.me/writing/${post.slug}`,
        {
          "CF-Connecting-IP": pattern.replace("N", String(index + 1)),
        },
      );
    }
  },
);

When("{string} sends a webmention for {string}", async ({ app, context, stub }, source: string, target: string) => {
  await mention({ app, context, stub }, source, await assetPaths(site || app.url, target));
});

When("I send a HEAD to {string}", async ({ app, context }, path: string) => {
  await ask({ app, context }, "HEAD", path);
});

Then("the {string} header matches the pattern {string}", ({}, name: string, text: string) => {
  expect(reply.headers[name.toLowerCase()] ?? "").toMatch(new RegExp(text));
});

Then("the only email addresses in the body are {string}", ({}, addresses: string) => {
  expect([...new Set(reply.body.match(/[\w.+-]+@[\w-]+\.[a-z]{2,}/gi) ?? [])]).toEqual(addresses.split(", "));
});

When("I load the body I kept into the page", async ({ page }) => {
  await page.route("**/contact-kept", (route) => route.fulfill({ body: kept, contentType: "text/html" }));
  await page.goto("/contact-kept");
});

When("I load the body I kept into the page after keeping it", async ({ page }) => {
  kept = reply.body;
  await page.route("**/contact-kept", (route) => route.fulfill({ body: kept, contentType: "text/html" }));
  await page.goto("/contact-kept");
});

When("I send {word} {string}", async ({ http }, method: string, path: string) => {
  await http.send(method, fill(http, path));
});

When("I send {word} {string} as {string}", async ({ http }, method: string, path: string, as: string) => {
  await http.send(method, path, { as });
});

When("I post to {string}", async ({ http }, path: string) => {
  await http.send("POST", fill(http, path), { form: { _csrf_token: await http.csrf() } });
});

When("I post to {string} with:", async ({ http }, path: string, table: DataTable) => {
  const fields = Object.entries(table.rowsHash()).map(([name, value]) => [name, formValue(fill(http, value))]);
  await http.send("POST", fill(http, path), {
    form: { _csrf_token: await http.csrf(), ...Object.fromEntries(fields) },
  });
});

When("I post to {string} without a CSRF token", async ({ http }, path: string) => {
  await http.send("POST", path);
});

Then("the answer is {int}", ({ http }, status: number) => {
  expect(http.last?.status(), http.body.slice(0, 500)).toBe(status);
});

Then("the answer does not say {string}", ({ http }, text: string) => {
  expect(http.body).not.toContain(text);
});

Then("the answer sends me to {string}", ({ http }, path: string) => {
  expect(http.last?.status(), http.body.slice(0, 2000)).toBeLessThan(400);
  expect(http.last?.headers().location).toMatch(new RegExp(`(^|//[^/]+)${RegExp.escape(fill(http, path))}$`));
});

Then("the answer has the header {string} set to {string}", ({ app, http }, name: string, value: string) => {
  expect(http.last?.headers()[name.toLowerCase()]).toBe(value.replaceAll("SITE", app.url));
});

Then("the answer has no header {string}", ({ http }, name: string) => {
  expect(http.last?.headers()[name.toLowerCase()]).toBeUndefined();
});

Then("the answer has the header {string} holding {string}", ({ app, http }, name: string, value: string) => {
  expect(http.last?.headers()[name.toLowerCase()]).toContain(value.replaceAll("SITE", app.url));
});

When("I send {word} {string} with a CSRF token", async ({ http }, method: string, path: string) => {
  const form = method === "GET" ? undefined : { _csrf_token: await http.csrf() };
  await http.send(method, path, { form });
});

Then("I am turned away to sign in", ({ http }) => {
  const location = http.last?.headers().location ?? "";
  expect(http.last?.status() === 401 || location.endsWith("/admin/sign-in"), `${http.last?.status()} ${location}`).toBe(
    true,
  );
});

When("I follow the answer", async ({ http, page }) => {
  await page.goto(http.last?.headers().location ?? "");
});

Then("the page's toast reads {string}", async ({ page }, text: string) => {
  await expect(page.locator("[data-toast] .toast").first()).toHaveText(text, { useInnerText: false });
});

Then("the page's toast starts with {string}", async ({ page }, text: string) => {
  await expect(page.locator("[data-toast] .toast").first()).toContainText(text);
  expect((await page.locator("[data-toast] .toast").first().textContent())?.trim()).toMatch(
    new RegExp(`^${RegExp.escape(text)}`),
  );
});

Then("the menu reads {string}", async ({ page }, items: string) => {
  expect((await page.locator(".ctx-label").allTextContents()).map((item) => item.trim()).join(", ")).toBe(items);
});

When("I post to {string} with the fields {string}", async ({ http }, path: string, fields: string) => {
  const form = Object.fromEntries(new URLSearchParams(fields));
  await http.send("POST", fill(http, path), { form: { _csrf_token: await http.csrf(), ...form } });
});

When("I send GET {string} with the forwarded host {string}", async ({ http }, path: string, host: string) => {
  await http.send("GET", path, { headers: { "X-Forwarded-Host": host } });
});

When("a browser on another site asks before it posts to {string}", async ({ http }, path: string) => {
  await http.send("OPTIONS", path, {
    headers: {
      "Access-Control-Request-Headers": "authorization, content-type, mcp-protocol-version",
      "Access-Control-Request-Method": "POST",
      Origin: "https://client.example",
    },
  });
});

Then("the answer has no body", ({ http }) => {
  expect(http.body).toBe("");
});

Then("the answer's header {string} does not hold {string}", ({ http }, name: string, text: string) => {
  expect(http.last?.headers()[name.toLowerCase()] ?? "").not.toContain(text);
});
