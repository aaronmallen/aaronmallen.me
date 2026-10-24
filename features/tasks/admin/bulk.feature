Feature: Bulk task actions
  The bulk bar posts the ticked tasks with one action, changes all or none of them, and says what it did.

  Background:
    Given I am signed in to the admin

  Scenario: The list draws one bar the boxes join, which works with scripts off
    Given the admin scripts do not load
    And the tasks:
      | title                |
      | Email the accountant |
      | Plan a trip          |
    When I visit "/admin/tasks?filter=next"
    Then the page has 1 of "form#task-bulk[action='/admin/tasks/bulk'][method='post']"
    And the page parts "form#task-bulk [data-bulk-acts] button[name='act']:not([hidden])" have "value" set to "complete | cancel | move | tag | untag | delete"
    And the page has 2 of ".task input[type='checkbox'][name='ids[]'][form='task-bulk'][autocomplete='off']"
    And the page has "input[value='{task:Email the accountant}'][aria-label='Select Email the accountant']"
    And the page has "[data-bulk-acts]:not([hidden])"
    And the page has "[data-bulk-all][hidden] input[autocomplete='off']"
    And the page parts "form#task-bulk select[name='to'] option" have "value" set to " | today | next | someday | external"
    And the page has "form#task-bulk input[name='tag'][aria-label='Tag name']"
    And the page has "button[value='delete'][data-confirm]"
    And the page has no axe breaches in light or dark

  Scenario: The bar keeps the search, the page and the pull column's pool
    Given the tasks:
      | title          | sprint |
      | Ship it today  | today  |
    And 101 more tasks on next called "Plan a trip"
    When I visit "/admin/tasks?filter=next&page=2&q=a"
    Then the page field "form#task-bulk input[name='q']" holds "a"
    And the page field "form#task-bulk input[name='page']" holds "2"
    And the page has no "form#task-bulk input[name='pool']"
    When I visit "/admin/tasks?filter=today&pool=someday"
    Then the page field "form#task-bulk input[name='pool']" holds "someday"

  Scenario: The archive and an empty list draw no bar
    Given the tasks:
      | title    | status |
      | Filed it | done   |
    When I visit "/admin/tasks?filter=completed"
    Then the page has no "form#task-bulk"
    When I visit "/admin/tasks?filter=someday"
    Then the page has no "form#task-bulk"

  Scenario Outline: <act> changes the ticked tasks, leaves the rest and says how many
    Given the tasks:
      | title |
      | one   |
      | two   |
      | left  |
    When I send the admin form "/admin/tasks/bulk" with:
      | act    | <act>      |
      | filter | next       |
      | ids[]  | {task:one} |
      | ids[]  | {task:two} |
    Then the database soon holds "<after>" for:
      """
      SELECT string_agg(title || ' ' || status, ', ' ORDER BY title) FROM tasks
      """
    When I follow the admin answer
    Then the toast says "<said>"

    Examples:
      | act      | after                                | said             |
      | complete | left open, one done, two done        | Finished 2 tasks |
      | cancel   | left open, one canceled, two canceled | Canceled 2 tasks |
      | delete   | left open                            | Deleted 2 tasks  |

  Scenario: A move puts the ticked tasks on the list and records a move on each
    Given the tasks:
      | title |
      | one   |
      | two   |
      | left  |
    When I send the admin form "/admin/tasks/bulk" with:
      | act    | move       |
      | filter | next       |
      | to     | someday    |
      | ids[]  | {task:one} |
      | ids[]  | {task:two} |
    Then the database soon holds "left next, one someday, two someday" for:
      """
      SELECT string_agg(title || ' ' || list, ', ' ORDER BY title) FROM tasks
      """
    And the database soon holds "one, moved, next, someday\ntwo, moved, next, someday" for:
      """
      SELECT title, kind, from_list, to_list FROM task_events JOIN tasks ON tasks.id = task_id ORDER BY title
      """
    When I follow the admin answer
    Then the toast says "Moved 2 tasks to someday"

  Scenario: A move to today puts the ticked tasks in today's sprint
    Given the tasks:
      | title |
      | one   |
      | two   |
    When I send the admin form "/admin/tasks/bulk" with:
      | act    | move       |
      | filter | next       |
      | to     | today      |
      | ids[]  | {task:one} |
      | ids[]  | {task:two} |
    Then the database soon holds "one, {day:today}\ntwo, {day:today}" for:
      """
      SELECT title, to_char(sprint_date, 'YYYY-MM-DD') FROM tasks JOIN sprints ON sprints.id = sprint_id ORDER BY title
      """
    And the database soon holds "one, moved, next\ntwo, moved, next" for:
      """
      SELECT title, kind, from_list FROM task_events JOIN tasks ON tasks.id = task_id ORDER BY title
      """

  Scenario: A tag adds the tag beside the others and records it on each
    Given the tasks:
      | title | tags |
      | one   | home |
      | two   |      |
      | left  | home |
    When I send the admin form "/admin/tasks/bulk" with:
      | act    | tag        |
      | filter | next       |
      | tag    | " Money "  |
      | ids[]  | {task:one} |
      | ids[]  | {task:two} |
    Then the database soon holds "left, home\none, home money\ntwo, money" for:
      """
      SELECT title, string_agg(name, ' ' ORDER BY name) FROM tasks JOIN task_tags ON task_id = tasks.id
      JOIN tags ON tags.id = tag_id GROUP BY title ORDER BY title
      """
    And the database soon holds "one, tagged, money\ntwo, tagged, money" for:
      """
      SELECT title, kind, tag_name FROM task_events JOIN tasks ON tasks.id = task_id ORDER BY title
      """
    When I follow the admin answer
    Then the toast says "Tagged 2 tasks money"

  Scenario: A tag a task has already keeps one and records nothing
    Given the tasks:
      | title | tags  |
      | one   | money |
    When I send the admin form "/admin/tasks/bulk" with:
      | act    | tag        |
      | filter | next       |
      | tag    | money      |
      | ids[]  | {task:one} |
    Then the database soon holds "1" for:
      """
      SELECT count(*) FROM task_tags
      """
    And the task_events table holds 0 rows

  Scenario: An untag takes the tag off the ticked tasks and records it on each
    Given the tasks:
      | title | tags       |
      | one   | home money |
      | two   | money      |
      | left  | money      |
    When I send the admin form "/admin/tasks/bulk" with:
      | act    | untag      |
      | filter | next       |
      | tag    | money      |
      | ids[]  | {task:one} |
      | ids[]  | {task:two} |
    Then the database soon holds "left, money\none, home" for:
      """
      SELECT title, string_agg(name, ' ' ORDER BY name) FROM tasks JOIN task_tags ON task_id = tasks.id
      JOIN tags ON tags.id = tag_id GROUP BY title ORDER BY title
      """
    And the database soon holds "one, untagged, money\ntwo, untagged, money" for:
      """
      SELECT title, kind, tag_name FROM task_events JOIN tasks ON tasks.id = task_id ORDER BY title
      """
    When I follow the admin answer
    Then the toast says "Took money off 2 tasks"

  Scenario Outline: <act> on one ticked task on <list> says so
    Given the tasks:
      | title | tags  | list   |
      | one   | money | <list> |
    When I send the admin form "/admin/tasks/bulk" with:
      | act    | <act>      |
      | filter | next       |
      | to     | <to>       |
      | tag    | money      |
      | ids[]  | {task:one} |
    And I follow the admin answer
    Then the toast says "<said>"

    Examples:
      | act    | list    | to       | said                     |
      | cancel | next    |          | Canceled 1 task          |
      | delete | next    |          | Deleted 1 task           |
      | move   | next    | external | Moved 1 task to external |
      | untag  | next    |          | Took money off 1 task    |
      | move   | someday | next     | Moved 1 task to next     |

  Scenario Outline: A <act> with a task that is gone changes nothing and names it
    Given the tasks:
      | title | tags  |
      | one   | money |
      | two   | money |
    When I send the admin form "/admin/tasks/bulk" with:
      | act    | <act>      |
      | filter | next       |
      | to     | someday    |
      | tag    | <tag>      |
      | ids[]  | {task:one} |
      | ids[]  | {task:two} |
      | ids[]  | 999        |
    Then the database soon holds "one next open money, two next open money" for:
      """
      SELECT string_agg(title || ' ' || list || ' ' || status || ' ' || name, ', ' ORDER BY title)
      FROM tasks JOIN task_tags ON task_id = tasks.id JOIN tags ON tags.id = tag_id
      """
    And the task_events table holds 0 rows
    When I follow the admin answer
    Then the toast says "Nothing changed · #999 is gone"

    Examples:
      | act      | tag   |
      | move     | money |
      | tag      | home  |
      | untag    | money |
      | complete | money |
      | cancel   | money |
      | delete   | money |

  Scenario: A cancel that reaches a closed task changes nothing and names it
    Given the tasks:
      | title          | status |
      | one            | open   |
      | Filed already  | done   |
    When I send the admin form "/admin/tasks/bulk" with:
      | act    | cancel               |
      | filter | next                 |
      | ids[]  | {task:one}           |
      | ids[]  | {task:Filed already} |
    Then the database soon holds "Filed already done, one open" for:
      """
      SELECT string_agg(title || ' ' || status, ', ' ORDER BY title) FROM tasks
      """
    When I follow the admin answer
    Then the toast says "Nothing changed · 2 Filed already is closed already"

  Scenario: A complete that reaches a closed task changes nothing and names it
    Given the tasks:
      | title   | status   |
      | one     | open     |
      | Dropped | canceled |
    And the database runs:
      """
      UPDATE tasks SET completed_at = date_trunc('second', now()) - interval '1 day' WHERE title = 'Dropped'
      """
    When I send the admin form "/admin/tasks/bulk" with:
      | act    | complete       |
      | filter | next           |
      | ids[]  | {task:one}     |
      | ids[]  | {task:Dropped} |
    Then the database soon holds "Dropped, canceled, true\none, open, false" for:
      """
      SELECT title, status, coalesce(completed_at < now() - interval '23 hours', false) FROM tasks ORDER BY title
      """
    When I follow the admin answer
    Then the toast says "Nothing changed · 2 Dropped is closed already"

  Scenario: The bar lands back on the list, the search, the pool and the page it came from
    Given the tasks:
      | title      | list    | sprint |
      | Someday it | someday |        |
      | Next it    | next    |        |
      | Today it   |         | today  |
    When I send the admin form "/admin/tasks/bulk" with:
      | act    | complete          |
      | filter | someday           |
      | ids[]  | {task:Someday it} |
    Then the admin answer goes to "/admin/tasks?filter=someday"
    When I send the admin form "/admin/tasks/bulk" with:
      | act    | complete       |
      | filter | next           |
      | q      | tag:site       |
      | ids[]  | {task:Next it} |
    Then the admin answer goes to "/admin/tasks?filter=next&q=tag:site"
    When I send the admin form "/admin/tasks/bulk" with:
      | act    | complete        |
      | filter | today           |
      | pool   | someday         |
      | ids[]  | {task:Today it} |
    Then the admin answer goes to "/admin/tasks?filter=today&pool=someday"
    When I send the admin form "/admin/tasks/bulk" with:
      | act    | complete |
      | filter | someday  |
      | ids[]  | 999      |
    Then the admin answer goes to "/admin/tasks?filter=someday"

  Scenario: The bar keeps the page while it still has rows and steps back once it empties
    Given 102 more tasks on next called "Water"
    When I send the admin form "/admin/tasks/bulk" with:
      | act    | complete         |
      | filter | next             |
      | page   | 2                |
      | ids[]  | {task:Water 102} |
    Then the admin answer goes to "/admin/tasks?filter=next&page=2"
    When I send the admin form "/admin/tasks/bulk" with:
      | act    | complete         |
      | filter | next             |
      | page   | 2                |
      | ids[]  | {task:Water 101} |
    Then the admin answer goes to "/admin/tasks?filter=next"

  Scenario: The bar keeps a page of finished tasks while it still has rows
    Given 101 more tasks on next called "Finished"
    And the database runs:
      """
      UPDATE tasks SET status = 'canceled', completed_at = now() - interval '1 minute'
      """
    When I send the admin form "/admin/tasks/bulk" with:
      | act    | tag                |
      | filter | completed          |
      | tag    | home               |
      | page   | 2                  |
      | ids[]  | {task:Finished 1}  |
    Then the admin answer goes to "/admin/tasks?filter=completed&page=2"

  Scenario: The bar steps back a page when the search no longer reaches it
    Given 100 more tasks on next called "Water plants"
    And the tasks:
      | title      |
      | Water lawn |
    When I send the admin form "/admin/tasks/bulk" with:
      | act    | complete          |
      | filter | next              |
      | q      | water             |
      | page   | 2                 |
      | ids[]  | {task:Water lawn} |
    Then the admin answer goes to "/admin/tasks?filter=next&q=water"

  Scenario Outline: The bar refuses <what>
    Given the tasks:
      | title |
      | one   |
    When I send the admin form "/admin/tasks/bulk" with:
      | act    | <act>      |
      | filter | next       |
      | to     | <to>       |
      | tag    | <tag>      |
      | ids[]  | {task:one} |
    Then the database soon holds "one, next, open, 0" for:
      """
      SELECT title, list, status, (SELECT count(*) FROM task_tags) FROM tasks
      """
    When I follow the admin answer
    Then the toast says "<said>"

    Examples:
      | what                  | act     | to | tag        | said                                                                |
      | a move with no list   | move    |    |            | Pick a list first                                                   |
      | a tag with no name    | tag     |    | " "        | Type a tag first                                                    |
      | a tag that is no slug | tag     |    | not a tag! | Nothing changed · a tag takes lowercase letters, numbers and dashes |
      | an action off the bar | archive |    |            | Nothing changed · pick an action from the bar                       |

  Scenario: The bar asks for a tick, and refuses more than 100 tasks before it changes any
    Given 101 more tasks on next called "Plan"
    When I send the admin form "/admin/tasks/bulk" with:
      | act    | complete |
      | filter | next     |
    And I follow the admin answer
    Then the toast says "Tick a task first"
    When I send the admin form "/admin/tasks/bulk" for the tasks on next with:
      | act    | complete |
      | filter | next     |
    And I follow the admin answer
    Then the toast says "Tick 100 tasks or fewer"
    And the database soon holds "101" for:
      """
      SELECT count(*) FROM tasks WHERE status = 'open'
      """
    When I send the admin form "/admin/tasks/bulk" with the task "Plan 1" ticked 101 times and:
      | act    | complete |
      | filter | next     |
    And I follow the admin answer
    Then the toast says "Finished 1 task"

  Scenario: The bar ignores the move and tag fields on other actions
    Given the tasks:
      | title |
      | one   |
    When I send the admin form "/admin/tasks/bulk" with:
      | act    | complete   |
      | filter | next       |
      | to     |            |
      | tag    | not a tag! |
      | ids[]  | {task:one} |
    Then the database soon holds "done" for:
      """
      SELECT status FROM tasks
      """
