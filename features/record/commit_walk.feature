@timeout:180000
Feature: The commit walk
  The commit walk reads one repository's history back from its back edge, a chunk at a time, stores each commit
  it finds, and moves the forward edge once it has read all it has to.

  Background:
    Given the record jobs have a GitHub token
    And the commit walk for "aaronmallen/aaronmallen.me" starts at "2026-08-18T15:00:00Z"

  Scenario: A chunk of history stores what it reads and moves the back edge
    Given these sync failures:
      | sync    | repo                       | reason        |
      | commits | aaronmallen/aaronmallen.me | github_failed |
      | commits | aaronmallen/other          | github_failed |
    And the commit walk for "aaronmallen/aaronmallen.me" last moved "3 days ago"
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": true, "endCursor": "main-page-2"},
              "nodes": [{"oid": "aaaaaaa", "message": "lib: an older commit", "authoredDate": "2026-08-10T14:30:00Z",
                "committedDate": "2026-08-10T14:30:00Z", "additions": 12, "deletions": 3}]}}}]}}}}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the database answers "main, lib: an older commit, aaronmallen/aaronmallen.me, 12, 3, 2026-08-10, 09:30:00" for:
      """
      select branch, message, repo, additions, deletions, commit_date::text, commit_time::text
      from commits where sha = 'aaaaaaa'
      """
    And the commit walk for "aaronmallen/aaronmallen.me" stands at "2026-08-10T14:30:00Z"
    And the commit walk for "aaronmallen/aaronmallen.me" last moved just now
    And the commit import has not read "aaronmallen/aaronmallen.me"
    And the commit walk for "aaronmallen/aaronmallen.me" waits in the schedule on the clock "2026-08-20T12:00:00Z"
    And the "commits" sync records no failure for "aaronmallen/aaronmallen.me"
    And the "commits" sync failure for "aaronmallen/other" reads "github_failed"
    And GitHub was asked 1 time for the query "refs(refPrefix:"
    And GitHub was asked for the query "refs(refPrefix:" with the variables:
      """
      {"until": "2026-08-18T15:00:00Z"}
      """
    And GitHub was never asked for the query "repositories("
    And every GraphQL request to GitHub carried the record jobs' token as JSON

  Scenario: A rebased commit keeps the day it was written and its whole message
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null},
              "nodes": [{"oid": "bbbbbbb", "message": "lib: a rebased commit\n\nand say why\n",
                "authoredDate": "2026-07-21T15:20:13Z", "committedDate": "2026-08-10T04:49:21Z",
                "additions": 1, "deletions": 0}]}}}]}}}}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the database answers "2026-07-21, true" for:
      """
      select commit_date::text, message = E'lib: a rebased commit\n\nand say why' from commits
      """

  Scenario: A walk ends once a step would pass the forward edge, and tells the admin nothing
    Given the commit import read "aaronmallen/aaronmallen.me" through "2026-08-01T09:00:00Z"
    And the commit walk for "aaronmallen/aaronmallen.me" starts at "2026-08-01T10:00:00Z"
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [{"name": "main", "target": {}}]}}}}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me" while the admin listens
    Then the commit walk for "aaronmallen/aaronmallen.me" has ended
    And the commit import has read "aaronmallen/aaronmallen.me" through "2026-08-19T12:00:00Z"
    And the admin hears of "nothing"
    And GitHub was asked for the query "refs(refPrefix:" with the variables:
      """
      {"since": "2026-08-01T09:00:00Z"}
      """

  Scenario: A walk steps back an hour while the forward edge is still below
    Given the commit import read "aaronmallen/aaronmallen.me" through "2026-08-01T09:00:00Z"
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [{"name": "main", "target": {}}]}}}}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the commit walk for "aaronmallen/aaronmallen.me" stands at "2026-08-18T14:00:00Z"

  Scenario: A walk waits for GitHub's points before it reads under the forward edge, then finds a branch pushed late
    Given the commit import read "aaronmallen/aaronmallen.me" through "2026-08-12T09:00:00Z"
    And the commit "bbbbbbb" is already stored on the branch "main"
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 1000, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null},
              "nodes": [{"oid": "aaaaaaa", "message": "lib: a newer commit", "authoredDate": "2026-08-15T09:00:00Z",
                "committedDate": "2026-08-15T09:00:00Z", "additions": 1, "deletions": 0}]}}}]}}}}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the commit walk for "aaronmallen/aaronmallen.me" stands at "2026-08-12T09:00:00Z"
    And the commit walk waits in the schedule until "2099-01-01T00:00:00Z"
    And the database answers "aaaaaaa, bbbbbbb" for:
      """
      select string_agg(sha, ', ' order by sha) from commits
      """
    When GitHub's points refill for the commit walk
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null},
              "nodes": [{"oid": "bbbbbbb", "message": "lib: an older commit", "authoredDate": "2026-08-10T14:30:00Z",
                "committedDate": "2026-08-10T14:30:00Z", "additions": 1, "deletions": 0}]}}},
            {"name": "topic", "target": {"history": {"pageInfo": {"hasNextPage": true, "endCursor": "topic-page-2"},
              "nodes": [{"oid": "ccccccc", "message": "lib: a late commit", "authoredDate": "2026-08-10T14:30:00Z",
                "committedDate": "2026-08-10T14:30:00Z", "additions": 1, "deletions": 0},
                {"oid": "bbbbbbb", "message": "lib: an older commit", "authoredDate": "2026-08-10T14:30:00Z",
                "committedDate": "2026-08-10T14:30:00Z", "additions": 1, "deletions": 0}]}}}]}}}}
      """
    And the waiting commit walk comes due
    Then the database answers "topic, aaronmallen/aaronmallen.me" for:
      """
      select branch, repo from commits where sha = 'ccccccc'
      """
    And the commit walk for "aaronmallen/aaronmallen.me" has ended
    And the commit import has read "aaronmallen/aaronmallen.me" through "2026-08-19T12:00:00Z"
    And no commit walk waits in the schedule

  Scenario: A walk under the forward edge keeps reading while a branch has only new commits
    Given the commit import read "aaronmallen/aaronmallen.me" through "2026-08-12T09:00:00Z"
    And the commit walk for "aaronmallen/aaronmallen.me" starts at "2026-08-12T09:00:00Z"
    And the commit "bbbbbbb" is already stored on the branch "main"
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null},
              "nodes": [{"oid": "bbbbbbb", "message": "lib: an older commit", "authoredDate": "2026-08-10T14:30:00Z",
                "committedDate": "2026-08-10T14:30:00Z", "additions": 1, "deletions": 0}]}}},
            {"name": "topic", "target": {"history": {"pageInfo": {"hasNextPage": true, "endCursor": "topic-page-2"},
              "nodes": [{"oid": "ccccccc", "message": "lib: a late commit", "authoredDate": "2026-08-05T09:00:00Z",
                "committedDate": "2026-08-05T09:00:00Z", "additions": 1, "deletions": 0}]}}}]}}}}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the commit walk for "aaronmallen/aaronmallen.me" stands at "2026-08-05T09:00:00Z"
    And the commit import has read "aaronmallen/aaronmallen.me" through "2026-08-12T09:00:00Z"
    And the commit walk for "aaronmallen/aaronmallen.me" waits in the schedule on the clock "2026-08-20T12:00:00Z"
    When GitHub's points refill for the commit walk
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "topic", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null},
              "nodes": [{"oid": "eeeeeee", "message": "lib: a deeper commit", "authoredDate": "2026-08-02T09:00:00Z",
                "committedDate": "2026-08-02T09:00:00Z", "additions": 1, "deletions": 0},
                {"oid": "bbbbbbb", "message": "lib: an older commit", "authoredDate": "2026-08-10T14:30:00Z",
                "committedDate": "2026-08-10T14:30:00Z", "additions": 1, "deletions": 0}]}}}]}}}}
      """
    And the waiting commit walk comes due
    Then the database answers "topic" for:
      """
      select branch from commits where sha = 'eeeeeee'
      """
    And the commit walk for "aaronmallen/aaronmallen.me" has ended
    And GitHub was asked for the query "refs(refPrefix:" with the variables:
      """
      {"since": null, "until": "2026-08-05T09:00:00Z"}
      """

  Scenario: A walk under the forward edge reads again after GitHub rate limits it
    Given the commit import read "aaronmallen/aaronmallen.me" through "2026-08-12T09:00:00Z"
    And the commit walk for "aaronmallen/aaronmallen.me" starts at "2026-08-12T09:00:00Z"
    And the commit "bbbbbbb" is already stored on the branch "main"
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"}},
        "errors": [{"type": "RATE_LIMITED", "message": "API rate limit exceeded"}]}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the commit walk waits in the schedule until "2099-01-01T00:00:00Z"
    When GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "topic", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null},
              "nodes": [{"oid": "ccccccc", "message": "lib: a late commit", "authoredDate": "2026-08-10T14:30:00Z",
                "committedDate": "2026-08-10T14:30:00Z", "additions": 1, "deletions": 0},
                {"oid": "bbbbbbb", "message": "lib: an older commit", "authoredDate": "2026-08-10T14:30:00Z",
                "committedDate": "2026-08-10T14:30:00Z", "additions": 1, "deletions": 0}]}}}]}}}}
      """
    And the waiting commit walk comes due
    Then the database answers "topic" for:
      """
      select branch from commits where sha = 'ccccccc'
      """

  Scenario: A rebased commit last on a cut page sets the back edge by its commit date
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": true, "endCursor": "main-page-2"},
              "nodes": [{"oid": "ddddddd", "message": "lib: a newer commit", "authoredDate": "2026-08-15T14:30:00Z",
                "committedDate": "2026-08-15T14:30:00Z", "additions": 1, "deletions": 0},
                {"oid": "aaaaaaa", "message": "lib: a rebased commit", "authoredDate": "2026-08-01T14:30:00Z",
                "committedDate": "2026-08-12T14:30:00Z", "additions": 1, "deletions": 0}]}}}]}}}}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the commit walk for "aaronmallen/aaronmallen.me" stands at "2026-08-12T14:30:00Z"
    When GitHub's points refill for the commit walk
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null},
              "nodes": [{"oid": "ccccccc", "message": "lib: a commit in between", "authoredDate": "2026-08-06T14:30:00Z",
                "committedDate": "2026-08-06T14:30:00Z", "additions": 1, "deletions": 0}]}}}]}}}}
      """
    And the waiting commit walk comes due
    Then the database answers "main" for:
      """
      select branch from commits where sha = 'ccccccc'
      """

  Scenario: A walk to the end moves the forward edge, leaves other repositories alone and asks for nothing after
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null},
              "nodes": [{"oid": "aaaaaaa", "message": "lib: an older commit", "authoredDate": "2026-08-10T14:30:00Z",
                "committedDate": "2026-08-10T14:30:00Z", "additions": 12, "deletions": 3}]}}}]}}}}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the commit import has read "aaronmallen/aaronmallen.me" through "2026-08-19T12:00:00Z"
    And the commit walk for "aaronmallen/aaronmallen.me" has ended
    And no commit walk waits in the schedule
    And the commit import has not read "aaronmallen/other"
    And GitHub was asked for the query "refs(refPrefix:" with the variables:
      """
      {"since": null}
      """
    When GitHub answers POST "/graphql" with status 500
    And the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the "commits" sync records no failure for "aaronmallen/aaronmallen.me"

  Scenario: A chunk whose commits all share the edge's second moves the edge down a second
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": true, "endCursor": "main-page-2"},
              "nodes": [{"oid": "aaaaaaa", "message": "lib: a commit on the edge", "authoredDate": "2026-08-18T15:00:00Z",
                "committedDate": "2026-08-18T15:00:00Z", "additions": 1, "deletions": 0}]}}}]}}}}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the commit walk for "aaronmallen/aaronmallen.me" stands at "2026-08-18T14:59:59Z"

  Scenario: A full page of commits at one second follows the branch past the page
    Given GitHub lists 100 commits on the branch "main" all committed at "2026-08-18T15:00:00Z", and 50 more at that second on the next page
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the database answers "150" for:
      """
      select count(*) from commits
      """
    And the commit walk for "aaronmallen/aaronmallen.me" has ended
    And GitHub was asked for the query "ref(qualifiedName:" with the variables:
      """
      {"cursor": "main-page-2", "ref": "refs/heads/main", "until": "2026-08-18T15:00:00Z"}
      """

  Scenario: A full page of commits at one second stops following once a page moves past that second
    Given GitHub lists 100 commits on the branch "main" all committed at "2026-08-18T15:00:00Z", then 50 more at that second and one at "2026-08-17T15:00:00Z", with 999 points left
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then GitHub was asked 1 time for the query "ref(qualifiedName:"
    And the commit walk for "aaronmallen/aaronmallen.me" stands at "2026-08-17T15:00:00Z"

  Scenario: A branch whose page came back empty steps back an hour and walks on
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": true, "endCursor": "main-page-2"},
              "nodes": []}}}]}}}}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the commit walk for "aaronmallen/aaronmallen.me" stands at "2026-08-18T14:00:00Z"
    And the commit walk for "aaronmallen/aaronmallen.me" waits in the schedule on the clock "2026-08-20T12:00:00Z"

  Scenario: A branch GitHub sent no history for keeps the walk going
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [{"name": "main", "target": {}}]}}}}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the commit import has not read "aaronmallen/aaronmallen.me"
    And the commit walk for "aaronmallen/aaronmallen.me" waits in the schedule on the clock "2026-08-20T12:00:00Z"

  Scenario: A walk back to the day the repository was made ends and names the branch it never read
    Given these sync failures:
      | sync    | repo                       | reason        |
      | commits | aaronmallen/aaronmallen.me | github_failed |
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": "2026-08-18T14:00:00Z", "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [{"name": "main", "target": {}}]}}}}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the commit walk for "aaronmallen/aaronmallen.me" has ended
    And the commit import has read "aaronmallen/aaronmallen.me" through "2026-08-19T12:00:00Z"
    And no commit walk waits in the schedule
    And the "commits" sync failure for "aaronmallen/aaronmallen.me" reads "repository_start"
    And the "commits" sync failure for "aaronmallen/aaronmallen.me" says "main still unread"
    And the "commits" sync failure for "aaronmallen/aaronmallen.me" has failed 1 time, starting just now
    When GitHub answers POST "/graphql" with status 500
    And the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the "commits" sync failure for "aaronmallen/aaronmallen.me" reads "repository_start"

  Scenario: A walk back to the day the repository was made stores what it read on the way
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": "2026-08-18T14:00:00Z", "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null},
              "nodes": [{"oid": "aaaaaaa", "message": "lib: an older commit", "authoredDate": "2026-08-10T14:30:00Z",
                "committedDate": "2026-08-10T14:30:00Z", "additions": 1, "deletions": 0}]}}},
            {"name": "topic", "target": {}}]}}}}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the database answers "main" for:
      """
      select branch from commits where sha = 'aaaaaaa'
      """
    And the "commits" sync failure for "aaronmallen/aaronmallen.me" says "topic still unread"

  Scenario: A repository still above the day it was made keeps walking and records nothing
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": "2019-04-02T08:15:00Z", "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [{"name": "main", "target": {}}]}}}}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the commit walk for "aaronmallen/aaronmallen.me" waits in the schedule on the clock "2026-08-20T12:00:00Z"
    And the "commits" sync records no failure for "aaronmallen/aaronmallen.me"

  Scenario: A walk over two branches stops at the shallower one
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": true, "endCursor": "main-page-2"},
              "nodes": [{"oid": "aaaaaaa", "message": "lib: an older commit", "authoredDate": "2026-08-10T14:30:00Z",
                "committedDate": "2026-08-10T14:30:00Z", "additions": 1, "deletions": 0}]}}},
            {"name": "topic", "target": {"history": {"pageInfo": {"hasNextPage": true, "endCursor": "topic-page-2"},
              "nodes": [{"oid": "bbbbbbb", "message": "lib: a topic commit", "authoredDate": "2026-08-15T09:00:00Z",
                "committedDate": "2026-08-15T09:00:00Z", "additions": 1, "deletions": 0}]}}}]}}}}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the commit walk for "aaronmallen/aaronmallen.me" stands at "2026-08-15T09:00:00Z"

  Scenario Outline: A commit on two branches lands once, under the default branch or else the first it came on
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": <default>,
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "topic", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null},
              "nodes": [{"oid": "aaaaaaa", "message": "lib: on both", "authoredDate": "2026-08-10T14:30:00Z",
                "committedDate": "2026-08-10T14:30:00Z", "additions": 1, "deletions": 0}]}}},
            {"name": "<other>", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null},
              "nodes": [{"oid": "aaaaaaa", "message": "lib: on both", "authoredDate": "2026-08-10T14:30:00Z",
                "committedDate": "2026-08-10T14:30:00Z", "additions": 1, "deletions": 0}]}}}]}}}}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the database answers "1, <branch>" for:
      """
      select count(*), min(branch) from commits
      """

    Examples:
      | default           | other | branch |
      | {"name": "trunk"} | trunk | trunk  |
      | null              | main  | topic  |

  Scenario: A commit read twice keeps the one row it first wrote
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null},
              "nodes": [{"oid": "aaaaaaa", "message": "lib: an older commit", "authoredDate": "2026-08-10T14:30:00Z",
                "committedDate": "2026-08-10T14:30:00Z", "additions": 1, "deletions": 0}]}}}]}}}}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    And the database runs:
      """
      update commits set updated_at = '2026-01-01T00:00:00Z';
      """
    And the commit walk for "aaronmallen/aaronmallen.me" starts at "2026-08-18T15:00:00Z"
    And the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the database answers "1, true" for:
      """
      select count(*), bool_and(updated_at = '2026-01-01T00:00:00Z') from commits
      """
    And GitHub was asked 1 time for the query "viewer { id }"
    And GitHub was asked 2 times for the query "refs(refPrefix:"
    And GitHub was asked for the query "refs(refPrefix:" with the variables:
      """
      {"author": "MDQ6VXNlcjkzMTA5NA=="}
      """

  Scenario: A commit already stored on another branch keeps its first branch and message
    Given the commit "aaaaaaa" is already stored on the branch "topic"
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null},
              "nodes": [{"oid": "aaaaaaa", "message": "lib: an older commit\n\nand say why",
                "authoredDate": "2026-08-10T14:30:00Z", "committedDate": "2026-08-10T14:30:00Z",
                "additions": 1, "deletions": 0}]}}}]}}}}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the database answers "topic, lib: an older commit" for:
      """
      select branch, message from commits
      """

  Scenario Outline: A commit that closes an issue a task came from credits the agent its trailer names
    Given a task came from the GitHub issue "<issue>"
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null},
              "nodes": [{"oid": "aaaaaaa", "message": "<message>", "authoredDate": "2026-08-10T14:30:00Z",
                "committedDate": "2026-08-10T14:30:00Z", "additions": 1, "deletions": 0}]}}}]}}}}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the database answers "<credits>" for:
      """
      select coalesce(string_agg(concat_ws(' ', kind, agent, model), ', '), 'none') from task_contributors
      """

    Examples:
      | issue                                                   | message                                                                                                                            | credits                           |
      | https://github.com/aaronmallen/aaronmallen.me/issues/42 | app: credit the agent\\n\\nCo-Authored-By: Claude Opus 5.5 <noreply@example.com>\\n\\nCloses #42                                       | agent claude-code claude-opus-5-5 |
      | https://github.com/aaronmallen/aaronmallen.me/issues/42 | app: credit the agent\\n\\nco-authored-by: Claude Opus 5.5 <noreply@example.com>\\n\\nCloses #42                                       | agent claude-code claude-opus-5-5 |
      | https://github.com/aaronmallen/aaronmallen.me/issues/42 | app: credit nobody\\n\\nCloses #42                                                                                                   | none                              |
      | https://github.com/aaronmallen/aaronmallen.me/issues/42 | app: credit nobody\\n\\nCo-Authored-By: Pat Doe <pat@example.com>\\nCo-Authored-By: Claude <noreply@example.com>\\n\\nCloses #42         | none                              |
      | https://github.com/aaronmallen/aaronmallen.me/issues/42 | app: credit nobody\\n\\nCo-Authored-By: Claude Opus 5.5 <noreply@example.com>\\n\\nSee #42                                             | none                              |
      | https://github.com/aaronmallen/aaronmallen.me/issues/42 | app: credit nobody\\n\\nCo-Authored-By: Claude Opus 5.5 <noreply@example.com>\\n\\nCloses #43                                          | none                              |
      | https://github.com/AaronMallen/AaronMallen.me/issues/42 | app: credit the agent\\n\\nCo-Authored-By: Claude Opus 5.5 <noreply@example.com>\\n\\nCloses #42                                       | agent claude-code claude-opus-5-5 |
      | https://github.com/aaronmallen/other/issues/42          | app: credit nobody\\n\\nCo-Authored-By: Claude Opus 5.5 <noreply@example.com>\\n\\nCloses #42                                          | none                              |

  Scenario: A commit read twice credits its agent once, and keeps off one the owner removed
    Given a task came from the GitHub issue "https://github.com/aaronmallen/aaronmallen.me/issues/42"
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null},
              "nodes": [{"oid": "aaaaaaa",
                "message": "app: credit the agent\n\nCo-Authored-By: Claude Opus 5.5 <noreply@example.com>\n\nCloses #42",
                "authoredDate": "2026-08-10T14:30:00Z", "committedDate": "2026-08-10T14:30:00Z",
                "additions": 1, "deletions": 0}]}}}]}}}}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    And the commit walk for "aaronmallen/aaronmallen.me" starts at "2026-08-18T15:00:00Z"
    And the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the database answers "1" for:
      """
      select count(*) from task_contributors
      """
    When the database runs:
      """
      delete from task_contributors;
      """
    And the commit walk for "aaronmallen/aaronmallen.me" starts at "2026-08-18T15:00:00Z"
    And the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the database answers "0" for:
      """
      select count(*) from task_contributors
      """

  Scenario: Two commits that name one agent credit it once
    Given a task came from the GitHub issue "https://github.com/aaronmallen/aaronmallen.me/issues/42"
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null},
              "nodes": [{"oid": "aaaaaaa",
                "message": "app: one\n\nCo-Authored-By: Claude Opus 5.5 <noreply@example.com>\n\nCloses #42",
                "authoredDate": "2026-08-10T14:30:00Z", "committedDate": "2026-08-10T14:30:00Z",
                "additions": 1, "deletions": 0},
                {"oid": "bbbbbbb",
                "message": "app: two\n\nCo-Authored-By: Claude Opus 5.5 <noreply@example.com>\n\nCloses #42",
                "authoredDate": "2026-08-10T14:00:00Z", "committedDate": "2026-08-10T14:00:00Z",
                "additions": 1, "deletions": 0}]}}}]}}}}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the database answers "1" for:
      """
      select count(*) from task_contributors
      """

  Scenario: An empty repository stores nothing and ends the walk
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": null,
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": []}}}}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the database answers "0" for:
      """
      select count(*) from commits
      """
    And the commit walk for "aaronmallen/aaronmallen.me" has ended

  Scenario Outline: A repository GitHub answers <type> for stores nothing and records no failure
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"}, "repository": null},
        "errors": [{"type": "<type>", "message": "GitHub said no"}]}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the database answers "0" for:
      """
      select count(*) from commits
      """
    And the "commits" sync records no failure for "aaronmallen/aaronmallen.me"

    Examples:
      | type      |
      | NOT_FOUND |
      | FORBIDDEN |

  Scenario: An answer GitHub does not send as JSON reads as an empty repository
    Given the commit walk for "aaronmallen/other" starts at "2026-08-18T15:00:00Z"
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": null,
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": []}}}}
      """
    And the commit walk runs for "aaronmallen/other"
    And GitHub answers POST "/graphql" with:
      """
      <html>maintenance</html>
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the database answers "0" for:
      """
      select count(*) from commits
      """
    And the commit walk for "aaronmallen/aaronmallen.me" has ended
    And the "commits" sync records no failure for "aaronmallen/aaronmallen.me"

  Scenario: A walk reads once, then waits while GitHub's points sit under the reserve
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": true, "endCursor": "main-page-2"},
              "nodes": [{"oid": "aaaaaaa", "message": "lib: an older commit", "authoredDate": "2026-08-10T14:30:00Z",
                "committedDate": "2026-08-10T14:30:00Z", "additions": 1, "deletions": 0}]}}}]}}}}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the commit walk for "aaronmallen/aaronmallen.me" stands at "2026-08-10T14:30:00Z"
    And the commit walk waits in the schedule until "2099-01-01T00:00:00Z"

  Scenario: A chunk GitHub rate limits waits for the reset GitHub names, and changes nothing
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 0, "resetAt": "2099-06-01T00:00:00Z"}},
        "errors": [{"type": "RATE_LIMITED", "message": "API rate limit exceeded"}]}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the commit walk waits in the schedule until "2099-06-01T00:00:00Z"
    And the commit walk for "aaronmallen/aaronmallen.me" stands at "2026-08-18T15:00:00Z"
    And the database answers "0" for:
      """
      select count(*) from commits
      """
    And the "commits" sync records no failure for "aaronmallen/aaronmallen.me"

  Scenario Outline: A chunk GitHub rate limits waits a minute when <when>
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": <limit>}, "errors": [{"type": "RATE_LIMITED", "message": "API rate limit exceeded"}]}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the commit walk waits in the schedule for about a minute

    Examples:
      | when                         | limit                                                            |
      | GitHub names no reset time   | {"limit": 5000, "remaining": 0}                                  |
      | the reset time has gone past | {"limit": 5000, "remaining": 0, "resetAt": "2020-01-01T00:00:00Z"} |

  Scenario: A chunk GitHub answers 502 for records the error against the repository and ends the walk
    Given GitHub answers POST "/graphql" with status 502
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the "commits" sync failure for "aaronmallen/aaronmallen.me" reads "github_failed"
    And the "commits" sync failure for "aaronmallen/aaronmallen.me" says "GitHub answered 502 for GraphQL"
    And the commit walk for "aaronmallen/aaronmallen.me" has ended
    And no commit walk waits in the schedule

  Scenario: A chunk GitHub refuses without a rate limit records an error
    Given GitHub answers POST "/graphql" with status 403
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the "commits" sync failure for "aaronmallen/aaronmallen.me" reads "github_failed"

  Scenario: A chunk whose answer reports an error records it
    Given GitHub answers POST "/graphql" with:
      """
      {"data": null, "errors": [{"type": "INTERNAL", "message": "something broke"}]}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the "commits" sync failure for "aaronmallen/aaronmallen.me" reads "github_failed"

  Scenario: An answer with no viewer records the failure and ends the walk
    Given GitHub answers POST "/graphql" with:
      """
      <html>maintenance</html>
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the "commits" sync failure for "aaronmallen/aaronmallen.me" reads "github_failed"
    And the "commits" sync failure for "aaronmallen/aaronmallen.me" says "GitHub sent no viewer id"
    And the commit walk for "aaronmallen/aaronmallen.me" has ended
    And GitHub was never asked for the query "refs(refPrefix:"

  Scenario: A repository with no walk going asks GitHub for nothing
    When the commit walk runs for "aaronmallen/unwalked"
    Then no commit walk waits in the schedule
    And the commit walk for "aaronmallen/aaronmallen.me" stands at "2026-08-18T15:00:00Z"

  Scenario: A walk with no GitHub token asks GitHub for nothing
    Given the record jobs lose their GitHub token
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then no commit walk waits in the schedule
    And the commit walk for "aaronmallen/aaronmallen.me" stands at "2026-08-18T15:00:00Z"

  Scenario: A next chunk walks back from the edge the last chunk left
    Given GitHub answers POST "/graphql" with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="}, "rateLimit": {"limit": 5000, "remaining": 999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": true, "endCursor": "main-page-2"},
              "nodes": [{"oid": "aaaaaaa", "message": "lib: a commit", "authoredDate": "2026-08-10T14:30:00Z",
                "committedDate": "2026-08-10T14:30:00Z", "additions": 1, "deletions": 0}]}}}]}}}}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    And GitHub's points refill for the commit walk
    And GitHub answers POST "/graphql" with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null},
              "nodes": [{"oid": "aaaaaaa", "message": "lib: a commit", "authoredDate": "2026-08-10T14:30:00Z",
                "committedDate": "2026-08-10T14:30:00Z", "additions": 1, "deletions": 0}]}}}]}}}}
      """
    And the waiting commit walk comes due
    Then GitHub was asked for the query "refs(refPrefix:" with the variables:
      """
      {"until": "2026-08-10T14:30:00Z"}
      """

  Scenario: A walk follows the branch listing past its first page with the cursor GitHub sent
    Given GitHub answers POST "/graphql" next with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"}}}
      """
    And GitHub answers POST "/graphql" next with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": true, "endCursor": "refs-page-2"}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null},
              "nodes": [{"oid": "aaaaaaa", "message": "lib: a commit", "authoredDate": "2026-08-10T14:30:00Z",
                "committedDate": "2026-08-10T14:30:00Z", "additions": 1, "deletions": 0}]}}}]}}}}
      """
    And GitHub answers POST "/graphql" next with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": false, "endCursor": null}, "nodes": [
            {"name": "topic", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null},
              "nodes": [{"oid": "bbbbbbb", "message": "lib: a commit", "authoredDate": "2026-08-10T14:30:00Z",
                "committedDate": "2026-08-10T14:30:00Z", "additions": 1, "deletions": 0}]}}}]}}}}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the database answers "topic" for:
      """
      select branch from commits where sha = 'bbbbbbb'
      """
    And GitHub was asked for the query "refs(refPrefix:" with the variables:
      """
      {"cursor": "refs-page-2"}
      """

  Scenario: A walk keeps what it read from a branch listing that goes mid-read
    Given GitHub answers POST "/graphql" next with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"}}}
      """
    And GitHub answers POST "/graphql" next with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": true, "endCursor": "refs-page-2"}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null},
              "nodes": [{"oid": "aaaaaaa", "message": "lib: a commit", "authoredDate": "2026-08-10T14:30:00Z",
                "committedDate": "2026-08-10T14:30:00Z", "additions": 1, "deletions": 0}]}}}]}}}}
      """
    And GitHub answers POST "/graphql" next with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"}, "repository": null},
        "errors": [{"type": "NOT_FOUND", "message": "Could not resolve to a Repository"}]}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the database answers "main" for:
      """
      select branch from commits where sha = 'aaaaaaa'
      """

  Scenario: A walk stores nothing when a later page fails, and leaves the forward edge alone
    Given GitHub answers POST "/graphql" next with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"}}}
      """
    And GitHub answers POST "/graphql" next with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": true, "endCursor": "refs-page-2"}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": false, "endCursor": null},
              "nodes": [{"oid": "aaaaaaa", "message": "lib: a commit", "authoredDate": "2026-08-10T14:30:00Z",
                "committedDate": "2026-08-10T14:30:00Z", "additions": 1, "deletions": 0}]}}}]}}}}
      """
    And GitHub answers the record jobs next with status 502
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the database answers "0" for:
      """
      select count(*) from commits
      """
    And the commit import has not read "aaronmallen/aaronmallen.me"
    And the "commits" sync failure for "aaronmallen/aaronmallen.me" says "GitHub answered 502 for GraphQL"

  Scenario: A walk keeps the last budget it saw when GitHub reports none
    Given GitHub answers POST "/graphql" next with:
      """
      {"data": {"viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="},
        "rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2099-01-01T00:00:00Z"}}}
      """
    And GitHub answers POST "/graphql" next with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 999, "resetAt": "2099-01-01T00:00:00Z"},
        "repository": {"createdAt": null, "defaultBranchRef": {"name": "main"},
          "refs": {"pageInfo": {"hasNextPage": true, "endCursor": "refs-page-2"}, "nodes": [
            {"name": "main", "target": {"history": {"pageInfo": {"hasNextPage": true, "endCursor": "main-page-2"},
              "nodes": [{"oid": "aaaaaaa", "message": "lib: a commit", "authoredDate": "2026-08-10T14:30:00Z",
                "committedDate": "2026-08-10T14:30:00Z", "additions": 1, "deletions": 0}]}}}]}}}}
      """
    And GitHub answers POST "/graphql" next with:
      """
      {"data": {"rateLimit": {}, "repository": null}}
      """
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then GitHub was asked 2 times for the query "refs(refPrefix:"
    And the commit walk waits in the schedule until "2099-01-01T00:00:00Z"

  Scenario: A chunk GitHub asks to wait for is put off
    Given GitHub answers POST "/graphql" with status 429 and the headers:
      | Retry-After | 60 |
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the commit walk waits in the schedule for about a minute
    And the "commits" sync records no failure for "aaronmallen/aaronmallen.me"

  Scenario: A chunk whose connection to GitHub times out records the error
    Given GitHub never answers POST "/graphql"
    When the commit walk runs for "aaronmallen/aaronmallen.me"
    Then the "commits" sync failure for "aaronmallen/aaronmallen.me" reads "github_failed"
