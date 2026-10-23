import { expect } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import type postgres from "postgres";
import { fill } from "../support/api.ts";
import { slugFor } from "../support/rows.ts";
import { Given, Then, When } from "../support/world.ts";
import { assetPaths } from "./http.ts";

const units: Record<string, number> = {
  day: 86_400_000,
  hour: 3_600_000,
  minute: 60_000,
  second: 1000,
  week: 604_800_000,
};

export function when(text: string) {
  const ago = text.match(/^(\d+) (second|minute|hour|day|week)s? ago$/);
  if (ago) return new Date(Date.now() - Number(ago[1]) * units[ago[2]]);
  const ahead = text.match(/^in (\d+) (second|minute|hour|day|week)s?$/);
  if (ahead) return new Date(Date.now() + Number(ahead[1]) * units[ahead[2]]);
  if (text === "now") return new Date();
  return new Date(text);
}

export async function tagIds(sql: postgres.Sql, names: string, scope = "public", projectId: number | null = null) {
  const ids: number[] = [];
  for (const name of names
    .split(",")
    .map((one) => one.trim())
    .filter(Boolean)) {
    const [found] = await sql`
      SELECT id FROM tags WHERE name = ${name} AND scope = ${scope} AND project_id IS NOT DISTINCT FROM ${projectId}
    `;
    const [tag] = found
      ? [found]
      : await sql`INSERT INTO tags ${sql({ color: "mk-blue", name, project_id: projectId, scope })} RETURNING id`;
    ids.push(tag.id);
  }
  return ids;
}

async function rendered(sql: postgres.Sql, pushJob: (job: string) => Promise<void>) {
  await pushJob("Posts::Jobs::RerenderPosts");
  await expect
    .poll(
      async () =>
        (
          await sql`
            SELECT (SELECT count(*) FROM posts WHERE body_html = '')
              + (SELECT count(*) FROM post_edits WHERE note_html = '') AS count
          `
        )[0].count,
    )
    .toBe("0");
}

async function insertPosts(
  app: { pushJob: (job: string) => Promise<void>; sql: postgres.Sql },
  rows: Record<string, string>[],
) {
  for (const row of rows) {
    const status = row.status || "published";
    const body = ((row.body || "").replaceAll("\\n", "\n") || `A post called ${row.title}.`).replace(
      /<(\d+) words>/,
      (_, count: string) => "word ".repeat(Number(count)).trim(),
    );
    const publishedAt = status === "draft" && !row.published ? null : when(row.published || "1 day ago");
    const [post] = await app.sql`
      INSERT INTO posts ${app.sql({
        body,
        body_html: "",
        canonical_url: row.canonical || "",
        og_image_url: row.image || "",
        og_title: row["og title"] || "",
        published_at: publishedAt,
        read_time: 1,
        slug: row.slug || slugFor(row.title),
        status,
        summary: row.summary || "",
        title: row.title,
        updated_at: row.updated ? when(row.updated) : (publishedAt ?? new Date()),
        webmentions_enabled: row.webmentions === "yes",
        word_count: 1,
      })}
      RETURNING id
    `;
    for (const tag of await tagIds(app.sql, row.tags ?? "")) {
      await app.sql`INSERT INTO post_tags ${app.sql({ post_id: post.id, tag_id: tag })}`;
    }
  }
  await rendered(app.sql, app.pushJob);
}

Given("the posts:", async ({ app }, table: DataTable) => {
  await insertPosts(app, table.hashes());
});

Given("{int} published posts", async ({ app }, count: number) => {
  for (let index = 1; index <= count; index++) {
    await app.sql`
      INSERT INTO posts ${app.sql({
        body: `Post number ${index}.`,
        body_html: `<p>Post number ${index}.</p>`,
        published_at: new Date(Date.now() - index * units.hour),
        updated_at: new Date(Date.now() - index * units.hour),
        read_time: 1,
        slug: `post-${index}`,
        status: "published",
        title: `Post ${index}`,
        webmentions_enabled: false,
        word_count: 3,
      })}
    `;
  }
});

async function insertProjects(sql: postgres.Sql, rows: Record<string, string>[]) {
  const app = { sql };
  for (const row of rows) {
    await app.sql`
      INSERT INTO projects ${app.sql({
        archived_on: row.archived || null,
        board_published: row.board === "published",
        key: row.key || null,
        name: row.name,
        og_image_url: row.image || null,
        release: row.release || null,
        repo: row.repo || null,
        stars: Number(row.stars || 0),
        updated_at: row.updated ? when(row.updated) : new Date(),
        started_on: row.started || "2024-01-01",
        tagline: row.tagline || null,
        url: row.url || null,
        visibility: row.visibility || "public",
      })}
      RETURNING id
    `.then(async ([project]) => {
      for (const tag of await tagIds(app.sql, row.tags ?? "")) {
        await app.sql`INSERT INTO project_tags ${app.sql({ project_id: project.id, tag_id: tag })}`;
      }
    });
  }
}

Given("the projects:", async ({ app }, table: DataTable) => {
  await insertProjects(app.sql, table.hashes());
});

Given("a draft and a scheduled post tagged {string}", async ({ app }, tag: string) => {
  await insertPosts(app, [
    { status: "draft", tags: tag, title: "Hidden draft" },
    { published: "in 1 day", status: "scheduled", tags: tag, title: "Hidden scheduled" },
  ]);
});

Given("a private project tagged {string} and an archived one tagged {string}", async ({ app }, one: string, other) => {
  await insertProjects(app.sql, [
    { name: "Secret", tags: one, visibility: "private" },
    { archived: "2026-01-01", name: "Retired", tags: other },
  ]);
});

Given("a private project with a published board and a public one without", async ({ app }) => {
  await insertProjects(app.sql, [
    { board: "published", name: "Hidden", visibility: "private" },
    { name: "Unpublished" },
  ]);
});

When("the posts are rendered again", async ({ app }) => {
  await app.sql`UPDATE posts SET body_html = ''`;
  await rendered(app.sql, app.pushJob);
});

Then("the page has {string}", async ({ app, http, page }, selector: string) => {
  await expect(page.locator(await assetPaths(app.url, fill(http, selector))).first()).toBeAttached();
});

Then("the page has no {string}", async ({ app, http, page }, selector: string) => {
  await expect(page.locator(await assetPaths(app.url, fill(http, selector)))).toHaveCount(0);
});

Then("the page has {int} of {string}", async ({ page }, count: number, selector: string) => {
  await expect(page.locator(selector)).toHaveCount(count);
});

Then("{string} reads {string}", async ({ page }, selector: string, text: string) => {
  await expect(page.locator(selector).first()).toHaveText(text);
});

Then("{string} includes {string}", async ({ page }, selector: string, text: string) => {
  await expect(page.locator(selector).first()).toContainText(text);
});

Then("{string} does not include {string}", async ({ page }, selector: string, text: string) => {
  await expect(page.locator(selector).first()).not.toContainText(text);
});

Then("the texts of {string} are:", async ({ http, page }, selector: string, table: DataTable) => {
  const texts = (await page.locator(fill(http, selector)).allTextContents()).map((text) =>
    text.trim().replace(/\s+/g, " "),
  );
  expect(texts).toEqual(table.raw().map(([text]) => fill(http, text)));
});

Then("{string} has the attribute {string} set to {string}", async ({ app, page }, selector, name, value) => {
  await expect(page.locator(selector).first()).toHaveAttribute(name, await assetPaths(app.url, value));
});

Then("the page shows {string}", async ({ page }, text: string) => {
  await expect(page.locator("body")).toContainText(text);
});

Then("the page does not show {string}", async ({ page }, text: string) => {
  await expect(page.locator("body")).not.toContainText(text);
});

Given("a long post {string} with the heading {string} in the middle", async ({ app }, title: string, heading) => {
  const filler = Array.from({ length: 40 }, () => "filler").join("\n\n");
  await app.sql`
    INSERT INTO posts ${app.sql({
      body: `${filler}\n\n## ${heading}\n\n${filler}`,
      body_html: "",
      published_at: when("1 day ago"),
      read_time: 1,
      slug: slugFor(title),
      status: "published",
      title,
      webmentions_enabled: false,
      word_count: 1,
    })}
  `;
  await rendered(app.sql, app.pushJob);
});

Then("the structured data on the page is:", async ({ app, page }, json: string) => {
  const found = await page
    .locator("script[type='application/ld+json']")
    .evaluateAll((scripts) => scripts.map((script) => JSON.parse(script.textContent ?? "")));
  expect(found).toEqual(JSON.parse(await assetPaths(app.url, json)));
});

Given("the career history:", async ({ app }, table: DataTable) => {
  for (const [index, row] of table.hashes().entries()) {
    await app.sql`
      INSERT INTO work_entries ${app.sql({
        blurb: row.blurb ?? null,
        from_year: Number(row.from || 2018),
        org: row.org || "Somewhere",
        position: Number(row.position || index + 1),
        role: row.role,
        to_year: row.to ? Number(row.to) : null,
      })}
    `;
  }
});

Then("the links in {string} go to:", async ({ app, page }, selector: string, table: DataTable) => {
  const hrefs = await page.locator(selector).evaluateAll((links) => links.map((link) => link.getAttribute("href")));
  const expected = await Promise.all(table.raw().map(([href]) => assetPaths(app.url, href)));
  expect(hrefs).toEqual(expected);
});

Then("{string} has a link {string} to {string}", async ({ page }, selector: string, name: string, href: string) => {
  await expect(page.locator(selector).getByRole("link", { exact: true, name })).toHaveAttribute("href", href);
});

Then("the structured data holds {string} as {string}", async ({ page }, key: string, value: string) => {
  const [first] = await page
    .locator("script[type='application/ld+json']")
    .evaluateAll((scripts) => scripts.map((script) => JSON.parse(script.textContent ?? "")));
  expect(first[key]).toBe(value);
});

Then("the structured data has no {string}", async ({ page }, key: string) => {
  const [first] = await page
    .locator("script[type='application/ld+json']")
    .evaluateAll((scripts) => scripts.map((script) => JSON.parse(script.textContent ?? "")));
  expect(first).not.toHaveProperty(key);
});

Then("the classes of {string} are:", async ({ page }, selector: string, table: DataTable) => {
  const classes = await page
    .locator(selector)
    .evaluateAll((nodes) => nodes.map((node) => node.getAttribute("class") ?? ""));
  expect(classes).toEqual(table.raw().map(([name]) => name));
});

Then(
  "the list after the heading {string} has {int} item(s) holding {string}",
  async ({ page }, heading: string, count: number, text: string) => {
    const list = page.locator(`.prose h2:text-is("${heading}") + ul`);
    await expect(list.locator("li").filter({ hasText: text })).toHaveCount(count);
  },
);

Given("the post {string} carries the edit notes:", async ({ app }, title: string, table: DataTable) => {
  const [post] = await app.sql`SELECT id FROM posts WHERE title = ${title}`;
  for (const row of table.hashes()) {
    const at = when(row.at || "now");
    await app.sql`
      INSERT INTO post_edits ${app.sql({ created_at: at, note: row.note, note_html: "", post_id: post.id, updated_at: at })}
    `;
  }
  await rendered(app.sql, app.pushJob);
});

Given("the post {string} links to the post {string}", async ({ app }, one: string, other: string) => {
  const ids = (await app.sql`SELECT id FROM posts WHERE title IN (${one}, ${other}) ORDER BY id`).map(({ id }) => id);
  await app.sql`INSERT INTO record_links ${app.sql({ left_id: ids[0], left_kind: "post", right_id: ids[1], right_kind: "post" })}`;
});

Then("{string} starts with the text {string}", async ({ page }, selector: string, text: string) => {
  const year = new Intl.DateTimeFormat("en-US", { timeZone: "America/Chicago", year: "numeric" }).format(new Date());
  const found = (await page.locator(selector).first().textContent())?.trim().replace(/\s+/g, " ") ?? "";
  expect(found.startsWith(text.replace("this year", year))).toBe(true);
});

Given("the photos:", async ({ app }, table: DataTable) => {
  for (const row of table.hashes()) {
    await app.sql`
      INSERT INTO photos ${app.sql({
        byte_size: 1024,
        height: Number(row.height),
        key: row.key,
        width: Number(row.width),
        widths: `{${row.widths || ""}}`,
      })}
    `;
  }
});

Then(
  "the first of {string} reads {string} and the last {string}, {int} in all",
  async ({ page }, selector, first, last, count: number) => {
    const texts = (await page.locator(selector).allTextContents()).map((text) => text.trim());
    expect([texts[0], texts.at(-1), texts.length]).toEqual([first, last, count]);
  },
);

Then("the hrefs and texts of {string} are:", async ({ page }, selector: string, table: DataTable) => {
  const found = await page
    .locator(selector)
    .evaluateAll((links) => links.map((link) => [link.getAttribute("href") ?? "", (link.textContent ?? "").trim()]));
  expect(found).toEqual(table.raw());
});

Then("the ids of {string} are:", async ({ page }, selector: string, table: DataTable) => {
  const ids = await page.locator(selector).evaluateAll((nodes) => nodes.map((node) => node.id));
  expect(ids).toEqual(table.raw().map(([id]) => id));
});

Given("{int} published posts tagged {string}", async ({ app }, count: number, tag: string) => {
  const [tagId] = await tagIds(app.sql, tag);
  for (let index = 1; index <= count; index++) {
    const [post] = await app.sql`
      INSERT INTO posts ${app.sql({
        body: `Post number ${index}.`,
        body_html: `<p>Post number ${index}.</p>`,
        published_at: new Date(Date.now() - index * units.hour),
        updated_at: new Date(Date.now() - index * units.hour),
        read_time: 1,
        slug: `post-${index}`,
        status: "published",
        title: `Post ${index}`,
        webmentions_enabled: false,
        word_count: 3,
      })}
      RETURNING id
    `;
    await app.sql`INSERT INTO post_tags ${app.sql({ post_id: post.id, tag_id: tagId })}`;
  }
});

Given("the {word} tag {string} with the description:", async ({ app }, scope: string, name: string, text: string) => {
  await app.sql`INSERT INTO tags ${app.sql({ color: "mk-blue", description: text, name, scope })}`;
});

Given("a task {string} tagged {string}", async ({ app }, title: string, tag: string) => {
  const [task] = await app.sql`INSERT INTO tasks (title, list, position) VALUES (${title}, 'next', 1) RETURNING id`;
  for (const id of await tagIds(app.sql, tag, "private")) {
    await app.sql`INSERT INTO task_tags ${app.sql({ tag_id: id, tag_scope: "private", task_id: task.id })}`;
  }
});

Given("a journal entry {string} tagged {string}", async ({ app }, body: string, tag: string) => {
  const [entry] = await app.sql`
    INSERT INTO journal_entries (entry_date, entry_time, body, body_html)
    VALUES (current_date, '12:00', ${body}, ${`<p>${body}</p>`}) RETURNING id
  `;
  for (const id of await tagIds(app.sql, tag, "private")) {
    await app.sql`INSERT INTO journal_entry_tags ${app.sql({ journal_entry_id: entry.id, tag_id: id, tag_scope: "private" })}`;
  }
});

Then("the meta descriptions are all {string}", async ({ page }, text: string) => {
  const contents = await page
    .locator("meta[name='description'], meta[property='og:description'], meta[name='twitter:description']")
    .evaluateAll((metas) => metas.map((meta) => meta.getAttribute("content")));
  expect(contents.length).toBe(3);
  expect([...new Set(contents)]).toEqual([text]);
});

Then("the meta descriptions are all {int} characters, ending in an ellipsis", async ({ page }, length: number) => {
  const contents = await page
    .locator("meta[name='description'], meta[property='og:description'], meta[name='twitter:description']")
    .evaluateAll((metas) => metas.map((meta) => meta.getAttribute("content") ?? ""));
  expect(contents.length).toBe(3);
  expect([...new Set(contents.map((content) => [...content].length))]).toEqual([length]);
  expect(contents[0].endsWith("…")).toBe(true);
});

Then("the hrefs and titles of {string} are:", async ({ page }, selector: string, table: DataTable) => {
  const found = await page
    .locator(selector)
    .evaluateAll((links) => links.map((link) => [link.getAttribute("href") ?? "", link.getAttribute("title") ?? ""]));
  expect(found).toEqual(table.raw());
});

Then("{string} has the value {string}", async ({ page }, selector: string, value: string) => {
  await expect(page.locator(selector).first()).toHaveValue(value);
});

Given("the post {string} went out on:", async ({ app }, title: string, table: DataTable) => {
  const [post] = await app.sql`SELECT id FROM posts WHERE title = ${title}`;
  const rows = table.hashes();
  const [social] = await app.sql`
    INSERT INTO social_posts ${app.sql({
      posted_at: when("1 day ago"),
      post_id: post.id,
      status: "posted",
      targets: `{${rows.map(({ network }) => network).join(",")}}`,
    })}
    RETURNING id
  `;
  for (const row of rows) {
    await app.sql`
      INSERT INTO social_post_deliveries ${app.sql({
        like_count: Number(row.likes || 0),
        network: row.network,
        remote_url: row.url,
        reply_count: Number(row.replies || 0),
        repost_count: Number(row.reposts || 0),
        social_post_id: social.id,
      })}
    `;
  }
});

Given("the post {string} has the webmentions:", async ({ app }, title: string, table: DataTable) => {
  const [post] = await app.sql`SELECT id FROM posts WHERE title = ${title}`;
  for (const [index, row] of table.hashes().entries()) {
    await app.sql`
      INSERT INTO webmentions ${app.sql({
        author_name: row.author === "none" ? null : row.author || `Author ${index + 1}`,
        author_url: row["author url"] || `https://author-${index + 1}.example/about`,
        excerpt: row.excerpt || null,
        post_id: post.id,
        received_at: when(row.received || "1 hour ago"),
        source_url: row.source || `https://source-${index + 1}.example/note`,
        status: row.status || "approved",
        type: row.type || "mention",
      })}
    `;
  }
});

Then("the meta tags {string} hold {string}", async ({ app, page }, selector: string, values: string) => {
  const found = await page
    .locator(`meta${selector}`)
    .evaluateAll((metas) => metas.map((meta) => meta.getAttribute("content")));
  expect(found.join(" | ")).toBe(await assetPaths(app.url, values));
});

Then("the meta tags {string} match {string}", async ({ app, page }, selector: string, pattern: string) => {
  const found = await page
    .locator(`meta${selector}`)
    .evaluateAll((metas) => metas.map((meta) => meta.getAttribute("content")));
  expect(found.join(" | ")).toMatch(new RegExp(await assetPaths(app.url, pattern)));
});

Then("the meta tags {string} hold the same as {string}", async ({ page }, one: string, other: string) => {
  const read = (selector: string) =>
    page.locator(`meta${selector}`).evaluateAll((metas) => metas.map((meta) => meta.getAttribute("content")));
  expect(await read(one)).toEqual(await read(other));
});

Then(
  "each of these pages has one description of its own in the meta, Open Graph and Twitter tags:",
  async ({ page }, table: DataTable) => {
    const seen: string[] = [];
    for (const [path, word] of table.raw()) {
      await page.goto(path);
      const found = await page
        .locator("meta[name='description'], meta[property='og:description'], meta[name='twitter:description']")
        .evaluateAll((metas) => metas.map((meta) => meta.getAttribute("content") ?? ""));
      expect(found.length, path).toBe(3);
      expect(new Set(found).size, path).toBe(1);
      expect(found[0].trim(), path).not.toBe("");
      if (word) expect(found[0], path).toContain(word);
      seen.push(found[0]);
    }
    expect(new Set(seen).size).toBe(seen.length);
  },
);

Then("the meta tags {string} hold the summary of {string}", async ({ app, page }, selector: string, title: string) => {
  const [post] = await app.sql`SELECT summary FROM posts WHERE title = ${title}`;
  const found = await page
    .locator(`meta${selector}`)
    .evaluateAll((metas) => metas.map((meta) => meta.getAttribute("content")));
  expect(found).toEqual([post.summary.trim()]);
});

Given("the zeppelin results", async ({ app }) => {
  await insertProjects(app.sql, [
    { board: "published", name: "Board", tagline: "Plans" },
    { name: "Zeppelin", tagline: "A zeppelin tool" },
  ]);
  await insertPosts(
    app,
    [0, 1, 2, 3].map((index) => ({
      published: `${index + 1} minutes ago`,
      slug: `zeppelin-${index}`,
      title: `Zeppelin ${index}`,
    })),
  );
  await app.sql`
    INSERT INTO tasks (title, list, position, project_id) SELECT 'Fly the zeppelin', 'next', 1, id FROM projects WHERE name = 'Board'
  `;
});

Given("the ways forward", async ({ app }) => {
  await app.sql`INSERT INTO tags ${app.sql({ color: "mk-violet", name: "ruby", scope: "public" })}`;
  await insertPosts(app, [
    { published: "4 minutes ago", tags: "ruby, rust", title: "First" },
    { published: "3 minutes ago", tags: "ruby", title: "Second" },
    { published: "2 minutes ago", title: "Third" },
    { published: "1 minute ago", title: "Fourth" },
    { status: "draft", tags: "draft-only", title: "Draft" },
  ]);
});

Then("{string} matches the pattern {string}", async ({ page }, selector: string, pattern: string) => {
  expect(((await page.locator(selector).first().textContent()) ?? "").trim()).toMatch(new RegExp(pattern));
});

Then("{string} is {int} by {int} pixels", async ({ page }, selector: string, width: number, height: number) => {
  const box = await page.locator(selector).first().boundingBox();
  expect([box?.width, box?.height]).toEqual([width, height]);
});

Given("the public screens hold their usual records", async ({ app }) => {
  await app.sql`INSERT INTO tags ${app.sql({ color: "mk-violet", name: "ruby", scope: "public" })}`;
  await insertProjects(app.sql, [{ board: "published", name: "sai", tagline: "Terminal colors", tags: "ruby" }]);
  const [{ id: project }] = await app.sql`SELECT id FROM projects WHERE name = 'sai'`;
  const [task] = await app.sql`
    INSERT INTO tasks ${app.sql({
      completed_at: new Date(),
      list: "next",
      note: "Pick the **colors** first\n\n- [x] light\n- [ ] dark",
      position: 1,
      project_id: project,
      status: "done",
      title: "Ship the palette",
    })}
    RETURNING id
  `;
  const [blocker] = await app.sql`
    INSERT INTO tasks ${app.sql({ list: "next", position: 2, project_id: project, title: "Name the colors" })} RETURNING id
  `;
  const [tone] = await app.sql`
    INSERT INTO tasks ${app.sql({ list: "next", position: 3, project_id: project, title: "Pick a tone" })} RETURNING id
  `;
  for (const id of await tagIds(app.sql, "palette", "project", project)) {
    await app.sql`INSERT INTO task_tags ${app.sql({ tag_id: id, tag_scope: "project", task_id: tone.id })}`;
  }
  await app.sql`INSERT INTO task_links ${app.sql({ from_task_id: blocker.id, to_task_id: task.id, type: "relates" })}`;
  await app.sql`
    INSERT INTO task_sources ${app.sql({
      provider: "github",
      remote_id: "I_1",
      task_id: task.id,
      url: "https://github.com/aaronmallen/aaronmallen.me/issues/1",
    })}
  `;
  await app.sql`INSERT INTO task_comments ${app.sql({ body: "Looks *good*", task_id: task.id })}`;
  await insertPosts(app, [
    {
      body: 'prose and `code`\n\n## First\n\n### Under the first\n\n## Second\n\n## Third\n\n```ruby\n# greets the reader\nclass Greeter < Base\n  def hello = puts("hello")\nend\n```\n\n> a quote',
      slug: "hello",
      summary: "One line and no more",
      tags: "ruby",
      title: "A published post with a fairly long title",
    },
  ]);
  const [post] = await app.sql`SELECT id FROM posts WHERE slug = 'hello'`;
  for (const [note, at] of [
    ["fixed `code`", "2026-09-07T12:00:00Z"],
    ["fixed a link", "2026-09-09T12:00:00Z"],
    ["fixed a typo", "2026-09-09T15:00:00Z"],
  ]) {
    await app.sql`INSERT INTO post_edits ${app.sql({ created_at: new Date(at), note, note_html: "", post_id: post.id })}`;
  }
  await rendered(app.sql, app.pushJob);
});

Given("a long post {string} with the sections {string}", async ({ app }, title: string, names: string) => {
  const body = names
    .split(", ")
    .map((name) => `## ${name}\n\n${"Words fill the page. ".repeat(80)}`)
    .join("\n\n");
  await insertPosts(app, [{ body, title }]);
});

When("the note {string} is revised to {string}", async ({ app }, note: string, revised: string) => {
  await app.sql`UPDATE post_edits SET note = ${revised}, note_html = '', updated_at = now() WHERE note = ${note}`;
  await rendered(app.sql, app.pushJob);
});

Then("the field labelled {string} is {string}", async ({ page }, label: string, selector: string) => {
  await expect(page.getByLabel(label, { exact: true })).toHaveAttribute("id", selector.replace("#", ""));
});

Then("the names of {string} are:", async ({ page }, selector: string, table: DataTable) => {
  const names = await page.locator(selector).evaluateAll((nodes) => nodes.map((node) => node.getAttribute("name")));
  expect(names).toEqual(table.raw().map(([name]) => name));
});

Then("the {string} of each {string} is:", async ({ page }, attribute: string, selector: string, table: DataTable) => {
  const found = await page
    .locator(selector)
    .evaluateAll((nodes, name) => nodes.map((node) => node.getAttribute(name)), attribute);
  expect(found).toEqual(table.raw().map(([value]) => value));
});

Then("{string} has no {string} attribute", async ({ page }, selector: string, attribute: string) => {
  expect(await page.locator(selector).first().getAttribute(attribute)).toBeNull();
});

Then("{string} does not match the pattern {string}", async ({ page }, selector: string, pattern: string) => {
  expect(((await page.locator(selector).first().textContent()) ?? "").trim()).not.toMatch(new RegExp(pattern));
});

Given("two posts {string} and {string} published at the same moment", async ({ app }, one: string, other: string) => {
  const at = new Date(Math.floor(Date.now() / 1000) * 1000 - 60_000).toISOString();
  await insertPosts(app, [
    { published: at, title: one },
    { published: at, title: other },
  ]);
});
