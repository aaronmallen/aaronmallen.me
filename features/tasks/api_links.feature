Feature: Task links through the API
  The API links two tasks, reads each link from either end and removes a link from whichever end.

  Background:
    Given an API token
    And the tasks:
      | title   |
      | Ship    |
      | Migrate |
      | Other   |

  Scenario: Linking two tasks stores the link by hand and reads it from either end
    Then the API calls answer:
      | call                         | body                                         | status | holds |
      | POST /tasks/{task:Ship}/links | {"kind": "relates", "other_id": {task:Migrate}} | 201 | {"links": [{"label": "relates", "id": 2, "task_label": "2", "title": "Migrate", "status": "open"}]} |
      | POST /tasks/{task:Ship}/links | {"kind": "blocked_by", "other_id": {task:Other}} | 201 | {"links": [{"label": "blocked_by", "id": 3}, {"label": "relates", "id": 2}]} |
      | GET /tasks/{task:Other}       |                                              | 200    | {"links": [{"label": "blocks", "id": 1}]} |
    And the database reads "false / false" for:
      """
      SELECT synced FROM task_links ORDER BY id
      """
    And the API answer has "links.length" as "1"

  Scenario: Linking refuses a link it cannot store
    Given the task "Migrate" relates to the task "Other"
    Then the API calls answer:
      | call                           | body                                              | status | holds |
      | POST /tasks/{task:Ship}/links   | {"kind": "relates", "other_id": {task:Ship}}      | 422    | {"errors": {"other_id": ["a task cannot link to itself"]}} |
      | POST /tasks/{task:Other}/links  | {"kind": "relates", "other_id": {task:Migrate}}   | 422    | {"message": "other_id: these two tasks are already linked"} |
      | POST /tasks/{task:Ship}/links   | {"kind": "relates", "other_id": 999999}           | 422    | {"errors": {"other_id": ["that task is gone, so find another"]}} |
      | POST /tasks/{task:Ship}/links   | {"kind": "relates", "other_id": 2147483648}       | 422    | {"errors": {"other_id": ["number at `/other_id` is greater than: 2147483647"]}} |
      | POST /tasks/{task:Ship}/links   | {"kind": "parent", "other_id": {task:Migrate}}    | 422    | "kind" |
      | POST /tasks/{task:Ship}/links   | {"kind": "follows", "other_id": {task:Migrate}}   | 422    | "kind" |
      | POST /tasks/{task:Ship}/links   | {"kind": "relates"}                               | 422    | {"errors": {"other_id": ["other_id is missing"]}} |
      | POST /tasks/999999/links        | {"kind": "relates", "other_id": {task:Migrate}}   | 404    | {"message": "no task has the ID 999999"} |
    And the database holds 1 task_links row

  Scenario: Unlinking removes the link from whichever end
    Given the task "Migrate" blocks the task "Ship"
    Then the API calls answer:
      | call                              | body | status | holds |
      | DELETE /tasks/{task:Ship}/links/{task:Migrate} | | 200 | {"links": []} |
      | DELETE /tasks/{task:Ship}/links/{task:Migrate} | | 404 | {"message": "task 1 has no link to task 2"} |

  Scenario: A parent link reads parent_of on the parent and child_of on the child, over MCP too
    Given the task "Ship" is the parent of the task "Migrate"
    And an MCP client connected with the scopes "read"
    Then the API calls answer:
      | call                     | body | status | holds |
      | GET /tasks/{task:Ship}    |      | 200    | {"links": [{"label": "parent_of", "id": 2}]} |
      | GET /tasks/{task:Migrate} |      | 200    | {"links": [{"label": "child_of", "id": 1}]} |
    And the API answer to GET "/tasks/{task:Migrate}" matches the MCP tool "read_task" with:
      """
      { "id": {task:Migrate} }
      """

  Scenario: The link tools answer as the link endpoints do
    Given an MCP client connected with the scopes "read write"
    When I POST "/tasks/{task:Ship}/links" through the API with:
      """
      { "kind": "blocks", "other_id": {task:Migrate} }
      """
    And I keep the API answer
    And I DELETE "/tasks/{task:Ship}/links/{task:Migrate}" through the API
    And I take back the kept API answer
    Then the MCP tool "link_tasks" answers as the API did, apart from "updated_at", with:
      """
      { "id": {task:Ship}, "kind": "blocks", "other_id": {task:Migrate} }
      """
    When I DELETE "/tasks/{task:Ship}/links/{task:Migrate}" through the API
    And I keep the API answer
    And the task "Ship" blocks the task "Migrate"
    And I take back the kept API answer
    Then the MCP tool "unlink_task" answers as the API did, apart from "updated_at", with:
      """
      { "id": {task:Ship}, "other_id": {task:Migrate} }
      """
    When I POST "/tasks/{task:Ship}/links" through the API with:
      """
      { "kind": "relates", "other_id": {task:Ship} }
      """
    Then the MCP tool "link_tasks" answers as the API did, apart from "", with:
      """
      { "id": {task:Ship}, "kind": "relates", "other_id": {task:Ship} }
      """
