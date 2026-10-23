Feature: Redis going away under the worker
  The site keeps answering while Redis is down, and the worker runs jobs again once Redis comes back.

  @timeout:180_000
  Scenario: The worker runs jobs again once Redis comes back
    Given a post "Due now" scheduled for an hour ago
    When Redis goes down
    Then the home page answers 200
    When Redis comes back
    And the due posts job runs
    Then the home page lists "Due now"
