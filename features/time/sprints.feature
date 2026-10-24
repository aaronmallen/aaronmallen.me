Feature: Sprints
  Each day has a sprint. The roll over starts it and carries in the unfinished tasks, and the API and MCP tools read,
  list, plan and drop sprints.

  Background:
    Given an API token

  Scenario: The roll over starts today's sprint once and carries in what is unfinished
    Given the tasks:
      | title        | sprint    | status      |
      | Unfinished   | today - 1 | open        |
      | Running      | today - 1 | in_progress |
      | Finished     | today - 1 | done        |
      | Dropped      | today - 1 | canceled    |
    And the database runs:
      """
      INSERT INTO work_sessions (task_id, started_at) VALUES ({task:Running}, date_trunc('second', now()) - interval '90 minutes')
      """
    When the sprint roll over runs
    And the sprint roll over runs
    Then the database soon holds "1, 2" for:
      """
      SELECT count(*) AS sprints, max(carried_in) AS carried FROM sprints WHERE sprint_date = '{day:today}'
      """
    And the database soon holds "Dropped {day:today - 1} | Finished {day:today - 1} | Running {day:today} | Unfinished {day:today}" for:
      """
      SELECT string_agg(title || ' ' || sprint_date, ' | ' ORDER BY title) FROM tasks JOIN sprints ON sprints.id = sprint_id
      """
    And the database soon holds "in_progress, 2, 1, true" for:
      """
      SELECT status, count(*) AS sessions, count(*) FILTER (WHERE ended_at IS NULL) AS running,
        max(ended_at) = max(started_at) AS joined
      FROM tasks JOIN work_sessions ON task_id = tasks.id WHERE title = 'Running' GROUP BY status
      """
    And the database soon holds "Running moved {day:today - 1} {day:today} | Unfinished moved {day:today - 1} {day:today}" for:
      """
      SELECT string_agg(title || ' ' || kind || ' ' || from_sprint_on || ' ' || to_sprint_on, ' | ' ORDER BY title)
      FROM task_events JOIN tasks ON tasks.id = task_id
      """

  Scenario: Two reads at once both roll today's sprint and move the carried task once
    Given the sprints:
      | day   |
      | today |
    And the tasks:
      | title   | sprint    | status      |
      | Carried | today - 1 | in_progress |
    And the database runs:
      """
      INSERT INTO work_sessions (task_id, started_at) VALUES ({task:Carried}, now() - interval '1 minute')
      """
    When two reads of the current sprint wait on another session's sprint lock, then run
    Then the database soon holds "1" for:
      """
      SELECT count(*) FROM task_events WHERE kind = 'moved' AND task_id = {task:Carried}
      """

  Scenario: Reading the current sprint answers today's with its tasks, as read_current_sprint does
    Given an MCP client connected with the scopes "read"
    And the sprints:
      | day   | carried_in |
      | today | 2          |
    And the tasks:
      | title        | sprint |
      | today's work | today  |
    When I GET "/sprints/current" through the API
    Then the API answers 200
    And the API answer holds:
      """
      {"id": {sprint:today}, "date": "{day:today}", "carried_in": 2,
        "tasks": [{"title": "today's work", "sprint_on": "{day:today}"}]}
      """
    And the API answer to GET "/sprints/current" matches the MCP tool "read_current_sprint" with:
      """
      {}
      """

  Scenario: Reading the current sprint starts it when there is none
    When I GET "/sprints/current" through the API
    Then the API answers 200
    And the database soon holds "1" for:
      """
      SELECT count(*) FROM sprints WHERE sprint_date = '{day:today}'
      """

  Scenario: Listing sprints covers today and later unless a window says otherwise, as list_sprints does
    Given an MCP client connected with the scopes "read"
    And the sprints:
      | day       |
      | today - 1 |
      | today     |
      | today + 1 |
    When I GET "/sprints" through the API
    Then the API answer holds:
      """
      {"partial": false, "sprints": [{"date": "{day:today}"}, {"date": "{day:today + 1}"}]}
      """
    When I GET "/sprints?to={day:today}" through the API
    Then the API answer holds:
      """
      {"sprints": [{"date": "{day:today - 1}"}, {"date": "{day:today}"}]}
      """
    When I GET "/sprints?from={day:today - 1}&to={day:today}" through the API
    Then the API answer holds:
      """
      {"sprints": [{"date": "{day:today - 1}"}, {"date": "{day:today}"}]}
      """
    And the API answer to GET "/sprints?from={day:today}" matches the MCP tool "list_sprints" with:
      """
      {"from": "{day:today}"}
      """

  Scenario: Listing sprints pages past a page's worth
    Given 101 sprints planned from tomorrow
    When I GET "/sprints" through the API
    Then the API answer holds:
      """
      {"partial": true, "next_page": 2}
      """
    When I GET "/sprints?page=2" through the API
    Then the API answer holds:
      """
      {"sprints": [{"date": "{day:today + 101}"}]}
      """

  Scenario: Listing sprints refuses a window or page it cannot use
    When I GET "/sprints?from={day:today}&to={day:today - 1}" through the API
    Then the API answers 422
    And the API answer holds:
      """
      {"error": "invalid", "message": "from comes after to",
        "errors": {"from": ["from comes after to"], "to": ["from comes after to"]}}
      """
    When I GET "/sprints?from=next%20week" through the API
    Then the API answers 422
    And the API answer holds:
      """
      {"message": "give from and to as days, such as 2026-01-01"}
      """
    When I GET "/sprints?page=0" through the API
    Then the API answers 422
    And the API answer holds "\"page\""
    When I GET "/sprints?page=two" through the API
    Then the API answers 422
    And the API answer holds "\"page\""

  Scenario: Planning a sprint for a later day, as plan_sprint does
    Given an MCP client connected with the scopes "read write"
    When I POST "/sprints" through the API with:
      """
      {"sprint_on": "{day:today + 2}"}
      """
    Then the API answers 201
    And the API answer holds:
      """
      {"date": "{day:today + 2}", "carried_in": 0}
      """
    When I call the MCP tool "plan_sprint" with:
      """
      {"sprint_on": "{day:today + 3}"}
      """
    Then the MCP answer holds:
      """
      {"date": "{day:today + 3}", "carried_in": 0}
      """

  Scenario: Planning refuses a day taken, today, a day it cannot read, no day and a body that is not JSON
    Given the sprints:
      | day       |
      | today + 2 |
    When I POST "/sprints" through the API with:
      """
      {"sprint_on": "{day:today + 2}"}
      """
    Then the API answers 422
    And the API answer holds:
      """
      {"error": "invalid", "message": "a sprint already exists for {day:today + 2}",
        "errors": {"sprint_on": ["a sprint already exists for {day:today + 2}"]}}
      """
    When I POST "/sprints" through the API with:
      """
      {"sprint_on": "{day:today}"}
      """
    Then the API answers 422
    And the database soon holds "0" for:
      """
      SELECT count(*) FROM sprints WHERE sprint_date = '{day:today}'
      """
    When I POST "/sprints" through the API with:
      """
      {"sprint_on": "next week"}
      """
    Then the API answer holds:
      """
      {"message": "pick a day first, such as 2026-01-01"}
      """
    When I POST "/sprints" through the API with:
      """
      {}
      """
    Then the API answer holds:
      """
      {"errors": {"sprint_on": ["sprint_on is missing"]}}
      """
    When I POST "/sprints" through the API with a body of "{nope"
    Then the API answers 400
    And the API answer holds:
      """
      {"error": "invalid_json"}
      """

  Scenario: Dropping a planned sprint sends its tasks back to next, as drop_sprint does
    Given an MCP client connected with the scopes "read write delete"
    And the tasks:
      | title   | sprint    |
      | Planned | today + 1 |
    And the sprints:
      | day       |
      | today + 2 |
    When I DELETE "/sprints/{sprint:today + 1}" through the API
    Then the API answer holds:
      """
      {"date": "{day:today + 1}", "carried_in": 0, "dropped": true}
      """
    And the database soon holds "next, " for:
      """
      SELECT list, coalesce(sprint_id::text, '') FROM tasks WHERE title = 'Planned'
      """
    When I call the MCP tool "drop_sprint" with:
      """
      {"id": {sprint:today + 2}}
      """
    Then the MCP answer holds:
      """
      {"carried_in": 0, "dropped": true}
      """

  Scenario: Dropping a sprint pauses a sourced task in progress and sends it back to external
    Given the tasks:
      | title  | sprint    | status      |
      | Synced | today + 1 | in_progress |
    And the database runs:
      """
      INSERT INTO task_sources (task_id, provider, remote_id, url) VALUES ({task:Synced}, 'github', 'I_1', 'https://github.com/a/b/issues/1');
      INSERT INTO work_sessions (task_id, started_at) VALUES ({task:Synced}, now() - interval '10 minutes')
      """
    When I DELETE "/sprints/{sprint:today + 1}" through the API
    Then the database soon holds "external, open, 0" for:
      """
      SELECT list, status, (SELECT count(*) FROM work_sessions WHERE ended_at IS NULL) AS running FROM tasks WHERE title = 'Synced'
      """
    And the database soon holds "{day:today + 1} external" for:
      """
      SELECT from_sprint_on || ' ' || to_list FROM task_events WHERE kind = 'moved'
      """

  Scenario: Dropping a sprint that has started is refused, by the API and by drop_sprint alike
    Given an MCP client connected with the scopes "read write delete"
    And the sprints:
      | day   |
      | today |
    When I DELETE "/sprints/{sprint:today}" through the API
    Then the API answers 422
    And the API answer holds:
      """
      {"message": "that sprint has already started"}
      """
    And the MCP tool "drop_sprint" answers as the API did, apart from "", with:
      """
      {"id": {sprint:today}}
      """
