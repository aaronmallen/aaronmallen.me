import { randomBytes } from "node:crypto";
import { createServer, type ServerResponse } from "node:http";
import type { AddressInfo } from "node:net";

export const ownerEmail = "owner@example.com";

function json(response: ServerResponse, body: unknown) {
  response.writeHead(200, { "Content-Type": "application/json" }).end(JSON.stringify(body));
}

const routes: Record<string, (url: URL, response: ServerResponse) => void> = {
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
  const server = createServer((request, response) => {
    const url = new URL(request.url ?? "/", "http://stub");
    request.resume();
    const route = routes[`${request.method} ${url.pathname}`];
    if (route) route(url, response);
    else response.writeHead(404).end();
  });
  await new Promise<void>((listening) => server.listen(0, "127.0.0.1", listening));

  return {
    stop: () => new Promise((closed) => server.close(closed)),
    url: `http://127.0.0.1:${(server.address() as AddressInfo).port}`,
  };
}
