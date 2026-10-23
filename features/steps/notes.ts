import { expect, type Page } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import type postgres from "postgres";
import { Given, Then, When } from "../support/world.ts";

const minute = 60 * 1000;
const wikiLink = /\[\[([^\]|\n]+)(?:\|([^\]\n]+))?\]\]/g;

export async function folderAt(sql: postgres.Sql, path: string) {
  let parent: number | null = null;
  for (const name of path.split("/").filter(Boolean)) {
    const [found] = await sql`
      SELECT id FROM note_folders WHERE lower(name) = lower(${name}) AND parent_id IS NOT DISTINCT FROM ${parent}
    `;
    parent = found
      ? found.id
      : (await sql`INSERT INTO note_folders ${sql({ name, parent_id: parent })} RETURNING id`)[0].id;
  }
  return parent;
}

export async function tagged(sql: postgres.Sql, name: string, scope = "private") {
  const [found] = await sql`SELECT id FROM tags WHERE name = ${name} AND scope = ${scope}`;
  return found ? found.id : (await sql`INSERT INTO tags ${sql({ color: "mk-blue", name, scope })} RETURNING id`)[0].id;
}

export async function noteId(sql: postgres.Sql, title: string) {
  const [note] = await sql`SELECT id FROM notes WHERE title = ${title}`;
  expect(note, `the note ${title}`).toBeTruthy();
  return note.id as number;
}

export async function folderId(sql: postgres.Sql, path: string) {
  const id = await folderAt(sql, path);
  return id as number;
}

async function insertNote(sql: postgres.Sql, row: Record<string, string>) {
  const body = (row.body ?? "").replaceAll("\\n", "\n");
  const edited = new Date(Date.now() - Number(row.edited ?? 0) * minute);
  const [{ id }] = await sql`
    INSERT INTO notes ${sql({
      body,
      created_at: edited,
      folder_id: row.folder ? await folderAt(sql, row.folder) : null,
      pinned: row.pinned === "yes",
      title: row.title,
      updated_at: edited,
      written_by_agent: row.agent === "yes",
    })}
    RETURNING id
  `;
  const titles = [
    ...new Map([...body.matchAll(wikiLink)].map(([, title]) => [title.trim().toLowerCase(), title.trim()])).values(),
  ];
  for (const title of titles) await sql`INSERT INTO note_links ${sql({ note_id: id, title })}`;
  for (const tag of (row.tags ?? "").split(" ").filter(Boolean)) {
    await sql`INSERT INTO note_tags ${sql({ note_id: id, tag_id: await tagged(sql, tag) })}`;
  }
}

Given("the note folder {string}", async ({ app }, path: string) => {
  await folderAt(app.sql, path);
});

Given("the note folder {string} described as {string}", async ({ app }, path: string, description: string) => {
  await app.sql`UPDATE note_folders SET description = ${description} WHERE id = ${await folderAt(app.sql, path)}`;
});

Given("the notes:", async ({ app }, table: DataTable) => {
  for (const row of table.hashes()) await insertNote(app.sql, row);
});

Given("the note {string}", async ({ app }, title: string) => {
  await insertNote(app.sql, { title });
});

Given("{int} more notes edited an hour ago", async ({ app }, count: number) => {
  for (let index = 1; index <= count; index++) await insertNote(app.sql, { edited: "60", title: `Older ${index}` });
});

async function folderPage(sql: postgres.Sql, path: string) {
  return `/admin/notes/folders/${await folderId(sql, path)}`;
}

function menu(page: Page) {
  return page.locator("[data-context-menu]").last();
}

When("I open the notes", async ({ page }) => {
  await page.goto("/admin/notes");
});

When("I open the note {string}", async ({ app, page }, title: string) => {
  await page.goto(`/admin/notes/${await noteId(app.sql, title)}`);
});

When("I edit the note {string}", async ({ app, page }, title: string) => {
  await page.goto(`/admin/notes/${await noteId(app.sql, title)}?edit=1`);
});

When("I open the note folder {string}", async ({ app, page }, path: string) => {
  await page.goto(await folderPage(app.sql, path));
});

When("I search the notes for {string}", async ({ page }, text: string) => {
  const search = page.getByRole("searchbox", { name: "Search notes" });
  await search.fill(text);
  await Promise.all([page.waitForURL(/[?&]q=/), search.press("Enter")]);
});

When("I right-click the note {string} in the tree", async ({ page }, title: string) => {
  await page.locator(".nt-tree a.nt-r", { hasText: title }).first().click({ button: "right" });
  await expect(menu(page)).toBeVisible();
});

When("I right-click the note folder {string} in the tree", async ({ page }, name: string) => {
  await page
    .locator(".nt-tree a.nt-dl", { has: page.getByText(name, { exact: true }) })
    .first()
    .click({ button: "right" });
  await expect(menu(page)).toBeVisible();
});

When("I right-click the notes sidebar", async ({ page }) => {
  await page.locator(".nt-side").click({ button: "right", position: { x: 5, y: 5 } });
  await expect(menu(page)).toBeVisible();
});

When("I choose {string} in the menu", async ({ page }, name: string) => {
  const start = new RegExp(`^${name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`);
  await menu(page).locator(".ctx-item:visible").filter({ hasText: start }).first().click();
});

When("I type {string} in the menu field {string}", async ({ page }, text: string, field: string) => {
  const input = page
    .locator("[data-context-menu]")
    .getByRole("textbox", { exact: true, name: field })
    .locator("visible=true");
  await input.fill(text);
  await input.press("Enter");
});

When("I type {string} in the note body", async ({ page }, text: string) => {
  await page.locator("textarea[name='note[body]']").fill(text);
});

When("I type {string} as the note title", async ({ page }, text: string) => {
  await page.locator("input[name='note[title]']").fill(text);
});

When("I leave the note title", async ({ page }) => {
  await page.locator("textarea[name='note[body]']").click();
});

When("I add the tag {string} to the open note", async ({ page }, tag: string) => {
  await page.locator(".nt-ta-add").click();
  await page.locator("[data-note-tag-input]").fill(tag);
  await page.locator("[data-note-tag-input]").press("Enter");
});

When("I make the note folder {string} from the tree", async ({ page }, path: string) => {
  await page.locator("#note-new-folder").click();
  await page.getByRole("textbox", { name: "New folder path" }).fill(path);
  await page.getByRole("textbox", { name: "New folder path" }).press("Enter");
});

When("I fold the note folder {string}", async ({ page }, name: string) => {
  await page
    .locator("summary.nt-dr", { has: page.getByText(`Fold ${name}`, { exact: true }) })
    .evaluate((summary: HTMLElement) => summary.click());
});

When("the note {string} changes elsewhere", async ({ app }, title: string) => {
  await app.sql`UPDATE notes SET body = 'Agent', version = version + 1 WHERE title = ${title}`;
});

Then("the note tree lists {string}", async ({ page }, titles: string) => {
  await expect(page.locator(".nt-tree a.nt-r .nt-t")).toHaveText(titles.split(", "));
});

Then("the note tree lists the pinned note {string} first", async ({ page }, title: string) => {
  await expect(page.locator(".nt-side > form.nt-sr:first-child + p.nt-g + a.nt-r")).toHaveText(title);
});

Then("the tree holds the note folder {string}", async ({ page }, name: string) => {
  await expect(page.locator("a.nt-dl", { has: page.getByText(name, { exact: true }) })).toBeVisible();
});

Then("the note folder {string} shows {int} notes in the tree", async ({ page }, name: string, count: number) => {
  await expect(
    page
      .locator("a.nt-dl", { has: page.getByText(name, { exact: true }) })
      .first()
      .locator(".nt-n"),
  ).toHaveText(String(count));
});

Then("the note folder {string} is marked empty with a way to remove it", async ({ app, page }, name: string) => {
  const folder = page.locator(`details[data-note-folder='${await folderId(app.sql, name)}']`);
  await expect(folder.locator(".nt-emp")).toHaveText("Empty");
  await expect(folder.locator("form[action$='/delete']")).toHaveCount(1);
});

Then("the note folder {string} offers no way to remove it", async ({ app, page }, name: string) => {
  const folder = page.locator(`details[data-note-folder='${await folderId(app.sql, name)}'] > .nt-da`);
  await expect(folder.locator("form[action$='/delete']")).toHaveCount(0);
});

Then("the note folder {string} offers a new note and a new subfolder", async ({ app, page }, path: string) => {
  const id = await folderId(app.sql, path);
  await expect(page.locator(`.nt-da form[action='/admin/notes'] input[name='folder_id'][value='${id}']`)).toHaveCount(
    1,
  );
  await expect(page.locator(`button[data-note-new-folder='${path}/']`)).toHaveCount(1);
});

Then(
  "the notes home lists {int} recent notes, the first in {string}",
  async ({ page }, count: number, path: string) => {
    await expect(page.locator(".nt-rw")).toHaveCount(count);
    await expect(page.locator(".nt-rw").first().locator(".nt-mt")).toContainText(path);
  },
);

Then("the note search finds {string}", async ({ page }, hits: string) => {
  const found = page.locator(".nt-side a.nt-hit");
  await expect(found.locator(".nt-t")).toHaveText(hits.split(", "));
});

Then("the note search hit {string} sits in {string}", async ({ page }, title: string, place: string) => {
  const hit = page.locator(".nt-side a.nt-hit", { has: page.getByText(title, { exact: true }) });
  await expect(hit.locator(".nt-p")).toHaveText(place);
});

Then("the note search counts {string}", async ({ page }, text: string) => {
  await expect(page.locator(".nt-side p.nt-g")).toHaveText(text);
  await expect(page.locator(".nt-tree")).toHaveCount(0);
});

Then("the note search hit {string} keeps the search", async ({ page }, title: string) => {
  await expect(page.getByRole("link", { name: title }).first()).toHaveAttribute("href", /\/admin\/notes\/\d+\?q=\w+$/);
});

Then("the note search offers to create {string}", async ({ page }, title: string) => {
  await expect(
    page.locator(`.nt-side form[action='/admin/notes'] input[name='title'][value='${title}'] ~ button`),
  ).toHaveText(`Create “${title}”`);
});

Then("the note search offers to create it in {string}", async ({ app, page }, path: string) => {
  const id = await folderId(app.sql, path);
  await expect(page.locator(`.nt-side form[action='/admin/notes'] input[name='folder_id'][value='${id}']`)).toHaveCount(
    1,
  );
});

Then("the note search offers nothing to create", async ({ page }) => {
  await expect(page.locator(".nt-side form[action='/admin/notes'] input[name='title']")).toHaveCount(0);
});

Then("the note search box asks for {string}", async ({ page }, placeholder: string) => {
  await expect(page.getByRole("searchbox", { name: "Search notes" })).toHaveAttribute("placeholder", placeholder);
});

Then("the note search stays on the note {string}", async ({ app, page }, title: string) => {
  const id = await noteId(app.sql, title);
  await expect(page.locator(`form.nt-sr[action='/admin/notes/${id}']`)).toHaveCount(1);
  await expect(page.locator(".nt-h")).toHaveText(title);
});

Then("the note {string} reads {string}", async ({ app }, title: string, body: string) => {
  await expect
    .poll(async () => (await app.sql`SELECT body FROM notes WHERE title = ${title}`)[0]?.body)
    .toBe(body.replaceAll("\\n", "\n"));
});

Then("the note {string} sits in {string}", async ({ app }, title: string, path: string) => {
  const want = path ? await folderId(app.sql, path) : null;
  await expect
    .poll(async () => (await app.sql`SELECT folder_id FROM notes WHERE title = ${title}`)[0]?.folder_id)
    .toBe(want);
});

Then("the note {string} carries the tags {string}", async ({ app }, title: string, tags: string) => {
  await expect
    .poll(async () =>
      (
        await app.sql`
          SELECT tags.name FROM tags JOIN note_tags ON note_tags.tag_id = tags.id JOIN notes ON notes.id = note_id
          WHERE notes.title = ${title} ORDER BY tags.name
        `
      ).map(({ name }) => name),
    )
    .toEqual(tags.split(" ").filter(Boolean));
});

Then("there is no note {string}", async ({ app }, title: string) => {
  await expect.poll(async () => (await app.sql`SELECT id FROM notes WHERE title = ${title}`).length).toBe(0);
});

Then("there is a note {string}", async ({ app }, title: string) => {
  await expect.poll(async () => (await app.sql`SELECT id FROM notes WHERE title = ${title}`).length).toBe(1);
});

Then("there is no note folder {string}", async ({ app }, name: string) => {
  await expect.poll(async () => (await app.sql`SELECT id FROM note_folders WHERE name = ${name}`).length).toBe(0);
});

Then("the note folder {string} sits in {string}", async ({ app }, name: string, path: string) => {
  const want = path ? await folderId(app.sql, path) : null;
  await expect
    .poll(async () => (await app.sql`SELECT parent_id FROM note_folders WHERE name = ${name}`)[0]?.parent_id)
    .toBe(want);
});

Then("I am on the note {string}", async ({ app, page }, title: string) => {
  const id = await noteId(app.sql, title);
  await expect(page).toHaveURL((url) => url.pathname === `/admin/notes/${id}`);
});

Then("I am editing the note {string}", async ({ app, page }, title: string) => {
  const id = await noteId(app.sql, title);
  await expect(page).toHaveURL((url) => url.pathname === `/admin/notes/${id}` && url.search === "?edit=1");
  await expect(page.locator("input[name='note[title]']")).toHaveValue(title);
});

Then("I am on the note folder {string}", async ({ app, page }, path: string) => {
  const target = await folderPage(app.sql, path);
  await expect(page).toHaveURL((url) => url.pathname === target);
});

Then("the note title field holds {string}", async ({ page }, title: string) => {
  await expect(page.locator("input[name='note[title]']")).toHaveValue(title);
});

Then("the note status says it saved", async ({ page }) => {
  await expect(page.locator("[data-note-status]")).toHaveText(/saved \d/);
});

Then("the note page heads with {string}", async ({ page }, title: string) => {
  await expect(page.locator("h1.nt-h")).toHaveText(title);
});

Then("the note editor shows no refusal", async ({ page }) => {
  await expect(page.locator("[data-note-refused]")).toBeHidden();
});

Then("the note editor holds the version {int}", async ({ page }, version: number) => {
  await expect(page.locator("form[data-note-editor] input[name='note[version]']")).toHaveValue(String(version));
});

Then("the note editor says {string}", async ({ page }, text: string) => {
  await expect(
    page.locator("[data-note-refused], [data-note-title-error]").filter({ hasText: text }).first(),
  ).toBeVisible();
});

Then("the note body shows {string} in bold", async ({ page }, text: string) => {
  await expect(page.locator(".nt-prose strong")).toHaveText(text);
});

Then("the note page shows the path {string}", async ({ page }, crumb: string) => {
  await expect(page.locator(".nt-crumb")).toHaveText(crumb);
});

Then("the note facts say {string}", async ({ page }, facts: string) => {
  await expect(page.locator(".nt-facts .nt-mt")).toHaveText(new RegExp(facts));
});

Then("the note shows the tag {string}", async ({ page }, tag: string) => {
  await expect(page.locator(".nt-tags a.tag", { hasText: tag })).toHaveCount(1);
});

Then("deleting the note asks {string}", async ({ page }, question: string) => {
  await expect(page.locator(`form[action$='/delete'][data-confirm='${question}']`)).toHaveCount(1);
});

Then("the wiki link {string} opens the note {string}", async ({ app, page }, text: string, title: string) => {
  const id = await noteId(app.sql, title);
  await expect(page.locator(".nt-prose a.wl", { hasText: text })).toHaveAttribute("href", `/admin/notes/${id}`);
});

Then(
  "the wiki link {string} is a button that makes it in {string}",
  async ({ app, page }, title: string, path: string) => {
    await expect(page.locator(`.nt-prose button.wl.miss[value='${title}']`)).toHaveText(title);
    const id = await folderId(app.sql, path);
    await expect(page.locator(`form#note-create input[name='folder_id'][value='${id}']`)).toHaveCount(1);
  },
);

When("I click the missing wiki link {string}", async ({ page }, title: string) => {
  await page.locator(".nt-prose").getByRole("button", { name: title }).click();
});

Then("the note lists the backlink {string} with {string}", async ({ page }, title: string, line: string) => {
  await expect(page.locator(".nt-links li.nt-bl a", { hasText: title })).toContainText(line);
});

Then("the note links out to {string}", async ({ page }, rows: string) => {
  await expect(page.locator(".nt-links li.record-link-row")).toHaveText(rows.split(", "));
});

Then(
  "the notes home lists {string} linked but not written from {string}",
  async ({ page }, title: string, from: string) => {
    await expect(page.locator(".nt-links .card-title", { hasText: "Linked, not written" })).toBeVisible();
    await expect(page.locator(".nt-ms", { hasText: title })).toContainText(`from ${from}`);
    await expect(page.locator(`form[action='/admin/notes'] input[name='title'][value='${title}']`)).toHaveCount(1);
  },
);

Then("the notes home counts {string} for {string}", async ({ page }, text: string, title: string) => {
  await expect(page.locator(".nt-rw", { hasText: title })).toContainText(text);
});

Then("the menu offers {string}", async ({ page }, items: string) => {
  const names = await menu(page)
    .locator(".ctx-label, .ctx-input")
    .evaluateAll((nodes) =>
      nodes.map((node) => (node instanceof HTMLInputElement ? node.placeholder : node.textContent?.trim())),
    );
  expect(names).toEqual(expect.arrayContaining(items.split(", ")));
});

Then("the menu leaves out {string}", async ({ page }, item: string) => {
  await expect(menu(page).locator(".ctx-label", { hasText: new RegExp(`^${item}$`) })).toHaveCount(0);
});

Then("the menu copies {string}", async ({ page }, text: string) => {
  await expect(menu(page).locator(`button[data-copy='${text}']`)).toHaveText(/Copy link/);
});

Then("the note links list {string}", async ({ page }, title: string) => {
  await expect(page.locator(".record-links").getByRole("link", { name: title })).toBeVisible();
});

Then("the note links from folders list {string}", async ({ page }, rows: string) => {
  const field = page.locator(".nt-meta .field", { hasText: "From folders" });
  await expect(field.locator("li")).toHaveText(rows.split(", "));
});

Then("the note shows no links from folders", async ({ page }) => {
  await expect(page.locator(".nt-meta .field", { hasText: "From folders" })).toHaveCount(0);
});

Then("the notes tab is open with a count of {int}", async ({ page }, count: number) => {
  const tab = page.locator("a.screen-tab[href='/admin/notes']");
  await expect(tab).toHaveAttribute("aria-current", "page");
  await expect(tab.locator(".screen-tab-note")).toHaveText(String(count));
});

Then("the switcher links the notes with a note icon", async ({ page }) => {
  await expect(page.locator(".switcher-panel a.switcher-row[href='/admin/notes'] i.fa-note-sticky")).toHaveCount(1);
});

Then("the note folder {string} is folded", async ({ app, page }, name: string) => {
  await expect(page.locator(`details[data-note-folder='${await folderId(app.sql, name)}']`)).not.toHaveAttribute(
    "open",
  );
});

Then("the notes tree is hidden", async ({ page }) => {
  await expect(page.locator(".nt-side")).toBeHidden();
});

Then("the notes tree shows", async ({ page }) => {
  await expect(page.locator(".nt-side")).toBeVisible();
});

Then(
  "the folder page heads with {string}, {string} and {string}",
  async ({ page }, name: string, description: string, counts: string) => {
    await expect(page.locator("h1.nt-h")).toHaveText(name);
    await expect(page.locator("h1.nt-h i.fa-folder-open")).toHaveCount(1);
    await expect(page.locator(".nt-fd")).toHaveText(description);
    await expect(page.locator(".nt-fm")).toHaveText(new RegExp(`${counts}\\s*last edited`));
  },
);

Then("the folder page shows the path back to {string}", async ({ app, page }, path: string) => {
  const link = page.locator(".nt-crumb a.nt-cb", { hasText: path.split("/").at(-1) });
  await expect(link).toHaveAttribute("href", await folderPage(app.sql, path));
});

Then("the tree marks the note folder {string} open", async ({ page }, name: string) => {
  await expect(page.locator(".nt-tree a.nt-dl[aria-current='page']")).toContainText(name);
  await expect(page.locator(".nt-tree summary.nt-dr.on")).toContainText(name);
});

Then("the folder page gathers the tag {string}", async ({ page }, tag: string) => {
  await expect(page.locator(".nt-fh .nt-tags a.tag")).toHaveText(tag);
});

Then("the folder page lists {string}", async ({ page }, rows: string) => {
  await expect(page.locator(".nt-ix .nt-rt")).toHaveText(rows.split(", "));
});

Then("the folder page shows {string} as empty", async ({ page }, name: string) => {
  await expect(page.locator(".nt-ix .nt-rw", { hasText: name })).toContainText("empty");
});

Then(
  "the folder page shows {string} pinned with the excerpt {string}",
  async ({ page }, title: string, excerpt: string) => {
    const row = page.locator(".nt-ix .nt-rw", { hasText: title });
    await expect(row.locator("i.fa-thumbtack[aria-label='pinned']")).toHaveCount(1);
    await expect(row.locator(".nt-ex")).toHaveText(excerpt);
    await expect(row.locator(".nt-mt a.tag")).toHaveCount(1);
  },
);

Then(
  "the folder page shows {string} with {string} and {string}",
  async ({ page }, title: string, words: string, backlinks: string) => {
    const row = page.locator(".nt-ix .nt-rw", { hasText: title });
    await expect(row).toContainText(words);
    await expect(row).toContainText(backlinks);
  },
);

Then("the folder page makes notes and subfolders in {string}", async ({ app, page }, path: string) => {
  const id = await folderId(app.sql, path);
  await expect(page.locator(`.nt-bar form[action='/admin/notes'] input[name='folder_id'][value='${id}']`)).toHaveCount(
    1,
  );
  await expect(
    page.locator(`.nt-bar form[action='/admin/notes/folders'] input[name='prefix'][value='${path}/']`),
  ).toHaveCount(1);
});

Then("removing the folder asks {string}", async ({ page }, question: string) => {
  await expect(page.locator(`form[action$='/delete'][data-confirm='${question}']`)).toHaveCount(1);
});

Then("the menu counts {int} beside {string}", async ({ page }, count: number, item: string) => {
  const entry = menu(page).getByRole("menuitem", { name: item });
  await expect(entry.locator(".ctx-hint")).toHaveText(String(count));
});

Then("removing the folder from the menu warns {string}", async ({ page }, warning: string) => {
  await expect(menu(page).locator(`[data-confirm-inline='${warning}']`)).toHaveCount(1);
});

When("I rename the open folder to {string}", async ({ page }, name: string) => {
  const input = page.locator("form[action$='/rename'] input[name='name']");
  await input.fill(name);
  await input.press("Enter");
});

When("I move the open folder to {string}", async ({ page }, path: string) => {
  const input = page.locator("input[name='path'][list='note-folder-places']");
  await input.fill(path);
  await input.press("Enter");
});

Then("the folder settings offer to move into {string}", async ({ page }, places: string) => {
  const values = await page
    .locator("#note-folder-places option")
    .evaluateAll((options) => options.map((option) => (option as HTMLOptionElement).value));
  expect(values.sort()).toEqual(places.split(", "));
});

When("I describe the open folder as {string}", async ({ page }, text: string) => {
  const form = page.locator("form[action$='/describe']");
  await form.locator("[name='description']").fill(text);
  await form.evaluate((element: HTMLFormElement) => element.requestSubmit());
});

When("I describe the open folder with {int} letters", async ({ page }, count: number) => {
  const form = page.locator("form[action$='/describe']");
  await form.locator("[name='description']").evaluate((field: HTMLTextAreaElement, size) => {
    field.removeAttribute("maxlength");
    field.value = "x".repeat(size);
  }, count);
  await form.evaluate((element: HTMLFormElement) => element.requestSubmit());
});

When("I link the {word} {string} from the record picker", async ({ page }, kind: string, title: string) => {
  await page.getByRole("searchbox", { name: "Link a record" }).fill(title);
  await page.getByRole("searchbox", { name: "Link a record" }).press("Enter");
  await page.locator(".record-picker-results").getByRole("button", { name: title }).click();
  void kind;
});

When("I unlink {string} from the linked records", async ({ page }, title: string) => {
  await page.locator(".record-links li", { hasText: title }).getByRole("button").click();
});

Then("the linked records list {string}", async ({ page }, title: string) => {
  await expect(page.locator(".record-links").first().getByRole("link", { name: title })).toBeVisible();
});

Then("the linked records list nothing", async ({ page }) => {
  await expect(page.locator(".record-links").first()).toContainText("Nothing linked yet.");
});

Then("the record picker finds {string}", async ({ page }, group: string) => {
  await expect(page.locator(".record-picker-results")).toContainText(group);
});

Then("the linked records link {string} to the note {string}", async ({ app, page }, title: string, note: string) => {
  const link = page.locator(".record-links").getByRole("link", { name: title });
  await expect(link).toHaveAttribute("href", `/admin/notes/${await noteId(app.sql, note)}`);
});

Then(
  "the linked records link {string} to the note folder {string}",
  async ({ app, page }, name: string, path: string) => {
    const link = page.locator(".record-links").getByRole("link", { name });
    await expect(link).toHaveAttribute("href", await folderPage(app.sql, path));
  },
);

Then("the parent folder links list {string} from {string}", async ({ page }, title: string, folder: string) => {
  const card = page.locator(".nt-meta .card", { hasText: "From parent folders" });
  await expect(card.getByRole("link", { name: title })).toBeVisible();
  await expect(card).toContainText(folder);
  await expect(card.locator("form")).toHaveCount(0);
});

Then("the folder page shows no parent folder links", async ({ page }) => {
  await expect(page.getByText("From parent folders")).toHaveCount(0);
});

Then("the note {string} was written by an agent", async ({ app }, title: string) => {
  const [note] = await app.sql`SELECT written_by_agent FROM notes WHERE title = ${title}`;
  expect(note.written_by_agent).toBe(true);
});

Then("the note folders are {string}", async ({ app }, names: string) => {
  const rows = await app.sql`SELECT name FROM note_folders ORDER BY name`;
  expect(rows.map(({ name }) => name)).toEqual(names.split(", "));
});

Then("the folder page shows {string} with no backlinks", async ({ page }, title: string) => {
  await expect(page.locator(".nt-ix .nt-rw", { hasText: title })).not.toContainText("backlink");
});
