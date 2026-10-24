Feature: Work sessions through the API and MCP
  The API pauses tasks, edits, adds and deletes work sessions, sets totals and completes with a duration, and the MCP
  tools answer as the endpoints do.

  Background:
    Given an API token
    And the worked tasks:
      | title      | sessions                           | total | status |
      | Write docs | today - 1 09:00 to today - 1 09:30 | 3600  | open   |
    And the worked tasks:
      | title   | sessions           | total | sprint |
      | Running | today - 1 09:00 to | 600   | today  |

  Scenario: Pausing ends the open session and keeps the task in its sprint
    When I POST "/tasks/{task:Running}/pause" through the API
    Then the API answers 200
    And the API answer holds:
      """
      {"status": "open", "sprint_on": "{day:today}"}
      """
    And the database soon holds "true, 0" for:
      """
      SELECT worked_seconds > 600, (SELECT count(*) FROM work_sessions WHERE ended_at IS NULL) AS running
      FROM tasks WHERE title = 'Running'
      """
    When I POST "/tasks/{task:Running}/start" through the API
    Then the database soon holds "2, 1" for:
      """
      SELECT count(*) AS sessions, count(*) FILTER (WHERE ended_at IS NULL) AS running FROM work_sessions WHERE task_id = {task:Running}
      """

  Scenario Outline: Pausing a <status> task is refused and leaves it <status>
    Given the database runs:
      """
      UPDATE tasks SET status = '<status>', completed_at = <completed> WHERE title = 'Write docs'
      """
    When I POST "/tasks/{task:Write docs}/pause" through the API
    Then the API answers 422
    And the API answer holds:
      """
      {"message": "task {task:Write docs} is not in progress"}
      """
    And the database soon holds "<status>" for:
      """
      SELECT status FROM tasks WHERE title = 'Write docs'
      """

    Examples:
      | status   | completed |
      | open     | NULL      |
      | done     | now()     |
      | canceled | now()     |

  Scenario: Editing a closed session shifts the total
    When I PATCH "/tasks/{task:Write docs}/sessions/{session:Write docs}" through the API with:
      """
      {"started_at": "{local:today - 1 09:00}", "ended_at": "{local:today - 1 09:45}"}
      """
    Then the API answers 200
    And the API answer holds:
      """
      {"worked_seconds": 4500}
      """
    When I PATCH "/tasks/{task:Write docs}/sessions/{session:Write docs}" through the API with:
      """
      {"started_at": "{local:today - 1 09:10}", "ended_at": "{local:today - 1 09:45}"}
      """
    Then the API answer holds:
      """
      {"worked_seconds": 3900}
      """

  Scenario: Editing the running session moves its start and leaves the total
    When I PATCH "/tasks/{task:Running}/sessions/{session:Running}" through the API with:
      """
      {"started_at": "{local:today - 1 08:50}"}
      """
    Then the API answers 200
    And the database soon holds "600, {day:today - 1} 08:50" for:
      """
      SELECT worked_seconds, to_char(started_at AT TIME ZONE 'America/Chicago', 'YYYY-MM-DD HH24:MI')
      FROM tasks JOIN work_sessions ON task_id = tasks.id WHERE title = 'Running'
      """

  Scenario Outline: An edit with <problem> is refused and keeps the session
    When I PATCH "/tasks/{task:Write docs}/sessions/{session:Write docs}" through the API with:
      """
      <body>
      """
    Then the API answers 422
    And the API answer holds:
      """
      {"errors": <errors>}
      """
    And the database soon holds "3600, {day:today - 1} 09:30" for:
      """
      SELECT worked_seconds, to_char(ended_at AT TIME ZONE 'America/Chicago', 'YYYY-MM-DD HH24:MI')
      FROM tasks JOIN work_sessions ON task_id = tasks.id WHERE title = 'Write docs'
      """

    Examples:
      | problem                 | body                                                                           | errors                                                                                                   |
      | an end before the start | {"started_at": "{local:today - 1 09:00}", "ended_at": "{local:today - 1 08:59}"} | {"ended_at": ["a session ends after it starts"]}                                                         |
      | an end later than now   | {"started_at": "{local:today - 1 09:00}", "ended_at": "{local:today + 1 09:00}"} | {"ended_at": ["a session cannot end later than now"]}                                                    |
      | a start later than now  | {"started_at": "{local:today + 1 09:00}", "ended_at": "{local:today + 1 10:00}"} | {"started_at": ["a session cannot start later than now"], "ended_at": ["a session cannot end later than now"]} |
      | no end                  | {"started_at": "{local:today - 1 09:00}"}                                          | {"ended_at": ["a finished session needs an end"]}                                                        |
      | a start it cannot read  | {"started_at": "yesterday", "ended_at": "{local:today - 1 09:00}"}                 | {"started_at": ["give the start as YYYY-MM-DDTHH:MM"]}                                                   |

  Scenario: An edit with no start, or of another task's session, is refused
    When I PATCH "/tasks/{task:Write docs}/sessions/{session:Write docs}" through the API with:
      """
      {"ended_at": "{local:today - 1 09:00}"}
      """
    Then the API answers 422
    When I PATCH "/tasks/{task:Write docs}/sessions/{session:Running}" through the API with:
      """
      {"started_at": "{local:today - 1 09:00}", "ended_at": "{local:today - 1 09:01}"}
      """
    Then the API answers 404
    And the API answer holds:
      """
      {"message": "task {task:Write docs} has no work session with the ID {session:Running}"}
      """

  Scenario: Adding a session raises the total, beside a running one or on a done task
    When I POST "/tasks/{task:Write docs}/sessions" through the API with:
      """
      {"started_at": "{local:today - 1 10:00}", "ended_at": "{local:today - 1 10:45}"}
      """
    Then the API answers 201
    And the API answer holds:
      """
      {"worked_seconds": 6300}
      """
    When I POST "/tasks/{task:Running}/sessions" through the API with:
      """
      {"started_at": "{local:today - 1 09:01}", "ended_at": "{local:today - 1 09:11}"}
      """
    Then the database soon holds "1200, 2" for:
      """
      SELECT worked_seconds, (SELECT count(*) FROM work_sessions WHERE task_id = tasks.id) AS sessions
      FROM tasks WHERE title = 'Running'
      """
    Given the database runs:
      """
      UPDATE tasks SET status = 'done', completed_at = '2026-01-01T12:00:00Z', worked_seconds = 0 WHERE title = 'Write docs'
      """
    When I POST "/tasks/{task:Write docs}/sessions" through the API with:
      """
      {"started_at": "{local:today - 1 11:00}", "ended_at": "{local:today - 1 11:10}"}
      """
    Then the API answer holds:
      """
      {"status": "done", "worked_seconds": 600}
      """
    And the database soon holds "2026-01-01" for:
      """
      SELECT to_char(completed_at, 'YYYY-MM-DD') FROM tasks WHERE title = 'Write docs'
      """

  Scenario Outline: Adding a session with <problem> is refused and adds nothing
    When I POST "/tasks/{task:Write docs}/sessions" through the API with:
      """
      <body>
      """
    Then the API answers 422
    And the API answer holds:
      """
      {"errors": <errors>}
      """
    And the database soon holds "3600, 1" for:
      """
      SELECT worked_seconds, (SELECT count(*) FROM work_sessions WHERE task_id = tasks.id) AS sessions
      FROM tasks WHERE title = 'Write docs'
      """

    Examples:
      | problem                 | body                                                                           | errors                                                                                                   |
      | an end before the start | {"started_at": "{local:today - 1 10:00}", "ended_at": "{local:today - 1 09:59}"} | {"ended_at": ["a session ends after it starts"]}                                                         |
      | times later than now    | {"started_at": "{local:today + 1 09:00}", "ended_at": "{local:today + 1 10:00}"} | {"started_at": ["a session cannot start later than now"], "ended_at": ["a session cannot end later than now"]} |
      | no end                  | {"started_at": "{local:today - 1 10:00}"}                                          | {}                                                                                                       |

  Scenario: Deleting a session drops the total, but the running one stays
    When I DELETE "/tasks/{task:Write docs}/sessions/{session:Write docs}" through the API
    Then the API answer holds:
      """
      {"worked_seconds": 1800}
      """
    When I DELETE "/tasks/{task:Running}/sessions/{session:Running}" through the API
    Then the API answers 422
    And the API answer holds:
      """
      {"errors": {"ended_at": ["pause or complete the task before you delete its running session"]}}
      """
    And the database soon holds "in_progress, 600, 1" for:
      """
      SELECT status, worked_seconds, (SELECT count(*) FROM work_sessions WHERE ended_at IS NULL) AS running
      FROM tasks WHERE title = 'Running'
      """
    When I DELETE "/tasks/{task:Write docs}/sessions/{session:Running}" through the API
    Then the API answers 404
    And the database soon holds "1" for:
      """
      SELECT count(*) FROM work_sessions WHERE task_id = {task:Running}
      """

  Scenario: Setting the total replaces it, and a later session adds to it
    When I POST "/tasks/{task:Write docs}/total" through the API with:
      """
      {"hours": 2, "minutes": 15}
      """
    Then the API answer holds:
      """
      {"worked_seconds": 8100}
      """
    When I POST "/tasks/{task:Write docs}/total" through the API with:
      """
      {"minutes": 45}
      """
    Then the API answer holds:
      """
      {"worked_seconds": 2700}
      """
    Given the database runs:
      """
      UPDATE work_sessions SET started_at = now() - interval '10 minutes' WHERE task_id = {task:Running}
      """
    When I POST "/tasks/{task:Running}/total" through the API with:
      """
      {"hours": 1}
      """
    And I POST "/tasks/{task:Running}/complete" through the API
    Then the database soon holds "true" for:
      """
      SELECT worked_seconds BETWEEN 3600 AND 3660 FROM tasks WHERE title = 'Running'
      """

  Scenario: A total I cannot use is refused and keeps the old one
    When I POST "/tasks/{task:Write docs}/total" through the API
    Then the API answers 422
    And the API answer holds:
      """
      {"errors": {"hours": ["give the hours, the minutes or both"]}}
      """
    When I POST "/tasks/{task:Write docs}/total" through the API with:
      """
      {"minutes": 60}
      """
    Then the API answer holds:
      """
      {"errors": {"minutes": ["minutes run from 0 to 59"]}}
      """
    And the database soon holds "3600" for:
      """
      SELECT worked_seconds FROM tasks WHERE title = 'Write docs'
      """

  Scenario: Completing keeps the total unless it names a duration
    When I POST "/tasks/{task:Write docs}/complete" through the API
    Then the API answer holds:
      """
      {"status": "done", "worked_seconds": 3600}
      """
    When I POST "/tasks/{task:Running}/complete" through the API with:
      """
      {"hours": 3}
      """
    Then the API answer holds:
      """
      {"status": "done", "worked_seconds": 10800}
      """
    And the database soon holds "0" for:
      """
      SELECT count(*) FROM work_sessions WHERE ended_at IS NULL
      """

  Scenario: Completing with a short duration replaces the total
    When I POST "/tasks/{task:Write docs}/complete" through the API with:
      """
      {"hours": 0, "minutes": 30}
      """
    Then the API answer holds:
      """
      {"status": "done", "worked_seconds": 1800}
      """

  Scenario: Completing with hours past 9999 is refused and leaves the task open
    When I POST "/tasks/{task:Write docs}/complete" through the API with:
      """
      {"hours": 10000}
      """
    Then the API answers 422
    And the API answer holds:
      """
      {"errors": {"hours": ["hours run from 0 to 9999"]}}
      """
    And the database soon holds "open" for:
      """
      SELECT status FROM tasks WHERE title = 'Write docs'
      """

  Scenario: Reads carry the total
    When I GET "/tasks/{task:Write docs}" through the API
    Then the API answer holds:
      """
      {"worked_seconds": 3600}
      """
    When I GET "/tasks" through the API
    Then the API answer holds "\"worked_seconds\":3600"

  Scenario: The MCP time tools answer as the endpoints do
    Given an MCP client connected with the scopes "read write delete"
    When I PATCH "/tasks/{task:Write docs}/sessions/{session:Write docs}" through the API with:
      """
      {"started_at": "{local:today - 1 09:00}", "ended_at": "{local:today - 1 09:15}"}
      """
    Then the MCP tool "update_work_session" answers as the API did, apart from "updated_at", with:
      """
      {"id": {task:Write docs}, "session_id": {session:Write docs}, "started_at": "{local:today - 1 09:00}", "ended_at": "{local:today - 1 09:15}"}
      """
    When I POST "/tasks/{task:Write docs}/total" through the API with:
      """
      {"hours": 4}
      """
    Then the MCP tool "set_task_total" answers as the API did, apart from "updated_at", with:
      """
      {"id": {task:Write docs}, "hours": 4}
      """
    When I POST "/tasks/{task:Write docs}/pause" through the API
    Then the MCP tool "pause_task" answers as the API did, apart from "", with:
      """
      {"id": {task:Write docs}}
      """
    When I DELETE "/tasks/{task:Running}/sessions/{session:Running}" through the API
    Then the MCP tool "delete_work_session" answers as the API did, apart from "", with:
      """
      {"id": {task:Running}, "session_id": {session:Running}}
      """

  Scenario: add_work_session adds as the endpoint does
    Given an MCP client connected with the scopes "read write"
    When I POST "/tasks/{task:Write docs}/sessions" through the API with:
      """
      {"started_at": "{local:today - 1 10:00}", "ended_at": "{local:today - 1 10:15}"}
      """
    Then the API answer holds:
      """
      {"worked_seconds": 4500}
      """
    And the MCP tool "add_work_session" answers as the API did, apart from "updated_at, worked_seconds, timeline", with:
      """
      {"id": {task:Write docs}, "started_at": "{local:today - 1 10:00}", "ended_at": "{local:today - 1 10:15}"}
      """
    And the database soon holds "5400" for:
      """
      SELECT worked_seconds FROM tasks WHERE title = 'Write docs'
      """

  Scenario: delete_work_session drops the total as the endpoint does
    Given an MCP client connected with the scopes "read write delete"
    And the task "Write docs" worked from "today - 1 11:00" to "today - 1 11:05"
    When I DELETE "/tasks/{task:Write docs}/sessions/{session:Write docs}" through the API
    And I call the MCP tool "delete_work_session" with:
      """
      {"id": {task:Write docs}, "session_id": {session:Write docs}}
      """
    Then the MCP answer holds:
      """
      {"worked_seconds": 1500}
      """

  Scenario: pause_task and complete_task answer as the endpoints do for a twin task
    Given an MCP client connected with the scopes "read write"
    And the tasks:
      | title | sprint |
      | same  | today  |
      | twin  | today  |
    When I POST "/tasks/{task:same}/start" through the API
    And I POST "/tasks/{task:twin}/start" through the API
    And I POST "/tasks/{task:same}/pause" through the API
    Then the MCP tool "pause_task" answers as the API did, apart from "id, label, number, title, position, created_at, updated_at, worked_seconds, timeline", with:
      """
      {"id": {task:twin}}
      """
    When I POST "/tasks/{task:same}/complete" through the API with:
      """
      {"minutes": 20}
      """
    Then the MCP tool "complete_task" answers as the API did, apart from "id, label, number, title, position, completed_at, created_at, updated_at, timeline", with:
      """
      {"id": {task:twin}, "minutes": 20}
      """
