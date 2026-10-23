import { expect, type Page } from "@playwright/test";
import type postgres from "postgres";

type App = { pushJob: (job: string, ...args: unknown[]) => Promise<void>; sql: postgres.Sql; url: string };

export const verifyJob = "Social::Jobs::VerifyWebmention";

export function expand(text: string, site: string) {
  return text
    .replaceAll("{post}", `${site}/writing/hello`)
    .replaceAll("{site}", site)
    .replaceAll("{SITE}", site.replace("http:", "HTTP:"))
    .replaceAll(/\{(.+?)\*(\d+)\}/gu, (_, chunk: string, times: string) => chunk.repeat(Number(times)));
}

export const stubKey = (url: string) => {
  const parsed = new URL(url);
  return `${parsed.origin}${parsed.pathname}`;
};

export async function postId(app: App, title: string): Promise<number> {
  const [row] = await app.sql`SELECT id FROM posts WHERE title = ${title}`;
  return row.id;
}

async function runs(app: App, job: string): Promise<number> {
  const [{ count }] = await app.sql`SELECT count(*)::int AS count FROM performance_jobs WHERE job = ${job}`;
  return count;
}

export async function runJob(app: App, job: string, ...args: unknown[]) {
  const before = await runs(app, job);
  await app.pushJob(job, ...args);
  await waitForRuns(app, job, before + 1);
}

export async function waitForRuns(app: App, job: string, count: number) {
  await expect.poll(() => runs(app, job), { timeout: 30_000 }).toBeGreaterThanOrEqual(count);
}

export async function lastRun(app: App, job: string) {
  const [row] = await app.sql`
    SELECT outcome, error_class FROM performance_jobs WHERE job = ${job} ORDER BY id DESC LIMIT 1
  `;
  return row;
}

export const runCount = runs;

export function unwrap(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(unwrap);
  if (value && typeof value === "object") {
    const record = value as Record<string, unknown>;
    if (record.untrusted === true && "text" in record) return record.text;
    return Object.fromEntries(Object.entries(record).map(([key, inner]) => [key, unwrap(inner)]));
  }
  return value;
}

export async function submitForm(page: Page, action: string, fields: [string, string][]) {
  const navigation = page.waitForNavigation();
  await page.evaluate(
    ([target, pairs]) => {
      const form = document.createElement("form");
      form.method = "post";
      form.action = target;
      const token = document.querySelector<HTMLInputElement>("input[name='_csrf_token']")?.value ?? "";
      for (const [name, value] of [["_csrf_token", token], ...pairs]) {
        const input = document.createElement("input");
        input.type = "hidden";
        input.name = name;
        input.value = value;
        form.append(input);
      }
      document.body.append(form);
      form.submit();
    },
    [action, fields] as const,
  );
  const response = await navigation;
  const first = response?.request().redirectedFrom();
  return (first ? (await first.response())?.status() : response?.status()) ?? 0;
}
