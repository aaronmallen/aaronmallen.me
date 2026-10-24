Feature: The task timeline records what changed
  Each move, tag change and status change in the admin leaves an event on the task's timeline.

  Background:
    Given I am signed in to the admin

  Scenario: Moving a task between lists records the from and to list, and nothing for a move in place
    Given the tasks:
      | title | list |
      | Move  | next |
      | Stay  | next |
    When I send the admin form "/admin/tasks/{task:Move}/move/someday"
    And I send the admin form "/admin/tasks/{task:Stay}/move/next"
    Then the events of "Move" read "moved next to someday"
    And the events of "Stay" read ""
    And the database reads "true" for:
      """
      SELECT occurred_at BETWEEN now() - interval '1 minute' AND now() FROM task_events
      """

  Scenario: Moving a task into and out of Today records the sprint day and the pause
    Given the tasks:
      | title    | list | sprint | status      |
      | Into     | next |        | open        |
      | Out      |      | today  | open        |
      | Running  |      | today  | in_progress |
    When I send the admin form "/admin/tasks/{task:Into}/move/today"
    And I send the admin form "/admin/tasks/{task:Out}/move/next"
    And I send the admin form "/admin/tasks/{task:Running}/move/next"
    Then the events of "Into" read "moved next to {day:today}"
    And the events of "Out" read "moved {day:today} to next"
    And the events of "Running" read "moved {day:today} to next / in_progress to open"

  Scenario: Scheduling a task records the move into, between and out of sprints
    Given the tasks:
      | title      | list | sprint    |
      | Later      | next |           |
      | From today |      | today     |
      | Unschedule |      | today + 2 |
      | Today      | next |           |
    When I send the admin form "/admin/tasks/{task:Later}/schedule" with:
      | sprint_on | {day:today + 2} |
    And I send the admin form "/admin/tasks/{task:From today}/schedule" with:
      | sprint_on | {day:today + 2} |
    And I send the admin form "/admin/tasks/{task:Unschedule}/schedule" with:
      | sprint_on | |
    And I send the admin form "/admin/tasks/{task:Today}/schedule" with:
      | sprint_on | {day:today} |
    And I send the admin form "/admin/tasks" with:
      | filter          | next            |
      | task[title]     | Plan it         |
      | task[note]      |                 |
      | task[tags]      | money           |
      | task[sprint_on] | {day:today + 1} |
    Then the events of "Later" read "moved next to {day:today + 2}"
    And the events of "From today" read "moved {day:today} to {day:today + 2}"
    And the events of "Unschedule" read "moved {day:today + 2} to next"
    And the events of "Today" read "moved next to {day:today}"
    And the events of "Plan it" read "tagged money / moved next to {day:today + 1}"

  Scenario: Dropping a sprint records the move back to each task's list, and the record outlives the sprint
    Given the tasks:
      | title  | sprint    | list     |
      | Plain  | today + 2 |          |
      | Synced | today + 2 |          |
    And the task sources:
      | task   | url                                                    |
      | Synced | https://github.com/aaronmallen/aaronmallen.me/issues/9 |
    When I visit "/admin/settings/tagging"
    And I send the admin form "/admin/tasks/sprints/{sprint:today + 2}/delete"
    Then the events of "Plain" read "moved {day:today + 2} to next"
    And the events of "Synced" read "moved {day:today + 2} to external"
    And the database reads "0" for:
      """
      SELECT count(*) FROM sprints WHERE sprint_date = '{day:today + 2}'
      """

  Scenario: Saving a task records each tag it adds and takes off, and nothing for the same tags
    Given the tasks:
      | title  |
      | Tagged |
      | Same   |
    When I save the task "Tagged" in the admin with:
      | task[tags] | money, home |
    And I save the task "Tagged" in the admin with:
      | task[tags] | money |
    And I save the task "Same" in the admin with:
      | task[tags] | money |
    And I save the task "Same" in the admin with:
      | task[tags] | money |
    Then the events of "Tagged" read "tagged money / tagged home / untagged home"
    And the events of "Same" read "tagged money"

  Scenario: Each status change records where it came from and went
    Given the tasks:
      | title    | list | sprint | status      |
      | Start    |      | today  | open        |
      | Listed   | next |        | open        |
      | Pause    |      | today  | in_progress |
      | Complete | next |        | in_progress |
      | Cancel   | next |        | open        |
      | Reopen   | next |        | done        |
    When I send the admin form "/admin/tasks/{task:Start}/start"
    And I send the admin form "/admin/tasks/{task:Listed}/start"
    And I send the admin form "/admin/tasks/{task:Pause}/stop"
    And I send the admin form "/admin/tasks/{task:Complete}/complete"
    And I send the admin form "/admin/tasks/{task:Cancel}/cancel"
    And I send the admin form "/admin/tasks/{task:Reopen}/reopen"
    And I send the admin form "/admin/tasks/{task:Start}/complete"
    Then the events of "Start" read "open to in_progress / in_progress to done"
    And the events of "Listed" read "moved next to {day:today} / open to in_progress"
    And the events of "Pause" read "in_progress to open"
    And the events of "Complete" read "in_progress to done"
    And the events of "Cancel" read "open to canceled"
    And the events of "Reopen" read "done to open"
    And the database reads "true" for:
      """
      SELECT bool_and(occurred_at BETWEEN now() - interval '1 minute' AND now()) FROM task_events
      """

  Scenario: Completing a closed task records nothing, and deleting a task takes its events
    Given the tasks:
      | title    | status   |
      | Finished | done     |
      | Dropped  | canceled |
      | Gone     | open     |
    When I send the admin form "/admin/tasks/{task:Finished}/complete" with:
      | filter | completed |
    And I send the admin form "/admin/tasks/{task:Dropped}/complete" with:
      | filter | completed |
    And I send the admin form "/admin/tasks/{task:Gone}/move/someday"
    And I send the admin form "/admin/tasks/{task:Gone}/delete"
    Then the database holds 0 task_events rows
