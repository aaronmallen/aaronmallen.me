Feature: Short link MCP tools
  An agent lists, makes and changes short links. Changes need the publish permission, since they show in public.

  Scenario: list_short_links lists each link with its short link, destination and marked title
    Given these short links:
      | code     | destination              | title   | clicks |
      | talk-now | https://example.com/talk | My talk | 3      |
    And I am signed in to the admin
    And an MCP client connected with the scopes "read"
    When I call the MCP tool "list_short_links"
    Then the MCP answer holds:
      """
      {
        "count": 1,
        "short_links": [
          {
            "id": 1, "code": "talk-now", "url": "http://shares.localhost/talk-now",
            "destination": "https://example.com/talk", "title": {"untrusted": true, "text": "My talk"}, "click_count": 3
          }
        ]
      }
      """

  Scenario: list_short_links sorts by clicks and finds words in the destination
    Given these short links:
      | code | destination           | title | clicks |
      | a    | https://example.com/a | Alpha | 1      |
      | b    | https://example.com/b | Beta  | 9      |
      | c    | https://example.org/c | Gamma | 5      |
    And I am signed in to the admin
    And an MCP client connected with the scopes "read"
    When I call the MCP tool "list_short_links" with:
      """
      {"sort": "clicks"}
      """
    Then the MCP answer holds:
      """
      {"short_links": [{"code": "b"}, {"code": "c"}, {"code": "a"}]}
      """
    When I call the MCP tool "list_short_links" with:
      """
      {"query": "example.com"}
      """
    Then the MCP answer holds:
      """
      {"short_links": [{"code": "b"}, {"code": "a"}]}
      """

  Scenario: create_short_link makes a link, or answers with the one a destination already has
    Given these short links:
      | code     | destination              |
      | talk-now | https://example.com/talk |
    And the web answers GET "http://203.0.113.32/new" with:
      """
      <title>New</title>
      """
    And I am signed in to the admin
    And an MCP client connected with the scopes "read publish"
    When I call the MCP tool "create_short_link" with:
      """
      {"destination": " http://203.0.113.32/new "}
      """
    Then the MCP answer holds:
      """
      {"id": 2, "destination": "http://203.0.113.32/new"}
      """
    When I call the MCP tool "create_short_link" with:
      """
      {"destination": "https://example.com/talk"}
      """
    Then the MCP answer holds:
      """
      {"id": 1, "code": "talk-now"}
      """
    And the short_links table holds 2 rows

  Scenario: create_short_link refuses a destination that is not a web address
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read publish"
    When I call the MCP tool "create_short_link" with:
      """
      {"destination": "ftp://example.com"}
      """
    Then the MCP tool refuses with "destination: destination is a web address that starts with http:// or https://"
    And the short_links table holds 0 rows

  Scenario: update_short_link changes only the fields it is given
    Given these short links:
      | code     | destination              | title   |
      | talk-now | https://example.com/talk | My talk |
      | taken    | https://example.com/x    | Other   |
    And I am signed in to the admin
    And an MCP client connected with the scopes "read publish"
    When I call the MCP tool "update_short_link" with:
      """
      {"id": 1, "destination": "https://example.com/v2"}
      """
    Then the MCP answer holds:
      """
      {"destination": "https://example.com/v2", "code": "talk-now", "title": {"untrusted": true, "text": "My talk"}}
      """
    And the MCP answer holds "retargeted_at"
    When I call the MCP tool "update_short_link" with:
      """
      {"id": 1, "code": "talk-later", "title": "Later"}
      """
    Then the MCP answer holds:
      """
      {"code": "talk-later", "url": "http://shares.localhost/talk-later", "title": {"untrusted": true, "text": "Later"}}
      """
    When I call the MCP tool "update_short_link" with:
      """
      {"id": 1, "code": "taken"}
      """
    Then the MCP tool refuses with "code: another share or short link already has this code"
    When I call the MCP tool "update_short_link" with:
      """
      {"id": 999999, "title": "Gone"}
      """
    Then the MCP tool refuses with "no short link has the ID 999999"

  Scenario: Without publish an agent lists links but makes and changes none
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read write delete"
    When I call the MCP tool "list_short_links"
    Then the MCP answer holds:
      """
      {"count": 0}
      """
    When I call the MCP tool "create_short_link"
    Then the MCP call is turned away for want of the "publish" permission
    When I call the MCP tool "update_short_link"
    Then the MCP call is turned away for want of the "publish" permission

  Scenario: Without read an agent cannot list links
    Given I am signed in to the admin
    And an MCP client connected with the scopes "publish"
    When I call the MCP tool "list_short_links"
    Then the MCP call is turned away for want of the "read" permission
