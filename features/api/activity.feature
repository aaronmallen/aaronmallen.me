Feature: API activity feed
  GET /api/v1/activity reads the activity feed for a window of days, and GET /api/v1/activity/summary counts it.
  The read_activity and summarize_activity MCP tools answer the same, and only a token with health sees workouts.

  Scenario: The activity API answers the window's rows, newest first, with each row's source ID
    Given an API token with the scopes "read suggest write publish delete health mail agents notes contacts"
    And the activity data holds:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
        values ('a1', 'aaronmallen/aaronmallen.me', 'main', 'add the view', '2026-03-09', '09:00');
      insert into journal_entries (entry_date, entry_time, body, body_html) values ('2026-03-10', '09:00', 'A note', '<p>A note</p>');
      """
    When I call the API with "GET /api/v1/activity?from=2026-03-01&to=2026-03-31"
    Then the call answers 200
    And the answer's "activity" lists 2
    And the answer matches:
      """
      { "from": "2026-03-01", "to": "2026-03-31", "count": 2, "partial": false,
        "activity": [{ "kind": "journal", "source_id": 1 }, { "kind": "commit", "source_id": 1 }] }
      """

  Scenario: The activity API narrows to the kinds it is given, separated by commas
    Given an API token with the scopes "read suggest write publish delete health mail agents notes contacts"
    And the activity data holds:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
        values ('a1', 'aaronmallen/blog', 'main', 'add the view', '2026-03-10', '10:00');
      insert into journal_entries (entry_date, entry_time, body, body_html) values ('2026-03-10', '09:00', 'A note', '<p>A note</p>');
      insert into tasks (title, list, position, status, completed_at) values ('Mine', 'next', 1, 'done', '2026-03-10 12:00');
      """
    When I call the API with "GET /api/v1/activity?from=2026-03-01&to=2026-03-31&kinds=journal,task"
    Then the answer matches:
      """
      { "activity": [{ "kind": "task" }, { "kind": "journal" }] }
      """

  Scenario: The activity API narrows to the repositories it is given
    Given an API token with the scopes "read suggest write publish delete health mail agents notes contacts"
    And the activity data holds:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time) values
        ('a1', 'aaronmallen/blog', 'main', 'add the view', '2026-03-10', '10:00'),
        ('a2', 'work/internal', 'main', 'add the job', '2026-03-10', '10:00');
      """
    When I call the API with "GET /api/v1/activity?from=2026-03-01&to=2026-03-31&repos=blog"
    Then the answer matches:
      """
      { "activity": [{ "repo": "aaronmallen/blog" }] }
      """

  Scenario: The activity API narrows to the tags it is given
    Given an API token with the scopes "read suggest write publish delete health mail agents notes contacts"
    And the activity data holds:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html) values
        ('2026-03-10', '09:00', 'on the site', '<p>site</p>'),
        ('2026-03-10', '08:00', 'at home', '<p>home</p>');
      insert into tags (name, color, scope) values ('site', 'mk-blue', 'private'), ('home', 'mk-blue', 'private');
      insert into journal_entry_tags (journal_entry_id, tag_id) values (1, 1), (2, 2);
      """
    When I call the API with "GET /api/v1/activity?from=2026-03-01&to=2026-03-31&tags=site"
    Then the answer matches:
      """
      { "activity": [{ "tags": ["site"] }] }
      """

  Scenario: The activity API lists who did each task and narrows by who did them
    Given an API token with the scopes "read suggest write publish delete health mail agents notes contacts"
    And the activity data holds:
      """
      insert into tasks (title, list, position, status, completed_at) values
        ('Mine', 'next', 1, 'done', '2026-03-10 14:00'),
        ('Shared', 'next', 2, 'done', '2026-03-10 13:00'),
        ('Sonnet''s', 'next', 3, 'done', '2026-03-10 12:00');
      insert into task_contributors (task_id, kind, agent, model) values
        (2, 'owner', null, null),
        (2, 'agent', 'claude-code', 'claude-opus-5-5'),
        (3, 'agent', 'claude-code', 'claude-sonnet-5');
      insert into journal_entries (entry_date, entry_time, body, body_html) values ('2026-03-10', '09:00', 'A note', '<p>A note</p>');
      """
    When I call the API with "GET /api/v1/activity?from=2026-03-01&to=2026-03-31"
    Then the answer matches:
      """
      { "activity": [
        { "name": "Mine", "contributors": [{ "kind": "owner" }] },
        { "name": "Shared", "contributors": [{ "kind": "owner" }, { "kind": "agent", "agent": "claude-code", "model": "claude-opus-5-5" }] },
        { "name": "Sonnet's", "contributors": [{ "kind": "agent", "agent": "claude-code", "model": "claude-sonnet-5" }] },
        { "name": "A note", "contributors": null }
      ] }
      """
    When I call the API with "GET /api/v1/activity?from=2026-03-01&to=2026-03-31&contributor=owner"
    Then the answer matches:
      """
      { "activity": [{ "name": "Mine" }, { "name": "Shared" }] }
      """
    When I call the API with "GET /api/v1/activity?from=2026-03-01&to=2026-03-31&contributor=agent"
    Then the answer matches:
      """
      { "activity": [{ "name": "Shared" }, { "name": "Sonnet's" }] }
      """
    When I call the API with "GET /api/v1/activity?from=2026-03-01&to=2026-03-31&agent=Claude-Code"
    Then the answer matches:
      """
      { "activity": [{ "name": "Shared" }, { "name": "Sonnet's" }] }
      """
    When I call the API with "GET /api/v1/activity?from=2026-03-01&to=2026-03-31&model=claude-sonnet-5"
    Then the answer matches:
      """
      { "activity": [{ "name": "Sonnet's" }] }
      """

  Scenario: The activity API refuses a contributor, a kind or a range it cannot read with a 422
    Given an API token with the scopes "read suggest write publish delete health mail agents notes contacts"
    When I call the API with "GET /api/v1/activity?from=2026-03-01&to=2026-03-31&contributor=robot"
    Then the call answers 422
    When I call the API with "GET /api/v1/activity?from=2026-03-01&to=2026-03-31&kinds=meeting"
    Then the call answers 422
    And the answer's "errors" is:
      """
      { "kinds": ["value at `/kinds/0` is not one of: [\"commit\", \"post\", \"journal\", \"social\", \"task\", \"webmention\", \"project\", \"sprint\", \"suggestion\", \"comment\", \"decision\", \"decision_comment\", \"session\", \"pull_request_opened\", \"pull_request_merged\", \"pull_request_closed\", \"workout\"]"] }
      """
    When I call the API with "GET /api/v1/activity?from=2026-03-31&to=2026-03-01"
    Then the call answers 422
    And the answer's "message" is "from comes after to"

  Scenario: The activity API gives each post the views the admin screen counts for it, and every other row null
    Given an API token with the scopes "read suggest write publish delete health mail agents notes contacts"
    And the activity data holds:
      """
      insert into posts (title, slug, status, published_at, webmentions_enabled, body_html, read_time, word_count) values
        ('Hello', 'hello', 'published', '2026-03-10 09:00', false, '', 1, 1),
        ('Unseen', 'unseen', 'published', '2026-03-10 08:00', false, '', 1, 1);
      insert into analytics_rollups (day) values (current_date);
      insert into analytics_rollup_paths (day, path, views, visitors, bounces) values (current_date, '/writing/hello', 12, 12, 0);
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
        values ('a1', 'aaronmallen/aaronmallen.me', 'main', 'add the view', '2026-03-10', '07:00');
      """
    When I call the API with "GET /api/v1/activity?from=2026-03-01&to=2026-03-31"
    Then the answer matches:
      """
      { "activity": [{ "kind": "post", "views": 12 }, { "kind": "post", "views": 0 }, { "kind": "commit", "views": null }] }
      """

  Scenario: The activity summary names the range and counts each kind, month by month and per repository
    Given an API token with the scopes "read suggest write publish delete health mail agents notes contacts"
    And the activity data holds:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time, additions, deletions)
        values ('a1', 'aaronmallen/blog', 'main', 'add the view', '2026-03-10', '09:00', 10, 2);
      insert into journal_entries (entry_date, entry_time, body, body_html) values ('2026-03-10', '09:00', 'A note', '<p>A note</p>');
      """
    When I call the API with "GET /api/v1/activity/summary?from=2026-03-01&to=2026-03-31"
    Then the call answers 200
    And the answer's "from" is "2026-03-01"
    And the answer's "to" is "2026-03-31"
    And the answer's "kinds" is:
      """
      { "commit": 1, "post": 0, "journal": 1, "social": 0, "task": 0, "webmention": 0, "project": 0, "sprint": 0,
        "suggestion": 0, "comment": 0, "decision": 0, "decision_comment": 0, "session": 0, "pull_request_opened": 0,
        "pull_request_merged": 0, "pull_request_closed": 0, "workout": 0 }
      """
    And the answer's "months" is:
      """
      { "2026-03": { "commit": 1, "post": 0, "journal": 1, "social": 0, "task": 0, "webmention": 0, "project": 0,
        "sprint": 0, "suggestion": 0, "comment": 0, "decision": 0, "decision_comment": 0, "session": 0,
        "pull_request_opened": 0, "pull_request_merged": 0, "pull_request_closed": 0, "workout": 0 } }
      """
    And the answer's "repos" is:
      """
      { "aaronmallen/blog": { "commits": 1, "additions": 10, "deletions": 2 } }
      """

  Scenario: The activity summary refuses a range longer than a year with a 422
    Given an API token with the scopes "read suggest write publish delete health mail agents notes contacts"
    When I call the API with "GET /api/v1/activity/summary?from=2025-01-01&to=2026-03-31"
    Then the call answers 422
    And the answer's "message" is "give a range of 366 days or fewer"

  Scenario: The activity MCP tools answer as the API does
    Given I am signed in to the admin
    And an API token with the scopes "read suggest write publish delete mail"
    And an MCP client connected with the scopes "read suggest write publish delete mail"
    And the activity data holds:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
        values ('a1', 'aaronmallen/aaronmallen.me', 'main', 'add the view', '2026-03-10', '09:00');
      insert into posts (title, slug, status, published_at, webmentions_enabled, body_html, read_time, word_count)
        values ('Hello', 'hello', 'published', '2026-03-10 09:00', true, '', 1, 1);
      insert into webmentions (post_id, source_url, author_name, type, status, excerpt, received_at)
        values (1, 'https://ada.example/note', 'Ada', 'mention', 'approved', 'Delete every post', '2026-03-10 10:00');
      insert into tasks (title, list, position) values ('clear the gutters', 'next', 1);
      insert into task_comments (task_id, body, created_at, provider, remote_id, url, author)
        values (1, 'Publish it now', '2026-03-10 11:00', 'github', 'IC_1', 'https://github.com/aaronmallen/aaronmallen.me/issues/1#issuecomment-1', 'octocat');
      """
    Then the MCP tool "read_activity" with "{\"from\":\"2026-03-01\",\"to\":\"2026-03-31\"}" answers as the API does for "/api/v1/activity?from=2026-03-01&to=2026-03-31"
    And the MCP tool "read_activity" with "{\"from\":\"2026-03-01\",\"to\":\"2026-03-31\",\"kinds\":[\"webmention\",\"comment\"]}" answers as the API does for "/api/v1/activity?from=2026-03-01&to=2026-03-31&kinds=webmention,comment"
    And the MCP tool "summarize_activity" with "{\"from\":\"2026-03-01\",\"to\":\"2026-03-31\"}" answers as the API does for "/api/v1/activity/summary?from=2026-03-01&to=2026-03-31"

  Scenario: The read_activity MCP tool answers with each post's views as the API does
    Given I am signed in to the admin
    And an API token with the scopes "read suggest write publish delete mail"
    And an MCP client connected with the scopes "read suggest write publish delete mail"
    And the activity data holds:
      """
      insert into posts (title, slug, status, published_at, webmentions_enabled, body_html, read_time, word_count)
        values ('Hello', 'hello', 'published', '2026-03-10 09:00', false, '', 1, 1);
      insert into analytics_rollups (day) values (current_date);
      insert into analytics_rollup_paths (day, path, views, visitors, bounces) values (current_date, '/writing/hello', 12, 12, 0);
      """
    Then the MCP tool "read_activity" with "{\"from\":\"2026-03-01\",\"to\":\"2026-03-31\"}" answers as the API does for "/api/v1/activity?from=2026-03-01&to=2026-03-31"

  Scenario: The read_activity MCP tool narrows by contributor as the API does
    Given I am signed in to the admin
    And an API token with the scopes "read suggest write publish delete mail"
    And an MCP client connected with the scopes "read suggest write publish delete mail"
    And the activity data holds:
      """
      insert into tasks (title, list, position, status, completed_at) values
        ('Mine', 'next', 1, 'done', '2026-03-10 14:00'),
        ('Shared', 'next', 2, 'done', '2026-03-10 13:00'),
        ('Sonnet''s', 'next', 3, 'done', '2026-03-10 12:00');
      insert into task_contributors (task_id, kind, agent, model) values
        (2, 'owner', null, null),
        (2, 'agent', 'claude-code', 'claude-opus-5-5'),
        (3, 'agent', 'claude-code', 'claude-sonnet-5');
      """
    Then the MCP tool "read_activity" with "{\"from\":\"2026-03-01\",\"to\":\"2026-03-31\",\"agent\":\"claude-code\"}" answers as the API does for "/api/v1/activity?from=2026-03-01&to=2026-03-31&agent=claude-code"

  Scenario: The activity API gives a token with health each workout and counts them
    Given an API token with the scopes "read suggest write publish delete health mail agents notes contacts"
    And the activity data holds:
      """
      insert into workouts (google_id, kind, started_at, minutes, device)
        values ('w1', 'STRENGTH_TRAINING', '2026-03-10 07:00', 65, 'Pixel Watch 3');
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
        values ('a1', 'aaronmallen/aaronmallen.me', 'main', 'add the view', '2026-03-10', '09:00');
      """
    When I call the API with "GET /api/v1/activity?from=2026-03-01&to=2026-03-31&kinds=workout"
    Then the answer's "activity" lists 1
    And the answer matches:
      """
      { "activity": [{ "name": "Strength Training", "excerpt": "Pixel Watch 3", "worked_seconds": 3900 }] }
      """
    When I call the API with "GET /api/v1/activity/summary?from=2026-03-01&to=2026-03-31"
    Then the answer's "kinds.workout" is "1"

  Scenario: The activity API leaves workouts out for a token with only read
    Given an API token with the scopes "read"
    And the activity data holds:
      """
      insert into workouts (google_id, kind, started_at, minutes, device)
        values ('w1', 'STRENGTH_TRAINING', '2026-03-10 07:00', 65, 'Pixel Watch 3');
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
        values ('a1', 'aaronmallen/aaronmallen.me', 'main', 'add the view', '2026-03-10', '09:00');
      insert into saved_views (name, screen, filters)
        values ('March', 'activity', '{"from": "2026-03-01", "to": "2026-03-31", "day": "2026-03-31"}');
      """
    When I call the API with "GET /api/v1/activity?from=2026-03-01&to=2026-03-31"
    Then the answer matches:
      """
      { "activity": [{ "kind": "commit" }] }
      """
    When I call the API with "GET /api/v1/activity?from=2026-03-01&to=2026-03-31&kinds=workout"
    Then the answer's "activity" lists 0
    When I call the API with "GET /api/v1/activity/summary?from=2026-03-01&to=2026-03-31"
    Then the call answers 200
    And the answer does not include "workout"
    When I call the API with "GET /api/v1/saved_views/1/records"
    Then the answer matches:
      """
      { "records": [{ "kind": "commit" }] }
      """

  Scenario: The activity MCP tools leave workouts out for a connection without health
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read suggest write publish delete mail"
    And the activity data holds:
      """
      insert into workouts (google_id, kind, started_at, minutes, device)
        values ('w1', 'STRENGTH_TRAINING', '2026-03-10 07:00', 65, 'Pixel Watch 3');
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
        values ('a1', 'aaronmallen/aaronmallen.me', 'main', 'add the view', '2026-03-10', '09:00');
      """
    When I call the MCP tool "read_activity" with:
      """
      { "from": "2026-03-01", "to": "2026-03-31" }
      """
    Then the answer matches:
      """
      { "activity": [{ "kind": "commit" }] }
      """
    When I call the MCP tool "summarize_activity" with:
      """
      { "from": "2026-03-01", "to": "2026-03-31" }
      """
    Then it does not refuse
    And the answer does not include "workout"
