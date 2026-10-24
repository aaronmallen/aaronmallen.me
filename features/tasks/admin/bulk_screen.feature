Feature: Bulk task actions on screen
  Select turns on boxes on each task row, and the bar acts on the ticked tasks.

  Background:
    Given I am signed in to the admin
    And the tasks:
      | title     | list    | position |
      | first     | next    | 1        |
      | second    | next    | 2        |
      | third     | next    | 3        |
      | elsewhere | someday | 4        |

  Scenario: Select turns bulk mode on and off and shows the bar once a row is ticked
    When I visit "/admin/tasks?filter=next"
    And I click "Select"
    Then the page has "button.bt[data-bulk-toggle][aria-pressed='true']:has-text('Select')"
    And the page part "[data-bulk-toggle]" has a filled background
    And the page hides "[data-bulk-acts]"
    When I tick the task "second"
    Then the page shows the part "[data-bulk-acts]"
    When I untick the task "second"
    Then the page hides "[data-bulk-acts]"
    When I tick the task "first"
    And I tick the task "third"
    Then the page part "[data-bulk-count]" reads "2 ticked"
    And the page has no axe breaches in light or dark
    When I click "Select"
    Then the page has no ".task input[name='ids[]']:visible"
    When I click "Select"
    Then the page has no ".task input[name='ids[]']:checked"

  Scenario: Select all ticks and clears every row, and marks itself partly ticked
    When I visit "/admin/tasks?filter=next"
    And I click "Select"
    And I tick the page box "[data-bulk-all] input"
    Then the page has 3 of ".task input[name='ids[]']:checked"
    When I untick the page box "[data-bulk-all] input"
    Then the page has no ".task input[name='ids[]']:checked"
    When I tick the task "first"
    Then the page part "[data-bulk-all] input" is partly ticked

  Scenario: The bar finishes and cancels the ticked tasks
    When I visit "/admin/tasks?filter=next"
    And I click "Select"
    And I tick the task "first"
    And I tick the task "third"
    And I click "Done" in "form#task-bulk"
    Then the page shows the part "[data-toast] .toast:has-text('Finished 2 tasks')"
    And the database soon holds "elsewhere, second" for:
      """
      SELECT string_agg(title, ', ' ORDER BY title) FROM tasks WHERE status = 'open'
      """
    When I click "Select"
    And I tick the page box "[data-bulk-all] input"
    And I click "Cancel" in "form#task-bulk"
    Then the page shows the part "[data-toast] .toast:has-text('Canceled 1 task')"
    And the database soon holds "elsewhere" for:
      """
      SELECT string_agg(title, ', ' ORDER BY title) FROM tasks WHERE status = 'open'
      """

  Scenario: The bar moves the ticked tasks to the list picked
    When I visit "/admin/tasks?filter=next"
    And I click "Select"
    And I tick the task "first"
    And I pick "Someday" in the page select "form#task-bulk select[name=to]"
    And I click "Move" in "form#task-bulk"
    Then the page shows the part "[data-toast] .toast:has-text('Moved 1 task to someday')"
    And the database soon holds "elsewhere, first" for:
      """
      SELECT string_agg(title, ', ' ORDER BY title) FROM tasks WHERE list = 'someday'
      """

  Scenario: Enter in the tag field tags rather than finishes
    When I visit "/admin/tasks?filter=next"
    And I click "Select"
    And I tick the task "first"
    And I set the page field "form#task-bulk input[name='tag']" to "home"
    And I press "Enter"
    Then the page shows the part "[data-toast] .toast:has-text('Tagged 1 task home')"
    And the database soon holds "first" for:
      """
      SELECT string_agg(title, ', ') FROM tasks JOIN task_tags ON task_id = tasks.id JOIN tags ON tags.id = tag_id
      WHERE tags.name = 'home'
      """

  Scenario: The bar asks before it deletes, and keeps the tasks when I say no
    When I visit "/admin/tasks?filter=next"
    And I click "Select"
    And I tick the task "second"
    And I click "Delete" in "form#task-bulk"
    And I say no to the question
    Then the database soon holds "4" for:
      """
      SELECT count(*) FROM tasks
      """
    When I click "Delete" in "form#task-bulk"
    And I say yes to the question
    Then the page shows the part "[data-toast] .toast:has-text('Deleted 1 task')"
    And the database soon holds "elsewhere, first, third" for:
      """
      SELECT string_agg(title, ', ' ORDER BY title) FROM tasks
      """

  Scenario: After the page morphs, Select stays pressed and still ticks rows
    When I visit "/admin/tasks?filter=next"
    And I click "Select"
    And I click "Cancel" on the task row "first"
    And I say yes to the question
    Then the toast says "Canceled"
    And the page has "button[data-bulk-toggle][aria-pressed='true']:has-text('Select')"
    When I tick the task "second"
    Then the page part "[data-bulk-count]" reads "1 ticked"

  Scenario: Select all on a paged list ticks only the rows on the page
    Given 98 more tasks on next called "filler"
    When I visit "/admin/tasks?filter=next"
    And I click "Select"
    And I tick the page box "[data-bulk-all] input"
    And I click "Done" in "form#task-bulk"
    Then the page shows the part "[data-toast] .toast:has-text('Finished 100 tasks')"
    And the database soon holds "filler 98, elsewhere" for:
      """
      SELECT string_agg(title, ', ' ORDER BY position DESC) FROM tasks WHERE status = 'open'
      """
