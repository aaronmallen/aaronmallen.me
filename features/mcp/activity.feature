Feature: MCP activity feed
  read_activity sends the day-by-day feed over a window, a page at a time, and summarize_activity counts it by kind,
  month and repository.

  Background:
    Given an MCP client connected with the scopes "read health"
    And the database runs "DELETE FROM sprints"

  Scenario: The feed names its window and gives each row its kind, date, time, name and the ID its read tool takes
    Given the table commits holds:
      | sha                                      | repo             | branch | message             | commit_date | commit_time |
      | bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb | aaronmallen/blog | main   | posts: add the view | today       | 14:30       |
    And the table journal_entries holds:
      | entry_date | entry_time | body   | body_html     |
      | today      | 09:00      | A note | <p>A note</p> |
    When I read the activity of the last 30 days
    Then the activity answer names the window of the last 30 days
    And the first activity row is dated today
    And the first activity row matches:
      """
      { "kind": "commit", "time": "14:30", "name": { "untrusted": true, "text": "posts: add the view" }, "source_id": 1 }
      """
    And the activity rows match, in any order:
      """
      [{ "kind": "commit", "source_id": 1 }, { "kind": "journal", "source_id": 1 }]
      """
    When I call the MCP tool "read_commit" with:
      """
      { "id": 1 }
      """
    Then the MCP tool answer at "sha" is '"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"'

  Scenario: A commit sends its whole message, its repository, sha and line counts
    Given the table commits holds:
      | sha                                      | repo          | branch | message                                             | commit_date | commit_time | additions | deletions |
      | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa | work/internal | main   | posts: add the view\n\nThe body says why it changed | today       | 14:30       | 12        | 3         |
    And the database runs "UPDATE commits SET message = replace(message, '\n', E'\n')"
    When I read the activity of the last 30 days
    Then the first activity row matches:
      """
      { "repo": "work/internal", "sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "additions": 12, "deletions": 3,
        "name": { "untrusted": true, "text": "posts: add the view\n\nThe body says why it changed" } }
      """

  Scenario: A journal entry and a finished task show, with no task type, and a canceled task stays out
    Given the table journal_entries holds:
      | entry_date | entry_time | body           | body_html             |
      | today      | 09:00      | wrote the tool | <p>wrote the tool</p> |
    And the table tasks holds:
      | title           | list | position | status   | completed_at   |
      | Clear the inbox | next | 1        | done     | today at 16:00 |
      | Drop the idea   | next | 2        | canceled | today at 17:00 |
    When I read the activity of the last 30 days with:
      """
      { "kinds": ["task"] }
      """
    Then the activity names are:
      """
      ["Clear the inbox"]
      """
    And the first activity row has no "task_type"
    When I read the activity of the last 30 days with:
      """
      { "kinds": ["journal"] }
      """
    Then the activity rows match, in any order:
      """
      [{ "kind": "journal", "name": "wrote the tool" }]
      """

  Scenario: A comment on a task sends its text, its task's title, id and tags, and a synced one its link
    Given the table tasks holds:
      | title           | list | position |
      | Clear the inbox | next | 1        |
    And the task "Clear the inbox" carries the private tags "home"
    And the table task_comments holds:
      | task_id | body           | created_at     | provider | remote_id | url                                                            |
      | 1       | Down to ten    | today at 10:00 |          |           |                                                                |
      | 1       | From the issue | today at 10:00 | github   | IC_1      | https://github.com/aaronmallen/aaronmallen.me/issues/7#issuecomment-1 |
    When I read the activity of the last 30 days
    Then the activity rows match, in any order:
      """
      [{ "kind": "comment", "name": { "untrusted": true, "text": "Down to ten" }, "excerpt": "Clear the inbox", "task_id": 1, "tags": ["home"] },
        { "kind": "comment", "name": { "untrusted": true, "text": "From the issue" },
          "link": "https://github.com/aaronmallen/aaronmallen.me/issues/7#issuecomment-1" }]
      """

  Scenario: Comments narrow by kind, by their task's tags and by their text
    Given the table tasks holds:
      | title           | list | position | status | completed_at   |
      | Clear the inbox | next | 1        | open   |                |
      | Elsewhere       | next | 2        | open   |                |
      | Finished        | next | 3        | done   | today at 16:00 |
    And the task "Clear the inbox" carries the private tags "home"
    And the table task_comments holds:
      | task_id | body        | created_at     |
      | 1       | Down to ten | today at 10:00 |
      | 1       | Still full  | today at 10:00 |
      | 2       | Elsewhere   | today at 10:00 |
    When I read the activity of the last 30 days with:
      """
      { "kinds": ["comment"] }
      """
    Then the activity kinds are "comment, comment, comment"
    When I read the activity of the last 30 days with:
      """
      { "tags": ["home"] }
      """
    Then the activity names, in any order, are:
      """
      [{ "untrusted": true, "text": "Down to ten" }, { "untrusted": true, "text": "Still full" }]
      """
    When I read the activity of the last 30 days with:
      """
      { "text": "down to" }
      """
    Then the activity names are:
      """
      [{ "untrusted": true, "text": "Down to ten" }]
      """

  Scenario: A closed work session sends its task's title, id, tags and how long it ran, on the day it started
    Given the table tasks holds:
      | title           | list | position | status      |
      | Clear the inbox | next | 1        | in_progress |
    And the task "Clear the inbox" carries the private tags "home"
    And the table work_sessions holds:
      | task_id | started_at       | ended_at         |
      | 1       | today at 09:00   | today at 10:30   |
      | 1       | 2 days ago at 23:00 | 1 days ago at 01:00 |
      | 1       | 1 days ago at 09:00 |                  |
    When I read the activity of the last 30 days
    Then the activity rows match, in any order:
      """
      [{ "kind": "session", "name": "Clear the inbox", "task_id": 1, "worked_seconds": 5400, "tags": ["home"] },
        { "kind": "session", "time": "23:00" }]
      """
    And the activity row of the kind "session" is dated 0 days ago at "09:00"

  Scenario: A session that crosses midnight shows on the day it started
    Given the table tasks holds:
      | title           | list | position | status      |
      | Clear the inbox | next | 1        | in_progress |
    And the table work_sessions holds:
      | task_id | started_at          | ended_at            |
      | 1       | 2 days ago at 23:00 | 1 days ago at 01:00 |
    When I read the activity of the last 30 days
    Then the activity row of the kind "session" is dated 2 days ago at "23:00"

  Scenario: A task's moves, tag changes and status changes stay out of the feed
    Given the table tasks holds:
      | title           | list | position | status      |
      | Clear the inbox | next | 1        | in_progress |
    And the table task_events holds:
      | task_id | kind           | occurred_at    | tag_name | from_status | to_status   | from_list | to_list |
      | 1       | tagged         | today at 09:00 | home     |             |             |           |         |
      | 1       | status_changed | today at 09:00 |          | open        | in_progress |           |         |
      | 1       | moved          | today at 09:00 |          |             |             | next      | someday |
    When I read the activity of the last 30 days
    Then the activity holds no rows

  Scenario: A merged pull request sends an opened row and a merged row, and a closed one a closed row
    Given the table pull_requests holds:
      | repo             | number | title     | url                                      | opened_at      | ready_at       | merged_at      | closed_at      |
      | aaronmallen/blog | 1      | Add feeds | https://github.com/aaronmallen/blog/pull/1 | today at 08:00 | today at 09:00 | today at 10:00 |                |
      | aaronmallen/blog | 2      | Add feeds | https://github.com/aaronmallen/blog/pull/2 | today at 08:00 | today at 09:00 |                | today at 10:00 |
    When I read the activity of the last 30 days
    Then the activity rows match, in any order:
      """
      [{ "kind": "pull_request_opened", "time": "09:00", "source_id": 1, "name": { "untrusted": true, "text": "Add feeds" },
          "repo": "aaronmallen/blog", "link": "https://github.com/aaronmallen/blog/pull/1" },
        { "kind": "pull_request_merged", "time": "10:00", "source_id": 1, "link": "https://github.com/aaronmallen/blog/pull/1" },
        { "kind": "pull_request_opened", "source_id": 2 },
        { "kind": "pull_request_closed", "source_id": 2 }]
      """

  Scenario: A decision's events and comments send its title, what happened, the reason or option, its id and tags
    Given the table decisions holds:
      | title        | problem      |
      | Pick a queue | Jobs pile up |
      | Other        | Jobs pile up |
    And the decision "Pick a queue" carries the private tags "infra"
    And the table decision_options holds:
      | decision_id | title   |
      | 1           | Sidekiq |
    And the table decision_events holds:
      | decision_id | kind         | option_id | reason          | created_at     |
      | 1           | opened       |           |                 | today at 10:00 |
      | 1           | option_added | 1         |                 | today at 10:00 |
      | 1           | resolved     | 1         | It already runs | today at 10:00 |
      | 2           | opened       |           |                 | today at 12:00 |
    And the table decision_comments holds:
      | decision_id | body          | created_at     |
      | 1           | Ask ops first | today at 11:00 |
    When I read the activity of the last 30 days with:
      """
      { "tags": ["infra"] }
      """
    Then the activity rows match, in any order:
      """
      [{ "kind": "decision", "name": "Pick a queue", "status": "opened", "decision_id": 1, "tags": ["infra"] },
        { "kind": "decision", "status": "option_added", "excerpt": "Sidekiq", "decision_id": 1 },
        { "kind": "decision", "status": "resolved", "excerpt": "It already runs", "decision_id": 1 },
        { "kind": "decision_comment", "name": "Ask ops first", "excerpt": "Pick a queue", "decision_id": 1, "tags": ["infra"] }]
      """
    When I read the activity of the last 30 days with:
      """
      { "kinds": ["decision"] }
      """
    Then the activity kinds are "decision, decision, decision, decision"

  Scenario: The feed sends every kind it holds, and narrows to a kind it once left out
    Given the whole activity feed happened today
    When I read the activity of the last 30 days
    Then every activity kind the feed holds shows
    When I read the activity of the last 30 days with:
      """
      { "kinds": ["webmention", "sprint"] }
      """
    Then the activity kinds, in any order, are "webmention, sprint"
    When I summarize the activity of the last 30 days
    Then the summary counts every kind once

  Scenario: A project sends its name, link, repository, status and tagline, and a sprint shows on its day
    Given the table projects holds:
      | name | key  | visibility | url                  | repo             | tagline  |
      | blog | BLOG | public     | https://blog.example | aaronmallen/blog | the site |
    And the table sprints holds:
      | sprint_date        |
      | the day 2 days ago |
    When I read the activity of the last 30 days
    Then the activity rows match, in any order:
      """
      [{ "kind": "project", "name": "blog", "link": "https://blog.example", "repo": "aaronmallen/blog", "status": "active", "excerpt": "the site" },
        { "kind": "sprint", "time": "00:00" }]
      """
    And the activity row of the kind "sprint" is dated 2 days ago at "00:00"

  Scenario: A suggestion is named by its post, linked to it, or by a social post's first part
    Given the draft post "Half done" with the body "teh" as "post"
    And the draft social post "teh first part" as "social"
    And the owner calls POST "suggestions" with:
      """
      { "target": "post", "id": {post}, "edits": [{ "original": "teh", "replacement": "the", "reason": "typo" }] }
      """
    And the owner calls POST "suggestions" with:
      """
      { "target": "social_post", "id": {social}, "edits": [{ "original": "teh", "replacement": "the", "reason": "typo" }] }
      """
    When I read the activity of the last 30 days
    Then the activity rows match, in any order:
      """
      [{ "kind": "suggestion", "name": "Half done", "link": "/writing/half-done" },
        { "kind": "suggestion", "name": "teh first part" }]
      """

  Scenario: No project, sprint, suggestion or commit outside the window shows, and a kind the feed lacks is refused
    Given the table projects holds:
      | name | key  | visibility | created_at   |
      | old  | OLD  | private    | 300 days ago |
    And the table sprints holds:
      | sprint_date          |
      | the day 300 days ago |
    And the table commits holds:
      | sha | repo             | branch | message  | commit_date          | commit_time |
      | a1  | aaronmallen/blog | main   | long ago | the day 300 days ago | 09:00       |
    And the draft post "Old" with the body "teh" as "post"
    And the owner calls POST "suggestions" with:
      """
      { "target": "post", "id": {post}, "edits": [{ "original": "teh", "replacement": "the", "reason": "typo" }] }
      """
    And the database runs "UPDATE suggestions SET created_at = now() - interval '300 days'"
    When I read the activity of the last 30 days
    Then the activity holds no rows
    When I read the activity of the last 365 days
    Then the activity holds 4 rows
    When I read the activity of the last 30 days with:
      """
      { "kinds": ["meeting"] }
      """
    Then the MCP tool refuses

  Scenario: The feed sends the newest row first and reads a range a year wide
    Given the table commits holds:
      | sha | repo             | branch | message  | commit_date          | commit_time |
      | a1  | aaronmallen/blog | main   | older    | the day 2 days ago   | 09:00       |
      | a2  | aaronmallen/blog | main   | newer    | today                | 09:00       |
      | a3  | aaronmallen/blog | main   | long ago | the day 300 days ago | 09:00       |
    When I read the activity of the last 30 days
    Then the activity names are:
      """
      [{ "untrusted": true, "text": "newer" }, { "untrusted": true, "text": "older" }]
      """
    When I read the activity from 365 days ago to 299 days ago
    Then the activity names are:
      """
      [{ "untrusted": true, "text": "long ago" }]
      """

  Scenario: The feed narrows to the repositories it is given, by full name, bare name or capitals, keeping what is no commit
    Given the table commits holds:
      | sha | repo              | branch | message  | commit_date | commit_time |
      | a1  | aaronmallen/blog  | main   | in blog  | today       | 09:00       |
      | a2  | aaronmallen/site  | main   | in site  | today       | 09:00       |
      | a3  | aaronmallen/other | main   | in other | today       | 09:00       |
    And the table journal_entries holds:
      | entry_date | entry_time | body           | body_html             |
      | today      | 09:00      | walked the dog | <p>walked the dog</p> |
    When I read the activity of the last 30 days with:
      """
      { "repos": ["aaronmallen/blog"], "kinds": ["commit"] }
      """
    Then the activity names are:
      """
      [{ "untrusted": true, "text": "in blog" }]
      """
    When I read the activity of the last 30 days with:
      """
      { "repos": ["aaronmallen/blog", "site"], "kinds": ["commit"] }
      """
    Then the activity names, in any order, are:
      """
      [{ "untrusted": true, "text": "in blog" }, { "untrusted": true, "text": "in site" }]
      """
    When I read the activity of the last 30 days with:
      """
      { "repos": ["aaronmallen/blog", "aaronmallen/site"], "kinds": ["commit", "journal"] }
      """
    Then the activity names, in any order, are:
      """
      [{ "untrusted": true, "text": "in blog" }, { "untrusted": true, "text": "in site" }, "walked the dog"]
      """
    When I read the activity of the last 30 days with:
      """
      { "repos": ["aaronmallen/Blog"], "kinds": ["commit"] }
      """
    Then the activity names are:
      """
      [{ "untrusted": true, "text": "in blog" }]
      """
    When I read the activity of the last 30 days with:
      """
      { "repos": ["Blog"], "kinds": ["commit"] }
      """
    Then the activity names are:
      """
      [{ "untrusted": true, "text": "in blog" }]
      """

  Scenario: The feed narrows to tags in any case and gives each row its tags, or an empty list
    Given the table journal_entries holds:
      | entry_date | entry_time | body           | body_html             |
      | today      | 09:00      | about the site | <p>about the site</p> |
      | today      | 09:00      | about work     | <p>about work</p>     |
    And the journal "about the site" carries the private tags "site"
    And the journal "about work" carries the private tags "work"
    And the table tasks holds:
      | title  | list | position | status | completed_at   |
      | Errand | next | 1        | done   | today at 16:00 |
    And the task "Errand" carries the private tags "home, errands"
    And the published post "Ruby" with the body "Words" as "post"
    And the post "Ruby" carries the tag "ruby" kept as "ruby"
    And the table commits holds:
      | sha | repo             | branch | message | commit_date | commit_time |
      | a1  | aaronmallen/blog | main   | untagged | today      | 09:00       |
    When I read the activity of the last 30 days with:
      """
      { "tags": ["Site"] }
      """
    Then the activity names are:
      """
      ["about the site"]
      """
    When I read the activity of the last 30 days with:
      """
      { "kinds": ["task", "post", "commit"] }
      """
    Then the activity rows match, in any order:
      """
      [{ "kind": "task", "tags": ["errands", "home"] }, { "kind": "post", "tags": ["ruby"] }, { "kind": "commit", "tags": [] }]
      """

  Scenario: The feed narrows to the text it is given and counts what it sent, whole, with no day to carry on from
    Given the table commits holds:
      | sha | repo             | branch | message             | commit_date | commit_time |
      | a1  | aaronmallen/blog | main   | admin: add the view | today       | 09:00       |
      | a2  | aaronmallen/blog | main   | admin: add the edit | today       | 09:00       |
    And the table journal_entries holds:
      | entry_date | entry_time | body           | body_html             |
      | today      | 09:00      | nothing to see | <p>nothing to see</p> |
    When I read the activity of the last 30 days with:
      """
      { "text": "add the view" }
      """
    Then the activity kinds are "commit"
    When I read the activity of the last 30 days with:
      """
      { "kinds": ["commit"] }
      """
    Then the MCP tool answer at "count" is "2"
    And the MCP tool answer at "partial" is "false"
    And the MCP answer has no "continue_to"

  Scenario Outline: <tool> refuses <what>
    When I call the MCP tool "<tool>" with:
      """
      <arguments>
      """
    Then the MCP tool refuses
    And the MCP tool's words hold "<says>"

    Examples:
      | what                      | tool               | arguments                                        | says                                          |
      | a day it cannot read      | read_activity      | { "from": "last tuesday", "to": "2026-10-01" }    | give from and to as days, such as 2026-01-01 |
      | a from after its to       | read_activity      | { "from": "2026-10-08", "to": "2026-10-01" }      | from comes after to                           |
      | a call naming no window   | read_activity      | {}                                               |                                               |
      | a day it cannot read      | summarize_activity | { "from": "last tuesday", "to": "2026-10-01" }    | give from and to as days, such as 2026-01-01 |
      | a from after its to       | summarize_activity | { "from": "2026-10-08", "to": "2026-10-01" }      | from comes after to                           |
      | a range over 366 days     | summarize_activity | { "from": "2025-01-01", "to": "2026-01-02" }      | give a range of 366 days or fewer             |
      | a call naming no range    | summarize_activity | {}                                               |                                               |
      | a kinds argument          | summarize_activity | { "from": "2026-01-01", "to": "2026-01-31", "kinds": ["webmention"] } |                          |

  Scenario: A window holding more than one answer sends the newest page, partial, and carries on with nothing repeated
    Given the database runs:
      """
      INSERT INTO commits (sha, repo, branch, message, commit_date, commit_time)
      SELECT 'c' || n, 'aaronmallen/blog', 'main', 'commit ' || n, ((now() AT TIME ZONE 'America/Chicago')::date - (n / 50 + 1)), '09:00'
      FROM generate_series(0, 149) AS n
      """
    When I read the activity of the last 30 days
    Then the MCP tool answer at "partial" is "true"
    And the activity holds 100 rows
    And the activity answer carries on from the day 3 days ago
    When I read the activity of the last 30 days up to the day it says to carry on from
    Then the activity holds 50 rows
    And the MCP tool answer at "partial" is "false"

  Scenario: A page rounds a day out rather than splitting it, and a window that rounds out to its oldest day is whole
    Given the database runs:
      """
      INSERT INTO commits (sha, repo, branch, message, commit_date, commit_time)
      SELECT 'c' || n, 'aaronmallen/blog', 'main', 'commit ' || n, ((now() AT TIME ZONE 'America/Chicago')::date - 1), '09:00'
      FROM generate_series(1, 101) AS n
      """
    When I read the activity of the last 30 days
    Then the activity holds 101 rows
    And the MCP tool answer at "partial" is "false"

  Scenario: The summary names its range and counts each kind in it, and nothing outside it
    Given the table commits holds:
      | sha | repo             | branch | message  | commit_date          | commit_time |
      | a1  | aaronmallen/blog | main   | one      | today                | 09:00       |
      | a2  | aaronmallen/blog | main   | two      | today                | 09:00       |
      | a3  | aaronmallen/blog | main   | long ago | the day 300 days ago | 09:00       |
    And the table journal_entries holds:
      | entry_date | entry_time | body   | body_html     |
      | today      | 09:00      | A note | <p>A note</p> |
    When I summarize the activity of the last 30 days
    Then the activity answer names the window of the last 30 days
    And the summary counts "commit 2, journal 1" and nothing else

  Scenario: The summary counts each kind in the month it happened, newest month first, and leaves out an empty month
    Given the table commits holds:
      | sha | repo             | branch | message | commit_date | commit_time |
      | a1  | aaronmallen/blog | main   | one     | 2026-01-05  | 09:00       |
      | a2  | aaronmallen/blog | main   | two     | 2026-03-05  | 09:00       |
    And the table journal_entries holds:
      | entry_date | entry_time | body   | body_html     |
      | 2026-02-07 | 09:00      | A note | <p>A note</p> |
    When I summarize the activity from "2026-01-01" to "2026-03-31"
    Then the summary's busy months are:
      """
      { "2026-03": { "commit": 1 }, "2026-02": { "journal": 1 }, "2026-01": { "commit": 1 } }
      """

  Scenario: The summary counts a project, a sprint, a suggestion, a finished task and comments in the month each happened
    Given the table projects holds:
      | name | key  | visibility | created_at                             |
      | old  | OLD  | private    | (TIMESTAMPTZ '2026-01-12 15:00:00+00') |
    And the table sprints holds:
      | sprint_date |
      | 2026-02-03  |
    And the draft post "Old" with the body "teh" as "post"
    And the owner calls POST "suggestions" with:
      """
      { "target": "post", "id": {post}, "edits": [{ "original": "teh", "replacement": "the", "reason": "typo" }] }
      """
    And the database runs "UPDATE suggestions SET created_at = TIMESTAMPTZ '2026-03-04 15:00:00+00'"
    When I summarize the activity from "2026-01-01" to "2026-03-31"
    Then the summary's busy months are:
      """
      { "2026-03": { "suggestion": 1 }, "2026-02": { "sprint": 1 }, "2026-01": { "project": 1 } }
      """

  Scenario: The summary counts a finished task, and local and synced comments, in the month each happened
    Given the table tasks holds:
      | title | list | position | status | completed_at                           |
      | Done  | next | 1        | done   | (TIMESTAMPTZ '2026-02-09 22:00:00+00') |
      | Open  | next | 2        | open   |                                        |
    And the table task_comments holds:
      | task_id | body   | created_at                             | provider | remote_id | url                          |
      | 2       | Local  | (TIMESTAMPTZ '2026-01-12 16:00:00+00') |          |           |                              |
      | 2       | Synced | (TIMESTAMPTZ '2026-03-03 16:00:00+00') | github   | IC_1      | https://github.com/x/y/1#c-1 |
    When I summarize the activity from "2026-01-01" to "2026-03-31"
    Then the summary's busy months are:
      """
      { "2026-03": { "comment": 1 }, "2026-02": { "task": 1 }, "2026-01": { "comment": 1 } }
      """

  Scenario: The summary totals commits and lines a repository, keeps repositories apart and totals none for other kinds
    Given the table commits holds:
      | sha | repo             | branch | message | commit_date | commit_time | additions | deletions |
      | a1  | aaronmallen/blog | main   | one     | today       | 09:00       | 10        | 2         |
      | a2  | aaronmallen/blog | main   | two     | today       | 09:00       | 5         | 1         |
      | a3  | work/internal    | main   | three   | today       | 09:00       | 0         | 0         |
    When I summarize the activity of the last 30 days
    Then the MCP tool answer at "repos" is:
      """
      { "aaronmallen/blog": { "commits": 2, "additions": 15, "deletions": 3 }, "work/internal": { "commits": 1, "additions": 0, "deletions": 0 } }
      """
    Given the database runs "DELETE FROM commits"
    And the table journal_entries holds:
      | entry_date | entry_time | body   | body_html     |
      | today      | 09:00      | A note | <p>A note</p> |
    When I summarize the activity of the last 30 days
    Then the MCP tool answer at "repos" is "{}"

  Scenario: The summary answers a year in one call, counts a range of 366 days and carries no row body
    Given the database runs:
      """
      INSERT INTO commits (sha, repo, branch, message, commit_date, commit_time)
      SELECT 'c' || n, 'aaronmallen/blog', 'main', 'posts: add the view ' || n, ((now() AT TIME ZONE 'America/Chicago')::date - n * 30), '09:00'
      FROM generate_series(0, 11) AS n
      """
    And the table journal_entries holds:
      | entry_date | entry_time | body           | body_html             |
      | today      | 09:00      | wrote the tool | <p>wrote the tool</p> |
    When I summarize the activity of the last 365 days
    Then the MCP tool answer at "kinds.commit" is "12"
    And the MCP tool's words do not hold "posts: add the view"
    And the MCP tool's words do not hold "wrote the tool"
