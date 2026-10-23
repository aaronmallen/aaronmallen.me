import { randomBytes } from "node:crypto";
import { createServer, type ServerResponse } from "node:http";
import type { AddressInfo } from "node:net";

export const ownerEmail = "owner@example.com";

export const services: Record<string, string> = {
  Bluesky: "/bluesky/pds",
  "Bluesky's app view": "/bluesky/public",
  GitHub: "/github/api",
  Gmail: "/google/gmail",
  "Google Calendar": "/google/calendar",
  "Google Health": "/google/health",
  "Google OAuth": "/google/oauth",
  "Google OpenID": "/google/openid",
  "Google People": "/google/people",
  "Google sign-in": "/google/accounts",
  Linear: "/linear",
  LinkedIn: "/linkedin/api",
  "LinkedIn OAuth": "/linkedin/oauth",
  Mastodon: "/mastodon",
  MaxMind: "/maxmind",
  "the web": "",
};

type Reply = { body: string; status: number };
type Route = (url: URL, response: ServerResponse) => void;

function json(response: ServerResponse, body: unknown) {
  response.writeHead(200, { "Content-Type": "application/json" }).end(JSON.stringify(body));
}

const signIn: Record<string, Route> = {
  "GET /github/api/user/emails": (_, response) =>
    json(response, [{ email: ownerEmail, primary: true, verified: true }]),
  "GET /github/login/oauth/authorize": (url, response) => {
    const callback = new URL(url.searchParams.get("redirect_uri") ?? "");
    callback.searchParams.set("code", randomBytes(16).toString("hex"));
    callback.searchParams.set("state", url.searchParams.get("state") ?? "");
    response.writeHead(302, { Location: callback.toString() }).end();
  },
  "POST /github/login/oauth/access_token": (_, response) =>
    json(response, {
      access_token: `gho_${randomBytes(16).toString("hex")}`,
      scope: "user:email",
      token_type: "bearer",
    }),
};

export async function startStub() {
  const replies = new Map<string, Reply>();
  const misses: string[] = [];
  const received: { body: string; key: string }[] = [];

  const server = createServer((request, response) => {
    const absolute = /^https?:\/\//.test(request.url ?? "");
    const url = new URL(request.url ?? "/", "http://stub");
    const key = `${request.method} ${absolute ? url.origin : ""}${url.pathname}`;
    const chunks: Buffer[] = [];
    request.on("data", (chunk) => chunks.push(chunk));
    request.on("end", () => received.push({ body: Buffer.concat(chunks).toString(), key }));

    const reply = replies.get(key);
    if (reply) {
      const type = reply.body.trimStart().startsWith("<") ? "text/html" : "application/json";
      response.writeHead(reply.status, { "Content-Type": type }).end(reply.body);
    } else if (signIn[key]) {
      signIn[key](url, response);
    } else {
      misses.push(`${request.method} ${request.url}`);
      response.writeHead(404).end();
    }
  });
  server.on("connect", (request, socket) => {
    misses.push(`CONNECT ${request.url}`);
    socket.end("HTTP/1.1 403 Forbidden\r\n\r\n");
  });
  await new Promise<void>((listening) => server.listen(0, "127.0.0.1", listening));

  return {
    misses: () => misses.splice(0),
    received: (method: string, path: string) =>
      received.filter(({ key }) => key === `${method} ${path}`).map(({ body }) => body),
    reply: (method: string, path: string, reply: Reply) => replies.set(`${method} ${path}`, reply),
    reset: () => {
      replies.clear();
      misses.length = 0;
      received.length = 0;
    },
    stop: () => new Promise((closed) => server.close(closed)),
    url: `http://127.0.0.1:${(server.address() as AddressInfo).port}`,
  };
}

export type Stub = Awaited<ReturnType<typeof startStub>>;
