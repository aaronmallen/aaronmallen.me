import { expect } from "@playwright/test";
import { Then, type test, When } from "../support/world.ts";

type World = Parameters<Parameters<typeof test>[2]>[0];

const trusted = (value: unknown): unknown => {
  if (Array.isArray(value)) return value.map(trusted);
  if (value && typeof value === "object") {
    const record = value as Record<string, unknown>;
    if (record.untrusted === true && "text" in record) return record.text;
    return Object.fromEntries(Object.entries(record).map(([key, inner]) => [key, trusted(inner)]));
  }
  return value;
};

const text = ({ answer }: Pick<World, "answer">) => answer.content ?? answer.body;

const parsed = (world: Pick<World, "answer">) => {
  try {
    return trusted(JSON.parse(text(world)));
  } catch {
    return text(world);
  }
};

const dig = (body: unknown, path: string) =>
  path.split(".").reduce<unknown>((value, key) => (value as Record<string, unknown> | undefined)?.[key], body);

const callApi = async (
  { answer, request }: Pick<World, "answer" | "request">,
  token: string | undefined,
  call: string,
  data?: string,
) => {
  const [method, path] = call.split(" ");
  const response = await request.fetch(path, {
    data: data === undefined ? undefined : JSON.parse(data),
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    method,
  });
  Object.assign(answer, { body: await response.text(), content: undefined, error: false, status: response.status() });
};

When("I call the API with {string}", ({ answer, request, tokens }, call: string) =>
  callApi({ answer, request }, tokens.api, call),
);

When("I call the API with {string} and:", ({ answer, request, tokens }, call: string, data: string) =>
  callApi({ answer, request }, tokens.api, call, data),
);

When("I call the API with {string} and no token", ({ answer, request }, call: string) =>
  callApi({ answer, request }, undefined, call),
);

Then("the call answers {int}", ({ answer }, status: number) => {
  expect(answer.status, answer.body).toBe(status);
});

Then("it refuses", ({ answer }) => {
  expect(answer.status >= 400 || Boolean(answer.error), answer.body).toBe(true);
});

Then("it does not refuse", ({ answer }) => {
  expect(answer.status < 400 && !answer.error, answer.body).toBe(true);
});

Then("the answer includes {string}", ({ answer }, needle: string) => {
  expect(text({ answer })).toContain(needle);
});

Then("the answer does not include {string}", ({ answer }, needle: string) => {
  expect(text({ answer })).not.toContain(needle);
});

Then("the answer matches:", ({ answer }, json: string) => {
  expect(parsed({ answer })).toMatchObject(JSON.parse(json));
});

Then("the answer's {string} is:", ({ answer }, path: string, json: string) => {
  expect(dig(parsed({ answer }), path)).toEqual(JSON.parse(json));
});

Then("the answer's {string} is {string}", ({ answer }, path: string, value: string) => {
  expect(String(dig(parsed({ answer }), path))).toBe(value);
});

Then("the answer's {string} lists {int}", ({ answer }, path: string, count: number) => {
  expect(dig(parsed({ answer }), path)).toHaveLength(count);
});
