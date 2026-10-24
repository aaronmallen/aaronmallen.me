Feature: Placing tasks and paging a list
  The grip posts where a task goes in its list, the place route keeps every move inside one list, and a long list
  pages.

  Background:
    Given I am signed in to the admin

  Scenario: The grip waits hidden on each open row, names its task and posts to the place route
    Given the tasks:
      | title  | position |
      | first  | 1        |
      | second | 2        |
    And the admin scripts do not load
    When I visit "/admin/tasks?filter=next"
    Then the page has 2 of "[data-task-grip][hidden]"
    And the page has no ".task-order, .task-caret, form[action*='/reorder/']"
    And the page part "[data-task-grip]" has "data-task-grip" set to "/admin/tasks/{task:first}/place"
    And the page part "[data-task-grip]" has a "data-task-token"
    And the page part "[data-task-grip]" has "aria-label" set to "Reorder first"
    And the page has 2 of ".task[data-task-order='next']"
    When I visit "/admin/tasks?filter=next&q=first"
    Then the page has no "[data-task-grip], [data-task-order]"

  Scenario: A sprint's rows group by the sprint
    Given the tasks:
      | title   | sprint    |
      | planned | today + 2 |
    When I visit "/admin/tasks?filter=upcoming"
    Then the page has ".task[data-task-order='{sprint:today + 2}']:has-text('planned')"

  Scenario Outline: Placing <title> after <after> puts the list in the order <order>
    Given the tasks:
      | title  | position |
      | first  | 1        |
      | second | 2        |
      | third  | 3        |
      | fourth | 4        |
    When I visit "/admin/tasks?filter=next"
    And I send the admin form "/admin/tasks/{task:<title>}/place" with:
      | after | <after id> |
    Then the server answers 204
    And the answer says ""
    And the database soon holds "<order>, next, true" for:
      """
      SELECT string_agg(title, ' ' ORDER BY position), min(list::text), bool_and(sprint_id IS NULL) FROM tasks
      """

    Examples:
      | title  | after   | after id      | order                      |
      | first  | third   | {task:third}  | second third first fourth  |
      | fourth | first   | {task:first}  | first fourth second third  |
      | third  | nothing |               | third first second fourth  |
      | second | first   | {task:first}  | first second third fourth  |

  Scenario: Placing skips a finished task between open ones
    Given the tasks:
      | title    | position | status |
      | first    | 1        | open   |
      | second   | 2        | open   |
      | third    | 3        | open   |
      | fourth   | 4        | open   |
      | finished | 5        | done   |
      | fifth    | 6        | open   |
    When I visit "/admin/tasks?filter=next"
    And I send the admin form "/admin/tasks/{task:fifth}/place" with:
      | after | {task:third} |
    Then the database soon holds "first second third fifth fourth" for:
      """
      SELECT string_agg(title, ' ' ORDER BY position) FROM tasks WHERE status = 'open'
      """

  Scenario: Placing handles tasks that share a position
    Given the tasks:
      | title  | position |
      | first  | 1        |
      | second | 2        |
      | third  | 3        |
      | fourth | 4        |
      | tied   | 4        |
    When I visit "/admin/tasks?filter=next"
    And I send the admin form "/admin/tasks/{task:tied}/place" with:
      | after | {task:first} |
    And I send the admin form "/admin/tasks/{task:first}/place" with:
      | after | {task:fourth} |
    Then the database soon holds "tied second third fourth first" for:
      """
      SELECT string_agg(title, ' ' ORDER BY position, id) FROM tasks
      """

  Scenario: Placing keeps a task led below position one where it is
    Given the tasks:
      | title  | position |
      | led    | -2       |
      | first  | 1        |
      | second | 2        |
      | third  | 3        |
      | fourth | 4        |
    When I visit "/admin/tasks?filter=next"
    And I send the admin form "/admin/tasks/{task:third}/place" with:
      | after | {task:led} |
    Then the database soon holds "led third first second fourth, -2" for:
      """
      SELECT string_agg(title, ' ' ORDER BY position, id), (SELECT position FROM tasks WHERE title = 'led') FROM tasks
      """

  Scenario Outline: Placing refuses <what> with no change
    Given the tasks:
      | title    | position | list    | sprint | status   |
      | first    | 1        | next    |        | open     |
      | second   | 2        | next    |        | open     |
      | third    | 3        | next    |        | open     |
      | fourth   | 4        | next    |        | open     |
      | other    | 5        | someday |        | open     |
      | planned  | 6        |         | today  | open     |
      | finished | 7        | next    |        | done     |
      | dropped  | 8        | next    |        | canceled |
    When I visit "/admin/tasks?filter=next"
    And I send the admin form "/admin/tasks/{task:<moved>}/place" with:
      | after | <after> |
    Then the server answers 422
    And the database soon holds "first second third fourth finished dropped" for:
      """
      SELECT string_agg(title, ' ' ORDER BY position) FROM tasks WHERE list = 'next'
      """

    Examples:
      | what                          | moved    | after           |
      | a finished task               | finished |                 |
      | a canceled task               | dropped  |                 |
      | to follow a task in another list | first | {task:other}    |
      | to follow a task in a sprint  | first    | {task:planned}  |
      | to follow a finished task     | first    | {task:finished} |
      | to follow the task itself     | first    | {task:first}    |
      | to follow a task that isn't there | first | 999999         |
      | to follow an id that isn't one | first   | third           |

  Scenario: Placing refuses a forged token with no change
    Given the tasks:
      | title  | position |
      | first  | 1        |
      | second | 2        |
      | third  | 3        |
    When I send the admin form "/admin/tasks/{task:first}/place" with a forged token and:
      | after | {task:third} |
    Then the server answers 403
    And the database soon holds "first second third" for:
      """
      SELECT string_agg(title, ' ' ORDER BY position) FROM tasks
      """

  Scenario: A long list pages its open tasks, counts the whole list and leads each grip from the page before
    Given 100 more tasks on next called "Filler"
    And the tasks:
      | title     | list    | status | position |
      | finished  | next    | done   | 1000     |
      | elsewhere | someday | open   | 1001     |
      | Last one  | next    | open   | 1002     |
    When I visit "/admin/tasks?filter=next"
    Then the page has 100 of ".task-title"
    And the page part "nav.pager a[rel='next']" has "href" set to "/admin/tasks?filter=next&page=2"
    And the page has no "nav.pager a[rel='prev']"
    And the page part "a.screen-tab[href='/admin/tasks?filter=next'] .task-tab-count" reads "101"
    And the page part ".card-note" reads "101 open"
    And the page has no "[data-task-grip][data-task-lead]"
    When I visit "/admin/tasks?filter=next&page=2"
    Then the task rows read "Last one"
    And the page part "nav.pager a[rel='prev']" has "href" set to "/admin/tasks?filter=next"
    And the page has no "nav.pager a[rel='next']"
    And the page part "[data-task-grip]" has "data-task-lead" set to "{task:Filler 100}"
    And the page has "a.task-title[data-task-open][href^='/admin/tasks/{task:Last one}?']"
    When I visit "/admin/tasks?filter=next&page=3"
    Then the server answers 404
    When I visit "/admin/tasks?filter=today"
    Then the page part "[data-pool='next']" reads "next · 101"
    And the page has 100 of "[data-pool-panel='next'] .li-title"

  Scenario: Today's sprint pages, and leads its grips from its own page before
    Given 101 more tasks on today called "Sprint task"
    When I visit "/admin/tasks?filter=today&page=2"
    Then the task rows read "Sprint task 101"
    And the page part "nav.pager a[rel='prev']" has "href" set to "/admin/tasks?filter=today"
    And the page part "[data-task-grip]" has "data-task-lead" set to "{task:Sprint task 100}"

  Scenario: A title holding HTML reads back as text, escaped, and a quoted title stays inside its attribute
    Given the tasks:
      | title                         |
      | <script>alert('x')</script>   |
      | Ask "why"                     |
    When I fetch the admin page "/admin/tasks?filter=next"
    Then the answer shows "&lt;script&gt;alert(&#39;x&#39;)&lt;/script&gt;"
    When I visit "/admin/tasks?filter=next"
    Then the page has ".task-title:text-is(\"<script>alert('x')</script>\")"
    When I open the editor of the task "Ask \"why\""
    Then the page part "form[action$='/delete']" has "data-confirm" set to "Delete Ask \"why\"? This cannot be undone."

  Scenario: A forged token refuses a capture and a move
    Given the tasks:
      | title   |
      | Stay me |
    When I send the admin form "/admin/tasks" with a forged token and:
      | task[title] | Email the accountant |
    Then the server answers 403
    When I send the admin form "/admin/tasks/{task:Stay me}/move/someday" with a forged token and:
      | filter | next |
    Then the database soon holds "Stay me, next" for:
      """
      SELECT title, list FROM tasks
      """

  Scenario: Every form on the list carries a token, and the list adds no navigation entry
    Given the tasks:
      | title   |
      | Plan it |
    When I visit "/admin/tasks?filter=next"
    Then every "main form[method='post']" holds an "input[name='_csrf_token']"
    And the page has no ".tab-strip a[href='/admin/tasks']"

  Scenario: Signed out, the list shows no task
    Given I sign out of the browser
    And the tasks:
      | title                |
      | Email the accountant |
    When I fetch the admin page "/admin/tasks"
    Then the answer does not show "Email the accountant"
