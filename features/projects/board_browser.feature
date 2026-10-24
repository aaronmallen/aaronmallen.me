Feature: Moving cards on the project board in the browser
  The board moves a card by its arrow, its menu or a drag without loading the page again, loads more cards in
  place and opens a card's task in the drawer.

  Background:
    Given I am signed in to the admin
    And the projects:
      | name | key |
      | blog | BLO |
    And the project tasks:
      | title           | project |
      | Write the brief | blog    |

  Scenario: A card moves by its arrow in place
    When I visit "/admin/projects/{project:blog}"
    And I keep the page
    And I hover the page part ".kc:has-text('Write the brief')"
    And I click the page part ".kc:has-text('Write the brief') button[aria-label='Move to ready']"
    Then the page shows the part ".kcol.k-ready .kc:has-text('Write the brief')"
    And the toast says "Moved BLO-1 to ready"
    And the page did not load again

  Scenario: A card moves from its menu in place
    When I visit "/admin/projects/{project:blog}"
    And I keep the page
    And I right-click the card "Write the brief" away from its title
    And I hover "Board column" in the menu
    And I choose "in progress" in the menu
    Then the page shows the part ".kcol.k-in_progress .kc:has-text('Write the brief')"
    And the page did not load again

  Scenario: A card dragged to another column moves in place, and one dragged to in progress starts
    When I visit "/admin/projects/{project:blog}"
    And I keep the page
    And I drag the card "Write the brief" onto the column "ready"
    Then the page shows the part ".kcol.k-ready .kc:has-text('Write the brief')"
    And the toast says "Moved BLO-1 to ready"
    And the database soon holds "ready" for:
      """
      SELECT stage FROM tasks
      """
    And the page did not load again
    When I drag the card "Write the brief" onto the column "in_progress"
    Then the page shows the part ".kcol.k-in_progress .kc.doing:has-text('Write the brief')"
    And the database soon holds "in_progress" for:
      """
      SELECT status FROM tasks
      """

  Scenario: A full column loads more cards in place and keeps them through a live change and a reload
    Given 20 tasks in "blog" in the column "backlog"
    When I visit "/admin/projects/{project:blog}"
    And I keep the page
    And I click "Load more · 1 left"
    Then the page has 21 of ".kcol.k-backlog .kc"
    And I am on "/admin/projects/1?backlog=40"
    And the page did not load again
    Given the project tasks:
      | title      | project | stage |
      | Live brief | blog    | ready |
    Then the page shows the part ".kcol.k-ready .kc:has-text('Live brief')"
    And the page has 21 of ".kcol.k-backlog .kc"
    When I visit "/admin/projects/1?backlog=40"
    Then the page has 21 of ".kcol.k-backlog .kc"

  Scenario: A card opens its task in the drawer
    When I visit "/admin/projects/{project:blog}"
    And I click the page part ".kc:has-text('Write the brief') .kc-title"
    Then the page shows the part "dialog[data-task-panel][open]:has-text('Write the brief')"
