Feature: Privacy
  The privacy page says what the site keeps about a visit, for how long, and how to ask about it.

  Scenario: The privacy page opens with its head and says how long each thing stays
    When I visit "/privacy"
    Then "header.hd h1" reads "What I keep about your visit."
    And "header.hd .ld" reads "No tracking cookies, no ads and no scripts from anyone else. Here is what the site does keep, why, and for how long."
    And the list after the heading "How long it stays" has 2 items holding "90 days"
    And the list after the heading "How long it stays" has 1 item holding "12 months old"
    And the list after the heading "How long it stays" has 1 item holding "for good"
    And the page has no axe breaches in light or dark

  Scenario: The privacy page matches the windows the analytics keep
    When I visit "/privacy"
    Then the page shows "90 days"
    And the page shows "12 months"
    And the page shows "30 seconds"
    And the page shows "20 minutes"
    And the page shows "up to 20 minutes"

  Scenario: The privacy page points requests to the contact form and publishes no address
    When I visit "/privacy"
    Then ".prose p:has-text('To ask what I hold about you')" has a link "contact form" to "/contact"
    When I request "/privacy"
    Then the body does not include "mailto:"
