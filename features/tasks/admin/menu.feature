Feature: The task row menu
  Each task row opens a menu of what the task can do next, and each action lands back on the page the menu opened on.

  Background:
    Given I am signed in to the admin

  Scenario: The menu of an open task offers every action an open task takes
    Given the tags table holds the rows:
      | name | color   | scope   |
      | home | mk-blue | private |
      | ruby | mk-blue | public  |
    And the tasks:
      | title   | tags |
      | Ship it | home |
    When I visit "/admin/tasks/{task:Ship it}/menu?return_to=/admin/tasks?filter=next&filter=next&origin=tasks"
    Then the page part "[data-context-menu] > .ctx-head" reads "1 · Ship it"
    And the page parts "[data-context-menu] .ctx-label" read "Open | Start | Complete | Pull into today's sprint | Move to | Today | Next | Someday | External | Schedule | Today's sprint | Tomorrow | Tags | #home | Copy | Task number | Title | Cancel task | Delete"
    And the page has "a.ctx-item[href='/admin/tasks/{task:Ship it}?filter=next&origin=tasks']"
    And the page has no "[data-context-menu] form:not([data-morph])"
    And every page part "[data-context-menu] form input[name=return_to]" has "value" set to "/admin/tasks?filter=next"
    And the page has "[role=menuitemcheckbox][aria-checked=true]:has-text('#home')"
    And the page has no "[role=menuitemcheckbox]:has-text('#ruby')"
    And the page has "form[action='/admin/tasks/bulk'] input[name=act][value=untag] ~ input[name='ids[]'][value='{task:Ship it}'] ~ input[name=tag][value=home]"
    And the page has "button[data-confirm-inline='Click again to delete']"
    And the page has "button.ctx-item[disabled]:has-text('Next')"

  Scenario: The menu of a task that is gone answers 404
    When I visit "/admin/tasks/0/menu"
    Then the server answers 404

  Scenario: The menu of a task on today's sprint disables Today
    Given the tasks:
      | title   | sprint |
      | Ship it | today  |
    When I visit "/admin/tasks/{task:Ship it}/menu"
    Then the page has "button.ctx-item[disabled]:has-text('Today')"

  Scenario: The menu of a task on a later sprint lets it move to Today
    Given the tasks:
      | title   | sprint    |
      | Ship it | today + 1 |
    When I visit "/admin/tasks/{task:Ship it}/menu"
    Then the page has "button.ctx-item:not([disabled]):has-text('Today')"
    And the page has no "button.ctx-item[disabled]"

  Scenario: The menu of a running task offers pause and leaves out the pull
    Given the tasks:
      | title   | sprint | status      |
      | Ship it | today  | in_progress |
      | Plan it | today  | open        |
    When I visit "/admin/tasks/{task:Ship it}/menu"
    Then the page has ".ctx-label:text-is('Pause')"
    And the page has no ".ctx-label:text-is('Start')"
    When I visit "/admin/tasks/{task:Plan it}/menu"
    Then the page has no ".ctx-label:has-text('Pull into today')"

  Scenario: The menu of a closed task offers reopen and nothing that needs it open
    Given the tasks:
      | title    | status |
      | Filed it | done   |
    When I visit "/admin/tasks/{task:Filed it}/menu"
    Then the page has ".ctx-label:text-is('Reopen')"
    And the page has no ".ctx-label:text-is('Start'), .ctx-label:text-is('Complete'), .ctx-label:text-is('Cancel task'), .ctx-label:text-is('Move to'), .ctx-label:text-is('Schedule')"

  Scenario: The menu of an external task opens and copies the issue and marks it seen
    Given the tasks:
      | title       | list     |
      | Fix the bug | external |
    And the task_sources table holds the rows:
      | task_id            | provider | remote_id | url                                                   |
      | {task:Fix the bug} | github   | 7         | https://github.com/aaronmallen/aaronmallen.me/issues/7 |
    When I visit "/admin/tasks/{task:Fix the bug}/menu"
    Then the page has "a.ctx-item[href$='/issues/7'][target=_blank]"
    And the page has "[data-copy$='/issues/7']"
    And the page has "form[action='/admin/inbox/tasks/{task:Fix the bug}/seen']"

  Scenario: Task rows carry the menu on the list, in the sprint pool and in the calendar day panel
    Given the tasks:
      | title      | sprint |
      | Plan it    |        |
      | Ship today | today  |
    When I visit "/admin/tasks?filter=next"
    Then the page has ".task[data-menu='/admin/tasks/{task:Plan it}/menu?filter=next&origin=tasks']"
    And the page has no axe breaches in light or dark
    When I visit "/admin"
    Then the page has "[data-pools] .li[data-menu^='/admin/tasks/{task:Plan it}/menu']"
    When I visit "/admin/calendar?day={day:today}"
    Then the page has "[data-calendar-panel] .li[data-menu='/admin/tasks/{task:Ship today}/menu']"

  Scenario: Actions from the menu land back on the page the menu opened on
    Given the tasks:
      | title       | list     |
      | Plan it     | next     |
      | Tag it      | next     |
      | Fix the bug | external |
    And the task_sources table holds the rows:
      | task_id            | provider | remote_id | url                                                   |
      | {task:Fix the bug} | github   | 7         | https://github.com/aaronmallen/aaronmallen.me/issues/7 |
    When I send the admin form "/admin/tasks/{task:Plan it}/move/someday" with:
      | return_to | /admin |
    Then the admin answer goes to "/admin"
    When I send the admin form "/admin/tasks/bulk" with:
      | return_to | /admin          |
      | act       | tag             |
      | ids[]     | {task:Tag it}   |
      | tag       | home            |
    Then the admin answer goes to "/admin"
    And the database soon holds "home" for:
      """
      SELECT tags.name FROM task_tags JOIN tags ON tags.id = tag_id JOIN tasks ON tasks.id = task_id WHERE title = 'Tag it'
      """
    When I send the admin form "/admin/inbox/tasks/{task:Fix the bug}/seen" with:
      | return_to | /admin |
    Then the admin answer goes to "/admin"
    When I send the admin form "/admin/tasks/{task:Plan it}/delete" with:
      | return_to | https://example.com/ |
    Then the admin answer goes to a page starting "/admin/tasks"

  Scenario: A bad tag name from the menu is refused
    Given the tasks:
      | title   |
      | Plan it |
    When I send the admin form "/admin/tasks/bulk" with:
      | return_to | /admin        |
      | act       | tag           |
      | ids[]     | {task:Plan it} |
      | tag       | no good       |
    And I follow the admin answer
    Then the toast says "Nothing changed · a tag takes lowercase letters, numbers and dashes"
