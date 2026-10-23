Feature: Gmail backfill
  The backfill job reads an account's Gmail threads a page at a time, half a minute apart,
  and waits two minutes when Gmail rate limits it.

  Background:
    Given the Google account "aaron@example.com" is connected with "openid gmail.modify"
    And the Gmail account "aaron@example.com" has synced to history "100"
    And I am signed in to the admin

  Scenario: The backfill stores every thread on the page and stops after the last page
    Given Gmail answers GET "/users/me/threads" with:
      """
      {"threads": [{"id": "t1"}, {"id": "t2"}]}
      """
    And Gmail holds the thread "t1" with the messages:
      | id |
      | m1 |
    And Gmail holds the thread "t2" with the messages:
      | id | labels |
      | m2 | SPAM   |
    When the Gmail backfill runs for "aaron@example.com"
    Then the Gmail threads are "t1, t2"
    And the mail account "aaron@example.com" holds the Gmail page "none"
    And the jobs page lists no "Mail::Jobs::BackfillGmail"
    And the page has no axe breaches in light or dark

  Scenario: The backfill queues the next page half a minute out
    Given Gmail answers GET "/users/me/threads" with:
      """
      {"threads": [], "nextPageToken": "page-2"}
      """
    When the Gmail backfill runs for "aaron@example.com"
    Then the mail account "aaron@example.com" holds the Gmail page "page-2"
    And the jobs page lists "Mail::Jobs::BackfillGmail" with "\"aaron@example.com\",\"page-2\"" in about 30 seconds

  Scenario: A page Gmail rate limits partway through is queued again in two minutes
    Given Gmail answers GET "/users/me/threads" with:
      """
      {"threads": [{"id": "t1"}, {"id": "t2"}], "nextPageToken": "page-3"}
      """
    And Gmail holds the thread "t1" with the messages:
      | id |
      | m1 |
    And Gmail rate limits GET "/users/me/threads/t2" with status 403
    When the Gmail backfill runs for "aaron@example.com" from the page "page-2"
    Then the Gmail threads are "t1"
    And the mail account "aaron@example.com" holds the Gmail page "page-2"
    And the jobs page lists "Mail::Jobs::BackfillGmail" with "\"aaron@example.com\",\"page-2\"" in about 120 seconds

  Scenario: The backfill treats a 429 from Gmail as a rate limit too
    Given Gmail rate limits GET "/users/me/threads" with status 429
    When the Gmail backfill runs for "aaron@example.com"
    Then the jobs page lists "Mail::Jobs::BackfillGmail" with "\"aaron@example.com\",null" in about 120 seconds
