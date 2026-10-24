import { createHmac } from "node:crypto";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { root } from "./shell.ts";

const appSecret = readFileSync(join(root, "config/settings/test.yml"), "utf8").match(/^app_secret: (.+)$/m)?.[1] ?? "";

export function signedPass(purpose: string, at: Date, secret = appSecret) {
  const issued = at.getTime();
  return `${issued}--${createHmac("sha256", secret).update(`${purpose}:${issued}`).digest("hex")}`;
}
