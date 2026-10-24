Feature: The tasks in progress
  The palette asks the admin which tasks run now, to offer a complete or a pause on each.

  Scenario: The admin lists the running tasks in list order with the action each posts to
    Given I am signed in to the admin
    And the tasks:
      | title            | sprint | status      | position |
      | Ship the palette | today  | in_progress | 1        |
      | Write the record | today  | in_progress | 2        |
      | Not started      |        | open        | 3        |
      | Done already     |        | done        | 4        |
    When I fetch the admin page "/admin/tasks/in-progress" as JSON
    Then the server answers 200
    And the answer header "Content-Type" is "application/json; charset=utf-8"
    And the answer header "Cache-Control" is "private, no-store"
    And the admin answer is:
      """
      { "rows": [
        { "id": {task:Ship the palette}, "title": "Ship the palette", "href": "/admin/tasks/{task:Ship the palette}/complete" },
        { "id": {task:Write the record}, "title": "Write the record", "href": "/admin/tasks/{task:Write the record}/complete" }
      ] }
      """
    When I fetch the admin page "/admin/tasks/in-progress?act=pause" as JSON
    Then the admin answer holds:
      """
      { "rows": [{ "href": "/admin/tasks/{task:Ship the palette}/stop" }, { "href": "/admin/tasks/{task:Write the record}/stop" }] }
      """
    When I fetch the admin page "/admin/tasks/in-progress?act=delete" as JSON
    Then the admin answer holds:
      """
      { "rows": [{ "href": "/admin/tasks/{task:Ship the palette}/complete" }, { "href": "/admin/tasks/{task:Write the record}/complete" }] }
      """

  Scenario: The admin lists no task when none runs
    Given I am signed in to the admin
    And the tasks:
      | title       |
      | Not started |
    When I fetch the admin page "/admin/tasks/in-progress" as JSON
    Then the admin answer is:
      """
      { "rows": [] }
      """

  Scenario: The tasks in progress answer 401 when I am signed out
    When I fetch the admin page "/admin/tasks/in-progress" as JSON
    Then the server answers 401
    And the answer has no header "Location"
