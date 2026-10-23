Feature: Home page
  The home page lists the newest published posts.

  Scenario: A published post shows on the home page
    Given a post "Hello world" published an hour ago
    When I visit the home page
    Then the home page lists "Hello world"
    And the page has no axe breaches in light or dark

  Scenario: The home page reads on a phone
    Given a post "Hello world" published an hour ago
    And I use a phone
    When I visit the home page
    Then the page has no axe breaches in light or dark

  Scenario: A scheduled post shows once the due posts job runs
    Given a post "Due now" scheduled for an hour ago
    Then the home page lists nothing under writing
    When the due posts job runs
    Then the home page lists "Due now"
