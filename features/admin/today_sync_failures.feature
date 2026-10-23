Feature: Sync failures on the Today page
  When a sync or a nightly job fails, the Needs attention card says which one, when, why and for how long.

  Background:
    Given I am signed in to the admin
    And the country database holds the test networks

  Scenario: Today says nothing while every sync is healthy
    When I visit "/admin"
    Then the Today page shows no sync failures

  Scenario: A sync failure warns with a sign and a time tag
    Given these sync failures:
      | sync    | reason        |
      | backups | upload_failed |
    When I visit "/admin"
    Then the sync failure warns with a sign
    And the sync failure has the time "2026-01-07T09:30:00-06:00"

  Scenario Outline: A sync failure reads as one line on the card
    Given these sync failures:
      | sync   | repo   | reason   | message   | since   | count   |
      | <sync> | <repo> | <reason> | <message> | <since> | <count> |
    When I visit "/admin"
    Then the sync failures read:
      """
      <line>
      """

    Examples:
      | sync             | repo            | reason        | message             | since                | count | line                                                                                                                           |
      | analytics_rollup |                 | rollup_failed |                     |                      | 1     | Analytics rollup failed at Jan 7, 2026, 09:30 · The days wouldn't roll up                                                      |
      | backups          |                 | upload_failed |                     |                      | 1     | Database backup failed at Jan 7, 2026, 09:30 · The dump wouldn't upload                                                        |
      | commits          |                 | teapot        |                     |                      | 1     | Commit import failed at Jan 7, 2026, 09:30 · teapot                                                                            |
      | commits          | aaronmallen/one | rate_limited  |                     |                      | 1     | Commit import failed for aaronmallen/one at Jan 7, 2026, 09:30 · It hit the rate limit                                         |
      | commits          |                 | page_limit    |                     |                      | 1     | Commit import failed at Jan 7, 2026, 09:30 · It stopped at the page limit                                                      |
      | commits          |                 | github_failed |                     |                      | 1     | Commit import failed at Jan 7, 2026, 09:30 · GitHub didn't answer                                                              |
      | commits          |                 | github_failed |                     | 2025-12-20T15:30:00Z | 2     | Commit import failed at Jan 7, 2026, 09:30 · GitHub didn't answer · failing since Dec 20, 2025                                 |
      | commits          | aaronmallen/one | rate_limited  |                     | 2025-12-20T15:30:00Z | 2     | Commit import failed for aaronmallen/one at Jan 7, 2026, 09:30 · It hit the rate limit · failing since Dec 20, 2025            |
      | commits          |                 | github_failed | GitHub answered 502 | 2025-12-20T15:30:00Z | 2     | Commit import failed at Jan 7, 2026, 09:30 · GitHub didn't answer · failing since Dec 20, 2025 · GitHub answered 502           |

  Scenario: Today leaves out a repository the page limit stopped, and links nowhere for it
    Given these sync failures:
      | sync    | repo            | reason       |
      | commits | aaronmallen/big | page_limit   |
      | commits | aaronmallen/one | rate_limited |
    When I visit "/admin"
    Then the sync failures read:
      """
      Commit import failed for aaronmallen/one at Jan 7, 2026, 09:30 · It hit the rate limit
      """
    And the Today page never names "aaronmallen/big"
    And the Today page has no link to a backfill

  Scenario: Today lists both syncs when both failed
    Given these sync failures:
      | sync     | reason        |
      | commits  | rate_limited  |
      | projects | github_failed |
    When I visit "/admin"
    Then the Today page shows 2 sync failures

  Scenario: A failed commit import reads what GitHub answered
    Given the Today page has a GitHub token
    And GitHub answers POST "/graphql" with status 502
    When the Today sync job "Record::Jobs::ImportCommits" runs
    And I visit "/admin"
    Then the sync failures match:
      """
      Commit import failed at <any> · GitHub didn't answer · GitHub answered 502 for GraphQL
      """

  Scenario: A failed pull request import reads what GitHub answered
    Given the Today page has a GitHub token
    And GitHub answers POST "/graphql" with status 502
    When the Today sync job "Record::Jobs::ImportPullRequests" runs
    And I visit "/admin"
    Then the sync failures match:
      """
      Pull request import failed at <any> · GitHub didn't answer · GitHub answered 502 for GraphQL
      """

  Scenario: A failed project refresh reads what GitHub answered
    Given the Today page has a GitHub token
    And the database runs:
      """
      insert into projects (name, repo, visibility, key) values ('Blog', 'aaronmallen/blog', 'public', 'BLOG');
      """
    And GitHub answers GET "/repos/aaronmallen/blog" with status 502
    When the Today sync job "Projects::Jobs::RefreshProjects" runs
    And I visit "/admin"
    Then the sync failures match:
      """
      Project refresh failed at <any> · GitHub didn't answer · GitHub answered 502 for /repos/aaronmallen/blog
      """

  Scenario: Failed GitHub and Linear issue syncs read apart, and each clears alone
    Given the Today page has a GitHub token
    And a Linear key for the Today page
    And GitHub answers POST "/graphql" with status 502
    And Linear answers POST "/graphql" with status 502
    When the Today sync job "Tasks::Jobs::SyncIssues" runs for "github"
    And the Today sync job "Tasks::Jobs::SyncIssues" runs for "linear"
    And I visit "/admin"
    Then the sync failures match:
      """
      GitHub issue sync failed at <any> · GitHub didn't answer · GitHub answered 502 for GraphQL
      Linear issue sync failed at <any> · Linear didn't answer · Linear answered 502 for GraphQL
      """
    Given Linear answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "0b7f5a52-viewer", "assignedIssues": {"nodes": [], "pageInfo": {"endCursor": null, "hasNextPage": false}}}}}
      """
    When the Today sync job "Tasks::Jobs::SyncIssues" runs for "linear"
    And I visit "/admin"
    Then the sync failures match:
      """
      GitHub issue sync failed at <any> · GitHub didn't answer · GitHub answered 502 for GraphQL
      """

  Scenario: A sync that recovers drops its line, and fails again without its old streak
    Given a Linear key for the Today page
    And Linear answers POST "/graphql" with status 502
    When the Today sync job "Tasks::Jobs::SyncIssues" runs for "linear"
    And the Today sync job "Tasks::Jobs::SyncIssues" runs for "linear"
    And the database runs:
      """
      update sync_states set failing_since = '2025-12-20 15:30:00+00' where kind = 'failure';
      """
    And I visit "/admin"
    Then the sync failures match:
      """
      Linear issue sync failed at <any> · Linear didn't answer · failing since Dec 20, 2025 · Linear answered 502 for GraphQL
      """
    Given Linear answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "0b7f5a52-viewer", "assignedIssues": {"nodes": [], "pageInfo": {"endCursor": null, "hasNextPage": false}}}}}
      """
    When the Today sync job "Tasks::Jobs::SyncIssues" runs for "linear"
    And I visit "/admin"
    Then the Today page shows no sync failures
    Given Linear answers POST "/graphql" with status 502
    When the Today sync job "Tasks::Jobs::SyncIssues" runs for "linear"
    And I visit "/admin"
    Then the sync failures match:
      """
      Linear issue sync failed at <any> · Linear didn't answer · Linear answered 502 for GraphQL
      """

  Scenario: Today says the country database is gone rather than leaving every visitor unknown
    Given the Today page's country database is gone
    When I visit "/admin"
    Then the sync failures read:
      """
      Country lookup · No database on disk
      """

  Scenario: Today lists the missing country database beside a sync that failed once
    Given these sync failures:
      | sync    | reason       |
      | commits | rate_limited |
    And the Today page's country database is gone
    When I visit "/admin"
    Then the last sync failure reads "Country lookup · No database on disk"

  Scenario: Today reads a dead MaxMind key off the failed refresh, message and all
    Given MaxMind answers the download with status 401
    When the country database refresh runs for the Today page
    And I visit "/admin"
    Then the sync failures match:
      """
      Country database refresh failed at <any> · The download failed · MaxMind answered 401 for GeoLite2-City
      """
