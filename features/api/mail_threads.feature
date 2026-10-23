Feature: Mail threads in the API
  A token with the mail scope lists, reads, marks, tags, snoozes and trashes mail threads,
  one at a time or in bulk. The MCP mail tools answer the same as the endpoints.

  Background:
    Given an API token with the scopes "read write delete mail"

  Scenario: The API lists mail threads newest first with the reply address and no body
    Given the mail threads:
      | subject | reply to          | body       | minutes ago |
      | Older   | grace@example.com | Old words  | 60          |
      | Engines | ada@example.com   | Hi there   | 5           |
    And the mail thread "Engines" arrived "2026-01-05T09:00:00Z"
    And the mail thread "Older" arrived "2026-01-04T09:00:00Z"
    When I call the mail API with GET "/mail/threads"
    Then the API answers with status 200
    And the API answer lists the mail threads "Engines, Older"
    And the API answer's "mail_threads.0" reads:
      """
      {"id": 2, "account": "Contact form", "subject": "Engines", "reply_to": "ada@example.com", "status": "unread",
        "tags": [], "received_at": "2026-01-05T09:00:00Z", "snoozed_until": null}
      """
    And the API answer does not hold "Hi there"

  Scenario: The API reads a thread with each message oldest first
    Given the mail threads:
      | subject | body  |
      | Engines | First |
    And the mail thread "Engines" has a later message saying "Second"
    When I call the mail API with GET "/mail/threads/#[Engines]"
    Then the API answers with status 200
    And the API answer's "messages.0.body" is "\"First\""
    And the API answer's "messages.1.body" is "\"Second\""

  Scenario: A token without the mail scope reaches no mail endpoint
    Given the mail threads:
      | subject |
      | Engines |
    And an API token with the scopes "read write delete"
    When I call the mail API with GET "/mail/threads"
    Then the API answers with status 403
    When I call the mail API with GET "/mail/threads/#[Engines]"
    Then the API answers with status 403

  Scenario Outline: A token without the mail scope may not <action> mail threads in bulk
    Given the mail threads:
      | subject |
      | Engines |
    And an API token with the scopes "read write delete"
    When I call the mail API with POST "/mail/threads/bulk/<action>" and:
      """
      {"ids": [#[Engines]], "tag": "billing", "snoozed_until": "2099-01-02T03:00:00Z"}
      """
    Then the API answers with status 403
    And the API answer's "error" is "\"insufficient_scope\""
    And the mail thread "Engines" reads:
      | status        | unread |
      | trashed       | false  |
      | snoozed_until | none   |

    Examples:
      | action |
      | read   |
      | unread |
      | tag    |
      | untag  |
      | snooze |
      | delete |

  Scenario: The API marks one thread and refuses a status it does not know
    Given the mail threads:
      | subject |
      | Engines |
    When I call the mail API with POST "/mail/threads/#[Engines]/mark" and:
      """
      {"status": "spam"}
      """
    Then the API answers with status 200
    And the API answer reads:
      """
      {"id": #[Engines], "status": "spam"}
      """
    And the mail thread "Engines" is now spam
    When I call the mail API with POST "/mail/threads/#[Engines]/mark" and:
      """
      {"status": "lost"}
      """
    Then the API answers with status 422

  Scenario Outline: Bulk <action> marks only the named threads and answers each one whole
    Given the mail threads:
      | subject | status   | reply to        | body     |
      | One     | <before> | ada@example.com | Hi there |
      | Two     | <before> |                 |          |
      | Left    | <before> |                 |          |
    And the mail thread "One" arrived "2026-01-05T09:00:00Z"
    And the mail thread "Two" snoozes until "2099-01-02T03:00:00Z"
    When I call the mail API with POST "/mail/threads/bulk/<action>" and:
      """
      {"ids": [#[One], #[Two]]}
      """
    Then the API answers with status 200
    And the API answer lists the mail threads "One, Two"
    And the API answer's "mail_threads.0" reads:
      """
      {"id": 1, "account": "Contact form", "subject": "One", "body": "Hi there", "reply_to": "ada@example.com",
        "status": "<after>", "tags": [], "received_at": "2026-01-05T09:00:00Z", "snoozed_until": null}
      """
    And the API answer's "mail_threads.1.snoozed_until" is "\"2099-01-02T03:00:00Z\""
    And the mail thread "Two" is now <after>
    And the mail thread "Left" is now <before>

    Examples:
      | action | before | after  |
      | read   | unread | read   |
      | unread | read   | unread |

  Scenario Outline: Bulk <action> changes nothing when one ID is gone and names it
    Given the mail threads:
      | subject | status   | tags    |
      | One     | <before> | billing |
      | Two     | <before> | billing |
    When I call the mail API with POST "/mail/threads/bulk/<action>" and:
      """
      {"ids": [#[One], #[Two], 99]<extra>}
      """
    Then the API answers with status 422
    And the API answer reads:
      """
      {"error": "invalid", "message": "no mail thread has the ID 99", "errors": {"ids": ["no mail thread has the ID 99"]}}
      """
    And the mail thread "One" reads:
      | status        | <before> |
      | trashed       | false    |
      | snoozed_until | none     |
    And the mail thread "Two" has the tags "billing"

    Examples:
      | action | before | extra                                     |
      | read   | unread |                                           |
      | unread | read   |                                           |
      | untag  | unread | , "tag": "billing"                        |
      | snooze | unread | , "snoozed_until": "2099-01-02T03:00:00Z" |
      | delete | unread |                                           |

  Scenario: Bulk tag adds the tag once and keeps the tags each thread had
    Given the mail threads:
      | subject | tags    |
      | One     | billing |
      | Two     |         |
      | Three   | urgent  |
    When I call the mail API with POST "/mail/threads/bulk/tag" and:
      """
      {"ids": [#[One], #[Two]], "tag": "Urgent"}
      """
    Then the API answers with status 200
    And the API answer's "mail_threads.0.tags" is "[\"billing\",\"urgent\"]"
    And the API answer's "mail_threads.1.tags" is "[\"urgent\"]"
    When I call the mail API with POST "/mail/threads/bulk/tag" and:
      """
      {"ids": [#[One], #[Three]], "tag": "billing"}
      """
    Then the mail thread "One" has the tags "billing, urgent"
    And the mail thread "Three" has the tags "billing, urgent"
    When I call the mail API with POST "/mail/threads/bulk/tag" and:
      """
      {"ids": [#[Two], 99], "tag": "later"}
      """
    Then the API answers with status 422
    And the API answer's "message" is "\"no mail thread has the ID 99\""
    And the mail thread "Two" has the tags "urgent"

  Scenario: Bulk tag refuses a tag it cannot use
    Given the mail threads:
      | subject |
      | One     |
    When I call the mail API with POST "/mail/threads/bulk/tag" and:
      """
      {"ids": [#[One]], "tag": "two words"}
      """
    Then the API answers with status 422
    And the API answer's "errors" is "{\"tag\":[\"a tag is lowercase words joined by hyphens\"]}"
    When I call the mail API with POST "/mail/threads/bulk/tag" and:
      """
      {"ids": [#[One]], "tag": " "}
      """
    Then the API answer's "message" is "\"tag: name the tag first\""
    When I call the mail API with POST "/mail/threads/bulk/tag" and:
      """
      {"ids": [#[One]]}
      """
    Then the API answer's "errors" is "{\"tag\":[\"tag is missing\"]}"
    And the mail thread "One" has the tags ""

  Scenario: Bulk untag takes the tag off each thread
    Given the mail threads:
      | subject | tags            |
      | One     | billing, urgent |
      | Two     | billing         |
    When I call the mail API with POST "/mail/threads/bulk/untag" and:
      """
      {"ids": [#[One], #[Two]], "tag": "billing"}
      """
    Then the API answers with status 200
    And the API answer's "mail_threads.0.tags" is "[\"urgent\"]"
    And the API answer's "mail_threads.1.tags" is "[]"

  Scenario: Bulk snooze snoozes the threads and answers them whole in the order given
    Given the mail threads:
      | subject | reply to        | body     |
      | One     | ada@example.com | Hi there |
      | Two     | ada@example.com | Hi again |
    And the mail thread "One" arrived "2026-01-05T09:00:00Z"
    And the mail thread "Two" arrived "2026-01-06T09:00:00Z"
    When I call the mail API with POST "/mail/threads/bulk/snooze" and:
      """
      {"ids": [#[Two], #[One]], "snoozed_until": "2099-01-02T03:00:00Z"}
      """
    Then the API answers with status 200
    And the API answer reads:
      """
      {"mail_threads": [
        {"id": #[Two], "account": "Contact form", "subject": "Two", "body": "Hi again", "reply_to": "ada@example.com",
          "tags": [], "received_at": "2026-01-06T09:00:00Z", "snoozed_until": "2099-01-02T03:00:00Z", "status": "unread"},
        {"id": #[One], "account": "Contact form", "subject": "One", "body": "Hi there", "reply_to": "ada@example.com",
          "tags": [], "received_at": "2026-01-05T09:00:00Z", "snoozed_until": "2099-01-02T03:00:00Z", "status": "unread"}
      ]}
      """
    And the mail thread "One" is now snoozed

  Scenario: Bulk snooze refuses a time in the past
    Given the mail threads:
      | subject |
      | One     |
    When I call the mail API with POST "/mail/threads/bulk/snooze" and:
      """
      {"ids": [#[One]], "snoozed_until": "2000-01-01T00:00:00Z"}
      """
    Then the API answers with status 422
    And the API answer's "errors" is "{\"snoozed_until\":[\"snoozed_until must be in the future\"]}"

  Scenario: Bulk delete moves only the named threads to the trash
    Given the mail threads:
      | subject |
      | One     |
      | Two     |
      | Left    |
    When I call the mail API with POST "/mail/threads/bulk/delete" and:
      """
      {"ids": [#[One], #[Two]]}
      """
    Then the API answers with status 200
    And the API answer reads:
      """
      {"mail_threads": [{"id": #[One], "subject": "One", "trashed": true}, {"id": #[Two], "subject": "Two", "trashed": true}]}
      """
    And the mail thread "One" is now trashed
    And the mail thread "Left" reads:
      | trashed | false |

  Scenario: Bulk delete sends a Gmail thread to the Gmail trash rather than deleting it
    Given the Google account "aaron@work.example" is connected with "openid gmail.modify"
    And the mail account "aaron@work.example"
    And the mail threads:
      | subject | account            | gmail id |
      | Lunch   | aaron@work.example | t1       |
    And Gmail takes changes to the mail threads "t1"
    When I call the mail API with POST "/mail/threads/bulk/delete" and:
      """
      {"ids": [#[Lunch]]}
      """
    Then the API answers with status 200
    And Gmail received POST "/users/me/threads/t1/trash"
    And Gmail received no DELETE "/users/me/threads/t1"
    And the mail thread "Lunch" is now trashed

  Scenario: Bulk read tells Gmail of every Gmail thread
    Given the Google account "aaron@work.example" is connected with "openid gmail.modify"
    And the mail account "aaron@work.example"
    And the mail threads:
      | subject | account            | gmail id |
      | One     | aaron@work.example | t1       |
      | Two     | aaron@work.example | t2       |
    And Gmail takes changes to the mail threads "t1, t2"
    When I call the mail API with POST "/mail/threads/bulk/read" and:
      """
      {"ids": [#[One], #[Two]]}
      """
    Then the API answers with status 200
    And Gmail received POST "/users/me/threads/t1/modify" holding "UNREAD"
    And Gmail received POST "/users/me/threads/t2/modify" holding "UNREAD"
    And the mail thread "Two" is now read

  Scenario: Bulk read changes no thread when Gmail refuses one
    Given the Google account "aaron@work.example" is connected with "openid gmail.modify"
    And the mail account "aaron@work.example"
    And the mail threads:
      | subject | account            | gmail id |
      | One     | aaron@work.example | t1       |
      | Two     | aaron@work.example | t2       |
    And Gmail takes changes to the mail threads "t1"
    And Gmail refuses changes to the mail thread "t2"
    When I call the mail API with POST "/mail/threads/bulk/read" and:
      """
      {"ids": [#[One], #[Two]]}
      """
    Then the API answers with status 500
    And the mail thread "One" is now unread
    And the mail thread "Two" is now unread

  Scenario: Bulk actions act on a repeated ID once and answer in the order given
    Given the mail threads:
      | subject |
      | One     |
      | Two     |
      | Three   |
    When I call the mail API with POST "/mail/threads/bulk/read" and:
      """
      {"ids": [#[One], #[One]]}
      """
    Then the API answer lists the mail threads "One"
    When I call the mail API with POST "/mail/threads/bulk/read" and:
      """
      {"ids": [#[Three], #[Two], #[One]]}
      """
    Then the API answer lists the mail threads "Three, Two, One"

  Scenario Outline: Bulk actions refuse <case>
    When I call the mail API with POST "/mail/threads/bulk/read" and:
      """
      <body>
      """
    Then the API answers with status 422
    And the API answer's "errors.ids" reads:
      """
      <errors>
      """

    Examples:
      | case                     | body                                     | errors                 |
      | an empty list            | {"ids": []}                              | ["array size at `/ids` is less than: 1"] |
      | more than 100 IDs        | {"ids": [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101]} | ["array size at `/ids` is greater than: 100"] |
      | an ID that is not a number | {"ids": ["one"]}                       | ["value at `/ids/0` is not an integer"] |
      | a request with no IDs    | {}                                       | ["ids is missing"]     |

  Scenario: The MCP mail tools answer as the endpoints do
    Given the mail threads:
      | subject | tags            |
      | One     | billing, urgent |
    And I am signed in to the admin
    And an MCP client connects with the scopes "read write delete mail" and I approve it
    Then the API GET "/mail/threads" and the MCP tool "list_mail_threads" answer alike with:
      """
      {}
      """
    And the API GET "/mail/threads/#[One]" and the MCP tool "read_mail_thread" answer alike with:
      """
      {"id": #[One]}
      """
    And the API POST "/mail/threads/bulk/read" and the MCP tool "mark_mail_threads_read" answer alike with:
      """
      {"ids": [#[One]]}
      """
    And the API POST "/mail/threads/bulk/unread" and the MCP tool "mark_mail_threads_unread" answer alike with:
      """
      {"ids": [#[One]]}
      """
    And the API POST "/mail/threads/bulk/untag" and the MCP tool "untag_mail_threads" answer alike with:
      """
      {"ids": [#[One]], "tag": "billing"}
      """
    And the API POST "/mail/threads/bulk/tag" and the MCP tool "tag_mail_threads" answer alike with:
      """
      {"ids": [#[One]], "tag": "billing"}
      """
    And the API POST "/mail/threads/bulk/delete" and the MCP tool "delete_mail_threads" answer alike with:
      """
      {"ids": [#[One]]}
      """
    When I call the MCP mail tool "mark_mail_threads_read" with:
      """
      {"ids": [99]}
      """
    Then the MCP answer says "no mail thread has the ID 99"
