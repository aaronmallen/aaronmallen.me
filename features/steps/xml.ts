import { execFile } from "node:child_process";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";
import { expect, type Page } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { root } from "../support/shell.ts";
import { Then } from "../support/world.ts";
import { assetPaths, lastReply } from "./http.ts";

export async function xpath(page: Page, query: string) {
  if (page.url() === "about:blank") await page.goto("/robots.txt");
  const path = query.replaceAll("{site}", new URL(page.url()).origin);
  return page.evaluate(
    ([text, query]) => {
      const xml = new DOMParser().parseFromString(text.replace(/\sxmlns="[^"]*"/, ""), "application/xml");
      const spaces = Object.fromEntries(
        [...xml.documentElement.attributes]
          .filter(({ name }) => name.startsWith("xmlns:"))
          .map(({ name, value }) => [name.slice(6), value]),
      );
      const found = xml.evaluate(query, xml, (prefix) => spaces[prefix ?? ""] ?? null, XPathResult.ANY_TYPE, null);
      if (found.resultType === XPathResult.STRING_TYPE) return [found.stringValue];
      if (found.resultType === XPathResult.NUMBER_TYPE) return [String(found.numberValue)];
      if (found.resultType === XPathResult.BOOLEAN_TYPE) return [String(found.booleanValue)];
      const values: string[] = [];
      for (let node = found.iterateNext(); node; node = found.iterateNext()) values.push(node.textContent ?? "");
      return values;
    },
    [lastReply().body, path],
  );
}

Then("the XML answer's {string} are:", async ({ app, page }, path: string, table: DataTable) => {
  const expected = await Promise.all(table.raw().map(([value]) => assetPaths(app.url, value)));
  expect(await xpath(page, path)).toEqual(expected);
});

Then("the XML answer's {string} are, in any order:", async ({ app, page }, path: string, table: DataTable) => {
  const expected = await Promise.all(table.raw().map(([value]) => assetPaths(app.url, value)));
  expect((await xpath(page, path)).toSorted()).toEqual(expected.toSorted());
});

Then("the XML answer's {string} is {string}", async ({ app, page }, path: string, value: string) => {
  expect(await xpath(page, path)).toEqual([(await assetPaths(app.url, value)).replaceAll("\\n", "\n")]);
});

Then("the XML answer has no {string}", async ({ page }, path: string) => {
  expect(await xpath(page, path)).toEqual([]);
});

Then("the XML answer's {string} include {string}", async ({ app, page }, path: string, value: string) => {
  expect(await xpath(page, path)).toContain((await assetPaths(app.url, value)).replaceAll("\\n", "\n"));
});

Then("the XML answer's {string} do not include {string}", async ({ app, page }, path: string, value: string) => {
  expect(await xpath(page, path)).not.toContain(await assetPaths(app.url, value));
});

Then("the XML answer passes the schema {string}", async ({}, schema: string) => {
  const dir = await mkdtemp(join(tmpdir(), "features-xml-"));
  try {
    const file = join(dir, "answer.xml");
    await writeFile(file, lastReply().raw);
    const flag = schema.endsWith(".rng") ? "--relaxng" : "--schema";
    await promisify(execFile)("xmllint", ["--noout", flag, join(root, "features/support/schemas", schema), file]);
  } finally {
    await rm(dir, { force: true, recursive: true });
  }
});

const entryContent = async (page: Page, title: string) => {
  const [html] = await xpath(page, `/feed/entry[title='${title}']/content`);
  return page.evaluate(
    (markup) =>
      [...new DOMParser().parseFromString(markup, "text/html").body.children].map((node) => node.tagName.toLowerCase()),
    html ?? "",
  );
};

Then("the feed entry's content for {string} holds the tags {string}", async ({ page }, title: string, tags: string) => {
  expect((await entryContent(page, title)).join(", ")).toBe(tags);
});

const contentQuery = async (page: Page, title: string, query: string) => {
  const [html] = await xpath(page, `/feed/entry[title='${title}']/content`);
  return page.evaluate(
    ([markup, selector]) =>
      [...new DOMParser().parseFromString(markup, "text/html").querySelectorAll(selector)].map((node) =>
        (node.textContent ?? "").trim().replace(/\s+/g, " "),
      ),
    [html ?? "", query],
  );
};

Then(
  "the feed entry's content for {string} reads {string} at {string}",
  async ({ page }, title, text: string, query) => {
    expect((await contentQuery(page, title, query)).join(", ")).toBe(text);
  },
);

Then("the feed entry's content for {string} has no {string}", async ({ page }, title: string, query: string) => {
  expect(await contentQuery(page, title, query)).toEqual([]);
});

Then("the feed links are {string}", async ({ app, page }, links: string) => {
  const expected = (await assetPaths(app.url, links)).split(", ").toSorted();
  const rels = await xpath(page, "/feed/link/@rel");
  const hrefs = await xpath(page, "/feed/link/@href");
  expect(rels.map((rel, index) => `${rel} ${hrefs[index]}`).toSorted()).toEqual(expected);
});

Then("the XML answer's {string} matches {string}", async ({ page }, path: string, pattern: string) => {
  expect((await xpath(page, path)).join("\n")).toMatch(new RegExp(pattern));
});

Then("the XML answer's {string} is later than a day ago", async ({ page }, path: string) => {
  const [value] = await xpath(page, path);
  expect(Date.parse(value)).toBeGreaterThan(Date.now() - 86_400_000);
});
