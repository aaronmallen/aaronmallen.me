Feature: The MCP task tools
  The task tools list, capture, stage, start, pause and recur tasks, and refuse what they cannot do.

  Background:
    Given an MCP client connected with the scopes "read write publish delete"

  Scenario: list_tasks narrows by sprint day, contributor and label, and refuses a list it does not know
    Given the projects:
      | name    | key |
      | Podcast | POD |
    And the tasks:
      | title            | sprint    | project |
      | planned          | today + 2 |         |
      | Mow the lawn     |           |         |
      | Record the intro |           | Podcast |
    And the task contributors:
      | task             | agent       | model           |
      | Record the intro | claude-code | claude-opus-5-5 |
    When I call the MCP tool "list_tasks" with:
      """
      { "sprint_on": "{day:today + 2}" }
      """
    Then the MCP answer holds:
      """
      { "total": 1, "tasks": [{ "id": 1 }] }
      """
    When I call the MCP tool "list_tasks" with:
      """
      { "contributor": "owner" }
      """
    Then the MCP answer holds:
      """
      { "total": 2, "tasks": [{ "id": 2 }, { "id": 1 }] }
      """
    When I call the MCP tool "list_tasks" with:
      """
      { "query": "POD-1" }
      """
    Then the MCP answer holds:
      """
      { "total": 1, "tasks": [{ "id": 3 }] }
      """
    When I call the MCP tool "list_tasks" with:
      """
      { "query": "Mo\u0000w the lawn" }
      """
    Then the MCP answer holds:
      """
      { "total": 1, "tasks": [{ "id": 2 }] }
      """
    When I call the MCP tool "list_tasks" with:
      """
      { "lists": ["nowhere"] }
      """
    Then the MCP call is refused

  Scenario: A column change puts the task first
    Given the tasks:
      | title    | status      | position |
      | running  | in_progress | 1        |
      | staged   | open        | 2        |
      | paused   | in_progress | 3        |
      | started  | open        | 4        |
      | kept     | in_progress | 5        |
      | backlog  | open        | 6        |
    When I call the MCP tool "stage_task" with:
      """
      { "id": {task:staged}, "stage": "ready" }
      """
    Then the first task in order is "staged"
    When I call the MCP tool "pause_task" with:
      """
      { "id": {task:paused} }
      """
    Then the first task in order is "paused"
    When I call the MCP tool "start_task" with:
      """
      { "id": {task:started} }
      """
    Then the first task in order is "started"
    When I call the MCP tool "start_task" with:
      """
      { "id": {task:kept} }
      """
    And I call the MCP tool "stage_task" with:
      """
      { "id": {task:backlog}, "stage": "backlog" }
      """
    Then the first task in order is "started"

  Scenario: capture_task stores the note, claims its photo and numbers the task in its project
    Given the photo "0123456789abcdef0123456789abcdef.jpg" uploaded 1 days ago
    And the projects:
      | name    | key |
      | Podcast | POD |
    When I call the MCP tool "capture_task" with:
      """
      { "title": "Fix the gutter", "note": "![The gutter](/media/0123456789abcdef0123456789abcdef.jpg)" }
      """
    Then the MCP answer holds:
      """
      { "id": 1, "note": { "untrusted": true, "text": "![The gutter](/media/0123456789abcdef0123456789abcdef.jpg)" } }
      """
    And the database answers "task, 1, 1" for:
      """
      SELECT owner, owner_id, photo_id FROM photo_claims
      """
    When I call the MCP tool "capture_task" with:
      """
      { "title": "Record the intro", "project": "POD" }
      """
    Then the MCP answer holds:
      """
      { "label": "POD-1" }
      """
    When I call the MCP tool "capture_task" with:
      """
      { "title": "Record the outro", "project": "NOPE" }
      """
    Then the MCP call is refused
    And the database holds 2 tasks rows

  Scenario Outline: <tool> refuses a task that is not there
    When I call the MCP tool "<tool>" with:
      """
      { "id": 999999 }
      """
    Then the MCP tool refuses with "no task has the ID 999999"

    Examples:
      | tool          |
      | start_task    |
      | complete_task |
      | reopen_task   |
      | cancel_task   |
      | delete_task   |

  Scenario: The task tools set, show, change and clear a cadence
    Given the tasks:
      | title  | list     |
      | Rent   | next     |
      | Issue  | external |
    And the task sources:
      | task  | url                                                    |
      | Issue | https://github.com/aaronmallen/aaronmallen.me/issues/5 |
    When I call the MCP tool "capture_task" with:
      """
      { "title": "Pay rent", "recur": { "cadence": "month_day", "day": 1 } }
      """
    Then the MCP answer holds:
      """
      { "recur": { "cadence": "month_day", "day": 1, "paused": false } }
      """
    When I call the MCP tool "save_task" with:
      """
      { "id": {task:Rent}, "recur": { "cadence": "days", "every": 4 } }
      """
    And I call the MCP tool "read_task" with:
      """
      { "id": {task:Rent} }
      """
    Then the MCP answer holds:
      """
      { "recur": { "cadence": "days", "every": 4 } }
      """
    When I call the MCP tool "save_task" with:
      """
      { "id": {task:Rent}, "recur": { "cadence": "yearly", "month": 3, "day": 14 } }
      """
    Then the MCP answer holds:
      """
      { "recur": { "cadence": "yearly", "month": 3, "day": 14 } }
      """
    When I call the MCP tool "save_task" with:
      """
      { "id": {task:Rent}, "recur": null }
      """
    Then the MCP answer holds:
      """
      { "recur": null }
      """
    And the database holds 1 task_series row
    When I call the MCP tool "save_task" with:
      """
      { "id": {task:Issue}, "recur": { "cadence": "month_end" } }
      """
    Then the MCP call is refused
    And the database holds 1 task_series row

  Scenario: The series tools list, pause and resume a series
    Given a task "Water the plants"
    And I call the MCP tool "save_task" with:
      """
      { "id": {task:Water the plants}, "recur": { "cadence": "days", "every": 2 } }
      """
    When I call the MCP tool "list_task_series" with:
      """
      {}
      """
    Then the MCP answer holds:
      """
      { "task_series": [{ "id": 1, "task": { "id": 1 } }] }
      """
    When I call the MCP tool "pause_task_series" with:
      """
      { "id": 1 }
      """
    Then the MCP answer holds:
      """
      { "paused": true }
      """
    When I call the MCP tool "resume_task_series" with:
      """
      { "id": 1 }
      """
    Then the MCP answer holds:
      """
      { "paused": false }
      """
