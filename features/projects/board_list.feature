Feature: The project board as a list
  The board page also draws a list view, one folding group per column, and lets the browser pick which to show
  unless the address names one.

  Background:
    Given I am signed in to the admin
    And the projects:
      | name | key |
      | blog | BLO |

  Scenario: The page draws the board and the list, with one group per column, and leaves the pick to the browser
    Given the project tasks:
      | title    | project | status      | stage |
      | Plan it  | blog    | open        |       |
      | Ready it | blog    | open        | ready |
      | Do it    | blog    | in_progress |       |
      | Ship it  | blog    | done        |       |
      | Drop it  | blog    | canceled    |       |
    And the admin scripts do not load
    When I visit "/admin/projects/{project:blog}"
    Then the page has ".kb-views[data-board-views]:not([data-board-view])"
    And the page has ".kb-views > [data-board-shows='board'] .kb"
    And the page has ".kb-views > [data-board-shows='list'] .kls3"
    And the page parts ".kb-meta > .kb-view .seg a.seg-option" read "board | list"
    And the page parts ".kb-meta > .kb-view .seg a.seg-option" have "href" set to "/admin/projects/1?view=board | /admin/projects/1?view=list"
    And the page parts ".kb-meta > .kb-view .seg a.seg-option" have "data-board-pick" set to "board | list"
    And the page parts ".kb-view a.seg-option i" have "class" set to "fa-solid fa-table-columns | fa-solid fa-list"
    And the page has no ".kb-view .current"
    And the page parts ".kls3 > section.klg h2" read "backlog | ready | in progress | done | canceled"
    And the page parts ".kls3 > section.klg .kcol-count" read "1 | 1 | 1 | 1 | 1"
    And the page parts ".kb-list section.klg .kli .task-title" read "Plan it | Ready it | Do it | Ship it | Drop it"
    And the page parts ".kls3 details[open] > summary.klh h2" read "backlog | ready | in progress | done"
    And the page has ".kb-list section.klg.k-canceled details:not([open]) > summary.klh"
    And the page parts ".kls3 > section[data-board-column]" have "data-board-column" set to "backlog | ready | in_progress | done | canceled"
    And the page part ".kb-list > p.hint" reads "Pick a task's column, or drag its row onto another group. In progress starts the task in today's sprint; done and canceled close it."
    And the page part ".kb-list section.klg.k-backlog .kli[data-board-card] > .task[data-key-row] a.task-title" reads "Plan it"
    And the page has no ".kli [data-task-grip]"
    And the page has ".kb-list section.klg.k-backlog .task[data-menu*='project=1']"
    And the page has ".kb-list section.klg.k-in_progress .task form input[name=return_to][value='/admin/projects/1']"
    And the page has no ".kb-list section.klg.k-in_progress .task form input[name=return_to]:not([value='/admin/projects/1'])"
    And the page has no axe breaches in light or dark

  Scenario: Each row's column picker posts the move and goes back to the board
    Given the project tasks:
      | title   | project |
      | Plan it | blog    |
    When I visit "/admin/projects/{project:blog}"
    Then the page part "form.kls[action='/admin/projects/1/tasks/1/move']" has "method" set to "post"
    And the page has "form.kls[action='/admin/projects/1/tasks/1/move'][data-morph][data-autosubmit] input[name=return_to][value='/admin/projects/1']"
    And the page parts "form.kls[action='/admin/projects/1/tasks/1/move'] select[name=to] option" have "value" set to "backlog | ready | in_progress | done | canceled"
    And the page part "form.kls[action='/admin/projects/1/tasks/1/move'] select[name=to] option[selected]" has "value" set to "backlog"
    And the page part "form.kls[action='/admin/projects/1/tasks/1/move'] label" holds "Column for BLO-1"
    And the page part "form.kls[action='/admin/projects/1/tasks/1/move'] noscript" holds "Move"
    When I send the admin form "/admin/projects/1/tasks/1/move" with:
      | to        | done              |
      | return_to | /admin/projects/1 |
    Then the admin answer goes to "/admin/projects/1"
    And the database reads "done" for:
      """
      SELECT status FROM tasks
      """

  Scenario: A view in the address picks it and marks its link
    Given the admin scripts do not load
    When I visit "/admin/projects/{project:blog}?view=list"
    Then the page has ".kb-views[data-board-view='list']"
    And the page part ".kb-view a.seg-option.current[aria-current='page']" holds "list"
    When I visit "/admin/projects/{project:blog}?view=board"
    Then the page has ".kb-views[data-board-view='board']"
    When I visit "/admin/projects/{project:blog}?view=grid"
    Then the page has ".kb-views:not([data-board-view])"
    When I visit "/admin/projects/{project:blog}?backlog=40"
    Then the page part ".kb-view a:has-text('list')" has "href" set to "/admin/projects/1?backlog=40&view=list"

  Scenario: A full group shows the cap and grows alone
    Given 21 tasks in "blog" in the column "backlog"
    And 2 tasks in "blog" in the column "ready"
    When I visit "/admin/projects/{project:blog}"
    Then the page has 20 of ".kb-list section.klg.k-backlog .kli .task-title"
    And the page part ".kb-list section.klg.k-backlog form[data-autosubmit][method='get'] button" holds "Load more · 1 left"
    And the page has no ".kb-list section.klg.k-ready form[data-autosubmit][method='get']"
    And the page parts ".kb-list section.klg.k-backlog form[data-autosubmit][method='get'] input[type=hidden]" have "name" set to "backlog"
    And the page parts ".kb-list section.klg.k-backlog form[data-autosubmit][method='get'] input[type=hidden]" have "value" set to "40"
    When I visit "/admin/projects/{project:blog}?backlog=40"
    Then the page has 21 of ".kb-list section.klg.k-backlog .kli .task-title"

  Scenario: An old closed task drops out of its group
    Given the project tasks:
      | title   | project | status   | closed        |
      | Shipped | blog    | done     | now - 14 days |
      | Dropped | blog    | canceled | now - 1 day   |
    When I visit "/admin/projects/{project:blog}"
    Then the page has no ".kb-list section.klg.k-done .kli"
    And the page part ".kb-list section.klg.k-done .kcol-empty" holds "No tasks"
    And the page parts ".kb-list section.klg.k-canceled .kli .task-title" read "Dropped"
