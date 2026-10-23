Feature: New devices on the attention list
  When a sign-in, an API token or an MCP client shows up from a device it has not used before, the Needs attention
  card gets a row for a week, so the owner can check it was them.

  Background:
    Given an API token
    And the country database holds the test networks
    And the database runs:
      """
      delete from known_devices;
      delete from sign_ins;
      """

  Scenario: An API token's first device adds nothing
    Given an attention API token named "Terminal"
    When the attention API token "Terminal" calls from Chrome
    And I call the API with "GET /api/v1/attention"
    Then the answer's "attention" lists 0

  Scenario: An API token on a device it has not called from adds a row
    Given an attention API token named "Terminal"
    When the attention API token "Terminal" calls from Chrome
    And the attention API token "Terminal" calls from curl
    And I call the API with "GET /api/v1/attention"
    Then the answer matches:
      """
      {"attention": [{"kind": "new_device", "title": "API token Terminal: an unknown device in an unknown place", "days": 0}]}
      """

  Scenario: An API token on a device it already used adds nothing
    Given an attention API token named "Terminal"
    When the attention API token "Terminal" calls from Chrome
    And the attention API token "Terminal" calls from curl
    And the database runs:
      """
      update known_devices set created_at = now() - interval '30 days';
      """
    And the attention API token "Terminal" calls from curl
    And I call the API with "GET /api/v1/attention"
    Then the answer's "attention" lists 0

  Scenario: An API token on a known device adds nothing once its sightings are pruned
    Given an attention API token named "Terminal"
    When the attention API token "Terminal" calls from Chrome
    And the attention API token "Terminal" calls from curl
    And the database runs:
      """
      update known_devices set created_at = now() - interval '30 days';
      delete from sightings;
      """
    And the attention API token "Terminal" calls from curl
    And I call the API with "GET /api/v1/attention"
    Then the answer's "attention" lists 0
    And the database answers "1" for:
      """
      select count(*) from sightings where api_token_id = (select id from api_tokens where name = 'Terminal')
      """

  Scenario: A new device row stays for seven days
    Given an attention API token named "Terminal"
    When the attention API token "Terminal" calls from Chrome
    And the attention API token "Terminal" calls from curl
    And the database runs:
      """
      update known_devices set created_at = now() - interval '6 days' where id = 2;
      """
    And I call the API with "GET /api/v1/attention"
    Then the answer matches:
      """
      {"attention": [{"kind": "new_device", "record_id": 2, "days": 6}]}
      """
    Given the database runs:
      """
      update known_devices set created_at = now() - interval '7 days' where id = 2;
      """
    When I call the API with "GET /api/v1/attention"
    Then the answer's "attention" lists 0

  Scenario: A new device row ranks above stalled work
    Given an attention API token named "Terminal"
    And the database runs:
      """
      insert into tasks (title, list, position, carried_count) values ('Carried task', 'next', 1, 9);
      """
    When the attention API token "Terminal" calls from Chrome
    And the attention API token "Terminal" calls from curl
    And I call the API with "GET /api/v1/attention"
    Then the answer matches:
      """
      {"attention": [{"kind": "new_device"}, {"kind": "carried"}]}
      """

  Scenario: Snoozing a new device row takes it off the list
    Given an attention API token named "Terminal"
    When the attention API token "Terminal" calls from Chrome
    And the attention API token "Terminal" calls from curl
    And I call the API with "POST /api/v1/attention/snooze" and:
      """
      {"kind": "new_device", "record_id": 2}
      """
    Then the call answers 200
    When I call the API with "GET /api/v1/attention"
    Then the answer's "attention" lists 0

  Scenario: A new device row's snooze goes when the token goes
    Given an attention API token named "Terminal"
    When the attention API token "Terminal" calls from Chrome
    And the attention API token "Terminal" calls from curl
    And the database runs:
      """
      insert into attention_snoozes (kind, record_id, ends_at) values ('new_device', 2, now() + interval '7 days');
      delete from api_tokens where name = 'Terminal';
      """
    Then the database answers "0, 0" for:
      """
      select (select count(*) from known_devices) as devices, (select count(*) from attention_snoozes) as snoozes
      """

  Scenario: An MCP client on a device it has not called from adds a row, its title marked untrusted
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read"
    When the attention MCP client calls from Playwright
    And the attention MCP client calls from Firefox
    And I call the MCP tool "list_attention"
    Then the answer matches:
      """
      {"attention": [{"kind": "new_device", "title": "MCP client Features: Firefox on Linux in an unknown place", "days": 0,
                      "carried_count": null, "post_id": null, "url": null, "reason": null, "failures": null}]}
      """
    And the answer's "attention" lists 1
    And the answer includes '"untrusted":true'

  Scenario: A sign-in from a device the owner has not signed in from adds a row
    When a sign-in to the admin comes from Chrome
    And a sign-in to the admin comes from Firefox
    And I call the API with "GET /api/v1/attention"
    Then the answer matches:
      """
      {"attention": [{"kind": "new_device", "title": "Sign-in: Firefox on Linux in an unknown place"}]}
      """

  Scenario: A failed sign-in from a new device adds nothing
    When a sign-in to the admin comes from Chrome
    Given GitHub answers GET "/user/emails" with:
      """
      [{"email": "stranger@example.com", "primary": true, "verified": true}]
      """
    When a sign-in to the admin comes from Firefox
    And I call the API with "GET /api/v1/attention"
    Then the answer's "attention" lists 0
    And the database answers "signed_in, wrong_account" for:
      """
      select string_agg(outcome::text, ', ' order by id) from sign_ins
      """

  Scenario: A new sign-in device shows on the admin card with a snooze
    When a sign-in to the admin comes from Chrome
    And a sign-in to the admin comes from Firefox
    And I am signed in to the admin
    And I visit "/admin"
    Then the attention row "Sign-in: Firefox on Linux in an unknown place" says only "New device or place today"
    And the attention row "Sign-in: Firefox on Linux in an unknown place" snoozes as "new_device"
