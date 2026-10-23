Feature: MCP record tools
  Agents list commits and pull requests by window, read a pull request and the sync state, write the journal and queue a
  commit import.

  Background:
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read write publish delete"

  Scenario: list_commits answers each commit whole
    Given the database runs:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time, additions, deletions)
        values ('abc123', 'aaronmallen/blog', 'main', E'fix the feed\n\nthe body runs on', '2026-03-02', '14:05', 12, 3)
      """
    When I call the MCP tool "list_commits" with:
      """
      { "from": "2026-03-01", "to": "2026-03-31" }
      """
    Then the answer's "commits" is:
      """
      [
        {
          "id": 1, "sha": "abc123", "repo": "aaronmallen/blog", "branch": "main",
          "message": "fix the feed\n\nthe body runs on", "date": "2026-03-02", "time": "14:05",
          "additions": 12, "deletions": 3
        }
      ]
      """

  Scenario: list_commits keeps to the window, newest first, and says it answered the whole window
    Given the database runs:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time) values
        ('older', 'aaronmallen/blog', 'main', 'older', '2026-03-01', '09:00'),
        ('newer', 'aaronmallen/blog', 'main', 'newer', '2026-03-31', '09:00'),
        ('later', 'aaronmallen/blog', 'main', 'later', '2026-04-01', '09:00')
      """
    When I call the MCP tool "list_commits" with:
      """
      { "from": "2026-03-01", "to": "2026-03-31" }
      """
    Then the answer's "commits" lists 2
    And the answer's "commits.0.sha" is "newer"
    And the answer's "commits.1.sha" is "older"
    And the answer matches:
      """
      { "count": 2, "partial": false }
      """

  Scenario: list_commits narrows to the repositories named, with or without the owner
    Given the database runs:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time) values
        ('blog', 'aaronmallen/blog', 'main', 'blog', '2026-03-02', '09:00'),
        ('site', 'aaronmallen/site', 'main', 'site', '2026-03-03', '09:00'),
        ('other', 'aaronmallen/other', 'main', 'other', '2026-03-04', '09:00')
      """
    When I call the MCP tool "list_commits" with:
      """
      { "from": "2026-03-01", "to": "2026-03-31", "repos": ["blog", "aaronmallen/site"] }
      """
    Then the answer's "commits" lists 2
    And the answer's "commits.0.sha" is "site"
    And the answer's "commits.1.sha" is "blog"

  Scenario: list_commits stops at the row cap and says where to go on
    Given the database runs:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
      select 'sha' || n, 'aaronmallen/blog', 'main', 'commit ' || n,
              case when n = 1 then date '2026-03-01' when n = 102 then date '2026-03-03' else date '2026-03-02' end, '09:00'
      from generate_series(1, 102) as n
      """
    When I call the MCP tool "list_commits" with:
      """
      { "from": "2026-03-01", "to": "2026-03-31" }
      """
    Then the answer matches:
      """
      { "count": 101, "partial": true, "continue_to": "2026-03-01" }
      """

  Scenario: list_commits rounds a full window out to the end of its last day
    Given the database runs:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
      select 'sha' || n, 'aaronmallen/blog', 'main', 'commit ' || n, '2026-03-02', '09:00'
      from generate_series(1, 101) as n
      """
    When I call the MCP tool "list_commits" with:
      """
      { "from": "2026-03-01", "to": "2026-03-31" }
      """
    Then the answer matches:
      """
      { "count": 101, "partial": false }
      """

  Scenario: Each day-paged tool names the MCP page size in its description
    Then the record MCP tools "list_commits, list_journal_entries, list_pull_requests, read_activity" each say "One answer carries about 100 rows"

  Scenario: list_commits refuses a day it cannot read
    When I call the MCP tool "list_commits" with:
      """
      { "from": "March", "to": "2026-03-31" }
      """
    Then the answer includes "give from and to as days, such as 2026-01-01"

  Scenario Outline: <tool> refuses a window that runs backwards
    When I call the MCP tool "<tool>" with:
      """
      { "from": "2026-03-31", "to": "2026-03-01" }
      """
    Then the answer includes "from comes after to"

    Examples:
      | tool               |
      | list_commits       |
      | list_pull_requests |

  Scenario: list_pull_requests answers each pull request whole
    Given the database runs:
      """
      insert into pull_requests (repo, number, title, body, url, ready_at, merged_at, opened_at)
        values ('someone/else', 7, 'Import them', 'Every one', 'https://github.com/someone/else/pull/7',
                '2026-03-02 18:00Z', '2026-03-03 18:00Z', '2026-03-02 18:00Z')
      """
    When I call the MCP tool "list_pull_requests" with:
      """
      { "from": "2026-03-01", "to": "2026-03-31" }
      """
    Then the answer's "pull_requests" is:
      """
      [
        {
          "id": 1, "repo": "someone/else", "number": 7, "title": "Import them", "description": "Every one",
          "url": "https://github.com/someone/else/pull/7", "state": "merged",
          "ready_at": "2026-03-02T18:00:00Z", "merged_at": "2026-03-03T18:00:00Z", "closed_at": null
        }
      ]
      """

  Scenario: list_pull_requests keeps to the window, newest first, by the day each one last moved
    Given the database runs:
      """
      insert into pull_requests (repo, number, title, url, ready_at, closed_at, merged_at, opened_at) values
        ('aaronmallen/blog', 1, 'One', 'https://github.com/aaronmallen/blog/pull/1', '2026-03-01 18:00Z', null, null, '2026-03-01 18:00Z'),
        ('aaronmallen/blog', 2, 'Two', 'https://github.com/aaronmallen/blog/pull/2', '2026-02-20 18:00Z', '2026-03-31 17:00Z', null, '2026-02-20 18:00Z'),
        ('aaronmallen/blog', 3, 'Three', 'https://github.com/aaronmallen/blog/pull/3', '2026-03-05 18:00Z', null, '2026-04-01 17:00Z', '2026-03-05 18:00Z')
      """
    When I call the MCP tool "list_pull_requests" with:
      """
      { "from": "2026-03-01", "to": "2026-03-31" }
      """
    Then the answer's "pull_requests" lists 2
    And the answer's "pull_requests.0.number" is "2"
    And the answer's "pull_requests.1.number" is "1"

  Scenario: list_pull_requests dates an open draft by when it opened and answers it as a draft
    Given the database runs:
      """
      insert into pull_requests (repo, number, title, url, ready_at, opened_at) values
        ('aaronmallen/blog', 1, 'One', 'https://github.com/aaronmallen/blog/pull/1', null, '2026-03-02 18:00Z'),
        ('aaronmallen/blog', 2, 'Two', 'https://github.com/aaronmallen/blog/pull/2', '2026-03-01 18:00Z', '2026-03-01 18:00Z'),
        ('aaronmallen/blog', 3, 'Three', 'https://github.com/aaronmallen/blog/pull/3', null, '2026-02-20 18:00Z')
      """
    When I call the MCP tool "list_pull_requests" with:
      """
      { "from": "2026-03-01", "to": "2026-03-31" }
      """
    Then the answer's "pull_requests" lists 2
    And the answer's "pull_requests.0.number" is "1"
    And the answer's "pull_requests.0.state" is "draft"
    And the answer's "pull_requests.1.number" is "2"

  Scenario: list_pull_requests stops at the row cap and says where to go on
    Given the database runs:
      """
      insert into pull_requests (repo, number, title, url, ready_at, opened_at)
      select 'aaronmallen/blog', n, 'Pull ' || n, 'https://github.com/aaronmallen/blog/pull/' || n, at, at
      from generate_series(1, 102) as n,
        lateral (select case when n = 1 then timestamptz '2026-03-01 18:00Z'
                              when n = 102 then timestamptz '2026-03-03 18:00Z'
                              else timestamptz '2026-03-02 18:00Z' end as at) as day
      """
    When I call the MCP tool "list_pull_requests" with:
      """
      { "from": "2026-03-01", "to": "2026-03-31" }
      """
    Then the answer matches:
      """
      { "count": 101, "partial": true, "continue_to": "2026-03-01" }
      """

  Scenario: read_pull_request answers an open pull request with its times
    Given the database runs:
      """
      insert into pull_requests (repo, number, title, url, ready_at, opened_at)
        values ('aaronmallen/blog', 12, 'Twelve', 'https://github.com/aaronmallen/blog/pull/12', '2026-03-02 14:05Z', '2026-03-02 14:05Z')
      """
    When I call the MCP tool "read_pull_request" with:
      """
      { "id": 1 }
      """
    Then the answer matches:
      """
      {
        "repo": "aaronmallen/blog", "number": 12, "url": "https://github.com/aaronmallen/blog/pull/12",
        "state": "open", "ready_at": "2026-03-02T14:05:00Z", "merged_at": null, "closed_at": null
      }
      """

  Scenario: read_pull_request answers a pull request closed unmerged as closed
    Given the database runs:
      """
      insert into pull_requests (repo, number, title, url, ready_at, closed_at, opened_at)
        values ('aaronmallen/blog', 12, 'Twelve', 'https://github.com/aaronmallen/blog/pull/12', now(), now(), now())
      """
    When I call the MCP tool "read_pull_request" with:
      """
      { "id": 1 }
      """
    Then the answer's "state" is "closed"

  Scenario: read_pull_request refuses an unknown ID
    When I call the MCP tool "read_pull_request" with:
      """
      { "id": 999999 }
      """
    Then it refuses
    And the answer includes "no pull request has the ID 999999"

  Scenario: create_journal_entry shows the entry in the admin
    When I call the MCP tool "create_journal_entry" with:
      """
      { "body": "Wrote about abc" }
      """
    And I visit "/admin/journal"
    Then I see "Wrote about abc"

  Scenario: create_journal_entry refuses a day after today as an error and saves nothing
    When I call the MCP tool "create_journal_entry" with:
      """
      { "body": "Not yet", "entry_date": "2999-01-01" }
      """
    Then it refuses
    And the answer includes "entry_date falls after today; pick today or an earlier day"
    And the database answers "0" for:
      """
      select count(*) from journal_entries
      """

  Scenario: update_journal_entry shows the change in the admin
    Given the database runs:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html)
        values ((now() at time zone 'America/Chicago')::date, '09:00', 'before', '<p>before</p>')
      """
    When I call the MCP tool "update_journal_entry" with:
      """
      { "id": 1, "body": "after the edit" }
      """
    And I visit "/admin/journal"
    Then I see "after the edit"

  Scenario: delete_journal_entry drops the entry from the admin
    Given the database runs:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html)
        values ((now() at time zone 'America/Chicago')::date, '09:00', 'gone soon', '<p>gone soon</p>')
      """
    When I call the MCP tool "delete_journal_entry" with:
      """
      { "id": 1 }
      """
    And I visit "/admin/journal"
    Then I do not see "gone soon"

  Scenario: read_sync_state answers nothing synced and nothing failing on a fresh site
    When I call the MCP tool "read_sync_state"
    Then the answer's "commits_last_synced_at" is:
      """
      null
      """
    And the answer's "failures" is:
      """
      []
      """

  Scenario: read_sync_state answers when commits last synced
    Given the database runs:
      """
      insert into sync_states (kind, repo, synced_at) values ('commits', 'aaronmallen/blog', '2026-03-02 09:00Z')
      """
    Then the record MCP tool "read_sync_state" gives "commits_last_synced_at" within a minute of now

  Scenario: read_sync_state answers each failing sync with when it began failing
    Given the database runs:
      """
      insert into sync_states (kind, sync, synced_at, failure_reason, failure_message, failing_since, failure_count)
        values ('failure', 'commits', '2026-03-02 08:00Z', 'github_failed', '503', '2026-03-01 08:00Z', 2)
      """
    When I call the MCP tool "read_sync_state"
    Then the answer's "failures" is:
      """
      [
        {
          "sync": "commits", "repo": null, "reason": "github_failed", "count": 2, "message": "503",
          "failing_since": "2026-03-01T08:00:00Z", "last_failed_at": "2026-03-02T08:00:00Z"
        }
      ]
      """

  Scenario: import_commits queues the import the admin queues
    Given the record lists have a GitHub token
    And GitHub answers POST "/graphql" with status 502
    When I call the MCP tool "import_commits"
    Then the answer's "status" is "queued"
    And the database soon answers "commits" for:
      """
      select sync from sync_states where kind = 'failure'
      """

  Scenario: import_commits refuses when GitHub is not connected
    When I call the MCP tool "import_commits"
    Then the answer includes "GitHub isn't connected, so no import can run"
    And the database answers "0" for:
      """
      select count(*) from sync_states
      """

  Scenario: The journal page has no axe breaches
    Given the database runs:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html)
        values ((now() at time zone 'America/Chicago')::date, '09:00', 'before', '<p>before</p>')
      """
    When I visit "/admin/journal"
    Then the page has no axe breaches in light or dark
