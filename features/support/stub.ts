import { randomBytes } from "node:crypto";
import { createServer, type IncomingHttpHeaders, type ServerResponse } from "node:http";
import type { AddressInfo } from "node:net";

export const ownerEmail = "owner@example.com";

export const services: Record<string, string> = {
  Bluesky: "/bluesky/pds",
  "Bluesky's app view": "/bluesky/public",
  GitHub: "/github/api",
  "GitHub sign-in": "/github",
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
  "the media store": "/s3/photos",
  "the web": "",
};

type Reply = {
  body: string | Buffer;
  delay?: number;
  drop?: boolean;
  headers?: Record<string, string>;
  status: number;
};
export type Sent = { body: Buffer; headers: IncomingHttpHeaders; method: string; url: URL };
type Answer = Reply | ((sent: Sent) => Reply | Promise<Reply>);
type Stored = { body: Buffer; type: string };
type Route = (url: URL, response: ServerResponse) => void;

function json(response: ServerResponse, body: unknown) {
  response.writeHead(200, { "Content-Type": "application/json" }).end(JSON.stringify(body));
}

const standing: Record<string, Route> = {
  "GET /maxmind/geoip/databases/GeoLite2-City/download": (_, response) => response.writeHead(503).end(),
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

function store(objects: Map<string, Stored>, method: string, url: URL, body: Buffer, response: ServerResponse) {
  const key = decodeURIComponent(url.pathname.slice("/s3/".length));
  const object = objects.get(key);
  if (method === "PUT") {
    objects.set(key, { body, type: response.req.headers["content-type"] ?? "binary/octet-stream" });
    response.writeHead(200, { ETag: '"stub"' }).end();
  } else if (method === "DELETE") {
    objects.delete(key);
    response.writeHead(204).end();
  } else if (method === "GET" && url.searchParams.get("list-type") === "2") {
    const bucket = `${key.replace(/\/$/, "")}/`;
    const prefix = bucket + (url.searchParams.get("prefix") ?? "");
    const keys = [...objects.keys()].filter((name) => name.startsWith(prefix)).sort();
    const contents = keys.map(
      (name) =>
        `<Contents><Key>${name.slice(bucket.length)}</Key><Size>${objects.get(name)?.body.length}</Size></Contents>`,
    );
    response
      .writeHead(200, { "Content-Type": "application/xml" })
      .end(
        `<?xml version="1.0" encoding="UTF-8"?><ListBucketResult><KeyCount>${keys.length}</KeyCount><IsTruncated>false</IsTruncated>${contents.join("")}</ListBucketResult>`,
      );
  } else if (!object) {
    response
      .writeHead(404, { "Content-Type": "application/xml" })
      .end(method === "HEAD" ? undefined : "<Error><Code>NoSuchKey</Code></Error>");
  } else {
    const range = /bytes=(\d*)-(\d*)/.exec(response.req.headers.range ?? "");
    const size = object.body.length;
    const first = range ? (range[1] ? Number(range[1]) : size - Number(range[2])) : 0;
    const last = range?.[1] && range[2] ? Math.min(Number(range[2]), size - 1) : size - 1;
    const part = object.body.subarray(first, last + 1);
    const headers = { "Content-Length": part.length, "Content-Type": object.type, ETag: '"stub"' };
    if (range) Object.assign(headers, { "Content-Range": `bytes ${first}-${last}/${size}` });
    response.writeHead(range ? 206 : 200, headers).end(method === "HEAD" ? undefined : part);
  }
}

const keyOf = ({ method, url }: Sent) => `${method} ${url.origin === "http://stub" ? "" : url.origin}${url.pathname}`;

export async function startStub() {
  const replies = new Map<string, Answer[]>();
  const log: Sent[] = [];
  const objects = new Map<string, Stored>();
  const misses: string[] = [];
  const held = new Map<NodeJS.Timeout, ServerResponse>();

  function next(key: string, search: string) {
    const prefix = [...replies.keys()].find((path) => path.endsWith("*") && key.startsWith(path.slice(0, -1)));
    const queue = [`${key}${search}`, key, prefix].map((path) => path && replies.get(path)).find(Boolean);
    return queue && queue.length > 1 ? queue.shift() : queue?.[0];
  }

  const server = createServer(async (request, response) => {
    const absolute = /^https?:\/\//.test(request.url ?? "");
    const url = new URL(request.url ?? "/", "http://stub");
    const key = `${request.method} ${absolute ? url.origin : ""}${url.pathname}`;
    const chunks: Buffer[] = [];
    for await (const chunk of request) chunks.push(chunk);
    const sent = { body: Buffer.concat(chunks), headers: request.headers, method: request.method ?? "GET", url };
    log.push(sent);

    const answer = next(key, url.search);
    const reply = typeof answer === "function" ? await answer(sent) : answer;
    if (reply?.drop) {
      response.socket?.destroy();
    } else if (reply) {
      const type =
        typeof reply.body === "string" && reply.body.trimStart().startsWith("<") ? "text/html" : "application/json";
      const send = () =>
        response
          .writeHead(reply.status, { "Content-Type": type, ...reply.headers })
          .end(sent.method === "HEAD" ? undefined : reply.body);
      if (reply.delay) {
        const timer = setTimeout(() => held.delete(timer) && send(), reply.delay);
        held.set(timer, response);
      } else send();
    } else if (!absolute && url.pathname.startsWith("/s3/")) {
      store(objects, sent.method, url, sent.body, response);
    } else if (standing[key]) {
      standing[key](url, response);
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
    objects,
    received: (method: string, path: string) =>
      log.filter((sent) => keyOf(sent) === `${method} ${path}`).map(({ body }) => body.toString()),
    reply: (method: string, path: string, reply: Answer) => replies.set(`${method} ${path}`, [reply]),
    replyThen: (method: string, path: string, reply: Answer) => {
      const key = `${method} ${path}`;
      replies.set(key, [...(replies.get(key) ?? []), reply]);
    },
    requests: () => [...log],
    reset: () => {
      replies.clear();
      objects.clear();
      log.length = 0;
      misses.length = 0;
      for (const [timer, response] of held) {
        clearTimeout(timer);
        response.destroy();
      }
      held.clear();
    },
    stop: () =>
      new Promise((closed) => {
        server.close(closed);
        server.closeAllConnections();
      }),
    url: `http://127.0.0.1:${(server.address() as AddressInfo).port}`,
  };
}

export type Stub = Awaited<ReturnType<typeof startStub>>;
