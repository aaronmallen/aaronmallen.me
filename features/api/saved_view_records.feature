Feature: API saved view records
  The JSON API and the read_saved_view tool read the records a saved view shows: the tasks, posts, journal entries
  or activity its screen lists for its filters, in pages or windows of days.

  Background:
    Given an API token with the scopes "read"

  Scenario: A tasks view on the recurring tab answers the current copy of each series
    Given the saved views database runs:
      """
      insert into tasks (title, list, position) values ('Water the plants', 'next', 1), ('Other', 'next', 2);
      insert into task_series (task_id, cadence, every) values (1, 'days', 1);
      insert into saved_views (name, screen, filters) values ('Recurring', 'tasks', '{"filter": "recurring"}');
      """
    When I read the records of saved view 1
    Then the saved view records give the ids "1"

  Scenario: A tasks view answers the view, the tasks in its list and paging
    Given the saved views database runs:
      """
      insert into tasks (title, list, position) values ('Next one', 'next', 1), ('Later one', 'someday', 2);
      insert into saved_views (name, screen, filters) values ('Next', 'tasks', '{"filter": "next"}');
      """
    When I read the records of saved view 1
    Then the saved view records answer 200
    And the saved view records' "saved_view" is:
      """
      {"id": 1, "name": "Next", "screen": "tasks", "filters": {"filter": "next"}}
      """
    And the saved view records' "count" is "1"
    And the saved view records' "partial" is "false"
    And the saved view records give the ids "1"

  Scenario: A tasks view narrows by the tags and words in its search
    Given the saved views database runs:
      """
      insert into tasks (title, list, position) values
        ('ship the deploy', 'next', 1), ('ship the deploy', 'next', 2), ('other', 'next', 3);
      insert into tags (name, color, scope) values ('ops', 'mk-blue', 'private');
      insert into task_tags (task_id, tag_id) values (1, 1), (3, 1);
      insert into saved_views (name, screen, filters) values ('Ops', 'tasks', '{"filter": "next", "q": "tag:ops deploy"}');
      """
    When I read the records of saved view 1
    Then the saved view records give the ids "1"

  Scenario: A tasks view narrows by the contributor terms in its search
    Given the saved views database runs:
      """
      insert into tasks (title, list, position) values ('ship the deploy', 'next', 1), ('ship the deploy', 'next', 2);
      insert into task_contributors (task_id, kind, agent, model) values (1, 'agent', 'claude-code', 'claude-opus-5-5');
      insert into saved_views (name, screen, filters)
      values ('Credited', 'tasks', '{"filter": "next", "q": "agent:claude-code model:claude-opus-5-5"}');
      """
    When I read the records of saved view 1
    Then the saved view records give the ids "1"

  Scenario: A tasks view with no list reads today's sprint, giving each task its sprint day
    Given the saved views database runs:
      """
      insert into sprints (sprint_date) values ('{today}');
      insert into tasks (title, list, sprint_id, position) values ('In the sprint', null, 1, 1), ('Loose', 'next', null, 2);
      insert into saved_views (name, screen) values ('Today', 'tasks');
      """
    When I read the records of saved view 1
    Then the saved view records give the ids "1"
    And the saved view records give the sprint_ons "{today}"

  Scenario: A tasks view reads the finished tasks on the completed tab
    Given the saved views database runs:
      """
      insert into tasks (title, list, status, completed_at, position) values ('Done', 'next', 'done', now(), 1);
      insert into tasks (title, list, position) values ('Open', 'next', 2);
      insert into saved_views (name, screen, filters) values ('Done', 'tasks', '{"filter": "completed"}');
      """
    When I read the records of saved view 1
    Then the saved view records give the ids "1"

  Scenario: A tasks view reads the planned sprints on the upcoming tab
    Given the saved views database runs:
      """
      insert into sprints (sprint_date) values ('{today+3}');
      insert into tasks (title, list, sprint_id, position) values ('Planned', null, 1, 1);
      insert into saved_views (name, screen, filters) values ('Upcoming', 'tasks', '{"filter": "upcoming"}');
      """
    When I read the records of saved view 1
    Then the saved view records' "records.0.id" is "1"
    And the saved view records' "records.0.sprint_on" is "{today+3}"

  Scenario: A tasks view gives each task what read_task gives, less its note, comments, record links and timeline
    Given the saved views database runs:
      """
      insert into tasks (title, list, position) values ('linked', 'next', 1);
      insert into tasks (title, list, status, completed_at, position) values ('Blocker', 'next', 'done', now(), 2);
      insert into tags (name, color, scope) values ('ops', 'mk-blue', 'private');
      insert into task_tags (task_id, tag_id) values (1, 1);
      insert into task_links (from_task_id, to_task_id, type) values (2, 1, 'blocks');
      insert into saved_views (name, screen, filters) values ('Next', 'tasks', '{"filter": "next"}');
      """
    When I read the records of saved view 1
    Then the saved view records are the tasks "1" as read_task gives them, less its note, comments, record links and timeline

  Scenario: A tasks view pages as list_tasks does
    Given the saved views database runs:
      """
      insert into tasks (title, list, position) select 'Task ' || n, 'next', n from generate_series(1, 101) n;
      insert into saved_views (name, screen, filters) values ('Next', 'tasks', '{"filter": "next"}');
      """
    When I read the records of saved view 1
    Then the saved view records' "count" is "100"
    And the saved view records' "partial" is "true"
    And the saved view records' "next_page" is "2"
    When I read the records of saved view 1 with "?page=2"
    Then the saved view records' "count" is "1"
    And the saved view records' "partial" is "false"

  Scenario: A posts view reads the posts in its status, each as the bulk post endpoints give it
    Given an API token with the scopes "read write"
    And the saved views database runs:
      """
      insert into posts (title, slug, status, body, body_html, read_time, word_count, webmentions_enabled)
      values ('Draft', 'draft', 'draft', 'Body', '<p>Body</p>', 1, 1, false);
      insert into posts (title, slug, status, published_at, body, body_html, read_time, word_count, webmentions_enabled)
      values ('Out', 'out', 'published', now() - interval '1 day', 'Body', '<p>Body</p>', 1, 1, false);
      insert into tags (name, color, scope) values ('ruby', 'mk-blue', 'public');
      insert into post_tags (post_id, tag_id) values (1, 1);
      insert into saved_views (name, screen, filters) values ('Drafts', 'posts', '{"status": "draft"}');
      """
    When I tag the post "Draft" with "ruby" through the bulk tag endpoint
    And I read the records of saved view 1
    Then the saved view records give the titles "Draft"
    And the saved view records are the posts the bulk tag endpoint answered

  Scenario: A posts view with no status reads every post
    Given the saved views database runs:
      """
      insert into posts (title, slug, status, body, body_html, read_time, word_count, webmentions_enabled)
      values ('Draft', 'draft', 'draft', 'Body', '<p>Body</p>', 1, 1, false);
      insert into posts (title, slug, status, published_at, body, body_html, read_time, word_count, webmentions_enabled)
      values ('Out', 'out', 'published', now() - interval '1 day', 'Body', '<p>Body</p>', 1, 1, false);
      insert into saved_views (name, screen) values ('All', 'posts');
      """
    When I read the records of saved view 1
    Then the saved view records' "count" is "2"

  Scenario: A posts view pages by page
    Given the saved views database runs:
      """
      insert into posts (title, slug, status, body, body_html, read_time, word_count, webmentions_enabled)
      select 'Post ' || n, 'post-' || n, 'draft', 'Body', '<p>Body</p>', 1, 1, false from generate_series(1, 101) n;
      insert into saved_views (name, screen) values ('All', 'posts');
      """
    When I read the records of saved view 1 with "?page=2"
    Then the saved view records' "count" is "1"
    And the saved view records' "partial" is "false"

  Scenario: A journal view reads the entries matching its search, newest first, as read_journal_entry gives them
    Given the saved views database runs:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html) values
        ('{today-1}', '09:00', 'a long run', '<p>a long run</p>'),
        ('{today}', '09:00', 'a short run', '<p>a short run</p>'),
        ('{today}', '09:00', 'a long run', '<p>a long run</p>');
      insert into tags (name, color, scope) values ('health', 'mk-blue', 'private');
      insert into journal_entry_tags (journal_entry_id, tag_id) values (1, 1), (2, 1);
      insert into saved_views (name, screen, filters) values ('Runs', 'journal', '{"q": "tag:health run"}');
      """
    When I read the records of saved view 1
    Then the saved view records are the entries "2, 1" as read_journal_entry gives them, less their record links

  Scenario: A journal view reads back from its last day
    Given the saved views database runs:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html) values
        ('{today-5}', '09:00', 'Kept', '<p>Kept</p>'), ('{today}', '09:00', 'Later', '<p>Later</p>');
      insert into saved_views (name, screen, filters) values ('Back', 'journal', '{"to": "{today-2}"}');
      """
    When I read the records of saved view 1
    Then the saved view records give the ids "1"

  Scenario: A journal view pages by day, taking continue_to for the next window
    Given the saved views database runs:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html)
      select '{today}', '09:00', 'Today ' || n, '<p>Today</p>' from generate_series(1, 100) n;
      insert into journal_entries (entry_date, entry_time, body, body_html) values
        ('{today-1}', '09:00', 'Yesterday', '<p>Yesterday</p>');
      insert into saved_views (name, screen) values ('All', 'journal');
      """
    When I read the records of saved view 1
    Then the saved view records' "count" is "100"
    And the saved view records' "continue_to" is "{today-1}"
    When I read the next window of saved view 1
    Then the saved view records give the ids "101"

  Scenario: An activity view with no days reads the last week
    Given the saved views database runs:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time) values
        ('a1', 'aaronmallen/aaronmallen.me', 'main', 'kept', '{today-6}', '09:00'),
        ('a2', 'aaronmallen/aaronmallen.me', 'main', 'dropped', '{today-7}', '09:00');
      insert into saved_views (name, screen) values ('Week', 'activity');
      """
    When I read the records of saved view 1
    Then the saved view records give the names "kept"

  Scenario: An activity view reads only the kinds it ticks, inside its days
    Given the saved views database runs:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time) values
        ('a1', 'aaronmallen/aaronmallen.me', 'main', 'Commit', '{today-20}', '09:00');
      insert into journal_entries (entry_date, entry_time, body, body_html) values
        ('{today-20}', '09:00', 'Inside', '<p>Inside</p>'), ('{today-40}', '09:00', 'Outside', '<p>Outside</p>');
      insert into saved_views (name, screen, filters)
      values ('Journal', 'activity', '{"from": "{today-30}", "to": "{today-10}", "types": {"journal": "1"}}');
      """
    When I read the records of saved view 1
    Then the saved view records give the source_ids "1"
    And the saved view records give the kinds "journal"

  Scenario: An activity view narrows by repository and words
    Given the saved views database runs:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time) values
        ('a1', 'aaronmallen/kept', 'main', 'fix the deploy', '{today}', '09:00'),
        ('a2', 'aaronmallen/other', 'main', 'fix the deploy', '{today}', '09:00'),
        ('a3', 'aaronmallen/kept', 'main', 'tidy', '{today}', '09:00');
      insert into saved_views (name, screen, filters) values ('Kept', 'activity', '{"q": "repo:kept deploy"}');
      """
    When I read the records of saved view 1
    Then the saved view records' "count" is "1"
    And the saved view records give the repos "aaronmallen/kept"

  Scenario: An activity view keeps a contributor filter in its search
    Given the saved views database runs:
      """
      insert into tasks (title, list, status, completed_at, position) values
        ('Mine', 'next', 'done', '{today} 09:00 America/Chicago', 1),
        ('Sonnet''s', 'next', 'done', '{today} 10:00 America/Chicago', 2);
      insert into task_contributors (task_id, kind, agent, model) values (2, 'agent', 'claude-code', 'claude-sonnet-5');
      insert into saved_views (name, screen, filters) values ('Sonnet', 'activity', '{"q": "model:claude-sonnet-5"}');
      """
    When I read the records of saved view 1
    Then the saved view records give the names "Sonnet's"

  Scenario: An activity view gives a commit its whole message, repository, sha and lines
    Given the saved views database runs:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time, additions, deletions) values
        ('abc123', 'aaronmallen/aaronmallen.me', 'main', E'Fix it\n\nThe long story', '{today}', '09:00', 3, 1);
      insert into saved_views (name, screen) values ('Week', 'activity');
      """
    When I read the records of saved view 1
    Then the saved view records' "records.0" is:
      """
      {
        "kind": "commit", "source_id": 1, "date": "{today}", "time": "09:00", "name": "Fix it\n\nThe long story",
        "link": null, "repo": "aaronmallen/aaronmallen.me", "sha": "abc123", "additions": 3, "deletions": 1,
        "status": null, "targets": null, "excerpt": null, "task_id": null, "decision_id": null,
        "worked_seconds": null, "views": null, "tags": [], "contributors": null
      }
      """

  Scenario: An activity view gives a post the views the admin screen counts for it
    Given the saved views database runs:
      """
      insert into posts (title, slug, status, published_at, body, body_html, read_time, word_count, webmentions_enabled)
      values ('Hello', 'hello', 'published', '{today} 09:00 America/Chicago', 'Body', '<p>Body</p>', 1, 1, false);
      insert into analytics_rollups (day) values ('{today}');
      insert into analytics_rollup_paths (day, path, views, visitors, bounces) values ('{today}', '/writing/hello', 12, 8, 2);
      insert into saved_views (name, screen, filters) values ('Posts', 'activity', '{"types": {"post": "1"}}');
      """
    When I read the records of saved view 1
    Then the saved view records' "records.0" holds:
      """
      {"link": "/writing/hello", "views": 12}
      """

  Scenario: An activity view gives a finished work session its task and the seconds it ran
    Given the saved views database runs:
      """
      insert into tasks (title, list, position) values ('Write it', 'next', 1);
      insert into tags (name, color, scope) values ('ops', 'mk-blue', 'private');
      insert into task_tags (task_id, tag_id) values (1, 1);
      insert into work_sessions (task_id, started_at, ended_at)
      values (1, '{today} 09:00 America/Chicago', '{today} 10:00 America/Chicago');
      insert into saved_views (name, screen, filters) values ('Sessions', 'activity', '{"types": {"session": "1"}}');
      """
    When I read the records of saved view 1
    Then the saved view records' "records.0" holds:
      """
      {"name": "Write it", "task_id": 1, "worked_seconds": 3600, "tags": ["ops"]}
      """

  Scenario: An activity view gives a decision event its decision, what happened and why
    Given the saved views database runs:
      """
      insert into decisions (title, problem) values ('Pick a queue', 'Jobs pile up');
      insert into decision_events (decision_id, kind, reason, created_at)
      values (1, 'dropped', 'Not needed', '{today} 09:00 America/Chicago');
      insert into saved_views (name, screen, filters) values ('Decisions', 'activity', '{"types": {"decision": "1"}}');
      """
    When I read the records of saved view 1
    Then the saved view records' "records.0" holds:
      """
      {"name": "Pick a queue", "status": "dropped", "excerpt": "Not needed", "decision_id": 1}
      """

  Scenario: An activity view gives a comment on a decision its text and the decision's title
    Given the saved views database runs:
      """
      insert into decisions (title, problem) values ('Pick a queue', 'Jobs pile up');
      insert into decision_comments (decision_id, body, created_at)
      values (1, 'Leaning on Sidekiq', '{today} 09:00 America/Chicago');
      insert into saved_views (name, screen, filters)
      values ('Comments', 'activity', '{"types": {"decision_comment": "1"}}');
      """
    When I read the records of saved view 1
    Then the saved view records' "records.0" holds:
      """
      {"name": "Leaning on Sidekiq", "excerpt": "Pick a queue", "decision_id": 1}
      """

  Scenario: An activity view starts from its saved day and pages back by continue_to
    Given the saved views database runs:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
      select 'a' || n, 'aaronmallen/aaronmallen.me', 'main', 'day 1', '{today-1}', '09:00' from generate_series(1, 100) n;
      insert into commits (sha, repo, branch, message, commit_date, commit_time) values
        ('b0', 'aaronmallen/aaronmallen.me', 'main', 'day 0', '{today}', '09:00'),
        ('b2', 'aaronmallen/aaronmallen.me', 'main', 'day 2', '{today-2}', '09:00');
      insert into saved_views (name, screen, filters) values ('Back', 'activity', '{"day": "{today-1}"}');
      """
    When I read the records of saved view 1
    Then the saved view records' "count" is "100"
    And the saved view records' "records.0.name" is "day 1"
    And the saved view records' "continue_to" is "{today-2}"
    When I read the next window of saved view 1
    Then the saved view records give the names "day 2"

  Scenario: An activity view covers the days and kinds the admin screen shows for the same filters
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read"
    And the saved views database runs:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time) values
        ('a11', 'aaronmallen/aaronmallen.me', 'main', 'commit 11', '{today-11}', '09:00'),
        ('a12', 'aaronmallen/aaronmallen.me', 'main', 'commit 12', '{today-12}', '09:00'),
        ('a15', 'aaronmallen/aaronmallen.me', 'main', 'commit 15', '{today-15}', '09:00'),
        ('a31', 'aaronmallen/aaronmallen.me', 'main', 'commit 31', '{today-31}', '09:00');
      insert into journal_entries (entry_date, entry_time, body, body_html) values
        ('{today-14}', '09:00', 'journal 14', '<p>journal 14</p>');
      insert into posts (title, slug, status, published_at, body, body_html, read_time, word_count, webmentions_enabled)
      values ('post 13', 'post-13', 'published', '{today-13} 12:00 America/Chicago', 'Body', '<p>Body</p>', 1, 1, false);
      insert into saved_views (name, screen, filters) values ('Window', 'activity',
        '{"from": "{today-30}", "to": "{today-10}", "day": "{today-12}", "types": {"commit": "1", "journal": "1"}}');
      """
    Then the activity screen and saved view 1 both show:
      | {today-12} | commit 12  |
      | {today-14} | journal 14 |
      | {today-15} | commit 15  |

  Scenario: A filter the screen no longer knows reads as if left at its default, and stays stored
    Given the saved views database runs:
      """
      insert into posts (title, slug, status, body, body_html, read_time, word_count, webmentions_enabled)
      values ('Draft', 'draft', 'draft', 'Body', '<p>Body</p>', 1, 1, false);
      insert into posts (title, slug, status, published_at, body, body_html, read_time, word_count, webmentions_enabled)
      values ('Out', 'out', 'published', now() - interval '1 day', 'Body', '<p>Body</p>', 1, 1, false);
      insert into saved_views (name, screen, filters) values ('Stale', 'posts', '{"state": "draft"}');
      insert into saved_views (name, screen, filters) values ('Mixed', 'posts', '{"status": "draft", "tag": "ruby"}');
      """
    When I read the records of saved view 1
    Then the saved view records' "count" is "2"
    And the saved view records' "saved_view.filters" is:
      """
      {}
      """
    When I read the records of saved view 2
    Then the database answers '{"tag": "ruby", "status": "draft"}' for:
      """
      select filters::text from saved_views where id = 2
      """

  Scenario: A value the screen no longer takes falls back to the default
    Given the saved views database runs:
      """
      insert into sprints (sprint_date) values ('{today}');
      insert into tasks (title, list, sprint_id, position) values ('In the sprint', null, 1, 1), ('Loose', 'next', null, 2);
      insert into saved_views (name, screen, filters) values ('Inbox', 'tasks', '{"filter": "inbox"}');
      """
    When I read the records of saved view 1
    Then the saved view records give the ids "1"

  Scenario: A missing view answers 404
    When I read the records of saved view 999999
    Then the saved view records answer 404
    And the saved view records' "" is:
      """
      {"error": "not_found", "message": "no saved view has the ID 999999"}
      """

  Scenario: A continue_to that is not a day answers 422
    Given a saved view "Any" on the tasks screen
    When I read the records of saved view 1 with "?continue_to=soon"
    Then the saved view records answer 422
    And the saved view records' "errors" is:
      """
      {"continue_to": ["give continue_to as a day, such as 2026-01-01"]}
      """

  Scenario: The read_saved_view tool answers each kind of view as the endpoint does
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read"
    And the saved views database runs:
      """
      insert into tasks (title, list, position) values ('Tagged', 'next', 1);
      insert into tags (name, color, scope) values ('ops', 'mk-blue', 'private'), ('ruby', 'mk-blue', 'public');
      insert into task_tags (task_id, tag_id) values (1, 1);
      insert into posts (title, slug, status, body, body_html, read_time, word_count, webmentions_enabled)
      values ('Draft', 'draft', 'draft', 'Body', '<p>Body</p>', 1, 1, false);
      insert into post_tags (post_id, tag_id) values (1, 2);
      insert into posts (title, slug, status, published_at, body, body_html, read_time, word_count, webmentions_enabled)
      values ('Hello', 'hello', 'published', '{today} 09:00 America/Chicago', 'Body', '<p>Body</p>', 1, 1, false);
      insert into analytics_rollups (day) values ('{today}');
      insert into analytics_rollup_paths (day, path, views, visitors, bounces) values ('{today}', '/writing/hello', 12, 8, 2);
      insert into journal_entries (entry_date, entry_time, body, body_html) values ('{today}', '09:00', 'a run', '<p>a run</p>');
      insert into commits (sha, repo, branch, message, commit_date, commit_time) values
        ('a1', 'aaronmallen/aaronmallen.me', 'main', 'Ship it', '{today}', '09:00');
      insert into saved_views (name, screen, filters) values
        ('Activity', 'activity', '{"types": {"commit": "1", "post": "1"}}'),
        ('Journal', 'journal', '{"q": "run"}'),
        ('Posts', 'posts', '{"status": "draft"}'),
        ('Tasks', 'tasks', '{"filter": "next"}');
      """
    Then the read_saved_view tool answers saved view 1 as the endpoint does, given:
      """
      {"id": 1}
      """
    And the read_saved_view tool answers saved view 2 as the endpoint does, given:
      """
      {"id": 2}
      """
    And the read_saved_view tool answers saved view 3 as the endpoint does, given:
      """
      {"id": 3}
      """
    And the read_saved_view tool answers saved view 4 as the endpoint does, given:
      """
      {"id": 4}
      """

  Scenario: The read_saved_view tool keeps a completed view to its range of days
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read"
    And the saved views database runs:
      """
      insert into tasks (title, list, status, completed_at, position) values
        ('Inside', 'next', 'done', '{today-3} 12:00 America/Chicago', 1),
        ('Outside', 'next', 'done', '{today-1} 12:00 America/Chicago', 2);
      insert into saved_views (name, screen, filters)
      values ('Range', 'tasks', '{"filter": "completed", "from": "{today-4}", "to": "{today-3}"}');
      """
    Then the read_saved_view tool gives saved view 1 the ids "1"

  Scenario: The read_saved_view tool pages as the endpoint does
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read"
    And the saved views database runs:
      """
      insert into tasks (title, list, position) select 'Task ' || n, 'next', n from generate_series(1, 101) n;
      insert into saved_views (name, screen, filters) values ('Next', 'tasks', '{"filter": "next"}');
      """
    Then the read_saved_view tool answers saved view 1 as the endpoint does, given:
      """
      {"id": 1, "page": 2}
      """

  Scenario: The read_saved_view tool refuses a missing view as an error with the endpoint's message
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read"
    Then the read_saved_view tool refuses saved view 999999 with the message the endpoint gives
