Feature: API token sightings
  Each call with an API token records the device it came from, one row a device.

  Background:
    Given an API token

  Scenario: A call records the token's device, address, user agent and times
    When I call the API GET "token" as "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/141.0.0.0 Safari/537.36"
    Then the database answers "Chrome, macOS, 1, 127.0.0.1, Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/141.0.0.0 Safari/537.36, true, true" for:
      """
      SELECT browser, os, calls, last_address, last_user_agent,
        first_seen_at > now() - interval '1 minute' AS first, last_seen_at > now() - interval '1 minute' AS last
      FROM sightings WHERE api_token_id IS NOT NULL
      """
    And the database answers "Chrome, macOS, true" for:
      """
      SELECT browser, os, api_token_id IS NOT NULL AS tokened FROM known_devices
      """

  Scenario: Repeat calls from one device count on one row, keep the first time and the newest user agent, and know the device once
    When I call the API GET "token" as "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/141.0.0.0 build/0"
    And the database runs "UPDATE sightings SET first_seen_at = now() - interval '1 hour', last_seen_at = now() - interval '1 hour'"
    And I call the API GET "token" as "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/141.0.0.0 build/1"
    And I call the API GET "token" as "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/141.0.0.0 build/2"
    Then the database answers "3, Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/141.0.0.0 build/2, true, true" for:
      """
      SELECT calls, last_user_agent, first_seen_at < now() - interval '59 minutes' AS kept,
        last_seen_at > now() - interval '1 minute' AS fresh
      FROM sightings
      """
    And the table known_devices holds 1 row

  Scenario: Another device adds a row, and a device it cannot read counts on one row
    When I call the API GET "token" as "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/141.0.0.0"
    And I call the API GET "token" as "curl/8.7.1"
    And I call the API GET "token" as "curl/8.7.1"
    Then the database answers "Chrome macOS 1, none none 2" for:
      """
      SELECT string_agg(coalesce(browser, 'none') || ' ' || coalesce(os, 'none') || ' ' || calls, ', ' ORDER BY id) FROM sightings
      """

  Scenario: A token it refuses records nothing
    When I call the API GET "token" with the token "never-minted-token-value-that-is-long-enough"
    Then the table sightings holds 0 rows
