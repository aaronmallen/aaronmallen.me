Feature: When work sessions open and close
  Starting a task opens a work session, and anything that takes the task out of progress or out of Today closes it and
  adds its length to the task's total.

  Background:
    Given I am signed in to the admin
    And the worked tasks:
      | title   | sessions            | total | sprint |
      | Running | 30 minutes ago to   | 0     | today  |

  Scenario: Starting opens one session that page loads leave whole
    Given the tasks:
      | title  | sprint |
      | Fresh  | today  |
    When I send the admin form "/admin/tasks/{task:Fresh}/start"
    And I visit "/admin/tasks/{task:Fresh}"
    And I visit "/admin/tasks/{task:Fresh}"
    Then the server answers 200
    And the database soon holds "1, 1, true" for:
      """
      SELECT count(*) AS sessions, count(*) FILTER (WHERE ended_at IS NULL) AS running,
        bool_and(started_at > now() - interval '1 minute') AS fresh
      FROM work_sessions WHERE task_id = {task:Fresh}
      """
    When I send the admin form "/admin/tasks/{task:Running}/start"
    And I visit "/admin/tasks"
    And I visit "/admin/tasks"
    Then the database soon holds "1, true" for:
      """
      SELECT count(*), bool_and(ended_at IS NULL) FROM work_sessions WHERE task_id = {task:Running}
      """

  Scenario: Pausing ends the session and adds it to the total; starting again opens a new one
    When I send the admin form "/admin/tasks/{task:Running}/reopen"
    Then the database soon holds "true, true" for:
      """
      SELECT bool_and(ended_at > now() - interval '1 minute') AS closed, max(worked_seconds) BETWEEN 1795 AND 1810 AS total
      FROM work_sessions JOIN tasks ON tasks.id = task_id WHERE title = 'Running'
      """
    When I send the admin form "/admin/tasks/{task:Running}/start"
    And the database runs:
      """
      UPDATE work_sessions SET started_at = now() - interval '5 minutes' WHERE ended_at IS NULL
      """
    And I send the admin form "/admin/tasks/{task:Running}/stop"
    Then the database soon holds "2, 0, true" for:
      """
      SELECT count(*) AS sessions, count(*) FILTER (WHERE ended_at IS NULL) AS running,
        max(worked_seconds) BETWEEN 2095 AND 2110 AS total
      FROM work_sessions JOIN tasks ON tasks.id = task_id WHERE title = 'Running'
      """

  Scenario: Closing a session adds to a total already on the task, and no open session leaves it alone
    Given the database runs:
      """
      UPDATE tasks SET worked_seconds = 3600 WHERE title = 'Running';
      INSERT INTO tasks (title, list, number, position, worked_seconds) VALUES ('Idle', 'next', 900, 900, 120)
      """
    When I send the admin form "/admin/tasks/{task:Running}/complete"
    And I send the admin form "/admin/tasks/{task:Idle}/complete"
    Then the database soon holds "Idle done 120 | Running done true" for:
      """
      SELECT string_agg(title || ' ' || status || ' ' ||
        CASE WHEN title = 'Idle' THEN worked_seconds::text ELSE (worked_seconds BETWEEN 5395 AND 5410)::text END,
        ' | ' ORDER BY title)
      FROM tasks
      """

  Scenario Outline: The session ends when the task is <change>
    When I send the admin form "<path>" with:
      | sprint_on | <day> |
    Then the database soon holds "0, true" for:
      """
      SELECT count(*) FILTER (WHERE ended_at IS NULL) AS running, bool_and(ended_at > now() - interval '1 minute') AS now
      FROM work_sessions WHERE task_id = {task:Running}
      """

    Examples:
      | change                    | path                                     | day             |
      | completed                 | /admin/tasks/{task:Running}/complete     |                 |
      | canceled                  | /admin/tasks/{task:Running}/cancel       |                 |
      | moved out of Today        | /admin/tasks/{task:Running}/move/next    |                 |
      | scheduled for a later day | /admin/tasks/{task:Running}/schedule     | {day:today + 2} |
      | unscheduled               | /admin/tasks/{task:Running}/schedule     |                 |

  Scenario: Moving a task in progress into Today keeps its session open
    Given the database runs:
      """
      UPDATE tasks SET sprint_id = NULL, list = 'next' WHERE title = 'Running'
      """
    When I send the admin form "/admin/tasks/{task:Running}/move/today"
    Then the database soon holds "1" for:
      """
      SELECT count(*) FROM work_sessions WHERE ended_at IS NULL AND task_id = {task:Running}
      """

  Scenario: Dropping the task's sprint ends the session
    Given the database runs:
      """
      INSERT INTO sprints (sprint_date) VALUES ('{day:today + 2}');
      UPDATE tasks SET sprint_id = (SELECT id FROM sprints WHERE sprint_date = '{day:today + 2}') WHERE title = 'Running'
      """
    When I send the admin form "/admin/tasks/sprints/{sprint:today + 2}/delete"
    Then the database soon holds "0" for:
      """
      SELECT count(*) FROM work_sessions WHERE ended_at IS NULL
      """

  Scenario: Deleting the task takes its sessions with it
    When I send the admin form "/admin/tasks/{task:Running}/delete"
    Then the database soon holds "0" for:
      """
      SELECT count(*) FROM work_sessions
      """

  Scenario: The database refuses a second open session, a session that ends before it starts and a negative total
    Then the database refuses, breaking a unique constraint:
      """
      INSERT INTO work_sessions (task_id, started_at) SELECT id, now() FROM tasks WHERE title = 'Running'
      """
    And the database refuses, breaking a check constraint:
      """
      INSERT INTO work_sessions (task_id, started_at, ended_at) SELECT id, now(), now() - interval '1 minute' FROM tasks
      """
    And the database refuses, breaking a check constraint:
      """
      UPDATE tasks SET worked_seconds = -1
      """

  Scenario: Two deletes of one session at once take its length off once
    Given an API token
    And the task "Running" worked from "today - 1 09:00" to "today - 1 09:30"
    And the database runs:
      """
      UPDATE tasks SET worked_seconds = 3600 WHERE title = 'Running'
      """
    When two deletes of the closed session of "Running" wait on a lock on the task, then run
    Then the two deletes answered "200, 404" in some order
    And the database soon holds "1800" for:
      """
      SELECT worked_seconds FROM tasks WHERE title = 'Running'
      """
