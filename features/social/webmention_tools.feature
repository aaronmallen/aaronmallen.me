Feature: Webmention tools for MCP clients
  An MCP client moderates webmentions, reads and changes the webmention settings and keeps the trusted authors.

  Background:
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read write publish delete"
    And the posts table holds:
      | title   | status    | published_at |
      | Engines | published | 1 day ago    |
    And the webmentions table holds:
      | post_id | source_url               | author_name  | author_url             | type  | status  |
      | 1       | https://ada.example/post | Ada Lovelace | https://ada.example/   | reply | pending |

  Scenario: Marking spam stores the reason given
    When I call the MCP tool "moderate_webmention" with:
      """
      {"id": 1, "verdict": "spam", "reason": "link farm"}
      """
    Then the MCP answer holds:
      """
      {"id": 1, "status": "spam"}
      """
    And the webmentions table has a row with:
      | id | status | spam_reason |
      | 1  | spam   | link farm   |

  Scenario Outline: Approving a webmention trusts its author
    When I call the MCP tool "<tool>" with:
      """
      <arguments>
      """
    Then the trusted_authors table has a row with:
      | author_url           |
      | https://ada.example/ |

    Examples:
      | tool                | arguments                           |
      | moderate_webmention | {"id": 1, "verdict": "approved"}    |
      | approve_webmentions | {"ids": [1]}                        |

  Scenario: A verdict it does not know changes nothing, and an unknown ID is refused
    When I call the MCP tool "moderate_webmention" with:
      """
      {"id": 1, "verdict": "pending"}
      """
    Then the webmentions table has a row with:
      | id | status  |
      | 1  | pending |
    When I call the MCP tool "moderate_webmention" with:
      """
      {"id": 999999, "verdict": "spam"}
      """
    Then the MCP tool refuses with "no webmention has the ID 999999"

  Scenario: Reading the settings gives every setting
    When I call the MCP tool "read_webmention_settings"
    Then the MCP answer holds:
      """
      {
        "accept_bridgy": true, "auto_approve_known_authors": true, "auto_approve_likes": true,
        "auto_approve_reposts": true, "enable_on_new_posts": true, "receive": true, "send_on_publish": true,
        "single_author_hosts": []
      }
      """

  Scenario: Updating changes the settings it was given, keeps the rest and answers with every one
    When I call the MCP tool "update_webmention_settings" with:
      """
      {"receive": false, "auto_approve_likes": false, "auto_approve_reposts": false}
      """
    Then the MCP answer holds:
      """
      {"receive": false, "auto_approve_likes": false, "auto_approve_reposts": false, "send_on_publish": true, "accept_bridgy": true}
      """
    And the webmention_settings table has a row with:
      | receive | send_on_publish | auto_approve_likes | auto_approve_reposts |
      | false   | true            | false              | false                |

  Scenario: Updating saves the hosts cleaned up and in order
    When I call the MCP tool "update_webmention_settings" with:
      """
      {"single_author_hosts": ["grace.example", "https://Ada.Example/", "a b"]}
      """
    Then the MCP answer holds:
      """
      {"single_author_hosts": ["ada.example", "grace.example"]}
      """
    When I call the MCP tool "update_webmention_settings" with:
      """
      {"single_author_hosts": ["ada.example", "grace.example"]}
      """
    Then the MCP tool refuses with "nothing saved, since no setting changed"

  Scenario: Updating with nothing new saves nothing and says so
    When I call the MCP tool "update_webmention_settings" with:
      """
      {"receive": true}
      """
    Then the MCP tool refuses with "nothing saved, since no setting changed"

  Scenario: Trusted authors list newest first with the URL marked untrusted
    Given the trusted_authors table holds:
      | author_url               | created_at    |
      | https://ada.example/     | 1 minute ago  |
      | https://grace.example/   | now           |
    When I call the MCP tool "list_trusted_authors"
    Then the MCP answer holds:
      """
      {"trusted_authors": [
        {"author_url": {"untrusted": true, "text": "https://grace.example/"}},
        {"author_url": {"untrusted": true, "text": "https://ada.example/"}}
      ]}
      """

  Scenario: Removing a trusted author keeps their approved webmentions approved
    Given the trusted_authors table holds:
      | author_url           |
      | https://ada.example/ |
    And the webmentions table holds:
      | post_id | source_url                | author_url           | type  | status   |
      | 1       | https://ada.example/other | https://ada.example/ | reply | approved |
    When I call the MCP tool "remove_trusted_author" with:
      """
      {"author_url": "https://ada.example/"}
      """
    Then the trusted_authors table holds 0 rows
    And the webmentions table has a row with:
      | id | status   |
      | 2  | approved |
    When I call the MCP tool "remove_trusted_author" with:
      """
      {"author_url": "https://grace.example/"}
      """
    Then the MCP tool refuses with "no trusted author has the URL https://grace.example/"
