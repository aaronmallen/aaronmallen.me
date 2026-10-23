import { createCipheriv, hkdfSync, randomBytes } from "node:crypto";

const dataKey = "test-data-key-not-a-real-secret-do-not-use-this-one-in-production";
const key = Buffer.from(hkdfSync("sha256", dataKey, "", "blog-encryptor", 32));

export function seal(text: string) {
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key, iv);
  const body = Buffer.concat([cipher.update(text), cipher.final()]);
  return Buffer.concat([iv, cipher.getAuthTag(), body]).toString("base64");
}
