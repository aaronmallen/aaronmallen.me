Feature: API inbox actions
  The JSON API and the MCP server clear inbox rows, snooze one row or many until a time, and wake a snoozed row.
  A call that names a row that is gone changes nothing.

  Background:
    Given the inbox holds:
      | id | kind       | title   |
      | 9  | issue      | Issue   |
      | 7  | message    | Message |
      | 8  | webmention | Mention |
    And an API token with the scopes "read write mail"

  Scenario: Clearing marks issues seen, messages read and webmentions seen but pending
    When I call the API with "POST /api/v1/inbox/seen" and:
      """
      { "tasks": [9], "messages": [7], "webmentions": [8] }
      """
    Then the call answers 200
    And the answer matches:
      """
      { "tasks": [9], "messages": [7], "webmentions": [8] }
      """
    And the database answers "seen, read, seen, pending" for:
      """
      SELECT (SELECT CASE WHEN seen_at IS NULL THEN 'unseen' ELSE 'seen' END FROM task_sources WHERE task_id = 9) AS issue,
        (SELECT status FROM mail_threads WHERE id = 7) AS message,
        (SELECT CASE WHEN seen_at IS NULL THEN 'unseen' ELSE 'seen' END FROM webmentions WHERE id = 8) AS mention_seen,
        (SELECT status FROM webmentions WHERE id = 8) AS mention
      """

  Scenario: Clearing marks every issue named seen
    Given the inbox holds:
      | id | kind  | title       |
      | 10 | issue | Other issue |
    When I call the API with "POST /api/v1/inbox/seen" and:
      """
      { "tasks": [9, 10] }
      """
    Then the call answers 200
    And the database answers "2" for:
      """
      SELECT count(*) FROM task_sources WHERE seen_at IS NOT NULL
      """

  Scenario: Clearing leaves a row it was not given in the inbox
    Given the inbox holds:
      | id | kind    | title |
      | 20 | message | Later |
    When I call the API with "POST /api/v1/inbox/seen" and:
      """
      { "tasks": [9], "messages": [7], "webmentions": [8] }
      """
    And I call the API with "GET /api/v1/inbox"
    Then the answer's "inbox" lists 1
    And the answer's "inbox.0.id" is "20"

  Scenario: Clearing changes nothing when one row is gone and names it under its kind
    When I call the API with "POST /api/v1/inbox/seen" and:
      """
      { "tasks": [9], "messages": [7], "webmentions": [8, 999] }
      """
    Then the call answers 422
    And the answer's "errors" is:
      """
      { "webmentions": ["no webmention has the ID 999"] }
      """
    And the database answers "unseen, unread, unseen, pending" for:
      """
      SELECT (SELECT CASE WHEN seen_at IS NULL THEN 'unseen' ELSE 'seen' END FROM task_sources WHERE task_id = 9) AS issue,
        (SELECT status FROM mail_threads WHERE id = 7) AS message,
        (SELECT CASE WHEN seen_at IS NULL THEN 'unseen' ELSE 'seen' END FROM webmentions WHERE id = 8) AS mention_seen,
        (SELECT status FROM webmentions WHERE id = 8) AS mention
      """

  Scenario: Clearing keeps the first seen time of an issue already seen
    Given the database runs:
      """
      UPDATE task_sources SET seen_at = '2026-01-02T00:00:00Z' WHERE task_id = 9
      """
    When I call the API with "POST /api/v1/inbox/seen" and:
      """
      { "tasks": [9] }
      """
    Then the database answers "2026-01-02" for:
      """
      SELECT to_char(seen_at AT TIME ZONE 'UTC', 'YYYY-MM-DD') FROM task_sources WHERE task_id = 9
      """

  Scenario: Clearing refuses a call with no rows
    When I call the API with "POST /api/v1/inbox/seen" and:
      """
      { "tasks": [] }
      """
    Then the call answers 422
    And the answer's "errors" is:
      """
      { "input": ["name at least one row to clear"] }
      """

  Scenario: Clearing changes nothing when Gmail refuses a thread
    Given the mail account "aaron@work.example"
    And the Google account "aaron@work.example" is connected with "openid gmail.modify"
    And the inbox holds:
      | id | kind    | title | account            | gmail |
      | 21 | message | Work  | aaron@work.example | t1    |
    And Gmail refuses changes to the mail thread "t1"
    When I call the API with "POST /api/v1/inbox/seen" and:
      """
      { "tasks": [9], "messages": [21] }
      """
    Then the call answers 422
    And the answer's "errors" is:
      """
      { "messages": ["could not clear message 21"] }
      """
    And the database answers "unseen, unread" for:
      """
      SELECT (SELECT CASE WHEN seen_at IS NULL THEN 'unseen' ELSE 'seen' END FROM task_sources WHERE task_id = 9) AS issue,
        (SELECT status FROM mail_threads WHERE id = 21) AS message
      """

  Scenario: Clearing marks a Gmail thread read with no transaction open
    Given the mail account "aaron@work.example"
    And the Google account "aaron@work.example" is connected with "openid gmail.modify"
    And the inbox holds:
      | id | kind    | title | account            | gmail |
      | 21 | message | Work  | aaron@work.example | t1    |
    And Gmail takes changes to the inbox thread "t1" and counts the open transactions
    When I call the API with "POST /api/v1/inbox/seen" and:
      """
      { "tasks": [9], "messages": [21] }
      """
    Then the call answers 200
    And Gmail received POST "/users/me/threads/t1/modify" holding '"removeLabelIds":["UNREAD"]'
    And Gmail saw 0 open transactions while it marked the inbox thread
    And the database answers "seen, read" for:
      """
      SELECT (SELECT CASE WHEN seen_at IS NULL THEN 'unseen' ELSE 'seen' END FROM task_sources WHERE task_id = 9) AS issue,
        (SELECT status FROM mail_threads WHERE id = 21) AS message
      """

  Scenario: The MCP tool clear_inbox answers with the same JSON
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read write mail"
    When I call the MCP tool "clear_inbox" with:
      """
      { "messages": [7] }
      """
    Then the answer matches:
      """
      { "tasks": [], "messages": [7], "webmentions": [] }
      """

  Scenario: Snoozing a row drops it from the inbox
    When I call the API with "POST /api/v1/inbox/snooze" and:
      """
      { "kind": "message", "id": 7, "snoozed_until": "2030-01-01T15:00:00Z" }
      """
    Then the call answers 200
    And the answer matches:
      """
      { "kind": "message", "id": 7, "snoozed_until": "2030-01-01T15:00:00Z" }
      """
    When I call the API with "GET /api/v1/inbox"
    Then the answer does not include "Message"

  Scenario: Snoozing takes each kind the inbox lists
    When I call the API with "POST /api/v1/inbox/snooze" and:
      """
      { "kind": "task", "id": 9, "snoozed_until": "2030-01-01T15:00:00Z" }
      """
    And I call the API with "POST /api/v1/inbox/snooze" and:
      """
      { "kind": "webmention", "id": 8, "snoozed_until": "2030-01-01T15:00:00Z" }
      """
    And I call the API with "GET /api/v1/inbox"
    Then the answer's "inbox" lists 1
    And the answer's "inbox.0.kind" is "message"

  Scenario: Snoozing a row refuses a time in the past or what is not a time
    When I call the API with "POST /api/v1/inbox/snooze" and:
      """
      { "kind": "message", "id": 7, "snoozed_until": "2020-01-01T15:00:00Z" }
      """
    Then the call answers 422
    And the answer's "errors.snoozed_until" is:
      """
      ["snoozed_until must be in the future"]
      """
    When I call the API with "POST /api/v1/inbox/snooze" and:
      """
      { "kind": "message", "id": 7, "snoozed_until": "soon" }
      """
    Then the call answers 422

  Scenario: Snoozing answers 404 for a row that is not there
    When I call the API with "POST /api/v1/inbox/snooze" and:
      """
      { "kind": "message", "id": 999999, "snoozed_until": "2030-01-01T15:00:00Z" }
      """
    Then the call answers 404

  Scenario: The MCP tool snooze_inbox_row answers the same way
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read write mail"
    When I call the MCP tool "snooze_inbox_row" with:
      """
      { "kind": "message", "id": 7, "snoozed_until": "2030-01-01T15:00:00Z" }
      """
    Then the answer matches:
      """
      { "kind": "message", "id": 7, "snoozed_until": "2030-01-01T15:00:00Z" }
      """

  Scenario: Snoozing many rows snoozes every row it names until the time
    Given the inbox holds:
      | id | kind    | title |
      | 20 | message | Later |
    When I call the API with "POST /api/v1/inbox/snooze/all" and:
      """
      { "tasks": [9], "messages": [7], "webmentions": [8], "snoozed_until": "2030-01-01T15:00:00Z" }
      """
    Then the call answers 200
    And the answer matches:
      """
      { "tasks": [9], "messages": [7], "webmentions": [8], "snoozed_until": "2030-01-01T15:00:00Z" }
      """
    When I call the API with "GET /api/v1/inbox"
    Then the answer's "inbox" lists 1
    And the answer's "inbox.0.id" is "20"

  Scenario: Snoozing many rows changes nothing when one row is gone and names it under its kind
    When I call the API with "POST /api/v1/inbox/snooze/all" and:
      """
      { "tasks": [9], "messages": [7, 999999], "webmentions": [8], "snoozed_until": "2030-01-01T15:00:00Z" }
      """
    Then the call answers 422
    And the answer's "errors" is:
      """
      { "messages": ["no message has the ID 999999"] }
      """
    When I call the API with "POST /api/v1/inbox/snooze/all" and:
      """
      { "tasks": [9, 999999], "messages": [7], "webmentions": [8], "snoozed_until": "2030-01-01T15:00:00Z" }
      """
    Then the call answers 422
    And the answer's "errors" is:
      """
      { "tasks": ["no task has the ID 999999"] }
      """
    When I call the API with "GET /api/v1/inbox"
    Then the answer's "inbox" lists 3

  Scenario: Snoozing many rows refuses a time in the past or a call with no rows
    When I call the API with "POST /api/v1/inbox/snooze/all" and:
      """
      { "tasks": [9], "messages": [7], "webmentions": [8], "snoozed_until": "2020-01-01T15:00:00Z" }
      """
    Then the call answers 422
    And the answer's "errors" is:
      """
      { "snoozed_until": ["snoozed_until must be in the future"] }
      """
    When I call the API with "POST /api/v1/inbox/snooze/all" and:
      """
      { "tasks": [], "snoozed_until": "2030-01-01T15:00:00Z" }
      """
    Then the call answers 422
    And the answer's "errors" is:
      """
      { "input": ["name at least one row to snooze"] }
      """

  Scenario: The MCP tool snooze_inbox answers with the same JSON
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read write mail"
    When I call the MCP tool "snooze_inbox" with:
      """
      { "messages": [7], "snoozed_until": "2030-01-01T15:00:00Z" }
      """
    Then the answer matches:
      """
      { "tasks": [], "messages": [7], "webmentions": [], "snoozed_until": "2030-01-01T15:00:00Z" }
      """

  Scenario Outline: Waking a <kind> brings it to the top of the inbox and answers with its row
    Given the inbox holds:
      | id | kind   | title | arrived | snoozed |
      | 30 | <row>  | Woken | -600    | 3600    |
    When I call the API with "POST /api/v1/inbox/wake" and:
      """
      { "kind": "<kind>", "id": 30 }
      """
    Then the call answers 200
    And the answer matches:
      """
      { "kind": "<kind>", "id": 30, "title": "Woken" }
      """
    When I call the API with "GET /api/v1/inbox"
    Then the answer's "inbox.0.kind" is "<kind>"
    And the answer's "inbox.0.id" is "30"

    Examples:
      | kind       | row        |
      | message    | message    |
      | webmention | webmention |
      | task       | issue      |

  Scenario: Waking answers a row that is not snoozed with a 422, and the MCP tool refuses with the same message
    When I call the API with "POST /api/v1/inbox/wake" and:
      """
      { "kind": "message", "id": 7 }
      """
    Then the call answers 422
    And the answer matches:
      """
      { "error": "invalid", "message": "message 7 is not snoozed", "errors": { "id": ["message 7 is not snoozed"] } }
      """
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read write mail"
    When I call the MCP tool "wake_inbox_row" with:
      """
      { "kind": "message", "id": 7 }
      """
    Then it refuses
    And the answer includes "message 7 is not snoozed"

  Scenario: Waking answers a row that is not there with a 404 and refuses an unknown kind
    When I call the API with "POST /api/v1/inbox/wake" and:
      """
      { "kind": "task", "id": 1 }
      """
    Then the call answers 404
    And the answer matches:
      """
      { "error": "not_found", "message": "no task has the ID 1" }
      """
    When I call the API with "POST /api/v1/inbox/wake" and:
      """
      { "kind": "comet", "id": 1 }
      """
    Then the call answers 422

  Scenario: The MCP tool wake_inbox_row answers with the row the endpoint gives
    Given the inbox holds:
      | id | kind    | title  | snoozed | body | reply_to      |
      | 30 | message | Asleep | 3600    | Hi   | a@example.com |
    And I am signed in to the admin
    And an MCP client connected with the scopes "read write mail"
    When I call the MCP tool "wake_inbox_row" with:
      """
      { "kind": "message", "id": 30 }
      """
    Then the answer matches:
      """
      { "kind": "message", "id": 30, "title": "Asleep", "excerpt": "Hi", "url": null, "tags": null, "source": null,
        "type": null, "post_id": null, "reply_to": "a@example.com", "reason": "contact_form" }
      """
