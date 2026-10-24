Feature: Inline icons
  The public site draws its icons as inline SVG, and the admin keeps the icon font.

  Scenario: Every public icon is inline SVG
    When I visit "/contact"
    Then the page has "i svg"
    And the page has no "i:not(:has(svg))"

  Scenario: The admin keeps its icons on the icon font
    Given I am signed in to the admin
    When I visit "/admin"
    Then the page has "i"
    And the page has no "i svg"
