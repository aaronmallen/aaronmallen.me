import { expect } from "@playwright/test";
import { Then, When } from "../support/world.ts";

type Stream = { abort: AbortController; heard: string };

let streams: Stream[] = [];

When(/^I open (\d+) admin event streams?$/, async ({ app, context }, count: string) => {
  const cookie = (await context.cookies(app.url)).map(({ name, value }) => `${name}=${value}`).join("; ");
  streams = await Promise.all(
    Array.from({ length: Number(count) }, async () => {
      const stream = { abort: new AbortController(), heard: "" };
      const response = await fetch(`${app.url}/admin/events`, {
        headers: { Accept: "text/event-stream", Cookie: cookie },
        signal: stream.abort.signal,
      });
      expect(response.headers.get("content-type")).toBe("text/event-stream");
      const text = response.body?.pipeThrough(new TextDecoderStream());
      (async () => {
        for await (const chunk of text ?? []) stream.heard += chunk;
      })().catch(() => {});
      await expect.poll(() => stream.heard).toContain("retry:");
      return stream;
    }),
  );
});

Then("each admin event stream hears {string}", async ({}, text: string) => {
  const expected = text.replaceAll("\\n", "\n");
  for (const stream of streams) await expect.poll(() => stream.heard).toContain(expected);
  for (const stream of streams) stream.abort.abort();
});
