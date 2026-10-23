Feature: Admin menu switcher
  Below 860px a switcher button takes the place of the pills. It names the screen I am on, flags waiting mail, and
  opens a panel of every screen in two stacked sides. The top bar shrinks the search and the wordmark to fit.

  Background:
    Given I am signed in to the admin
    And the contact form brings in "Hello"

  Scenario: At 860px the pills show and the switcher hides
    Given the admin window is 860 by 800
    When I visit "/admin"
    Then ".pill-nav" shows
    And the admin markup lacks ".switcher:visible"

  Scenario: Below 860px the switcher names the screen and flags the waiting mail on one 4.5rem row
    Given the admin window is 859 by 800
    When I visit "/admin/inbox"
    Then ".switcher:has-text('Inbox')" shows
    And the admin markup lacks ".pill-nav:visible"
    And the top bar stands 72px tall
    And ".switcher[aria-label='Navigate. Current: Inbox, waiting'] .pill-nav-dot" shows
    And ".switcher-screen:has-text('waiting')" shows

  Scenario: The switcher reports whether its panel is open
    Given the admin window is 859 by 800
    When I visit "/admin/inbox"
    Then the switcher reports itself shut
    When I open the switcher
    Then the switcher reports itself open

  Scenario: Escape closes the switcher
    Given the admin window is 859 by 800
    When I visit "/admin/inbox"
    And I open the switcher
    And I press the keys "Escape"
    Then the switcher panel is shut

  Scenario: A click outside closes the switcher
    Given the admin window is 859 by 800
    When I visit "/admin/inbox"
    And I open the switcher
    And I click the admin window at 10, 790
    Then the switcher panel is shut

  Scenario: The switcher opens the chosen screen and closes
    Given the admin window is 859 by 800
    When I visit "/admin/inbox"
    And I open the switcher
    And I follow "mail" in the switcher
    Then ".switcher[aria-label='Navigate. Current: Inbox, mail']" shows
    And the switcher panel is shut

  Scenario: The switcher keeps working after a live update redraws the top bar
    Given the admin window is 859 by 800
    When I open "/admin/inbox" and its live stream
    And the contact form brings in "Hello there"
    Then "main:has-text('Hello there')" shows
    When I open the switcher
    And I follow "mail" in the switcher
    Then ".switcher-screen:has-text('mail')" shows

  Scenario: At 480px search folds into a 44px icon button, the switcher drops the screen and the wordmark shrinks
    Given the admin window is 480 by 844
    When I visit "/admin/inbox"
    Then the top bar search button is 44px wide
    And the admin markup lacks ".top-bar-search-label:visible"
    And the admin markup lacks ".top-bar-search-key:visible"
    And ".switcher:has-text('Inbox')" shows
    And the admin markup lacks ".switcher-screen:visible"
    And the wordmark's font size is "15px"
    And the wordmark reads "AARON/ALLEN"

  Scenario: At 400px the wordmark cuts to its initials
    Given the admin window is 400 by 844
    When I visit "/admin"
    Then the wordmark reads "A/A"

  Scenario Outline: At <width>px the switcher opens on two stacked sides
    Given the admin window is <width> by 800
    When I visit "/admin"
    And I open the switcher
    Then the switcher sides name the groups:
      | today, Tasks, Publish, Insights |
      | Inbox, Journal, Agents          |
    And each switcher side keeps one column
    And each switcher group sits 4px under the one above it
    And today is as wide as the switcher groups under it

    Examples:
      | width |
      | 375   |
      | 800   |

  Scenario: With scripts off the switcher still opens and follows a row
    Then with scripts off at 390 by 844, the switcher opens and follows "tasks" to "/admin/tasks"

  Scenario Outline: <path> at <width>px passes axe in light and dark
    Given the admin window is <width> by 800
    When I visit "<path>"
    Then the page has no axe breaches in light or dark

    Examples:
      | path         | width |
      | /admin       | 860   |
      | /admin/inbox | 480   |
