Feature: The worker during maintenance
  While the maintenance flag file exists the worker puts each one-off job off for later and drops each
  scheduled job, since its next run tries again. Once the file is gone, jobs run again.

  Scenario: A one-off job waits while the maintenance flag is up, and runs once it comes down
    Given a short link to "http://203.0.113.5/page" with no title
    And the web answers GET "http://203.0.113.5/page" with:
      """
      <html><head><title>Hello from the page</title></head></html>
      """
    And the maintenance flag is up
    When the short link title job runs
    Then the worker puts the job off for later
    And the short link has no title
    When the maintenance flag comes down
    And the put off job comes due
    Then the short link's title is "Hello from the page"

  Scenario: A scheduled job is dropped while the maintenance flag is up
    Given a post "Due now" scheduled for an hour ago
    And the maintenance flag is up
    When the due posts job runs
    Then the worker drops the job
    And the post "Due now" is still scheduled
