import type { APIRequestContext } from "@playwright/test";
import { chicagoDay, type Http } from "./http.ts";

const kept = new WeakMap<Http, Record<string, unknown>>();

export const keep = (http: Http, name: string, value: unknown) => {
  kept.set(http, { ...kept.get(http), [name]: value });
};

export const recall = (http: Http, name: string) => kept.get(http)?.[name];

const clock = (at = new Date()) =>
  new Intl.DateTimeFormat("en-GB", { hour: "2-digit", minute: "2-digit", timeZone: "America/Chicago" }).format(at);

const chicagoTime = (hours: number) => {
  const at = new Date(Date.now() - hours * 3_600_000);
  const day = new Intl.DateTimeFormat("en-CA", { timeZone: "America/Chicago" }).format(at);
  return `${day}T${clock(at)}`;
};

export const fill = (http: Http, text: string) =>
  text.replaceAll(/\{([\w:]+)\}/g, (whole, name) => {
    if (name === "clock") return clock();
    if (name === "today") return chicagoDay(0);
    const [unit, count] = name.split(":");
    if (unit === "days_ago") return chicagoDay(-Number(count));
    if (unit === "days_ahead") return chicagoDay(Number(count));
    if (unit === "hours_ago") return chicagoTime(Number(count));
    const value = recall(http, name);
    return value === undefined ? whole : String(value);
  });

export const dig = (value: unknown, path: string) =>
  path
    .split(".")
    .filter(Boolean)
    .reduce<unknown>((found, key) => (found as Record<string, unknown> | undefined)?.[key], value);

export async function callApi(
  request: APIRequestContext,
  http: Http,
  token: string | undefined,
  method: string,
  path: string,
  body?: string,
) {
  const url = path.startsWith("/") ? fill(http, path) : `/api/v1/${fill(http, path)}`;
  const headers: Record<string, string> = { Accept: "application/json", "Content-Type": "application/json" };
  if (token) headers.Authorization = `Bearer ${token}`;
  http.last = await request.fetch(url, {
    data: body === undefined ? undefined : fill(http, body),
    headers,
    maxRedirects: 0,
    method,
  });
  http.body = await http.last.text();
  return http.last;
}

export const answer = (http: Http) => JSON.parse(http.body || "null");
