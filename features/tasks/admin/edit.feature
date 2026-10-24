Feature: Editing a task
  The edit page fills the task's fields, saves them, says what went wrong, and keeps the task in the sprint or list
  it belongs in.

  Background:
    Given I am signed in to the admin

  Scenario: The edit page draws the drawer around the task's form
    Given the tasks:
      | title            | note            | tags       |
      | Email accountant | Ring before ten | ruby admin |
    When I visit "/admin/tasks/{task:Email accountant}/edit?filter=upcoming&origin=today"
    Then the server answers 200
    And the page part "h1" reads "Email accountant"
    And the page has "main article.task-drawer[data-task-edit='{task:Email accountant}'] header.task-drawer-head a[data-task-close]"
    And the page has "main article.task-drawer[data-task-edit='{task:Email accountant}'] .task-drawer-body form#task-{task:Email accountant}-form[method='post'][action='/admin/tasks/{task:Email accountant}']"
    And the page has "main article.task-drawer[data-task-edit='{task:Email accountant}'] footer.task-drawer-foot"
    And the page parts ".task-drawer-foot :is(a, button)" read "Delete | Cancel | Save"
    And the page has ".task-drawer-foot button[type='submit'][form='task-{task:Email accountant}-form']"
    And the page has no "#task-{task:Email accountant}-form button[type='submit']"
    And the page has ".task-form-pair:has([name='task[tags]']):has([name='task[list]']) + .field [name='task[sprint_on]']"
    And the page parts "#task-{task:Email accountant}-form [name^='task[']" have "name" starting with "task[title] | task[note] | task[tags] | task[list] | task[sprint_on]"
    And the page field "[name='task[title]']" holds "Email accountant"
    And the page field "textarea[name='task[note]']" holds "Ring before ten"
    And the page part "select[name='task[list]'] option[selected]" reads "next"
    And the page field "[name='task[tags]']" holds "admin, ruby"
    And the page has "[data-markdown-editor][style='--edit-height: 160px']:has(textarea[name='task[note]']) [role='toolbar']"
    And the page has "[data-markdown-editor]:has(textarea[name='task[note]']) [data-editor-preview='/admin/markdown/preview/tasks']"
    And the page field "#task-{task:Email accountant}-form input[name='filter']" holds "upcoming"
    And the page field "#task-{task:Email accountant}-form input[name='origin']" holds "today"
    And the page part ".task-drawer-foot form[action='/admin/tasks/{task:Email accountant}/delete']" holds "Delete"
    And the page part ".task-drawer-foot form[action='/admin/tasks/{task:Email accountant}/delete']" has "data-confirm" set to "Delete Email accountant? This cannot be undone."
    And the page part ".task-drawer-body .hint:has-text('No sessions')" reads "No sessions yet."
    And the page has no axe breaches in light or dark

  Scenario: The edit page leads Cancel to the task's page, and the task's page links Edit to it
    Given the tasks:
      | title            |
      | Email accountant |
    When I visit "/admin/tasks/{task:Email accountant}/edit?filter=next&origin=tasks"
    Then the page part ".task-drawer-foot a[data-task-cancel]:text-is('Cancel')" has "href" set to "/admin/tasks/{task:Email accountant}?filter=next&origin=tasks"
    And the page part "textarea[name='task[note]']" reads ""
    When I visit "/admin/tasks/{task:Email accountant}?filter=next&origin=tasks"
    Then the page part "a:text-is('Edit')" has "href" set to "/admin/tasks/{task:Email accountant}/edit?filter=next&origin=tasks"

  Scenario: The edit page answers 404 for a task that isn't there
    When I visit "/admin/tasks/0/edit"
    Then the server answers 404

  Scenario: The edit page lists the sessions, the set total form and the link editor that searches it
    Given the tasks:
      | title            |
      | Email accountant |
      | Book the flight  |
    And the work_sessions table holds the rows:
      | task_id                 | started_at | ended_at   |
      | {task:Email accountant} | now - 7200 | now - 3600 |
    When I visit "/admin/tasks/{task:Email accountant}/edit?filter=next&origin=tasks"
    Then the page has "#task-session-{session:Email accountant} form[action$='/sessions/{session:Email accountant}']"
    And the page has "form[action='/admin/tasks/{task:Email accountant}/total']"
    And the page has "form[action='/admin/tasks/{task:Email accountant}/links']"
    And the page part "[data-task-find]" has "data-task-find" set to "/admin/tasks/{task:Email accountant}/edit?filter=next&origin=tasks"
    When I visit "/admin/tasks/{task:Email accountant}/edit?link_q=flight"
    Then the page part ".task-link-target" holds "Book the flight"

  Scenario: The edit page reads today back for a task in today's sprint, with its date
    Given the tasks:
      | title    | sprint |
      | In today | today  |
    When I visit "/admin/tasks/{task:In today}/edit"
    Then the page part "select[name='task[list]'] option[selected]" reads "today"
    And the page field "#task-{task:In today}-form [name='task[sprint_on]']" holds "{day:today}"

  Scenario: Saving rewrites the title, note and tags, says so and comes back to the list
    Given the tasks:
      | title            |
      | Email accountant |
    When I visit "/admin/tasks/{task:Email accountant}/edit"
    And I send the admin form "/admin/tasks/{task:Email accountant}" with:
      | filter      | next                 |
      | task[title] | Email the accountant |
      | task[list]  |                      |
      | task[note]  | Ring before ten      |
      | task[tags]  | ruby, admin          |
    Then the admin answer goes to "/admin/tasks?filter=next"
    And the database soon holds "Email the accountant, Ring before ten, next, admin ruby" for:
      """
      SELECT title, note, list, string_agg(name, ' ' ORDER BY name) FROM tasks JOIN task_tags ON task_id = tasks.id
      JOIN tags ON tags.id = tag_id GROUP BY title, note, list
      """
    When I follow the admin answer
    Then the toast says "Task saved"
    And the page has ".task-meta .tag:not([class='tag']):has-text('#ruby')"
    And the page has "a[href='/admin/tags/ruby']:has-text('#ruby')"
    And the page has no ".task-meta .task-mark"
    And the page part ".task .record-key" has "class" set to "record-key"

  Scenario: Saving from Today comes back to Today
    Given the tasks:
      | title            |
      | Email accountant |
    When I visit "/admin/tasks/{task:Email accountant}/edit"
    And I send the admin form "/admin/tasks/{task:Email accountant}" with:
      | filter      | today                |
      | origin      | today                |
      | task[title] | Email the accountant |
    Then the admin answer goes to "/admin"

  Scenario Outline: Saving with the list <list> leaves the task <where>
    Given the tasks:
      | title            |
      | Email accountant |
    When I visit "/admin/tasks/{task:Email accountant}/edit"
    And I send the admin form "/admin/tasks/{task:Email accountant}" with:
      | filter      | next                 |
      | task[title] | Email the accountant |
      | task[list]  | <list>               |
    Then the database soon holds "<after>" for:
      """
      SELECT coalesce(list::text, '-') || ' ' || coalesce(to_char(sprint_date, 'YYYY-MM-DD'), '-') FROM tasks LEFT JOIN sprints ON sprints.id = sprint_id
      """

    Examples:
      | list    | where             | after           |
      | someday | on someday        | someday -       |
      | today   | in today's sprint | - {day:today}   |
      | next    | where it was      | next -          |

  Scenario: Saving with a list that is not one answers 422
    Given the tasks:
      | title            |
      | Email accountant |
    When I visit "/admin/tasks/{task:Email accountant}/edit"
    And I send the admin form "/admin/tasks/{task:Email accountant}" with:
      | filter      | next                 |
      | task[title] | Email the accountant |
      | task[list]  | later                |
    Then the server answers 422

  Scenario: A failed edit shows the edit page with the errors, what was typed and where it was opened
    Given the tasks:
      | title            |
      | Email accountant |
    When I visit "/admin/tasks/{task:Email accountant}/edit"
    And I send the admin form "/admin/tasks/{task:Email accountant}" with:
      | filter          | someday         |
      | origin          | tasks           |
      | task[title]     | " "             |
      | task[note]      | Ring before ten |
      | task[list]      | someday         |
      | task[tags]      | not_a_tag       |
      | task[sprint_on] |                 |
    Then the server answers 422
    And the database soon holds "Email accountant, , next" for:
      """
      SELECT title, note, list FROM tasks
      """
    When I look at the admin answer
    Then the page has "main [data-task-edit='{task:Email accountant}'] form[action='/admin/tasks/{task:Email accountant}']"
    And the page part "#task-{task:Email accountant}-title-error" holds "Write the task down first."
    And the page part "#task-{task:Email accountant}-tags-error" holds "A tag is lowercase words joined by hyphens."
    And the page field "[name='task[title]']" holds " "
    And the page part "textarea[name='task[note]']" reads "Ring before ten"
    And the page part "select[name='task[list]'] option[selected]" reads "someday"
    And the page field "[name='task[tags]']" holds "not_a_tag"
    And the page field "#task-{task:Email accountant}-form input[name='filter']" holds "someday"
    And the page field "#task-{task:Email accountant}-form input[name='origin']" holds "tasks"

  Scenario: The sprint date of a finished task is the day it ran, and saving from completed keeps it there
    Given the tasks:
      | title    | sprint    | status |
      | Ran then | today - 1 | done   |
    When I visit "/admin/tasks/{task:Ran then}/edit?filter=completed"
    Then the page field "#task-{task:Ran then}-form [name='task[sprint_on]']" holds "{day:today - 1}"
    And the page part "#task-{task:Ran then}-form [name='task[sprint_on]']" has "min" set to "{day:today - 1}"
    And the page part "#task-{task:Ran then}-form .field:has([name='task[sprint_on]']) .hint" reads "Ran in that day's sprint."
    When I save the task form of "Ran then" from "completed" with:
      | task[title] | Ran then |
    Then the database soon holds "{day:today - 1}" for:
      """
      SELECT to_char(sprint_date, 'YYYY-MM-DD') FROM tasks JOIN sprints ON sprints.id = sprint_id
      """

  Scenario: A sprint task saved from today with nothing changed stays where it is
    Given the tasks:
      | title    | sprint |
      | In today | today  |
    And the database runs:
      """
      UPDATE tasks SET carried_count = 2
      """
    When I save the task form of "In today" from "today" with:
      | task[title] | In today |
    Then the database soon holds "{day:today}, 2" for:
      """
      SELECT to_char(sprint_date, 'YYYY-MM-DD'), carried_count FROM tasks JOIN sprints ON sprints.id = sprint_id
      """

  Scenario: A task left in yesterday's sprint rolls into today's before the editor fills its date, and saves there
    Given the tasks:
      | title      | sprint    |
      | Left there | today - 1 |
    When I visit "/admin/tasks/{task:Left there}/edit?filter=today"
    Then the page field "#task-{task:Left there}-form [name='task[sprint_on]']" holds "{day:today}"
    When I save the task form of "Left there" from "today" with:
      | task[title] | Left there |
    Then the database soon holds ", {day:today}" for:
      """
      SELECT coalesce(list::text, ''), to_char(sprint_date, 'YYYY-MM-DD') FROM tasks JOIN sprints ON sprints.id = sprint_id
      """
    When I follow the admin answer
    Then the toast says "Task saved"

  Scenario Outline: Saving from <filter> with <change> moves the task <where>
    Given the tasks:
      | title  | sprint   | list   |
      | Edited | <sprint> | <list> |
    When I save the task form of "Edited" from "<filter>" with:
      | <field> | <value> |
    Then the database soon holds "<after>" for:
      """
      SELECT title, coalesce(list::text, ''), coalesce(to_char(sprint_date, 'YYYY-MM-DD'), ''), carried_count
      FROM tasks LEFT JOIN sprints ON sprints.id = sprint_id
      """

    Examples:
      | filter   | sprint    | list | change               | field           | value           | where                     | after                                 |
      | today    | today     |      | next picked          | task[list]      | next            | to next                   | Edited, next, , 0                     |
      | upcoming | today + 1 |      | someday picked       | task[list]      | someday         | to someday                | Edited, someday, , 0                  |
      | next     |           | next | today and no date    | task[list]      | today           | into today's sprint       | Edited, , {day:today}, 0              |
      | today    | today     |      | the date cleared     | task[sprint_on] |                 | to next                   | Edited, next, , 0                     |
      | upcoming | today + 1 |      | a new title          | task[title]     | Renamed         | nowhere                   | Renamed, , {day:today + 1}, 0         |
      | upcoming | today + 1 |      | a new date           | task[sprint_on] | {day:today + 2} | to that day               | Edited, , {day:today + 2}, 0          |

  Scenario: A sprint task from an issue goes back to external when its date is cleared
    Given the tasks:
      | title      | sprint |
      | From issue | today  |
    And the task_sources table holds the rows:
      | task_id           | provider | remote_id | url                                                    |
      | {task:From issue} | github   | 7         | https://github.com/aaronmallen/aaronmallen.me/issues/7 |
    When I save the task form of "From issue" from "today" with:
      | task[sprint_on] |  |
    Then the database soon holds "external, true" for:
      """
      SELECT list, sprint_id IS NULL FROM tasks
      """

  Scenario: The footnote says how sprints work, and the activity feed holds a finished task
    Given the tasks:
      | title          | sprint    |
      | Left behind    | today - 2 |
      | Planned later  | today + 3 |
      | Ship the notes |           |
    When I visit "/admin/tasks?filter=today"
    Then the page part ".task-note" reads "Sprints last one day. Open tasks left in a past sprint move into today's. Starting a task pulls it into today; completing one files it under completed and on that day's activity feed."
    And the database soon holds "Left behind, {day:today}" for:
      """
      SELECT title, to_char(sprint_date, 'YYYY-MM-DD') FROM tasks JOIN sprints ON sprints.id = sprint_id WHERE title = 'Left behind'
      """
    When I send the admin form "/admin/tasks/{task:Planned later}/start"
    And I follow the admin answer
    Then the page has ".task-note"
    And the database soon holds "{day:today}" for:
      """
      SELECT to_char(sprint_date, 'YYYY-MM-DD') FROM tasks JOIN sprints ON sprints.id = sprint_id WHERE title = 'Planned later'
      """
    When I send the admin form "/admin/tasks/{task:Ship the notes}/complete"
    And I visit "/admin/tasks?filter=completed"
    Then the task rows read "Ship the notes"
    And the page has ".task-note"
    When I visit "/admin/activity"
    Then the page part ".activity-day:has(time[datetime='{day:today}'])" holds "Ship the notes"

  Scenario: The sprint field hint says what the sprint does for the task
    Given the tasks:
      | title      | sprint    | status | list |
      | Running    | today     | done   |      |
      | Waiting    | today + 1 | open   |      |
      | In a list  |           | open   | next |
    When I visit "/admin/tasks/{task:Running}/edit"
    Then the page part "#task-{task:Running}-form .field:has([name='task[sprint_on]']) .hint" reads "Runs in today's sprint."
    When I visit "/admin/tasks/{task:Waiting}/edit"
    Then the page part "#task-{task:Waiting}-form .field:has([name='task[sprint_on]']) .hint" reads "Waits until that sprint starts."
    When I visit "/admin/tasks/{task:In a list}/edit"
    Then the page part "#task-{task:In a list}-form .field:has([name='task[sprint_on]']) .hint" reads "Unscheduled · lives in a list only."
    And the database soon holds "{day:today + 1}" for:
      """
      SELECT to_char(sprint_date, 'YYYY-MM-DD') FROM tasks JOIN sprints ON sprints.id = sprint_id WHERE title = 'Waiting'
      """

  Scenario: A carried task says so on its row, and the page counts what arrived
    Given the tasks:
      | title           | sprint    |
      | Ship the screen | today - 1 |
      | Ship the other  | today - 1 |
    When I visit "/admin/tasks"
    Then the page has ".task-meta .task-mark.sand:has-text('carried ×1')"
    And the page part ".page-head-sub" holds "2 carried in"

  Scenario: A task never carried, or finished, says nothing of carrying
    Given the tasks:
      | title    | sprint | status |
      | Fresh    | today  | open   |
      | Finished | today  | done   |
    And the database runs:
      """
      UPDATE tasks SET carried_count = 2 WHERE title = 'Finished'
      """
    When I visit "/admin/tasks"
    Then the page has no ".task-meta .task-mark:has-text('carried')"

  Scenario: A delete asks first, naming the task, and takes the task away
    Given the tasks:
      | title                |
      | Email the accountant |
    When I visit "/admin/tasks/{task:Email the accountant}/edit?filter=next"
    Then the page part "form[action$='/delete']" has "data-confirm" set to "Delete Email the accountant? This cannot be undone."
    When I send the admin form "/admin/tasks/{task:Email the accountant}/delete" with:
      | filter | next |
    Then the tasks table holds 0 rows
