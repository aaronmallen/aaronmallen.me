Feature: The settings menu
  The gear opens the settings menu, which closes on Escape or a click outside it.

  Background:
    Given I am signed in to the admin
    When I visit "/about"
    And I click the element ".settings-menu-toggle"

  Scenario: The menu opens from the gear
    Then "#settings-menu" is visible

  Scenario: The menu closes on Escape and hands focus back to the gear
    When I press "Escape"
    Then "#settings-menu" is hidden
    And the focus is on ".settings-menu-toggle"

  Scenario: The menu closes on a click outside it
    When I click the element "main"
    Then "#settings-menu" is hidden
