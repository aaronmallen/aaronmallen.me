Feature: Needs attention through the API
  GET /api/v1/attention lists what the admin's Needs attention card shows, worst first, and POST
  /api/v1/attention/snooze snoozes one row for a week. The list_attention and snooze_attention MCP tools answer the
  same.

  Background:
    Given an API token

  Scenario: The API lists one row of each kind worst first, with a carried count or days
    Given the database runs:
      """
      insert into tasks (title, list, position, carried_count) values ('Carried task', 'next', 1, 4);
      insert into posts (title, slug, status, body_html, read_time, word_count, webmentions_enabled, updated_at)
      values ('Old draft', 'old-draft', 'draft', '', 1, 1, false, now() - interval '60 days');
      insert into tasks (title, list, position, updated_at) values ('Someday task', 'someday', 2, now() - interval '100 days');
      insert into journal_entries (entry_date, entry_time, body, body_html)
      values ((now() at time zone 'America/Chicago')::date - 3, '09:00', 'Old', '<p>Old</p>');
      """
    When I call the API with "GET /api/v1/attention"
    Then the call answers 200
    And the answer matches:
      """
      {"attention": [
        {"kind": "draft", "record_id": 1, "title": "Old draft", "carried_count": null, "days": 60},
        {"kind": "journal", "record_id": null, "title": null, "carried_count": null, "days": 3},
        {"kind": "carried", "record_id": 1, "title": "Carried task", "carried_count": 4, "days": null},
        {"kind": "someday", "record_id": 2, "title": "Someday task", "carried_count": null, "days": 100}
      ]}
      """
    And the answer's "attention" lists 4
    Given I am signed in to the admin
    When I visit "/admin"
    Then the attention card lists:
      """
      Old draft
      Journal
      Carried task
      Someday task
      """

  Scenario: The API leaves out a snoozed row, as the card does
    Given the database runs:
      """
      insert into tasks (title, list, position, carried_count) values ('Carried task', 'next', 1, 4);
      insert into posts (title, slug, status, body_html, read_time, word_count, webmentions_enabled, updated_at)
      values ('Old draft', 'old-draft', 'draft', '', 1, 1, false, now() - interval '60 days');
      insert into tasks (title, list, position, updated_at) values ('Someday task', 'someday', 2, now() - interval '100 days');
      insert into journal_entries (entry_date, entry_time, body, body_html)
      values ((now() at time zone 'America/Chicago')::date - 3, '09:00', 'Old', '<p>Old</p>');
      insert into attention_snoozes (kind, record_id, ends_at) values ('draft', 1, now() + interval '7 days');
      """
    When I call the API with "GET /api/v1/attention"
    Then the answer matches:
      """
      {"attention": [{"kind": "journal"}, {"kind": "carried"}, {"kind": "someday"}]}
      """
    And the answer's "attention" lists 3

  Scenario Outline: The API leaves out work that is not stale
    Given the database runs:
      """
      <rows>
      """
    When I call the API with "GET /api/v1/attention"
    Then the answer's "attention" lists 0

    Examples:
      | rows                                                                                                                                                                                   |
      | insert into tasks (title, list, position, carried_count) values ('Carried twice', 'next', 1, 2);                                                                                       |
      | insert into tasks (title, list, position, carried_count, status, completed_at) values ('Done', 'next', 1, 5, 'done', now());                                                            |
      | insert into posts (title, slug, status, body_html, read_time, word_count, webmentions_enabled, updated_at) values ('Draft', 'draft', 'draft', '', 1, 1, false, now() - interval '1 day'); |
      | insert into posts (title, slug, status, published_at, body_html, read_time, word_count, webmentions_enabled, updated_at) values ('Out', 'out', 'published', now() - interval '60 days', '', 1, 1, false, now() - interval '60 days'); |
      | insert into tasks (title, list, position, status, completed_at, updated_at) values ('Closed', 'someday', 1, 'done', now(), now() - interval '120 days');                                 |
      | insert into tasks (title, list, position, updated_at) values ('Old next', 'next', 1, now() - interval '120 days');                                                                     |
      | select 1;                                                                                                                                                                              |

  Scenario: The API returns no rows when nothing is stale
    Given the database runs:
      """
      insert into tasks (title, list, position, carried_count) values ('Carried twice', 'next', 1, 2);
      insert into posts (title, slug, status, body_html, read_time, word_count, webmentions_enabled)
      values ('Fresh draft', 'fresh-draft', 'draft', '', 1, 1, false);
      insert into journal_entries (entry_date, entry_time, body, body_html)
      values ((now() at time zone 'America/Chicago')::date, '09:00', 'Today', '<p>Today</p>');
      """
    When I call the API with "GET /api/v1/attention"
    Then the answer's "attention" lists 0

  Scenario: The API returns the worst five of each kind and every kind's total
    Given the database runs:
      """
      insert into tasks (title, list, position, updated_at)
      select 'Someday ' || n, 'someday', n + 1, now() - make_interval(days => 100 + n) from generate_series(0, 6) n;
      insert into posts (title, slug, status, body_html, read_time, word_count, webmentions_enabled, updated_at)
      values ('Old draft', 'old-draft', 'draft', '', 1, 1, false, now() - interval '60 days');
      insert into journal_entries (entry_date, entry_time, body, body_html)
      values ((now() at time zone 'America/Chicago')::date, '09:00', 'Today', '<p>Today</p>');
      """
    When I call the API with "GET /api/v1/attention"
    Then the answer matches:
      """
      {"attention": [{"title": "Old draft"}, {"title": "Someday 6"}, {"title": "Someday 5"}, {"title": "Someday 4"},
                      {"title": "Someday 3"}, {"title": "Someday 2"}]}
      """
    And the answer's "attention" lists 6
    And the answer's "attention_counts" is:
      """
      {"broken_link": 0, "carried": 0, "draft": 1, "journal": 0, "lapsing": 0, "new_device": 0, "someday": 7}
      """
    Given I am signed in to the admin
    When I visit "/admin"
    Then the attention card lists:
      """
      Old draft
      Someday 6
      Someday 5
      Someday 4
      Someday 3
      Someday 2
      """
    And the Today line "Someday tasks" reads "2 more →"
    And the Today line "Someday tasks" links to "/admin/tasks?filter=someday"

  Scenario: The list_attention tool answers the same JSON as the API
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read"
    And the database runs:
      """
      insert into tasks (title, list, position, carried_count) values ('Carried task', 'next', 1, 3);
      insert into posts (title, slug, status, body_html, read_time, word_count, webmentions_enabled, updated_at)
      values ('Old draft', 'old-draft', 'draft', '', 1, 1, false, now() - interval '45 days');
      insert into journal_entries (entry_date, entry_time, body, body_html)
      values ((now() at time zone 'America/Chicago')::date - 5, '09:00', 'Old', '<p>Old</p>');
      """
    Then the MCP tool "list_attention" answers what "GET /api/v1/attention" answers

  Rule: Snoozing a row
    Background:
      Given the database runs:
        """
        insert into posts (title, slug, status, body_html, read_time, word_count, webmentions_enabled, updated_at)
        values ('Old draft', 'old-draft', 'draft', '', 1, 1, false, now() - interval '60 days');
        insert into journal_entries (entry_date, entry_time, body, body_html)
        values ((now() at time zone 'America/Chicago')::date - 3, '09:00', 'Old', '<p>Old</p>');
        """

    Scenario: Snoozing a row keeps it off the list for seven days
      When I call the API with "POST /api/v1/attention/snooze" and:
        """
        {"kind": "draft", "record_id": 1}
        """
      Then the call answers 200
      And the answer matches:
        """
        {"kind": "draft", "record_id": 1}
        """
      And the database answers "true" for:
        """
        select abs(extract(epoch from ends_at - (now() + interval '7 days'))) < 60 from attention_snoozes
        """
      When I call the API with "GET /api/v1/attention"
      Then the answer matches:
        """
        {"attention": [{"kind": "journal"}]}
        """
      And the answer's "attention" lists 1

    Scenario: Snoozing the journal needs no record_id
      When I call the API with "POST /api/v1/attention/snooze" and:
        """
        {"kind": "journal"}
        """
      Then the call answers 200
      When I call the API with "GET /api/v1/attention"
      Then the answer matches:
        """
        {"attention": [{"kind": "draft"}]}
        """
      And the answer's "attention" lists 1

    Scenario: Snoozing a row again moves the end out a week
      Given the database runs:
        """
        insert into attention_snoozes (kind, record_id, ends_at) values ('draft', 1, now() - interval '1 day');
        """
      When I call the API with "POST /api/v1/attention/snooze" and:
        """
        {"kind": "draft", "record_id": 1}
        """
      Then the database answers "1, true" for:
        """
        select count(*), bool_and(abs(extract(epoch from ends_at - (now() + interval '7 days'))) < 60) from attention_snoozes
        """

    Scenario: Snoozing an unknown kind answers 422
      When I call the API with "POST /api/v1/attention/snooze" and:
        """
        {"kind": "comet", "record_id": 1}
        """
      Then the call answers 422
      And the answer's "error" is "invalid"

    Scenario: Snoozing a row not on the card answers 404 with a message
      When I call the API with "POST /api/v1/attention/snooze" and:
        """
        {"kind": "draft", "record_id": 2}
        """
      Then the call answers 404
      And the answer's "error" is "not_found"
      And the answer's "message" is "no draft row on the card has the record_id 2"

    Scenario: Snoozing a draft with no record_id answers 404
      When I call the API with "POST /api/v1/attention/snooze" and:
        """
        {"kind": "draft"}
        """
      Then the call answers 404

    Scenario: The snooze_attention tool answers the same JSON as the API
      Given I am signed in to the admin
      And an MCP client connected with the scopes "read write"
      Then the MCP tool "snooze_attention" answers what "POST /api/v1/attention/snooze" answers, but the end, for:
        """
        {"kind": "draft", "record_id": 1}
        """

    Scenario: The snooze_attention tool refuses with the message the API gives
      Given I am signed in to the admin
      And an MCP client connected with the scopes "read write"
      When I call the MCP tool "snooze_attention" with:
        """
        {"kind": "draft", "record_id": 2}
        """
      Then it refuses
      And the answer includes "no draft row on the card has the record_id 2"

    Scenario: The snooze_attention tool refuses an unknown kind
      Given I am signed in to the admin
      And an MCP client connected with the scopes "read write"
      When I call the MCP tool "snooze_attention" with:
        """
        {"kind": "comet"}
        """
      Then it refuses
      And the database answers "0" for:
        """
        select count(*) from attention_snoozes
        """
