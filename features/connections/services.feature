Feature: Connected services settings
  The connected services tab lists every outside service the site uses, shows
  what each one powers, and lets me connect, test and drop accounts.

  Background:
    Given I am signed in to the admin

  Scenario: The services tab heads its sections and passes axe
    When I visit "/admin/settings/services"
    Then the services tab is titled "Connected services" under "Settings"
    And the services tab shows the sections "services tokens clients"
    And the page has no axe breaches in light or dark

  Scenario: The services tab lets its forms reach a sign-in page on any https origin
    When I visit "/admin/settings/services"
    Then the services page lets forms post to "'self' https:"
    When I connect Linear with the key "  "
    Then the services page lets forms post to "'self' https:"
    When I visit "/admin/tasks"
    Then the services page lets forms post to "'self'"

  Scenario: The tab label counts the services the tab lists
    Given a Linear connection to "Workspace" with the key "lin_api_secret"
    Then the connected services tab counts the services it lists

  Scenario: An old services address sends me to the tab and keeps the pick
    When I visit "/admin/services"
    Then the services address is "/admin/settings/services#services"
    When I visit "/admin/services?selected=maxmind"
    Then the services address is "/admin/settings/services?selected=maxmind#services"
    When I visit "/admin/services?connect=linear"
    Then the services address is "/admin/settings/services?connect=linear#services"

  Scenario: The command palette opens the services tab
    When I visit "/admin"
    Then the command palette opens the services tab

  Scenario: The list holds the services that need no sign-in and the picker holds the rest
    When I visit "/admin/settings/services"
    Then the services group "Social" lists "Bridgy"
    And the services group "Infrastructure" lists "Backup store, Honeybadger, MaxMind, Media store"
    And the service picker lists "GitHub, Linear, Bluesky, LinkedIn, Mastodon, Google"
    And no services group is called "Available"
    And the service row "Honeybadger" shows "not set up"
    And the service row "Bridgy" shows "connected"
    And the service panel shows "Click a service to see what it powers and how often its jobs run."
    And the service picker hints "The media and backup stores, MaxMind and Honeybadger take their keys from the server environment"

  Scenario: Connected services keep their keys sealed in the database
    Given a Linear connection to "ROOT" with the key "lin_api_secret"
    When I visit "/admin/settings/services"
    Then I see "Services you connect keep their tokens encrypted in the database."
    And the stored Linear credentials do not hold "lin_api_secret"
    And the Linear connection "ROOT" holds the credentials '{"api_key": "lin_api_secret"}'

  Scenario: Two Linear workspaces show as two rows and Linear stays in the picker
    Given a Linear connection to "ROOT" with the key "lin_api_root"
    And a Linear connection to "Hanakai" with the key "lin_api_hana"
    When I visit "/admin/settings/services"
    Then the services group "Code and sign-in" lists "Linear, Linear"
    And the service rows show the accounts "ROOT, Hanakai"
    And the service picker offers "Linear"

  Scenario: A row dots the account and its last use apart
    Given a Linear connection to "ROOT" used an hour ago
    When I visit "/admin/settings/services"
    Then the service row "ROOT" reads "ROOT · used"

  Scenario: A connection to a service with no definition stays hidden
    Given a connection to the unknown service "myspace" as "Tom from Myspace"
    When I visit "/admin/settings/services"
    Then I do not see "Tom from Myspace"

  Scenario: Bridgy pauses while the webmention settings turn it off
    Given the webmention settings turn Bridgy off
    When I visit "/admin/settings/services"
    Then the service row "Bridgy" shows "paused"

  Scenario: A failing job marks its service and names the failure
    Given a Linear connection to "ROOT" with the key "lin_api_root"
    And the Linear issue sync is failing
    When I visit "/admin/settings/services"
    Then the service row "Linear" shows "failing"
    And the services count shows "1 failing"
    And the services glance names a sync failure
    When I open the connection "ROOT"
    Then the service panel shows a sync failure named for its job

  Scenario: A picked service shows its powers, jobs and environment keys but never their values
    When I visit "/admin/settings/services?selected=maxmind"
    Then the service panel shows "MaxMind"
    And the service panel lists "Countries in Analytics" under its powers
    And the service line "Country database refresh" reads "weekly"
    And the service row "MaxMind" is open
    And the service panel lists the environment keys "MAXMIND_ACCOUNT_ID MAXMIND_LICENSE_KEY"
    And the service line "MAXMIND_LICENSE_KEY" shows "set"
    And I do not see "stub-license"
    And the service panel shows "Set in the server environment. Change them there, then redeploy."
    And the page has no axe breaches in light or dark

  Scenario: A connected account shows the scopes it holds
    Given a Mastodon connection as "@aaron@203.0.113.9" on "203.0.113.9" with the scopes "write:statuses"
    When I open the connection "@aaron@203.0.113.9"
    Then the service line "Post on your behalf" shows "granted"
    And the service line "Look up accounts" shows "not granted"

  Scenario: Bridgy points to the webmention toggle
    When I visit "/admin/settings/services?selected=bridgy"
    Then the service panel links "webmentions →" to "/admin/settings/webmentions#webmentions"

  Scenario: The MCP token tool lists live tokens newest first and never their secrets
    Given the API token "Laptop" was made on "2026-09-01T00:00:00Z" and last used on "2026-09-02T00:00:00Z"
    And the API token "Terminal" was made on "2026-09-03T00:00:00Z" and last used on ""
    And the API token "Retired" was revoked
    When an MCP client connected with the scopes "read"
    And I call the MCP tool "list_api_tokens"
    Then the MCP answer lists "Terminal" before "Laptop"
    And the MCP answer holds "2026-09-03T00:00:00Z"
    And the MCP answer holds "2026-09-02T00:00:00Z"
    And the MCP answer does not hold "Retired"
    And the MCP answer holds no token or digest

  Scenario: The MCP client tool lists live clients, marks the caller and never sends a token
    Given an MCP client named "Cursor" holding a live token for "write read"
    And an MCP client with no name that comes back to "https://cursor.example/callback"
    And an MCP client named "Gone" whose token was revoked
    And an MCP client named "Idle" holding no token
    When an MCP client connected with the scopes "read"
    And I call the MCP tool "list_clients"
    Then the MCP client list shows "Cursor" with the scopes "read write"
    And the MCP client list shows "cursor.example" with the scopes "read"
    And the MCP client list marks "Features" as the caller with its last use
    And the MCP answer does not hold "Gone"
    And the MCP answer does not hold "Idle"
    And the MCP answer holds no token or digest
