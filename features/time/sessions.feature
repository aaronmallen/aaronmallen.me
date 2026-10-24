Feature: Work sessions in the admin
  The task page edits, adds and deletes work sessions, sets the total by hand and keeps the running time ticking.

  Background:
    Given I am signed in to the admin
    And the worked tasks:
      | title      | sessions                     | total | status |
      | Write docs | today - 1 09:00 to today - 1 09:30 | 3600  | open   |
    And the worked tasks:
      | title   | sessions                 | total | sprint |
      | Running | today - 1 09:00 to       | 600   | today  |

  Scenario: Editing a closed session shifts the total by the change
    When I send the admin form "/admin/tasks/{task:Write docs}/sessions/{session:Write docs}" with:
      | filter             | next                   |
      | session[started_at] | {local:today - 1 09:00} |
      | session[ended_at]   | {local:today - 1 09:45} |
    Then the admin answer goes to "/admin/tasks?filter=next"
    And the database soon holds "4500, {day:today - 1} 09:45" for:
      """
      SELECT worked_seconds, to_char(ended_at AT TIME ZONE 'America/Chicago', 'YYYY-MM-DD HH24:MI')
      FROM tasks JOIN work_sessions ON task_id = tasks.id WHERE title = 'Write docs'
      """
    When I send the admin form "/admin/tasks/{task:Write docs}/sessions/{session:Write docs}" with:
      | session[started_at] | {local:today - 1 09:10} |
      | session[ended_at]   | {local:today - 1 09:45} |
    Then the database soon holds "3900" for:
      """
      SELECT worked_seconds FROM tasks WHERE title = 'Write docs'
      """

  Scenario: An edit that leaves a time in the same minute keeps its seconds
    Given the database runs:
      """
      UPDATE work_sessions SET started_at = started_at + interval '15 seconds', ended_at = ended_at + interval '45 seconds'
      WHERE task_id = {task:Write docs}
      """
    When I send the admin form "/admin/tasks/{task:Write docs}/sessions/{session:Write docs}" with:
      | session[started_at] | {local:today - 1 09:00} |
      | session[ended_at]   | {local:today - 1 09:45} |
    Then the database soon holds "4455, 15" for:
      """
      SELECT worked_seconds, extract(second FROM started_at)::int
      FROM tasks JOIN work_sessions ON task_id = tasks.id WHERE title = 'Write docs'
      """

  Scenario: Editing the running session moves only its start
    When I send the admin form "/admin/tasks/{task:Running}/sessions/{session:Running}" with:
      | session[started_at] | {local:today - 1 08:50} |
      | session[ended_at]   | soon                    |
    Then the database soon holds "600, {day:today - 1} 08:50, true" for:
      """
      SELECT worked_seconds, to_char(started_at AT TIME ZONE 'America/Chicago', 'YYYY-MM-DD HH24:MI'), ended_at IS NULL
      FROM tasks JOIN work_sessions ON task_id = tasks.id WHERE title = 'Running'
      """
    When I send the admin form "/admin/tasks/{task:Running}/sessions/{session:Running}" with:
      | session[started_at] | {local:today + 1 09:00} |
    Then the server answers 422
    And the database soon holds "{day:today - 1} 08:50" for:
      """
      SELECT to_char(started_at AT TIME ZONE 'America/Chicago', 'YYYY-MM-DD HH24:MI') FROM work_sessions
      WHERE task_id = {task:Running}
      """

  Scenario Outline: An edit with <problem> is refused beside the field and changes nothing
    When I send the admin form "/admin/tasks/{task:Write docs}/sessions/{session:Write docs}" with:
      | session[started_at] | <from> |
      | session[ended_at]   | <to>   |
    Then the server answers 422
    When I look at the admin answer
    Then the page part "#task-session-{session:Write docs}-<field>-error" holds "<error>"
    And the database soon holds "3600, {day:today - 1} 09:30" for:
      """
      SELECT worked_seconds, to_char(ended_at AT TIME ZONE 'America/Chicago', 'YYYY-MM-DD HH24:MI')
      FROM tasks JOIN work_sessions ON task_id = tasks.id WHERE title = 'Write docs'
      """

    Examples:
      | problem               | from                    | to                      | field      | error                                   |
      | an end later than now | {local:today - 1 09:00} | {local:today + 1 09:00} | ended-at   | A session cannot end later than now.    |
      | a start later than now | {local:today + 1 09:00} | {local:today + 1 10:00} | started-at | A session cannot start later than now. |
      | an end before the start | {local:today - 1 09:00} | {local:today - 1 08:59} | ended-at | End it after it starts.                 |

  Scenario: A refused edit keeps what I typed, and a blank start says so
    When I send the admin form "/admin/tasks/{task:Write docs}/sessions/{session:Write docs}" with:
      | session[started_at] | {local:today - 1 09:00} |
      | session[ended_at]   | nonsense                |
    And I look at the admin answer
    Then the page part "#task-session-{session:Write docs}-started-at" has "value" set to "{local:today - 1 09:00}"
    When I send the admin form "/admin/tasks/{task:Write docs}/sessions/{session:Write docs}" with:
      | session[started_at] |                         |
      | session[ended_at]   | {local:today - 1 09:00} |
    Then the answer shows "Give the time it started."

  Scenario: A session of another task is not found
    When I send the admin form "/admin/tasks/{task:Write docs}/sessions/{session:Running}" with:
      | session[started_at] | {local:today - 1 09:00} |
      | session[ended_at]   | {local:today - 1 09:01} |
    Then the server answers 404
    When I send the admin form "/admin/tasks/{task:Write docs}/sessions/{session:Running}/delete"
    Then the server answers 404

  Scenario: Deleting a session drops the total by its length and leaves no mark
    When I send the admin form "/admin/tasks/{task:Write docs}/sessions/{session:Write docs}/delete" with:
      | filter | next |
    Then the database soon holds "1800, 0" for:
      """
      SELECT worked_seconds, (SELECT count(*) FROM work_sessions) - 1 FROM tasks WHERE title = 'Write docs'
      """
    When I visit "/admin/tasks/{task:Write docs}?filter=next"
    Then the page has no ".task-session-row, [id^='task-session-'][id$='-delete']"
    And the page part ".task-timeline .hint" holds "Nothing has happened yet."
    And the page has no axe breaches in light or dark

  Scenario: Deleting a session never takes the total below zero
    Given the database runs:
      """
      UPDATE tasks SET worked_seconds = 60 WHERE title = 'Write docs'
      """
    When I send the admin form "/admin/tasks/{task:Write docs}/sessions/{session:Write docs}/delete"
    Then the database soon holds "0" for:
      """
      SELECT worked_seconds FROM tasks WHERE title = 'Write docs'
      """

  Scenario: The running session cannot be deleted
    When I send the admin form "/admin/tasks/{task:Running}/sessions/{session:Running}/delete"
    Then the server answers 422
    When I look at the admin answer
    Then the page part "#task-session-{session:Running}-ended-at-error" holds "Pause or complete the task before you delete its running session."
    And the page part "#task-session-{session:Running}-started-at" has "value" set to "{local:today - 1 09:00}"
    And the database soon holds "in_progress, 1" for:
      """
      SELECT status, (SELECT count(*) FROM work_sessions WHERE ended_at IS NULL) AS running FROM tasks WHERE title = 'Running'
      """

  Scenario: Only a closed session offers a delete form
    Given the task "Running" worked from "today - 1 07:00" to "today - 1 07:30"
    When I visit "/admin/tasks/{task:Running}?filter=next"
    Then the page has 1 of "form[action$='/delete'][action*='/sessions/']"
    And the page has no "form[action$='/sessions/{session:Running}/delete']"

  Scenario: The add form sits beside the total form, on the task page and the edit page
    When I visit "/admin/tasks/{task:Write docs}?filter=next"
    Then the page has ".field > details.task-session-add + details.task-total-edit"
    And the page part ".task-session-add input[name='session[started_at]']" has "value" set to ""
    And the page part ".task-session-add input[name='session[ended_at]']" has "value" set to ""
    And the page part ".task-session-add input[name='session[started_at]']" has "type" set to "datetime-local"
    And the page part ".task-total-edit input[name='total[hours]']" has "value" set to "1"
    And the page part ".task-total-edit input[name='total[minutes]']" has "value" set to "0"
    And the page part ".task-total-edit input[name='total[hours]']" has "max" set to "9999"
    And the page part ".task-total-edit input[name='total[minutes]']" has "max" set to "59"
    And the page part ".task-total-edit .hint" holds "This replaces the total. Sessions after it add to it."
    When I visit "/admin/tasks/{task:Write docs}/edit?filter=next"
    Then the page has ".task-session-add form[action$='/tasks/{task:Write docs}/sessions']"

  Scenario: Adding work raises the total without starting the task
    When I send the admin form "/admin/tasks/{task:Write docs}/sessions" with:
      | filter              | next                    |
      | session[started_at] | {local:today - 1 10:00} |
      | session[ended_at]   | {local:today - 1 10:45} |
    Then the admin answer goes to "/admin/tasks?filter=next"
    And the database soon holds "6300, open, 2, 0" for:
      """
      SELECT worked_seconds, status, (SELECT count(*) FROM work_sessions WHERE task_id = tasks.id) AS sessions,
        (SELECT count(*) FROM task_events WHERE task_id = tasks.id) AS events
      FROM tasks WHERE title = 'Write docs'
      """
    When I visit "/admin/tasks/{task:Write docs}?filter=next"
    Then the page has 2 of "[id^='task-session-']:not([id*='-error']):not([id$='-at'])"

  Scenario: Added work that overlaps the running session still saves
    When I send the admin form "/admin/tasks/{task:Running}/sessions" with:
      | session[started_at] | {local:today - 1 09:10} |
      | session[ended_at]   | {local:today - 1 09:20} |
    Then the database soon holds "1200, 2, 1" for:
      """
      SELECT worked_seconds, (SELECT count(*) FROM work_sessions WHERE task_id = tasks.id) AS sessions,
        (SELECT count(*) FROM work_sessions WHERE task_id = tasks.id AND ended_at IS NULL) AS running
      FROM tasks WHERE title = 'Running'
      """

  Scenario Outline: Adding work to a <status> task leaves its status and completion
    Given the database runs:
      """
      UPDATE tasks SET status = '<status>', completed_at = '2026-01-01T12:00:00Z', worked_seconds = 0 WHERE title = 'Write docs'
      """
    When I send the admin form "/admin/tasks/{task:Write docs}/sessions" with:
      | session[started_at] | {local:today - 1 10:00} |
      | session[ended_at]   | {local:today - 1 10:10} |
    Then the database soon holds "600, <status>, 2026-01-01" for:
      """
      SELECT worked_seconds, status, to_char(completed_at, 'YYYY-MM-DD') FROM tasks WHERE title = 'Write docs'
      """

    Examples:
      | status   |
      | done     |
      | canceled |

  Scenario Outline: Added work with <problem> is refused and adds nothing
    When I send the admin form "/admin/tasks/{task:Write docs}/sessions" with:
      | session[started_at] | <from> |
      | session[ended_at]   | <to>   |
    Then the server answers 422
    When I look at the admin answer
    Then the page part "#task-{task:Write docs}-session-ended-at-error" holds "<error>"
    And the database soon holds "3600, 1" for:
      """
      SELECT worked_seconds, (SELECT count(*) FROM work_sessions WHERE task_id = tasks.id) FROM tasks WHERE title = 'Write docs'
      """

    Examples:
      | problem                  | from                    | to                      | error                                |
      | times later than now     | {local:today + 1 09:00} | {local:today + 1 10:00} | A session cannot end later than now. |
      | an end before the start  | {local:today - 1 10:00} | {local:today - 1 09:59} | End it after it starts.              |
      | no end                   | {local:today - 1 10:00} |                         | Give the time it ended.              |

  Scenario: Refused work keeps the form open with what I typed
    When I send the admin form "/admin/tasks/{task:Write docs}/sessions" with:
      | session[started_at] | {local:today + 1 09:00} |
      | session[ended_at]   | {local:today + 1 10:00} |
    And I look at the admin answer
    Then the page part "#task-{task:Write docs}-session-started-at-error" holds "A session cannot start later than now."
    When I send the admin form "/admin/tasks/{task:Write docs}/sessions" with:
      | session[started_at] | {local:today - 1 10:00} |
      | session[ended_at]   |                         |
    And I look at the admin answer
    Then the page has "details.task-session-add[open]"
    And the page part ".task-session-add input[name='session[started_at]']" has "value" set to "{local:today - 1 10:00}"

  Scenario: Adding work to a task that is not there is not found
    When I send the admin form "/admin/tasks/999999/sessions" with:
      | session[started_at] | {local:today - 1 10:00} |
      | session[ended_at]   | {local:today - 1 10:10} |
    Then the server answers 404

  Scenario: Setting the total replaces it, and later sessions add to it
    When I send the admin form "/admin/tasks/{task:Write docs}/total" with:
      | total[hours]   | 2  |
      | total[minutes] | 15 |
    Then the database soon holds "8100" for:
      """
      SELECT worked_seconds FROM tasks WHERE title = 'Write docs'
      """
    When I send the admin form "/admin/tasks/{task:Write docs}/total" with:
      | total[hours]   |    |
      | total[minutes] | 20 |
    And I send the admin form "/admin/tasks/{task:Write docs}/start"
    And the database runs:
      """
      UPDATE work_sessions SET started_at = now() - interval '10 minutes' WHERE ended_at IS NULL AND task_id = {task:Write docs}
      """
    And I send the admin form "/admin/tasks/{task:Write docs}/reopen"
    Then the database soon holds "true" for:
      """
      SELECT worked_seconds BETWEEN 1800 AND 1810 FROM tasks WHERE title = 'Write docs'
      """

  Scenario: Setting the total of a running task counts its time so far and keeps it running
    When I send the admin form "/admin/tasks/{task:Running}/total" with:
      | total[hours] | 1 |
    Then the database soon holds "3600, false, true" for:
      """
      SELECT worked_seconds, bool_or(ended_at IS NULL) FILTER (WHERE started_at < now() - interval '1 hour') AS old_open,
        bool_or(ended_at IS NULL) AS running
      FROM tasks JOIN work_sessions ON task_id = tasks.id WHERE title = 'Running' GROUP BY worked_seconds
      """

  Scenario: A total I cannot use is refused
    When I send the admin form "/admin/tasks/{task:Write docs}/total" with:
      | total[hours]   |  |
      | total[minutes] |  |
    Then the server answers 422
    And the answer shows "Give the hours, the minutes or both."
    When I send the admin form "/admin/tasks/{task:Write docs}/total" with:
      | total[hours]   | 1  |
      | total[minutes] | 75 |
    And I look at the admin answer
    Then the page part "details.task-total-edit[open]" holds "Give whole minutes, up to 59."
    And the database soon holds "3600" for:
      """
      SELECT worked_seconds FROM tasks WHERE title = 'Write docs'
      """

  Scenario: Done asks how long a task took only when it has no tracked time
    Given the tasks:
      | title   |
      | Untimed |
    When I visit "/admin/tasks?filter=next"
    Then the page part "form[action$='/tasks/{task:Untimed}/complete'] legend" reads "How long did this take?"
    And the page part "form[action$='/tasks/{task:Untimed}/complete'] input[name='worked[hours]']" has "value" set to "0"
    And the page part "form[action$='/tasks/{task:Untimed}/complete'] input[name='worked[minutes]']" has "value" set to "0"
    When I visit "/admin/tasks/{task:Running}?filter=next"
    Then the page has no "form[action$='/complete'] legend"

  Scenario: Done keeps the tracked total of a task with closed sessions
    When I send the admin form "/admin/tasks/{task:Write docs}/complete"
    Then the database soon holds "done, 3600" for:
      """
      SELECT status, worked_seconds FROM tasks WHERE title = 'Write docs'
      """

  Scenario Outline: Done on a running task <outcome>
    Given the database runs:
      """
      UPDATE work_sessions SET started_at = now() - interval '30 minutes' WHERE task_id = {task:Running}
      """
    When I send the admin form "/admin/tasks/{task:Running}/complete" with:
      | worked[hours]   | <hours>   |
      | worked[minutes] | <minutes> |
      | worked[tracked] | 2400      |
    Then the database soon holds "<status>, true" for:
      """
      SELECT status, worked_seconds BETWEEN <low> AND <high> FROM tasks WHERE title = 'Running'
      """

    Examples:
      | outcome                                   | hours | minutes | status      | low   | high  |
      | keeps the tracked total left as it was    | 0     | 40      | done        | 2395  | 2405  |
      | keeps the tracked total on a blank answer |       |         | done        | 2395  | 2405  |
      | replaces the total with a new number      | 3     | 5       | done        | 11100 | 11100 |
      | refuses an answer out of range            | -1    | 0       | in_progress | 0     | 99999 |

  Scenario: Done with no answer still completes and keeps the tracked total
    Given the database runs:
      """
      UPDATE work_sessions SET started_at = now() - interval '30 minutes' WHERE task_id = {task:Running}
      """
    When I send the admin form "/admin/tasks/{task:Running}/complete"
    Then the database soon holds "done, true" for:
      """
      SELECT status, worked_seconds BETWEEN 2395 AND 2405 FROM tasks WHERE title = 'Running'
      """

  Scenario: The running time counts from when the tracked time began, on every screen
    Given the database runs:
      """
      UPDATE work_sessions SET started_at = date_trunc('second', now()) - interval '1830 seconds' WHERE task_id = {task:Running}
      """
    When I visit "/admin/tasks"
    Then the running figure ".task-meta .task-mark.blue" of "Running" reads "40m" and counts from its tracked start
    When I visit "/admin"
    Then the running figure ".task-meta" of "Running" reads "40m" and counts from its tracked start
    When I visit "/admin/tasks/{task:Running}?filter=next"
    Then the running figure ".task-stbar-worked" of "Running" reads "40m" and counts from its tracked start
    And the running figure ".field .f" of "Running" reads "40m" and counts from its tracked start
    When I visit "/admin/tasks/{task:Write docs}?filter=next"
    Then the page has no "[data-tracked-since]"

  Scenario: The running figure adds a minute as each minute passes, even when drawn again
    Given the database runs:
      """
      UPDATE work_sessions SET started_at = now() - interval '10 minutes' WHERE task_id = {task:Running};
      UPDATE tasks SET worked_seconds = 0 WHERE title = 'Running'
      """
    When I visit "/admin/tasks"
    And the running figure on the tasks list began 1 minute sooner
    Then the page part ".task-meta [data-tracked-since]" reads "11m"
    When the page draws the running figure again
    And the running figure on the tasks list began 62 minutes sooner
    Then the page part ".task-meta [data-tracked-since]" reads "1h 13m"
