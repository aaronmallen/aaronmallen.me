import { createHash } from "node:crypto";
import { expect } from "@playwright/test";
import { Given, Then, When } from "../support/world.ts";
import { ask, assetPaths, lastReply } from "./http.ts";

export const viewToken = (name: string) => createHash("sha256").update(`view-${name}`).digest("hex").slice(0, 32);

const body = async (base: string, json: string) =>
  (await assetPaths(base, json))
    .replaceAll(/\{token:([^}]+)\}/g, (_, name: string) => viewToken(name))
    .replace("LONGHOST", `${"a".repeat(250)}.example`)
    .replace("/writing/LONGPATH", `/writing/${"a".repeat(2048)}`)
    .replace("LONGPATH", `/${"a".repeat(2048)}`)
    .replace("LONGTITLE", "a".repeat(513))
    .replace("/BIGPATH", `/${"a".repeat(9000)}`);

type World = Parameters<typeof ask>[0];

const send = async (world: World, json: string, headers: Record<string, string | null> = {}) =>
  ask(world, "POST", "/pulse", {
    body: await body(world.app.url, json),
    headers: { "Content-Type": "application/json", ...headers },
  });

When("I send a beacon:", async ({ app, context }, json: string) => {
  await send({ app, context }, json);
});

When("I send a beacon with the header {string} as {string}:", async ({ app, context }, name, value, json: string) => {
  await send({ app, context }, json, { [name]: value });
});

When("I send a beacon as {string}:", async ({ app, context }, agent: string, json: string) => {
  await send({ app, context }, json, { "User-Agent": agent });
});

When("I send a beacon with no user agent:", async ({ app, context }, json: string) => {
  await send({ app, context }, json, { "User-Agent": null });
});

When("I send {int} beacons:", async ({ app, context }, count: number, json: string) => {
  for (let index = 0; index < count; index++) await send({ app, context }, json.replaceAll("{n}", String(index)));
});

When(
  /^I send (\d+) beacons? (from the addresses|with the browsers) "([^"]*)":$/,
  async ({ app, context }, count: string, how: string, pattern: string, json: string) => {
    const name = how === "with the browsers" ? "User-Agent" : "CF-Connecting-IP";
    for (let index = 0; index < Number(count); index++) {
      await send({ app, context }, json.replaceAll("{n}", String(index)), {
        [name]: pattern.replace("N", String(index + 1)),
      });
    }
  },
);

let statuses: number[] = [];

When("I send {int} beacons at once:", async ({ app, context }, count: number, json: string) => {
  const sent = Array.from(
    { length: count },
    async (_, index) => (await send({ app, context }, json.replaceAll("{n}", String(index)))).status,
  );
  statuses = await Promise.all(sent);
});

Then("{int} of them were accepted and {int} throttled", ({}, accepted: number, throttled: number) => {
  expect([
    statuses.filter((status) => status === 202).length,
    statuses.filter((status) => status === 429).length,
  ]).toEqual([accepted, throttled]);
});

Given("the view {string} already has {int} clicks", async ({ app }, name: string, count: number) => {
  await app.sql`
    INSERT INTO analytics_clicks (event_id, link_host, link_path)
    SELECT id, 'docs.example', '/guide' FROM analytics_events, generate_series(1, ${count}) WHERE view_token = ${viewToken(name)}
  `;
});

Then("the answer is empty", () => {
  expect(lastReply().body).toBe("");
});

When("I send a beacon with a referrer of {int} characters", async ({ app, context }, length: number) => {
  const referrer = `https://news.example/${"a".repeat(length)}`;
  await send({ app, context }, JSON.stringify({ kind: "view", path: "/writing/hello", referrer, title: "Hello" }));
});

When("the visits move to yesterday", async ({ app }) => {
  await app.sql`
    UPDATE analytics_events SET occurred_at = occurred_at - interval '1 day', created_at = created_at - interval '1 day'
  `;
});

When("the analytics roll up", async ({ app }) => {
  await app.pushJob("Analytics::Jobs::RollUpAnalytics");
});

Given("a reader viewed {string} as {string}", async ({ app, context }, path: string, name: string) => {
  const { status } = await send(
    { app, context },
    JSON.stringify({ kind: "view", path, title: "Page", view_token: viewToken(name) }),
  );
  expect(status).toBe(202);
});

When("I send a beacon with no stated length:", async ({ app, context }, json: string) => {
  await send({ app, context }, json, { "Content-Length": null });
});

When("I send a beacon at the cap", async ({ app, context }) => {
  const referrer = `https://example.com/${"a".repeat(8103)}`;
  await send({ app, context }, JSON.stringify({ kind: "view", path: "/writing/hello", referrer, title: "Hello" }));
});

Then("every script and sheet on the page loads from the site", async ({ page }) => {
  const sources = await page.evaluate(() => [
    ...[...document.querySelectorAll("script[src]")].map((node) => node.getAttribute("src") ?? ""),
    ...[...document.querySelectorAll("link[rel='stylesheet']")].map((node) => node.getAttribute("href") ?? ""),
  ]);
  expect(sources.length).toBeGreaterThan(0);
  expect(sources.filter((source) => !source.startsWith("/"))).toEqual([]);
});

let pulses = 0;

When("I visit {string} from the referrer {string}", async ({ app, page }, path: string, referrer: string) => {
  await page.goto(path, { referer: await assetPaths(app.url, referrer) });
});

When("I count the beacons the page sends", ({ page }) => {
  pulses = 0;
  page.on("request", (request) => {
    if (new URL(request.url()).pathname === "/pulse") pulses++;
  });
});

When(/^I (leave|come back to) the page$/, async ({ page }, way: string) => {
  await page.evaluate(
    (name) => {
      dispatchEvent(new PageTransitionEvent(name, { persisted: true }));
    },
    way === "leave" ? "pagehide" : "pageshow",
  );
});

Then("the page soon has sent {int} beacon(s)", async ({}, count: number) => {
  await expect.poll(() => pulses).toBe(count);
});

When("I watch what the beacon sends", async ({ page }) => {
  await page.evaluate(() => {
    const sent: Promise<string>[] = [];
    (window as unknown as { beaconSent: Promise<string>[] }).beaconSent = sent;
    const original = navigator.sendBeacon.bind(navigator);
    navigator.sendBeacon = (url, body) => {
      sent.push((body as Blob).text());
      return original(url, body);
    };
    document.addEventListener("click", (event) => event.preventDefault(), { capture: true });
  });
});

const beaconsSent = (page: import("@playwright/test").Page) =>
  page.evaluate(async () =>
    (await Promise.all((window as unknown as { beaconSent: Promise<string>[] }).beaconSent)).map((text) =>
      JSON.parse(text),
    ),
  );

Then("the beacon sent:", async ({ page }, json: string) => {
  await expect.poll(() => beaconsSent(page)).toEqual(JSON.parse(json));
});

Then("the beacon sent nothing", async ({ page }) => {
  await page.waitForTimeout(300);
  expect(await beaconsSent(page)).toEqual([]);
});

Then("the beacon sent a read with the timing of the page", async ({ page }) => {
  await expect
    .poll(async () => {
      const [read] = (await beaconsSent(page)).filter(({ kind }) => kind === "read");
      return (
        read &&
        Object.entries(read.timing ?? {})
          .map(([key, value]) => `${key}:${typeof value}`)
          .toSorted()
      );
    })
    .toEqual(["dom_content_loaded:number", "lcp:number", "load:number", "ttfb:number"]);
});

When("I scroll through {string} of the page and leave it", async ({ page }, shares: string) => {
  await page.evaluate(
    async (list) => {
      const frame = () => new Promise((settled) => requestAnimationFrame(() => requestAnimationFrame(settled)));
      const height = () => document.documentElement.scrollHeight - innerHeight;
      for (const share of list) {
        scrollTo(0, height() * share);
        await frame();
      }
      dispatchEvent(new PageTransitionEvent("pagehide", { persisted: true }));
      await frame();
    },
    shares ? shares.split(", ").map(Number) : [],
  );
});

Then("the beacons sent the kinds and depths {string}", async ({ page }, kinds: string) => {
  await expect
    .poll(async () =>
      (await beaconsSent(page))
        .map((visit) => ("scroll_depth" in visit ? `${visit.kind} ${visit.scroll_depth}` : visit.kind))
        .join(", "),
    )
    .toBe(kinds);
});

When("I click an injected link to another site with the {word} button", async ({ page }, button: string) => {
  await page.evaluate((which) => {
    const link = document.createElement("a");
    link.href = "https://docs.example/guide";
    link.textContent = "Injected";
    document.querySelector("main")?.append(link);
    const type = which === "middle" ? "auxclick" : "click";
    link.dispatchEvent(new MouseEvent(type, { bubbles: true, button: which === "middle" ? 1 : 0, cancelable: true }));
  }, button);
});

When("I wait for the page loaded and painted, then leave it", async ({ page }) => {
  await page.evaluate(
    () =>
      new Promise<void>((done) => {
        const leave = () => {
          dispatchEvent(new PageTransitionEvent("pagehide", { persisted: true }));
          done();
        };
        const painted = new PerformanceObserver(() => {
          painted.disconnect();
          if (document.readyState === "complete") setTimeout(leave);
          else addEventListener("load", () => setTimeout(leave));
        });
        painted.observe({ buffered: true, type: "largest-contentful-paint" });
      }),
  );
});

When(
  "I visit {string} from a referrer of {int} characters on {string}",
  async ({ page }, path: string, length, host) => {
    await page.goto(path, { referer: `https://${host}/${"a".repeat(length)}` });
  },
);
