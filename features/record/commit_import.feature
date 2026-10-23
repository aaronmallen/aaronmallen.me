@timeout:180000
Feature: The commit import
  The commit import lists the repositories I can push to, picks the ones pushed since it last read them or with a
  failure to retry, and starts a commit walk for each. It records how the run went under the commits sync.

  Background:
    Given the record jobs have a GitHub token

  Scenario: An empty commits table starts a walk for every repository, however long ago it was pushed
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"nameWithOwner": "aaronmallen/one", "pushedAt": "2015-01-01T00:00:00Z", "viewerPermission": "ADMIN"},
          {"nameWithOwner": "aaronmallen/aaronmallen.me", "pushedAt": null, "viewerPermission": "ADMIN"}]}}}}
      """
    When the commit import runs
    Then the commit walks waiting in the schedule are for "aaronmallen/one, aaronmallen/aaronmallen.me"
    And each commit walk waiting in the schedule runs on the import's clock
    And the commit walk for "aaronmallen/aaronmallen.me" stands at about now
    And GitHub was never asked for the query "refs(refPrefix:"
    And GitHub was asked for the query " affiliations: [OWNER, COLLABORATOR, ORGANIZATION_MEMBER]"
    And GitHub was asked for the query "ownerAffiliations: [OWNER, COLLABORATOR, ORGANIZATION_MEMBER]"

  Scenario: A commit import follows the listing to the next page
    Given GitHub answers POST "/graphql" next with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"repositories": {"pageInfo": {"hasNextPage": true, "endCursor": "repos-page-2"}, "nodes": [
          {"nameWithOwner": "aaronmallen/one", "pushedAt": "2026-08-01T00:00:00Z", "viewerPermission": "ADMIN"}]}}}}
      """
    And GitHub answers POST "/graphql" next with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"nameWithOwner": "aaronmallen/aaronmallen.me", "pushedAt": "2026-08-01T00:00:00Z", "viewerPermission": "ADMIN"}]}}}}
      """
    When the commit import runs
    Then the commit walks waiting in the schedule are for "aaronmallen/one, aaronmallen/aaronmallen.me"

  Scenario: A commit import stops at the page limit
    Given GitHub lists my repositories over 11 pages
    When the commit import runs
    Then GitHub was asked 10 times for the query "repositories("

  Scenario: A commit import skips a repository I can't push to and starts one I maintain
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"nameWithOwner": "someone/else", "pushedAt": "2026-08-01T00:00:00Z", "viewerPermission": "READ"},
          {"nameWithOwner": "org/one", "pushedAt": "2026-08-01T00:00:00Z", "viewerPermission": "MAINTAIN"}]}}}}
      """
    When the commit import runs
    Then the commit walks waiting in the schedule are for "org/one"

  Scenario: A commit import reads an answer GitHub does not send as JSON as no repositories
    Given GitHub answers POST "/graphql" with:
      """
      <html>maintenance</html>
      """
    When the commit import runs
    Then no commit walk waits in the schedule
    And the "commits" sync records no failure

  Scenario Outline: A commit import with commits stored <does> a repository pushed <when>
    Given the commit import stored a commit "2026-08-10T12:00:00Z"
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"nameWithOwner": "aaronmallen/aaronmallen.me", "pushedAt": <pushed>, "viewerPermission": "ADMIN"}]}}}}
      """
    When the commit import runs
    Then the commit walks waiting in the schedule are for "<walks>"

    Examples:
      | does   | when                                       | pushed                 | walks                      |
      | starts | since a day before the newest stored commit | "2026-08-09T13:00:00Z" | aaronmallen/aaronmallen.me |
      | skips  | before that                                | "2026-08-08T12:00:00Z" |                            |
      | skips  | never                                      | null                   |                            |

  Scenario: A commit import reads the window off the newest stored commit, not the oldest
    Given the commit import stored a commit "2026-08-10T12:00:00Z"
    And the commit import stored a commit "2026-07-01T12:00:00Z"
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"nameWithOwner": "aaronmallen/aaronmallen.me", "pushedAt": "2026-07-31T12:00:00Z", "viewerPermission": "ADMIN"}]}}}}
      """
    When the commit import runs
    Then no commit walk waits in the schedule

  Scenario: A commit import stops at the first repository outside the window, since GitHub sorts by push
    Given the commit import stored a commit "2026-08-10T12:00:00Z"
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"repositories": {"pageInfo": {"hasNextPage": true, "endCursor": "repos-page-2"}, "nodes": [
          {"nameWithOwner": "aaronmallen/aaronmallen.me", "pushedAt": "2026-08-09T15:00:00Z", "viewerPermission": "ADMIN"},
          {"nameWithOwner": "old/one", "pushedAt": "2020-01-01T00:00:00Z", "viewerPermission": "ADMIN"},
          {"nameWithOwner": "aaronmallen/one", "pushedAt": "2026-08-09T14:00:00Z", "viewerPermission": "ADMIN"}]}}}}
      """
    When the commit import runs
    Then the commit walks waiting in the schedule are for "aaronmallen/aaronmallen.me"

  Scenario Outline: A commit import starts a walk once for a repository with a failure, pushed <when>
    Given the commit import stored a commit "2026-08-10T12:00:00Z"
    And these sync failures:
      | sync    | repo                       | reason        |
      | commits | aaronmallen/aaronmallen.me | github_failed |
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"nameWithOwner": "aaronmallen/aaronmallen.me", "pushedAt": "<pushed>", "viewerPermission": "ADMIN"}]}}}}
      """
    When the commit import runs
    Then the commit walks waiting in the schedule are for "aaronmallen/aaronmallen.me"

    Examples:
      | when                | pushed               |
      | long before         | 2026-07-01T12:00:00Z |
      | inside the window   | 2026-08-09T15:00:00Z |

  Scenario: A failure that names no repository starts no walk
    Given the commit import stored a commit "2026-08-10T12:00:00Z"
    And these sync failures:
      | sync    | reason       |
      | commits | rate_limited |
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"nameWithOwner": "aaronmallen/aaronmallen.me", "pushedAt": "2026-07-01T12:00:00Z", "viewerPermission": "ADMIN"}]}}}}
      """
    When the commit import runs
    Then no commit walk waits in the schedule

  Scenario: A commit import starts no second walk for a repository whose walk is going
    Given the commit walk for "aaronmallen/aaronmallen.me" starts at "10 minutes ago"
    And these sync failures:
      | sync    | repo                       | reason        |
      | commits | aaronmallen/aaronmallen.me | github_failed |
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"nameWithOwner": "aaronmallen/aaronmallen.me", "pushedAt": "2099-01-01T00:00:00Z", "viewerPermission": "ADMIN"}]}}}}
      """
    When the commit import runs
    Then no commit walk waits in the schedule
    And the commit walk for "aaronmallen/aaronmallen.me" stands at "10 minutes ago"

  Scenario: A commit import starts a stalled walk again, pushed or not
    Given the commit walk for "aaronmallen/aaronmallen.me" starts at "10 minutes ago"
    And the commit walk for "aaronmallen/aaronmallen.me" last moved "3 hours ago"
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"nameWithOwner": "aaronmallen/aaronmallen.me", "pushedAt": null, "viewerPermission": "ADMIN"}]}}}}
      """
    When the commit import runs
    Then the commit walks waiting in the schedule are for "aaronmallen/aaronmallen.me"
    And the commit walk for "aaronmallen/aaronmallen.me" stands at about now

  Scenario: A first import fills an empty table with a repository's whole history
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"id": "MDQ6VXNlcjkzMTA5NA==", "repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null},
          "nodes": [{"nameWithOwner": "aaronmallen/aaronmallen.me", "pushedAt": "2026-08-01T00:00:00Z",
            "viewerPermission": "ADMIN"}]}},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
              {"oid": "aaaaaaa", "message": "lib: the newest", "authoredDate": "2026-07-31T12:00:00Z",
                "committedDate": "2026-07-31T12:00:00Z", "additions": 1, "deletions": 0},
              {"oid": "bbbbbbb", "message": "lib: the middle", "authoredDate": "2026-07-20T12:00:00Z",
                "committedDate": "2026-07-20T12:00:00Z", "additions": 1, "deletions": 0},
              {"oid": "ccccccc", "message": "lib: the oldest", "authoredDate": "2026-07-01T12:00:00Z",
                "committedDate": "2026-07-01T12:00:00Z", "additions": 1, "deletions": 0}]}}}]}}}}
      """
    When the commit import runs
    Then the database answers "aaaaaaa, bbbbbbb, ccccccc" for:
      """
      select string_agg(sha, ', ' order by sha) from commits where repo = 'aaronmallen/aaronmallen.me'
      """
    And the commit walk for "aaronmallen/aaronmallen.me" has ended
    And the commit import has read "aaronmallen/aaronmallen.me" through a day ago

  Scenario: An import after a push reads a commit twice into one row and tells the admin nothing
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"id": "MDQ6VXNlcjkzMTA5NA==", "repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null},
          "nodes": [{"nameWithOwner": "aaronmallen/aaronmallen.me", "pushedAt": "2026-08-01T00:00:00Z",
            "viewerPermission": "ADMIN"}]}},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
              {"oid": "aaaaaaa", "message": "lib: the newest", "authoredDate": "2026-07-31T12:00:00Z",
                "committedDate": "2026-07-31T12:00:00Z", "additions": 1, "deletions": 0},
              {"oid": "bbbbbbb", "message": "lib: the middle", "authoredDate": "2026-07-20T12:00:00Z",
                "committedDate": "2026-07-20T12:00:00Z", "additions": 1, "deletions": 0},
              {"oid": "ccccccc", "message": "lib: the oldest", "authoredDate": "2026-07-01T12:00:00Z",
                "committedDate": "2026-07-01T12:00:00Z", "additions": 1, "deletions": 0}]}}}]}}}}
      """
    And the commit import runs
    And I note the forward edge for "aaronmallen/aaronmallen.me"
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"id": "MDQ6VXNlcjkzMTA5NA==", "repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null},
          "nodes": [{"nameWithOwner": "aaronmallen/aaronmallen.me", "pushedAt": "2099-01-01T00:00:00Z",
            "viewerPermission": "ADMIN"}]}},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
              {"oid": "aaaaaaa", "message": "lib: the newest", "authoredDate": "2026-07-31T12:00:00Z",
                "committedDate": "2026-07-31T12:00:00Z", "additions": 1, "deletions": 0},
              {"oid": "bbbbbbb", "message": "lib: the middle", "authoredDate": "2026-07-20T12:00:00Z",
                "committedDate": "2026-07-20T12:00:00Z", "additions": 1, "deletions": 0},
              {"oid": "ccccccc", "message": "lib: the oldest", "authoredDate": "2026-07-01T12:00:00Z",
                "committedDate": "2026-07-01T12:00:00Z", "additions": 1, "deletions": 0}]}}}]}}}}
      """
    When the commit import runs while the admin listens
    Then the database answers "3" for:
      """
      select count(*) from commits
      """
    And the commit walk for "aaronmallen/aaronmallen.me" has ended
    And the admin hears of "nothing"
    And GitHub was asked for the commits since the noted forward edge

  Scenario Outline: An import after an earlier walk <does> the repository when <when>
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"id": "MDQ6VXNlcjkzMTA5NA==", "repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null},
          "nodes": [{"nameWithOwner": "aaronmallen/aaronmallen.me", "pushedAt": "2026-08-01T00:00:00Z",
            "viewerPermission": "ADMIN"}]}},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
              {"oid": "aaaaaaa", "message": "lib: the newest", "authoredDate": "2026-07-31T12:00:00Z",
                "committedDate": "2026-07-31T12:00:00Z", "additions": 1, "deletions": 0}]}}}]}}}}
      """
    And the commit import runs
    And the database runs:
      """
      <before>
      """
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"nameWithOwner": "aaronmallen/aaronmallen.me", "pushedAt": "<pushed>", "viewerPermission": "ADMIN"}]}}}}
      """
    When the commit import runs
    Then the commit walks waiting in the schedule are for "<walks>"

    Examples:
      | does   | when                                     | pushed               | before                                                                                                                                                         | walks                      |
      | skips  | no one pushed since its last walk began  | 2026-08-01T00:00:00Z | select 1                                                                                                                                                       |                            |
      | walks  | someone pushed after its last walk began | 2099-01-01T00:00:00Z | select 1                                                                                                                                                       | aaronmallen/aaronmallen.me |
      | walks  | it has a failure, though no one pushed   | 2026-08-01T00:00:00Z | insert into sync_states (kind, sync, repo, synced_at, failure_reason, failing_since, failure_count) values ('failure', 'commits', 'aaronmallen/aaronmallen.me', now(), 'github_failed', now(), 1) | aaronmallen/aaronmallen.me |

  Scenario: An import reads a repository made since the last one, with commits dated weeks before it
    Given the commit import stored a commit "10 minutes ago"
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"id": "MDQ6VXNlcjkzMTA5NA==", "repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null},
          "nodes": [{"nameWithOwner": "aaronmallen/one", "pushedAt": "2099-01-01T00:00:00Z", "viewerPermission": "ADMIN"}]}},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
              {"oid": "eeeeeee", "message": "lib: three weeks back", "authoredDate": "2026-09-01T12:00:00Z",
                "committedDate": "2026-09-01T12:00:00Z", "additions": 1, "deletions": 0},
              {"oid": "fffffff", "message": "lib: five weeks back", "authoredDate": "2026-08-20T12:00:00Z",
                "committedDate": "2026-08-20T12:00:00Z", "additions": 1, "deletions": 0}]}}}]}}}}
      """
    When the commit import runs
    Then the database answers "eeeeeee aaronmallen/one, fffffff aaronmallen/one" for:
      """
      select string_agg(sha || ' ' || repo, ', ' order by sha) from commits where sha in ('eeeeeee', 'fffffff')
      """

  Scenario: An import fills a repository whose walk failed, though nobody pushed to it
    Given the commit import stored a commit "10 minutes ago"
    And these sync failures:
      | sync    | repo                       | reason        |
      | commits | aaronmallen/aaronmallen.me | github_failed |
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"id": "MDQ6VXNlcjkzMTA5NA==", "repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null},
          "nodes": [{"nameWithOwner": "aaronmallen/aaronmallen.me", "pushedAt": "2026-01-01T00:00:00Z",
            "viewerPermission": "ADMIN"}]}},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
              {"oid": "aaaaaaa", "message": "lib: the newest", "authoredDate": "2026-07-31T12:00:00Z",
                "committedDate": "2026-07-31T12:00:00Z", "additions": 1, "deletions": 0},
              {"oid": "bbbbbbb", "message": "lib: the middle", "authoredDate": "2026-07-20T12:00:00Z",
                "committedDate": "2026-07-20T12:00:00Z", "additions": 1, "deletions": 0}]}}}]}}}}
      """
    When the commit import runs
    Then the database answers "aaaaaaa, bbbbbbb" for:
      """
      select string_agg(sha, ', ' order by sha) from commits where repo = 'aaronmallen/aaronmallen.me'
      """
    And the "commits" sync records no failure for "aaronmallen/aaronmallen.me"

  Scenario: A walk that fails is started again by the next import, which then has the missing commits
    Given the commit import stored a commit "10 minutes ago"
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"nameWithOwner": "aaronmallen/aaronmallen.me", "pushedAt": "2099-01-01T00:00:00Z", "viewerPermission": "ADMIN"}]}}}}
      """
    And the commit import runs
    And GitHub's points refill for the commit walk
    And GitHub answers POST "/graphql" with status 502
    And the waiting commit walk comes due
    And the "commits" sync failure for "aaronmallen/aaronmallen.me" reads "github_failed"
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"id": "MDQ6VXNlcjkzMTA5NA==", "repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null},
          "nodes": [{"nameWithOwner": "aaronmallen/aaronmallen.me", "pushedAt": "2026-01-01T00:00:00Z",
            "viewerPermission": "ADMIN"}]}},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
              {"oid": "aaaaaaa", "message": "lib: an old commit", "authoredDate": "2026-08-20T12:00:00Z",
                "committedDate": "2026-08-20T12:00:00Z", "additions": 1, "deletions": 0}]}}}]}}}}
      """
    When the commit import runs
    Then the database answers "aaronmallen/aaronmallen.me" for:
      """
      select repo from commits where sha = 'aaaaaaa'
      """
    And the "commits" sync records no failure for "aaronmallen/aaronmallen.me"

  Scenario: A commit import that finishes clears the sync's failure
    Given these sync failures:
      | sync    | reason       |
      | commits | rate_limited |
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": []}}}}
      """
    When the commit import runs
    Then the "commits" sync records no failure

  Scenario: A commit import GitHub rate limits records it and starts no walk
    Given these sync failures:
      | sync    | repo                       | reason        |
      | commits | aaronmallen/aaronmallen.me | github_failed |
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 0, "resetAt": "2099-01-01T00:00:00Z"}},
        "errors": [{"type": "RATE_LIMITED", "message": "API rate limit exceeded"}]}
      """
    When the commit import runs
    Then the "commits" sync failure reads "rate_limited"
    And no commit walk waits in the schedule
    And the commit walk for "aaronmallen/aaronmallen.me" has ended

  Scenario: A commit import records what GitHub answered and counts each failed run
    Given GitHub answers POST "/graphql" with status 502
    When the commit import runs
    And the commit import runs
    Then the "commits" sync failure reads "github_failed"
    And the "commits" sync failure says "GitHub answered 502 for GraphQL"
    And the "commits" sync has failed 2 times

  Scenario: A commit import keeps the token out of the failure
    Given GitHub answers POST "/graphql" with status 500
    When the commit import runs
    Then the "commits" sync failure leaves out the GitHub token

  Scenario: A commit import with no GitHub token records the sync that never ran and asks GitHub for nothing
    Given the record jobs lose their GitHub token
    When the commit import runs
    Then the "commits" sync failure reads "not_configured"
    And no commit walk waits in the schedule

  Scenario: A commit import leaves the run to the one holding the lock and reports nothing
    Given these sync failures:
      | sync    | reason       |
      | commits | rate_limited |
    When the commit import runs while another run holds its lock
    Then the "commits" sync failure reads "rate_limited"
    And the "commits" sync has failed 1 time

  Scenario: A commit import that crashes records the crash and still fails the job
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "viewer": {"repositories": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
          {"pushedAt": "2026-08-01T00:00:00Z", "viewerPermission": "ADMIN"}]}}}}
      """
    When the commit import runs
    Then the "commits" sync failure reads "crashed"
    And the "commits" sync failure says "key not found: \"nameWithOwner\""
    And the record job "Record::Jobs::ImportCommits" failed with a KeyError

  Scenario: A commit import whose connection to GitHub times out says the request failed
    Given GitHub never answers POST "/graphql"
    When the commit import runs
    Then the "commits" sync failure reads "github_failed"
    And the "commits" sync failure says something starting with "GitHub GraphQL request failed: "
