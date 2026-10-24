Feature: Task row actions
  The buttons on a task row act in place, with a toast and no page load, and keep the scroll, the focus and the palette.

  Background:
    Given I am signed in to the admin

  Scenario Outline: Starting a task on <screen> switches it to pause with no page load
    Given the tasks:
      | title   | sprint |
      | Ship it | today  |
    When I visit "<screen>"
    And I keep the page
    And I click "Start" on the task row "Ship it"
    Then the toast says "Started · it is today's work now"
    And the task row "Ship it" offers "Stop"
    And the page did not load again
    And the page has no axe breaches in light or dark

    Examples:
      | screen                    |
      | /admin                    |
      | /admin/tasks?filter=today |

  Scenario: Starting a task keeps the scroll and the focus in the row
    Given the tasks:
      | title   | sprint |
      | Ship it | today  |
    And the window is 1024 by 300
    When I visit "/admin/tasks?filter=today"
    And I hover the page part ".task:has(.task-title:text-is('Ship it'))"
    And I press "Start" with the page scrolled and the button focused on the task row "Ship it"
    Then the toast says "Started · it is today's work now"
    And the page kept its scroll
    And the focus sits in the task row "Ship it"

  Scenario: Starting a task keeps the palette open
    Given the tasks:
      | title   | sprint |
      | Ship it | today  |
    When I visit "/admin/tasks?filter=today"
    And I press "Meta+/"
    Then the page shows the part "dialog[data-palette][open]"
    When the start form of the first task row submits
    Then the toast says "Started · it is today's work now"
    And the page shows the part "dialog[data-palette][open]"

  Scenario: The keys still work after an update, closing the running task at once
    Given the tasks:
      | title   | sprint |
      | Ship it | today  |
    When I visit "/admin/tasks?filter=today"
    And I keep the page
    And I press the keys "j s"
    Then the toast says "Started · it is today's work now"
    When I press the keys "j x"
    Then the toast says "Done"
    And the database soon holds "done" for:
      """
      SELECT status FROM tasks WHERE title = 'Ship it'
      """
    And the page did not load again

  Scenario: A start from next whose live change arrives before it lands asks for no refresh
    Given the tasks:
      | title   |
      | Plan it |
    When I visit "/admin/tasks?filter=next"
    And a live change to "tasks" reaches the page
    And the page settles
    And I count the pages loaded from "/admin/tasks"
    And I hold the answer to "/admin/tasks/{task:Plan it}/start"
    And I click "Start" on the task row "Plan it"
    And a request to "/admin/tasks/{task:Plan it}/start" arrives
    And a live change to "tasks" reaches the page
    And I let the held requests to "/admin/tasks/{task:Plan it}/start" go
    Then the toast says "Started · it is today's work now"
    When the page settles
    Then 1 page loaded from "/admin/tasks"
    And the page part ".task-tabs [aria-current]" holds "today"
    And the task row "Plan it" offers "Done"

  Scenario: Pulling a task from a pool moves it into the sprint with no page load
    Given the tasks:
      | title                |
      | Email the accountant |
    When I visit "/admin"
    And I keep the page
    And I click "Pull Email the accountant into today" in "[data-pools] .li:has-text('Email the accountant')"
    Then the toast says "Moved"
    And the page part "[data-sprint-panel]" holds "Email the accountant"
    And the page did not load again

  Scenario: A running task pauses and completes in place
    Given the tasks:
      | title   | sprint | status      |
      | Ship it | today  | in_progress |
      | Run it  | today  | in_progress |
    When I visit "/admin/tasks?filter=today"
    And I keep the page
    And I click "Stop" on the task row "Ship it"
    Then the toast says "Stopped · it waits in the sprint"
    And the task row "Ship it" offers "Start"
    When I complete the task row "Run it"
    Then the toast says "Done"
    And the database soon holds "done" for:
      """
      SELECT status FROM tasks WHERE title = 'Run it'
      """
    And the page did not load again

  Scenario: An open task cancels after asking, and completes without asking for time
    Given the tasks:
      | title           |
      | Write the brief |
      | File the forms  |
    When I visit "/admin/tasks?filter=next"
    And I keep the page
    And I click "Cancel" on the task row "Write the brief"
    And I say yes to the question
    Then the toast says "Canceled"
    And the database soon holds "canceled" for:
      """
      SELECT status FROM tasks WHERE title = 'Write the brief'
      """
    When I complete the task row "File the forms"
    Then the toast says "Done"
    And the database soon holds "done" for:
      """
      SELECT status FROM tasks WHERE title = 'File the forms'
      """
    And the page did not load again

  Scenario: An open task moves right and left in place
    Given the tasks:
      | title           |
      | Write the brief |
    When I visit "/admin/tasks?filter=next"
    And I keep the page
    And I click the page part ".task:has-text('Write the brief') button:has(.fa-arrow-right)"
    Then the toast says "Moved"
    And I am on "/admin/tasks?filter=someday"
    And I see "Write the brief"
    When I click the page part ".task:has-text('Write the brief') button:has(.fa-arrow-left)"
    Then I am on "/admin/tasks?filter=next"
    When I click the page part ".task:has-text('Write the brief') button:has(.fa-arrow-left)"
    Then the toast says "Moved"
    And I am on "/admin/tasks?filter=today"
    And I see "Write the brief"
    And the page did not load again

  Scenario: An action that fails shows the error toast and leaves the page as it was
    Given the tasks:
      | title           |
      | Write the brief |
    When I visit "/admin/tasks?filter=next"
    And I keep the page
    And the database runs:
      """
      DELETE FROM tasks WHERE title = 'Write the brief'
      """
    And I click the page part ".task:has-text('Write the brief') button:has(.fa-arrow-right)"
    Then the page shows the part ".toast-failed:has-text('Nothing changed · that didn')"
    And I see "Write the brief"
    And the page did not load again

  Scenario: A closed task reopens in place from its hover bar
    Given the tasks:
      | title           | status |
      | Filed the taxes | done   |
    When I visit "/admin/tasks?filter=completed"
    And I keep the page
    And I click "Reopen" on the task row "Filed the taxes"
    Then the toast says "Reopened"
    And the page did not load again

  Scenario: A task schedules into an upcoming sprint in place
    Given the sprints table holds the rows:
      | sprint_date      |
      | {day:today + 3}  |
    And the tasks:
      | title         |
      | Plan the trip |
    When I visit "/admin/tasks?filter=upcoming"
    And I keep the page
    And I click the page part ".sprint-pull summary"
    And I click "Schedule Plan the trip into this sprint" in ".sprint-pull .li:has-text('Plan the trip')"
    Then the database soon holds "{day:today + 3}" for:
      """
      SELECT to_char(sprint_date, 'YYYY-MM-DD') FROM tasks JOIN sprints ON sprints.id = sprint_id WHERE title = 'Plan the trip'
      """
    And the toast says "Scheduled for the"
    And the page did not load again

  Scenario: The create form still posts and loads the page
    When I visit "/admin/tasks?filter=next"
    And I keep the page
    And I click "Create Task"
    And I set the page field "dialog[open] [name='task[title]']" to "Ship the screen"
    And I click "Create task"
    Then the toast says "Task captured"
    And the page loaded again
