Feature: Text holding a NUL byte
  Postgres cannot hold a NUL byte in text. A search or filter holding one finds nothing, and a saved view
  filter holding one is refused, through the admin, the API and MCP alike.

  Background:
    Given the database runs:
      """
      INSERT INTO tasks (title, note, list, position) VALUES ('Ship the deploy', 'deploy', 'next', 1)
      """

  Scenario: An API search holding a NUL answers 200 with no results
    Given my requests carry an API token
    When I request "/api/v1/search?query=dep%00loy"
    Then it answers 200
    And the JSON answer holds "results" as "[]"

  Scenario: An MCP search holding a NUL answers no results
    Given an MCP client connected with the scopes "read"
    When I call the MCP tool "search" with:
      """
      {"query": "dep\u0000loy"}
      """
    Then the MCP answer holds "results" as "[]"

  Scenario: The admin search screen and palette answer 200 with nothing found for a NUL
    Given I am signed in to the admin
    When I visit "/admin/search?q=dep%00loy"
    Then the page has no ".li-title"
    When I request "/admin/search?q=dep%00loy"
    Then it answers 200
    Given my requests send the header "Accept" as "application/json"
    When I request "/admin/search/palette?q=dep%00loy"
    Then it answers 200
    And the JSON answer holds "hits" as "[]"

  Scenario Outline: The admin tasks, activity and journal screens answer 200 for the filter <query>
    Given I am signed in to the admin
    When I request "/admin/tasks?q=<query>"
    Then it answers 200
    When I visit "/admin/tasks?q=<query>"
    Then I see "No matches in this list."
    When I request "/admin/activity?q=<query>"
    Then it answers 200
    When I request "/admin/journal?q=<query>"
    Then it answers 200

    Examples:
      | query                       |
      | dep%00loy                   |
      | tag%3Adep%00loy             |
      | repo%3Aaaronmallen%2Fbl%00og |

  Scenario: The admin tagging tab answers 200 and no tags for a NUL
    Given I am signed in to the admin
    And the database runs:
      """
      INSERT INTO tags (name, color, scope) VALUES ('deploy', 'mk-blue', 'public')
      """
    When I request "/admin/settings/tagging?q=dep%00loy"
    Then it answers 200
    When I visit "/admin/settings/tagging?q=dep%00loy"
    Then I see "Nothing matches"

  Scenario Outline: A <search> search on a task holding a NUL answers 200 with no matches
    Given I am signed in to the admin
    And the database runs:
      """
      INSERT INTO tasks (title, list, position) VALUES ('Other', 'next', 2)
      """
    When I request the task "Other" with "?<search>_q=dep%00loy"
    Then it answers 200
    When I visit the task "Other" with "?<search>_q=dep%00loy"
    Then I do not see "Ship the deploy"

    Examples:
      | search |
      | link   |
      | record |

  Scenario Outline: An MCP activity read reads the window when <field> holds a NUL
    Given an MCP client connected with the scopes "read"
    When I call the MCP tool "read_activity" for today with:
      """
      {"<field>": <value>}
      """
    Then the MCP answer holds a list at "activity"

    Examples:
      | field | value             |
      | text  | "dep\u0000loy"    |
      | repos | ["bl\u0000og"]    |
      | tags  | ["dep\u0000loy"]  |

  Scenario Outline: A saved view filter with a NUL in <where> is refused by the API, MCP and the admin
    Given my requests carry an API token
    When I post "/api/v1/saved_views" with the "application/json" body:
      """
      {"name": "Deploys", "screen": "<screen>", "filters": <filters>}
      """
    Then it answers 422
    And the JSON answer's "errors" names only "filters"
    Given an MCP client connected with the scopes "read write"
    When I call the MCP tool "create_saved_view" with:
      """
      {"name": "Deploys", "screen": "<screen>", "filters": <filters>}
      """
    Then the MCP tool refuses
    Given I am signed in to the admin
    When I post the form "/admin/saved-views" with my token and the body "screen=<screen>&saved_view%5Bname%5D=Deploys&<form>"
    Then it answers 302
    And the database answers "0" for:
      """
      SELECT count(*) FROM saved_views
      """
    Given the database runs:
      """
      INSERT INTO saved_views (name, screen, filters) VALUES ('Ship', '<screen>', '{"q": "ship"}')
      """
    When I post the form "/admin/saved-views/1/change" with my token and the body "<form>"
    Then the database answers "ship" for:
      """
      SELECT filters->>'q' FROM saved_views WHERE filters = '{"q": "ship"}'
      """

    Examples:
      | where                    | screen   | filters                        | form                            |
      | a value                  | tasks    | {"q": "dep\u0000loy"}          | filters%5Bq%5D=dep%00loy        |
      | an activity type's value | activity | {"types": {"post": "1\u0000"}} | filters%5Btypes%5D%5Bpost%5D=1%00 |
      | an activity type's name  | activity | {"types": {"post\u0000": "1"}} | filters%5Btypes%5D%5Bpost%00%5D=1 |

  Scenario: A saved view PATCH with a new name and a NUL filter answers 422 and changes nothing
    Given the database runs:
      """
      INSERT INTO saved_views (name, screen, filters) VALUES ('Old', 'tasks', '{"q": "ship"}')
      """
    And my requests carry an API token
    When I patch "/api/v1/saved_views/1" with the "application/json" body:
      """
      {"name": "New", "filters": {"q": "dep\u0000loy"}}
      """
    Then it answers 422
    And the JSON answer's "errors" names only "filters"
    And the database answers "Old" for:
      """
      SELECT name FROM saved_views WHERE filters = '{"q": "ship"}'
      """
