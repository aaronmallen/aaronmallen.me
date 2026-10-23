import { createHash, randomBytes } from "node:crypto";
import type { APIRequestContext } from "@playwright/test";
import { csrfIn, type Http } from "./http.ts";

export const redirectUri = "https://claude.ai/api/mcp/auth_callback";

export type Connection = { access: string; clientId: string; refresh: string; verifier: string };

export async function register(request: APIRequestContext, name = "Features") {
  const registered = await request.post("/oauth/register", {
    data: { client_name: name, redirect_uris: [redirectUri] },
  });
  return (await registered.json()).client_id as string;
}

export const challengeFor = (verifier: string) => createHash("sha256").update(verifier).digest("base64url");

export async function authorize(http: Http, clientId: string, verifier: string, scope: string, extra = {}) {
  const query = new URLSearchParams({
    client_id: clientId,
    code_challenge: challengeFor(verifier),
    code_challenge_method: "S256",
    redirect_uri: redirectUri,
    response_type: "code",
    scope,
    state: "state-from-claude",
    ...extra,
  });
  const agent = await http.agent();
  const form = await (await agent.get(`/oauth/authorize?${query}`)).text();
  const fields = Object.fromEntries(
    [...form.matchAll(/<input[^>]*type="hidden"[^>]*>/g)].map(([input]) => [
      input.match(/name="([^"]+)"/)?.[1] ?? "",
      (input.match(/value="([^"]*)"/)?.[1] ?? "").replaceAll("&amp;", "&").replaceAll("&quot;", '"'),
    ]),
  );
  fields._csrf_token ||= csrfIn(form);
  const decided = await agent.post("/oauth/authorize", { form: { ...fields, decision: "approve" }, maxRedirects: 0 });
  return new URL(decided.headers().location ?? "", "http://x").searchParams.get("code") ?? "";
}

export async function connect(request: APIRequestContext, http: Http, scope: string): Promise<Connection> {
  const clientId = await register(request);
  const verifier = randomBytes(32).toString("base64url");
  const code = await authorize(http, clientId, verifier, scope);
  const granted = await request.post("/oauth/token", {
    form: {
      client_id: clientId,
      code,
      code_verifier: verifier,
      grant_type: "authorization_code",
      redirect_uri: redirectUri,
    },
  });
  const tokens = await granted.json();
  return { access: tokens.access_token, clientId, refresh: tokens.refresh_token, verifier };
}

export async function rpc(
  request: APIRequestContext,
  token: string | undefined,
  method: string,
  params?: unknown,
  headers: Record<string, string> = {},
) {
  return request.post("/mcp", {
    data: { id: 1, jsonrpc: "2.0", method, ...(params === undefined ? {} : { params }) },
    headers: {
      Accept: "application/json, text/event-stream",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...headers,
    },
    maxRedirects: 0,
  });
}
