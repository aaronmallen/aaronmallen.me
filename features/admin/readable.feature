Feature: Admin screens read well
  Every admin screen passes axe in light and dark, lets the Tab key reach each control in order behind a focus
  ring, and holds to the desk and the phone it is read on: nothing wider than a phone, no tap target under 44px
  and no text under 12px there, and no font preloaded that the page never draws.

  Background:
    Given I am signed in to the admin
    And the database runs:
      """
      INSERT INTO decisions (title, problem) VALUES ('Pick a queue', 'Jobs pile up');
      INSERT INTO projects (name, visibility, key) VALUES ('Blog', 'public', 'BLOG');
      INSERT INTO posts (title, slug, body, body_html, status, read_time, word_count)
        VALUES ('A draft in progress', 'a-draft-in-progress', 'Hi.', '<p>Hi.</p>', 'draft', 1, 1);
      INSERT INTO tasks (title, position, list) VALUES ('Ship it', 1, 'next');
      INSERT INTO commits (sha, repo, branch, message, commit_date, commit_time)
        VALUES ('abc1234', 'aaronmallen/blog', 'main', 'app: ship it', current_date, '09:00');
      INSERT INTO pull_requests (repo, number, title, url, opened_at)
        VALUES ('aaronmallen/blog', 7, 'Ship it', 'https://github.com/aaronmallen/blog/pull/7', now());
      INSERT INTO tags (name, color, scope) VALUES ('ruby', 'mk-blue', 'public');
      INSERT INTO people (name, key) VALUES ('Ada Lovelace', 'ada-lovelace');
      INSERT INTO short_codes (code) VALUES ('files'), ('link'), ('file');
      INSERT INTO share_groups (short_code_id) VALUES (1);
      INSERT INTO share_group_files (short_code_id, key, filename, content_type, byte_size)
        VALUES (3, md5('a'), 'a.txt', 'text/plain', 1);
      INSERT INTO short_links (short_code_id, destination) VALUES (2, 'https://example.com');
      INSERT INTO agent_sessions (title, agent, model) VALUES ('Spike', 'claude-code', 'claude-opus-5-5');
      INSERT INTO memory_files (path, scope, description) VALUES ('hanami.md', 'global', 'Notes');
      INSERT INTO artifacts (title, type) VALUES ('Plan', 'plan');
      INSERT INTO artifact_versions (artifact_id, number, body) VALUES (1, 1, 'Do it');
      INSERT INTO note_folders (name) VALUES ('work');
      INSERT INTO notes (title, body, folder_id, pinned) VALUES ('Plan the quarter', 'Ship **it**', 1, true);
      """

  Scenario Outline: An admin screen passes axe in light and dark
    When I visit "<route>"
    Then the page has no axe breaches in light or dark

    Examples:
      | route                            |
      | /admin                           |
      | /admin/activity                  |
      | /admin/agents/artifacts          |
      | /admin/agents/artifacts/new      |
      | /admin/agents/memories           |
      | /admin/agents/sessions           |
      | /admin/analytics                 |
      | /admin/calendar                  |
      | /admin/contacts                  |
      | /admin/contacts/new              |
      | /admin/decisions                 |
      | /admin/decisions/new             |
      | /admin/files                     |
      | /admin/health                    |
      | /admin/inbox                     |
      | /admin/journal                   |
      | /admin/links                     |
      | /admin/mail                      |
      | /admin/mail/settings             |
      | /admin/notes                     |
      | /admin/performance               |
      | /admin/performance/requests      |
      | /admin/posts                     |
      | /admin/posts/new                 |
      | /admin/projects                  |
      | /admin/projects/new              |
      | /admin/review                    |
      | /admin/search                    |
      | /admin/settings/jobs             |
      | /admin/settings/security         |
      | /admin/settings/services         |
      | /admin/settings/webmentions      |
      | /admin/settings/tagging          |
      | /admin/social                    |
      | /admin/tasks                     |
      | /admin/tasks/new                 |
      | /admin/time                      |
      | /admin/webmentions               |
      | /admin/decisions/1               |
      | /admin/decisions/1/edit          |
      | /admin/projects/1                |
      | /admin/projects/1/edit           |
      | /admin/posts/1/edit              |
      | /admin/posts/1/analytics         |
      | /admin/tasks/1                   |
      | /admin/tasks/1/edit              |
      | /admin/commits/1                 |
      | /admin/pull-requests/1           |
      | /admin/tags/ruby                 |
      | /admin/contacts/1                |
      | /admin/contacts/1/edit           |
      | /admin/files/1/edit              |
      | /admin/files/groups/1/edit       |
      | /admin/links/1/edit              |
      | /admin/agents/sessions?session=1 |
      | /admin/agents/memories/1         |
      | /admin/agents/artifacts/1        |
      | /admin/agents/artifacts/1/edit   |
      | /admin/notes/1                   |
      | /admin/notes/folders/1           |

  Scenario Outline: The Tab key reaches every control on an admin screen in order behind a ring
    When I visit "<route>"
    Then Tab reaches every control in order behind a ring

    Examples:
      | route                            |
      | /admin                           |
      | /admin/activity                  |
      | /admin/agents/artifacts          |
      | /admin/agents/artifacts/new      |
      | /admin/agents/memories           |
      | /admin/agents/sessions           |
      | /admin/analytics                 |
      | /admin/calendar                  |
      | /admin/contacts                  |
      | /admin/contacts/new              |
      | /admin/decisions                 |
      | /admin/decisions/new             |
      | /admin/files                     |
      | /admin/health                    |
      | /admin/inbox                     |
      | /admin/journal                   |
      | /admin/links                     |
      | /admin/mail                      |
      | /admin/mail/settings             |
      | /admin/notes                     |
      | /admin/performance               |
      | /admin/performance/requests      |
      | /admin/posts                     |
      | /admin/posts/new                 |
      | /admin/projects                  |
      | /admin/projects/new              |
      | /admin/review                    |
      | /admin/search                    |
      | /admin/settings/jobs             |
      | /admin/settings/security         |
      | /admin/settings/services         |
      | /admin/settings/webmentions      |
      | /admin/settings/tagging          |
      | /admin/social                    |
      | /admin/tasks                     |
      | /admin/tasks/new                 |
      | /admin/time                      |
      | /admin/webmentions               |
      | /admin/decisions/1               |
      | /admin/decisions/1/edit          |
      | /admin/projects/1                |
      | /admin/projects/1/edit           |
      | /admin/posts/1/edit              |
      | /admin/posts/1/analytics         |
      | /admin/tasks/1                   |
      | /admin/tasks/1/edit              |
      | /admin/commits/1                 |
      | /admin/pull-requests/1           |
      | /admin/tags/ruby                 |
      | /admin/contacts/1                |
      | /admin/contacts/1/edit           |
      | /admin/files/1/edit              |
      | /admin/files/groups/1/edit       |
      | /admin/links/1/edit              |
      | /admin/agents/sessions?session=1 |
      | /admin/agents/memories/1         |
      | /admin/agents/artifacts/1        |
      | /admin/agents/artifacts/1/edit   |
      | /admin/notes/1                   |
      | /admin/notes/folders/1           |

  Scenario Outline: An admin screen holds to the desk and the phone
    Given I read the admin on a <device>
    When I visit "<route>"
    Then the screen holds to the size it is read on

    Examples:
      | device | route                            |
      | desk   | /admin                           |
      | desk   | /admin/activity                  |
      | desk   | /admin/agents/artifacts          |
      | desk   | /admin/agents/artifacts/new      |
      | desk   | /admin/agents/memories           |
      | desk   | /admin/agents/sessions           |
      | desk   | /admin/analytics                 |
      | desk   | /admin/calendar                  |
      | desk   | /admin/contacts                  |
      | desk   | /admin/contacts/new              |
      | desk   | /admin/decisions                 |
      | desk   | /admin/decisions/new             |
      | desk   | /admin/files                     |
      | desk   | /admin/health                    |
      | desk   | /admin/inbox                     |
      | desk   | /admin/journal                   |
      | desk   | /admin/links                     |
      | desk   | /admin/mail                      |
      | desk   | /admin/mail/settings             |
      | desk   | /admin/notes                     |
      | desk   | /admin/performance               |
      | desk   | /admin/performance/requests      |
      | desk   | /admin/posts                     |
      | desk   | /admin/posts/new                 |
      | desk   | /admin/projects                  |
      | desk   | /admin/projects/new              |
      | desk   | /admin/review                    |
      | desk   | /admin/search                    |
      | desk   | /admin/settings/jobs             |
      | desk   | /admin/settings/security         |
      | desk   | /admin/settings/services         |
      | desk   | /admin/settings/webmentions      |
      | desk   | /admin/settings/tagging          |
      | desk   | /admin/social                    |
      | desk   | /admin/tasks                     |
      | desk   | /admin/tasks/new                 |
      | desk   | /admin/time                      |
      | desk   | /admin/webmentions               |
      | desk   | /admin/decisions/1               |
      | desk   | /admin/decisions/1/edit          |
      | desk   | /admin/projects/1                |
      | desk   | /admin/projects/1/edit           |
      | desk   | /admin/posts/1/edit              |
      | desk   | /admin/posts/1/analytics         |
      | desk   | /admin/tasks/1                   |
      | desk   | /admin/tasks/1/edit              |
      | desk   | /admin/commits/1                 |
      | desk   | /admin/pull-requests/1           |
      | desk   | /admin/tags/ruby                 |
      | desk   | /admin/contacts/1                |
      | desk   | /admin/contacts/1/edit           |
      | desk   | /admin/files/1/edit              |
      | desk   | /admin/files/groups/1/edit       |
      | desk   | /admin/links/1/edit              |
      | desk   | /admin/agents/sessions?session=1 |
      | desk   | /admin/agents/memories/1         |
      | desk   | /admin/agents/artifacts/1        |
      | desk   | /admin/agents/artifacts/1/edit   |
      | desk   | /admin/notes/1                   |
      | desk   | /admin/notes/folders/1           |
      | phone  | /admin                           |
      | phone  | /admin/activity                  |
      | phone  | /admin/agents/artifacts          |
      | phone  | /admin/agents/artifacts/new      |
      | phone  | /admin/agents/memories           |
      | phone  | /admin/agents/sessions           |
      | phone  | /admin/analytics                 |
      | phone  | /admin/calendar                  |
      | phone  | /admin/contacts                  |
      | phone  | /admin/contacts/new              |
      | phone  | /admin/decisions                 |
      | phone  | /admin/decisions/new             |
      | phone  | /admin/files                     |
      | phone  | /admin/health                    |
      | phone  | /admin/inbox                     |
      | phone  | /admin/journal                   |
      | phone  | /admin/links                     |
      | phone  | /admin/mail                      |
      | phone  | /admin/mail/settings             |
      | phone  | /admin/notes                     |
      | phone  | /admin/performance               |
      | phone  | /admin/performance/requests      |
      | phone  | /admin/posts                     |
      | phone  | /admin/posts/new                 |
      | phone  | /admin/projects                  |
      | phone  | /admin/projects/new              |
      | phone  | /admin/review                    |
      | phone  | /admin/search                    |
      | phone  | /admin/settings/jobs             |
      | phone  | /admin/settings/security         |
      | phone  | /admin/settings/services         |
      | phone  | /admin/settings/webmentions      |
      | phone  | /admin/settings/tagging          |
      | phone  | /admin/social                    |
      | phone  | /admin/tasks                     |
      | phone  | /admin/tasks/new                 |
      | phone  | /admin/time                      |
      | phone  | /admin/webmentions               |
      | phone  | /admin/decisions/1               |
      | phone  | /admin/decisions/1/edit          |
      | phone  | /admin/projects/1                |
      | phone  | /admin/projects/1/edit           |
      | phone  | /admin/posts/1/edit              |
      | phone  | /admin/posts/1/analytics         |
      | phone  | /admin/tasks/1                   |
      | phone  | /admin/tasks/1/edit              |
      | phone  | /admin/commits/1                 |
      | phone  | /admin/pull-requests/1           |
      | phone  | /admin/tags/ruby                 |
      | phone  | /admin/contacts/1                |
      | phone  | /admin/contacts/1/edit           |
      | phone  | /admin/files/1/edit              |
      | phone  | /admin/files/groups/1/edit       |
      | phone  | /admin/links/1/edit              |
      | phone  | /admin/agents/sessions?session=1 |
      | phone  | /admin/agents/memories/1         |
      | phone  | /admin/agents/artifacts/1        |
      | phone  | /admin/agents/artifacts/1/edit   |
      | phone  | /admin/notes/1                   |
      | phone  | /admin/notes/folders/1           |

  Scenario Outline: The admin dialogs read well
    Given I read the admin on a <device>
    When I visit "/admin/tasks"
    And I open the admin dialog "<dialog>"
    Then the page has no axe breaches in light or dark
    And Tab reaches every control in order behind a ring
    And the screen holds to the size it is read on

    Examples:
      | device | dialog          |
      | desk   | key help        |
      | desk   | command palette |
      | desk   | create task     |
      | desk   | journal         |
      | phone  | key help        |
      | phone  | command palette |
      | phone  | create task     |
      | phone  | journal         |
