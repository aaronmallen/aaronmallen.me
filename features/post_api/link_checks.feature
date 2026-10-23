Feature: Checking the links in blog posts
  The nightly link check fetches each outbound link in a published post once, and keeps a count of the
  failures in a row with the reason. A later check of one post or one link counts on from it.

  Scenario: The nightly check fetches each outbound link once and records the run
    Given a published post "Notes" that links to:
      """
      http://203.0.113.10/notes/1
      http://203.0.113.11/gone
      http://203.0.113.10/notes/1
      {site}/writing/hello
      /about
      http://192.168.1.10/admin
      """
    And a published post "More" that links to:
      """
      http://203.0.113.11/gone
      """
    And a draft post "Draft" that links to:
      """
      http://203.0.113.12/draft
      """
    And the short_codes table holds:
      | code |
      | talk |
    And the short_links table holds:
      | short_code_id | destination                 |
      | 1             | http://203.0.113.10/notes/1 |
    And the web answers GET "http://203.0.113.10/notes/1" with:
      """
      <p>a note</p>
      """
    And the web answers GET "http://203.0.113.11/gone" with status 404
    When the job "Posts::Jobs::CheckPostLinks" runs
    Then the link_check_runs table has a row with:
      | links_checked | links_due | stopped_early | started_at | finished_at |
      | 4             | 4         | false         | set        | set         |
    And the post_link_checks table holds 4 rows
    And the post_link_checks table has a row with:
      | post_id | url                         | failures | reason | checked_at | first_failed_at |
      | 1       | http://203.0.113.10/notes/1 | 0        | null   | set        | null            |
    And the post_link_checks table has a row with:
      | post_id | url                      | failures | reason        | checked_at | first_failed_at |
      | 1       | http://203.0.113.11/gone | 1        | 404 Not Found | set        | set             |
    And the post_link_checks table has a row with:
      | post_id | url                      | failures | reason        |
      | 2       | http://203.0.113.11/gone | 1        | 404 Not Found |
    And the post_link_checks table has a row with:
      | post_id | url                       | failures | reason |
      | 1       | http://192.168.1.10/admin | 0        | null   |

  Scenario Outline: The check counts a broken status as a failure and a turned away bot as working
    Given a published post "Notes" that links to:
      """
      http://203.0.113.10/page
      """
    And the web answers GET "http://203.0.113.10/page" with status <status>
    When the job "Posts::Jobs::CheckPostLinks" runs
    Then the post_link_checks table has a row with:
      | url                      | failures   | reason   |
      | http://203.0.113.10/page | <failures> | <reason> |

    Examples:
      | status | failures | reason                  |
      | 404    | 1        | 404 Not Found           |
      | 410    | 1        | 410 Gone                |
      | 503    | 1        | 503 Service Unavailable |
      | 599    | 1        | 599                     |
      | 429    | 0        | null                    |
      | 403    | 0        | null                    |

  Scenario: A link that keeps failing counts on and keeps the time it first failed
    Given a published post "Notes" that links to:
      """
      http://203.0.113.11/gone
      """
    And the post_link_checks table holds:
      | post_id | url                      | failures | reason        | checked_at | first_failed_at      |
      | 1       | http://203.0.113.11/gone | 1        | 404 Not Found | 1 day ago  | 2026-10-01T00:00:00Z |
    And the web answers GET "http://203.0.113.11/gone" with status 404
    When the job "Posts::Jobs::CheckPostLinks" runs
    Then the post_link_checks table has a row with:
      | failures | first_failed_at          |
      | 2        | 2026-10-01T00:00:00.000Z |

  Scenario: A link that passes again resets its count and forgets when it first failed
    Given a published post "Notes" that links to:
      """
      http://203.0.113.10/notes/1
      """
    And the post_link_checks table holds:
      | post_id | url                         | failures | reason        | checked_at | first_failed_at      |
      | 1       | http://203.0.113.10/notes/1 | 2        | 404 Not Found | 1 day ago  | 2026-10-01T00:00:00Z |
    And the web answers GET "http://203.0.113.10/notes/1" with status 200
    When the job "Posts::Jobs::CheckPostLinks" runs
    Then the post_link_checks table has a row with:
      | failures | reason | first_failed_at |
      | 0        | null   | null            |

  Scenario: The check forgets links a post dropped and the links of a post taken back to a draft
    Given a published post "Notes" that links to:
      """
      http://203.0.113.10/notes/1
      """
    And a draft post "Back" that links to:
      """
      http://203.0.113.11/gone
      """
    And the post_link_checks table holds:
      | post_id | url                      | failures | reason        | checked_at |
      | 1       | http://203.0.113.11/gone | 1        | 404 Not Found | 1 day ago  |
      | 2       | http://203.0.113.11/gone | 1        | 404 Not Found | 1 day ago  |
    And the web answers GET "http://203.0.113.10/notes/1" with status 200
    When the job "Posts::Jobs::CheckPostLinks" runs
    Then the link_check_runs table has a row with:
      | finished_at |
      | set         |
    And the post_link_checks table holds 1 rows
    And the post_link_checks table has a row with:
      | post_id | url                         |
      | 1       | http://203.0.113.10/notes/1 |

  Scenario: A check of one post fetches every link in it and counts on from the nightly run
    Given a published post "Notes" that links to:
      """
      http://203.0.113.10/notes/1
      http://203.0.113.11/gone
      """
    And a published post "Other" that links to:
      """
      http://203.0.113.12/other
      """
    And the post_link_checks table holds:
      | post_id | url                      | failures | reason        | checked_at |
      | 1       | http://203.0.113.11/gone | 1        | 404 Not Found | 1 day ago  |
    And the web answers GET "http://203.0.113.10/notes/1" with status 200
    And the web answers GET "http://203.0.113.11/gone" with status 404
    When the job "Posts::Jobs::CheckPostLinksAgain" runs with:
      """
      [1]
      """
    Then the post_link_checks table has a row with:
      | url                      | failures | reason        |
      | http://203.0.113.11/gone | 2        | 404 Not Found |
    And the post_link_checks table has a row with:
      | url                         | failures |
      | http://203.0.113.10/notes/1 | 0        |
    And the post_link_checks table holds 2 rows

  Scenario: A check of one link fetches only that link
    Given a published post "Notes" that links to:
      """
      http://203.0.113.10/notes/1
      http://203.0.113.11/gone
      """
    And the web answers GET "http://203.0.113.11/gone" with status 404
    When the job "Posts::Jobs::CheckPostLinksAgain" runs with:
      """
      [1, "http://203.0.113.11/gone"]
      """
    Then the post_link_checks table has a row with:
      | url                      | failures |
      | http://203.0.113.11/gone | 1        |
    And the post_link_checks table holds 1 rows

  Scenario: A check of one link fetches nothing the post no longer names, nor anything in a draft
    Given a published post "Notes" that links to:
      """
      http://203.0.113.10/notes/1
      """
    And a draft post "Draft" that links to:
      """
      http://203.0.113.11/gone
      """
    And the post_link_checks table holds:
      | post_id | url                      | failures | reason        | checked_at |
      | 1       | http://203.0.113.11/gone | 1        | 404 Not Found | 1 day ago  |
    When the job "Posts::Jobs::CheckPostLinksAgain" runs with:
      """
      [2]
      """
    And the job "Posts::Jobs::CheckPostLinksAgain" runs with:
      """
      [1, "http://203.0.113.11/gone"]
      """
    Then the post_link_checks table holds 0 rows

  Scenario: The check follows a redirect to the page it lands on, and counts endless redirects as working
    Given a published post "Notes" that links to:
      """
      http://203.0.113.11/moved
      http://203.0.113.11/loop
      """
    And the web answers GET "http://203.0.113.11/moved" with a redirect to "http://203.0.113.10/notes/1"
    And the web answers GET "http://203.0.113.10/notes/1" with status 200
    And the web answers GET "http://203.0.113.11/loop" with a redirect to "http://203.0.113.11/loop"
    When the job "Posts::Jobs::CheckPostLinks" runs
    Then the link check of "http://203.0.113.11/moved" records 0 failures with the reason "null", waiting up to 10 seconds
    And the link check of "http://203.0.113.11/loop" records 0 failures with the reason "null", waiting up to 10 seconds

  Scenario: The check names the site and the link check when it asks for a page
    Given a published post "Notes" that links to:
      """
      http://203.0.113.10/notes/1
      """
    And the web answers GET "http://203.0.113.10/notes/1" with status 200
    When the job "Posts::Jobs::CheckPostLinks" runs
    Then the link check asked for "http://203.0.113.10/notes/1" naming the site and the link check

  Scenario: The check counts a page that will not answer in time as a failure and says how long it waited
    Given a published post "Notes" that links to:
      """
      http://203.0.113.13/slow
      """
    And the web holds its answer to GET "http://203.0.113.13/slow" for 15 seconds
    When the job "Posts::Jobs::CheckPostLinks" runs
    Then the link check of "http://203.0.113.13/slow" records 1 failure with the reason "Timed out after 10 seconds", waiting up to 25 seconds

  Scenario: The check reads the status without waiting for a long body
    Given a published post "Notes" that links to:
      """
      http://203.0.113.14/big
      """
    And the web answers GET "http://203.0.113.14/big" with status 404 and a long body still to come
    When the job "Posts::Jobs::CheckPostLinks" runs
    Then the link check of "http://203.0.113.14/big" records 1 failure with the reason "404 Not Found", waiting up to 10 seconds

  Scenario: The check counts a host no resolver answers for as a failure
    Given a published post "Notes" that links to:
      """
      http://no-such-host.invalid/page
      """
    When the job "Posts::Jobs::CheckPostLinks" runs
    Then the link check of "http://no-such-host.invalid/page" records 1 failure with a reason holding "resolve"
