Feature: Task rows and their actions
  Each row leads with the task's key, marks its state on a meta line, and offers the moves, start, stop, complete,
  cancel and reopen that suit it.

  Background:
    Given I am signed in to the admin

  Scenario Outline: Each <filter> task leads with its key and links its title and pen back to the tab
    Given the tasks:
      | title | list   | sprint   | status   |
      | One   | <list> | <sprint> | <status> |
      | Two   | <list> | <sprint> | <status> |
    When I visit "/admin/tasks?filter=<filter>"
    Then the page parts ".task .record-key" read in any order "1 | 2"
    And the page part ".task a.task-title:text-is('One')" has "href" set to "/admin/tasks/{task:One}?filter=<filter>&origin=tasks"
    And the page part ".task:has(.task-title:text-is('One')) .task-acts > :last-child" has "href" set to "/admin/tasks/{task:One}/edit?filter=<filter>&origin=tasks"
    And the page has no axe breaches in light or dark

    Examples:
      | filter    | list    | sprint    | status |
      | today     |         | today     | open   |
      | upcoming  |         | today + 1 | open   |
      | next      | next    |           | open   |
      | someday   | someday |           | open   |
      | completed | next    |           | done   |

  Scenario: The row marks a task done, in progress, or neither
    Given the tasks:
      | title         | sprint | status      |
      | Filed already |        | done        |
      | Doing it      | today  | in_progress |
    When I visit "/admin/tasks?filter=completed"
    Then the page has ".task.done .task-title:text-is('Filed already')"
    And the page has no ".task.canceled"
    When I visit "/admin/tasks"
    Then the page has ".task.doing"
    And the page part ".task-meta .task-mark.blue" holds "in progress"
    Given the tasks:
      | title     |
      | Open task |
    When I visit "/admin/tasks?filter=next"
    Then the page has ".task"
    And the page has no ".task.doing, .task.done"

  Scenario: The meta line reads in progress, blocked by, carried, source, tags, blocking
    Given the tasks:
      | title   | sprint | status      | tags |
      | Busy    | today  | in_progress | ruby |
      | Blocker |        | open        |      |
      | Blocked |        | open        |      |
    And the database runs:
      """
      UPDATE tasks SET carried_count = 1 WHERE title = 'Busy'
      """
    And the task_links table holds the rows:
      | from_task_id  | to_task_id    | type   |
      | {task:Blocker} | {task:Busy}   | blocks |
      | {task:Busy}    | {task:Blocked} | blocks |
    And the task_sources table holds the rows:
      | task_id     | provider | remote_id | url                                                    |
      | {task:Busy} | github   | 7         | https://github.com/aaronmallen/aaronmallen.me/issues/7 |
    When I visit "/admin/tasks"
    Then the meta parts of ".task.doing" are "blue pink sand task-source tag sand"

  Scenario: The meta line shows the time worked on a task not in progress
    Given the tasks:
      | title  | worked |
      | Worked | 5700   |
    When I visit "/admin/tasks?filter=next"
    Then the page part ".task-meta .task-mark:has(.fa-clock)" reads "1h 35m"

  Scenario Outline: The completed tab says the day and time a task was <status>
    Given the tasks:
      | title         | status   |
      | Filed already | <status> |
    And the database runs:
      """
      UPDATE tasks SET completed_at = '2026-09-18 11:20 America/Chicago'
      """
    When I visit "/admin/tasks?filter=completed"
    Then the page part ".task-finished" reads "<status> Sep 18 · 11:20"
    And the page part ".task-finished time" has "datetime" set to "2026-09-18T11:20:00-05:00"

    Examples:
      | status   |
      | done     |
      | canceled |

  Scenario: An open row offers start, cancel and a keyed complete, and no delete, box or edit form
    Given the tasks:
      | title    | status | worked |
      | Open one | open   |        |
      | Closed   | done   |        |
    When I visit "/admin/tasks?filter=next"
    Then the page has ".task-acts form[action$='/start']"
    And the page has "form[action$='/cancel']"
    And the page has ".task-acts form[data-task-act='complete'] details.task-complete"
    And the page has "details.task-complete > summary.bt.sm[aria-keyshortcuts='x'][data-key='x']"
    And the page has no ".task-box, .task > form"
    And the page has no ".task-acts form[action$='/delete'], .task [name^='task[']"
    And the page part ".task .task-acts > :last-child" has "data-task-open-edit" set to ""
    And the page part ".task .task-acts > :last-child" has "aria-label" set to "Edit"
    And the page part ".task .task-acts > :last-child" has "title" set to "Edit"
    And the page has ".task .task-acts > :last-child i.fa-pen-to-square[aria-hidden='true']"

  Scenario: A row with tracked time, or a running session, completes from a keyed submit with no question
    Given the tasks:
      | title   | sprint | status      | worked |
      | Tracked |        | open        | 1800   |
      | Running | today  | in_progress |        |
    And the work_sessions table holds the rows:
      | task_id        | started_at |
      | {task:Running} | now        |
    When I visit "/admin/tasks?filter=next"
    Then the page has ".task-acts form[data-task-act='complete'] > button[type=submit][data-key='x']"
    And the page has no ".task-complete, .task-complete-ask"
    When I visit "/admin/tasks"
    Then the page has ".task-acts form[data-task-act='complete'] > button[type=submit][data-key='x']"
    And the page has no ".task-complete, .task-complete-ask"
    And the page has "form[action$='/complete']"
    And the page has 1 of "form[action$='/stop']"
    And the page has "form[action$='/cancel']"
    And the page has no "form[action$='/start']"

  Scenario: The read page keeps the pen off its actions
    Given the tasks:
      | title    |
      | Open one |
    When I visit "/admin/tasks/{task:Open one}?filter=next"
    Then the page has no ".task-stbar .fa-pen-to-square"

  Scenario: Each list offers the moves on either side, keyed toward today
    Given the tasks:
      | title       | list    | sprint    | status      |
      | In today    |         | today     | open        |
      | Running now |         | today     | in_progress |
      | In next     | next    |           | open        |
      | In someday  | someday |           | open        |
      | Waiting     |         | today + 1 | open        |
    When I visit "/admin/tasks?filter=next"
    Then the page parts ".task-acts form[action*='/move/']" have "action" set to "/admin/tasks/{task:In next}/move/today | /admin/tasks/{task:In next}/move/someday"
    And the page parts ".task-acts form[action*='/move/']:has(button[data-key='m'])" have "action" set to "/admin/tasks/{task:In next}/move/today"
    And the page has no ".task-acts form[action$='/move/today'][data-confirm]"
    When I visit "/admin/tasks?filter=someday"
    Then the page parts ".task-acts form[action*='/move/']" have "action" set to "/admin/tasks/{task:In someday}/move/next"
    And the page parts ".task-acts form[action*='/move/']:has(button[data-key='m'])" have "action" set to "/admin/tasks/{task:In someday}/move/next"
    When I visit "/admin/tasks?filter=today"
    Then the page parts ".task-acts form[action*='/move/']" have "action" set to "/admin/tasks/{task:In today}/move/next | /admin/tasks/{task:Running now}/move/next"
    And the page parts ".task-acts form[action*='/move/']:has(button[data-key='m'])" have "action" set to "/admin/tasks/{task:In today}/move/next | /admin/tasks/{task:Running now}/move/next"
    And the page part ".task:has-text('In today') .task-acts form[action$='/move/next']" has no "data-confirm"
    And the page part ".task:has-text('Running now') .task-acts form[action$='/move/next']" has "data-confirm" set to "Move Running now to Next? It stops and goes back to open."
    When I visit "/admin/tasks?filter=upcoming"
    Then the page parts ".task-acts form[action*='/move/']" have "action" set to "/admin/tasks/{task:Waiting}/move/today | /admin/tasks/{task:Waiting}/move/next"
    And the page parts ".task-acts form[action*='/move/']:has(button[data-key='m'])" have "action" set to "/admin/tasks/{task:Waiting}/move/today"

  Scenario: A move files the task on its list and follows it there, and today joins the sprint
    Given the tasks:
      | title    |
      | Move me  |
      | Today me |
    When I send the admin form "/admin/tasks/{task:Move me}/move/someday"
    Then the admin answer goes to "/admin/tasks?filter=someday"
    When I send the admin form "/admin/tasks/{task:Today me}/move/today"
    Then the database soon holds "Move me, someday, \nToday me, , {day:today}" for:
      """
      SELECT title, coalesce(list::text, ''), coalesce(to_char(sprint_date, 'YYYY-MM-DD'), '')
      FROM tasks LEFT JOIN sprints ON sprints.id = sprint_id ORDER BY title
      """
    When I send the admin form "/admin/tasks/{task:Move me}/move/later"
    Then the server answers 404

  Scenario: A start sets the task in progress in today's sprint and lands on today
    Given the tasks:
      | title      | list    |
      | Start me   | someday |
    When I send the admin form "/admin/tasks/{task:Start me}/start"
    Then the admin answer goes to "/admin/tasks?filter=today"
    And the database soon holds "in_progress, , {day:today}" for:
      """
      SELECT status, coalesce(list::text, ''), to_char(sprint_date, 'YYYY-MM-DD') FROM tasks JOIN sprints ON sprints.id = sprint_id
      """

  Scenario: A task moved out of today while in progress offers start again
    Given the tasks:
      | title   | sprint | status      |
      | Running | today  | in_progress |
    When I visit "/admin/tasks?filter=today"
    Then the page has no "form[action$='/start']"
    When I send the admin form "/admin/tasks/{task:Running}/move/someday"
    And I visit "/admin/tasks?filter=someday"
    Then the page has "form[action$='/start']"

  Scenario Outline: A start clears the close time of a <status> task
    Given the tasks:
      | title  | status   |
      | Closed | <status> |
    When I send the admin form "/admin/tasks/{task:Closed}/start" with:
      | filter | completed |
    Then the database soon holds "in_progress, true" for:
      """
      SELECT status, completed_at IS NULL FROM tasks
      """

    Examples:
      | status   |
      | done     |
      | canceled |

  Scenario: A stop takes the task out of progress, keeps it in the sprint and says so
    Given the tasks:
      | title   | sprint | status      |
      | Running | today  | in_progress |
    When I send the admin form "/admin/tasks/{task:Running}/stop" with:
      | filter | today |
    Then the admin answer goes to "/admin/tasks?filter=today"
    And the database soon holds "open, {day:today}" for:
      """
      SELECT status, to_char(sprint_date, 'YYYY-MM-DD') FROM tasks JOIN sprints ON sprints.id = sprint_id
      """
    When I follow the admin answer
    Then the page part "[data-toast] .toast" reads "Stopped · it waits in the sprint"

  Scenario Outline: A stop leaves a <status> task as it was and says it is not in progress
    Given the tasks:
      | title  | sprint   | status   | list   |
      | Closed | <sprint> | <status> | <list> |
    When I send the admin form "/admin/tasks/{task:Closed}/stop" with:
      | filter | today |
    Then the database soon holds "<status>, <closed>, <list>" for:
      """
      SELECT status, completed_at IS NOT NULL, coalesce(list::text, '') FROM tasks
      """
    When I follow the admin answer
    Then the page part "[data-toast] .toast" reads "That task is not in progress"

    Examples:
      | status   | sprint | list | closed |
      | done     | today  |      | true   |
      | canceled | today  |      | true   |
      | open     |        | next | false  |

  Scenario: A complete marks the task done when it was finished and keeps the list open
    Given the tasks:
      | title      | list    |
      | Finish me  | someday |
    When I send the admin form "/admin/tasks/{task:Finish me}/complete" with:
      | filter | someday |
    Then the admin answer goes to "/admin/tasks?filter=someday"
    And the database soon holds "done, true" for:
      """
      SELECT status, completed_at IS NOT NULL FROM tasks
      """
    When I visit "/admin/tasks?filter=someday"
    Then the task rows read ""
    When I visit "/admin/tasks?filter=completed"
    Then the page has "form[action$='/reopen']"
    And the page has no "form[action$='/complete']"

  Scenario Outline: A reopen opens a <status> task again, clears its time and says so
    Given the tasks:
      | title  | status   |
      | Closed | <status> |
    When I send the admin form "/admin/tasks/{task:Closed}/reopen" with:
      | filter | completed |
    Then the admin answer goes to "/admin/tasks?filter=completed"
    And the database soon holds "open, true" for:
      """
      SELECT status, completed_at IS NULL FROM tasks
      """
    When I follow the admin answer
    Then the page part "[data-toast] .toast" reads "Reopened"
    When I visit "/admin/tasks?filter=next"
    Then the task rows read "Closed"

    Examples:
      | status   |
      | done     |
      | canceled |

  Scenario Outline: A <act> leaves a closed <status> task as it was and says it is closed already
    Given the tasks:
      | title  | status   |
      | Closed | <status> |
    And the database runs:
      """
      UPDATE tasks SET completed_at = date_trunc('second', now()) - interval '1 day'
      """
    When I send the admin form "/admin/tasks/{task:Closed}/<act>" with:
      | filter | completed |
    Then the database soon holds "<status>, true" for:
      """
      SELECT status, completed_at < now() - interval '23 hours' FROM tasks
      """
    When I follow the admin answer
    Then the page part "[data-toast] .toast" reads "That task is closed already"

    Examples:
      | status   | act      |
      | done     | complete |
      | canceled | complete |
      | done     | cancel   |

  Scenario: A cancel marks the task canceled with a close time, says so and keeps the list open
    Given the tasks:
      | title     | list    |
      | Cancel me | someday |
    When I visit "/admin/tasks?filter=someday"
    Then the page has "form[action$='/cancel']"
    When I send the admin form "/admin/tasks/{task:Cancel me}/cancel" with:
      | filter | someday |
    Then the admin answer goes to "/admin/tasks?filter=someday"
    And the database soon holds "canceled, true" for:
      """
      SELECT status, completed_at IS NOT NULL FROM tasks
      """
    When I follow the admin answer
    Then the page part "[data-toast] .toast" reads "Canceled"
    And the task rows read ""

  Scenario: The completed tab marks a canceled task and offers only reopen
    Given the tasks:
      | title   | status   |
      | Dropped | canceled |
    When I visit "/admin/tasks?filter=completed"
    Then the page part ".task.canceled .task-meta" holds "canceled"
    And the page has ".task-acts form[action$='/reopen'] button"
    And the page has no "form[action$='/cancel'], form[action$='/complete'], form[action*='/move/']"

  Scenario: A canceled task stays out of a planned sprint's card and count
    Given the tasks:
      | title    | sprint    | status   |
      | Still on | today + 1 | open     |
      | Dropped  | today + 1 | canceled |
      | Gone too | today + 2 | canceled |
    When I visit "/admin/tasks?filter=upcoming"
    Then the task rows read "Still on"
    And the page has ".cols .card-note:has-text('0 planned')"

  Scenario: The link finder names a canceled task's place
    Given the tasks:
      | title    | status   |
      | Still on | open     |
      | Dropped  | canceled |
    When I visit "/admin/tasks/{task:Still on}?filter=next&link_q=Dropped"
    Then the page part ".task-link-target .task-link-place" reads "canceled"
