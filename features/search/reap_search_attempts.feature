Feature: Reap search attempts
  Each public search claims an attempt against the visitor's limit. A job deletes the attempts that fall outside
  the one-minute window and keeps the rest.

  Scenario: The job deletes an attempt older than the window and keeps the ones inside it
    When I visit "/search?q=zeppelin"
    And I visit "/search?q=airship"
    Then the database answers "2" for:
      """
      select count(*) from search_attempts
      """
    Given the database runs:
      """
      update search_attempts set attempted_at = now() - interval '61 seconds' where id = 1;
      update search_attempts set attempted_at = now() - interval '40 seconds' where id = 2;
      """
    When the search attempts reaper runs
    Then the database soon answers "0" for:
      """
      select count(*) from search_attempts where id = 1
      """
    And the database answers "2" for:
      """
      select string_agg(id::text, ', ') from search_attempts
      """
