@timeout:180000
Feature: The sync state reap
  The sync state reap lists the repositories I can push to and drops the walks and failures left by any it no
  longer finds. It reaps nothing when it cannot trust the list, and records why under the commits sync.

  Background:
    Given the record jobs have a GitHub token
    And the commit walk for "aaronmallen/renamed" starts at "1 hour ago"
    And these sync failures:
      | sync    | repo                | reason        |
      | commits | aaronmallen/renamed | github_failed |

  Scenario: A repository GitHub no longer lists loses its back edge and failure
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"nameWithOwner": "aaronmallen/aaronmallen.me", "pushedAt": "2026-08-01T00:00:00Z", "viewerPermission": "ADMIN"}]}}}}
      """
    When the sync state reap runs
    Then the commit walk for "aaronmallen/renamed" has ended
    And the "commits" sync records no failure for "aaronmallen/renamed"

  Scenario: A repository that is merely quiet keeps everything it left, as does the whole sync's failure
    Given the commit walk for "aaronmallen/aaronmallen.me" starts at "1 hour ago"
    And these sync failures:
      | sync    | repo                       | reason         |
      | commits | aaronmallen/aaronmallen.me | github_failed  |
      | commits |                            | not_configured |
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"nameWithOwner": "aaronmallen/aaronmallen.me", "pushedAt": "2026-08-01T00:00:00Z", "viewerPermission": "ADMIN"}]}}}}
      """
    When the sync state reap runs
    Then the commit walk for "aaronmallen/aaronmallen.me" stands at "1 hour ago"
    And the "commits" sync failure for "aaronmallen/aaronmallen.me" reads "github_failed"
    And the "commits" sync failure reads "not_configured"

  Scenario: A repository nobody has pushed to in years keeps its walk
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"nameWithOwner": "aaronmallen/aaronmallen.me", "pushedAt": "2026-08-01T00:00:00Z", "viewerPermission": "ADMIN"},
          {"nameWithOwner": "aaronmallen/renamed", "pushedAt": null, "viewerPermission": "ADMIN"}]}}}}
      """
    When the sync state reap runs
    Then the commit walk for "aaronmallen/renamed" stands at "1 hour ago"

  Scenario: A clean reap leaves the import's failure alone
    Given these sync failures:
      | sync    | reason       |
      | commits | rate_limited |
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"nameWithOwner": "aaronmallen/aaronmallen.me", "pushedAt": "2026-08-01T00:00:00Z", "viewerPermission": "ADMIN"}]}}}}
      """
    When the sync state reap runs
    Then the "commits" sync failure reads "rate_limited"
    And the "commits" sync has failed 1 time

  Scenario: A reap with no GitHub token reaps nothing, asks GitHub for nothing and leaves the import to report it
    Given these sync failures:
      | sync    | reason         |
      | commits | not_configured |
    And the record jobs lose their GitHub token
    When the sync state reap runs
    Then the commit walk for "aaronmallen/renamed" stands at "1 hour ago"
    And the "commits" sync failure reads "not_configured"
    And the "commits" sync has failed 1 time

  Scenario: A list the page limit cuts short reaps nothing and records the page limit
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"repositories": {"pageInfo": {"hasNextPage": true, "endCursor": "repos-page-2"}, "nodes": [
          {"nameWithOwner": "aaronmallen/aaronmallen.me", "pushedAt": "2026-08-01T00:00:00Z", "viewerPermission": "ADMIN"}]}}}}
      """
    When the sync state reap runs
    Then the commit walk for "aaronmallen/renamed" stands at "1 hour ago"
    And the "commits" sync failure reads "page_limit"

  Scenario: A reap GitHub breaks reaps nothing and keeps GitHub's message
    Given GitHub answers POST "/graphql" with status 500
    When the sync state reap runs
    Then the commit walk for "aaronmallen/renamed" stands at "1 hour ago"
    And the "commits" sync failure reads "github_failed"
    And the "commits" sync failure says "GitHub answered 500 for GraphQL"

  Scenario: A reap GitHub rate limits reaps nothing and records the rate limit
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 0, "resetAt": "2099-01-01T00:00:00Z"}},
        "errors": [{"type": "RATE_LIMITED", "message": "API rate limit exceeded"}]}
      """
    When the sync state reap runs
    Then the commit walk for "aaronmallen/renamed" stands at "1 hour ago"
    And the "commits" sync failure reads "rate_limited"

  Scenario Outline: A reap reaps nothing and records nothing when <when>
    Given GitHub answers POST "/graphql" with:
      """
      <answer>
      """
    When the sync state reap runs
    Then the commit walk for "aaronmallen/renamed" stands at "1 hour ago"
    And the "commits" sync records no failure

    Examples:
      | when                                    | answer                                                                                                                                                                                                   |
      | the list comes back empty               | {"data": {"viewer": {"repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": []}}}}                                                                                             |
      | every listed repository is read-only    | {"data": {"viewer": {"repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [{"nameWithOwner": "aaronmallen/aaronmallen.me", "pushedAt": null, "viewerPermission": "READ"}]}}}} |
      | GitHub sends an answer it cannot read   | <html>maintenance</html>                                                                                                                                                                                 |

  Scenario: A reap reads every page of the repository list
    Given GitHub answers POST "/graphql" next with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"repositories": {"pageInfo": {"hasNextPage": true, "endCursor": "repos-page-2"}, "nodes": [
          {"nameWithOwner": "aaronmallen/aaronmallen.me", "pushedAt": "2026-08-01T00:00:00Z", "viewerPermission": "ADMIN"}]}}}}
      """
    And GitHub answers POST "/graphql" next with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"nameWithOwner": "aaronmallen/renamed", "pushedAt": "2026-08-01T00:00:00Z", "viewerPermission": "ADMIN"}]}}}}
      """
    When the sync state reap runs
    Then the commit walk for "aaronmallen/renamed" stands at "1 hour ago"
