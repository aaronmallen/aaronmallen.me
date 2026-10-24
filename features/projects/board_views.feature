Feature: Switching the project board between the board and the list
  The view links switch in place and the browser keeps the choice; with nothing saved the width picks, and CSS
  picks when script is off.

  Background:
    Given I am signed in to the admin
    And the projects:
      | name | key |
      | blog | BLO |
    And the project tasks:
      | title           | project |
      | Write the brief | blog    |
    When I visit "/admin/projects/{project:blog}"
    And the browser forgets the saved board view

  Scenario: The list link shows the list in place and the board link shows the board again
    When I visit "/admin/projects/{project:blog}"
    And I keep the page
    And I click the page part ".kb-view a:has-text('list')"
    Then I am on "/admin/projects/1?view=list"
    And the board view shows list
    And the page part ".kb-view a.current[aria-current='page']" holds "list"
    And the page did not load again
    When I click the page part ".kb-view a:has-text('board')"
    Then I am on "/admin/projects/1?view=board"
    And the board view shows board
    And the page did not load again

  Scenario: The browser keeps the choice for the next visit, and a view in the address beats it
    When I visit "/admin/projects/{project:blog}"
    And I click the page part ".kb-view a:has-text('list')"
    And I visit "/admin/projects/{project:blog}"
    Then the board view shows list
    When I visit "/admin/projects/{project:blog}?view=board"
    Then the board view shows board

  Scenario: With nothing saved the board shows above 700 pixels wide and the list at 700
    When I visit "/admin/projects/{project:blog}"
    Then the board view shows board
    Given the window is 700 by 800
    When I visit "/admin/projects/{project:blog}"
    Then the board view shows list

  Scenario: With no pick CSS shows the list at 700 pixels wide and the board at 701
    Given the window is 700 by 800
    When I visit "/admin/projects/{project:blog}"
    And the page forgets the board view it picked
    Then the board view shows list
    Given the window is 701 by 800
    When I visit "/admin/projects/{project:blog}"
    And the page forgets the board view it picked
    Then the board view shows board

  Scenario: The list moves a task with its column picker or a drag, in place
    Given the project tasks:
      | title  | project |
      | Second | blog    |
    When I visit "/admin/projects/{project:blog}?view=list"
    And I keep the page
    And I pick "ready" in the page select ".kli:has-text('Write the brief') select[name=to]"
    Then the page shows the part ".klg.k-ready .kli:has-text('Write the brief')"
    And the toast says "Moved BLO-1 to ready"
    And the board view shows list
    And the page did not load again
    When I drag ".kli:has-text('Second') .task-title" onto ".klg.k-ready summary"
    Then the page shows the part ".klg.k-ready .kli:has-text('Second')"
    And the toast says "Moved BLO-2 to ready"
    And the database soon holds "ready, ready" for:
      """
      SELECT string_agg(stage::text, ', ') FROM tasks
      """
    And the page did not load again

  Scenario: A group folds from its header, and the canceled group opens from its
    Given the project tasks:
      | title   | project | status   |
      | Dropped | blog    | canceled |
    When I visit "/admin/projects/{project:blog}?view=list"
    And I click the page part ".klg.k-backlog summary"
    Then the page hides ".klg.k-backlog .kli"
    When I click the page part ".klg.k-backlog summary"
    Then the page shows the part ".klg.k-backlog .kli:has-text('Write the brief')"
    When I click the page part ".klg.k-canceled summary"
    Then the page shows the part ".klg.k-canceled .kli:has-text('Dropped')"
