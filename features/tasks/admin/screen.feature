Feature: The tasks screen in the browser
  The Create Task dialog, the task drawer, the row questions and the pull in column work in place on the screen
  they open over.

  Background:
    Given I am signed in to the admin
    And the tasks:
      | title                | list    |
      | Email the accountant | next    |
      | Learn Elixir         | someday |

  Scenario: The Create Task button opens the dialog over the list with the cursor in the title
    When I visit "/admin/tasks?filter=next"
    And I click "Create Task"
    Then the page shows the part "dialog#task-create[open]"
    And I am on "/admin/tasks?filter=next"
    And the focus is on the field "task[title]"
    And the page has no axe breaches in light or dark
    When I set the page field "dialog#task-create[open] [name='task[title]']" to "Half a thought"
    And I click the page at 10, 700
    Then the page field "dialog#task-create[open] [name='task[title]']" holds "Half a thought"
    When I click "Cancel" in "dialog#task-create"
    Then the page has no "dialog#task-create[open]"
    When I click "Create Task"
    And I click the page part "dialog#task-create[open] button[aria-label='Close']"
    Then the page has no "dialog#task-create[open]"
    When I click "Create Task"
    And I press "Escape" in "dialog#task-create[open]"
    Then the page has no "dialog#task-create[open]"

  Scenario: The Create Task dialog fits a phone
    Given the window is 375 by 800
    When I visit "/admin/tasks?filter=next"
    And I click "Create Task"
    Then the page shows the part "dialog#task-create[open]"
    And "the page" does not scroll sideways

  Scenario: The dialog files a task in the list it names with its note, tags and #word
    When I visit "/admin/tasks?filter=next"
    And I click "Create Task"
    And I set the page field "dialog#task-create[open] [name='task[title]']" to "Call the #plumber"
    And I pick "someday" in the page select "dialog#task-create[open] select[name='task[list]']"
    And I set the page field "dialog#task-create[open] [name='task[note]']" to "the sink leaks"
    And I fill in "Tags" in "dialog#task-create[open]" with "home, chores"
    And I click "Create task" in "dialog#task-create[open]"
    Then the toast says "Task captured"
    And the page has ".task-title:has-text('Call the #plumber')"
    And the database soon holds "Call the #plumber, someday, the sink leaks, chores home" for:
      """
      SELECT title, list, note, string_agg(name, ' ' ORDER BY name) FROM tasks JOIN task_tags ON task_id = tasks.id
      JOIN tags ON tags.id = tag_id GROUP BY title, list, note
      """

  Scenario: The dialog offers the live projects and files the task under the one picked
    Given the projects:
      | name    | key |
      | Podcast | POD |
    When I visit "/admin/tasks?filter=next"
    And I click "Create Task"
    Then the page parts "dialog#task-create[open] select[name='task[project]'] option" read "No project | Podcast"
    When I set the page field "dialog#task-create[open] [name='task[title]']" to "Book a guest"
    And I pick "Podcast" in the page select "dialog#task-create[open] select[name='task[project]']"
    And I click "Create task" in "dialog#task-create[open]"
    Then the page part ".task:has-text('Book a guest') .record-key" holds "POD-"

  Scenario: Clicking a row's key copies it
    When I visit "/admin/tasks?filter=next"
    And I watch the clipboard
    And I click the page part ".task:has-text('Email the accountant') .record-key"
    Then the toast says "Task 1 copied"
    And the clipboard got "1"

  Scenario: An empty sprint takes a new task from the dialog and from the quick add
    When I visit "/admin/tasks?filter=today"
    And I create the task "Ship the screen" on today from the dialog
    Then the page has ".task-title:has-text('Ship the screen')"
    When I set the page field ".quick-add input[name='task[title]']" to "Ship the other"
    And I press "Enter" in ".quick-add input[name='task[title]']"
    Then the page has ".task-title:has-text('Ship the other')"
    And the page has ".task-pull"
    And the database soon holds "Ship the other, {day:today}\nShip the screen, {day:today}" for:
      """
      SELECT title, to_char(sprint_date, 'YYYY-MM-DD') FROM tasks JOIN sprints ON sprints.id = sprint_id ORDER BY title
      """

  Scenario: The pull in column switches its pool without loading the page or losing the scroll
    Given the window is 1024 by 400
    When I visit "/admin/tasks?filter=today"
    And I keep the page
    And I scroll the pools into view
    And I click the page part ".task-pull .seg-option:text-is('someday · 1')"
    Then the page part ".task-pull .li-title" holds "Learn Elixir"
    And the page did not load again
    And the page kept its scroll

  Scenario: An imported task takes a tag from the editor and stays on external
    Given the tasks:
      | title        | list     |
      | Fix the feed | external |
    And the task_sources table holds the rows:
      | task_id             | provider | remote_id | url                                                     |
      | {task:Fix the feed} | github   | 42        | https://github.com/aaronmallen/aaronmallen.me/issues/42 |
    When I visit "/admin/tasks?filter=external"
    And I open the task "Fix the feed" in the drawer
    And I click "Edit" in "dialog#task-panel[open] .task-drawer-foot"
    And I fill in "Tags" in "dialog#task-panel[open]" with "site"
    And I click "Save" in "dialog#task-panel[open]"
    Then the toast says "Task saved"
    When I click the page part "dialog#task-panel[open] [data-task-read] .task-drawer-close"
    Then I am on "/admin/tasks?filter=external"
    And the page part ".task:has-text('Fix the feed') .tag" reads "#site"

  Scenario: A canceled task files under completed and reopens back onto its list
    When I visit "/admin/tasks?filter=next"
    And I click "Cancel" on the task row "Email the accountant"
    And I say yes to the question
    Then the toast says "Canceled"
    When I click the page part ".task-tabs .screen-tab:has-text('completed')"
    Then the page part ".task.canceled:has-text('Email the accountant') .task-meta" holds "canceled"
    When I click "Reopen" on the task row "Email the accountant"
    Then the toast says "Reopened"
    When I click the page part ".task-tabs .screen-tab:has-text('next')"
    Then the page has ".task-title:has-text('Email the accountant')"
    And the page has no ".task:has-text('Email the accountant') .task-meta:has-text('canceled')"
    And the database soon holds "open" for:
      """
      SELECT status FROM tasks WHERE title = 'Email the accountant'
      """

  Scenario: A cancel from a row asks inline; no and Escape keep the task and hand focus back
    When I visit "/admin/tasks?filter=next"
    And I click "Cancel" on the task row "Email the accountant"
    Then the page part "[data-confirm-ask] [data-confirm-message]" reads "Cancel Email the accountant? It moves to completed."
    When I click the page at 5, 5
    Then the page has "[data-confirm-ask]"
    When I say no to the question
    Then the page has no "[data-confirm-ask]"
    And the page has no ".toast"
    And the focus is on the control named "Cancel"
    When I click "Cancel" on the task row "Email the accountant"
    And I press "Escape" in "[data-confirm-decline]"
    Then the page has no "[data-confirm-ask]"
    And the focus is on the control named "Cancel"
    And the database soon holds "open" for:
      """
      SELECT status FROM tasks WHERE title = 'Email the accountant'
      """
    When I click "Cancel" on the task row "Email the accountant"
    And I say yes to the question
    Then the toast says "Canceled"
    And the database soon holds "canceled" for:
      """
      SELECT status FROM tasks WHERE title = 'Email the accountant'
      """

  Scenario: A cancel from the task page asks inline and cancels on yes
    When I visit "/admin/tasks/{task:Email the accountant}?filter=next&origin=tasks"
    And I click "Cancel" in ".task-stbar"
    Then the page part "[data-confirm-ask] [data-confirm-message]" reads "Cancel Email the accountant? It moves to completed."
    When I say yes to the question
    Then the toast says "Canceled"
    And the database soon holds "canceled" for:
      """
      SELECT status FROM tasks WHERE title = 'Email the accountant'
      """

  Scenario: A cancel from the drawer asks inline, and Escape closes the drawer and keeps the task
    When I visit "/admin/tasks?filter=next"
    And I open the task "Email the accountant" in the drawer
    And I click "Cancel" in "dialog#task-panel[open]"
    Then the page part "[data-confirm-ask] [data-confirm-message]" reads "Cancel Email the accountant? It moves to completed."
    When I press "Escape" in "[data-confirm-decline]"
    Then the page has no "dialog#task-panel[open]"
    And the page has no "[data-confirm-ask]"
    And the database soon holds "open" for:
      """
      SELECT status FROM tasks WHERE title = 'Email the accountant'
      """

  Scenario: Moving a task in progress out of today asks first, on the tasks page and on Today
    Given the tasks:
      | title           | sprint | status      |
      | Ship the screen | today  | in_progress |
    When I visit "/admin/tasks?filter=today"
    And I click "Move to Next" on the task row "Ship the screen"
    Then the page part "[data-confirm-ask] [data-confirm-message]" reads "Move Ship the screen to Next? It stops and goes back to open."
    When I say no to the question
    Then the page has no "[data-confirm-ask]"
    And the database soon holds ", in_progress, true" for:
      """
      SELECT coalesce(list::text, ''), status, sprint_id IS NOT NULL FROM tasks WHERE title = 'Ship the screen'
      """
    When I visit "/admin"
    And I click "Move to Next" on the task row "Ship the screen"
    Then the page part "[data-confirm-ask] [data-confirm-message]" reads "Move Ship the screen to Next? It stops and goes back to open."
    When I say yes to the question
    Then the page has no ".task-title:text-is('Ship the screen')"
    And the database soon holds "next, open, true" for:
      """
      SELECT list, status, sprint_id IS NULL FROM tasks WHERE title = 'Ship the screen'
      """

  Scenario: Moving a task in progress to next from the tasks page lands on next
    Given the tasks:
      | title           | sprint | status      |
      | Ship the screen | today  | in_progress |
    When I visit "/admin/tasks?filter=today"
    And I click "Move to Next" on the task row "Ship the screen"
    And I say yes to the question
    Then I am on "/admin/tasks?filter=next"
    And the database soon holds "next, open" for:
      """
      SELECT list, status FROM tasks WHERE title = 'Ship the screen'
      """

  Scenario: Moving an open task out of today does not ask
    Given the tasks:
      | title            | sprint |
      | Water the plants | today  |
    When I visit "/admin/tasks?filter=today"
    And I click "Move to Next" on the task row "Water the plants"
    Then I am on "/admin/tasks?filter=next"
    And the page has no "[data-confirm-ask]"

  Scenario: Dropping a planned sprint asks inline
    Given the sprints table holds the rows:
      | sprint_date     |
      | {day:today + 2} |
    When I visit "/admin/tasks?filter=upcoming"
    And I click "Drop"
    Then the page part "[data-confirm-ask] [data-confirm-message]" holds "Drop the sprint for"
    When I say no to the question
    Then the database soon holds "1" for:
      """
      SELECT count(*) FROM sprints WHERE sprint_date > (now() AT TIME ZONE 'America/Chicago')::date
      """

  Scenario: Opening a task shows it in the drawer over the list, which closes in each way it should
    When I visit "/admin/tasks?filter=next"
    And I open the task "Email the accountant" in the drawer
    Then I am on "/admin/tasks?filter=next"
    And the page part "dialog#task-panel[open] .record-key" reads "1"
    And the page part "#task-panel" is 760 pixels wide against the right edge
    And the page has no axe breaches in light or dark
    When I press "Escape" in "dialog#task-panel[open]"
    Then the page has no "dialog#task-panel[open]"
    And the focus is on the text "Email the accountant"
    When I open the task "Email the accountant" in the drawer
    And I click the page at 100, 400
    Then the page has no "dialog#task-panel[open]"
    And the focus is on the text "Email the accountant"
    When I open the task "Email the accountant" in the drawer
    And I click "Close" in "dialog#task-panel[open] .task-drawer-foot"
    Then the page has no "dialog#task-panel[open]"
    And I am on "/admin/tasks?filter=next"

  Scenario: The drawer copies the key and comes back to the list after an action
    When I visit "/admin/tasks?filter=next"
    And I open the task "Email the accountant" in the drawer
    And I watch the clipboard
    And I click the page part "dialog#task-panel[open] .record-key"
    Then the toast says "Task 1 copied"
    When I click "Cancel" in "dialog#task-panel[open]"
    And I say yes to the question
    Then the toast says "Canceled"
    And the page has no "dialog#task-panel[open]"
    And I am on "/admin/tasks?filter=next"

  Scenario: The drawer spans a phone with no sideways scroll
    Given the window is 375 by 800
    When I visit "/admin/tasks?filter=next"
    And I open the task "Email the accountant" in the drawer
    Then the page part "#task-panel" is 375 pixels wide against the right edge
    And "#task-panel" does not scroll sideways
    And "the page" does not scroll sideways

  Scenario: A task opened from Today stays on Today, and an action in the drawer comes back there
    Given the tasks:
      | title   | sprint |
      | Ship it | today  |
    When I visit "/admin"
    And I open the task "Ship it" in the drawer
    Then I am on "/admin"
    When I click "Start" in "dialog#task-panel[open]"
    Then the toast says "Started"
    And I am on "/admin"

  Scenario: The dialog opened from Today puts the task in today's sprint and comes back there
    When I visit "/admin"
    And I click "Create Task"
    Then the page part "dialog#task-create[open] select[name='task[list]'] option:checked" reads "today"
    And I am on "/admin"
    When I set the page field "dialog#task-create[open] [name='task[title]']" to "Ship the screen"
    And I click "Create task" in "dialog#task-create[open]"
    Then the page part "[data-sprint-panel] .task-title" holds "Ship the screen"
    And I am on "/admin"
    And the database soon holds "{day:today}" for:
      """
      SELECT to_char(sprint_date, 'YYYY-MM-DD') FROM tasks JOIN sprints ON sprints.id = sprint_id WHERE title = 'Ship the screen'
      """

  Scenario: The dialog opened from Today fits a phone
    Given the window is 375 by 800
    When I visit "/admin"
    And I click "Create Task"
    Then the page shows the part "dialog#task-create[open] [name='task[title]']"
    And "the page" does not scroll sideways

  Scenario: A task opened from the archive stays on the archive, and comes back there after a reopen
    Given the tasks:
      | title           | status |
      | Filed the taxes | done   |
    When I visit "/admin/tasks?filter=completed"
    And I open the task "Filed the taxes" in the drawer
    Then I am on "/admin/tasks?filter=completed"
    When I click "Reopen" in "dialog#task-panel[open]"
    Then the toast says "Reopened"
    And I am on "/admin/tasks?filter=completed"
