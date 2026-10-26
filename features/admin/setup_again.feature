Feature: Admin scripts after new markup
  When the page swaps its main, top bar, palette and key help for new markup and hears two morphs, each admin
  script still works, and works once.

  Background:
    Given I am signed in to the admin
    And the tasks:
      | title  | list | position |
      | first  | next | 1        |
      | second | next | 2        |
      | third  | next | 3        |
    And the database runs:
      """
      INSERT INTO sprints (sprint_date) VALUES ((now() AT TIME ZONE 'America/Chicago')::date) ON CONFLICT DO NOTHING
      """
    When I visit "/admin/tasks?filter=next"
    And the admin page swaps in new markup and hears two morphs

  Scenario: A dialog opens from its new trigger
    When I open the key help from the avatar menu
    Then the page has "dialog#key-help[open]"

  Scenario: A dialog closes once from its new button
    When I open the key help from the avatar menu
    And I count the dialog closes
    And I click the element "dialog#key-help [data-dialog-close]"
    Then the page has no "dialog#key-help[open]"
    And dialogs closed 1 time

  Scenario: The new avatar menu picks a theme
    When I pick the theme the avatar menu does not mark
    Then the avatar menu marks the theme I picked

  Scenario: The palette opens from its new trigger and moves one row per arrow
    When I click the element ".top-bar-search"
    And the admin markup lacks "[data-palette-list][aria-busy]"
    And I press "ArrowDown" in "[data-palette-query]"
    Then the palette picks its second shown row

  Scenario: j moves one row
    When I press the keys "j j"
    Then the highlighted row holds "second"

  Scenario: The new bulk form counts the ticked rows
    When I click the button "Select"
    And I tick the task "first"
    And I tick the task "second"
    Then "[data-bulk-count]" reads "2 ticked"

  Scenario: A task opens from the new list in the panel
    When I click the element ".task-title:text-is('second')"
    Then "dialog#task-panel[open] h1" reads "second"

  Scenario: A drag saves once
    When I count the requests to "/admin/tasks/{task:first}/place"
    And I drag the task "first" below "third"
    Then 1 request to "/admin/tasks/{task:first}/place" came back
    And the task rows read "second, third, first"
