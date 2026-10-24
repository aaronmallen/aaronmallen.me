Feature: Capturing, placing, scheduling and moving tasks in the admin
  The admin's task forms capture and edit tasks, place them in today's sprint, schedule and move them, and
  leave a closed task where it closed.

  Background:
    Given I am signed in to the admin

  Scenario: Capturing a task needs a title, ignores an old type and puts it after the tasks in its list
    Given the tasks:
      | title | position |
      | older | 1        |
      | old   | 2        |
    When I send the admin form "/admin/tasks" with:
      | filter     | next |
      | task[note] |      |
    Then the server answers 422
    When I send the admin form "/admin/tasks" with:
      | filter            | next |
      | task[title]       | new  |
      | task[task_type_id] | 1   |
    Then the next list reads "older, old, new"
    When I save the task "new" in the admin with:
      | task[title]        | Email the accountant |
      | task[task_type_id] | 1                    |
    Then the next list reads "older, old, Email the accountant"

  Scenario: Completing a task in a live series carries its tags and photos to the next copy
    Given the photo "0123456789abcdef0123456789abcdef.jpg" uploaded 1 days ago
    And the tasks:
      | title  | tags | note                                                         |
      | Plants | home | ![A photo](/media/0123456789abcdef0123456789abcdef.jpg)      |
    And the database runs:
      """
      INSERT INTO photo_claims (photo_id, owner, owner_id) VALUES (1, 'task', 1);
      """
    And the task "Plants" repeats every 1 days
    When I send the admin form "/admin/tasks/{task:Plants}/complete" with:
      | filter | completed |
    Then the database reads "2, home, 1" for:
      """
      SELECT tasks.id, name, photo_id FROM tasks JOIN task_tags ON task_id = tasks.id JOIN tags ON tags.id = tag_id
      JOIN photo_claims ON owner = 'task' AND owner_id = tasks.id WHERE tasks.id = 2
      """

  Scenario: Deleting a task imported from GitHub takes its source with it
    Given the tasks:
      | title | list     |
      | Gone  | external |
    And the task sources:
      | task | url                                                     |
      | Gone | https://github.com/aaronmallen/aaronmallen.me/issues/21 |
    When I send the admin form "/admin/tasks/{task:Gone}/delete"
    Then the database holds 0 task_sources rows

  Scenario: Placing a task in today's sprint puts it after the task it follows, or first
    Given the tasks:
      | title     | sprint    | position | list |
      | first     | today     | 1        |      |
      | second    | today     | 2        |      |
      | third     | today     | 3        |      |
      | tomorrow  | today + 1 | 4        |      |
      | listed    |           | 5        | next |
    When I send the admin form "/admin/tasks/{task:first}/place" with:
      | after | {task:tomorrow} |
    Then the server answers 422
    When I send the admin form "/admin/tasks/{task:first}/place" with:
      | after | {task:listed} |
    Then the server answers 422
    And today's sprint reads "first, second, third"
    When I send the admin form "/admin/tasks/{task:first}/place" with:
      | after | {task:third} |
    Then today's sprint reads "second, third, first"
    When I send the admin form "/admin/tasks/{task:first}/place"
    Then today's sprint reads "first, second, third"

  Scenario: Scheduling a task in progress for a later day puts it back to open on that day's sprint
    Given the tasks:
      | title   | sprint | status      |
      | Running | today  | in_progress |
    When I send the admin form "/admin/tasks/{task:Running}/schedule" with:
      | sprint_on | {day:today + 2} |
    Then the database reads "open, {day:today + 2}" for:
      """
      SELECT status, sprint_date::text FROM tasks JOIN sprints ON sprints.id = sprint_id
      """

  Scenario Outline: Scheduling a <status> task leaves it closed in its list and opens no sprint
    Given the tasks:
      | title                | status   |
      | Email the accountant | <status> |
    When I visit "/admin/settings/tagging"
    And I send the admin form "/admin/tasks/{task:Email the accountant}/schedule" with:
      | sprint_on | {day:today + 3} |
    When I send the admin form "/admin/tasks/{task:Email the accountant}/schedule" with:
      | sprint_on | {day:today} |
    And I save the task "Email the accountant" in the admin with:
      | task[title]     | Call the accountant |
      | task[sprint_on] | {day:today + 3}     |
    Then the database reads "Email the accountant, <status>, next, " for:
      """
      SELECT title, status, list, coalesce(sprint_id::text, '') FROM tasks
      """
    And the database holds 0 sprints rows
    When I follow the admin answer
    Then the toast says "That task is closed already"
    When I send the admin form "/admin/tasks/{task:Email the accountant}/schedule" with:
      | sprint_on | {day:today + 3} |
    And I follow the admin answer
    Then the toast says "That task is closed already"

    Examples:
      | status   |
      | done     |
      | canceled |

  Scenario Outline: Clearing the date of a <status> task leaves it in the sprint it closed in
    Given the tasks:
      | title | sprint    | status   |
      | Ran   | today - 1 | <status> |
    When I send the admin form "/admin/tasks/{task:Ran}/schedule" with:
      | sprint_on | |
    Then the database reads "{day:today - 1}, " for:
      """
      SELECT sprint_date::text, coalesce(list::text, '') FROM tasks JOIN sprints ON sprints.id = sprint_id
      """

    Examples:
      | status   |
      | done     |
      | canceled |

  Scenario: Moving or unscheduling a task in progress leaves it open in its new list
    Given the tasks:
      | title      | sprint | list | status      |
      | To next    | today  |      | in_progress |
      | To someday | today  |      | in_progress |
      | To ext     | today  |      | in_progress |
      | Unschedule | today  |      | in_progress |
      | Listed     |        | next | in_progress |
      | Finished   | today  |      | done        |
    When I send the admin form "/admin/tasks/{task:To next}/move/next"
    And I send the admin form "/admin/tasks/{task:To someday}/move/someday"
    And I send the admin form "/admin/tasks/{task:To ext}/move/external"
    And I send the admin form "/admin/tasks/{task:Unschedule}/schedule" with:
      | sprint_on | |
    And I send the admin form "/admin/tasks/{task:Listed}/move/today"
    And I send the admin form "/admin/tasks/{task:Finished}/move/next"
    Then the database reads "To next, next, open / To someday, someday, open / To ext, external, open / Unschedule, next, open / Listed, , in_progress / Finished, next, done" for:
      """
      SELECT title, coalesce(list::text, ''), status FROM tasks ORDER BY id
      """

  Scenario: Dropping a sprint leaves a task in progress open in next and a finished task finished
    Given the tasks:
      | title    | sprint    | status      |
      | Running  | today + 2 | in_progress |
      | Finished | today + 2 | done        |
    When I send the admin form "/admin/tasks/sprints/{sprint:today + 2}/delete"
    Then the database reads "Running, next, open / Finished, next, done" for:
      """
      SELECT title, list, status FROM tasks ORDER BY id
      """
