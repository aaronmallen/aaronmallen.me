Feature: Planning a sprint ahead
  The upcoming tab opens sprints for days after today, fills them, and drops them, sending their tasks back to
  their lists.

  Background:
    Given I am signed in to the admin

  Scenario: Planning opens a sprint for a day after today, says which day and comes back to upcoming
    When I visit "/admin/tasks?filter=upcoming"
    And I send the admin form "/admin/tasks/sprints" with:
      | sprint_on | {day:today + 1} |
    Then the admin answer goes to "/admin/tasks?filter=upcoming"
    And the database soon holds "{day:today + 1}" for:
      """
      SELECT to_char(sprint_date, 'YYYY-MM-DD') FROM sprints WHERE sprint_date > (now() AT TIME ZONE 'America/Chicago')::date
      """
    When I follow the admin answer
    Then the page part "[data-toast] .toast" holds "{medium:today + 1}"

  Scenario: Planning a day that has a sprint says so rather than making a second
    Given the sprints table holds the rows:
      | sprint_date     |
      | {day:today + 1} |
    When I visit "/admin/tasks?filter=upcoming"
    And I send the admin form "/admin/tasks/sprints" with:
      | sprint_on | {day:today + 1} |
    And I follow the admin answer
    Then the page part "[data-toast] .toast" holds "already exists"
    And the database soon holds "1" for:
      """
      SELECT count(*) FROM sprints WHERE sprint_date > (now() AT TIME ZONE 'America/Chicago')::date
      """

  Scenario Outline: Planning <what> makes no sprint and says why
    When I visit "/admin/projects"
    Then the database soon holds "0" for:
      """
      SELECT count(*) FROM sprints
      """
    And I send the admin form "/admin/tasks/sprints" with:
      | sprint_on | <day> |
    Then the database soon holds "0" for:
      """
      SELECT count(*) FROM sprints WHERE sprint_date <= (now() AT TIME ZONE 'America/Chicago')::date - <before>
      """
    When I follow the admin answer
    Then the page part "[data-toast] .toast" reads "<said>"

    Examples:
      | what               | day             | before | said                                 |
      | today              | {day:today}     | 0      | Plan a sprint for a day after today  |
      | a day that is over | {day:today - 1} | 1      | Plan a sprint for a day after today  |
      | a day it can't read | soon           | 0      | Pick a day first                     |

  Scenario: The upcoming tab lists each planned sprint by its day, ready to fill
    Given the sprints table holds the rows:
      | sprint_date     |
      | {day:today + 1} |
    And the tasks:
      | title                | sprint    |
      | Tomorrow's work      | today + 1 |
      | Email the accountant |           |
    When I visit "/admin/tasks?filter=upcoming"
    Then the page part ".cols .card-title" reads "Tomorrow"
    And the page part ".cols .card-note" holds "{weekday:today + 1}"
    And the page part ".page-head-sub" holds "1 upcoming"
    And the page field ".cols form.quick-add [name='filter']" holds "next"
    And the page field ".cols form.quick-add [name='task[sprint_on]']" holds "{day:today + 1}"
    And the page field ".cols form.quick-add [name='task[title]']" holds ""
    And the page parts "details.sprint-pull .li-title" read "Email the accountant"
    And the page part "details.sprint-pull form" has "action" set to "/admin/tasks/{task:Email the accountant}/schedule"
    And the page part ".task-meta .task-mark.orange" holds "{short:today + 1}"
    And the page part "form[action='/admin/tasks/sprints/{sprint:today + 1}/delete']" has a "data-morph"
    And the page part "form[action='/admin/tasks/sprints/{sprint:today + 1}/delete']" has "data-confirm" set to "Drop the sprint for {medium:today + 1}? Its tasks go back to their lists."
    And the page has "form[action='/admin/tasks/sprints/{sprint:today + 1}/delete'] button.bt.warn.sm[type=submit] i.fa-trash-can"
    And the page has no axe breaches in light or dark
    When I visit "/admin/tasks?filter=next"
    Then the task rows read "Email the accountant"

  Scenario: An empty upcoming tab says nothing is planned
    When I visit "/admin/tasks?filter=upcoming"
    Then the page part ".empty" holds "No future sprints"

  Scenario: Dropping a sprint sends its tasks back to next, or external for an issue, and says so
    Given the tasks:
      | title        | sprint    |
      | Carried task | today + 1 |
      | From issue   | today + 1 |
    And the database runs:
      """
      UPDATE tasks SET carried_count = 4 WHERE title = 'Carried task'
      """
    And the task_sources table holds the rows:
      | task_id           | provider | remote_id | url                                                    |
      | {task:From issue} | github   | 7         | https://github.com/aaronmallen/aaronmallen.me/issues/7 |
    When I visit "/admin/tasks?filter=upcoming"
    And I send the admin form "/admin/tasks/sprints/{sprint:today + 1}/delete"
    Then the database soon holds "Carried task, next, 0, true\nFrom issue, external, 0, true" for:
      """
      SELECT title, list, carried_count, sprint_id IS NULL FROM tasks ORDER BY title
      """
    And the database soon holds "0" for:
      """
      SELECT count(*) FROM sprints WHERE sprint_date > (now() AT TIME ZONE 'America/Chicago')::date
      """
    When I follow the admin answer
    Then the page part "[data-toast] .toast" holds "went back to their lists"
    When I visit "/admin"
    Then the page has no "section.card[data-attention] .li:has-text('Carried task')"
    When I visit "/admin/tasks?filter=next"
    Then the page has ".task-title:text-is('Carried task')"
    And the page has no ".task-meta .task-mark.sand:has-text('carried')"

  Scenario: Dropping the sprint the day is running keeps it
    Given the sprints table holds the rows:
      | sprint_date |
      | {day:today} |
    When I visit "/admin/tasks?filter=upcoming"
    And I send the admin form "/admin/tasks/sprints/{sprint:today}/delete"
    Then the database soon holds "1" for:
      """
      SELECT count(*) FROM sprints WHERE sprint_date = (now() AT TIME ZONE 'America/Chicago')::date
      """

  Scenario: A capture with a sprint day goes straight into that sprint and lands on upcoming
    Given the sprints table holds the rows:
      | sprint_date     |
      | {day:today + 1} |
    When I visit "/admin/tasks?filter=upcoming"
    And I send the admin form "/admin/tasks" with:
      | filter          | next            |
      | task[title]     | Tomorrow's work |
      | task[sprint_on] | {day:today + 1} |
    Then the admin answer goes to "/admin/tasks?filter=upcoming"
    When I send the admin form "/admin/tasks" with:
      | filter          | next         |
      | task[title]     | Today's work |
      | task[sprint_on] | {day:today}  |
    Then the database soon holds "Today's work, {day:today}\nTomorrow's work, {day:today + 1}" for:
      """
      SELECT title, to_char(sprint_date, 'YYYY-MM-DD') FROM tasks JOIN sprints ON sprints.id = sprint_id ORDER BY title
      """

  Scenario Outline: A capture with <what> captures nothing, says why and lands on its tab
    When I visit "/admin/tasks?filter=next"
    And I send the admin form "/admin/tasks" with:
      | filter          | next          |
      | task[title]     | Refused work  |
      | task[sprint_on] | <day>         |
    Then the admin answer goes to "/admin/tasks?filter=next"
    And the tasks table holds 0 rows
    When I follow the admin answer
    Then the page part "[data-toast] .toast" holds "A sprint opens on today"

    Examples:
      | what                | day             |
      | a day that is over  | {day:today - 1} |
      | a day it can't read | next week       |

  Scenario: A refused capture sent again with a good day captures one task
    When I visit "/admin/tasks?filter=next"
    And I send the admin form "/admin/tasks" with:
      | filter          | next            |
      | task[title]     | Tomorrow's work |
      | task[sprint_on] | {day:today - 1} |
    And I send the admin form "/admin/tasks" with:
      | filter          | next            |
      | task[title]     | Tomorrow's work |
      | task[sprint_on] | {day:today + 1} |
    Then the database soon holds "Tomorrow's work" for:
      """
      SELECT string_agg(title, ', ') FROM tasks
      """

  Scenario Outline: Scheduling a planned task <how> says <said>
    Given the tasks:
      | title     | sprint    |
      | Scheduled | today + 2 |
    When I visit "/admin/tasks?filter=upcoming"
    And I send the admin form "/admin/tasks/{task:Scheduled}/schedule" with:
      | sprint_on | <day> |
    And I follow the admin answer
    Then the page part "[data-toast] .toast" holds "<said>"

    Examples:
      | how                    | day             | said                       |
      | for tomorrow           | {day:today + 1} | Scheduled for the          |
      | for today              | {day:today}     | Pulled into today's sprint |
      | with no day            |                 | Unscheduled · back in next |
      | for a day that is over | {day:today - 1} | A sprint opens on today    |

  Scenario: Unscheduling an imported task says it went back to external
    Given the tasks:
      | title      | sprint    |
      | From issue | today + 2 |
    And the task_sources table holds the rows:
      | task_id           | provider | remote_id | url                                                    |
      | {task:From issue} | github   | 7         | https://github.com/aaronmallen/aaronmallen.me/issues/7 |
    When I visit "/admin/tasks?filter=upcoming"
    And I send the admin form "/admin/tasks/{task:From issue}/schedule" with:
      | sprint_on |  |
    And I follow the admin answer
    Then the page part "[data-toast] .toast" holds "Unscheduled · back in external"

  Scenario: Scheduling pulls a task out of next onto a planned sprint
    Given the sprints table holds the rows:
      | sprint_date     |
      | {day:today + 1} |
    And the tasks:
      | title                |
      | Email the accountant |
    When I visit "/admin/tasks?filter=upcoming"
    And I send the admin form "/admin/tasks/{task:Email the accountant}/schedule" with:
      | sprint_on | {day:today + 1} |
    Then the database soon holds "{day:today + 1}" for:
      """
      SELECT to_char(sprint_date, 'YYYY-MM-DD') FROM tasks JOIN sprints ON sprints.id = sprint_id
      """

  Scenario: The editor schedules and unschedules a task, and leaves someday alone with no date
    Given the tasks:
      | title      | list    | sprint    |
      | Schedule   | next    |           |
      | Unschedule |         | today + 1 |
      | Parked     | someday |           |
    When I visit "/admin/tasks?filter=next"
    And I send the admin form "/admin/tasks/{task:Schedule}" with:
      | filter          | next            |
      | task[title]     | Schedule        |
      | task[sprint_on] | {day:today + 1} |
    And I send the admin form "/admin/tasks/{task:Unschedule}" with:
      | filter          | next       |
      | task[title]     | Unschedule |
      | task[sprint_on] |            |
    And I send the admin form "/admin/tasks/{task:Parked}" with:
      | filter          | someday |
      | task[title]     | Parked  |
      | task[sprint_on] |         |
    Then the database soon holds "Parked, someday, -\nSchedule, -, {day:today + 1}\nUnschedule, next, -" for:
      """
      SELECT title, coalesce(list::text, '-'), coalesce(to_char(sprint_date, 'YYYY-MM-DD'), '-')
      FROM tasks LEFT JOIN sprints ON sprints.id = sprint_id ORDER BY title
      """

  Scenario Outline: The editor refuses <what>, leaves the task as it was and says why
    Given the tasks:
      | title                | tags  |
      | Email the accountant | admin |
    When I visit "/admin/tasks?filter=next"
    And I send the admin form "/admin/tasks/{task:Email the accountant}" with:
      | filter          | next                |
      | task[title]     | Call the accountant |
      | task[tags]      |                     |
      | task[sprint_on] | <day>               |
    Then the database soon holds "Email the accountant, admin, true" for:
      """
      SELECT title, string_agg(name, ' '), bool_and(sprint_id IS NULL) FROM tasks JOIN task_tags ON task_id = tasks.id
      JOIN tags ON tags.id = tag_id GROUP BY title
      """
    When I follow the admin answer
    Then the page part "[data-toast] .toast" holds "A sprint opens on today"

    Examples:
      | what                | day             |
      | a day that is over  | {day:today - 1} |
      | a day it can't read | next week       |

  Scenario: A planned sprint takes over today when its day arrives
    Given the sprints table holds the rows:
      | sprint_date |
      | {day:today} |
    And the tasks:
      | title          | sprint    |
      | Left yesterday | today - 1 |
    When I visit "/admin/tasks"
    Then the database soon holds "{day:today}, 1" for:
      """
      SELECT to_char(sprint_date, 'YYYY-MM-DD'), (SELECT count(*) FROM sprints WHERE sprint_date = (now() AT TIME ZONE 'America/Chicago')::date)
      FROM tasks JOIN sprints ON sprints.id = sprint_id
      """
