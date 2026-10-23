Feature: Admin MCP clients
  The connected services tab lists each MCP client holding a live token and revokes its access.

  Background:
    Given I am signed in to the admin

  Scenario: The list says so when nothing has connected
    When I visit "/admin/settings/services"
    Then the "Connected clients" card says "Nothing has connected yet"
    And the "Connected clients" card says "No client has connected yet."

  Scenario: Clients holding a live token list newest first, and only those
    Given the MCP clients:
      | name       | connected      | tokens                 |
      | Older      | 1 minute ago   | access                 |
      | Newer      | now            | access, refresh        |
      | Stranger   | now            | none                   |
      | Lapsed     | now            | expired access         |
      | Signed out | now            | revoked access         |
      | Refreshing | 2 minutes ago  | expired access, refresh |
    When I visit "/admin/settings/services"
    Then the "Connected clients" card lists:
      | Newer      |
      | Older      |
      | Refreshing |
    And the page has no axe breaches in light or dark

  Scenario: The count holds only clients that called in the last hour, and the idle ones group apart
    Given the MCP clients:
      | name   | last used      |
      | Claude | 30 minutes ago |
      | Codex  | 2 hours ago    |
      | Fresh  |                |
    When I visit "/admin/settings/services"
    Then the "Connected clients" card says "1 called in the last hour"
    And the "Connected clients" card shows "Claude" then the label "Authorized, idle"
    And the times in the "Codex" row of "Connected clients" end with, in Chicago:
      """
      SELECT last_used_at FROM oauth_clients WHERE client_name = 'Codex'
      """

  Scenario: Every client that called in the last hour leaves out the idle label
    Given the MCP clients:
      | name   | last used |
      | Claude | now       |
    When I visit "/admin/settings/services"
    Then the "Connected clients" card says "1 called in the last hour"
    And the "Connected clients" card does not say "Authorized, idle"

  Scenario: Registrations of one app count once, group together and each keep a revoke
    Given the MCP clients:
      | name   | last used | redirect                                |
      | Claude | now       | https://claude.ai/api/mcp/auth_callback |
      | Claude |           | https://claude.ai/api/mcp/auth_callback |
      | Claude |           | https://evil.example/callback           |
    When I visit "/admin/settings/services"
    Then the "Connected clients" card says "1 called in the last hour"
    And the "Connected clients" card groups "Claude · claude.ai · 2 registrations"
    And the "Claude · claude.ai · 2 registrations" group revokes clients 1 and 2
    And the "Connected clients" card says "evil.example"

  Scenario: Each client shows its redirect host, its times and a link to its sightings
    Given the MCP clients:
      | name   | connected  | last used  | redirect                                |
      | Claude | 3 days ago | 1 hour ago | https://claude.ai/api/mcp/auth_callback |
    When I visit "/admin/settings/services"
    Then the "Claude" row in "Connected clients" says "claude.ai · connected"
    And the "Claude" row in "Connected clients" says "last used"
    And the times in the "Claude" row of "Connected clients" begin with, in Chicago:
      """
      SELECT created_at, last_used_at FROM oauth_clients WHERE client_name = 'Claude'
      """
    And the "Claude" row in "Connected clients" links "sightings →" to "/admin/settings/security"

  Scenario: A client that never made a request says so
    Given the MCP clients:
      | name   |
      | Claude |
    When I visit "/admin/settings/services"
    Then the "Claude" row in "Connected clients" says "never used"

  Scenario: Two clients that registered one name show their hosts
    Given the MCP clients:
      | name   | redirect                                |
      | Claude | https://claude.ai/api/mcp/auth_callback |
      | Claude | https://evil.example/callback           |
    When I visit "/admin/settings/services"
    Then the "Connected clients" card says "claude.ai"
    And the "Connected clients" card says "evil.example"

  Scenario: A client with no name goes by its redirect host, or its client ID
    Given the MCP clients:
      | name | redirect                                | client_id                            | connected    |
      |      | https://claude.ai/api/mcp/auth_callback | 11111111-0000-4000-8000-000000000001 | now          |
      |      | not a uri                               | 11111111-0000-4000-8000-000000000002 | 1 minute ago |
    When I visit "/admin/settings/services"
    Then the "Connected clients" card lists:
      | claude.ai                            |
      | 11111111-0000-4000-8000-000000000002 |
    And the "claude.ai" row in "Connected clients" says "connected"

  Scenario: Revoking asks first and keeps the client when I decline
    Given the MCP clients:
      | name   |
      | Claude |
    When I visit "/admin/settings/services"
    And I press "Revoke" in the "Claude" row of "Connected clients"
    Then I am asked "Revoke access for Claude? It will have to sign in again."
    When I decline
    Then the "Connected clients" card lists:
      | Claude |

  Scenario: Revoking deletes the client's tokens and codes, keeps it registered and says so
    Given the MCP clients:
      | name   | tokens          | codes |
      | Claude | access, refresh | 1     |
      | Other  | access          | 0     |
    When I visit "/admin/settings/services"
    And I press "Revoke" in the "Claude" row of "Connected clients"
    And I confirm
    Then the page toasts "Access revoked"
    And the "Connected clients" card lists:
      | Other |
    And the database answers "Claude 0 0, Other 1 0" for:
      """
      SELECT string_agg(c.client_name || ' ' ||
        (SELECT count(*) FROM oauth_tokens t WHERE t.oauth_client_id = c.id) || ' ' ||
        (SELECT count(*) FROM oauth_codes o WHERE o.oauth_client_id = c.id), ', ' ORDER BY c.client_name)
      FROM oauth_clients c
      """

  Scenario: Revoking comes back to the clients section and refuses a client it does not know
    Given the MCP clients:
      | name   |
      | Claude |
    When I post to "/admin/clients/1/revoke"
    Then the answer sends me to "/admin/settings/services#clients"
    When I post to "/admin/clients/0/revoke"
    Then the answer is 404

  Scenario: The old clients address sends me to the connected services tab
    When I send GET "/admin/clients"
    Then the answer is 302
    And the answer sends me to "/admin/settings/services#clients"

  Scenario: Today links to the clients and the palette opens their tab
    When I visit the admin
    Then the page links "MCP clients" to "/admin/settings/services#clients"
    And the palette offers "/admin/settings/services"
