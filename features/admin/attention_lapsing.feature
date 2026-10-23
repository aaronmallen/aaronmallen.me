Feature: Lapsing connections on the attention list
  A service connection that lapses within a week gets a row on the Needs attention card with the days left, and
  keeps it once it has lapsed, until the owner reconnects or removes it.

  Background:
    Given an API token
    And the country database holds the test networks

  Scenario: A connection that never lapses adds nothing
    Given an attention LinkedIn connection for "Ada Lovelace" that never lapses
    When I call the API with "GET /api/v1/attention"
    Then the answer's "attention" lists 0

  Scenario: A connection more than a week from lapsing adds nothing
    Given an attention LinkedIn connection for "Ada Lovelace" that lapses in 8 days
    When I call the API with "GET /api/v1/attention"
    Then the answer's "attention" lists 0

  Scenario: A connection a week from lapsing adds a row with the days left
    Given an attention LinkedIn connection for "Ada Lovelace" that lapses in 7 days
    When I call the API with "GET /api/v1/attention"
    Then the answer matches:
      """
      {"attention": [{"kind": "lapsing", "record_id": 1, "title": "Ada Lovelace", "days": 7}]}
      """

  Scenario: A lapsed connection keeps its row below zero days and ranks above stalled work
    Given an attention LinkedIn connection for "Ada Lovelace" that lapsed 2 days ago
    And the database runs:
      """
      insert into tasks (title, list, position, carried_count) values ('Carried task', 'next', 1, 9);
      """
    When I call the API with "GET /api/v1/attention"
    Then the answer matches:
      """
      {"attention": [{"kind": "lapsing", "days": -2}, {"kind": "carried"}]}
      """

  Scenario: A snoozed row stays hidden, and goes with its snooze when the connection goes
    Given an attention LinkedIn connection for "Ada Lovelace" that lapses in 2 days
    When I call the API with "POST /api/v1/attention/snooze" and:
      """
      {"kind": "lapsing", "record_id": 1}
      """
    And I call the API with "GET /api/v1/attention"
    Then the answer's "attention" lists 0
    Given the database runs:
      """
      delete from service_connections;
      """
    Then the database answers "0" for:
      """
      select count(*) from attention_snoozes
      """

  Scenario: The admin card shows the days left, a link to the connection and a snooze
    Given an attention LinkedIn connection for "Ada Lovelace" that lapses in 3 days
    And I am signed in to the admin
    When I visit "/admin"
    Then the attention row "Ada Lovelace" opens "/admin/settings/services?selected=1#services"
    And the attention row "Ada Lovelace" says only "Connection lapses in 3 days"
    And the attention row "Ada Lovelace" snoozes as "lapsing"

  Scenario: The admin card says so once the connection has lapsed
    Given an attention LinkedIn connection for "Ada Lovelace" that lapsed 1 day ago
    And I am signed in to the admin
    When I visit "/admin"
    Then the attention row "Ada Lovelace" says only "Connection lapsed, reconnect it to post again"

  Scenario: list_attention returns the row
    Given an attention LinkedIn connection for "Ada Lovelace" that lapses in 3 days
    And I am signed in to the admin
    And an MCP client connected with the scopes "read"
    When I call the MCP tool "list_attention"
    Then the answer's "attention" is:
      """
      [{"kind": "lapsing", "record_id": 1, "title": "Ada Lovelace", "carried_count": null, "days": 3, "post_id": null,
        "url": null, "reason": null, "failures": null}]
      """
