Feature: The task lists
  The tasks screen shows one list at a time behind a tab for each, with counts, a card that names the list and a
  quick add.

  Background:
    Given I am signed in to the admin

  Scenario Outline: The <filter> tab shows only its tasks and marks itself current
    Given the tasks:
      | title                | list    | sprint |
      | Ship the screen      |         | today  |
      | Email the accountant | next    |        |
      | Learn Elixir         | someday |        |
    When I visit "/admin/tasks?filter=<filter>"
    Then the task rows read "<listed>"
    And the page has ".task-tabs .screen-tab[aria-current='page']:has-text('<tab>')"
    And the page has no axe breaches in light or dark

    Examples:
      | filter  | tab     | listed               |
      | today   | today   | Ship the screen      |
      | next    | next    | Email the accountant |
      | someday | someday | Learn Elixir         |
      | later   | today   | Ship the screen      |

  Scenario: The tasks screen heads itself and offers a tab for each list
    Given the tasks:
      | title           | sprint |
      | Ship the screen | today  |
    When I visit "/admin/tasks"
    Then the page title is "Tasks | Admin | Aaron Allen"
    And the task rows read "Ship the screen"
    And the page parts ".page-head + .screen-tabs a.screen-tab" have "href" set to "/admin/tasks | /admin/calendar | /admin/projects"
    And the page parts ".task-tabs .screen-tab span:first-of-type" read "today | upcoming | next | someday | external | recurring | completed"
    And the page part ".page-head-sub" holds "Sprint {long:today}"
    And the page part ".page-head-sub" holds "1 open in today · 0 carried in · 0 finished today"
    And the page part ".card-title" reads "Sprint · {short:today}"

  Scenario Outline: A <status> task counts on its tabs and as finished today, but on no open list
    Given the tasks:
      | title                | list    | sprint | status   |
      | Ship the screen      |         | today  | open     |
      | Email the accountant | next    |        | open     |
      | Learn Elixir         | someday |        | open     |
      | Filed already        | next    |        | <status> |
    When I visit "/admin/tasks?filter=someday"
    Then the page parts ".task-tab-count" read "1 | 0 | 1 | 1 | 0 | 0 | 1"
    When I visit "/admin/tasks?filter=next"
    Then the task rows read "Email the accountant"
    When I visit "/admin/tasks"
    Then the page part ".page-head-sub" holds "1 finished today"
    When I visit "/admin/tasks?filter=completed"
    Then the page has ".task-title:text-is('Filed already')"

    Examples:
      | status   |
      | done     |
      | canceled |

  Scenario: A task finished on an earlier day counts on completed but not as finished today
    Given the tasks:
      | title         | status |
      | Filed earlier | done   |
    And the database runs:
      """
      UPDATE tasks SET completed_at = date_trunc('day', now() AT TIME ZONE 'America/Chicago') AT TIME ZONE 'America/Chicago' - interval '1 minute'
      """
    When I visit "/admin/tasks"
    Then the page part ".page-head-sub" holds "0 finished today"
    And the page part ".task-tab-count >> nth=-1" reads "1"

  Scenario Outline: A finished task stays off the <filter> tab
    Given the tasks:
      | title         | list   | sprint   | status |
      | Filed already | <list> | <sprint> | done   |
    When I visit "/admin/tasks?filter=<filter>"
    Then the page has no ".task-title:text-is('Filed already')"

    Examples:
      | filter   | list    | sprint    |
      | today    |         | today     |
      | upcoming |         | today + 1 |
      | next     | next    |           |
      | someday  | someday |           |

  Scenario: Nothing carried into a sprint says so
    When I visit "/admin/tasks"
    Then the page part ".page-head-sub" holds "0 carried in"

  Scenario Outline: The <filter> card names its list, counts what is open and quick adds into it
    Given the tasks:
      | title                | list    |
      | Email the accountant | next    |
      | Learn Elixir         | someday |
    When I visit "/admin/tasks?filter=<filter>"
    Then the page part ".card-title" reads "<title>"
    And the page part ".card-blurb" holds "<blurb>"
    And the page part ".card-note" reads "1 open"
    And the page has no ".task-capture"
    And the page part ".task-list form.quick-add" has "action" set to "/admin/tasks"
    And the page field ".task-list form.quick-add [name='filter']" holds "<filter>"

    Examples:
      | filter  | title   | blurb                          |
      | next    | Next    | queued up, not today           |
      | someday | Someday | maybe, eventually, probably not |

  Scenario: The today card quick adds into today, and a quick add files the task in its list
    When I visit "/admin/tasks?filter=today"
    Then the page field ".task-list form.quick-add [name='filter']" holds "today"
    When I send the admin form "/admin/tasks" with:
      | filter      | someday    |
      | task[title] | Learn Rust |
    Then the database soon holds "someday" for:
      """
      SELECT list FROM tasks WHERE title = 'Learn Rust'
      """

  Scenario: The Select button shows with bulk mode off, and not on an empty list, upcoming or completed
    Given the tasks:
      | title                |
      | Email the accountant |
    When I visit "/admin/tasks?filter=next"
    Then the page has ".page-head-actions button.bt[data-bulk-toggle='task-bulk'][aria-pressed='false']"
    And the page has "form#task-bulk[data-bulk-off]"
    When I visit "/admin/tasks?filter=next&q=nothing matches this"
    Then the page has no "[data-bulk-toggle]"
    When I visit "/admin/tasks?filter=upcoming"
    Then the page has no "[data-bulk-toggle]"
    When I visit "/admin/tasks?filter=completed"
    Then the page has no "[data-bulk-toggle]"

  Scenario: A list orders its tasks by position, and an empty list says so
    When I visit "/admin/tasks?filter=next"
    Then the page part ".empty" reads "Nothing waiting."
    When I visit "/admin/tasks?filter=someday"
    Then the page part ".empty" reads "Nothing parked."
    Given the tasks:
      | title  | position |
      | second | 2        |
      | first  | 1        |
    When I visit "/admin/tasks?filter=next"
    Then the task rows read "first, second"

  Scenario: The external tab lists the open imported issues and keeps them off the other lists
    Given the tasks:
      | title                | list     | status | tags |
      | Email the accountant | next     | open   |      |
      | Learn Elixir         | someday  | open   |      |
      | Fix the feed         | external | open   | site |
      | Shipped already      | external | done   |      |
    And the task_sources table holds the rows:
      | task_id               | provider | remote_id | url                                                     |
      | {task:Fix the feed}    | github   | 42        | https://github.com/aaronmallen/aaronmallen.me/issues/42 |
      | {task:Shipped already} | github   | 43        | https://github.com/aaronmallen/aaronmallen.me/issues/43 |
    When I visit "/admin/tasks?filter=external"
    Then the task rows read "Fix the feed"
    And the page has ".task-tabs .screen-tab[aria-current='page']:has-text('external')"
    And the page part ".card-title" reads "External"
    And the page part ".card-blurb" holds "open GitHub and Linear issues assigned to you"
    And the page has no "form.quick-add"
    And the page part ".task .task-meta a.task-source" reads "aaronmallen/aaronmallen.me#42"
    And the page part ".task .task-meta a.task-source" has "href" set to "https://github.com/aaronmallen/aaronmallen.me/issues/42"
    And the page has ".task-source i.fa-brands.fa-github"
    And the page parts ".task-acts form[action*='/move/']" have "action" set to "/admin/tasks/{task:Fix the feed}/move/today"
    And the page parts ".task-acts form[action*='/move/']:has(button[data-key='m'])" have "action" set to "/admin/tasks/{task:Fix the feed}/move/today"
    And the page has no axe breaches in light or dark
    When I visit "/admin/tasks?filter=next"
    Then the task rows read "Email the accountant"
    And the page has no ".task-source"
    And the page part ".task-tabs .screen-tab:has-text('external') .task-tab-count" reads "1"
    And the page has ".task-tabs .screen-tab:has-text('external') .task-tab-count.w"
    When I visit "/admin/tasks?filter=someday"
    Then the task rows read "Learn Elixir"

  Scenario: The external count goes plain once every issue is seen, and an empty external list says so
    Given the tasks:
      | title        | list     |
      | Fix the feed | external |
    And the task_sources table holds the rows:
      | task_id             | provider | remote_id | url                                                     | seen_at |
      | {task:Fix the feed} | github   | 42        | https://github.com/aaronmallen/aaronmallen.me/issues/42 | now     |
    When I visit "/admin/tasks?filter=next"
    Then the page has no ".task-tab-count.w"
    Given the database runs:
      """
      DELETE FROM tasks
      """
    When I visit "/admin/tasks?filter=external"
    Then the page part ".empty" reads "No open issues assigned to you."

  Scenario: A Linear row links its issue by its own workspace and key, with Linear's mark
    Given the tasks:
      | title            | list     |
      | Fix the feed     | external |
      | Ship the release | external |
      | Write the notes  | external |
    And the task_sources table holds the rows:
      | task_id                 | provider | remote_id | url                                                      |
      | {task:Fix the feed}     | github   | 42        | https://github.com/aaronmallen/aaronmallen.me/issues/42  |
      | {task:Ship the release} | linear   | lin-1     | https://linear.app/acme/issue/ABC-123/ship-the-release   |
      | {task:Write the notes}  | linear   | lin-2     | https://linear.app/globex/issue/ABC-124/write-the-notes  |
    When I visit "/admin/tasks?filter=external"
    Then the page has ".task .task-meta a.task-source[href='https://linear.app/acme/issue/ABC-123/ship-the-release']:has-text('acme/ABC-123') i.linear-mark[aria-hidden='true']"
    And the page has no "a.task-source:has-text('acme/ABC-123') i.fa-github"
    And the page has "a[href='https://linear.app/globex/issue/ABC-124/write-the-notes']:has-text('globex/ABC-124')"
    And the page has "a[href='https://github.com/aaronmallen/aaronmallen.me/issues/42']:has-text('aaronmallen/aaronmallen.me#42')"

  Scenario: The editor of an imported task offers external and saves its tags and list
    Given the tasks:
      | title          | list     | tags |
      | Fix the feed   | external | site |
      | Write the post | next     |      |
    And the task_sources table holds the rows:
      | task_id             | provider | remote_id | url                                                     |
      | {task:Fix the feed} | github   | 42        | https://github.com/aaronmallen/aaronmallen.me/issues/42 |
    When I visit "/admin/tasks/{task:Fix the feed}/edit?filter=external"
    Then the page parts "#task-{task:Fix the feed}-form select[name='task[list]'] option" read "today | next | someday | external"
    And the page part "#task-{task:Fix the feed}-form option[selected]" reads "external"
    And the page has no axe breaches in light or dark
    When I fill in "Tags" in "#task-{task:Fix the feed}-form" with "site, bug"
    And I click "Save"
    Then the toast says "Task saved"
    And the database soon holds "external, bug site" for:
      """
      SELECT list, string_agg(name, ' ' ORDER BY name) FROM tasks JOIN task_tags ON task_id = tasks.id
      JOIN tags ON tags.id = tag_id WHERE title = 'Fix the feed' GROUP BY list
      """
    When I visit "/admin/tasks/{task:Fix the feed}/edit?filter=external"
    And I pick "next" in the page select "#task-{task:Fix the feed}-form select[name='task[list]']"
    And I click "Save"
    Then the toast says "Task saved"
    And the database soon holds "next" for:
      """
      SELECT list FROM tasks WHERE title = 'Fix the feed'
      """
    When I visit "/admin/tasks/{task:Write the post}/edit?filter=next"
    Then the page parts "#task-{task:Write the post}-form select[name='task[list]'] option" read "today | next | someday"

  Scenario: A linked task on external names external as its place
    Given the tasks:
      | title          | list     |
      | Fix the feed   | external |
      | Write the post | next     |
    And the task_links table holds the rows:
      | from_task_id          | to_task_id          | type    |
      | {task:Write the post} | {task:Fix the feed} | relates |
    When I visit "/admin/tasks/{task:Write the post}?filter=next"
    Then the page part ".task-link-place" reads "external"

  Scenario: The pull in column heads the sprint once and lists what waits in next
    Given the tasks:
      | title                | list     | tags  |
      | Email the accountant | next     | admin |
      | Learn Elixir         | someday  |       |
      | Fix the feed         | external |       |
      | Filed already        | next     |       |
    And the database runs:
      """
      UPDATE tasks SET status = 'done', completed_at = now() WHERE title = 'Filed already'
      """
    And the task_sources table holds the rows:
      | task_id             | provider | remote_id | url                                                     |
      | {task:Fix the feed} | github   | 42        | https://github.com/aaronmallen/aaronmallen.me/issues/42 |
    When I visit "/admin/tasks?filter=today"
    Then the page part ".g-main > aside.task-pull .card-title" reads "Pull in"
    And the page parts ".task-pull :is(.card-title, .card-label)" read "Pull in"
    And the page part ".task-list .empty" reads "Nothing open in today's sprint."
    And the page parts ".task-pull .li-title" read "Email the accountant"
    And the page parts ".task-pull .seg-option" read "next · 1 | someday · 1 | external · 1"
    And the page parts ".task-pull .seg-option" have "href" set to "/admin/tasks?filter=today&pool=next | /admin/tasks?filter=today&pool=someday | /admin/tasks?filter=today&pool=external"
    And the page has no ".task-pull .task-meta .task-mark"
    And the page parts ".task-pull .task-meta .tag" read "#admin"
    And the page parts ".task-pull .li-side form" have "action" set to "/admin/tasks/{task:Email the accountant}/move/today"
    And the page has no axe breaches in light or dark

  Scenario: The pull in column offers nothing finished and says which pool is empty
    Given the tasks:
      | title                | status |
      | Email the accountant | done   |
    When I visit "/admin/tasks?filter=today"
    Then the page parts ".task-pull .seg-option" read "next · 0 | someday · 0 | external · 0"
    And the page part ".task-pull .empty" reads "Nothing in next yet."
    When I visit "/admin/tasks?filter=today&pool=someday"
    Then the page part ".task-pull .empty" reads "Nothing in someday yet."
    And the page has ".task-pull nav.seg a.seg-option.current[aria-current='page'][data-pool='someday']:text-is('someday · 0')"

  Scenario: The pull in column shows the pool asked for, and a pull returns to it
    Given the tasks:
      | title                | list    | tags  |
      | Email the accountant | next    |       |
      | Learn Elixir         | someday | admin |
    When I visit "/admin/tasks?filter=today&pool=someday"
    Then the page parts ".task-pull .li-title" read "Learn Elixir"
    And the page parts ".task-pull [data-pool-panel]" have "data-pool-panel" set to "someday"
    And the page parts ".task-pull form [name='pool']" have "value" set to "someday"
    And the page has "a[href='/admin/tags/admin']:has-text('#admin')"
    When I send the admin form "/admin/tasks/{task:Learn Elixir}/move/today" with:
      | filter | today   |
      | origin | tasks   |
      | pool   | someday |
    Then the admin answer goes to "/admin/tasks?filter=today&pool=someday"

  Scenario: The pull in column holds no more than a page of tasks
    Given 101 more tasks on next called "Waiting"
    When I visit "/admin/tasks?filter=today"
    Then the page has 100 of ".task-pull .li-title"

  Scenario: The pull in column names external when it is empty, and stays off the other lists
    When I visit "/admin/tasks?filter=today&pool=external"
    Then the page part ".task-pull .empty" reads "Nothing in external. Sync issues from the External tab."
    When I visit "/admin/tasks?filter=next"
    Then the page has no ".task-pull"

  Scenario: The pull in column stays once the sprint holds a task
    Given the tasks:
      | title                | sprint |
      | Ship it              | today  |
      | Email the accountant |        |
    When I visit "/admin/tasks?filter=today"
    Then the task rows read "Ship it"
    And the page parts ".task-pull .li-title" read "Email the accountant"

  Scenario: The external pool lists the imported tasks with their issues, and pulls one into today
    Given the tasks:
      | title                | list     |
      | Email the accountant | next     |
      | Fix the feed         | external |
      | Ship the release     | external |
    And the task_sources table holds the rows:
      | task_id                 | provider | remote_id | url                                                     |
      | {task:Fix the feed}     | github   | 42        | https://github.com/aaronmallen/aaronmallen.me/issues/42 |
      | {task:Ship the release} | linear   | lin-1     | https://linear.app/acme/issue/ABC-123/ship-the-release  |
    When I visit "/admin/tasks?filter=today&pool=external"
    Then the page parts ".task-pull .li-title" read "Fix the feed | Ship the release"
    And the page has "a[href='https://github.com/aaronmallen/aaronmallen.me/issues/42']:has-text('aaronmallen/aaronmallen.me#42')"
    And the page has "a[href='https://linear.app/acme/issue/ABC-123/ship-the-release']:has-text('acme/ABC-123')"
    When I send the admin form "/admin/tasks/{task:Fix the feed}/move/today" with:
      | origin | tasks |
    And I visit "/admin/tasks?filter=today"
    Then the database soon holds "true" for:
      """
      SELECT list IS NULL AND sprint_id = (SELECT id FROM sprints WHERE sprint_date = (now() AT TIME ZONE 'America/Chicago')::date)
      FROM tasks WHERE title = 'Fix the feed'
      """
    And the page part ".task .task-meta a.task-source" has "href" set to "https://github.com/aaronmallen/aaronmallen.me/issues/42"
