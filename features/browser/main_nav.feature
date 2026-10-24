Feature: The public header
  The header fills the current page's pill, flips the theme from one toggle, and gives every control a 44px
  target on a phone.

  Scenario: The header fills the current page's pill, shows one theme icon and no menu toggle
    When I visit "/about"
    Then the texts of "nav.main-nav a[aria-current='page']" are:
      | about |
    And the page has no ".site-header button[aria-controls]:not(.settings-menu-toggle)"
    And 1 of "[data-theme-toggle] i" are visible

  Scenario: The toggle flips the theme both ways
    When I visit "/about"
    And I click the element "[data-theme-toggle]"
    And I keep the page's theme
    And I click the element "[data-theme-toggle]"
    Then the two themes were light and dark

  Scenario: A theme saved in the cookie draws past the content security policy
    Then a browser that keeps to the content security policy and holds the cookie "site_theme=dark" draws "/about" in the "dark" theme

  Scenario: On a phone the pills wrap to a full-width row and every control is a 44px target
    Given I use a phone
    When I visit "/about"
    Then the width of "nav.main-nav" is more than 330 pixels
    And every visible control in ".site-header" is at least 44 pixels tall
    And the page has no axe breaches in light or dark
