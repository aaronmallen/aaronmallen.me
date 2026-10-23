Feature: Switching pools on the Today page
  The pools under the sprint switch in place, so the owner keeps their place on the page.

  Background:
    Given I am signed in to the admin
    And the country database holds the test networks
    And the Today pool next holds "Email the accountant"
    And the Today pool someday holds "Learn Elixir"
    When I visit "/admin"
    And I switch the Today pool to "someday · 1" further down the page

  Scenario: Switching the pool swaps it in without loading the page
    Then the pools list "Learn Elixir"
    And the Today page switched the pool without loading again or scrolling
    And the pool tab "someday · 1" is the current page

  Scenario: Switching the pool lets the owner copy a key from the new pool
    When I copy the key of the first task in the "someday" pool
    Then the Today page toasts "Task 2 copied" and copied "2"
