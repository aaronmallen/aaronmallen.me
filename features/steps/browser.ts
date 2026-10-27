import { expect } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { Given, Then, When } from "../support/world.ts";

Given("I see the page in {word} mode", async ({ page }, scheme: "light" | "dark") => {
  await page.emulateMedia({ colorScheme: scheme });
});

Given("I prefer reduced motion", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
});

When("I write the post body:", async ({ page }, body: string) => {
  await page.getByLabel("Body", { exact: true }).fill(body);
});

When("I click the element {string}", async ({ page }, selector: string) => {
  await page.locator(selector).first().click();
});

When("I click the button {string}", async ({ page }, name: string) => {
  await page.getByRole("button", { name }).first().click();
});

When("I hover over {string}", async ({ page }, selector: string) => {
  await page.locator(selector).first().hover();
});

When("I focus {string} from the keyboard", async ({ page }, selector: string) => {
  await page
    .locator(selector)
    .first()
    .evaluate((node) => (node as HTMLElement).focus({ focusVisible: true } as FocusOptions));
});

Then("{string} is visible", async ({ page }, selector: string) => {
  await expect(page.locator(selector).first()).toBeVisible();
});

Then("{string} is hidden", async ({ page }, selector: string) => {
  await expect(page.locator(selector).first()).toBeHidden();
});

Then("the focus is on {string}", async ({ page }, selector: string) => {
  await expect(page.locator(selector).first()).toBeFocused();
});

Then("the {string} of {string} is {string}", async ({ page }, property: string, selector: string, value: string) => {
  await expect
    .poll(() =>
      page
        .locator(selector)
        .first()
        .evaluate((node, name) => getComputedStyle(node).getPropertyValue(name), property),
    )
    .toBe(value);
});

Then("the {string} of {string} is the color {string}", async ({ page }, property: string, selector, css: string) => {
  const resolved = await page.evaluate((color) => {
    const probe = document.createElement("span");
    probe.style.color = color;
    document.body.append(probe);
    const value = getComputedStyle(probe).color;
    probe.remove();
    return value;
  }, css);
  await expect
    .poll(() =>
      page
        .locator(selector)
        .first()
        .evaluate((node, name) => getComputedStyle(node).getPropertyValue(name), property),
    )
    .toBe(resolved);
});

Then("{string} is animating", async ({ page }, selector: string) => {
  await expect
    .poll(() =>
      page
        .locator(selector)
        .first()
        .evaluate((node) => node.getAnimations().some(({ playState }) => playState === "running")),
    )
    .toBe(true);
});

Then("{string} is not animating", async ({ page }, selector: string) => {
  await page.waitForTimeout(200);
  expect(
    await page
      .locator(selector)
      .first()
      .evaluate((node) => node.getAnimations().some(({ playState }) => playState === "running")),
  ).toBe(false);
});

Then("the colors of these code parts are:", async ({ page }, table: DataTable) => {
  const colors = await page.evaluate(
    (selectors) =>
      selectors.map((selector) => getComputedStyle(document.querySelector(`pre ${selector}`) as Element).color),
    table.rows().map(([selector]) => selector),
  );
  const rgb = (hex: string) =>
    `rgb(${hex
      .match(/\w\w/g)
      ?.map((pair) => Number.parseInt(pair, 16))
      .join(", ")})`;
  expect(colors).toEqual(table.rows().map(([, hex]) => rgb(hex)));
});

Then("every highlighter class starts with hl-", async ({ page }) => {
  const names = await page.evaluate(() =>
    [...document.querySelectorAll("pre.syntax-highlighting [class]")].flatMap((node) => [...node.classList]),
  );
  expect(names.length).toBeGreaterThan(0);
  expect(names.filter((name) => !name.startsWith("hl-"))).toEqual([]);
});

Then("the code block draws {int} lines", async ({ page }, count: number) => {
  const lines = await page
    .locator("pre.syntax-highlighting code")
    .first()
    .evaluate((code) => {
      const range = document.createRange();
      range.selectNodeContents(code);
      return new Set([...range.getClientRects()].filter((rect) => rect.width > 0).map((rect) => Math.round(rect.top)))
        .size;
    });
  expect(lines).toBe(count);
});

Then("the code block numbers {int} lines", async ({ page }, count: number) => {
  const numbers = await page
    .locator("pre.syntax-highlighting code")
    .first()
    .evaluate((code) =>
      [...code.querySelectorAll(":scope > .hl-ln")].map((line) => getComputedStyle(line, "::before").content),
    );
  expect(numbers).toEqual(Array(count).fill("counter(hl-ln)"));
});

When("I copy the code block", async ({ page }) => {
  await page.context().grantPermissions(["clipboard-read", "clipboard-write"]);
  await page
    .locator("pre.syntax-highlighting code")
    .first()
    .evaluate((code) => getSelection()?.selectAllChildren(code));
  await page.keyboard.press("ControlOrMeta+c");
});

Then("the clipboard holds:", async ({ page }, text: string) => {
  expect(await page.evaluate(() => navigator.clipboard.readText())).toBe(text);
});

Then("nothing inside the code block has a border", async ({ page }) => {
  const bordered = await page.evaluate(
    () =>
      [...document.querySelectorAll("pre.syntax-highlighting *")].filter((node) =>
        ["Top", "Right", "Bottom", "Left"].some(
          (side) => getComputedStyle(node).getPropertyValue(`border-${side.toLowerCase()}-width`) !== "0px",
        ),
      ).length,
  );
  expect(bordered).toBe(0);
});

Then("the top of {string} sits {int} pixels down the window", async ({ page }, selector: string, top: number) => {
  await expect
    .poll(async () =>
      Math.abs((await page.locator(selector).evaluate((node) => node.getBoundingClientRect().top)) - top),
    )
    .toBeLessThanOrEqual(2);
});

Then(
  "the {string} property {string} of {string} is the list:",
  async ({ page }, _kind, prefix, selector, table: DataTable) => {
    const values = await page
      .locator(selector)
      .first()
      .evaluate(
        (node, [name, count]) => {
          const style = getComputedStyle(node);
          return Array.from({ length: Number(count) }, (_, step) => style.getPropertyValue(`${name}${step}`).trim());
        },
        [prefix, String(table.raw().length)],
      );
    const expected = await page.evaluate(
      (names) => names.map((name) => getComputedStyle(document.documentElement).getPropertyValue(name).trim()),
      table.raw().map(([name]) => name),
    );
    expect(values).toEqual(expected);
  },
);

Then("the page's theme is {string}", async ({ page }, theme: string) => {
  await expect.poll(() => page.evaluate(() => document.documentElement.dataset.siteTheme)).toBe(theme);
});

Then("the page's color scheme is {string}", async ({ page }, scheme: string) => {
  await expect.poll(() => page.evaluate(() => getComputedStyle(document.documentElement).colorScheme)).toBe(scheme);
});

Then("the width of {string} is more than {int} pixels", async ({ page }, selector: string, width: number) => {
  expect(
    await page
      .locator(selector)
      .first()
      .evaluate((node) => node.getBoundingClientRect().width),
  ).toBeGreaterThan(width);
});

Then(
  "every visible control in {string} is at least {int} pixels tall",
  async ({ page }, selector: string, height: number) => {
    const short = await page.evaluate(
      ([scope, least]) =>
        [...document.querySelectorAll(`${scope} a:not(.skip-link), ${scope} button`)]
          .filter((node) => node.checkVisibility())
          .filter((node) => node.getBoundingClientRect().height < Number(least))
          .map((node) => node.textContent?.trim() || node.getAttribute("aria-label")),
      [selector, String(height)],
    );
    expect(short).toEqual([]);
  },
);

Then(
  "a browser that keeps to the content security policy and holds the cookie {string} draws {string} in the {string} theme",
  async ({ app, browser }, cookie: string, path: string, theme: string) => {
    const context = await browser.newContext({ baseURL: app.url, bypassCSP: false, colorScheme: "light" });
    try {
      const [name, value] = cookie.split("=");
      await context.addCookies([{ name, url: app.url, value }]);
      const page = await context.newPage();
      await page.goto(path);
      expect(await page.evaluate(() => document.documentElement.dataset.siteTheme)).toBe(theme);
      expect(await page.evaluate(() => getComputedStyle(document.documentElement).colorScheme)).toBe(theme);
    } finally {
      await context.close();
    }
  },
);

Given("I am not signed in", () => {});

let themes: (string | undefined)[] = [];

When("I keep the page's theme", async ({ page }) => {
  themes = [await page.evaluate(() => document.documentElement.dataset.siteTheme)];
});

Then("the two themes were light and dark", async ({ page }) => {
  themes.push(await page.evaluate(() => document.documentElement.dataset.siteTheme));
  expect(themes.toSorted()).toEqual(["dark", "light"]);
});

When("I choose the {string} option", async ({ page }, name: string) => {
  await page.getByRole("radio", { name }).first().check({ force: true });
});

Then("{int} of {string} are visible", async ({ page }, count: number, selector: string) => {
  await expect(page.locator(selector).filter({ visible: true })).toHaveCount(count);
});

Given("the web answers images blank", async ({ context }) => {
  await context.route(
    (url) => !["127.0.0.1", "localhost"].includes(url.hostname) && /\.(png|jpe?g|gif|webp|svg)$/.test(url.pathname),
    (route) => route.fulfill({ body: "", contentType: "image/png", status: 200 }),
  );
});

Given("my window is {int} by {int}", async ({ page }, width: number, height: number) => {
  await page.setViewportSize({ height, width });
});

Then("{string} lays out in {int} column(s)", async ({ page }, selector: string, count: number) => {
  await expect
    .poll(() =>
      page
        .locator(selector)
        .first()
        .evaluate((node) => getComputedStyle(node).gridTemplateColumns.split(" ").length),
    )
    .toBe(count);
});

Then(
  "the {string} of {string} is not {string}",
  async ({ page }, property: string, selector: string, value: string) => {
    expect(
      await page
        .locator(selector)
        .first()
        .evaluate((node, name) => getComputedStyle(node).getPropertyValue(name), property),
    ).not.toBe(value);
  },
);

Then("only {string} of {string} shows", async ({ page }, shown: string, all: string) => {
  const visible = [];
  for (const selector of all.split(", ")) if (await page.locator(selector).first().isVisible()) visible.push(selector);
  expect(visible).toEqual(shown ? shown.split(", ") : []);
});

Then("the page does not reload", async ({ page }) => {
  expect(await page.evaluate(() => (window as unknown as { kept?: boolean }).kept)).toBe(true);
});

When("I mark the page", async ({ page }) => {
  await page.evaluate(() => {
    (window as unknown as { kept?: boolean }).kept = true;
  });
});

When("I clear the browser's saved choices", async ({ page }) => {
  await page.goto("/");
  await page.evaluate(() => localStorage.clear());
});

When("I type {string} into {string}", async ({ page }, text: string, selector: string) => {
  await page.locator(selector).first().pressSequentially(text);
});

When("I drop the board's view mark", async ({ page }) => {
  await page.evaluate(() => document.querySelector("[data-board-views]")?.removeAttribute("data-view"));
});

Then("the page's query is {string}", async ({ page }, query: string) => {
  await expect.poll(() => new URL(page.url()).search.replace(/^\?/, "")).toBe(query);
});

Then("every one of {string} is at least {int} pixels tall", async ({ page }, selector: string, height: number) => {
  const heights = await page
    .locator(selector)
    .evaluateAll((nodes) => nodes.map((node) => node.getBoundingClientRect().height));
  expect(heights.length).toBeGreaterThan(0);
  expect(Math.min(...heights)).toBeGreaterThanOrEqual(height);
});

Then("the page does not scroll sideways", async ({ page }) => {
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
});

const box = (page: import("@playwright/test").Page, selector: string) =>
  page
    .locator(selector)
    .first()
    .evaluate((node) => node.getBoundingClientRect().toJSON() as DOMRect);

Then(
  /^"([^"]*)" sits (right of|below|at or below|on the row of) "([^"]*)"$/,
  async ({ page }, one: string, where: string, other) => {
    await expect
      .poll(async () => {
        const [a, b] = [await box(page, one), await box(page, other)];
        if (where === "right of") return a.left > b.right;
        if (where === "below") return a.top > b.bottom;
        if (where === "at or below") return a.top >= b.bottom;
        return a.top < b.bottom && b.top < a.bottom;
      })
      .toBe(true);
  },
);

Then("{string} is at least {int} pixels wide", async ({ page }, selector: string, width: number) => {
  const { right, left } = await box(page, selector);
  expect(right - left).toBeGreaterThanOrEqual(width);
});

Then("{string} runs the full width of the window", async ({ page }, selector: string) => {
  const { width } = await box(page, selector);
  const client = await page.evaluate(() => document.documentElement.clientWidth);
  expect(Math.abs(width - client)).toBeLessThanOrEqual(1);
});

Then("the right edge of {string} meets the right edge of {string}", async ({ page }, one: string, other: string) => {
  expect(Math.abs((await box(page, one)).right - (await box(page, other)).right)).toBeLessThanOrEqual(1);
});

Then(
  "the top of {string} sits {int} pixels down the window, give or take one",
  async ({ page }, selector: string, top) => {
    await expect.poll(async () => Math.abs((await box(page, selector)).top - top)).toBeLessThanOrEqual(1);
  },
);

When("I set the width of {string} to {int} pixels", async ({ page }, selector: string, width: number) => {
  await page
    .locator(selector)
    .first()
    .evaluate((node, value) => {
      (node as HTMLElement).style.width = `${value}px`;
    }, width);
});

When("I scroll {string} into view", async ({ page }, selector: string) => {
  await page
    .locator(selector)
    .first()
    .evaluate((node) => node.scrollIntoView());
});

Then("the middle of {string} sits inside no link", async ({ page }, selector: string) => {
  const href = await page
    .locator(selector)
    .first()
    .evaluate((node) => {
      const { left, top, width, height } = node.getBoundingClientRect();
      return document.elementFromPoint(left + width / 2, top + height / 2)?.closest("a")?.href ?? null;
    });
  expect(href).toBeNull();
});

let size = 0;

When("I note the font size of {string}", async ({ page }, selector: string) => {
  size = Number.parseFloat(
    await page
      .locator(selector)
      .first()
      .evaluate((node) => getComputedStyle(node).fontSize),
  );
});

Then("the font size of {string} is larger than I noted", async ({ page }, selector: string) => {
  expect(
    Number.parseFloat(
      await page
        .locator(selector)
        .first()
        .evaluate((node) => getComputedStyle(node).fontSize),
    ),
  ).toBeGreaterThan(size);
});

Given("the page's scripts do not load", async ({ context }) => {
  await context.route(/\.js(\?.*)?$/, (route) => route.abort());
});

Given("the browser's clock reads {string}", async ({ page }, at: string) => {
  await page.clock.install({ time: new Date(at) });
});

When("I reload the page", async ({ page }) => {
  await page.reload();
});

Then("the browser holds no cookie for the page", async ({ page }) => {
  expect(await page.evaluate(() => document.cookie)).toBe("");
});

Then("the right edge of {string} sits off the screen", async ({ page }, selector: string) => {
  expect(
    await page
      .locator(selector)
      .first()
      .evaluate((node) => node.getBoundingClientRect().right),
  ).toBeLessThan(0);
});

Then("Tab from {string} reaches:", async ({ page }, selector: string, table: DataTable) => {
  await page.locator(selector).first().click();
  const reached = [];
  for (const _ of table.raw()) {
    await page.keyboard.press("Tab");
    reached.push(await page.evaluate(() => document.activeElement?.id || document.activeElement?.tagName));
  }
  expect(reached).toEqual(table.raw().map(([id]) => id));
});

When("I click the link {string}", async ({ page }, name: string) => {
  await page.getByRole("link", { exact: true, name }).click();
});

Then("I see the heading {string}", async ({ page }, name: string) => {
  await expect(page.getByRole("heading", { name })).toBeVisible();
});

Then("visiting {string} answers {int}", async ({ page }, path: string, status: number) => {
  const response = await page.goto(path);

  expect(response?.status()).toBe(status);
});

When("I fill the field {string} with:", async ({ page }, selector: string, text: string) => {
  await page.locator(selector).first().fill(text);
});

Then("the window's {string} is not set", async ({ page }, name: string) => {
  expect(await page.evaluate((key) => key in window, name)).toBe(false);
});

const DIAGRAM_FILLS: Record<string, string> = { dark: "rgb(31, 32, 32)", light: "rgb(236, 236, 255)" };

Then("the diagram draws in the {word} theme", async ({ page }, theme: string) => {
  await expect
    .poll(() =>
      page.evaluate(() => {
        const node = document.querySelector("pre.mermaid svg .node rect");
        return node && getComputedStyle(node).fill;
      }),
    )
    .toBe(DIAGRAM_FILLS[theme]);
});

Then("the page loads no mermaid code", async ({ page }) => {
  await page.waitForLoadState("load");
  const loaded = await page.evaluate(() => performance.getEntriesByType("resource").map(({ name }) => name));
  expect(loaded.length).toBeGreaterThan(0);
  expect(loaded.filter((name) => name.includes("mermaid"))).toEqual([]);
});

Then(
  "a browser that keeps to the content security policy draws the diagram on {string} from the site alone",
  async ({ app, browser }, path: string) => {
    const context = await browser.newContext({ baseURL: app.url, bypassCSP: false });
    try {
      const page = await context.newPage();
      const origins = new Set<string>();
      const errors: string[] = [];
      page.on("request", (request) => {
        if (request.url().startsWith("http")) origins.add(new URL(request.url()).origin);
      });
      page.on("console", (message) => {
        if (message.type() === "error") errors.push(message.text());
      });
      await page.goto(path);
      await expect(page.locator("pre.mermaid svg .node").first()).toBeAttached();
      expect(errors).toEqual([]);
      expect([...origins]).toEqual([new URL(app.url).origin]);
    } finally {
      await context.close();
    }
  },
);
