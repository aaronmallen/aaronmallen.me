Feature: Social composer with no account connected
  With no network connected the composer cannot send anything and says why.

  Background:
    Given I am signed in to the admin

  Scenario: Every target is off, both buttons are off, and the sub-line says no network is connected
    When I visit "/admin/social"
    Then the social page has no "[data-social-target]:checked"
    And the social page has no "[data-social-target]:enabled"
    And the social page has no "[data-social-composer] button[type='submit']:enabled"
    And the social page shows "No network is connected · 0 queued" in ".page-head-sub"
    And the page has no axe breaches in light or dark

  Scenario: An account disconnected since the form opened is refused
    When I send the social composer:
      | accounts | 0  |
      | parts    | hi |
    Then the social composer says "That network has no credentials"
