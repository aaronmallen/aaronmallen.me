Feature: The task page
  A task reads on a page of its own, or in the drawer, with its status, facts, note, actions and links.

  Background:
    Given the tasks:
      | title               | note                   |
      | Ship the read page  | say **why** it matters |
      | Write the migration |                        |

  Scenario: Signed out, the task page sends neither the title nor the note
    When I fetch the admin page "/admin/tasks/{task:Ship the read page}"
    Then the answer does not show "Ship the read page"
    And the answer does not show "it matters"

  Scenario: The page frames the task with a header, a body and a footer
    Given I am signed in to the admin
    When I visit "/admin/tasks/{task:Ship the read page}?filter=next"
    Then the page title is "Ship the read page | Admin | Aaron Allen"
    And the page part ".task-drawer-body > .task-stbar:first-child + h1.task-read-title" reads "Ship the read page"
    And the page has "article.task-drawer > header.task-drawer-head + .task-drawer-body + footer.task-drawer-foot"
    And the page has ".task-drawer-body > details.task-timeline"
    And the page has ".task-drawer-body > .task-facts + .field > .task-total-edit"
    And the page has ".task-drawer-body > .task-comments + details.task-timeline:last-child"
    And the page has "article.task-drawer > header.task-drawer-head a.task-drawer-close[data-task-close][aria-label='Close']"
    And the page part ".task-drawer-head button.record-key[data-record-key='1']" reads "1"
    And the page part ".task-drawer-head .pill" reads "open"
    And the page parts "article.task-drawer > footer.task-drawer-foot :is(a, button)" read "Delete | Close | Edit"
    And the page has "footer.task-drawer-foot a[data-task-open-edit][data-key='e'][title='Edit (E)']"
    And the page part "footer.task-drawer-foot form.task-drawer-delete" has "action" set to "/admin/tasks/{task:Ship the read page}/delete"
    And the page part "footer.task-drawer-foot form.task-drawer-delete" has "data-confirm" set to "Delete 1? This cannot be undone."
    And the page field "footer.task-drawer-foot form.task-drawer-delete input[name='filter']" holds "next"
    And the page has "footer.task-drawer-foot form.task-drawer-delete button.bt.warn.sm[type=submit] i.fa-regular.fa-trash-can"
    And the page has "nav"
    And the page has no ".task-source"
    And the page has no axe breaches in light or dark

  Scenario: A task page that isn't there answers 404
    Given I am signed in to the admin
    When I visit "/admin/tasks/999999"
    Then the server answers 404

  Scenario Outline: The header and the facts show where a task sits: <where>
    Given I am signed in to the admin
    And the tasks:
      | title  | list   | sprint   |
      | Placed | <list> | <sprint> |
    When I visit "/admin/tasks/{task:Placed}"
    Then the page part "header.task-drawer-head .read-meta-list" reads "<head>"
    And the page part ".task-fact:has(dt:text-is('List')) dd" reads "<list fact>"
    And the page part ".task-fact:has(dt:text-is('Sprint')) dd" reads "<sprint fact>"

    Examples:
      | where           | list    | sprint    | head               | list fact           | sprint fact          |
      | someday         | someday |           | someday            | someday             | unscheduled          |
      | today's sprint  |         | today     | today              | today               | {medium:today}       |
      | a later sprint  |         | today + 1 | {short:today + 1}  | {medium:today + 1}  | {medium:today + 1}   |
      | two days ahead  |         | today + 2 | {short:today + 2}  | {medium:today + 2}  | {medium:today + 2}   |

  Scenario: A task left in yesterday's sprint rolls into today's before the page shows its day
    Given I am signed in to the admin
    And the tasks:
      | title      | sprint    |
      | Left there | today - 1 |
    When I visit "/admin/tasks/{task:Left there}"
    Then the page part ".task-fact:has(dt:text-is('Sprint')) dd" reads "{medium:today}"

  Scenario Outline: The header shows the <status> status
    Given I am signed in to the admin
    And the tasks:
      | title  | status   | sprint   |
      | Status | <status> | <sprint> |
    When I visit "/admin/tasks/{task:Status}"
    Then the page part ".task-drawer-head .pill" reads "<shown>"

    Examples:
      | status      | sprint | shown       |
      | open        |        | open        |
      | in_progress | today  | in progress |
      | done        |        | done        |
      | canceled    |        | canceled    |

  Scenario: The facts lay out the list, sprint, tags, contributors, dates and tallies
    Given I am signed in to the admin
    And the database runs:
      """
      UPDATE tasks SET created_at = '2026-10-03 09:00 America/Chicago', updated_at = '2026-10-04 10:30 America/Chicago',
        carried_count = 2
      WHERE title = 'Ship the read page'
      """
    When I visit "/admin/tasks/{task:Ship the read page}"
    Then the page parts ".task-fact dt" read "List | Sprint | Tags | Contributors | Created | Updated | Carried | Worked"
    And the page part ".task-fact:has(dt:text-is('Tags')) dd" reads "none"
    And the page parts ".task-fact .pill" read "Me"
    And the page part ".task-fact:has(dt:text-is('Created')) dd" reads "Oct 3, 2026, 09:00"
    And the page part ".task-fact:has(dt:text-is('Updated')) dd" reads "Oct 4, 2026, 10:30"
    And the page parts ".task-fact time" have "datetime" set to "2026-10-03T09:00:00-05:00 | 2026-10-04T10:30:00-05:00"
    And the page part ".task-fact:has(dt:text-is('Carried')) dd" reads "2 times"

  Scenario: The facts show when a task was completed, and its tags linked to their summaries
    Given I am signed in to the admin
    And the tasks:
      | title    | status | tags       |
      | Finished | done   | site admin |
    And the database runs:
      """
      UPDATE tasks SET completed_at = '2026-10-05 08:15 America/Chicago' WHERE title = 'Finished'
      """
    When I visit "/admin/tasks/{task:Finished}?filter=someday"
    Then the page part ".task-fact:has(dt:text-is('Completed')) dd" reads "Oct 5, 2026, 08:15"
    And the page parts ".task-fact .tag" read "#admin | #site"
    And the page has "a[href='/admin/tags/site']:has-text('#site')"
    When I visit "/admin/tasks/{task:Ship the read page}"
    Then the page has no ".task-fact:has(dt:text-is('Completed'))"

  Scenario: The page shows the GitHub or Linear issue a task came from
    Given I am signed in to the admin
    And the task_sources table holds the rows:
      | task_id                   | provider | remote_id | url                                                         |
      | {task:Ship the read page} | github   | 42        | https://github.com/aaronmallen/aaronmallen.me/issues/42     |
      | {task:Write the migration} | linear  | lin-1     | https://linear.app/acme/issue/ABC-123/ship-the-release      |
    When I visit "/admin/tasks/{task:Ship the read page}"
    Then the page has "a[href='https://github.com/aaronmallen/aaronmallen.me/issues/42']:has-text('aaronmallen/aaronmallen.me#42')"
    When I visit "/admin/tasks/{task:Write the migration}"
    Then the page has "a[href='https://linear.app/acme/issue/ABC-123/ship-the-release']:has-text('acme/ABC-123')"

  Scenario: The drawer gets the task without the layout, a save's toast, and a failed save's form
    Given I am signed in to the admin
    When I fetch the admin page "/admin/tasks/{task:Ship the read page}" for the drawer
    Then the answer shows "data-task-read"
    And the answer does not show "<nav"
    And the answer does not show "<html"
    When I visit "/admin/tasks/{task:Ship the read page}"
    And I send the admin form "/admin/tasks/{task:Ship the read page}" with:
      | task[title] | Changed |
    And I fetch the admin page "/admin/tasks/{task:Changed}" for the drawer
    Then the answer shows "Task saved"
    When I send the admin form "/admin/tasks/{task:Changed}" from the drawer with:
      | task[title] |  |
    Then the server answers 422
    And the answer shows "data-task-edit"
    And the answer does not show "<nav"

  Scenario: The note renders as Markdown, says when there is none, and links Add some to the editor
    Given I am signed in to the admin
    And the task "List note" has the note:
      """
      - one
      - two
      """
    When I visit "/admin/tasks/{task:List note}"
    Then the page parts ".markdown-body li" read "one | two"
    When I visit "/admin/tasks/{task:Write the migration}?filter=next"
    Then the page has no ".markdown-body"
    And the page part ".task-read-empty" holds "No notes. Add some"
    And the page has ".task-read-empty a[data-task-open-edit][href*='/edit?filter=next']"

  Scenario: The note keeps raw HTML that does no harm and strips what runs or loads code
    Given I am signed in to the admin
    And the task "Details" has the note:
      """
      <details><summary>More</summary>

      Hidden <kbd>K</kbd><br><sub>s</sub></details>
      """
    And the task "Only a script" has the note:
      """
      <script>alert(1)</script>
      """
    And the task "Script between" has the note:
      """
      before

      <script>alert('owned')</script>

      after
      """
    And the task "Handlers" has the note:
      """
      <b onclick="alert(1)" onmouseover="alert(2)">bold</b> <div class="fixed inset-0" id="task-dialog" style="color:red" tabindex="0" title="kept">x</div>
      """
    And the task "Runners" has the note:
      """
      <iframe src="https://example.com"></iframe><object data="x"></object><embed src="x"><svg onload="alert(1)"></svg><form action="/admin/tasks"><button>go</button></form><style>*{}</style>
      """
    When I visit "/admin/tasks/{task:Details}"
    Then the page part ".markdown-body details summary" reads "More"
    And the page part ".markdown-body details kbd" reads "K"
    And the page has ".markdown-body details br"
    And the page part ".markdown-body details sub" reads "s"
    When I visit "/admin/tasks/{task:Only a script}"
    Then the page has no ".markdown-body"
    And the database soon holds "<script>alert(1)</script>" for:
      """
      SELECT note FROM tasks WHERE title = 'Only a script'
      """
    When I visit "/admin/tasks/{task:Script between}"
    Then the page has no ".markdown-body script"
    And the page part ".markdown-body" reads "before after"
    When I visit "/admin/tasks/{task:Handlers}"
    Then the page part ".markdown-body b" reads "bold"
    And the page has no ".markdown-body b[onclick], .markdown-body b[onmouseover]"
    And the page has ".markdown-body div[title='kept']:not([class]):not([id]):not([style]):not([tabindex])"
    When I visit "/admin/tasks/{task:Runners}"
    Then the page has no ".markdown-body :is(iframe, object, embed, svg, form, button, style)"

  Scenario: The note turns remote images into links and keeps the site's own images
    Given I am signed in to the admin
    And the task "Remote" has the note:
      """
      <img src="https://example.com/shot.png" alt="shot"> ![](http://example.com/bare.png)
      """
    And the task "Linked badge" has the note:
      """
      [![CI](https://example.com/badge.svg)](https://example.com/actions)
      """
    And the task "Other media" has the note:
      """
      ![shot](https://example.com/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.png) ![two](//example.com/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.png)
      """
    And the task "Own media" has a note linking the image "/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.png" on the site and on its full address
    And the task "Bare path" has the note:
      """
      ![a diagram](docs/diagram.png)
      """
    And the task "Data and srcset" has the note:
      """
      <img src="data:image/svg+xml;base64,PHN2Zz48L3N2Zz4=" alt="x"> <img src="https://example.com/a.png" srcset="data:image/png;base64,AA 1x" alt="y">
      """
    When I visit "/admin/tasks/{task:Remote}"
    Then the page has ".markdown-body a[href='https://example.com/shot.png']:text-is('shot')"
    And the page has ".markdown-body a[href='http://example.com/bare.png']:text-is('http://example.com/bare.png')"
    And the page has no ".markdown-body img"
    When I visit "/admin/tasks/{task:Linked badge}"
    Then the page has ".markdown-body a[href='https://example.com/actions']:text-is('CI')"
    And the page has no ".markdown-body img, .markdown-body a a"
    When I visit "/admin/tasks/{task:Other media}"
    Then the page has no ".markdown-body img"
    When I visit "/admin/tasks/{task:Own media}"
    Then the note shows the image "/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.png" on the site and on its full address
    When I visit "/admin/tasks/{task:Bare path}"
    Then the page has no ".markdown-body img, .markdown-body a"
    And the page part ".markdown-body" holds "a diagram"
    When I visit "/admin/tasks/{task:Data and srcset}"
    Then the page has no ".markdown-body img[src^='data:'], .markdown-body img[srcset]"

  Scenario: The note strips javascript links and keeps https ones
    Given I am signed in to the admin
    And the task "Links" has the note:
      """
      [one](javascript:alert(1)) <a href="javascript:alert(2)">two</a> <a href="JaVaScRiPt:x">3</a> [docs](https://hanamirb.org)
      """
    When I visit "/admin/tasks/{task:Links}"
    Then the page parts ".markdown-body a" read "one | two | 3 | docs"
    And the page parts ".markdown-body a[href]" have "href" set to "https://hanamirb.org"

  Scenario: The note keeps a task list as named, disabled boxes and strips every other input
    Given I am signed in to the admin
    And the task "Checklist" has the note:
      """
      - [x] call [the accountant](https://x.com)
        - [ ] find the forms

      1. [ ] a loose

          one
      """
    And the task "Inputs" has the note:
      """
      <input type="text" name="x"><input type="checkbox"><input type="hidden" value="y">
      """
    When I visit "/admin/tasks/{task:Checklist}"
    Then the page has 3 of ".markdown-body input[type='checkbox'][disabled]"
    And the page has 1 of ".markdown-body input[type='checkbox'][checked]"
    And the page parts ".markdown-body input[type='checkbox']" have "aria-label" set to "call the accountant | find the forms | a loose one"
    When I visit "/admin/tasks/{task:Inputs}"
    Then the page has no ".markdown-body input"

  Scenario: The actions match the status, and mark what the palette runs
    Given I am signed in to the admin
    And the tasks:
      | title   | status      | sprint | worked |
      | Running | in_progress | today  | 1800   |
      | Closed  | done        |        |        |
      | Timing  | in_progress | today  |        |
    And the work_sessions table holds the rows:
      | task_id       | started_at |
      | {task:Timing} | now        |
    When I visit "/admin/tasks/{task:Ship the read page}"
    Then the page has "form[action$='/start'][data-task-act='start'][data-morph]"
    And the page has "form[action$='/cancel']"
    And the page has no "form[action$='/complete'], form[action$='/stop'], form[action$='/reopen'], form[action*='/move/']"
    When I visit "/admin/tasks/{task:Running}"
    Then the page has "form[action='/admin/tasks/{task:Running}/complete'][data-task-act='complete'] > button.bt.pri.sm[type=submit]"
    And the page has "form[action='/admin/tasks/{task:Running}/stop'][data-task-act='pause']"
    And the page has "form[action$='/cancel']"
    And the page has no "form[action$='/start'], form[action$='/reopen'], [data-task-act='start'], .task-complete, .task-complete-ask"
    When I visit "/admin/tasks/{task:Timing}"
    Then the page has "form[data-task-act='complete'] > button.bt.pri.sm[type=submit]"
    And the page has no ".task-complete, .task-complete-ask"
    When I visit "/admin/tasks/{task:Closed}"
    Then the page has "form[action$='/reopen']"
    And the page has no "form[action$='/start'], form[action$='/cancel'], form[action$='/complete'], form[action$='/stop'], [data-task-act]"

  Scenario: The actions and the close carry where the task was opened
    Given I am signed in to the admin
    When I visit "/admin/tasks/{task:Ship the read page}?filter=someday&origin=today"
    Then the page field "form[action='/admin/tasks/{task:Ship the read page}/start'] input[name='filter']" holds "someday"
    And the page field "form[action='/admin/tasks/{task:Ship the read page}/start'] input[name='origin']" holds "today"
    And every page part "a[data-task-close]" has "href" set to "/admin"
    When I visit "/admin/tasks/{task:Ship the read page}?filter=next"
    Then every page part "a[data-task-close]" has "href" set to "/admin/tasks?filter=next"

  Scenario Outline: <act> goes back to the list the task was opened from
    Given I am signed in to the admin
    And the tasks:
      | title | status   |
      | Acted | <status> |
    When I send the admin form "/admin/tasks/{task:Acted}/<act>" with:
      | filter | next  |
      | origin | tasks |
    Then the admin answer goes to "<back>"

    Examples:
      | act      | status      | back                      |
      | complete | open        | /admin/tasks?filter=next  |
      | cancel   | open        | /admin/tasks?filter=next  |
      | start    | open        | /admin/tasks?filter=today |
      | stop     | in_progress | /admin/tasks?filter=next  |
      | reopen   | done        | /admin/tasks?filter=next  |

  Scenario Outline: <act> goes back to Today when the task was opened there
    Given I am signed in to the admin
    When I send the admin form "/admin/tasks/{task:Ship the read page}/<act>" with:
      | filter | today |
      | origin | today |
    Then the admin answer goes to "/admin"

    Examples:
      | act      |
      | complete |
      | cancel   |
      | start    |

  Scenario Outline: <act> goes back to the admin page it was run from, and nowhere else
    Given I am signed in to the admin
    And the tasks:
      | title | status   | sprint   |
      | Acted | <status> | <sprint> |
      | Again | <status> | <sprint> |
      | Third | <status> | <sprint> |
      | Last  | <status> | <sprint> |
    When I send the admin form "/admin/tasks/{task:Acted}/<act>" with:
      | return_to | /admin/posts?status=draft |
      | filter    | next                      |
    Then the admin answer goes to "/admin/posts?status=draft"
    When I send the admin form "/admin/tasks/{task:Again}/<act>" with:
      | return_to | //elsewhere.example/admin |
      | filter    | next                      |
    Then the admin answer goes to "<back>"
    When I send the admin form "/admin/tasks/{task:Third}/<act>" with:
      | return_to | /posts |
      | filter    | next   |
    Then the admin answer goes to "<back>"
    When I send the admin form "/admin/tasks/{task:Last}/<act>" with:
      | return_to | /administer |
      | filter    | next        |
    Then the admin answer goes to "<back>"

    Examples:
      | act      | status      | sprint | back                      |
      | complete | open        |        | /admin/tasks?filter=next  |
      | start    | open        |        | /admin/tasks?filter=today |
      | stop     | in_progress | today  | /admin/tasks?filter=next  |

  Scenario: The links block lists each link, keeps where the task was opened, and finds tasks to link
    Given I am signed in to the admin
    And the task_links table holds the rows:
      | from_task_id              | to_task_id                 | type   |
      | {task:Ship the read page} | {task:Write the migration} | blocks |
    When I visit "/admin/tasks/{task:Ship the read page}"
    Then the page part ".task-drawer-body > .task-link-editor > .field > .f:first-child" reads "Task links"
    And the page part ".task-link-row .task-link-label" reads "blocks"
    When I visit "/admin/tasks/{task:Write the migration}?filter=next&origin=tasks"
    Then the page has "a[href='/admin/tasks/{task:Ship the read page}?filter=next&origin=tasks']:has-text('Ship the read page')"

  Scenario: The link finder searches through a GET to the page itself
    Given I am signed in to the admin
    And the tasks:
      | title  |
      | Lonely |
    When I visit "/admin/tasks/{task:Lonely}"
    And I send the admin form "/admin/tasks/{task:Lonely}/links" with:
      | link_find | 1         |
      | link_q    | migration |
    Then the admin answer goes to a page starting "/admin/tasks/{task:Lonely}?"
    When I follow the admin answer
    Then the page parts ".task-link-target .record-key" read "2"
    When I visit "/admin/tasks/{task:Lonely}?link_q=migration"
    Then the page field "#task-{task:Lonely}-link-other-id" holds "migration"
    When I visit "/admin/tasks/{task:Lonely}?link_q=nothing like it"
    Then the page part ".task-link-editor" holds "No unlinked task matches."

  Scenario: A link added from the page returns to where it was opened, and a failed one shows the error
    Given I am signed in to the admin
    When I visit "/admin/tasks/{task:Ship the read page}"
    And I send the admin form "/admin/tasks/{task:Ship the read page}/links" with:
      | filter         | next                       |
      | origin         | tasks                      |
      | link[kind]     | blocks                     |
      | link[other_id] | {task:Write the migration} |
    Then the admin answer goes to "/admin/tasks?filter=next"
    And the database soon holds "blocks" for:
      """
      SELECT type FROM task_links
      """
    When I send the admin form "/admin/tasks/{task:Ship the read page}/links" with:
      | filter         | next                      |
      | origin         | tasks                     |
      | link[kind]     | relates                   |
      | link[other_id] | {task:Ship the read page} |
    Then the server answers 422
    When I look at the admin answer
    Then the page part "h1.task-read-title" reads "Ship the read page"
    And the page part "#task-{task:Ship the read page}-link-other-id-error" reads "A task cannot link to itself."
    And the page field "#task-{task:Ship the read page}-link-kind" holds "relates"

  Scenario: A link removed from the page returns to where it was opened
    Given I am signed in to the admin
    And the task_links table holds the rows:
      | from_task_id              | to_task_id                 | type   |
      | {task:Ship the read page} | {task:Write the migration} | blocks |
    When I visit "/admin/tasks/{task:Ship the read page}?filter=next"
    And I click "Remove the link to 2"
    Then I am on "/admin/tasks?filter=next"
    And the task_links table holds 0 rows
