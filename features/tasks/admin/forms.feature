Feature: The task forms
  A task is written down from the quick add, the Create Task dialog or the new task page, and the form says what is
  wrong when it cannot save.

  Background:
    Given I am signed in to the admin

  Scenario: The Create Task button leads to the new task page, or opens the dialog in place
    When I visit "/admin/tasks?filter=next"
    Then the page part ".page-head-actions a:has-text('Create Task')" has "href" set to "/admin/tasks/new"
    And the page part ".page-head-actions a:has-text('Create Task')" has "data-dialog-open" set to "task-create"

  Scenario: The new task page asks for every field a task has, with next picked
    When I visit "/admin/tasks/new"
    Then the server answers 200
    And the page parts "main form[action='/admin/tasks'] :is([name^='task[']:not([name^='task[recur]']), [name='task[recur][cadence]'])" have "name" set to "task[title] | task[note] | task[tags] | task[list] | task[project] | task[sprint_on] | task[recur][cadence]"
    And the page part "select[name='task[list]'] option:checked" reads "next"
    And the page part ".page-head-sub" reads "Title, notes, list, project, sprint, tags and repeats in one go."
    And the page has no axe breaches in light or dark

  Scenario: The project field offers no project and each live project, and fills the one the link names
    Given the projects:
      | name    | key  | archived  |
      | Podcast | POD  |           |
      | Gone    | GONE | today - 1 |
    When I visit "/admin/tasks/new"
    Then the page parts "main select[name='task[project]'] option" read "No project | Podcast"
    And the page part "select[name='task[project]'] option:checked" reads "No project"
    And the page has no "main select[name='task[project]'][data-project-choices]"
    When I visit "/admin/tasks/new?project=POD"
    Then the page part "select[name='task[project]'] option:checked" reads "Podcast"
    When I fetch the admin page "/admin"
    And I look at the admin answer
    Then the page part "dialog#task-create select[name='task[project]']" has "data-project-choices" set to "/admin/projects/choices"
    And the page parts "dialog#task-create select[name='task[project]'] option" read "No project"

  Scenario: The new task page from Today puts the task in today's sprint and leads back to Today
    When I visit "/admin/tasks/new?origin=today"
    Then the page part "main form[action='/admin/tasks'] select[name='task[list]'] option:checked" reads "today"
    And the page field "main form[action='/admin/tasks'] input[type=hidden][name='origin']" holds "today"
    And the page part ".page-head-actions a:has-text('Today')" has "href" set to "/admin"

  Scenario: The dialog sits shut in every screen with the same fields, on next away from Today
    When I fetch the admin page "/admin"
    And I look at the admin answer
    Then the page has "dialog#task-create[hidden]:not([open])"
    And the page parts "dialog#task-create [name^='task[']" have "name" set to "task[title] | task[note] | task[tags] | task[list] | task[project] | task[sprint_on] | task[recur][cadence] | task[recur][every] | task[recur][week] | task[recur][weekday] | task[recur][month] | task[recur][day] | task[recur][starts_on]"
    When I fetch the admin page "/admin/tasks?filter=someday"
    And I look at the admin answer
    Then the page part "dialog#task-create select[name='task[list]'] option[selected]" reads "next"
    And the page has no "dialog#task-create input[type=hidden][name='origin']"

  Scenario Outline: A capture from <filter> writes the task into that list and comes back to it
    When I visit "/admin/tasks?filter=<filter>"
    And I send the admin form "/admin/tasks" with:
      | filter      | <filter>                    |
      | task[title] | Email the accountant #admin |
    Then the admin answer goes to "/admin/tasks?filter=<filter>"
    And the database soon holds "Email the accountant #admin, <where>, 0" for:
      """
      SELECT title, coalesce(list::text, 'sprint ' || to_char(sprint_date, 'YYYY-MM-DD')), (SELECT count(*) FROM task_tags)
      FROM tasks LEFT JOIN sprints ON sprints.id = sprint_id
      """
    When I follow the admin answer
    Then the toast says "Task captured"

    Examples:
      | filter  | where   |
      | next    | next    |
      | someday | someday |

  Scenario: A capture from today goes into today's sprint and carries yesterday's work forward once
    Given the tasks:
      | title          | sprint    |
      | Left yesterday | today - 1 |
    When I visit "/admin/tasks/new"
    And I send the admin form "/admin/tasks" with:
      | filter      |  today          |
      | task[title] | Ship the screen |
    Then the database soon holds "Left yesterday, {day:today}, 1\nShip the screen, {day:today}, 0" for:
      """
      SELECT title, to_char(sprint_date, 'YYYY-MM-DD'), carried_count FROM tasks JOIN sprints ON sprints.id = sprint_id ORDER BY title
      """

  Scenario: A capture with no text answers 422, says what is missing and carries nothing forward
    Given the tasks:
      | title          | sprint    |
      | Left yesterday | today - 1 |
    When I visit "/admin/tasks/new"
    And I send the admin form "/admin/tasks" with:
      | filter      | today |
      | task[title] |       |
    Then the server answers 422
    And the database soon holds "Left yesterday, {day:today - 1}, 0" for:
      """
      SELECT title, to_char(sprint_date, 'YYYY-MM-DD'), carried_count FROM tasks JOIN sprints ON sprints.id = sprint_id
      """
    When I look at the admin answer
    Then the page part ".field-error" holds "Write the task down first."

  Scenario: The form writes down the title, note, list, tags and sprint day, and comes back to the list
    When I visit "/admin/tasks/new"
    And I send the admin form "/admin/tasks" with:
      | filter         | next              |
      | task[title]    | Learn Elixir      |
      | task[list]     | someday           |
      | task[note]     | read the guide    |
      | task[tags]     | elixir, learning  |
    Then the admin answer goes to "/admin/tasks?filter=someday"
    And the database soon holds "Learn Elixir, read the guide, someday, elixir learning" for:
      """
      SELECT title, note, list, string_agg(name, ' ' ORDER BY name) FROM tasks JOIN task_tags ON task_id = tasks.id
      JOIN tags ON tags.id = tag_id GROUP BY title, note, list
      """
    When I send the admin form "/admin/tasks" with:
      | task[title]     | Learn Rust        |
      | task[list]      | someday           |
      | task[sprint_on] | {day:today + 1}   |
    Then the database soon holds "{day:today + 1}" for:
      """
      SELECT to_char(sprint_date, 'YYYY-MM-DD') FROM tasks JOIN sprints ON sprints.id = sprint_id WHERE title = 'Learn Rust'
      """

  Scenario: A task made in a project gets the project's number, and an archived project is refused
    Given the projects:
      | name    | key  | archived  |
      | Podcast | POD  |           |
      | Gone    | GONE | today - 1 |
    When I visit "/admin/tasks/new"
    And I send the admin form "/admin/tasks" with:
      | task[title]   | Record the intro |
      | task[list]    | next             |
      | task[project] | POD              |
    And I send the admin form "/admin/tasks" with:
      | task[title]   | Bare task |
      | task[list]    | next      |
      | task[project] |           |
    Then the database soon holds "Bare task, , 1\nRecord the intro, POD, 1" for:
      """
      SELECT title, coalesce(key, ''), number FROM tasks LEFT JOIN projects ON projects.id = project_id ORDER BY title
      """
    When I send the admin form "/admin/tasks" with:
      | task[title]   | Archived one |
      | task[list]    | next         |
      | task[project] | GONE         |
    And I look at the admin answer
    Then the page part ".field-error" holds "That project is gone or archived. Pick another."
    And the database soon holds "0" for:
      """
      SELECT count(*) FROM tasks WHERE title = 'Archived one'
      """
    When I send the admin form "/admin/tasks" with:
      | task[title]   |      |
      | task[list]    | next |
      | task[project] | POD  |
    And I look at the admin answer
    Then the page part "select[name='task[project]'] option[selected]" reads "Podcast"

  Scenario: A failed save shows the new task page again with the errors and what was typed
    When I visit "/admin/tasks/new"
    And I send the admin form "/admin/tasks" with:
      | task[title] |                |
      | task[list]  | someday        |
      | task[note]  | read the guide |
      | task[tags]  | not_a_tag      |
    Then the server answers 422
    And the tasks table holds 0 rows
    When I look at the admin answer
    Then the page has "main form[action='/admin/tasks'] [name='task[title]']"
    And the page parts ".field-error" read "Write the task down first. | A tag is lowercase words joined by hyphens."
    And the page field "[name='task[note]']" holds "read the guide"
    And the page part "select[name='task[list]'] option[selected]" reads "someday"
    And the page field "[name='task[tags]']" holds "not_a_tag"
