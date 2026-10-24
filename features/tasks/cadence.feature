Feature: The cadence picker in the admin
  The task forms set, change and clear how often a task repeats, and show only the fields a cadence needs.

  Background:
    Given I am signed in to the admin

  Scenario Outline: Capturing a task sets <kind>
    When I send the admin form "/admin/tasks" with:
      | task[title]             | Water the plants |
      | task[list]              | next             |
      | task[recur][cadence]    | <cadence>        |
      | task[recur][every]      | <every>          |
      | task[recur][weekday]    | <weekday>        |
      | task[recur][week]       | <week>           |
      | task[recur][day]        | <day>            |
      | task[recur][month]      | <month>          |
      | task[recur][starts_on]  | <starts>         |
    Then the database reads "<stored>" for:
      """
      SELECT concat_ws(' ', cadence, every, weekday, week, day, month, starts_on) FROM task_series
      """

    Examples:
      | kind                       | cadence       | every | weekday | week | day | month | starts     | stored                  |
      | every few days             | days          | 3     |         |      |     |       |            | days 3                  |
      | every few weeks            | weeks         | 2     | 4       |      |     |       | 2026-01-01 | weeks 2 4 2026-01-01    |
      | a day each month           | month_day     |       |         |      | 31  |       |            | month_day 31            |
      | the last day of each month | month_end     |       |         |      |     |       |            | month_end               |
      | a weekday each month       | month_weekday |       | 5       | -1   |     |       |            | month_weekday 5 -1      |
      | a date each year           | yearly        |       |         |      | 29  | 2     |            | yearly 29 2             |

  Scenario: Capturing a task starts every few weeks today, and sets nothing when it never repeats
    When I send the admin form "/admin/tasks" with:
      | task[title]            | Review |
      | task[list]             | next   |
      | task[recur][cadence]   | weeks  |
      | task[recur][every]     | 1      |
      | task[recur][weekday]   | 1      |
      | task[recur][starts_on] |        |
    And I send the admin form "/admin/tasks" with:
      | task[title]          | Plain |
      | task[list]           | next  |
      | task[recur][cadence] |       |
      | task[recur][every]   | 3     |
    Then the database reads "Review, {day:today}" for:
      """
      SELECT title, starts_on::text FROM task_series JOIN tasks ON tasks.id = task_id
      """

  Scenario: Capturing a task with a cadence it refuses keeps the task out and keeps the kind picked
    When I send the admin form "/admin/tasks" with:
      | task[title]          | Water the plants |
      | task[list]           | next             |
      | task[recur][cadence] | days             |
      | task[recur][every]   | 0                |
    Then the server answers 422
    And the database holds 0 tasks rows
    When I look at the admin answer
    Then the page part "#new-every-error" holds "Give a whole number from 1 to 365."
    And the page has "#new-cadence option[selected][value='days']"
    And the page parts "main [name^='task[recur]']:not([disabled])" have "name" set to "task[recur][cadence] | task[recur][every]"

  Scenario: The new task page offers each cadence after never, bounds its fields and hides them until one is picked
    When I visit "/admin/tasks/new"
    Then the page parts "#new-cadence option" have "value" set to " | days | weeks | month_day | month_end | month_weekday | yearly"
    And the page part "#new-every" has "min" set to "1"
    And the page part "#new-every" has "max" set to "365"
    And the page part "#new-day" has "min" set to "1"
    And the page part "#new-day" has "max" set to "31"
    And the page parts "#new-week option" have "value" set to "1 | 2 | 3 | 4 | -1"
    And the page has no "main [data-cadence-for]:not([hidden])"
    And the page parts "main [name^='task[recur]']:not([disabled])" have "name" set to "task[recur][cadence]"
    And the page has no axe breaches in light or dark
    When I visit "/admin/tasks"
    Then the page has "#task-create form select[name='task[recur][cadence]']"

  Scenario: The picker shows only the fields each cadence needs, and fits a phone
    Given the window is 375 by 800
    When I visit "/admin/tasks/new"
    And I pick "On a weekday each month" in the page select "#new-cadence"
    Then the page parts "main [data-cadence-for]:not([hidden]) :is(input, select):not([disabled])" have "name" set to "task[recur][week] | task[recur][weekday]"
    When I pick "Every few weeks" in the page select "#new-cadence"
    Then the page parts "main [data-cadence-for]:not([hidden]) :is(input, select):not([disabled])" have "name" set to "task[recur][every] | task[recur][weekday] | task[recur][starts_on]"
    And the page shows the part "label[for='new-every'] :text-is('Weeks apart')"
    And the page hides "label[for='new-every'] :text-is('Days apart')"
    When I pick "On a date each year" in the page select "#new-cadence"
    Then "the page" does not scroll sideways
    When I pick "Never" in the page select "#new-cadence"
    Then the page has no "main [data-cadence-for]:not([hidden]) :is(input, select):not([disabled])"

  Scenario: The task panel's editor saves every few weeks
    Given the tasks:
      | title            |
      | Water the plants |
    When I visit "/admin/tasks?filter=next"
    And I click the page part ".task-title:text-is('Water the plants')"
    And I click "Edit" in "dialog#task-panel[open]"
    And I pick "Every few weeks" in the page select "dialog#task-panel[open] select[name='task[recur][cadence]']"
    Then the page parts "dialog#task-panel[open] [data-cadence-for]:not([hidden]) :is(input, select):not([disabled])" have "name" set to "task[recur][every] | task[recur][weekday] | task[recur][starts_on]"
    When I set the page field "dialog#task-panel[open] [name='task[recur][every]']" to "2"
    And I click "Save" in "dialog#task-panel[open]"
    Then the page part "dialog#task-panel[open] [data-task-read] h1" reads "Water the plants"
    And the database soon holds "weeks, 2" for:
      """
      SELECT cadence, every FROM task_series
      """

  Scenario: The editor shows a task's cadence with only its fields enabled
    Given the tasks:
      | title            |
      | Water the plants |
    And the task_series table holds the rows:
      | task_id                 | cadence       | week | weekday |
      | {task:Water the plants} | month_weekday | -1   | 5       |
    When I visit "/admin/tasks/{task:Water the plants}/edit?filter=next"
    Then the page has "#task-1-form [name='task[recur][cadence]'] option[selected][value='month_weekday']"
    And the page parts "#task-1-form [name^='task[recur]']:not([disabled])" have "name" set to "task[recur][cadence] | task[recur][week] | task[recur][weekday]"
    And the page part "#task-1-form select[name='task[recur][week]'] option[selected]" has "value" set to "-1"
    And the page has no axe breaches in light or dark

  Scenario: A weekly copy is planned two weeks on and says weeks count from its first day
    Given the tasks:
      | title            |
      | Water the plants |
    And the task "Water the plants" repeats every 2 weeks from "today - 7"
    When I send the admin form "/admin/tasks/{task:Water the plants}/complete" with:
      | filter | next |
    Then the database reads "{day:today + 7}" for:
      """
      SELECT sprint_date::text FROM sprints JOIN tasks ON tasks.sprint_id = sprints.id WHERE tasks.id = 2
      """
    When I visit "/admin/tasks/2/edit?filter=upcoming"
    Then the page has "#task-2-form .hint:text-is('Weeks count from this day.')"

  Scenario: Saving a task changes, sets, keeps and clears its cadence
    Given the tasks:
      | title  |
      | Change |
      | Set    |
      | Keep   |
      | Clear  |
    And the task "Change" repeats every 3 days
    And the task "Keep" repeats every 3 days
    And the task "Clear" repeats every 3 days
    When I save the task "Change" in the admin with:
      | task[recur][cadence] | yearly |
      | task[recur][month]   | 7      |
      | task[recur][day]     | 4      |
    And I save the task "Set" in the admin with:
      | task[recur][cadence] | month_end |
    And I save the task "Keep" in the admin with:
      | task[note] | still |
    And I save the task "Clear" in the admin with:
      | task[recur][cadence] |  |
    Then the database reads "Change, yearly, , 4, 7 / Keep, days, 3, ,  / Set, month_end, , , " for:
      """
      SELECT title, cadence, every, day, month FROM task_series JOIN tasks ON tasks.id = task_id ORDER BY title
      """

  Scenario: Saving a copy its series has moved past refuses the cadence and leaves one series
    Given the tasks:
      | title            |
      | Water the plants |
    And the task "Water the plants" repeats every 1 days
    When I send the admin form "/admin/tasks/{task:Water the plants}/complete" with:
      | filter | next |
    And I save the task "Water the plants" in the admin with:
      | task[recur][cadence] | days |
      | task[recur][every]   | 2    |
    Then the server answers 422
    When I look at the admin answer
    Then the page part "#task-1-form .field-error" holds "Its series has moved on to a newer copy. Set the cadence there."
    And the database holds 1 task_series row

  Scenario: Saving a refused cadence keeps the title as it was
    Given the tasks:
      | title            |
      | Water the plants |
    When I save the task "Water the plants" in the admin with:
      | task[title]          | Water the ferns |
      | task[recur][cadence] | month_day       |
      | task[recur][day]     |                 |
    Then the server answers 422
    And the database reads "Water the plants" for:
      """
      SELECT title FROM tasks
      """

  Scenario: An imported task shows no cadence picker and refuses a cadence
    Given the tasks:
      | title        | list     |
      | Fix the feed | external |
    And the task sources:
      | task         | url                                                    |
      | Fix the feed | https://github.com/aaronmallen/aaronmallen.me/issues/4 |
    When I visit "/admin/tasks/{task:Fix the feed}/edit?filter=external"
    Then the page has no "#task-1-form [name^='task[recur]']"
    When I save the task "Fix the feed" in the admin with:
      | task[list]           | external |
      | task[recur][cadence] | days     |
      | task[recur][every]   | 3        |
    Then the server answers 422
    And the database holds 0 task_series rows
