import { seal } from "../support/seal.ts";
import { Given } from "../support/world.ts";

const scopeFor = (name: string) =>
  name === "openid" || name.startsWith("https://") ? name : `https://www.googleapis.com/auth/${name}`;

Given("the Google account {string} is connected with {string}", async ({ app }, account: string, scopes: string) => {
  const credentials = {
    access_token: `ya29.${account}`,
    expires_at: Math.floor(Date.now() / 1000) + 3600,
    refresh_token: `1//${account}`,
  };
  await app.sql`
      INSERT INTO service_connections ${app.sql({
        account_id: account,
        credentials: seal(JSON.stringify(credentials)),
        label: account,
        provider: "google",
        scopes: scopes.split(" ").map(scopeFor),
      })}
    `;
});

Given("the Google account {string} syncs contacts", async ({ app }, account: string) => {
  await app.sql`
    UPDATE service_connections SET sync_contacts = true, saves_contacts = true
    WHERE provider = 'google' AND account_id = ${account}
  `;
});
