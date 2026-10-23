Feature: Broken links in the admin
  The posts list gathers the links that failed the nightly check, in posts and short links, says when the last
  check ran and whether it stopped early, and checks a link again on demand.

  Background:
    Given I am signed in to the admin

  Scenario: The broken filter counts and lists only published posts with a failing link
    Given a published post "Broken" that links to:
      """
      http://203.0.113.40/gone
      http://203.0.113.41/slow
      """
    And a published post "Fine" that links to:
      """
      http://203.0.113.42/fine
      """
    And these short links:
      | code | destination              |
      | slow | http://203.0.113.41/slow |
    And the post_link_checks table holds:
      | post_id | url                      | failures | reason        | checked_at | first_failed_at |
      | 1       | http://203.0.113.40/gone | 1        | 404 Not Found | 1 day ago  | 1 day ago       |
      | 2       | http://203.0.113.42/fine | 0        | null          | 1 day ago  | null            |
    And the short_link_checks table holds:
      | short_link_id | url                      | failures | reason                  | checked_at | first_failed_at |
      | 1             | http://203.0.113.41/slow | 1        | 503 Service Unavailable | 1 day ago  | 1 day ago       |
    When I visit "/admin/posts"
    Then I see "broken · 2"
    And I see "0 drafts in progress."
    When I visit "/admin/posts?status=broken"
    Then the broken links filter is checked
    And the post list shows "Broken" and not "Fine"
    And the page has no axe breaches in light or dark

  Scenario: The header line counts the broken links and says when the last check finished
    Given a published post "Linked" that links to:
      """
      http://203.0.113.40/gone
      http://203.0.113.41/slow
      """
    And a published post "Other" that links to:
      """
      http://203.0.113.41/slow
      """
    And these short links:
      | code | destination              |
      | slow | http://203.0.113.41/slow |
    And the post_link_checks table holds:
      | post_id | url                      | failures | reason        | checked_at           | first_failed_at      |
      | 1       | http://203.0.113.40/gone | 1        | 404 Not Found | 2026-10-12T08:12:00Z | 2026-10-12T08:12:00Z |
      | 2       | http://203.0.113.41/slow | 2        | 404 Not Found | 2026-10-13T08:12:00Z | 2026-10-12T08:12:00Z |
    And the short_link_checks table holds:
      | short_link_id | url                      | failures | reason                  | checked_at           | first_failed_at      |
      | 1             | http://203.0.113.41/slow | 1        | 503 Service Unavailable | 2026-10-12T08:12:00Z | 2026-10-12T08:12:00Z |
    And the link_check_runs table holds:
      | started_at           | finished_at          | links_checked | links_due |
      | 2026-10-13T08:02:00Z | 2026-10-13T08:12:00Z | 3             | 3         |
    When I visit "/admin/posts?status=broken"
    Then I see "3 broken links: 2 in 2 posts and 1 short link."
    And I see "The last check finished Oct 13 · 03:12"

  Scenario: The finish time comes from the latest run, and stays out while a run is going
    Given a published post "Linked" that links to:
      """
      http://203.0.113.40/gone
      """
    And the post_link_checks table holds:
      | post_id | url                      | failures | reason        | checked_at           | first_failed_at      |
      | 1       | http://203.0.113.40/gone | 3        | 404 Not Found | 2026-10-14T08:12:00Z | 2026-10-12T08:12:00Z |
    And the link_check_runs table holds:
      | started_at           | finished_at          | links_checked | links_due |
      | 2026-10-12T08:02:00Z | 2026-10-12T08:12:00Z | 1             | 1         |
    When I visit "/admin/posts?status=broken"
    Then I see "The last check finished Oct 12 · 03:12"
    Given the link_check_runs table holds:
      | started_at           | finished_at | links_due |
      | 2026-10-12T08:13:00Z | null        | 1         |
    When I visit "/admin/posts?status=broken"
    Then I do not see "finished"

  Scenario: The header line says when nothing is broken
    Given a published post "Fine" that links to:
      """
      http://203.0.113.42/fine
      """
    And the post_link_checks table holds:
      | post_id | url                      | failures | reason | checked_at |
      | 1       | http://203.0.113.42/fine | 0        | null   | 1 day ago  |
    When I visit "/admin/posts?status=broken"
    Then I see "Every link answered the last check"

  Scenario: A post lists its failing links, longest failing first, with what to do about each
    Given a published post "Linked" that links to:
      """
      http://203.0.113.42/fine
      http://203.0.113.40/gone
      http://203.0.113.41/slow
      """
    And the post_link_checks table holds:
      | post_id | url                      | failures | reason        | checked_at           | first_failed_at      |
      | 1       | http://203.0.113.41/slow | 1        | 404 Not Found | 2026-10-12T08:12:00Z | 2026-10-12T08:12:00Z |
      | 1       | http://203.0.113.40/gone | 3        | 404 Not Found | 2026-10-14T08:12:00Z | 2026-10-12T08:12:00Z |
      | 1       | http://203.0.113.42/fine | 0        | null          | 2026-10-12T08:12:00Z | null                 |
    When I visit "/admin/posts?status=broken"
    Then the failing links read "http://203.0.113.40/gone, http://203.0.113.41/slow"
    And the first failing link shows a pink pill reading "failing 3 nights", the reason "404 Not Found" and "first failed Oct 12, 2026"
    And the first failing link offers to fix it at "/admin/posts/1/edit?links=1" and to open "http://203.0.113.40/gone"
    And the links page holds "form#broken-links-check input[name='return_to'][value='/admin/posts?status=broken']"
    And the page has no axe breaches in light or dark

  Scenario Outline: A post's row carries a failing tag coloured by how long its links fail
    Given a published post "Linked" that links to:
      """
      http://203.0.113.40/gone
      http://203.0.113.41/slow
      """
    And the post_link_checks table holds:
      | post_id | url                      | failures | reason        | checked_at | first_failed_at |
      | 1       | http://203.0.113.40/gone | <gone>   | <gone_reason> | 1 day ago  | <gone_first>    |
      | 1       | http://203.0.113.41/slow | <slow>   | <slow_reason> | 1 day ago  | <slow_first>    |
    When I visit "/admin/posts"
    Then the post row "Linked" <tag>

    Examples:
      | gone | gone_reason   | gone_first | slow | slow_reason   | slow_first | tag                                    |
      | 1    | 404 Not Found | 1 day ago  | 0    | null          | null       | carries an orange tag "1 link failing" |
      | 2    | 404 Not Found | 2 days ago | 1    | 404 Not Found | 1 day ago  | carries a pink tag "2 links failing"   |
      | 0    | null          | null       | 0    | null          | null       | carries no failing tag                 |

  Scenario: The short links card lists failing destinations and skips a failure against an old destination
    Given these short links:
      | code  | destination              |
      | fine  | http://203.0.113.42/fine |
      | slow  | http://203.0.113.41/slow |
      | moved | http://203.0.113.40/gone |
    And the short_link_checks table holds:
      | short_link_id | url                      | failures | reason                  | checked_at | first_failed_at |
      | 2             | http://203.0.113.41/slow | 1        | 503 Service Unavailable | 1 day ago  | 1 day ago       |
      | 3             | https://old.example/     | 1        | 404 Not Found           | 1 day ago  | 1 day ago       |
    When I visit "/admin/posts?status=broken"
    Then the short links card says "1 of 3 failing" and lists "http://203.0.113.41/slow" only
    And the short links card shows an orange pill reading "failing" and the reason "503 Service Unavailable"
    And the short links card offers to change the destination at "/admin/links/2/edit" and to open "http://203.0.113.41/slow"

  Scenario: Check again on a post link checks it, says so and stays on the list
    Given a published post "Linked" that links to:
      """
      http://203.0.113.40/gone
      """
    And the post_link_checks table holds:
      | post_id | url                      | failures | reason        | checked_at | first_failed_at |
      | 1       | http://203.0.113.40/gone | 1        | 404 Not Found | 1 day ago  | 1 day ago       |
    And the web answers GET "http://203.0.113.40/gone" with status 200
    When I visit "/admin/posts?status=broken"
    And I press the check again button for "http://203.0.113.40/gone"
    Then I see "Checking that link"
    And I am on "/admin/posts?status=broken"
    And the post_link_checks table has a row with:
      | url                      | failures |
      | http://203.0.113.40/gone | 0        |
    And I see "Every link answered the last check"

  Scenario: Check again on a short link checks it and the card clears once the check lands
    Given these short links:
      | code | destination              |
      | slow | http://203.0.113.41/slow |
    And the short_link_checks table holds:
      | short_link_id | url                      | failures | reason                  | checked_at | first_failed_at |
      | 1             | http://203.0.113.41/slow | 1        | 503 Service Unavailable | 1 day ago  | 1 day ago       |
    And the web answers GET "http://203.0.113.41/slow" with status 200
    When I visit "/admin/posts?status=broken"
    Then I see "1 of 1 failing"
    When I press the check again button for "http://203.0.113.41/slow"
    Then I see "Checking that link"
    And I am on "/admin/posts?status=broken"
    And the short_link_checks table has a row with:
      | short_link_id | failures |
      | 1             | 0        |
    And I do not see "1 of 1 failing"

  Scenario: A check landing updates the open list
    Given a published post "Linked" that links to:
      """
      http://203.0.113.40/gone
      """
    And these short links:
      | code | destination              |
      | gone | http://203.0.113.40/gone |
    And the post_link_checks table holds:
      | post_id | url                      | failures | reason        | checked_at | first_failed_at |
      | 1       | http://203.0.113.40/gone | 1        | 404 Not Found | 1 day ago  | 1 day ago       |
    And the short_link_checks table holds:
      | short_link_id | url                      | failures | reason        | checked_at | first_failed_at |
      | 1             | http://203.0.113.40/gone | 1        | 404 Not Found | 1 day ago  | 1 day ago       |
    When I visit "/admin/posts?status=broken"
    And the post link check of "http://203.0.113.40/gone" passes behind the page
    Then I see "1 broken link: 0 in 0 posts and 1 short link."
    When the short link check of "http://203.0.113.40/gone" passes behind the page
    Then I see "Every link answered the last check"

  Scenario: Check again says so when the job queue is down
    Given a published post "Linked" that links to:
      """
      http://203.0.113.40/gone
      """
    And these short links:
      | code | destination              |
      | gone | http://203.0.113.40/gone |
    And the post_link_checks table holds:
      | post_id | url                      | failures | reason        | checked_at | first_failed_at |
      | 1       | http://203.0.113.40/gone | 1        | 404 Not Found | 1 day ago  | 1 day ago       |
    And the short_link_checks table holds:
      | short_link_id | url                      | failures | reason        | checked_at | first_failed_at |
      | 1             | http://203.0.113.40/gone | 1        | 404 Not Found | 1 day ago  | 1 day ago       |
    When I visit "/admin/posts?status=broken"
    And Redis goes down
    And I press the first check again button for "http://203.0.113.40/gone"
    Then I see "Not queued · the job queue is down, so try again soon"
    When I visit "/admin/posts?status=broken"
    And I press the last check again button for "http://203.0.113.40/gone"
    Then I see "Not queued · the job queue is down, so try again soon"

  Scenario: A run that stopped early shows a banner on Posts and Today, and Run it now starts another
    Given the link_check_runs table holds:
      | started_at           | finished_at          | links_checked | links_due |
      | 2026-10-13T08:02:00Z | 2026-10-13T08:12:00Z | 290           | 473       |
    When I visit "/admin/posts?status=broken"
    Then I see "The last check stopped early Oct 13 · 03:12, after 290 of 473 links. The rest keep their earlier results."
    And the page has no axe breaches in light or dark
    When I visit "/admin"
    Then I see "The last check stopped early Oct 13 · 03:12, after 290 of 473 links."
    When I visit "/admin/posts"
    Then I do not see "The last check stopped early"
    When I visit "/admin/posts?status=broken"
    And I click "Run it now"
    Then I see "Checking every link"
    And I am on "/admin/posts?status=broken"
    And the link_check_runs table has a row with:
      | links_checked | links_due | finished_at |
      | 0             | 0         | set         |

  Scenario: Run it now says so when the job queue is down
    Given the link_check_runs table holds:
      | started_at           | finished_at          | links_checked | links_due |
      | 2026-10-13T08:02:00Z | 2026-10-13T08:12:00Z | 290           | 473       |
    When I visit "/admin/posts?status=broken"
    And Redis goes down
    And I click "Run it now"
    Then I see "Not queued · the job queue is down, so try again soon"

  Scenario: The banner stays away after a full run
    Given the link_check_runs table holds:
      | started_at           | finished_at          | links_checked | links_due |
      | 2026-10-12T08:02:00Z | 2026-10-12T08:12:00Z | 290           | 473       |
      | 2026-10-13T08:02:00Z | 2026-10-13T08:12:00Z | 473           | 473       |
    When I visit "/admin/posts?status=broken"
    Then I do not see "The last check stopped early"

  Scenario: The banner stays away while a run is going and comes back to the page it was on
    Given the link_check_runs table holds:
      | started_at           | finished_at          | links_checked | links_due |
      | 2026-10-12T08:02:00Z | 2026-10-12T08:12:00Z | 290           | 473       |
    When I visit "/admin/posts?status=broken"
    Then the link check banner comes back to "/admin/posts?status=broken"
    Given the link_check_runs table holds:
      | started_at           | finished_at | links_due |
      | 2026-10-12T08:13:00Z | null        | 473       |
    When I visit "/admin"
    Then I do not see "The last check stopped early"
