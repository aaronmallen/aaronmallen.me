Feature: Admin live tables
  Each admin page names the tables it draws, so the event stream can tell it when to refresh. The top bar reads
  tasks and mail, so every page names those.

  Background:
    Given I am signed in to the admin
    And the database runs:
      """
      INSERT INTO decisions (title, problem) VALUES ('Pick a queue', 'Jobs pile up');
      INSERT INTO projects (name, visibility, key) VALUES ('Blog', 'public', 'BLOG');
      INSERT INTO posts (title, slug, body, body_html, status, read_time, word_count)
        VALUES ('Hello', 'hello', 'Hi.', '<p>Hi.</p>', 'draft', 1, 1);
      INSERT INTO tasks (title, position, list) VALUES ('Ship it', 1, 'next');
      INSERT INTO commits (sha, repo, branch, message, commit_date, commit_time)
        VALUES ('abc1234', 'aaronmallen/blog', 'main', 'app: ship it', current_date, '09:00');
      INSERT INTO pull_requests (repo, number, title, url, opened_at)
        VALUES ('aaronmallen/blog', 7, 'Ship it', 'https://github.com/aaronmallen/blog/pull/7', now());
      INSERT INTO tags (name, color, scope) VALUES ('ruby', 'mk-blue', 'public');
      INSERT INTO people (name) VALUES ('Ada');
      INSERT INTO short_codes (code) VALUES ('files'), ('link'), ('file');
      INSERT INTO share_groups (short_code_id) VALUES (1);
      INSERT INTO share_group_files (short_code_id, key, filename, content_type, byte_size)
        VALUES (3, md5('a'), 'a.txt', 'text/plain', 1);
      INSERT INTO short_links (short_code_id, destination) VALUES (2, 'https://example.com');
      INSERT INTO agent_sessions (title, agent, model) VALUES ('Spike', 'claude-code', 'claude-opus-5-5');
      INSERT INTO memory_files (path, scope, description) VALUES ('hanami.md', 'global', 'Notes');
      INSERT INTO artifacts (title, type) VALUES ('Plan', 'plan');
      INSERT INTO artifact_versions (artifact_id, number, body) VALUES (1, 1, 'Do it');
      INSERT INTO notes (title) VALUES ('Groceries');
      INSERT INTO note_folders (name) VALUES ('Home');
      """

  Scenario: Every live page names the tasks and mail tables
    Then each of these admin pages answers 200 and lists the live tables "tasks mail_threads":
      | /admin                               |
      | /admin/activity                      |
      | /admin/agents/artifacts              |
      | /admin/agents/artifacts/new          |
      | /admin/agents/memories               |
      | /admin/agents/sessions               |
      | /admin/analytics                     |
      | /admin/calendar                      |
      | /admin/contacts                      |
      | /admin/decisions                     |
      | /admin/decisions/new                 |
      | /admin/files                         |
      | /admin/health                        |
      | /admin/inbox                         |
      | /admin/journal                       |
      | /admin/links                         |
      | /admin/mail                          |
      | /admin/mail/settings                 |
      | /admin/notes                         |
      | /admin/contacts/new                  |
      | /admin/performance                   |
      | /admin/performance/requests          |
      | /admin/posts                         |
      | /admin/posts/new                     |
      | /admin/projects                      |
      | /admin/projects/new                  |
      | /admin/review                        |
      | /admin/search                        |
      | /admin/settings/jobs                 |
      | /admin/settings/security             |
      | /admin/settings/services             |
      | /admin/settings/webmentions          |
      | /admin/settings/tagging              |
      | /admin/social                        |
      | /admin/tasks                         |
      | /admin/tasks/new                     |
      | /admin/time                          |
      | /admin/webmentions                   |
      | /admin/decisions/1                   |
      | /admin/decisions/1/edit              |
      | /admin/projects/1                    |
      | /admin/projects/1/edit               |
      | /admin/posts/1/edit                  |
      | /admin/posts/1/analytics             |
      | /admin/tasks/1                       |
      | /admin/tasks/1/edit                  |
      | /admin/commits/1                     |
      | /admin/pull-requests/1               |
      | /admin/tags/ruby                     |
      | /admin/contacts/1                    |
      | /admin/contacts/1/edit               |
      | /admin/files/1/edit                  |
      | /admin/files/groups/1/edit           |
      | /admin/links/1/edit                  |
      | /admin/agents/sessions?session=1     |
      | /admin/agents/memories/1             |
      | /admin/agents/artifacts/1            |
      | /admin/agents/artifacts/1/edit       |
      | /admin/notes/1                       |
      | /admin/notes/1?edit=1                |
      | /admin/notes/folders/1               |
    And each live table those pages list carries the admin change trigger

  Scenario: A page nothing lives at names the tasks table
    When I visit "/admin/nowhere"
    Then the main element lists the live tables "tasks"

  Scenario: A form the CSRF check turns away names the tasks table
    When I post to "/admin/tags" with a wrong CSRF token
    Then the main element lists the live tables "tasks"

  Scenario: The calendar names the tables it draws beside the top bar's, and not the commits
    When I visit "/admin/calendar"
    Then the main element lists the live tables "calendar_events task_tags tasks"
    And the main element leaves out the live table "commits"

  Scenario: The tagging tab names the tables of the tags and the task rules
    When I visit "/admin/settings/tagging"
    Then the main element lists the live tables "post_tags task_tags task_rules task_rule_projects projects"

  Scenario: The webmentions tab names the tables of the webmention settings
    When I visit "/admin/settings/webmentions"
    Then the main element lists the live tables "posts trusted_authors webmention_settings"

  Scenario: The connected services tab names the tables of the services and the MCP clients
    When I visit "/admin/settings/services"
    Then the main element lists the live tables "service_connections sync_states webmention_settings oauth_clients oauth_tokens"

  Scenario: The jobs tab names only the tables the settings head and the top bar read
    When I visit "/admin/settings/jobs"
    Then the main element lists only the live tables of a page nothing lives at and "service_connections task_rules"
