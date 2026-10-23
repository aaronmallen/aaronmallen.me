Feature: Webmentions over the API and MCP
  The API and the MCP tools list, read and moderate webmentions, one at a time
  or in bulk, and read and change the webmention settings and trusted authors.
  Each MCP tool answers as its endpoint does.

  Background:
    Given a published post "Hello" taking webmentions
    And an API token

  Scenario: The list holds the webmentions received in the range, newest first, with each one's fields
    Given these webmentions on the post "Hello":
      | author_name | status | spam_reason | received_at          | source_url                 | author_url               | excerpt |
      | Older       | spam   | link farm   | 2026-03-02T12:00:00Z | http://203.0.113.7/notes/1 | http://203.0.113.7/about | Hi      |
      | Newer       | spam   | null        | 2026-03-20T12:00:00Z | http://203.0.113.7/notes/2 | http://203.0.113.7/about | Yo      |
      | Outside     | spam   | null        | 2026-04-01T12:00:00Z | http://203.0.113.7/notes/3 | http://203.0.113.7/about | No      |
    When I GET "/webmentions?from=2026-03-01&to=2026-03-31" through the API
    Then the API answers 200
    And the API answer holds:
      """
      {
        "from": "2026-03-01", "to": "2026-03-31", "time_zone": "America/Chicago", "partial": false,
        "counts": {"pending": 0, "approved": 0, "ignored": 0, "spam": 2},
        "webmentions": [
          {"id": 2, "author_name": "Newer"},
          {"id": 1, "post_id": 1, "type": "mention", "status": "spam", "source_url": "http://203.0.113.7/notes/1",
            "author_name": "Older", "author_url": "http://203.0.113.7/about", "excerpt": "Hi",
            "spam_reason": "link farm", "received_at": "2026-03-02T12:00:00Z"}
        ]
      }
      """

  Scenario: The list with no range holds every webmention, newest first
    Given these webmentions on the post "Hello":
      | author_name | received_at          |
      | Older       | 2024-03-02T12:00:00Z |
      | Newer       | 2026-03-20T12:00:00Z |
    When I GET "/webmentions" through the API
    Then the API answer holds:
      """
      {"from": null, "to": null, "webmentions": [{"author_name": "Newer"}, {"author_name": "Older"}]}
      """

  Scenario: The list with no range pages through every webmention in one status
    Given 101 pending webmentions on the post "Hello"
    And these webmentions on the post "Hello":
      | author_name | status |
      | Junk        | spam   |
    When I GET "/webmentions?status=pending&page=2" through the API
    Then the API answer holds:
      """
      {"webmentions": [{"author_name": "Author 101"}]}
      """

  Scenario: The list with only from holds every webmention from that day on
    Given these webmentions on the post "Hello":
      | author_name | received_at          |
      | Before      | 2026-02-28T12:00:00Z |
      | After       | 2026-05-01T12:00:00Z |
    When I GET "/webmentions?from=2026-03-01" through the API
    Then the API answer holds:
      """
      {"webmentions": [{"author_name": "After"}]}
      """

  Scenario: The counts cover the range by status, whatever status is asked for
    Given these webmentions on the post "Hello":
      | status   | received_at          |
      | pending  | 2026-03-02T12:00:00Z |
      | spam     | 2026-03-03T12:00:00Z |
      | spam     | 2026-03-04T12:00:00Z |
      | approved | 2026-04-01T12:00:00Z |
    When I GET "/webmentions?from=2026-03-01&to=2026-03-31&status=pending" through the API
    Then the API answer holds:
      """
      {"counts": {"pending": 1, "approved": 0, "ignored": 0, "spam": 2}}
      """

  Scenario: The list narrows to one post, and to one post and one status, with counts for that post
    Given the posts table holds:
      | title | status    | published_at | webmentions_enabled |
      | Other | published | 1 hour ago   | true                |
      | Quiet | published | 1 hour ago   | true                |
    And these webmentions on the post "Hello":
      | author_name | status   | received_at          |
      | Kept        | approved | 2020-03-02T12:00:00Z |
      | Waiting     | pending  | 2026-03-03T12:00:00Z |
    And these webmentions on the post "Other":
      | author_name | received_at          |
      | Elsewhere   | 2026-03-02T12:00:00Z |
    When I GET "/webmentions?post_id=1" through the API
    Then the API answer holds:
      """
      {"counts": {"pending": 1, "approved": 1, "ignored": 0, "spam": 0},
        "webmentions": [{"author_name": "Waiting"}, {"author_name": "Kept"}]}
      """
    When I GET "/webmentions?post_id=1&status=approved" through the API
    Then the API answer holds:
      """
      {"webmentions": [{"author_name": "Kept"}]}
      """
    When I GET "/webmentions?post_id=3" through the API
    Then the API answer holds:
      """
      {"webmentions": []}
      """

  Scenario: A webmention falls under its Chicago day and gives received_at in UTC
    Given these webmentions on the post "Hello":
      | received_at                    |
      | 2026-03-31T23:30:00-05:00      |
    When I GET "/webmentions?from=2026-03-01&to=2026-03-31" through the API
    Then the API answer holds:
      """
      {"webmentions": [{"received_at": "2026-04-01T04:30:00Z"}]}
      """

  Scenario Outline: The list refuses <what> with a 422
    When I GET "/webmentions?<query>" through the API
    Then the API answers 422
    And the API answer holds "<names>"

    Examples:
      | what                       | query                        | names                |
      | a post_id that is no number | post_id=abc                 | post_id              |
      | a range that runs backwards | from=2026-03-31&to=2026-03-01 | from comes after to |

  Scenario: One webmention reads with its post's title and slug
    Given these webmentions on the post "Hello":
      | author_name | type  |
      | Ada         | reply |
    When I GET "/webmentions/1" through the API
    Then the API answers 200
    And the API answer holds:
      """
      {"id": 1, "author_name": "Ada", "type": "reply", "post_title": "Hello", "post_slug": "hello"}
      """

  Scenario: The MCP tools read webmentions as the endpoints do
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read"
    And these webmentions on the post "Hello":
      | author_name | received_at          | excerpt               |
      | Ada         | 2026-03-02T12:00:00Z | a zeppelin flew past  |
      | Grace       | 2020-03-03T12:00:00Z | Hi                    |
    When I GET "/webmentions?from=2026-03-01&to=2026-03-31&post_id=1" through the API
    Then the MCP tool "list_webmentions" answers the same as the API with:
      """
      {"from": "2026-03-01", "to": "2026-03-31", "post_id": 1}
      """
    When I GET "/webmentions?status=pending" through the API
    Then the MCP tool "list_webmentions" answers the same as the API with:
      """
      {"status": "pending"}
      """
    When I GET "/webmentions/1" through the API
    Then the MCP tool "read_webmention" answers the same as the API with:
      """
      {"id": 1}
      """
    When I call the MCP tool "search" with:
      """
      {"query": "zeppelin"}
      """
    Then the MCP answer holds:
      """
      {"results": [{"kind": "webmention", "id": 1}]}
      """
    When I GET "/webmentions/999999" through the API
    Then the MCP tool "read_webmention" refuses as the API did with:
      """
      {"id": 999999}
      """

  Scenario: A moderation files the webmention under the verdict and keeps the spam note
    Given these webmentions on the post "Hello":
      | author_name |
      | Ada         |
    When I POST "/webmentions/1/moderate" through the API with:
      """
      {"verdict": "spam", "reason": "link farm"}
      """
    Then the API answers 200
    And the API answer holds:
      """
      {"id": 1, "status": "spam"}
      """
    And the webmentions table has a row with:
      | status | spam_reason |
      | spam   | link farm   |

  Scenario: Approving one at a time or in bulk trusts the author
    Given these webmentions on the post "Hello":
      | author_url               |
      | http://203.0.113.7/about |
      | http://203.0.113.8/about |
    When I POST "/webmentions/1/moderate" through the API with:
      """
      {"verdict": "approved"}
      """
    And I POST "/webmentions/bulk/approve" through the API with:
      """
      {"ids": [2]}
      """
    Then the trusted_authors table holds 2 rows

  Scenario: A verdict it does not know is refused with a 422
    Given these webmentions on the post "Hello":
      | author_name |
      | Ada         |
    When I POST "/webmentions/1/moderate" through the API with:
      """
      {"verdict": "pending"}
      """
    Then the API answers 422

  Scenario Outline: A spam verdict on a trusted author <way> needs the delete scope
    Given the trusted author "http://203.0.113.7/"
    And these webmentions on the post "Hello":
      | author_url          |
      | http://203.0.113.7/ |
      | http://203.0.113.8/ |
    And an API token with the scopes "read write"
    When I send POST "<path>" to the webmention API with:
      """
      <body>
      """
    Then the API answers 403
    And the API answer holds "Bearer error=\"insufficient_scope\", scope=\"delete\""
    And the API answer holds "this change removes a trusted author for good, so it needs the delete scope"
    And the trusted_authors table holds 1 rows
    And the webmentions table has no row with:
      | status |
      | spam   |
    Given an API token with the scopes "read write delete"
    When I send POST "<path>" to the webmention API with:
      """
      <body>
      """
    Then the API answers 200
    And the trusted_authors table holds 0 rows

    Examples:
      | way            | path                            | body                 |
      | one at a time  | /api/v1/webmentions/1/moderate  | {"verdict": "spam"}  |
      | in bulk        | /api/v1/webmentions/bulk/spam   | {"ids": [1]}         |

  Scenario Outline: A spam verdict on an author who is not trusted <way> runs with write alone
    Given these webmentions on the post "Hello":
      | author_url          |
      | http://203.0.113.8/ |
    And an API token with the scopes "read write"
    When I send POST "<path>" to the webmention API with:
      """
      <body>
      """
    Then the API answers 200
    And the webmentions table has a row with:
      | status |
      | spam   |

    Examples:
      | way            | path                            | body                 |
      | one at a time  | /api/v1/webmentions/1/moderate  | {"verdict": "spam"}  |
      | in bulk        | /api/v1/webmentions/bulk/spam   | {"ids": [1]}         |

  Scenario: A bulk spam is refused without delete when any one author is trusted, and ignore still runs
    Given the trusted author "http://203.0.113.7/"
    And these webmentions on the post "Hello":
      | author_url          |
      | http://203.0.113.7/ |
      | http://203.0.113.8/ |
    And an API token with the scopes "read write"
    When I send POST "/api/v1/webmentions/bulk/spam" to the webmention API with:
      """
      {"ids": [2, 1]}
      """
    Then the API answers 403
    And the webmentions table has no row with:
      | status |
      | spam   |
    When I send POST "/api/v1/webmentions/1/moderate" to the webmention API with:
      """
      {"verdict": "ignored"}
      """
    Then the API answers 200

  Scenario Outline: Over MCP without delete, <tool> on a trusted author is refused naming delete
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read write"
    And the trusted author "http://203.0.113.7/"
    And these webmentions on the post "Hello":
      | author_url          |
      | http://203.0.113.7/ |
    When I call the MCP tool "<tool>" with:
      """
      <args>
      """
    Then the MCP tool refuses with "this change removes a trusted author for good, so it needs the delete scope"

    Examples:
      | tool                  | args                           |
      | moderate_webmention   | {"id": 1, "verdict": "spam"}   |
      | mark_webmentions_spam | {"ids": [1]}                   |

  Scenario Outline: A bulk <act> changes the webmentions it names, answers them and leaves the rest
    Given these webmentions on the post "Hello":
      | author_name |
      | One         |
      | Two         |
      | Left        |
    When I POST "/webmentions/bulk/<act>" through the API with:
      """
      {"ids": [1, 2]}
      """
    Then the API answers 200
    And the API answer holds:
      """
      {"webmentions": [{"id": 1, "status": "<status>"}, {"id": 2, "status": "<status>"}]}
      """
    And the webmentions table has a row with:
      | author_name | status  |
      | Left        | pending |

    Examples:
      | act     | status   |
      | approve | approved |
      | ignore  | ignored  |
      | spam    | spam     |

  Scenario Outline: A bulk <act> with a gone ID changes none and names it
    Given these webmentions on the post "Hello":
      | author_name |
      | One         |
      | Two         |
    When I POST "/webmentions/bulk/<act>" through the API with:
      """
      {"ids": [1, 2, 99]}
      """
    Then the API answers 422
    And the API answer holds:
      """
      {"error": "invalid", "message": "no webmention has the ID 99", "errors": {"ids": ["no webmention has the ID 99"]}}
      """
    And the webmentions table has no row with:
      | status   |
      | <status> |

    Examples:
      | act     | status   |
      | approve | approved |
      | ignore  | ignored  |
      | spam    | spam     |

  Scenario: A bulk approve on spam clears the spam note, answers every field, and acts on a repeated ID once
    Given these webmentions on the post "Hello":
      | author_name | status | spam_reason | received_at          | source_url                 | author_url               | excerpt |
      | Ada         | spam   | link farm   | 2026-03-01T12:00:00Z | http://203.0.113.7/notes/1 | http://203.0.113.7/about | Hi      |
    When I POST "/webmentions/bulk/approve" through the API with:
      """
      {"ids": [1, 1]}
      """
    Then the API answer holds:
      """
      {"webmentions": [{"id": 1, "post_id": 1, "type": "mention", "status": "approved",
        "source_url": "http://203.0.113.7/notes/1", "author_name": "Ada", "author_url": "http://203.0.113.7/about",
        "excerpt": "Hi", "spam_reason": null, "received_at": "2026-03-01T12:00:00Z"}]}
      """

  Scenario Outline: A bulk request refuses <what>
    When I send POST "/api/v1/webmentions/bulk/approve" to the webmention API with:
      """
      <body>
      """
    Then the API answers 422
    And the API answer holds "<error>"

    Examples:
      | what                     | body                    | error          |
      | an empty list            | {"ids": []}             | ids            |
      | more than 100 IDs        | {"ids": "{ids:1..101}"} | ids            |
      | an ID that is no number  | {"ids": ["one"]}        | ids            |
      | a request with no IDs    | {}                      | ids is missing |

  Scenario Outline: The MCP tool <tool> acts as POST /api/v1/webmentions/bulk/<act> does
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read write publish delete"
    And these webmentions on the post "Hello":
      | author_name | author_url             | excerpt | received_at          |
      | Ada         | http://203.0.113.7/    | Hi      | 2026-03-01T12:00:00Z |
      | Ada         | http://203.0.113.7/    | Hi      | 2026-03-01T12:00:00Z |
    When I POST "/webmentions/bulk/<act>" through the API with:
      """
      {"ids": [1]}
      """
    And I call the MCP tool "<tool>" with:
      """
      {"ids": [2]}
      """
    Then the MCP answer holds:
      """
      {"webmentions": [{"id": 2, "status": "<status>", "author_name": {"untrusted": true, "text": "Ada"},
        "excerpt": {"untrusted": true, "text": "Hi"}, "received_at": "2026-03-01T12:00:00Z"}]}
      """

    Examples:
      | act     | tool                  | status   |
      | approve | approve_webmentions   | approved |
      | ignore  | ignore_webmentions    | ignored  |
      | spam    | mark_webmentions_spam | spam     |

  Scenario: The MCP bulk tool refuses a gone ID with the endpoint's message
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read write publish"
    When I POST "/webmentions/bulk/approve" through the API with:
      """
      {"ids": [99]}
      """
    Then the MCP tool "approve_webmentions" refuses as the API did with:
      """
      {"ids": [99]}
      """

  Scenario: The settings read with a 200, as read_webmention_settings does
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read"
    When I GET "/webmention_settings" through the API
    Then the API answers 200
    And the API answer holds:
      """
      {"accept_bridgy": true, "auto_approve_known_authors": true, "auto_approve_likes": true,
        "auto_approve_reposts": true, "enable_on_new_posts": true, "receive": true, "send_on_publish": true,
        "single_author_hosts": []}
      """
    And the MCP tool "read_webmention_settings" answers the same as the API with:
      """
      {}
      """

  Scenario: A settings change changes what it names, keeps the rest and cleans up the hosts
    When I PATCH "/webmention_settings" through the API with:
      """
      {"receive": false, "auto_approve_likes": false, "auto_approve_reposts": false,
        "single_author_hosts": ["grace.example", "https://Ada.Example/"]}
      """
    Then the API answers 200
    And the API answer holds:
      """
      {"receive": false, "send_on_publish": true, "auto_approve_likes": false, "auto_approve_reposts": false,
        "single_author_hosts": ["ada.example", "grace.example"]}
      """

  Scenario: A settings change that changes nothing is refused with a 422
    When I PATCH "/webmention_settings" through the API with:
      """
      {"receive": true}
      """
    Then the API answers 422
    And the API answer holds:
      """
      {"message": "nothing saved, since no setting changed"}
      """

  Scenario: The trusted authors list as list_trusted_authors does, and one is removed under any case
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read"
    And the trusted author "https://ada.example/"
    When I GET "/trusted_authors" through the API
    Then the API answer holds:
      """
      {"trusted_authors": [{"author_url": "https://ada.example/"}]}
      """
    And the MCP tool "list_trusted_authors" answers the same as the API with:
      """
      {}
      """
    When I POST "/trusted_authors/remove" through the API with:
      """
      {"author_url": "https://ADA.example"}
      """
    Then the API answers 200
    And the API answer holds:
      """
      {"author_url": "https://ada.example/", "removed": true}
      """
    And the trusted_authors table holds 0 rows

  Scenario: Removing an author not on the list answers 404
    When I POST "/trusted_authors/remove" through the API with:
      """
      {"author_url": "https://grace.example/"}
      """
    Then the API answers 404
    And the API answer holds:
      """
      {"message": "no trusted author has the URL https://grace.example/"}
      """

  Scenario: Removing an author needs the delete scope
    Given the trusted author "https://ada.example/"
    And an API token with the scopes "read write publish"
    When I POST "/trusted_authors/remove" through the API with:
      """
      {"author_url": "https://ada.example/"}
      """
    Then the API answers 403
