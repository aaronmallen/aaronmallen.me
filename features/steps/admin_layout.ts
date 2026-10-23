import { expect } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { seal } from "../support/seal.ts";
import { Before, Given, Then, When } from "../support/world.ts";

const texts = (page: import("@playwright/test").Page, selector: string) =>
  page.locator(selector).evaluateAll((nodes) => nodes.map((node) => (node.textContent ?? "").trim()));

const hrefs = (page: import("@playwright/test").Page, selector: string) =>
  page.locator(selector).evaluateAll((nodes) => nodes.map((node) => node.getAttribute("href") ?? ""));

Given("the contact form brings in {string}", async ({ app }, subject: string) => {
  await app.sql`
    INSERT INTO mail_accounts (provider, name)
    SELECT 'contact_form', 'Contact form'
    WHERE NOT EXISTS (SELECT 1 FROM mail_accounts WHERE provider = 'contact_form')
  `;
  const [{ id }] = await app.sql`
    INSERT INTO mail_threads (mail_account_id, subject)
    SELECT id, ${subject} FROM mail_accounts WHERE provider = 'contact_form'
    RETURNING id
  `;
  await app.sql`
    INSERT INTO mail_messages ${app.sql({ body: "Hello.", mail_thread_id: id, reply_to: "ada@example.com", subject })}
  `;
});

When("I fail a GitHub sign-in", async ({ page }) => {
  await page.goto("/admin/auth/github/callback?code=nope&state=nope");
});

Then("the admin markup holds {string}", async ({ page }, selector: string) => {
  await expect(page.locator(selector).first()).toBeAttached();
});

Then("the admin markup holds {int} of {string}", async ({ page }, count: number, selector: string) => {
  await expect(page.locator(selector)).toHaveCount(count);
});

Then("the admin markup lacks {string}", async ({ page }, selector: string) => {
  await expect(page.locator(selector)).toHaveCount(0);
});

Then("the admin texts of {string} are:", async ({ page }, selector: string, table: DataTable) => {
  expect(await texts(page, selector)).toEqual(table.raw().map(([text]) => text));
});

Then("the admin links of {string} are:", async ({ page }, selector: string, table: DataTable) => {
  expect(await hrefs(page, selector)).toEqual(table.raw().map(([href]) => href));
});

Then("the admin links of {string} are, in any order:", async ({ page }, selector: string, table: DataTable) => {
  expect((await hrefs(page, selector)).sort()).toEqual(
    table
      .raw()
      .map(([href]) => href)
      .sort(),
  );
});

Then("the page kicker shows today's date", async ({ page }) => {
  const today = new Intl.DateTimeFormat("en-US", {
    day: "numeric",
    month: "long",
    timeZone: "America/Chicago",
    weekday: "long",
  }).format(new Date());

  await expect(page.locator("main#main .page-head-kicker")).toContainText(today);
});

Then("the switcher sides open with:", async ({ page }, table: DataTable) => {
  const sides = await page
    .locator("#nav-switcher > .switcher-side")
    .evaluateAll((nodes) =>
      nodes.map((side) =>
        [...side.querySelectorAll(".switcher-column")]
          .map((column) => (column.querySelector(".switcher-heading, .switcher-row")?.textContent ?? "").trim())
          .join(", "),
      ),
    );

  expect(sides).toEqual(table.raw().map(([side]) => side));
});

Then("the palette offers the sections:", async ({ page }, table: DataTable) => {
  const groups = "[data-palette-group]:not([aria-labelledby$='-actions']):not([aria-labelledby$='-see-all'])";
  const sections = await page
    .locator(`${groups} [data-palette-option]`)
    .evaluateAll((nodes) => nodes.map((node) => node.getAttribute("data-palette-href")));

  expect(sections).toEqual(table.raw().map(([href]) => href));
});

Then("the main element lists the live tables {string}", async ({ page }, tables: string) => {
  const listed = ((await page.locator("main").first().getAttribute("data-live-tables")) ?? "").split(" ");

  expect(listed).toEqual(expect.arrayContaining(tables.split(" ")));
});

Then("the main element leaves out the live table {string}", async ({ page }, table: string) => {
  const listed = ((await page.locator("main").first().getAttribute("data-live-tables")) ?? "").split(" ");

  expect(listed).not.toContain(table);
});

When("I save a draft post titled {string} from the post editor", async ({ page }, title: string) => {
  await page.goto("/admin/posts/new");
  await page.locator("main").getByLabel("Title", { exact: true }).fill(title);
  await page.getByRole("button", { name: "Save draft" }).click();
  await page.waitForURL((url) => url.pathname !== "/admin/posts/new");
});

When("I load the admin page again", async ({ page }) => {
  await page.reload();
});

Then("the toast is gone within {int} seconds", async ({ page }, seconds: number) => {
  await expect(page.locator("[data-toast]")).toHaveCount(0, { timeout: seconds * 1000 });
});

let listedTables = new Set<string>();

const liveTables = async (page: import("@playwright/test").Page) =>
  ((await page.locator("main").first().getAttribute("data-live-tables")) ?? "").split(" ").filter(Boolean);

Then(
  "each of these admin pages answers 200 and lists the live tables {string}:",
  async ({ page }, tables: string, paths: DataTable) => {
    listedTables = new Set();
    for (const [path] of paths.raw()) {
      const response = await page.goto(path);
      const listed = await liveTables(page);

      expect(response?.status(), path).toBe(200);
      expect(listed, path).toEqual(expect.arrayContaining(tables.split(" ")));
      for (const table of listed) listedTables.add(table);
    }
  },
);

Then("each live table those pages list carries the admin change trigger", async ({ app }) => {
  const rows = await app.sql`
    SELECT DISTINCT c.relname FROM pg_trigger t
    JOIN pg_proc p ON p.oid = t.tgfoid
    JOIN pg_class c ON c.oid = t.tgrelid
    WHERE p.proname = 'notify_admin_change'
  `;
  const triggered = new Set(rows.map(({ relname }) => relname));

  expect([...listedTables].filter((table) => !triggered.has(table))).toEqual([]);
});

When("I post to {string} with a wrong CSRF token", async ({ page }, path: string) => {
  await page.goto("/admin");
  const response = await page.request.post(path, { headers: { "X-CSRF-Token": "wrong" } });
  await page.setContent(await response.text());
});

Then(
  "the main element lists only the live tables of a page nothing lives at and {string}",
  async ({ page }, extra: string) => {
    const listed = await liveTables(page);
    await page.goto("/admin/nowhere");
    const layout = await liveTables(page);

    expect([...listed].sort()).toEqual([...new Set([...layout, ...extra.split(" ")])].sort());
  },
);

When("I type {string} in the field {string}", async ({ page }, text: string, id: string) => {
  await page.locator(`#${id}`).pressSequentially(text);
});

When("I open the key help from the avatar menu", async ({ page }) => {
  await page.locator("button.avatar").click();
  await page.locator(".avatar-menu-item[data-key-help-open]").click();
});

When("I open {string} under {string}", async ({ page }, summary: string, selector: string) => {
  await page.locator(`${selector} summary`, { hasText: summary }).click();
});

Then("the highlighted row holds {string}", async ({ page }, text: string) => {
  await expect
    .poll(() => page.evaluate(() => document.activeElement?.closest("[data-key-row]")?.textContent ?? ""))
    .toContain(text);
});

Then("no row is highlighted", async ({ page }) => {
  expect(await page.evaluate(() => document.activeElement?.closest("[data-key-row]") ?? null)).toBeNull();
});

Then("the highlighted row is the row itself", async ({ page }) => {
  await expect.poll(() => page.evaluate(() => document.activeElement?.matches("[data-key-row]"))).toBe(true);
});

Then("the highlighted row shows its ring", async ({ page }) => {
  await expect(page.locator("[data-key-row]:has(:focus-visible)")).toHaveCount(1);
});

Then("the highlighted row sits inside the window", async ({ page }) => {
  const inside = await page.evaluate(() => {
    const row = document.activeElement?.closest("[data-key-row]");
    return Boolean(row) && (row?.getBoundingClientRect().bottom ?? Infinity) <= window.innerHeight;
  });

  expect(inside).toBe(true);
});

Then("the admin address is {string}", async ({ page }, path: string) => {
  await expect.poll(() => new URL(page.url()).pathname + new URL(page.url()).search).toBe(path);
});

const squeeze = (text: string) => text.replaceAll(/\s+/g, "");

const keyRows = (page: import("@playwright/test").Page) =>
  page
    .locator("#key-help .keys-row")
    .evaluateAll((rows) => rows.filter((row) => row.checkVisibility()).map((row) => row.textContent ?? ""));

Then("the key help is open", async ({ page }) => {
  await expect(page.locator("dialog#key-help[open]")).toHaveCount(1);
});

Then("the key help is shut", async ({ page }) => {
  await expect(page.locator("dialog#key-help[open]")).toHaveCount(0);
});

Then("the key help has the row {string}", async ({ page }, row: string) => {
  expect((await keyRows(page)).map(squeeze)).toContain(squeeze(row));
});

Then("the key help has a row that starts {string}", async ({ page }, row: string) => {
  expect((await keyRows(page)).map(squeeze).some((text) => text.startsWith(squeeze(row)))).toBe(true);
});

Then("the key help has a row with {string}", async ({ page }, text: string) => {
  expect((await keyRows(page)).some((row) => row.includes(text))).toBe(true);
});

Then("the key help has no row with {string}", async ({ page }, text: string) => {
  expect((await keyRows(page)).some((row) => row.includes(text))).toBe(false);
});

Then("the key help has {int} row with {string}", async ({ page }, count: number, text: string) => {
  expect((await keyRows(page)).filter((row) => row.includes(text))).toHaveLength(count);
});

Then("the focus is on the {word} of {string}", async ({ page }, which: string, selector: string) => {
  const all = await texts(page, selector);
  const wanted = { first: all[0], last: all.at(-1), second: all[1] }[which];

  await expect.poll(() => page.evaluate(() => document.activeElement?.textContent?.trim())).toBe(wanted);
});

Then("the field {string} holds {string}", async ({ page }, id: string, value: string) => {
  await expect(page.locator(`#${id}`)).toHaveValue(value);
});

When("I click {string} in the open done panel", async ({ page }, name: string) => {
  await page.locator("details.task-complete[open]").getByRole("button", { exact: true, name }).click();
});

const live = { arrival: Promise.resolve(), asked: new Map<string, number>(), heard: 0, release: () => {} };

Before(() => {
  listedTables = new Set();
  Object.assign(live, { arrival: Promise.resolve(), asked: new Map(), heard: 0, release: () => {} });
});

const askedFor = (path: string) => live.asked.get(path) ?? 0;

const heard = (page: import("@playwright/test").Page) =>
  page.evaluate(() => Number(document.documentElement.dataset.liveHeard) || 0);

const settled = async (page: import("@playwright/test").Page) => {
  await expect.poll(() => heard(page)).toBeGreaterThan(live.heard);
  live.heard = await heard(page);
  await expect.poll(() => page.evaluate(() => document.documentElement.dataset.fetch ?? null)).toBeNull();
};

When("I open {string} and its live stream", async ({ page }, path: string) => {
  live.asked = new Map();
  live.heard = 0;
  page.on("request", (request) => {
    const { pathname } = new URL(request.url());
    if (request.method() === "GET") live.asked.set(pathname, askedFor(pathname) + 1);
  });
  const stream = page.waitForResponse((response) => new URL(response.url()).pathname === "/admin/events");
  await page.goto(path);
  await stream;
});

When("the admin change stream announces {string}", async ({ app }, table: string) => {
  await app.sql`SELECT pg_notify('admin_changes', ${table})`;
});

When("the live page hears it and settles", async ({ page }) => {
  await settled(page);
});

Then("{string} was asked for {int} time(s)", ({}, path: string, count: number) => {
  expect(askedFor(path)).toBe(count);
});

Then("{string} is soon asked for at least {int} times", async ({}, path: string, count: number) => {
  await expect.poll(() => askedFor(path)).toBeGreaterThanOrEqual(count);
});

Then("the live page is asking", async ({ page }) => {
  expect(await page.evaluate(() => document.documentElement.dataset.fetch ?? null)).toBe("asking");
});

When("every refetch of {string} fails", async ({ page }, path: string) => {
  await page.evaluate(() => {
    const counted = window as unknown as { failedToasts: number };
    counted.failedToasts = 0;
    new MutationObserver((changes) => {
      for (const { addedNodes } of changes)
        for (const node of addedNodes)
          if ((node as Element).querySelector?.(".toast-failed")) counted.failedToasts += 1;
    }).observe(document.body, { childList: true });
  });
  await page.route(
    (url) => url.pathname === path,
    (route) => route.fulfill({ body: "", status: 500 }),
  );
});

Then("the failed toast showed once", async ({ page }) => {
  await expect.poll(() => page.evaluate(() => document.documentElement.dataset.fetch ?? null)).toBeNull();
  expect(await page.evaluate(() => (window as unknown as { failedToasts: number }).failedToasts)).toBe(1);
});

When("the next refetch of {string} is held once the server answers", async ({ page }, path: string) => {
  let arrived = () => {};
  live.arrival = new Promise<void>((done) => {
    arrived = done;
  });
  const released = new Promise<void>((done) => {
    live.release = done;
  });
  let held = false;
  await page.route(
    (url) => url.pathname === path,
    async (route) => {
      if (held) return route.continue();
      held = true;
      arrived();
      const response = await route.fetch();
      await released;
      return route.fulfill({ response });
    },
  );
});

When("the held refetch arrives", async () => {
  await live.arrival;
});

When("the held refetch lands", () => {
  live.release();
});

When("the admin session cookie goes away", async ({ context }) => {
  await context.clearCookies({ name: "admin.session" });
});

When("the tab is {word}", async ({ page }, state: string) => {
  await page.evaluate((hidden) => {
    Object.defineProperty(document, "hidden", { configurable: true, value: hidden });
    document.dispatchEvent(new Event("visibilitychange"));
  }, state === "hidden");
});

Then("{string} does not show within a second", async ({ page }, selector: string) => {
  await page.waitForTimeout(1000);
  await expect(page.locator(selector)).toHaveCount(0);
});

Then("{string} shows", async ({ page }, selector: string) => {
  await expect(page.locator(selector).first()).toBeVisible();
});

Then(
  "a browser that keeps the page's policy shows {string} on {string} once the contact form brings in {string}",
  async ({ app, browser, owner }, selector: string, path: string, subject: string) => {
    const context = await browser.newContext({ baseURL: app.url, bypassCSP: false });
    await context.addCookies(owner.cookies);
    const page = await context.newPage();
    const errors: string[] = [];
    page.on("pageerror", (error) => errors.push(error.message));
    const stream = page.waitForResponse((response) => new URL(response.url()).pathname === "/admin/events");
    const answer = await page.goto(path);
    await stream;
    const [{ id }] = await app.sql`
      INSERT INTO mail_threads (mail_account_id, subject)
      SELECT id, ${subject} FROM mail_accounts WHERE provider = 'contact_form'
      RETURNING id
    `;
    await app.sql`
      INSERT INTO mail_messages ${app.sql({ body: "Hello.", mail_thread_id: id, reply_to: "ada@example.com", subject })}
    `;

    expect(answer?.headers()["content-security-policy"]).toContain("script-src 'self'");
    expect(answer?.headers()["content-security-policy"]).not.toContain("unsafe-eval");
    await expect(page.locator(selector.replace("<id>", String(id)))).toBeVisible();
    expect(errors).toEqual([]);
    await context.close();
  },
);

Given("the services hold a {word} connection labelled {string}", async ({ app }, provider: string, label: string) => {
  const scopes: Record<string, string[]> = {
    google: ["openid", "https://www.googleapis.com/auth/gmail.modify"],
    mastodon: ["write:statuses", "write:media", "read:accounts", "read:search", "read:statuses"],
  };
  const host = provider === "mastodon" ? "203.0.113.5" : null;
  const credentials = seal(
    JSON.stringify({ access_token: "token", expires_at: Math.floor(Date.now() / 1000) + 3600, refresh_token: "1//x" }),
  );
  await app.sql`
      INSERT INTO service_connections ${app.sql({
        account_id: label,
        credentials,
        host,
        label,
        provider,
        scopes: scopes[provider] ?? [],
      })}
    `;
});

When("I click the avatar", async ({ page }) => {
  await page.locator("button.avatar").click();
});

Then("the avatar menu marks the current theme", async ({ page }) => {
  const theme = await page.evaluate(
    () =>
      document.documentElement.dataset.siteTheme ??
      (matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"),
  );

  await expect(page.locator(`.avatar-menu-item[data-theme-choice='${theme}'][aria-pressed='true']`)).toBeVisible();
});

When("the live page hears it", async ({ page }) => {
  await expect.poll(() => heard(page)).toBeGreaterThan(live.heard);
  live.heard = await heard(page);
});

When("the live page settles", async ({ page }) => {
  await expect.poll(() => page.evaluate(() => document.documentElement.dataset.fetch ?? null)).toBeNull();
});

When("I start the task {string} from its row", async ({ page }, title: string) => {
  const row = page.locator(".task", { has: page.locator(".task-title", { hasText: title }) });
  await row.hover();
  await row.getByRole("button", { exact: true, name: "Start" }).click();
});

When(
  "I rename the task {string} to {string} in the task panel and close it",
  async ({ page }, title: string, renamed: string) => {
    const changes = page.evaluate(
      () =>
        new Promise<void>((done) => {
          const source = new EventSource("/admin/events");
          source.addEventListener("change", (event) => {
            if (event.data === "tasks") {
              source.close();
              done();
            }
          });
        }),
    );
    await page.locator(".task", { hasText: title }).locator(".task-title").click();
    const panel = page.locator("dialog#task-panel[open]");
    await panel.getByRole("link", { exact: true, name: "Edit" }).click();
    await panel.locator("[data-task-edit] [name='task[title]']").fill(renamed);
    await panel.getByRole("button", { exact: true, name: "Save" }).click();
    await expect(panel.locator("[data-task-read] h1")).toHaveText(renamed);
    await changes;
    await panel.locator("[data-task-read] .task-drawer-close").click();
  },
);

When(
  "I type {string} in {string} and pick its letters {int} to {int}",
  async ({ page }, text: string, selector: string, start: number, end: number) => {
    await page.locator(selector).pressSequentially(text);
    await page.evaluate(
      ([from, to]) => (document.activeElement as HTMLInputElement).setSelectionRange(from, to),
      [start, end],
    );
  },
);

Then(
  "{string} keeps focus, the text {string} and the letters {int} to {int} picked",
  async ({ page }, selector: string, text: string, start: number, end: number) => {
    const field = page.locator(selector);

    await expect(field).toBeFocused();
    await expect(field).toHaveValue(text);
    expect(await field.evaluate((input: HTMLInputElement) => [input.selectionStart, input.selectionEnd])).toEqual([
      start,
      end,
    ]);
  },
);

When(
  "I fill the post editor's {string} with {string} and {string} with {string}",
  async ({ page }, first: string, firstText: string, second: string, secondText: string) => {
    const main = page.locator("main");
    await main.getByLabel(first, { exact: true }).fill(firstText);
    await main.getByLabel(second, { exact: true }).fill(secondText);
    await page.evaluate(() => (document.activeElement as HTMLElement | null)?.blur());
  },
);

Then("the post editor's {string} holds {string}", async ({ page }, label: string, text: string) => {
  await expect(page.locator("main").getByLabel(label, { exact: true })).toHaveValue(text);
});

When("I pick every social account in the composer's memory", async ({ app, page }) => {
  const ids = (await app.sql`SELECT id FROM service_connections ORDER BY id`).map(({ id }) => String(id));
  await page.goto("/admin/social");
  await page.evaluate((picked) => localStorage.setItem("social:accounts", picked), JSON.stringify(ids));
});

Then("every social account stays picked", async ({ app, page }) => {
  const ids = (await app.sql`SELECT id FROM service_connections ORDER BY id`).map(({ id }) => String(id));
  const picked = await page
    .locator("[data-social-target]:checked")
    .evaluateAll((boxes) => boxes.map((box) => (box as HTMLInputElement).value));

  expect(picked.sort()).toEqual(ids.sort());
});

When("I tick every task with select all", async ({ page }) => {
  await page.locator(".task input[name='ids[]']").first().check();
  await page.locator("[data-bulk-all] input").check();
});

When("I ask to delete the journal entry {string}", async ({ page }, body: string) => {
  const entry = page.locator(".journal-entry", { hasText: body });
  await entry.hover();
  await entry.getByRole("button", { exact: true, name: "Delete" }).click();
  await expect(page.locator("[data-confirm-ask]")).toBeVisible();
});

When("I decline the confirm", async ({ page }) => {
  await page.locator("[data-confirm-decline]").click();
});

When("I close the key help", async ({ page }) => {
  await page.locator("dialog#key-help [data-dialog-close]").click();
});

Then("the admin shows the button {string}", async ({ page }, name: string) => {
  await expect(page.getByRole("button", { exact: true, name }).first()).toBeVisible();
});

Then("{string} does not show", async ({ page }, selector: string) => {
  await expect(page.locator(`${selector} >> visible=true`)).toHaveCount(0);
});

Given("the browser keeps hold of the page's event streams", async ({ page }) => {
  await page.addInitScript(() => {
    const streams: EventSource[] = [];
    const Original = window.EventSource;
    window.EventSource = class extends Original {
      constructor(url: string | URL, init?: EventSourceInit) {
        super(url, init);
        streams.push(this);
      }
    };
    (window as unknown as { streams: EventSource[] }).streams = streams;
  });
});

When("the page's event stream drops and its reconnect is held", async ({ page }) => {
  const released = new Promise<void>((done) => {
    live.release = done;
  });
  let arrived = () => {};
  live.arrival = new Promise<void>((done) => {
    arrived = done;
  });
  await page.route(
    (url) => url.pathname === "/admin/events",
    async (route) => {
      arrived();
      await released;
      return route.continue();
    },
  );
  await page.evaluate(() => {
    for (const stream of (window as unknown as { streams: EventSource[] }).streams) {
      stream.close();
      stream.dispatchEvent(new Event("error"));
    }
  });
  await live.arrival;
});

When("the reconnect goes through", () => {
  live.release();
});

const devices: Record<string, { height: number; width: number }> = {
  desk: { height: 800, width: 1280 },
  phone: { height: 844, width: 390 },
};

Given("I read the admin on a {word}", async ({ page }, device: string) => {
  await page.setViewportSize(devices[device]);
});

Then("the screen holds to the size it is read on", async ({ page }) => {
  const faults = await page.evaluate(
    ({ phoneBelow, smallestTap, smallestText }) => {
      const width = window.innerWidth;
      const named = (el: Element) =>
        el.tagName.toLowerCase() + (el.classList.length ? `.${[...el.classList].join(".")}` : "");
      const shown = (el: Element) => el.getClientRects().length > 0;
      const seen = (el: Element) =>
        shown(el) && el.checkVisibility({ opacityProperty: true, visibilityProperty: true });
      const hidden = (el: Element) => el.closest(".sr-only, .skip-link, .top-bar-skip");
      const scrolled = (el: Element) => {
        for (let node = el.parentElement; node && node !== document.body; node = node.parentElement)
          if (getComputedStyle(node).overflowX !== "visible") return true;
        return false;
      };
      const target = (el: Element) => {
        if (el instanceof HTMLLabelElement) {
          const field = el.htmlFor && document.getElementById(el.htmlFor);
          return !field || !shown(field);
        }
        return !el.closest("label");
      };
      const phone = width < phoneBelow;
      const wide = document.documentElement.scrollWidth;
      const pageFaults = phone && wide > width ? [`the page is ${wide}px wide on a ${width}px phone`] : [];
      const overflow = !phone
        ? []
        : [...document.querySelectorAll("body *")]
            .filter((el) => shown(el) && !hidden(el) && !scrolled(el))
            .filter((el) => el.getBoundingClientRect().right > width + 1)
            .map((el) => `${named(el)} reaches ${Math.round(el.getBoundingClientRect().right)}px`);
      const controls = !phone
        ? []
        : [...document.querySelectorAll("a[href],button,input,select,textarea,summary,label[for]")]
            .filter(
              (el) =>
                shown(el) &&
                (el as HTMLInputElement).type !== "hidden" &&
                !hidden(el) &&
                !el.closest(".site-header") &&
                target(el),
            )
            .map((el) => ({ box: el.getBoundingClientRect(), name: named(el) }))
            .filter(({ box }) => box.height < smallestTap || box.width < smallestTap)
            .map(({ box, name }) => `${name} is ${Math.round(box.width)}x${Math.round(box.height)}`);
      const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
      const nodes: Node[] = [];
      for (let node = walker.nextNode(); node; node = walker.nextNode()) nodes.push(node);
      const text = nodes
        .filter((node) => (node.textContent ?? "").trim().length > 0)
        .map((node) => node.parentElement as Element)
        .filter((el) => el && seen(el) && !hidden(el))
        .map((el) => ({ name: named(el), size: Number.parseFloat(getComputedStyle(el).fontSize) }))
        .filter(({ size }) => size < smallestText)
        .map(({ name, size }) => `${name} reads at ${size}px`);
      return [...new Set([...pageFaults, ...overflow, ...controls, ...text])];
    },
    { phoneBelow: 700, smallestTap: 44, smallestText: 12 },
  );
  const idle = await page.evaluate(async () => {
    await document.fonts.ready;
    const bare = (family: string) => family.replaceAll('"', "");
    const faces = [...document.styleSheets]
      .flatMap((sheet) => [...sheet.cssRules])
      .filter((rule): rule is CSSFontFaceRule => rule instanceof CSSFontFaceRule);
    const source = (rule: CSSFontFaceRule) => {
      const url = rule.style.getPropertyValue("src").match(/url\(\s*["']?([^"')]+)/)?.[1] ?? "";
      return new URL(url, rule.parentStyleSheet?.href ?? location.href).href;
    };
    const drawn = (rule: CSSFontFaceRule) =>
      [...document.fonts].some(
        (font) =>
          font.status === "loaded" &&
          bare(font.family) === bare(rule.style.getPropertyValue("font-family")) &&
          font.style === rule.style.getPropertyValue("font-style") &&
          font.unicodeRange === rule.style.getPropertyValue("unicode-range"),
      );
    return [...document.querySelectorAll<HTMLLinkElement>('link[rel="preload"][as="font"]')]
      .filter((link) => !faces.some((rule) => source(rule) === link.href && drawn(rule)))
      .map((link) => `${link.getAttribute("href")} is preloaded but never drawn`);
  });

  expect([...faults, ...idle]).toEqual([]);
});

Then("Tab reaches every control in order behind a ring", async ({ page }) => {
  const stops = await page.evaluate(() => {
    const modal = document.querySelector("dialog:modal");
    const scope = modal ?? document;
    const marked = [
      ...scope.querySelectorAll<HTMLElement>("a[href], button, input, select, textarea, summary, [tabindex]"),
    ]
      .filter(
        (el) => el.tabIndex >= 0 && !(el as HTMLButtonElement).disabled && (el as HTMLInputElement).type !== "hidden",
      )
      .filter((el) => el.checkVisibility({ opacityProperty: !el.closest(".hov"), visibilityProperty: true }))
      .filter((el) => {
        const radio = el as HTMLInputElement;
        if (radio.type !== "radio" || !radio.name) return true;
        const group = [...document.getElementsByName(radio.name)].filter(
          (other) => (other as HTMLInputElement).type === "radio" && (other as HTMLInputElement).form === radio.form,
        ) as HTMLInputElement[];
        return radio === (group.find((other) => other.checked) ?? group[0]);
      })
      .map((el, index) => {
        el.dataset.tabStop = `${index}: ${el.outerHTML.slice(0, 60)}`;
        return el.dataset.tabStop;
      });
    const top = document.createElement("span");
    top.tabIndex = -1;
    ((modal as HTMLElement | null) ?? document.body).prepend(top);
    top.focus();
    return marked;
  });
  const tab = async () => {
    await page.keyboard.press("Tab");
    return page.evaluate(() => {
      const active = document.activeElement as HTMLElement;
      const style = getComputedStyle(active);
      const outline = style.outlineStyle !== "none" && Number.parseFloat(style.outlineWidth) > 0;
      return { ring: outline || style.boxShadow !== "none", stop: active.dataset.tabStop };
    });
  };
  const walked: { ring: boolean; stop?: string }[] = [];
  for (let index = 0; index < stops.length; index += 1) {
    const last = walked.at(-1)?.stop ?? "top";
    let step = await tab();
    for (let extra = 0; extra < 6 && step.stop === last; extra += 1) step = await tab();
    walked.push(step);
  }

  expect(walked.map(({ stop }) => stop)).toEqual(stops);
  expect(walked.filter(({ ring }) => !ring).map(({ stop }) => stop)).toEqual([]);
});

const dialogKeys: Record<string, string> = {
  "command palette": "/",
  "create task": "c",
  journal: "w",
  "key help": "?",
};

When("I open the admin dialog {string}", async ({ page }, dialog: string) => {
  await page.keyboard.press(dialogKeys[dialog]);
  await expect(page.locator("dialog[open]").first()).toBeVisible();
});
