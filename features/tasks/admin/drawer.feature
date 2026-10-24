Feature: The task drawer
  A task opens over its list in a drawer whose header and footer stay in view, and that works on a phone.

  Background:
    Given I am signed in to the admin
    And the tasks:
      | title             | tags |
      | Clear the gutters | home |
      | Buy a ladder      |      |
    And the database runs:
      """
      INSERT INTO task_comments (task_id, body)
      SELECT (SELECT id FROM tasks WHERE title = 'Clear the gutters'), 'note ' || n || E'\n\n' || repeat('Long line. ', 40)
      FROM generate_series(0, 11) AS n
      """

  Scenario: A long task keeps the header and the footer in view while the body scrolls
    When I visit "/admin/tasks?filter=next"
    And I open the task "Clear the gutters" in the drawer
    And I scroll "[data-task-panel-body]" to the bottom
    Then the top of "#task-panel .task-drawer-head" lines up with the top of "[data-task-panel-body]"
    And the bottom of "#task-panel .task-drawer-foot" lines up with the bottom of "[data-task-panel-body]"
    And the page has no axe breaches in light or dark

  Scenario: Delete in the drawer asks first, then deletes the task and closes the drawer
    When I visit "/admin/tasks?filter=next"
    And I open the task "Clear the gutters" in the drawer
    And I click "Delete" in "#task-panel .task-drawer-foot"
    Then the question reads "Delete 1? This cannot be undone."
    When I say yes to the question
    Then the toast says "Task deleted"
    And the page has no "dialog#task-panel[open]"
    And the database soon holds "0" for:
      """
      SELECT count(*) FROM tasks WHERE title = 'Clear the gutters'
      """

  Scenario: A link in the drawer swaps the header and the footer to the other task
    Given the task_links table holds the rows:
      | from_task_id        | to_task_id               | type   |
      | {task:Buy a ladder} | {task:Clear the gutters} | blocks |
    When I visit "/admin/tasks?filter=next"
    And I open the task "Clear the gutters" in the drawer
    And I click "Buy a ladder" in "dialog#task-panel[open]"
    Then the page part "dialog#task-panel[open] h1" reads "Buy a ladder"
    And the page part "#task-panel .task-drawer-head .record-key" reads "2"
    And the page part "#task-panel .task-drawer-foot form" has "action" set to "/admin/tasks/{task:Buy a ladder}/delete"

  Scenario: The drawer on a phone gives each control a tap size and does not scroll sideways
    Given the work_sessions table holds the rows:
      | task_id                  | started_at | ended_at |
      | {task:Clear the gutters} | now - 3600 | now      |
    And the task_events table holds the rows:
      | task_id                  | kind   | tag_name | occurred_at |
      | {task:Clear the gutters} | tagged | home     | now         |
    And the window is 375 by 800
    When I visit "/admin/tasks?filter=next"
    And I open the task "Clear the gutters" in the drawer
    Then every visible control in "#task-panel :is(.task-drawer-head, .task-drawer-foot)" is at least 44 pixels square
    And at least 4 visible controls in "#task-panel :is(.task-stbar, .task-read-empty, .task-facts)" stand at least 44 pixels tall
    And "the page" does not scroll sideways
    And "[data-task-panel-body]" does not scroll sideways
    When I click the page part "#task-panel .task-timeline > summary"
    Then at least 4 visible controls in "#task-panel :is(.task-session, .task-comments, .task-timeline)" stand at least 44 pixels tall
    And "#task-panel .timeline-event" lays out in 1 column

  Scenario: The task's own page keeps the header under the top bar and the footer at the bottom
    When I visit "/admin/tasks/{task:Clear the gutters}"
    And I scroll the window to 600
    Then the top of "main .task-drawer-head" lines up with the bottom of ".top-bar"
    And the bottom of "main .task-drawer-foot" lines up with the bottom of "the window"
    And the page has no axe breaches in light or dark
