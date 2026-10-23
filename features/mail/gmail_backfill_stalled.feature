Feature: A stalled Gmail backfill
  A backfill page that fails past its retries keeps its place. The Gmail sync queues it again
  once it has stalled for an hour, while the account still holds its Google connection.

  Background:
    Given the Google account "aaron@example.com" is connected with "openid gmail.modify"
    And Gmail is quiet at history "100" for "aaron@example.com"
    And the Gmail sync runs
    And Gmail answers GET "/users/me/threads" with status 503
    And the Gmail backfill runs for "aaron@example.com" from the page "page-2"

  Scenario: The sync leaves a backfill alone while it might still be retrying
    When the Gmail sync runs
    Then Gmail received GET "/users/me/threads" 2 times
    And the mail account "aaron@example.com" holds the Gmail page "page-2"

  Scenario: The sync queues a stalled backfill again, only once
    Given an hour passes for the Gmail account "aaron@example.com"
    When the Gmail sync runs
    Then Gmail received GET "/users/me/threads" 3 times
    When the Gmail sync runs
    Then Gmail received GET "/users/me/threads" 3 times
    And the mail account "aaron@example.com" holds the Gmail page "page-2"

  Scenario: The sync goes on with a stalled backfill and lets it finish on its saved page
    Given an hour passes for the Gmail account "aaron@example.com"
    And Gmail answers GET "/users/me/threads" with:
      """
      {"threads": []}
      """
    When the Gmail sync runs
    Then the mail account "aaron@example.com" holds the Gmail page "none"

  Scenario: The sync never queues a backfill again once it reads its last page
    Given Gmail answers GET "/users/me/threads" with:
      """
      {"threads": []}
      """
    And the Gmail backfill runs for "aaron@example.com" from the page "page-2"
    And an hour passes for the Gmail account "aaron@example.com"
    When the Gmail sync runs
    Then Gmail received GET "/users/me/threads" 3 times
    And the mail account "aaron@example.com" holds the Gmail page "none"

  Scenario: The sync does not queue the backfill of an account whose connection is revoked or gone
    Given the Google connection for "aaron@example.com" is revoked
    And an hour passes for the Gmail account "aaron@example.com"
    When the Gmail sync runs
    Then Gmail received GET "/users/me/threads" 2 times
    Given the Google connection for "aaron@example.com" is gone
    When the Gmail sync runs
    Then Gmail received GET "/users/me/threads" 2 times

  Scenario: The sync goes on with a stalled backfill once the account reconnects
    Given the Google connection for "aaron@example.com" is revoked
    And an hour passes for the Gmail account "aaron@example.com"
    And the Gmail sync runs
    And the Google connection for "aaron@example.com" is back
    When the Gmail sync runs
    Then Gmail received GET "/users/me/threads" 3 times
