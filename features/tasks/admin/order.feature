Feature: Task order
  A task row carries a grip that drags it to a new place in its list, by mouse, by finger or by Alt and an arrow key.

  Background:
    Given I am signed in to the admin
    And the tasks:
      | title     | list    | position |
      | first     | next    | 1        |
      | second    | next    | 2        |
      | third     | next    | 3        |
      | elsewhere | someday | 4        |
    And the database runs:
      """
      INSERT INTO sprints (sprint_date) VALUES ((now() AT TIME ZONE 'America/Chicago')::date) ON CONFLICT DO NOTHING
      """

  Scenario: A row shows a grip and no carets, with a tap square on a phone that fits the screen
    When I visit "/admin/tasks?filter=next"
    Then the page has 3 of ".task [data-task-grip]:not([hidden])"
    And the page has no ".task-order, .task-caret"
    And the page has no axe breaches in light or dark
    Given I use a phone
    Then every visible control in ".task:has-text('first')" is at least 44 pixels square
    And "the page" does not scroll sideways

  Scenario: Dragging with a mouse moves the row at once and saves the new order
    When I visit "/admin/tasks?filter=next"
    And I count the requests to "/admin/tasks/{task:first}/place"
    And I drag the task "first" below "third"
    Then the task rows read "second, third, first"
    And 1 request to "/admin/tasks/{task:first}/place" came back
    And the database soon holds "second, third, first" for:
      """
      SELECT string_agg(title, ', ' ORDER BY position) FROM tasks WHERE list = 'next'
      """
    And the database soon holds "elsewhere" for:
      """
      SELECT string_agg(title, ', ' ORDER BY position) FROM tasks WHERE list = 'someday'
      """
    When I visit "/admin/tasks?filter=next"
    Then the task rows read "second, third, first"

  Scenario: Dragging with a finger on a phone saves the new order
    Given I use a phone
    When I visit "/admin/tasks?filter=next"
    And I count the requests to "/admin/tasks/{task:first}/place"
    And I drag the task "first" below "second" with a finger
    Then 1 request to "/admin/tasks/{task:first}/place" came back
    And the database soon holds "second, first, third" for:
      """
      SELECT string_agg(title, ', ' ORDER BY position) FROM tasks WHERE list = 'next'
      """

  Scenario: A drag the browser cancels puts the row back without saving
    Given I use a phone
    When I visit "/admin/tasks?filter=next"
    And I count the requests to "/admin/tasks/{task:first}/place"
    And I drag the task "first" below "third" with a finger, and the browser cancels it
    Then the page has no ".task-dragging"
    And the task rows read "first, second, third"
    And 0 requests to "/admin/tasks/{task:first}/place" came back

  Scenario: Alt and an arrow move a task a place, save it and keep the focus on it
    When I visit "/admin/tasks?filter=next"
    And I count the requests to "/admin/tasks/{task:first}/place"
    And I press "Alt+ArrowDown" on the task row "first"
    Then the task rows read "second, first, third"
    And the focus sits in the task row "first"
    And 1 request to "/admin/tasks/{task:first}/place" came back
    And the database soon holds "second, first, third" for:
      """
      SELECT string_agg(title, ', ' ORDER BY position) FROM tasks WHERE list = 'next'
      """
    When I press "Alt+ArrowUp" on the task row "first"
    Then 2 requests to "/admin/tasks/{task:first}/place" came back
    And the database soon holds "first, second, third" for:
      """
      SELECT string_agg(title, ', ' ORDER BY position) FROM tasks WHERE list = 'next'
      """

  Scenario: Alt and Up leave a field in the row alone, and do nothing past the top
    When I visit "/admin/tasks?filter=next"
    And I count the requests to "/admin/tasks/{task:first}/place"
    And I count the requests to "/admin/tasks/{task:second}/place"
    And I hover the page part ".task:has-text('second')"
    And I click the page part ".task:has-text('second') .task-complete summary"
    And I click the page part ".task:has-text('second') input[type=number]"
    And I press "Alt+ArrowUp"
    Then the task rows read "first, second, third"
    When I press "Alt+ArrowUp" on the task row "first"
    Then the task rows read "first, second, third"
    And 0 requests to "/admin/tasks/{task:second}/place" came back
    And 0 requests to "/admin/tasks/{task:first}/place" came back

  Scenario: A search hides the grips and leaves Alt and Down alone
    When I visit "/admin/tasks?filter=next&q=i"
    And I count the requests to "/admin/tasks/{task:first}/place"
    Then the page has no "[data-task-grip]"
    When I press "Alt+ArrowDown" on the task row "first"
    Then the task rows read "first, third"
    And 0 requests to "/admin/tasks/{task:first}/place" came back

  Scenario: A save that fails puts the row back and says the order did not save
    When I visit "/admin/tasks?filter=next"
    And the database runs:
      """
      UPDATE tasks SET status = 'done', completed_at = now() WHERE title = 'first'
      """
    And I press "Alt+ArrowDown" on the task row "first"
    Then the page shows the part ".toast-failed:has-text('save the new order')"
    And the task rows read "first, second, third"

  Scenario: A live change while a save is in flight waits to refetch until the save lands
    When I visit "/admin/tasks?filter=next"
    And a live change to "tasks" reaches the page
    And the page settles
    And I count the requests to "/admin/tasks"
    And I hold the requests to "/admin/tasks/{task:first}/place"
    And I press "Alt+ArrowDown" on the task row "first"
    And a request to "/admin/tasks/{task:first}/place" arrives
    And a live change to "tasks" reaches the page
    Then 0 requests to "/admin/tasks" came back
    When I let the held requests to "/admin/tasks/{task:first}/place" go
    Then at least 1 request to "/admin/tasks" came back
    And the task rows read "second, first, third"
    And the database soon holds "second, first, third" for:
      """
      SELECT string_agg(title, ', ' ORDER BY position) FROM tasks WHERE list = 'next'
      """

  Scenario: A task dropped in another sprint stays in its own sprint
    Given the tasks:
      | title     | sprint    | position |
      | soon one  | today + 1 | 5        |
      | soon two  | today + 1 | 6        |
      | later one | today + 2 | 7        |
    And the window is 800 by 1000
    When I visit "/admin/tasks?filter=upcoming"
    And I count the requests to "/admin/tasks/{task:soon one}/place"
    And I drag the task "soon one" below "later one"
    Then 1 request to "/admin/tasks/{task:soon one}/place" came back
    And the page parts ".card:has-text('soon two') .task-title" read "soon two | soon one"
    And the page parts ".card:has-text('later one') .task-title" read "later one"
    And the database soon holds "1" for:
      """
      SELECT count(DISTINCT sprint_id) FROM tasks WHERE title IN ('soon one', 'soon two')
      """
