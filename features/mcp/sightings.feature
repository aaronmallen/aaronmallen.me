Feature: MCP client sightings
  Each call an MCP client makes records the device it came from, one row a device.

  Background:
    Given an MCP client connected with the scopes "read"
    And the database runs "DELETE FROM sightings"

  Scenario: A call records the client's device, address, user agent and times
    When I ask MCP for "tools/list" as "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/141.0.0.0 Safari/537.36"
    Then the database answers "true, true, Chrome, macOS, 1, 127.0.0.1, Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/141.0.0.0 Safari/537.36, true, true" for:
      """
      SELECT api_token_id IS NULL AS untokened, oauth_client_id IS NOT NULL AS client, browser, os, calls, last_address,
        last_user_agent, first_seen_at > now() - interval '1 minute' AS first, last_seen_at > now() - interval '1 minute' AS last
      FROM sightings
      """

  Scenario: A repeat call from the same device counts on one row
    When I ask MCP for "tools/list" as "claude-code/1.2"
    And I ask MCP for "tools/list" as "claude-code/1.2"
    And I ask MCP for "tools/list" as "claude-code/1.2"
    Then the database answers "3" for:
      """
      SELECT string_agg(calls::text, ', ') FROM sightings
      """

  Scenario: A client it cannot read is keyed on the first product in its user agent
    When I ask MCP for "tools/list" as "claude-code/1.2 (external, cli)"
    And I ask MCP for "tools/list" as "claude-code/1.3"
    And I ask MCP for "tools/list" as "python-httpx/0.27"
    Then the database answers "claude-code 2, python-httpx 1" for:
      """
      SELECT string_agg(product || ' ' || calls, ', ' ORDER BY id) FROM sightings
      """

  Scenario: A token it refuses records nothing
    When I ask MCP for "tools/list" with the authorization "Bearer never-issued-token-value-that-is-long-enough"
    Then the table sightings holds 0 rows
