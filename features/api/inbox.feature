Feature: API inbox
  The JSON API and the MCP server list the inbox as the Inbox screen does, and clear, snooze and wake its rows.

  Scenario: The API lists each row newest first with its kind, id, title, excerpt, link and kind fields
    Given the inbox holds:
      | id | kind       | title  | arrived | tags | body        | reply_to          | excerpt   | source                                           |
      | 9  | issue      | Oldest | -120    | home |             |                   |           | https://github.com/aaronmallen/aaronmallen.me/issues/1 |
      | 7  | message    | Middle | -60     |      | Hello there | ada@example.com   |           |                                                  |
      | 8  | webmention | Newest | 0       |      |             |                   | Nice post | https://example.com/a                            |
    And an API token with the scopes "read mail"
    When I call the API with "GET /api/v1/inbox"
    Then the call answers 200
    And the answer matches:
      """
      {
        "inbox": [
          { "kind": "webmention", "id": 8, "title": "Newest", "excerpt": "Nice post", "url": "https://example.com/a",
            "tags": null, "source": null, "type": "mention", "post_id": 1, "reply_to": null, "reason": null },
          { "kind": "message", "id": 7, "title": "Middle", "excerpt": "Hello there", "url": null,
            "tags": null, "source": null, "type": null, "post_id": null, "reply_to": "ada@example.com",
            "reason": "contact_form" },
          { "kind": "task", "id": 9, "title": "Oldest", "excerpt": null,
            "url": "https://github.com/aaronmallen/aaronmallen.me/issues/1", "tags": ["home"],
            "source": { "provider": "github", "reference": "aaronmallen/aaronmallen.me#1" }, "type": null,
            "post_id": null, "reply_to": null, "reason": null }
        ]
      }
      """

  Scenario: The API lists the rows the Inbox screen shows, in the same order
    Given the inbox holds:
      | kind       | title  | arrived |
      | issue      | Oldest | -120    |
      | message    | Middle | -60     |
      | webmention | Newest | 0       |
    And an API token with the scopes "read mail"
    When I call the API with "GET /api/v1/inbox"
    Then the answer's "inbox.0.title" is "Newest"
    And the answer's "inbox.1.title" is "Middle"
    And the answer's "inbox.2.title" is "Oldest"
    And the answer's "inbox" lists 3
    Given I am signed in to the admin
    Then the inbox shows the rows "Newest, Middle, Oldest"

  Scenario: The API cuts a message's excerpt to the start of its body
    Given the inbox holds:
      | id | kind    | title | body          |
      | 7  | message | Long  | [c × 500]TAIL |
    And an API token with the scopes "read mail"
    Then the API inbox gives the row 7 the excerpt "[c × 500]"

  Scenario: The API gives each row its time
    Given the inbox holds:
      | kind    | title  | arrived              |
      | message | Middle | 2026-09-07T17:30:00Z |
    And an API token with the scopes "read mail"
    When I call the API with "GET /api/v1/inbox"
    Then the answer's "inbox.0.at" is "2026-09-07T17:30:00Z"

  Scenario: The API gives a token with mail the newest 100 rows of every kind
    Given the inbox holds:
      | id | kind       | title   | arrived |
      | 8  | webmention | Mention | -3600   |
    And 101 more inbox messages arrived in the last minutes, titled "Message" and a number
    And an API token with the scopes "read mail"
    When I call the API with "GET /api/v1/inbox"
    Then the answer's "inbox" lists 100
    And the answer's "inbox.0.title" is "Message 1"
    And the answer's "inbox.99.kind" is "message"

  Scenario: The API still lists the older webmention for a token without mail
    Given the inbox holds:
      | id | kind       | title   | arrived |
      | 8  | webmention | Mention | -3600   |
    And 101 more inbox messages arrived in the last minutes, titled "Message" and a number
    And an API token with the scopes "read write"
    When I call the API with "GET /api/v1/inbox"
    Then the answer's "inbox" lists 1
    And the answer's "inbox.0.kind" is "webmention"
    And the answer's "inbox.0.id" is "8"

  Scenario: The API leaves out what no longer waits, as the screen does
    Given the inbox holds:
      | kind       | title      | state    |
      | message    | Read       | read     |
      | webmention | Approved   | approved |
      | webmention | Seen       | seen     |
      | issue      | Seen issue | seen     |
      | issue      | Done       | done     |
      | issue      | Canceled   | canceled |
    And an API token with the scopes "read mail"
    When I call the API with "GET /api/v1/inbox"
    Then the answer's "inbox" lists 0

  Scenario: The MCP tool list_inbox answers what the API does
    Given the inbox holds:
      | kind       | title   |
      | issue      | Issue   |
      | message    | Message |
      | webmention | Mention |
    And an API token with the scopes "read mail"
    And I am signed in to the admin
    And an MCP client connected with the scopes "read mail"
    Then the MCP tool "list_inbox" answers what "GET /api/v1/inbox" does, once its marks come off
