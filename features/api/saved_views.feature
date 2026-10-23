Feature: API saved views
  The JSON API and the MCP tools list, save, change and delete the saved views the admin screens keep. A view
  keeps only the filters its screen reads.

  Background:
    Given an API token

  Scenario: The list gives every view by screen and then name, with its ID, name, screen and filters
    Given a saved view "Open" on the tasks screen with the filters:
      """
      {"q": "deploy"}
      """
    And a saved view "Published" on the posts screen
    And a saved view "Drafts" on the posts screen
    When I call the API with "GET /api/v1/saved_views"
    Then the call answers 200
    And the answer's "saved_views" is:
      """
      [
        {"id": 3, "name": "Drafts", "screen": "posts", "filters": {}},
        {"id": 2, "name": "Published", "screen": "posts", "filters": {}},
        {"id": 1, "name": "Open", "screen": "tasks", "filters": {"q": "deploy"}}
      ]
      """

  Scenario: The list narrows to the screen it names
    Given a saved view "Drafts" on the posts screen
    And a saved view "Calm" on the journal screen
    When I call the API with "GET /api/v1/saved_views?screen=journal"
    Then the answer's "saved_views" lists 1
    And the answer's "saved_views.0.id" is "2"

  Scenario: The list leaves out a filter the screen no longer reads
    Given a saved view "Drafts" on the posts screen with the filters:
      """
      {"status": "draft", "tag": "ruby"}
      """
    And a saved view "Calm" on the journal screen with the filters:
      """
      {"mood": "calm"}
      """
    When I call the API with "GET /api/v1/saved_views"
    Then the answer's "saved_views.1.filters" is:
      """
      {"status": "draft"}
      """
    And the answer's "saved_views.0.filters" is:
      """
      {}
      """

  Scenario Outline: The list keeps every filter a <screen> view reads
    Given a saved view "Every filter" on the <screen> screen with the filters:
      """
      <filters>
      """
    When I call the API with "GET /api/v1/saved_views"
    Then the answer's "saved_views.0.filters" is:
      """
      <kept>
      """

    Examples:
      | screen   | filters                                                                                    | kept                                                                         |
      | activity | {"from": "x", "to": "x", "types": {"post": "1"}, "q": "x", "day": "x", "page": "2"}         | {"from": "x", "to": "x", "types": {"post": "1"}, "q": "x", "day": "x"}       |
      | journal  | {"q": "x", "to": "x", "page": "2"}                                                         | {"q": "x", "to": "x"}                                                        |
      | posts    | {"status": "x", "page": "2"}                                                               | {"status": "x"}                                                              |
      | tasks    | {"filter": "x", "pool": "x", "q": "x", "from": "x", "to": "x", "page": "2"}                | {"filter": "x", "pool": "x", "q": "x", "from": "x", "to": "x"}               |

  Scenario: The list answers an empty list with 200
    When I call the API with "GET /api/v1/saved_views"
    Then the call answers 200
    And the answer matches:
      """
      {"saved_views": []}
      """

  Scenario: The list refuses a screen it does not know with a 422
    Then the saved views API refuses "GET /api/v1/saved_views?screen=inbox" on "screen" alone, given:
      """
      {}
      """

  Scenario: Saving a view answers it with a 201
    When I call the API with "POST /api/v1/saved_views" and:
      """
      {"name": "Open deploys", "screen": "tasks", "filters": {"filter": "next", "q": "deploy"}}
      """
    Then the call answers 201
    And the answer matches:
      """
      {"id": 1, "name": "Open deploys", "screen": "tasks", "filters": {"filter": "next", "q": "deploy"}}
      """

  Scenario: Saving keeps the activity types as an object
    When I call the API with "POST /api/v1/saved_views" and:
      """
      {"name": "Posts", "screen": "activity", "filters": {"types": {"post": "1"}}}
      """
    Then the database answers '{"types": {"post": "1"}}' for:
      """
      select filters::text from saved_views
      """

  Scenario: Saving keeps only the filters the screen reads
    When I call the API with "POST /api/v1/saved_views" and:
      """
      {"name": "Drafts", "screen": "posts", "filters": {"status": "draft", "page": "2"}}
      """
    Then the answer's "filters" is:
      """
      {"status": "draft"}
      """

  Scenario: Saving with no filters saves none
    When I call the API with "POST /api/v1/saved_views" and:
      """
      {"name": "Everything", "screen": "journal"}
      """
    Then the answer's "filters" is:
      """
      {}
      """

  Scenario: Saving a blank name answers 422 naming the field and saves nothing
    When I call the API with "POST /api/v1/saved_views" and:
      """
      {"name": "  ", "screen": "tasks"}
      """
    Then the call answers 422
    And the answer matches:
      """
      {
        "error": "invalid",
        "message": "name needs a character that is not a space",
        "errors": {"name": ["name needs a character that is not a space"]}
      }
      """
    And the database answers "0" for:
      """
      select count(*) from saved_views
      """

  Scenario Outline: Saving refuses <what>
    When I call the API with "POST /api/v1/saved_views" and:
      """
      <body>
      """
    Then the call answers 422
    And the answer's "errors" is:
      """
      <errors>
      """

    Examples:
      | what                       | body                                              | errors                                                |
      | a name holding a NUL       | {"name": "bad\u0000name", "screen": "tasks"}      | {"name": ["name holds a control character"]}          |
      | a name holding a bell      | {"name": "bad\u0007name", "screen": "tasks"}      | {"name": ["name holds a control character"]}          |
      | a long name                | {"name": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "screen": "tasks"} | {"name": ["name runs past 100 characters"]} |
      | a view with no screen      | {"name": "Open"}                                  | {"screen": ["screen is missing"]}                     |

  Scenario Outline: Saving refuses <what> on the field it names alone
    Then the saved views API refuses "POST /api/v1/saved_views" on "<field>" alone, given:
      """
      <body>
      """

    Examples:
      | what                                 | body                                                                       | field   |
      | a filter holding a control character | {"name": "Open", "screen": "tasks", "filters": {"q": "sh\u0007ip"}}        | filters |
      | an object for a filter but the types | {"name": "Open", "screen": "tasks", "filters": {"q": {"a": "b"}}}          | filters |
      | a filter that is not text            | {"name": "Open", "screen": "tasks", "filters": {"q": 3}}                   | filters |
      | activity types that are not text     | {"name": "Posts", "screen": "activity", "filters": {"types": {"post": 1}}} | filters |
      | a screen it does not know            | {"name": "Inbox", "screen": "inbox"}                                       | screen  |
      | a view with no name                  | {"screen": "tasks"}                                                        | name    |

  Scenario: Changing the name keeps the filters
    Given a saved view "Old" on the tasks screen with the filters:
      """
      {"q": "deploy"}
      """
    When I call the API with "PATCH /api/v1/saved_views/1" and:
      """
      {"name": "New"}
      """
    Then the call answers 200
    And the answer matches:
      """
      {"id": 1, "name": "New", "screen": "tasks", "filters": {"q": "deploy"}}
      """

  Scenario: Changing the filters replaces them whole and keeps the name
    Given a saved view "Old" on the tasks screen with the filters:
      """
      {"q": "deploy"}
      """
    When I call the API with "PATCH /api/v1/saved_views/1" and:
      """
      {"filters": {"filter": "next"}}
      """
    Then the database answers 'Old, {"filter": "next"}' for:
      """
      select name, filters::text from saved_views
      """

  Scenario: Changing the name and the filters together
    Given a saved view "Old" on the tasks screen with the filters:
      """
      {"q": "deploy"}
      """
    When I call the API with "PATCH /api/v1/saved_views/1" and:
      """
      {"name": "New", "filters": {"pool": "work"}}
      """
    Then the answer matches:
      """
      {"name": "New", "filters": {"pool": "work"}}
      """

  Scenario: Changing the filters to an empty object clears them
    Given a saved view "Old" on the tasks screen with the filters:
      """
      {"q": "deploy"}
      """
    When I call the API with "PATCH /api/v1/saved_views/1" and:
      """
      {"filters": {}}
      """
    Then the answer's "filters" is:
      """
      {}
      """

  Scenario: Changing nothing answers the view as it is
    Given a saved view "Old" on the tasks screen
    When I call the API with "PATCH /api/v1/saved_views/1" and:
      """
      {}
      """
    Then the call answers 200
    And the answer's "name" is "Old"

  Scenario: Changing to a blank name answers 422 and keeps the old one
    Given a saved view "Old" on the tasks screen
    When I call the API with "PATCH /api/v1/saved_views/1" and:
      """
      {"name": " "}
      """
    Then the call answers 422
    And the database answers "Old" for:
      """
      select name from saved_views
      """

  Scenario: A refused change of filters keeps the old name too
    Given a saved view "Old" on the tasks screen with the filters:
      """
      {"q": "deploy"}
      """
    When I call the API with "PATCH /api/v1/saved_views/1" and:
      """
      {"name": "New", "filters": {"q": {"a": "b"}}}
      """
    Then the call answers 422
    And the database answers 'Old, {"q": "deploy"}' for:
      """
      select name, filters::text from saved_views
      """

  Scenario: Changing refuses a field it does not take, such as screen
    Given a saved view "Old" on the tasks screen
    Then the saved views API refuses "PATCH /api/v1/saved_views/1" on "screen" alone, given:
      """
      {"screen": "posts"}
      """

  Scenario: Deleting a view removes it and leaves the others alone
    Given a saved view "Gone" on the tasks screen
    And a saved view "Kept" on the tasks screen
    When I call the API with "DELETE /api/v1/saved_views/1"
    Then the answer matches:
      """
      {"id": 1, "deleted": true}
      """
    And the database answers "2" for:
      """
      select id from saved_views
      """

  Scenario: The database refuses a blank name, a long name and filters that are not an object
    Then the database refuses, breaking a check constraint:
      """
      insert into saved_views (name, screen) values (' ', 'tasks')
      """
    And the database refuses, breaking a check constraint:
      """
      insert into saved_views (name, screen) values (repeat('a', 101), 'tasks')
      """
    And the database refuses, breaking a check constraint:
      """
      insert into saved_views (name, screen, filters) values ('Open', 'tasks', '["q"]')
      """

  Scenario: The MCP tools list, save, change and delete as the endpoints do
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read write delete"
    And a saved view "Posts" on the activity screen with the filters:
      """
      {"types": {"post": "1"}}
      """
    And a saved view "Old" on the tasks screen
    And a saved view "Gone" on the tasks screen
    And a saved view "Also gone" on the tasks screen
    Then the saved views MCP tool "list_saved_views" answers as "GET /api/v1/saved_views?screen=activity" does, given:
      """
      {"screen": "activity"}
      """
    And the saved views MCP tool "create_saved_view" answers as "POST /api/v1/saved_views" does but for the ID, given:
      """
      {"name": "Open", "screen": "tasks", "filters": {"q": "deploy"}}
      """
    And the saved views MCP tool "update_saved_view" answers as "PATCH /api/v1/saved_views/2" does, given:
      """
      {"id": 2, "name": "New", "filters": {"q": "deploy"}}
      """
    And the saved views MCP tool "delete_saved_view" answers as "DELETE /api/v1/saved_views/3" does but for the ID, given:
      """
      {"id": 4}
      """
    And the database answers "1, 2, 5, 6" for:
      """
      select string_agg(id::text, ', ' order by id) from saved_views
      """

  Scenario: The MCP tools refuse with the message the endpoints give
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read write delete"
    Then the saved views MCP tool "create_saved_view" refuses with the message "POST /api/v1/saved_views" gives, given:
      """
      {"name": " ", "screen": "tasks"}
      """
    And the saved views MCP tool "update_saved_view" refuses with the message "PATCH /api/v1/saved_views/999999" gives, given:
      """
      {"id": 999999, "name": "New"}
      """
