import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve } from "node:path";
import { type APIRequestContext, expect, type Page } from "@playwright/test";
import { Given, Then, When } from "../support/world.ts";
import { runJobs } from "./health.ts";

const fixtures = resolve(import.meta.dirname, "../photos/fixtures");
const day = 24 * 60 * 60 * 1000;
const jpegStart = Buffer.from([0xff, 0xd8, 0xff]);

const types: Record<string, string> = {
  gif: "image/gif",
  heic: "image/heic",
  jpg: "image/jpeg",
  png: "image/png",
  svg: "image/svg+xml",
  webp: "image/webp",
};

const made: Record<string, () => Buffer> = {
  "big.jpg": () => Buffer.concat([jpegStart, Buffer.alloc(20 * 1024 * 1024)]),
  "drawing.svg": () => Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>`),
  "half.jpg": () => Buffer.concat([jpegStart, Buffer.from("not a photo")]),
  "text.jpg": () => Buffer.from("just some text"),
};

function photoFile(given: string) {
  const [, file, as] = /^(\S+)(?: as (\S+))?$/.exec(given) ?? [];
  const buffer = made[file]?.() ?? readFileSync(resolve(fixtures, file));
  const name = as ?? file;
  return { buffer, mimeType: types[name.split(".").pop() ?? ""] ?? "application/octet-stream", name };
}

function header(bytes: Buffer, options = "") {
  const path = resolve(mkdtempSync(resolve(tmpdir(), "photo-")), `photo${options}`);
  writeFileSync(path.replace(/\[.*\]$/, ""), bytes);
  const fields = execFileSync("vipsheader", ["-a", path]).toString();
  return Object.fromEntries([...fields.matchAll(/^([\w-]+): (.*)$/gm)].map(([, key, value]) => [key, value]));
}

function pixel(bytes: Buffer, x: number, y: number) {
  const path = resolve(mkdtempSync(resolve(tmpdir(), "photo-")), "photo");
  writeFileSync(path, bytes);
  return execFileSync("vips", ["getpoint", path, String(x), String(y)])
    .toString()
    .trim()
    .split(" ")
    .map(Number);
}

async function csrfToken(page: Page | APIRequestContext, path: string) {
  if ("goto" in page) await page.goto(path);
  const html = "goto" in page ? await page.content() : await (await page.get(path)).text();
  return /name="_csrf_token" value="([^"]+)"/.exec(html)?.[1] ?? "";
}

function stored(objects: Map<string, { body: Buffer; type: string }>) {
  return [...objects].filter(([key]) => key.startsWith("photos/"));
}

function original(objects: Map<string, { body: Buffer; type: string }>) {
  const found = stored(objects).find(([key]) => key.split("/").length === 2);
  expect(found, "a stored photo").toBeTruthy();
  const [key, object] = found ?? ["", { body: Buffer.alloc(0), type: "" }];
  return { key: key.slice("photos/".length), ...object };
}

Given(
  "the photo {string} of {int} by {int} uploaded {int} hours ago",
  async ({ app }, key: string, width: number, height: number, hours: number) => {
    const body = readFileSync(resolve(fixtures, "rotated_with_gps.jpg"));
    await app.sql`
      INSERT INTO photos ${app.sql({
        byte_size: body.length,
        created_at: new Date(Date.now() - hours * 60 * 60 * 1000),
        height,
        key,
        width,
      })}
    `;
    app.stub.objects.set(`photos/${key}`, { body, type: "image/jpeg" });
  },
);

Given("the photo {string} uploaded {int} days ago", async ({ app }, key: string, days: number) => {
  await app.sql`
    INSERT INTO photos ${app.sql({ byte_size: 10, created_at: new Date(Date.now() - days * day), height: 1, key, width: 1 })}
  `;
  app.stub.objects.set(`photos/${key}`, { body: Buffer.from("photo"), type: "image/jpeg" });
});

Given("the photo {string} also kept at the widths {string}", async ({ app }, key: string, widths: string) => {
  const list = widths.split(" ").map(Number);
  await app.sql`UPDATE photos SET widths = ${list} WHERE key = ${key}`;
  for (const width of list)
    app.stub.objects.set(`photos/${width}/${key}`, { body: Buffer.from("w"), type: "image/jpeg" });
});

Given("the photo {string} is missing from the photo store", ({ app }, key: string) => {
  app.stub.objects.delete(`photos/${key}`);
});

When("I upload the photo file {string} in the admin", async ({ answer, page }, name: string) => {
  const token = await csrfToken(page, "/admin/posts/new");
  const response = await page.request.post("/admin/photos", {
    headers: { Accept: "application/json", "X-CSRF-Token": token },
    multipart: { photo: photoFile(name) },
  });
  answer.status = response.status();
  answer.body = await response.text();
});

When("I send the admin a photo upload with no file", async ({ answer, page }) => {
  const token = await csrfToken(page, "/admin/posts/new");
  const response = await page.request.post("/admin/photos", {
    headers: { Accept: "application/json", "X-CSRF-Token": token },
    multipart: { photo: "" },
  });
  answer.status = response.status();
  answer.body = await response.text();
});

When("I upload the photo file {string} in the admin without a CSRF token", async ({ answer, page }, name: string) => {
  await page.goto("/admin/posts/new");
  const response = await page.request.post("/admin/photos", {
    headers: { Accept: "application/json" },
    multipart: { photo: photoFile(name) },
  });
  answer.status = response.status();
});

When("someone signed out uploads the photo file {string} to the admin", async ({ answer, request }, name: string) => {
  const token = await csrfToken(request, "/admin/sign-in");
  const response = await request.post("/admin/photos", {
    headers: { Accept: "application/json", "X-CSRF-Token": token },
    maxRedirects: 0,
    multipart: { photo: photoFile(name) },
  });
  answer.status = response.status();
});

When("I upload the photo file {string} through the API", async ({ answer, request, tokens }, name: string) => {
  const { buffer, name: filename } = photoFile(name);
  const response = await request.post("/api/v1/photos", {
    data: { data: buffer.toString("base64"), filename },
    headers: { Authorization: `Bearer ${tokens.api}` },
  });
  answer.status = response.status();
  answer.body = await response.text();
});

When(
  "I upload the photo file {string} through the API in base64 broken across lines",
  async ({ answer, request, tokens }, name: string) => {
    const { buffer, name: filename } = photoFile(name);
    const data = buffer.toString("base64").replace(/.{1,60}/g, "$&\n");
    const response = await request.post("/api/v1/photos", {
      data: { data, filename },
      headers: { Authorization: `Bearer ${tokens.api}` },
    });
    answer.status = response.status();
    answer.body = await response.text();
  },
);

When("I upload the photo file {string} through the API with no token", async ({ answer, request }, name: string) => {
  const { buffer, name: filename } = photoFile(name);
  const response = await request.post("/api/v1/photos", { data: { data: buffer.toString("base64"), filename } });
  answer.status = response.status();
});

When("I upload the photo file {string} through MCP", async ({ answer, request, tokens }, name: string) => {
  const { buffer, name: filename } = photoFile(name);
  const response = await request.post("/mcp", {
    data: {
      id: 1,
      jsonrpc: "2.0",
      method: "tools/call",
      params: { arguments: { data: buffer.toString("base64"), filename }, name: "upload_photo" },
    },
    headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${tokens.mcp}` },
  });
  const { result } = await response.json();
  answer.error = result.isError ?? false;
  answer.body = result.content[0].text;
  answer.content = answer.body;
});

When(
  "I call the MCP tool {string} with the uploaded photo's URL in:",
  async ({ answer, request, tokens }, name: string, args: string) => {
    const url = JSON.parse(answer.body).url;
    const response = await request.post("/mcp", {
      data: {
        id: 1,
        jsonrpc: "2.0",
        method: "tools/call",
        params: { arguments: JSON.parse(args.replaceAll("PHOTO_URL", url)), name },
      },
      headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${tokens.mcp}` },
    });
    const { result } = await response.json();
    expect(result.isError ?? false, result.content[0].text).toBe(false);
  },
);

When("I read the photo {string} through the API", async ({ answer, request, tokens }, reference: string) => {
  const response = await request.get("/api/v1/photos", {
    headers: { Authorization: `Bearer ${tokens.api}` },
    params: { photo: reference },
  });
  answer.status = response.status();
  answer.body = await response.text();
});

When("I read the photo {string} through MCP", async ({ answer, request, tokens }, reference: string) => {
  const response = await request.post("/mcp", {
    data: {
      id: 1,
      jsonrpc: "2.0",
      method: "tools/call",
      params: { arguments: { photo: reference }, name: "read_photo" },
    },
    headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${tokens.mcp}` },
  });
  const { result } = await response.json();
  answer.error = result.isError ?? false;
  answer.body = JSON.stringify(result.content);
});

When("the photo sweep runs", async ({ $testInfo, app }) => {
  await runJobs(app, $testInfo.parallelIndex, "Media::Jobs::SweepPhotos");
});

Then("the photo upload answers {int} with the error {string}", ({ answer }, status: number, error: string) => {
  expect([answer.status, JSON.parse(answer.body)]).toEqual([status, { error }]);
});

Then("the photo upload is refused with {int}", ({ answer }, status: number) => {
  expect(answer.status).toBe(status);
});

Then("the API refuses the photo with {string}", ({ answer }, message: string) => {
  expect([answer.status, JSON.parse(answer.body)]).toEqual([
    422,
    { error: "invalid", errors: { data: [message] }, message },
  ]);
});

Then("the photo store and the photos table are empty", async ({ app }) => {
  expect(stored(app.stub.objects)).toEqual([]);
  expect(await app.sql`SELECT key FROM photos`).toHaveLength(0);
});

Then("the photo store holds {int} file(s)", ({ app }, count: number) => {
  expect(stored(app.stub.objects)).toHaveLength(count);
});

Then("the photo upload answers 201 with the photo's URL and key", ({ answer, app }) => {
  const { key } = original(app.stub.objects);
  expect(answer.status).toBe(201);
  expect(JSON.parse(answer.body)).toMatchObject({ key, url: `${app.url}/media/${key}` });
});

Then("the uploaded photo answers with its URL and size", async ({ answer, app }) => {
  const [row] = await app.sql`SELECT key, width, height FROM photos`;
  expect([answer.status, JSON.parse(answer.body)]).toEqual([
    201,
    { height: row.height, url: `${app.url}/media/${row.key}`, width: row.width },
  ]);
});

Then("the photo's URL serves the stored photo to the owner", async ({ answer, app, page }) => {
  const response = await page.request.get(JSON.parse(answer.body).url);
  expect(response.status()).toBe(200);
  expect(await response.body()).toEqual(original(app.stub.objects).body);
});

Then("the stored photo is a {word} of {int} by {int}", ({ app }, extension: string, width: number, height: number) => {
  const { body, key, type } = original(app.stub.objects);
  const fields = header(body);
  expect([/^[0-9a-f]{32}\.(\w+)$/.exec(key)?.[1], type, Number(fields.width), Number(fields.height)]).toEqual([
    extension,
    types[extension],
    width,
    height,
  ]);
});

Then("the stored photo carries no metadata", ({ app }) => {
  const { body } = original(app.stub.objects);
  const fields = Object.keys(header(body));
  expect(fields.filter((field) => /exif|orientation|xmp|iptc/.test(field))).toEqual([]);
  expect(body.includes("Exif")).toBe(false);
});

Then("the stored photo starts like a JPEG", ({ app }) => {
  expect(original(app.stub.objects).body.subarray(0, 3)).toEqual(jpegStart);
});

Then(
  "the photo row is {int} by {int} with the widths {string}",
  async ({ app }, width: number, height: number, widths: string) => {
    const { body, key } = original(app.stub.objects);
    const rows = await app.sql`SELECT key, width, height, byte_size, widths FROM photos`;
    expect(rows.map((row) => ({ ...row }))).toEqual([
      { byte_size: body.length, height, key, width, widths: widths ? widths.split(" ").map(Number) : [] },
    ]);
  },
);

Then("the photo store keeps the stored photo at the widths {string}", ({ app }, widths: string) => {
  const { key, type } = original(app.stub.objects);
  for (const width of widths.split(" ")) {
    const copy = app.stub.objects.get(`photos/${width}/${key}`);
    expect(copy, `the ${width} wide copy`).toBeTruthy();
    expect([Number(header(copy?.body ?? Buffer.alloc(0)).width), copy?.type]).toEqual([Number(width), type]);
  }
});

Then(
  "the stored photo {word} holds {int} frames of {int} by {int}",
  ({ app }, copy: string, frames: number, width: number, height: number) => {
    const { body, key } = original(app.stub.objects);
    const bytes = copy === "itself" ? body : app.stub.objects.get(`photos/${copy}/${key}`)?.body;
    const fields = header(bytes ?? Buffer.alloc(0), "[n=-1]");
    expect([fields["n-pages"], fields["page-height"], fields.width].map(Number)).toEqual([frames, height, width]);
  },
);

Then("the stored photo's {int} wide copy is white at {int}, {int}", ({ app }, width: number, x: number, y: number) => {
  const { key } = original(app.stub.objects);
  const copy = app.stub.objects.get(`photos/${width}/${key}`)?.body ?? Buffer.alloc(0);
  expect(pixel(copy, x, y).slice(0, 3)).toEqual([255, 255, 255]);
});

Then(
  "the photo read answers the photo {string} of {int} by {int} with its bytes",
  async ({ answer }, key: string, width: number, height: number) => {
    const body = readFileSync(resolve(fixtures, "rotated_with_gps.jpg"));
    expect([answer.status, JSON.parse(answer.body)]).toEqual([
      200,
      { byte_size: body.length, content_type: "image/jpeg", data: body.toString("base64"), height, key, width },
    ]);
  },
);

Then("the photo read answers {int} with {string}", ({ answer }, status: number, message: string) => {
  expect(answer.status).toBe(status);
  expect(JSON.parse(answer.body).message).toBe(message);
});

Then(
  "the MCP photo read shows the photo {string} of {int} by {int}",
  ({ answer }, key: string, width: number, height: number) => {
    const body = readFileSync(resolve(fixtures, "rotated_with_gps.jpg"));
    expect(answer.error).toBe(false);
    expect(JSON.parse(answer.body)).toEqual([
      { data: body.toString("base64"), mimeType: "image/jpeg", type: "image" },
      { text: JSON.stringify({ key, width, height, byte_size: body.length }), type: "text" },
    ]);
  },
);

Then("the MCP photo read refuses with {string}", ({ answer }, message: string) => {
  expect([answer.error, JSON.parse(answer.body)]).toEqual([true, [{ text: message, type: "text" }]]);
});

Then("the MCP upload answers like the API upload, less the key", async ({ answer, app }) => {
  const [row] = await app.sql`SELECT key, width, height FROM photos ORDER BY id DESC LIMIT 1`;
  expect(JSON.parse(answer.body)).toEqual({ height: row.height, url: `${app.url}/media/${row.key}`, width: row.width });
});

Then("the photos left are {string}", async ({ app }, keys: string) => {
  await expect
    .poll(async () => (await app.sql`SELECT key FROM photos ORDER BY key`).map((row) => row.key).join(" "))
    .toBe(keys);
});

Then("the photo store holds {string}", ({ app }, keys: string) => {
  expect(
    stored(app.stub.objects)
      .map(([key]) => key.slice("photos/".length))
      .sort()
      .join(" "),
  ).toBe(keys);
});

Then("the {word} claims of photos are {string}", async ({ app }, owner: string, keys: string) => {
  await expect
    .poll(async () =>
      (
        await app.sql`
          SELECT photos.key FROM photo_claims JOIN photos ON photos.id = photo_claims.photo_id
          WHERE photo_claims.owner = ${owner} ORDER BY photos.key
        `
      )
        .map((row) => row.key)
        .join(" "),
    )
    .toBe(keys);
});

Then("no photo is claimed", async ({ app }) => {
  expect(await app.sql`SELECT photo_id FROM photo_claims`).toHaveLength(0);
});

Then("the {word} claims {int} photo(s)", async ({ app }, owner: string, count: number) => {
  await expect
    .poll(async () => (await app.sql`SELECT photo_id FROM photo_claims WHERE owner = ${owner}`).length)
    .toBe(count);
});

Given("a post claims the photo {string}", async ({ app }, key: string) => {
  await app.sql`
    INSERT INTO photo_claims (owner, owner_id, photo_id) SELECT 'post', 1, id FROM photos WHERE key = ${key}
  `;
});

Given("the photo {string} uploaded {int} hours ago", async ({ app }, key: string, hours: number) => {
  await app.sql`
    INSERT INTO photos ${app.sql({ byte_size: 10, created_at: new Date(Date.now() - hours * 60 * 60 * 1000), height: 1, key, width: 1 })}
  `;
  app.stub.objects.set(`photos/${key}`, { body: Buffer.from("photo"), type: "image/jpeg" });
});

async function handOver(page: Page, event: string, name: string, text?: string) {
  const { buffer, mimeType, name: filename } = photoFile(name);
  return page.evaluate(
    ([event, filename, data, type, text]) => {
      const transfer = new DataTransfer();
      const bytes = Uint8Array.from(atob(data ?? ""), (char) => char.charCodeAt(0));
      transfer.items.add(new File([bytes], filename ?? "", { type }));
      if (text) transfer.setData("text/plain", text);
      const init = { bubbles: true, cancelable: true };
      const handed =
        event === "drop"
          ? new DragEvent("drop", { ...init, dataTransfer: transfer })
          : new ClipboardEvent("paste", { ...init, clipboardData: transfer });
      document.getElementById("post-body")?.dispatchEvent(handed);
      return handed.defaultPrevented;
    },
    [event, filename, buffer.toString("base64"), mimeType, text],
  );
}

const releases = new WeakMap<Page, () => void>();

When("I write {string} in a new post's body", async ({ page }, text: string) => {
  await page.goto("/admin/posts/new");
  await page.locator("#post-body").fill(text);
});

When("I {word} the photo file {string} into the post body", async ({ page }, event: string, name: string) => {
  await handOver(page, event, name);
});

When("I paste the photo file {string} with text into the post body", async ({ answer, page }, name: string) => {
  answer.body = String(await handOver(page, "paste", name, "words"));
});

When("I pick the photo file {string} from the post body's toolbar", async ({ page }, name: string) => {
  await expect(page.getByRole("toolbar").getByRole("button", { name: "Add a photo" }).first()).toBeVisible();
  await page.locator("[data-markdown-editor]:has(#post-body) [data-editor-file]").setInputFiles(photoFile(name));
});

Given("the photo upload waits until I let it go", async ({ page }) => {
  let release = () => {};
  const released = new Promise<void>((done) => {
    release = done;
  });
  releases.set(page, release);
  await page.route("**/admin/photos", async (route) => {
    await released;
    await route.continue();
  });
});

When("I let the photo upload go", ({ page }) => {
  releases.get(page)?.();
});

Then("the post body reads {string}", async ({ page }, text: string) => {
  await expect(page.locator("#post-body")).toHaveValue(text);
});

Then("the post body holds a link to the uploaded photo after {string}", async ({ app, page }, before: string) => {
  const media = `${app.url}/media/`.replace(/[.:/]/g, "\\$&");
  await expect(page.locator("#post-body")).toHaveValue(
    new RegExp(`^${before}!\\[\\]\\(${media}[0-9a-f]{32}\\.png\\)$`),
  );
});

Then("the post body's cursor sits after {string}", async ({ page }, text: string) => {
  expect(await page.locator("#post-body").evaluate((body: HTMLTextAreaElement) => body.selectionStart)).toBe(
    text.length,
  );
});

Then("the post body's editor says {string}", async ({ page }, message: string) => {
  await expect(page.locator("[data-markdown-editor]:has(#post-body) [role='alert']")).toHaveText(message);
});

Then("the browser kept the paste", ({ answer }) => {
  expect(answer.body).toBe("false");
});

Given("the photo store turns away every write", ({ app }) => {
  app.stub.reply("PUT", "/s3/photos/*", { body: "", status: 500 });
});

Given("the photo store turns away the delete of {string}", ({ app }, key: string) => {
  app.stub.reply("DELETE", `/s3/photos/${key}`, { body: "", status: 500 });
});

Then("the API says the photo store is down", ({ answer }) => {
  expect([answer.status, JSON.parse(answer.body)]).toEqual([
    503,
    { error: "unavailable", message: "The photo store is down or not set up." },
  ]);
});

Given("the photo store turns away the third write", ({ app }) => {
  let writes = 0;
  app.stub.reply("PUT", "/s3/photos/*", () => ({ body: "", status: ++writes >= 3 ? 500 : 200 }));
});

Then("the photo store was told to delete each photo it took", ({ app }) => {
  const sent = app.stub.requests().filter((each) => each.url.pathname.startsWith("/s3/photos/"));
  const taken = [...new Set(sent.filter((each) => each.method === "PUT").map((each) => each.url.pathname))].slice(0, 2);
  const deleted = sent.filter((each) => each.method === "DELETE").map((each) => each.url.pathname);
  expect(taken).toHaveLength(2);
  expect(deleted).toEqual(expect.arrayContaining(taken));
});
