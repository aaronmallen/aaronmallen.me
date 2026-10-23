Feature: API commits, pull requests, syncs and tokens
  The API lists commits and pull requests in a window, queues a commit import, and reads the sync state and tokens.

  Background:
    Given an API token with the scopes "read write"

  Scenario: Listing commits answers the window's commits, newest first, with a 200
    Given the database runs:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time) values
        ('older', 'aaronmallen/blog', 'main', 'older', '2026-03-01', '09:00'),
        ('newer', 'aaronmallen/blog', 'main', 'newer', '2026-03-31', '09:00'),
        ('later', 'aaronmallen/blog', 'main', 'later', '2026-04-01', '09:00')
      """
    When I call the API with "GET /api/v1/commits?from=2026-03-01&to=2026-03-31"
    Then the call answers 200
    And the answer's "commits" lists 2
    And the answer's "commits.0.sha" is "newer"
    And the answer's "commits.1.sha" is "older"

  Scenario: Listing commits narrows to the repositories named
    Given the database runs:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time) values
        ('blog', 'aaronmallen/blog', 'main', 'blog', '2026-03-02', '09:00'),
        ('other', 'aaronmallen/other', 'main', 'other', '2026-03-04', '09:00')
      """
    When I call the API with "GET /api/v1/commits?from=2026-03-01&to=2026-03-31&repos=blog"
    Then the answer's "commits" lists 1
    And the answer's "commits.0.sha" is "blog"

  Scenario: Listing commits or pull requests answers what the MCP tools answer, less the untrusted marks
    Given the database runs:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
        values ('blog', 'aaronmallen/blog', 'main', 'fix the feed', '2026-03-02', '09:00');
      insert into pull_requests (repo, number, title, url, ready_at, opened_at)
        values ('aaronmallen/blog', 1, 'fix the feed', 'https://github.com/aaronmallen/blog/pull/1',
                '2026-03-02 12:00Z', '2026-03-02 12:00Z')
      """
    And I am signed in to the admin
    And an MCP client connected with the scopes "read"
    Then the record MCP tool "list_commits" answers as "GET /api/v1/commits?from=2026-03-01&to=2026-03-31" does, given:
      """
      { "from": "2026-03-01", "to": "2026-03-31" }
      """
    And the record MCP tool "list_pull_requests" answers as "GET /api/v1/pull_requests?from=2026-03-01&to=2026-03-31" does, given:
      """
      { "from": "2026-03-01", "to": "2026-03-31" }
      """

  Scenario: Listing commits with no end to the window is refused with a 422
    When I call the API with "GET /api/v1/commits?from=2026-03-01"
    Then the call answers 422

  Scenario: Importing commits queues the import
    Given the record lists have a GitHub token
    And GitHub answers POST "/graphql" with status 502
    When I call the API with "POST /api/v1/commits/import" and:
      """
      {}
      """
    Then the call answers 200
    And the answer's "status" is "queued"
    And the database soon answers "commits" for:
      """
      select sync from sync_states where kind = 'failure'
      """

  Scenario: Importing commits answers 503 when GitHub is not connected
    When I call the API with "POST /api/v1/commits/import" and:
      """
      {}
      """
    Then the call answers 503
    And the answer's "message" is "GitHub isn't connected, so no import can run"

  Scenario: Importing commits answers 503 when the queue is down
    Given the record lists have a GitHub token
    When Redis goes down
    And I call the API with "POST /api/v1/commits/import" and:
      """
      {}
      """
    Then the call answers 503
    And the answer's "error" is "unavailable"

  Scenario: Listing pull requests answers the window's pull requests with their text unmarked
    Given the database runs:
      """
      insert into pull_requests (repo, number, title, url, ready_at, opened_at)
        values ('aaronmallen/blog', 1, 'fix the feed', 'https://github.com/aaronmallen/blog/pull/1',
                '2026-03-02 12:00Z', '2026-03-02 12:00Z')
      """
    When I call the API with "GET /api/v1/pull_requests?from=2026-03-01&to=2026-03-31"
    Then the answer's "pull_requests.0.title" is "fix the feed"
    And the answer's "pull_requests" lists 1
    And the answer does not include "untrusted"

  Scenario: The sync state answers nothing synced and nothing failing on a fresh site
    When I call the API with "GET /api/v1/sync_state"
    Then the call answers 200
    And the answer's "commits_last_synced_at" is:
      """
      null
      """
    And the answer's "failures" is:
      """
      []
      """

  Scenario: The sync state answers each failing sync as read_sync_state does
    Given the database runs:
      """
      insert into sync_states (kind, sync, synced_at, failure_reason, failure_message, failing_since, failure_count)
        values ('failure', 'commits', '2026-03-01 08:00Z', 'github_failed', '502', '2026-03-01 08:00Z', 1)
      """
    And I am signed in to the admin
    And an MCP client connected with the scopes "read"
    Then the record MCP tool "read_sync_state" answers as "GET /api/v1/sync_state" does, given:
      """
      {}
      """

  Scenario: Listing tokens shows the live tokens and never the token itself, as list_api_tokens does
    When I call the record links API with "GET /api/v1/tokens"
    Then the record links API answers 200 with rows at "tokens" holding only "id, name, created_at, last_used_at"
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read"
    Then the record MCP tool "list_api_tokens" answers as "GET /api/v1/tokens" does, given:
      """
      {}
      """
