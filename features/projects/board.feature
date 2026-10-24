Feature: The project board
  A project's board shows its tasks in five columns, moves a card or many ticked cards between them, and
  drops a task two weeks after it closed.

  Background:
    Given I am signed in to the admin
    And the projects:
      | name | key | tagline | repo             | url                    |
      | blog | BLO | My site | aaronmallen/blog | https://aaronmallen.me |

  Scenario: The board shows each task in its column with the project's facts and controls
    Given the project tasks:
      | title    | project | status      | stage |
      | Plan it  | blog    | open        |       |
      | Ready it | blog    | open        | ready |
      | Do it    | blog    | in_progress |       |
      | Ship it  | blog    | done        |       |
      | Drop it  | blog    | canceled    |       |
      | Elsewhere |        | open        |       |
    When I visit "/admin/projects/{project:blog}"
    Then the board columns read "Plan it / Ready it / Do it / Ship it / Drop it"
    And the page parts ".kb .kcol-count" read "1 | 1 | 1 | 1 | 1"
    And the page part ".page-head-title" holds "blog"
    And the page part ".page-head-sub" holds "My site"
    And the page part "a[href='https://github.com/aaronmallen/blog']" holds "aaronmallen/blog"
    And the page part "a[href='https://aaronmallen.me']" holds "aaronmallen.me"
    And the page part ".kb-meta" holds "3 open · 5 total"
    And the page part ".kb-meta" holds "board is private"
    And the page part "a:has-text('Edit Project')" has "href" set to "/admin/projects/1/edit"
    And the page part ".page-head-actions a:has-text('Create Task')" has "href" set to "/admin/tasks/new?project=BLO"
    And the page part "section.kcol.k-backlog a.kc-title[data-task-open][href^='/admin/tasks/']" reads "Plan it"
    And the page parts "section.kcol.k-ready .hov form[data-morph] input[name=to]" have "value" set to "backlog | in_progress"
    And the page parts "section.kcol.k-backlog .hov form[data-morph] input[name=to]" have "value" set to "ready"
    And the page parts "section.kcol.k-canceled .hov form[data-morph] input[name=to]" have "value" set to "done"
    And the page has "section.kcol.k-backlog form button[aria-label='Move to ready'][title='Move to ready']"
    And the page part "section.kcol.k-backlog form button[aria-label='Move to ready']" reads ""
    And the page has "button[data-bulk-toggle='board-bulk'][aria-pressed='false']"
    And the page has "form#board-bulk[data-bulk-off][action='/admin/projects/1/tasks/bulk']"
    And the page has 5 of ".kc input[type='checkbox'][name='ids[]'][form='board-bulk']"
    And the page parts "form#board-bulk select[name='to'] option" have "value" set to " | backlog | ready | in_progress | done | canceled"
    And the page has "section.kcol.k-backlog .kc[data-menu$='/menu?project=1']"
    And the page has no axe breaches in light or dark

  Scenario: The project menu offers the board first, and the editor links back to it
    When I fetch the admin page "/admin/projects/{project:blog}/menu"
    And I look at the admin answer
    Then the page part "a.ctx-item" has "href" set to "/admin/projects/1"
    When I visit "/admin/projects/{project:blog}/edit"
    Then the page part "a.editor-back" has "href" set to "/admin/projects/1"
    And the page part "a.editor-back" holds "blog board"

  Scenario: An archived project's board offers no Create Task, and a published board says so
    Given the projects:
      | name    | visibility | archived  | started    | board     |
      | gone    | public     | today - 1 | today - 30 |           |
      | shown   | public     |           |            | published |
      | hidden  | private    |           |            | published |
    When I visit "/admin/projects/{project:gone}"
    Then the page has no ".page-head-actions a:has-text('Create Task')"
    When I visit "/admin/projects/{project:shown}"
    Then the page part ".kb-meta .kb-published" holds "board published"
    When I visit "/admin/projects/{project:hidden}"
    Then the page part ".kb-meta" holds "board is private"
    When I visit "/admin/projects/999999"
    Then the server answers 404

  Scenario: A card's key joins the project key to the task's number and follows a new key
    Given the project tasks:
      | title    | project |
      | Plan it  | blog    |
      | Write it | blog    |
    When I visit "/admin/projects/{project:blog}"
    Then the page parts "section.kcol.k-backlog .record-key" read "BLO-1 | BLO-2"
    When I save a project in the admin with:
      | project       | blog             |
      | project[name] | blog             |
      | project[repo] | aaronmallen/blog |
      | project[key]  | WEB              |
    And I visit "/admin/projects/{project:blog}"
    Then the page parts "section.kcol.k-backlog .record-key" read "WEB-1 | WEB-2"

  Scenario: A card counts its open blocks and shows no link chips
    Given the project tasks:
      | title   | project |
      | Plan it | blog    |
    And the tasks:
      | title     | status   |
      | Blocked 1 | open     |
      | Blocked 2 | open     |
      | Shipped   | done     |
      | Blocker   | open     |
      | Dropped   | canceled |
      | Child     | open     |
      | Dupe      | open     |
      | Related   | open     |
    And the task "Plan it" blocks the task "Blocked 1"
    And the task "Plan it" blocks the task "Blocked 2"
    And the task "Plan it" blocks the task "Shipped"
    And the task "Blocker" blocks the task "Plan it"
    And the task "Dropped" blocks the task "Plan it"
    And the task "Child" is the parent of the task "Plan it"
    And the task "Plan it" duplicates the task "Dupe"
    And the task "Plan it" relates to the task "Related"
    When I visit "/admin/projects/{project:blog}"
    Then the page parts "section.kcol.k-backlog .kc .task-mark:has-text('block')" read "blocked by 1 | blocking 2"
    And the page has no "section.kcol.k-backlog .kc .task-link-label"

  Scenario: A card with only closed blocks shows no count
    Given the project tasks:
      | title   | project |
      | Plan it | blog    |
    And the tasks:
      | title   | status   |
      | Shipped | done     |
      | Dropped | canceled |
    And the task "Plan it" blocks the task "Shipped"
    And the task "Dropped" blocks the task "Plan it"
    When I visit "/admin/projects/{project:blog}"
    Then the page has no "section.kcol.k-backlog .kc .task-mark:has-text('block')"

  Scenario: The card menu offers every column with the card's own disabled, copies the label and returns to the board
    Given the project tasks:
      | title   | project |
      | Plan it | blog    |
    And the tasks:
      | title    |
      | Loose    |
    When I fetch the admin page "/admin/tasks/{task:Plan it}/menu?project=1&return_to=/admin/projects/1"
    And I look at the admin answer
    Then the page parts "form[action='/admin/projects/1/tasks/1/move'] input[name=to]" have "value" set to "backlog | ready | in_progress | done | canceled"
    And the page has "form[action='/admin/projects/1/tasks/1/move'] button[disabled]"
    And the page has "[data-copy='BLO-1']"
    And the page part "form[action='/admin/projects/1/tasks/1/move'] input[name=return_to]" has "value" set to "/admin/projects/1"
    When I fetch the admin page "/admin/tasks/{task:Loose}/menu"
    Then the answer does not show "Board column"

  Scenario: Moving ticked cards moves each to the column and says so
    Given the project tasks:
      | title | project | status |
      | Open  | blog    | open   |
      | Done  | blog    | done   |
    When I send the admin form "/admin/projects/{project:blog}/tasks/bulk" with:
      | act   | move        |
      | ids[] | 1           |
      | ids[] | 2           |
      | to    | in_progress |
    Then the admin answer goes to a page starting "/admin/projects/1"
    And the database reads "in_progress / in_progress" for:
      """
      SELECT status FROM tasks ORDER BY id
      """
    When I follow the admin answer
    Then the toast says "Moved 2 tasks to in progress"

  Scenario: Moving ticked cards into an open column puts the last ticked first, ahead of the column
    Given the project tasks:
      | title     | project | stage | status      | sprint | list    |
      | Waiting   | blog    | ready | open        |        | next    |
      | Elsewhere |         |       | open        |        | someday |
      | Plan it   | blog    |       | open        |        | next    |
      | Ship it   | blog    |       | in_progress | today  |         |
    When I send the admin form "/admin/projects/{project:blog}/tasks/bulk" with:
      | act   | move  |
      | ids[] | 3     |
      | ids[] | 4     |
      | to    | ready |
    And I visit "/admin/projects/{project:blog}"
    Then the page parts "section.kcol.k-ready .kc-title" read "Ship it | Plan it | Waiting"
    And the database reads "1 / 2" for:
      """
      SELECT position FROM tasks WHERE id IN (1, 2) ORDER BY id
      """

  Scenario: Moving ticked cards changes nothing when one is gone, too many are ticked, or no column is picked
    Given the project tasks:
      | title | project |
      | Plan  | blog    |
    When I send the admin form "/admin/projects/{project:blog}/tasks/bulk" with:
      | act   | move   |
      | ids[] | 1      |
      | ids[] | 999999 |
      | to    | done   |
    And I follow the admin answer
    Then the toast says "Nothing changed · #999999 is gone"
    When I send the admin form "/admin/projects/{project:blog}/tasks/bulk" with:
      | act   | move |
      | ids[] | 1    |
      | to    |      |
    And I follow the admin answer
    Then the toast says "Pick a column first"
    When a bulk board move of 101 cards to "done" goes to "blog"
    And I follow the admin answer
    Then the toast says "Tick 100 cards or fewer"
    And the database reads "open" for:
      """
      SELECT status FROM tasks
      """

  Scenario Outline: Moving a <from> card to <to> leaves it <status> in <stage>
    Given the project tasks:
      | title   | project | status   | stage   |
      | Plan it | blog    | <status0> | <stage0> |
    When I send the admin form "/admin/projects/{project:blog}/tasks/{task:Plan it}/move" with:
      | to | <to> |
    Then the database reads "<status>, <stage>, <open session>" for:
      """
      SELECT status, stage, EXISTS (SELECT 1 FROM work_sessions WHERE ended_at IS NULL) FROM tasks
      """

    Examples:
      | from        | status0     | stage0 | to          | status      | stage   | open session |
      | open        | open        |        | ready       | open        | ready   | false        |
      | ready       | open        | ready  | backlog     | open        | backlog | false        |
      | open        | open        |        | in_progress | in_progress | backlog | true         |
      | in progress | in_progress |        | done        | done        | backlog | false        |
      | open        | open        |        | canceled    | canceled    | backlog | false        |
      | done        | done        |        | canceled    | canceled    | backlog | false        |
      | done        | done        |        | ready       | open        | ready   | false        |
      | in progress | in_progress | ready  | backlog     | open        | backlog | false        |

  Scenario: Moving an open card to ready keeps its list and leaves no history
    Given the project tasks:
      | title   | project |
      | Plan it | blog    |
    When I send the admin form "/admin/projects/{project:blog}/tasks/{task:Plan it}/move" with:
      | to | ready |
    Then the admin answer goes to a page starting "/admin/projects/1"
    And the database reads "next, true" for:
      """
      SELECT list, completed_at IS NULL FROM tasks
      """
    And the database holds 0 task_events rows
    When I follow the admin answer
    Then the toast says "Moved BLO-1 to ready"

  Scenario: A moved card goes first in its new column
    Given the project tasks:
      | title    | project | stage | status      | sprint | list    |
      | Waiting  | blog    | ready | open        |        | next    |
      | Plan it  | blog    |       | open        |        | next    |
      | Doing    | blog    |       | in_progress | today  |         |
      | Someday  | blog    |       | open        |        | someday |
      | Queued   | blog    |       | open        |        | next    |
      | Ship it  | blog    |       | done        |        | next    |
    When I send the admin form "/admin/projects/{project:blog}/tasks/{task:Plan it}/move" with:
      | to | ready |
    And I send the admin form "/admin/projects/{project:blog}/tasks/{task:Someday}/move" with:
      | to | in_progress |
    And I send the admin form "/admin/projects/{project:blog}/tasks/{task:Ship it}/move" with:
      | to | backlog |
    And I visit "/admin/projects/{project:blog}"
    Then the page parts "section.kcol.k-ready .kc-title" read "Plan it | Waiting"
    And the page parts "section.kcol.k-in_progress .kc-title" read "Someday | Doing"
    And the page parts "section.kcol.k-backlog .kc-title" read "Ship it | Queued"

  Scenario: In progress starts a task in today's sprint, and done and canceled close it
    Given the project tasks:
      | title | project |
      | One   | blog    |
      | Two   | blog    |
      | Three | blog    |
    When I send the admin form "/admin/projects/{project:blog}/tasks/{task:One}/move" with:
      | to | in_progress |
    And I send the admin form "/admin/projects/{project:blog}/tasks/{task:Two}/move" with:
      | to | done |
    And I send the admin form "/admin/projects/{project:blog}/tasks/{task:Three}/move" with:
      | to | canceled |
    Then the database reads "One, in_progress, {day:today}, false / Two, done, , true / Three, canceled, , true" for:
      """
      SELECT title, status, coalesce(sprint_date::text, ''), completed_at IS NOT NULL FROM tasks
      LEFT JOIN sprints ON sprints.id = sprint_id ORDER BY tasks.id
      """
    When I visit "/admin/projects/{project:blog}"
    Then the page part "p.hint:has-text('Drag a card')" reads "Drag a card, or use its arrows or menu, to move it. Select moves several. In progress starts the task in today's sprint; done and canceled close it."

  Scenario: A card move goes back to the page the menu opened on, refuses an unknown column and a gone task
    Given the project tasks:
      | title   | project |
      | Plan it | blog    |
    When I send the admin form "/admin/projects/{project:blog}/tasks/{task:Plan it}/move" with:
      | to        | ready        |
      | return_to | /admin/tasks |
    Then the admin answer goes to "/admin/tasks"
    When I send the admin form "/admin/projects/{project:blog}/tasks/{task:Plan it}/move" with:
      | to | someday |
    Then the server answers 422
    When I send the admin form "/admin/projects/{project:blog}/tasks/0/move" with:
      | to | ready |
    Then the server answers 404

  Scenario: A full column shows 20 cards, offers the rest, and grows alone
    Given 21 tasks in "blog" in the column "backlog"
    And 21 tasks in "blog" in the column "ready"
    When I visit "/admin/projects/{project:blog}"
    Then the page has 20 of "section.kcol.k-backlog .kc-title"
    And the page part "section.kcol.k-backlog form[data-autosubmit][method='get'] button" holds "Load more · 1 left"
    And the page part "section.kcol.k-backlog form[data-autosubmit][method='get']" has "action" set to "/admin/projects/1"
    And the page parts "section.kcol.k-backlog form[data-autosubmit][method='get'] input[type=hidden]" have "value" set to "40"
    And the page parts ".kb .kcol-count" read "21 | 21 | 0 | 0 | 0"
    And the page part ".kb-meta" holds "42 open · 42 total"
    When I visit "/admin/projects/{project:blog}?backlog=40"
    Then the page has 21 of "section.kcol.k-backlog .kc-title"
    And the page has 20 of "section.kcol.k-ready .kc-title"
    And the page has no "section.kcol.k-backlog form[data-autosubmit]"
    And the page parts "section.kcol.k-ready form[data-autosubmit][method='get'] input[type=hidden]" have "name" set to "backlog | ready"
    And the page part "section.kcol.k-backlog .hov input[name=return_to]" has "value" set to "/admin/projects/1?backlog=40"
    And the page part "input[name=return_to][form=board-bulk]" has "value" set to "/admin/projects/1?backlog=40"
    When I visit "/admin/projects/{project:blog}?backlog=1"
    Then the page has 20 of "section.kcol.k-backlog .kc-title"

  Scenario: A card move and a bulk move go back to the grown board
    Given the project tasks:
      | title | project |
      | One   | blog    |
      | Two   | blog    |
    When I send the admin form "/admin/projects/{project:blog}/tasks/{task:One}/move" with:
      | to        | ready                        |
      | return_to | /admin/projects/1?backlog=40 |
    Then the admin answer goes to "/admin/projects/1?backlog=40"
    When I send the admin form "/admin/projects/{project:blog}/tasks/bulk" with:
      | act       | move                       |
      | ids[]     | 2                          |
      | to        | done                       |
      | return_to | /admin/projects/1?ready=40 |
    Then the admin answer goes to "/admin/projects/1?ready=40"

  Scenario: The done column shows the latest closed first and leaves old closed tasks out of its count
    Given the project tasks:
      | title  | project | status   | closed           |
      | Oldest | blog    | done     | now - 3 days     |
      | Newest | blog    | done     | now - 1 day      |
      | Middle | blog    | done     | now - 2 days     |
      | Old    | blog    | done     | now - 30 days    |
    When I visit "/admin/projects/{project:blog}"
    Then the page parts "section.kcol.k-done .kc-title" read "Newest | Middle | Oldest"
    And the page part "section.kcol.k-done .kcol-count" reads "3"
    And the page has no "section.kcol.k-done form[data-autosubmit]"

  Scenario: A task closed 14 days ago or more drops off the board but stays in the task list and MCP
    Given the project tasks:
      | title    | project | status   | closed                     |
      | Shipped  | blog    | done     | now - 14 days              |
      | Dropped  | blog    | canceled | now - 30 days              |
      | Recent   | blog    | done     | now - 14 days + 60 seconds |
      | Gone too | blog    | canceled | now - 1 day                |
    When I visit "/admin/projects/{project:blog}"
    Then the page parts "section.kcol.k-done .kc-title" read "Recent"
    And the page parts "section.kcol.k-canceled .kc-title" read "Gone too"
    And the page part ".kb-meta" holds "0 open · 2 total"
    When I visit "/admin/tasks?filter=completed"
    Then the page parts ".task-title" read "Gone too | Recent | Shipped | Dropped"
    Given an MCP client connected with the scopes "read"
    When I call the MCP tool "list_tasks" with:
      """
      { "statuses": ["done"] }
      """
    Then the MCP answer holds "Shipped"

  Scenario: A task reopened and closed again counts its days from the last close
    Given the project tasks:
      | title         | project | status | closed        |
      | Shipped again | blog    | done   | now - 30 days |
    When I send the admin form "/admin/projects/{project:blog}/tasks/1/move" with:
      | to | backlog |
    And I send the admin form "/admin/projects/{project:blog}/tasks/1/move" with:
      | to | done |
    And I visit "/admin/projects/{project:blog}"
    Then the page parts "section.kcol.k-done .kc-title" read "Shipped again"
