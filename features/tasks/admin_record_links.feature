Feature: Linked records on the task page
  The task page lists the records linked to a task, grouped by kind, and finds, adds and removes links.

  Background:
    Given I am signed in to the admin
    And the tasks:
      | title           |
      | Move the server |
    And a published post "On hosting the site"

  Scenario: A task with no links says so in a plain block
    When I visit "/admin/tasks/{task:Move the server}"
    Then the page part ".task-drawer-body > .field.record-links:not(.card) > .f:first-child" reads "Linked records"
    And the page part ".record-links .hint" reads "Nothing linked yet."
    And the page has no axe breaches in light or dark

  Scenario: The Linked block groups the links by kind and links each record to its page
    Given the projects:
      | name           | visibility | archived  | started    |
      | aaronmallen.me | public     |           |            |
      | hidden         | private    |           |            |
      | retired        | public     | today - 1 | today - 30 |
    And the database runs:
      """
      INSERT INTO commits (sha, repo, branch, message, commit_date, commit_time) VALUES ('abc123', 'aaronmallen/aaronmallen.me', 'main', 'Move the box', '2026-10-01', '09:00');
      INSERT INTO decisions (title, problem) VALUES ('Pick a host', 'Where?'), ('Pick a rack', 'Which?');
      INSERT INTO memory_files (path, scope, task_id, description) VALUES ('hanami.md', 'task', 1, 'Hanami notes');
      INSERT INTO artifacts (title, type) VALUES ('Server plan', 'plan');
      INSERT INTO tasks (title, list, position) VALUES ('Order the rack', 'next', 2);
      INSERT INTO task_links (from_task_id, to_task_id, type) VALUES (1, 2, 'blocks');
      UPDATE tasks SET project_id = 1 WHERE id = 1;
      INSERT INTO record_links (left_kind, left_id, right_kind, right_id) VALUES
        ('task', 1, 'commit', 1), ('task', 1, 'post', 1), ('task', 1, 'decision', 1), ('task', 1, 'decision', 2), ('task', 1, 'artifact', 1);
      """
    When I visit "/admin/tasks/{task:Move the server}?filter=upcoming"
    Then the page parts ".record-links > .record-link-group .record-link-kind" read "Posts | Commits | Projects | Decisions | Memory files | Artifacts"
    And the page part ".record-link-group:has(.record-link-kind:text-is('Posts')) a:text-is('On hosting the site')" has "href" set to "/admin/posts/1/edit"
    And the page part ".record-link-group:has(.record-link-kind:text-is('Projects')) a:text-is('aaronmallen.me')" has "href" set to "/admin/projects/1/edit"
    And the page parts ".record-link-group:has(.record-link-kind:text-is('Projects')) a.record-link-title" read "aaronmallen.me"
    And the page parts ".record-link-group:has(.record-link-kind:text-is('Decisions')) a.record-link-title" have "href" set to "/admin/decisions/2 | /admin/decisions/1"
    And the page part ".record-link-group:has(.record-link-kind:text-is('Memory files')) .record-link-title" reads "hanami.md"
    And the page part ".record-link-group:has(.record-link-kind:text-is('Artifacts')) .record-link-title" reads "Server plan"
    And the page has 0 of ".record-link-group:has(.record-link-kind:text-is('Memory files')) .record-link-row form"
    And the page has 1 of ".record-link-group:has(.record-link-kind:text-is('Artifacts')) .record-link-row form"
    And the page part ".record-links form[action='/admin/records/task/1/links/post/1/delete'] input[name='filter']" has "value" set to "upcoming"
    And the page has ".record-links >> role=button[name='Remove the link to On hosting the site']"
    And the page has no ".record-links :text('Order the rack')"
    And the page has no axe breaches in light or dark

  Scenario: A link stored from the other side shows too
    Given the post "On hosting the site" links the task "Move the server"
    When I visit "/admin/tasks/{task:Move the server}"
    Then the page part ".record-link-group:has(.record-link-kind:text-is('Posts')) .record-link-title" reads "On hosting the site"

  Scenario: Removing the link to a memory file scoped to the task keeps it and says to change its scope
    Given the database runs:
      """
      INSERT INTO memory_files (path, scope, task_id, description) VALUES ('hanami.md', 'task', 1, 'Hanami notes');
      """
    When I send the admin form "/admin/records/task/{task:Move the server}/links/memory_file/1/delete" with:
      | filter | next |
    And I follow the admin answer
    Then the toast says "Link kept · this memory file belongs to that record, so change its scope instead"
    When I visit "/admin/tasks/{task:Move the server}"
    Then the page part ".record-link-group:has(.record-link-kind:text-is('Memory files')) .record-link-title" reads "hanami.md"

  Scenario: The picker finds a record of every kind but a task
    Given the projects:
      | name           |
      | server project |
    And the database runs:
      """
      INSERT INTO social_posts (targets) VALUES ('{mastodon}');
      INSERT INTO social_post_parts (social_post_id, position, body) VALUES (1, 1, 'server social_post');
      INSERT INTO journal_entries (entry_date, entry_time, body, body_html) VALUES ('2026-10-01', '09:00', 'server journal_entry', '<p>server journal_entry</p>');
      INSERT INTO commits (sha, repo, branch, message, commit_date, commit_time) VALUES ('abc123', 'aaronmallen/aaronmallen.me', 'main', 'server commit', '2026-10-01', '09:00');
      INSERT INTO work_entries (org, role, from_year, position) VALUES ('Acme', 'server work_entry', 2020, 1);
      INSERT INTO decisions (title, problem) VALUES ('server decision', 'Where?');
      INSERT INTO pull_requests (repo, number, title, url, opened_at) VALUES ('aaronmallen/aaronmallen.me', 1, 'server pull_request', 'https://github.com/aaronmallen/aaronmallen.me/pull/1', now());
      INSERT INTO mail_accounts (provider, name) VALUES ('contact_form', 'Contact form');
      INSERT INTO mail_threads (mail_account_id, subject) VALUES (1, 'server mail_thread');
      INSERT INTO memory_files (path, scope, description) VALUES ('server-memory-file.md', 'global', 'server memory_file');
      INSERT INTO artifacts (title, type) VALUES ('server artifact', 'plan');
      INSERT INTO notes (title) VALUES ('server note');
      INSERT INTO note_folders (name) VALUES ('server');
      INSERT INTO tasks (title, list, position) VALUES ('Rack the server', 'next', 2);
      """
    When I visit "/admin/tasks/{task:Move the server}?filter=next&record_q=server"
    Then the page parts ".record-picker-results .record-link-kind" read "Social posts | Journal entries | Commits | Projects | Work entries | Decisions | Pull requests | Mail threads | Memory files | Artifacts | Notes | Note folders"
    And the page has no ".record-picker-target .record-link-title:text-is('Rack the server')"

  Scenario: The picker finds a post by its title, keeps the query and posts the link from each match
    When I visit "/admin/tasks/{task:Move the server}?filter=next&record_q=hosting"
    Then the page parts ".record-picker-target .record-link-title" read "On hosting the site"
    And the page field "#task-1-record-other-id" holds "hosting"
    And the page has "form[action='/admin/tasks/1/records']:has(.record-picker-target) input[name='record[other_kind]'][value='post']"
    And the page has "form[action='/admin/tasks/1/records']:has(.record-picker-target) input[name='record[other_id]'][value='1']"
    And the page has no axe breaches in light or dark
    When I visit "/admin/tasks/{task:Move the server}?filter=next&record_q=%20%20"
    Then the page has no ".record-picker-results, .record-picker .hint"

  Scenario: The picker leaves out a record it already links to
    Given the task "Move the server" links the post "On hosting the site"
    When I visit "/admin/tasks/{task:Move the server}?filter=next&record_q=hosting"
    Then the page part ".record-links .record-picker .hint" reads "No unlinked record matches."

  Scenario: The picker's find gets the task page and keeps the tab and where the task opened from
    When I visit "/admin/tasks/{task:Move the server}?filter=upcoming&origin=today"
    Then the page part ".record-links form.record-picker-find" has "method" set to "get"
    And the page part ".record-links form.record-picker-find" has "action" set to "/admin/tasks/1"
    And the page has ".record-links form.record-picker-find input[name='record_q'][type='search']"
    And the page has ".record-links form.record-picker-find input[name='filter'][value='upcoming']"
    And the page has ".record-links form.record-picker-find input[name='origin'][value='today']"

  Scenario: Linking a project moves the task into it, even an archived one
    Given the projects:
      | name    | visibility | archived  | started    |
      | hidden  | private    |           |            |
      | retired | public     | today - 1 | today - 30 |
    When I send the admin form "/admin/tasks/{task:Move the server}/records" with:
      | filter             | next    |
      | record[other_kind] | project |
      | record[other_id]   | 1       |
    And I send the admin form "/admin/tasks/{task:Move the server}/records" with:
      | filter             | next    |
      | record[other_kind] | project |
      | record[other_id]   | 2       |
    And I visit "/admin/tasks/{task:Move the server}"
    Then the page parts ".record-link-group:has(.record-link-kind:text-is('Projects')) a.record-link-title" read "retired"

  Scenario: Adding a link stores it on both sides, says so and comes back to where it was added
    When I send the admin form "/admin/tasks/{task:Move the server}/records" with:
      | filter             | next |
      | record[other_kind] | post |
      | record[other_id]   | 1    |
    Then the admin answer goes to "/admin/tasks?filter=next"
    And the database reads "task, 1, post, 1" for:
      """
      SELECT left_kind, left_id, right_kind, right_id FROM record_links
      """
    When I follow the admin answer
    Then the toast says "Record linked"
    When I send the admin form "/admin/records/task/{task:Move the server}/links/post/1/delete" with:
      | filter | next |
    And I send the admin form "/admin/tasks/{task:Move the server}/records" with:
      | filter             | today |
      | origin             | today |
      | record[other_kind] | post  |
      | record[other_id]   | 1     |
    Then the admin answer goes to "/admin"
    When I send the admin form "/admin/tasks/0/records" with:
      | filter             | next |
      | record[other_kind] | post |
      | record[other_id]   | 1    |
    Then the server answers 404

  Scenario: Adding a record already linked keeps the query and says so beside the picker
    Given the task "Move the server" links the post "On hosting the site"
    When I send the admin form "/admin/tasks/{task:Move the server}/records" with:
      | filter             | next    |
      | record_q           | hosting |
      | record[other_kind] | post    |
      | record[other_id]   | 1       |
    Then the server answers 422
    When I look at the admin answer
    Then the page part ".record-links .record-picker #task-1-record-other-id-error" reads "These two are already linked."
    And the page part "#task-1-record-other-id" has "aria-describedby" set to "task-1-record-other-id-error"
    And the page field "#task-1-record-other-id" holds "hosting"
    And the page has "[data-task-read='1']"
    And 1 record link remains

  Scenario: Adding a link refuses a record that is gone, a task or a kind it does not know
    Given a task "Other"
    When I send the admin form "/admin/tasks/{task:Move the server}/records" with:
      | filter             | next   |
      | record[other_kind] | post   |
      | record[other_id]   | 999999 |
    And I look at the admin answer
    Then the page part "#task-1-record-other-id-error" reads "That record is gone. Find another."
    When I send the admin form "/admin/tasks/{task:Move the server}/records" with:
      | filter             | next |
      | record[other_kind] | task |
      | record[other_id]   | 2    |
    And I look at the admin answer
    Then the page part "#task-1-record-other-id-error" reads "Link two tasks from the Links section."
    When I send the admin form "/admin/tasks/{task:Move the server}/records" with:
      | filter             | next   |
      | record[other_kind] | person |
      | record[other_id]   | 1      |
    And I look at the admin answer
    Then the page part "#task-1-record-other-kind-error" reads "Pick a record from the list."
    And 0 record links remain

  Scenario: Removing a link clears it, says so and comes back to the list
    Given the task "Move the server" links the post "On hosting the site"
    And the projects:
      | name     |
      | Unlinked |
    When I send the admin form "/admin/records/task/{task:Move the server}/links/post/1/delete" with:
      | filter | next |
    Then the admin answer goes to "/admin/tasks?filter=next"
    And 0 record links remain
    When I follow the admin answer
    Then the toast says "Link removed"
    When I send the admin form "/admin/records/task/{task:Move the server}/links/project/1/delete" with:
      | filter | next |
    Then the server answers 404
