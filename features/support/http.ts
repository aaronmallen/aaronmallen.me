import type { APIRequestContext, APIResponse, Page } from "@playwright/test";

type Request = { data?: unknown; form?: Record<string, string>; headers?: Record<string, string> };

export type Http = {
  agent: (name?: string, userAgent?: string) => Promise<APIRequestContext>;
  body: string;
  csrf: (name?: string) => Promise<string>;
  last?: APIResponse;
  send: (method: string, path: string, request?: Request & { as?: string }) => Promise<APIResponse>;
};

export const csrfIn = (html: string) =>
  html.match(/name="_csrf_token"[^>]*value="([^"]+)"/)?.[1] ??
  html.match(/value="([^"]+)"[^>]*name="_csrf_token"/)?.[1] ??
  "";

type Answer = { body: string; content?: string; error?: boolean; headers?: Record<string, string>; status: number };

export function http(page: Page, newAgent: (userAgent?: string) => Promise<APIRequestContext>, answer: Answer) {
  const agents = new Map<string, APIRequestContext>();
  let last: APIResponse | undefined;
  const state: Http = {
    agent: async (name = "", userAgent = undefined) => {
      if (!name) return page.request;
      if (!agents.has(name)) agents.set(name, await newAgent(userAgent));
      return agents.get(name) as APIRequestContext;
    },
    get body() {
      return answer.body;
    },
    set body(body: string) {
      answer.body = body;
      answer.content = undefined;
      answer.error = undefined;
    },
    get last() {
      return last;
    },
    set last(response: APIResponse | undefined) {
      last = response;
      answer.status = response?.status() ?? 0;
      answer.headers = response?.headers();
    },
    csrf: async (name) => csrfIn(await (await (await state.agent(name)).get("/admin")).text()),
    send: async (method, path, { as, ...request } = {}) => {
      const agent = await state.agent(as);
      state.last = await agent.fetch(path, { maxRedirects: 0, method, ...request });
      state.body = await state.last.text();
      return state.last;
    },
  };
  return { dispose: () => Promise.all([...agents.values()].map((agent) => agent.dispose())), state };
}

export const chicagoDay = (shift: number) =>
  new Intl.DateTimeFormat("en-CA", { timeZone: "America/Chicago" }).format(new Date(Date.now() + shift * 86_400_000));

export function formValue(value: string) {
  if (value === "today") return chicagoDay(0);
  const days = value.match(/^in (\d+) days?$/);
  if (days) return chicagoDay(Number(days[1]));
  return value.replaceAll(/\\u([0-9a-fA-F]{4})/g, (_, code) => String.fromCharCode(Number.parseInt(code, 16)));
}
