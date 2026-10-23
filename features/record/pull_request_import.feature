@timeout:180000
Feature: The pull request import
  The pull request import searches GitHub for the pull requests I authored, stores each one with when it was
  opened, made ready, merged or closed, and records how the run went under the pull requests sync.

  Background:
    Given the record jobs have a GitHub token

  Scenario: A pull request import keeps mine, from any repository, with the title and description
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "search": {"issueCount": 3, "pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"number": 7, "title": "Import pull requests", "body": "Adds the import",
            "url": "https://github.com/someone/else/pull/7", "createdAt": "2026-10-01T12:00:00Z", "isDraft": false,
            "state": "OPEN", "mergedAt": null, "closedAt": null, "viewerDidAuthor": true,
            "repository": {"nameWithOwner": "someone/else"}, "timelineItems": {"nodes": []}},
          {"number": 8, "title": "Not mine", "body": "",
            "url": "https://github.com/aaronmallen/aaronmallen.me/pull/8", "createdAt": "2026-10-01T12:00:00Z",
            "isDraft": false, "state": "OPEN", "mergedAt": null, "closedAt": null, "viewerDidAuthor": false,
            "repository": {"nameWithOwner": "aaronmallen/aaronmallen.me"}, "timelineItems": {"nodes": []}},
          {"number": 9, "title": "Import them", "body": "Every one",
            "url": "https://github.com/aaronmallen/aaronmallen.me/pull/9", "createdAt": "2026-10-01T12:00:00Z",
            "isDraft": false, "state": "OPEN", "mergedAt": null, "closedAt": null, "viewerDidAuthor": true,
            "repository": {"nameWithOwner": "aaronmallen/aaronmallen.me"}, "timelineItems": {"nodes": []}}]}}}
      """
    When the pull request import runs
    Then the database answers "someone/else 7 Import pull requests https://github.com/someone/else/pull/7, aaronmallen/aaronmallen.me 9 Import them https://github.com/aaronmallen/aaronmallen.me/pull/9" for:
      """
      select string_agg(concat_ws(' ', repo, number, title, url), ', ' order by number) from pull_requests
      """
    And the database answers "Every one" for:
      """
      select body from pull_requests where number = 9
      """
    And GitHub was asked for a pull request search holding "is:pr author:@me"
    And GitHub was asked for a pull request search holding "updated:2008-01-01T00:00:00Z.."

  Scenario: A pull request import stores when each one was opened and made ready
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "search": {"issueCount": 2, "pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"number": 1, "title": "Opened ready", "body": "", "url": "https://github.com/aaronmallen/aaronmallen.me/pull/1",
            "createdAt": "2026-10-01T12:00:00Z", "isDraft": false, "state": "OPEN", "mergedAt": null, "closedAt": null,
            "viewerDidAuthor": true, "repository": {"nameWithOwner": "aaronmallen/aaronmallen.me"},
            "timelineItems": {"nodes": []}},
          {"number": 2, "title": "Opened as a draft", "body": "", "url": "https://github.com/aaronmallen/aaronmallen.me/pull/2",
            "createdAt": "2026-10-01T12:00:00Z", "isDraft": true, "state": "OPEN", "mergedAt": null, "closedAt": null,
            "viewerDidAuthor": true, "repository": {"nameWithOwner": "aaronmallen/aaronmallen.me"},
            "timelineItems": {"nodes": []}}]}}}
      """
    When the pull request import runs
    Then the database answers "1 true true, 2 none true" for:
      """
      select string_agg(concat_ws(' ', number, coalesce((ready_at = '2026-10-01T12:00:00Z')::text, 'none'),
                                  (opened_at = '2026-10-01T12:00:00Z')::text), ', ' order by number)
      from pull_requests
      """

  Scenario: A draft gets the time it was marked ready once it is
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "search": {"issueCount": 1, "pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"number": 1, "title": "A draft", "body": "", "url": "https://github.com/aaronmallen/aaronmallen.me/pull/1",
            "createdAt": "2026-10-01T12:00:00Z", "isDraft": true, "state": "OPEN", "mergedAt": null, "closedAt": null,
            "viewerDidAuthor": true, "repository": {"nameWithOwner": "aaronmallen/aaronmallen.me"},
            "timelineItems": {"nodes": []}}]}}}
      """
    And the pull request import runs
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "search": {"issueCount": 1, "pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"number": 1, "title": "A draft", "body": "", "url": "https://github.com/aaronmallen/aaronmallen.me/pull/1",
            "createdAt": "2026-10-01T12:00:00Z", "isDraft": false, "state": "OPEN", "mergedAt": null, "closedAt": null,
            "viewerDidAuthor": true, "repository": {"nameWithOwner": "aaronmallen/aaronmallen.me"},
            "timelineItems": {"nodes": [{"createdAt": "2026-10-02T12:00:00Z"}]}}]}}}
      """
    When the pull request import runs
    Then the database answers "true" for:
      """
      select ready_at = '2026-10-02T12:00:00Z' from pull_requests
      """

  Scenario: A pull request import stores how each one ended
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "search": {"issueCount": 2, "pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"number": 1, "title": "Merged", "body": "", "url": "https://github.com/aaronmallen/aaronmallen.me/pull/1",
            "createdAt": "2026-10-01T12:00:00Z", "isDraft": false, "state": "MERGED",
            "mergedAt": "2026-10-03T12:00:00Z", "closedAt": "2026-10-03T12:00:00Z",
            "viewerDidAuthor": true, "repository": {"nameWithOwner": "aaronmallen/aaronmallen.me"},
            "timelineItems": {"nodes": []}},
          {"number": 2, "title": "Closed", "body": "", "url": "https://github.com/aaronmallen/aaronmallen.me/pull/2",
            "createdAt": "2026-10-01T12:00:00Z", "isDraft": false, "state": "CLOSED",
            "mergedAt": null, "closedAt": "2026-10-03T12:00:00Z",
            "viewerDidAuthor": true, "repository": {"nameWithOwner": "aaronmallen/aaronmallen.me"},
            "timelineItems": {"nodes": []}}]}}}
      """
    When the pull request import runs
    Then the database answers "1 merged true closed none, 2 merged none closed true" for:
      """
      select string_agg(concat_ws(' ', number,
        'merged', coalesce((merged_at = '2026-10-03T12:00:00Z')::text, 'none'),
        'closed', coalesce((closed_at = '2026-10-03T12:00:00Z')::text, 'none')), ', ' order by number)
      from pull_requests
      """

  Scenario: A pull request import drops the closed time once it is reopened
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "search": {"issueCount": 1, "pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"number": 1, "title": "Closed", "body": "", "url": "https://github.com/aaronmallen/aaronmallen.me/pull/1",
            "createdAt": "2026-10-01T12:00:00Z", "isDraft": false, "state": "CLOSED",
            "mergedAt": null, "closedAt": "2026-10-03T12:00:00Z",
            "viewerDidAuthor": true, "repository": {"nameWithOwner": "aaronmallen/aaronmallen.me"},
            "timelineItems": {"nodes": []}}]}}}
      """
    And the pull request import runs
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "search": {"issueCount": 1, "pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"number": 1, "title": "Closed", "body": "", "url": "https://github.com/aaronmallen/aaronmallen.me/pull/1",
            "createdAt": "2026-10-01T12:00:00Z", "isDraft": false, "state": "OPEN",
            "mergedAt": null, "closedAt": "2026-10-03T12:00:00Z",
            "viewerDidAuthor": true, "repository": {"nameWithOwner": "aaronmallen/aaronmallen.me"},
            "timelineItems": {"nodes": []}}]}}}
      """
    When the pull request import runs
    Then the database answers "none" for:
      """
      select coalesce(closed_at::text, 'none') from pull_requests
      """

  Scenario: A later import picks up an edit on GitHub into the same row
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "search": {"issueCount": 1, "pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"number": 1, "title": "Import pull requests", "body": "Adds the import",
            "url": "https://github.com/aaronmallen/aaronmallen.me/pull/1", "createdAt": "2026-10-01T12:00:00Z",
            "isDraft": false, "state": "OPEN", "mergedAt": null, "closedAt": null, "viewerDidAuthor": true,
            "repository": {"nameWithOwner": "aaronmallen/aaronmallen.me"}, "timelineItems": {"nodes": []}}]}}}
      """
    And the pull request import runs
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "search": {"issueCount": 1, "pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"number": 1, "title": "Import them all", "body": "Edited",
            "url": "https://github.com/aaronmallen/aaronmallen.me/pull/1", "createdAt": "2026-10-01T12:00:00Z",
            "isDraft": false, "state": "OPEN", "mergedAt": null, "closedAt": null, "viewerDidAuthor": true,
            "repository": {"nameWithOwner": "aaronmallen/aaronmallen.me"}, "timelineItems": {"nodes": []}}]}}}
      """
    When the pull request import runs
    Then the database answers "1, Import them all, Edited" for:
      """
      select count(*) as rows, min(title) as title, min(body) as body from pull_requests
      """

  Scenario: A later import that reads nothing new tells the admin nothing and leaves the row alone
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "search": {"issueCount": 1, "pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"number": 1, "title": "Import pull requests", "body": "Adds the import",
            "url": "https://github.com/aaronmallen/aaronmallen.me/pull/1", "createdAt": "2026-10-01T12:00:00Z",
            "isDraft": false, "state": "OPEN", "mergedAt": null, "closedAt": null, "viewerDidAuthor": true,
            "repository": {"nameWithOwner": "aaronmallen/aaronmallen.me"}, "timelineItems": {"nodes": []}}]}}}
      """
    And the pull request import runs
    And the database runs:
      """
      update pull_requests set updated_at = now() - interval '1 hour';
      """
    When the pull request import runs while the admin listens
    Then the admin hears of "nothing"
    And the database answers "1, true" for:
      """
      select count(*), bool_and(updated_at < now() - interval '50 minutes') from pull_requests
      """
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "search": {"issueCount": 1, "pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"number": 1, "title": "Renamed", "body": "Adds the import",
            "url": "https://github.com/aaronmallen/aaronmallen.me/pull/1", "createdAt": "2026-10-01T12:00:00Z",
            "isDraft": false, "state": "OPEN", "mergedAt": null, "closedAt": null, "viewerDidAuthor": true,
            "repository": {"nameWithOwner": "aaronmallen/aaronmallen.me"}, "timelineItems": {"nodes": []}}]}}}
      """
    When the pull request import runs
    Then the database answers "Renamed, true" for:
      """
      select title, updated_at > now() - interval '5 minutes' from pull_requests
      """

  Scenario: A pull request import that finishes clears the sync's failure
    Given these sync failures:
      | sync          | reason       |
      | pull_requests | rate_limited |
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "search": {"issueCount": 0, "pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": []}}}
      """
    When the pull request import runs
    Then the "pull_requests" sync records no failure

  Scenario: A pull request import GitHub rate limits records it
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 0, "resetAt": "2099-01-01T00:00:00Z"}},
        "errors": [{"type": "RATE_LIMITED", "message": "API rate limit exceeded"}]}
      """
    When the pull request import runs
    Then the "pull_requests" sync failure reads "rate_limited"

  Scenario: A pull request import records what GitHub answered beside the reason
    Given GitHub answers POST "/graphql" with status 502
    When the pull request import runs
    Then the "pull_requests" sync failure reads "github_failed"
    And the "pull_requests" sync failure says "GitHub answered 502 for GraphQL"

  Scenario: A pull request import with no GitHub token records the sync that never ran and asks GitHub for nothing
    Given the record jobs lose their GitHub token
    When the pull request import runs
    Then the "pull_requests" sync failure reads "not_configured"

  Scenario: A pull request import leaves the run to the one holding the lock and reports nothing
    Given these sync failures:
      | sync          | reason       |
      | pull_requests | rate_limited |
    When the pull request import runs while another run holds its lock
    Then the "pull_requests" sync failure reads "rate_limited"
    And the "pull_requests" sync has failed 1 time

  Scenario: A pull request import that crashes records the crash and still fails the job
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "search": {"issueCount": 1, "pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"title": "No number", "body": "", "url": "https://github.com/aaronmallen/aaronmallen.me/pull/1",
            "createdAt": "2026-10-01T12:00:00Z", "isDraft": false, "state": "OPEN", "mergedAt": null, "closedAt": null,
            "viewerDidAuthor": true, "repository": {"nameWithOwner": "aaronmallen/aaronmallen.me"},
            "timelineItems": {"nodes": []}}]}}}
      """
    When the pull request import runs
    Then the "pull_requests" sync failure reads "crashed"
    And the "pull_requests" sync failure says "key not found: \"number\""
    And the record job "Record::Jobs::ImportPullRequests" failed with a KeyError

  Scenario: A first import splits my history into windows small enough for search to hold
    Given GitHub answers POST "/graphql" next with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "search": {"issueCount": 1500, "pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"number": 1, "title": "Import pull requests", "body": "", "url": "https://github.com/aaronmallen/aaronmallen.me/pull/1",
            "createdAt": "2026-10-01T12:00:00Z", "isDraft": false, "state": "OPEN", "mergedAt": null, "closedAt": null,
            "viewerDidAuthor": true, "repository": {"nameWithOwner": "aaronmallen/aaronmallen.me"},
            "timelineItems": {"nodes": []}}]}}}
      """
    And GitHub answers POST "/graphql" next with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "search": {"issueCount": 1, "pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"number": 2008, "title": "Import pull requests", "body": "", "url": "https://github.com/aaronmallen/aaronmallen.me/pull/2008",
            "createdAt": "2026-10-01T12:00:00Z", "isDraft": false, "state": "OPEN", "mergedAt": null, "closedAt": null,
            "viewerDidAuthor": true, "repository": {"nameWithOwner": "aaronmallen/aaronmallen.me"},
            "timelineItems": {"nodes": []}}]}}}
      """
    And GitHub answers POST "/graphql" next with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "search": {"issueCount": 1, "pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"number": 2017, "title": "Import pull requests", "body": "", "url": "https://github.com/aaronmallen/aaronmallen.me/pull/2017",
            "createdAt": "2026-10-01T12:00:00Z", "isDraft": false, "state": "OPEN", "mergedAt": null, "closedAt": null,
            "viewerDidAuthor": true, "repository": {"nameWithOwner": "aaronmallen/aaronmallen.me"},
            "timelineItems": {"nodes": []}}]}}}
      """
    When the pull request import runs
    Then GitHub was asked 3 times for the query "viewerDidAuthor"
    And the database answers "2008, 2017" for:
      """
      select string_agg(number::text, ', ' order by number) from pull_requests
      """

  Scenario: A first import follows a window to its next page and keeps the newest copy of one listed twice
    Given GitHub answers POST "/graphql" next with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "search": {"issueCount": 1, "pageInfo": {"hasNextPage": true, "endCursor": "pulls-page-2"}, "nodes": [
          {"number": 1, "title": "Import pull requests", "body": "", "url": "https://github.com/aaronmallen/aaronmallen.me/pull/1",
            "createdAt": "2026-10-01T12:00:00Z", "isDraft": false, "state": "OPEN", "mergedAt": null, "closedAt": null,
            "viewerDidAuthor": true, "repository": {"nameWithOwner": "aaronmallen/aaronmallen.me"},
            "timelineItems": {"nodes": []}}]}}}
      """
    And GitHub answers POST "/graphql" next with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "search": {"issueCount": 1, "pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"number": 2, "title": "Second", "body": "", "url": "https://github.com/aaronmallen/aaronmallen.me/pull/2", "createdAt": "2026-10-01T12:00:00Z", "isDraft": false, "state": "OPEN", "mergedAt": null, "closedAt": null, "viewerDidAuthor": true, "repository": {"nameWithOwner": "aaronmallen/aaronmallen.me"}, "timelineItems": {"nodes": []}},
          {"number": 1, "title": "New", "body": "", "url": "https://github.com/aaronmallen/aaronmallen.me/pull/1",
            "createdAt": "2026-10-01T12:00:00Z", "isDraft": false, "state": "OPEN", "mergedAt": null, "closedAt": null,
            "viewerDidAuthor": true, "repository": {"nameWithOwner": "aaronmallen/aaronmallen.me"},
            "timelineItems": {"nodes": []}}]}}}
      """
    When the pull request import runs
    Then the database answers "1 New, 2 Second" for:
      """
      select string_agg(number || ' ' || title, ', ' order by number) from pull_requests
      """

  Scenario: A pull request import stores nothing from a run that fails part way
    Given GitHub answers POST "/graphql" next with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "search": {"issueCount": 1, "pageInfo": {"hasNextPage": true, "endCursor": "pulls-page-2"}, "nodes": [
          {"number": 1, "title": "Import pull requests", "body": "", "url": "https://github.com/aaronmallen/aaronmallen.me/pull/1",
            "createdAt": "2026-10-01T12:00:00Z", "isDraft": false, "state": "OPEN", "mergedAt": null, "closedAt": null,
            "viewerDidAuthor": true, "repository": {"nameWithOwner": "aaronmallen/aaronmallen.me"},
            "timelineItems": {"nodes": []}}]}}}
      """
    And GitHub answers the record jobs next with status 502
    When the pull request import runs
    Then the database answers "0" for:
      """
      select count(*) from pull_requests
      """
    And the "pull_requests" sync failure reads "github_failed"

  Scenario: A later import reads from a day before the last one, though nothing it holds has changed for weeks
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "search": {"issueCount": 1, "pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"number": 1, "title": "Import pull requests", "body": "", "url": "https://github.com/aaronmallen/aaronmallen.me/pull/1",
            "createdAt": "2026-10-01T12:00:00Z", "isDraft": false, "state": "OPEN", "mergedAt": null, "closedAt": null,
            "viewerDidAuthor": true, "repository": {"nameWithOwner": "aaronmallen/aaronmallen.me"},
            "timelineItems": {"nodes": []}}]}}}
      """
    And the pull request import runs
    And the database runs:
      """
      update pull_requests set updated_at = now() - interval '30 days';
      """
    And I note when the pull request import last read
    When the pull request import runs
    Then GitHub was asked for pull requests updated since a day before the noted read

  Scenario: A later import after a failed run keeps the floor at the last good run
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "search": {"issueCount": 1, "pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"number": 1, "title": "Import pull requests", "body": "", "url": "https://github.com/aaronmallen/aaronmallen.me/pull/1",
            "createdAt": "2026-10-01T12:00:00Z", "isDraft": false, "state": "OPEN", "mergedAt": null, "closedAt": null,
            "viewerDidAuthor": true, "repository": {"nameWithOwner": "aaronmallen/aaronmallen.me"},
            "timelineItems": {"nodes": []}}]}}}
      """
    And the pull request import runs
    And the database runs:
      """
      update sync_states set synced_at = now() - interval '5 days' where kind = 'pull_requests';
      """
    And GitHub answers POST "/graphql" with status 502
    And the pull request import runs
    And I note when the pull request import last read
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "search": {"issueCount": 1, "pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"number": 1, "title": "Import pull requests", "body": "", "url": "https://github.com/aaronmallen/aaronmallen.me/pull/1",
            "createdAt": "2026-10-01T12:00:00Z", "isDraft": false, "state": "OPEN", "mergedAt": null, "closedAt": null,
            "viewerDidAuthor": true, "repository": {"nameWithOwner": "aaronmallen/aaronmallen.me"},
            "timelineItems": {"nodes": []}}]}}}
      """
    When the pull request import runs
    Then GitHub was asked for pull requests updated since a day before the noted read
