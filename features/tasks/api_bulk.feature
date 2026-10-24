Feature: Bulk task actions through the API
  POST /api/v1/tasks/bulk/:action completes, cancels, deletes, moves, tags and untags many tasks at once, and
  changes none when one of them cannot change.

  Background:
    Given an API token
    And the projects:
      | name    | key |
      | Podcast | POD |

  Scenario Outline: A bulk <action> changes the tasks it names, by ID or label, and leaves the rest
    Given the tasks:
      | title    | project |
      | one      |         |
      | two      |         |
      | left     |         |
      | labelled | Podcast |
    Then the API calls answer:
      | call                      | body                                   | status | holds |
      | POST /tasks/bulk/<action> | {"ids": [1, 2, "POD-9"]}               | 422    | {"error": "invalid", "message": "no task has the label POD-9", "errors": {"ids": ["no task has the label POD-9"]}} |
      | POST /tasks/bulk/<action> | {"ids": ["POD-8", 1, "POD-9"]}         | 422    | {"message": "no task has the label POD-8"} |
      | POST /tasks/bulk/<action> | {"ids": [1, 2, 999]}                   | 422    | {"message": "no task has the ID 999", "errors": {"ids": ["no task has the ID 999"]}} |
    And the database reads "open / open / open / open" for:
      """
      SELECT status FROM tasks ORDER BY id
      """
    And the API calls answer:
      | call                      | body                    | status | holds |
      | POST /tasks/bulk/<action> | {"ids": [1, "POD-1"]}   | 200    | {"tasks": [{"id": 1, "label": "1", "status": "<status>"}, {"id": 4, "label": "POD-1", "status": "<status>"}]} |
      | POST /tasks/bulk/<action> | {"ids": [2]}            | 200    | {"tasks": [{"id": 2, "status": "<status>"}]} |
    And the database reads "open" for:
      """
      SELECT status FROM tasks WHERE title = 'left'
      """

    Examples:
      | action   | status   |
      | complete | done     |
      | cancel   | canceled |

  Scenario: A bulk close changes none when one task is closed already
    Given the tasks with their times:
      | title    | status   | closed      |
      | open     | open     |             |
      | finished | done     | today 08:00 |
      | dropped  | canceled | today 08:00 |
    Then the API calls answer:
      | call                     | body             | status | holds |
      | POST /tasks/bulk/cancel   | {"ids": [1, 2]}  | 422    | {"errors": {"ids": ["task 2 is already done or canceled"]}} |
      | POST /tasks/bulk/complete | {"ids": [1, 3]}  | 422    | {"errors": {"ids": ["task 3 is already done or canceled"]}} |
      | POST /tasks/bulk/complete | {"ids": [1, 2]}  | 422    | {"errors": {"ids": ["task 2 is already done or canceled"]}} |
    And the database reads "open,  / done, true / canceled, true" for:
      """
      SELECT status, completed_at = '{at:today 08:00}' FROM tasks ORDER BY id
      """

  Scenario: A bulk delete removes the tasks it names and leaves the rest
    Given the tasks:
      | title |
      | One   |
      | Two   |
      | left  |
    Then the API calls answer:
      | call                   | body                  | status | holds |
      | POST /tasks/bulk/delete | {"ids": [1, 2, 999]} | 422    | |
    And the database holds 3 tasks rows
    And the API calls answer:
      | call                   | body             | status | holds |
      | POST /tasks/bulk/delete | {"ids": [1, 2]} | 200    | {"tasks": [{"id": 1, "title": "One", "deleted": true}, {"id": 2, "title": "Two", "deleted": true}]} |
    And the database reads "left" for:
      """
      SELECT title FROM tasks
      """

  Scenario: A bulk move sends the tasks to a list or today's sprint
    Given the tasks:
      | title |
      | one   |
      | two   |
    Then the API calls answer:
      | call                 | body                                  | status | holds |
      | POST /tasks/bulk/move | {"ids": [1, 2, 999], "list": "someday"} | 422  | |
      | POST /tasks/bulk/move | {"ids": [1, 2], "list": "nowhere"}    | 422    | "list" |
      | POST /tasks/bulk/move | {"ids": [1, 2]}                       | 422    | {"errors": {"list": ["list is missing"]}} |
    And the database reads "next / next" for:
      """
      SELECT list FROM tasks ORDER BY id
      """
    And the API calls answer:
      | call                 | body                                | status | holds |
      | POST /tasks/bulk/move | {"ids": [1, 2], "list": "someday"}  | 200    | {"tasks": [{"list": "someday"}, {"list": "someday"}]} |
    And the database reads "someday / someday" for:
      """
      SELECT list FROM tasks ORDER BY id
      """
    And the API calls answer:
      | call                 | body                              | status | holds |
      | POST /tasks/bulk/move | {"ids": [1, 2], "list": "today"}  | 200    | {"tasks": [{"sprint_on": "{day:today}"}, {"sprint_on": "{day:today}"}]} |

  Scenario: A bulk tag and untag add and take off one tag
    Given the tasks:
      | title  | tags       |
      | ruby   | ruby       |
      | bare   |            |
      | rails  | rails ruby |
    Then the API calls answer:
      | call                  | body                                   | status | holds |
      | POST /tasks/bulk/tag   | {"ids": [1, 2, 999], "tag": "release"} | 422    | |
      | POST /tasks/bulk/untag | {"ids": [1, 3, 999], "tag": "ruby"}    | 422    | |
      | POST /tasks/bulk/tag   | {"ids": [1, 2], "tag": "two words"}    | 422    | {"errors": {"tag": ["a tag is lowercase words joined by hyphens"]}} |
      | POST /tasks/bulk/tag   | {"ids": [1, 2], "tag": " "}            | 422    | {"message": "tag: name the tag first"} |
    And the database reads "1, ruby / 3, rails / 3, ruby" for:
      """
      SELECT task_id, name FROM task_tags JOIN tags ON tags.id = tag_id ORDER BY task_id, name
      """
    And the API calls answer:
      | call                  | body                              | status | holds |
      | POST /tasks/bulk/tag   | {"ids": [1, 2], "tag": "Release"} | 200    | {"tasks": [{"tags": ["release", "ruby"]}, {"tags": ["release"]}]} |
      | POST /tasks/bulk/untag | {"ids": [3, 1], "tag": "ruby"}    | 200    | {"tasks": [{"tags": ["rails"]}, {"tags": ["release"]}]} |

  Scenario: The list of IDs acts on each task once, in the order given, and refuses a bad list
    Given the tasks:
      | title |
      | one   |
      | two   |
      | three |
    Then the API calls answer:
      | call                     | body                  | status | holds |
      | POST /tasks/bulk/complete | {"ids": []}          | 422    | "ids" |
      | POST /tasks/bulk/complete | {"ids": ["one"]}     | 422    | "ids" |
      | POST /tasks/bulk/complete | {}                   | 422    | {"errors": {"ids": ["ids is missing"]}} |
      | POST /tasks/bulk/complete | {"ids": [3, 1, 2]}   | 200    | {"tasks": [{"id": 3}, {"id": 1}, {"id": 2}]} |
    And a bulk complete of 101 IDs gets a 422 naming "ids"
    Given a task "again"
    When I POST "/tasks/bulk/complete" through the API with:
      """
      { "ids": [4, 4] }
      """
    Then the API answer holds:
      """
      { "tasks": [{ "id": 4 }] }
      """

  Scenario: The bulk task tools answer as the bulk endpoints do
    Given the tasks:
      | title | tags        |
      | same  |             |
      | same  |             |
      | same  |             |
      | same  |             |
      | tags  | rails ruby  |
      | tags  | rails ruby  |
      | move  |             |
    And an MCP client connected with the scopes "read write delete"
    When I POST "/tasks/bulk/complete" through the API with:
      """
      { "ids": [1] }
      """
    Then the MCP tool "complete_tasks" answers as the API did, apart from "id, label, number, position, completed_at, created_at, updated_at", with:
      """
      { "ids": [2] }
      """
    When I POST "/tasks/bulk/cancel" through the API with:
      """
      { "ids": [3] }
      """
    Then the MCP tool "cancel_tasks" answers as the API did, apart from "id, label, number, position, completed_at, created_at, updated_at", with:
      """
      { "ids": [4] }
      """
    When I POST "/tasks/bulk/untag" through the API with:
      """
      { "ids": [5], "tag": "ruby" }
      """
    Then the MCP tool "untag_tasks" answers as the API did, apart from "id, label, number, position, created_at, updated_at", with:
      """
      { "ids": [6], "tag": "ruby" }
      """
    When I POST "/tasks/bulk/move" through the API with:
      """
      { "ids": [7], "list": "external" }
      """
    Then the MCP tool "move_tasks" answers as the API did, apart from "updated_at", with:
      """
      { "ids": [7], "list": "external" }
      """
    When I POST "/tasks/bulk/tag" through the API with:
      """
      { "ids": [7], "tag": "ruby" }
      """
    Then the MCP tool "tag_tasks" answers as the API did, apart from "updated_at", with:
      """
      { "ids": [7], "tag": "ruby" }
      """
    When I POST "/tasks/bulk/delete" through the API with:
      """
      { "ids": [1] }
      """
    Then the MCP tool "delete_tasks" answers as the API did, apart from "id", with:
      """
      { "ids": [2] }
      """
    When I POST "/tasks/bulk/complete" through the API with:
      """
      { "ids": [999] }
      """
    Then the MCP tool "complete_tasks" answers as the API did, apart from "", with:
      """
      { "ids": [999] }
      """
