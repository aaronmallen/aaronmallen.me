Feature: Admin keys
  The owner moves through lists with j and k, acts on the highlighted row with one key, jumps between screens with
  g, and reads every key in the help overlay.

  Background:
    Given I am signed in to the admin

  Scenario: j and k move the highlight through a list and stop at its ends
    Given the database runs:
      """
      INSERT INTO posts (title, slug, body, body_html, status, read_time, word_count) VALUES
        ('Alpha', 'alpha', 'A.', '<p>A.</p>', 'draft', 1, 1),
        ('Beta', 'beta', 'B.', '<p>B.</p>', 'draft', 1, 1),
        ('Gamma', 'gamma', 'G.', '<p>G.</p>', 'draft', 1, 1);
      """
    When I visit "/admin/posts"
    And I press the keys "j"
    Then the focus is on the first of ".li-title"
    And the highlighted row shows its ring
    When I press the keys "j"
    Then the focus is on the second of ".li-title"
    When I press the keys "k"
    Then the focus is on the first of ".li-title"
    When I press the keys "j j j j j"
    Then the focus is on the last of ".li-title"

  Scenario: k with no highlight starts from the last row
    Given the database runs:
      """
      INSERT INTO posts (title, slug, body, body_html, status, read_time, word_count) VALUES
        ('Alpha', 'alpha', 'A.', '<p>A.</p>', 'draft', 1, 1),
        ('Beta', 'beta', 'B.', '<p>B.</p>', 'draft', 1, 1);
      """
    When I visit "/admin/posts"
    And I press the keys "k"
    Then the focus is on the last of ".li-title"

  Scenario: Enter and e open the highlighted row where a click goes
    Given the database runs:
      """
      INSERT INTO posts (title, slug, body, body_html, status, read_time, word_count)
        VALUES ('Only post', 'only-post', 'O.', '<p>O.</p>', 'draft', 1, 1);
      """
    When I visit "/admin/posts"
    And I press the keys "e"
    Then the admin address is "/admin/posts"
    When I press the keys "j Enter"
    Then the admin address is "/admin/posts/1/edit"
    When I visit "/admin/posts"
    And I press the keys "j e"
    Then the admin address is "/admin/posts/1/edit"

  Scenario: The help lists e beside enter where no row key claims e
    Given the database runs:
      """
      INSERT INTO posts (title, slug, body, body_html, status, read_time, word_count)
        VALUES ('Only post', 'only-post', 'O.', '<p>O.</p>', 'draft', 1, 1);
      """
    When I visit "/admin/posts"
    And I press the keys "?"
    Then the key help has the row "↵ e Open the highlighted row"

  Scenario: A long list scrolls the highlighted row into view
    Given the database runs:
      """
      INSERT INTO tasks (title, position, list) SELECT 'Chore ' || n, n, 'next' FROM generate_series(1, 30) AS n;
      """
    When I visit "/admin/tasks?filter=next"
    And I press the keys "k"
    Then the highlighted row sits inside the window

  Scenario: Enter on a task opens it the way a click does
    Given the database runs:
      """
      INSERT INTO tasks (title, position, list) VALUES ('Write the brief', 1, 'next');
      """
    When I visit "/admin/tasks?filter=next"
    And I press the keys "j Enter"
    Then the admin markup holds "dialog[data-task-panel][open]:has-text('Write the brief')"

  Scenario: s starts the highlighted task and leaves the others alone
    Given the database runs:
      """
      INSERT INTO tasks (title, position, list) VALUES ('Write the brief', 1, 'next'), ('Book the venue', 2, 'next');
      """
    When I visit "/admin/tasks?filter=next"
    And I press the keys "j j s"
    Then the admin markup holds ".toast"
    And the database soon answers "Book the venue in_progress, Write the brief open" for:
      """
      SELECT string_agg(title || ' ' || status, ', ' ORDER BY title) FROM tasks
      """

  Scenario: s with no highlight starts nothing
    Given the database runs:
      """
      INSERT INTO tasks (title, position, list) VALUES ('Write the brief', 1, 'next'), ('Book the venue', 2, 'next');
      """
    When I visit "/admin/tasks?filter=next"
    And I press the keys "s"
    Then the admin address is "/admin/tasks?filter=next"
    And the database answers "open" for:
      """
      SELECT string_agg(DISTINCT status::text, ', ') FROM tasks
      """

  Scenario: m moves the task the way its first arrow does
    Given the database runs:
      """
      INSERT INTO tasks (title, position, list) VALUES ('Write the brief', 1, 'next');
      """
    When I visit "/admin/tasks?filter=next"
    And I press the keys "j m"
    Then the admin address is "/admin/tasks?filter=today"

  Scenario: e opens the task for editing the way the pen does
    Given the database runs:
      """
      INSERT INTO tasks (title, position, list) VALUES ('Write the brief', 1, 'next');
      """
    When I visit "/admin/tasks?filter=next"
    And I press the keys "j e"
    Then the admin markup holds "dialog#task-panel[open] [data-task-edit] form.task-form"

  Scenario: x opens the done panel with focus on its button, which completes the task
    Given the database runs:
      """
      INSERT INTO sprints (sprint_date) VALUES ((now() AT TIME ZONE 'America/Chicago')::date) ON CONFLICT DO NOTHING;
      INSERT INTO tasks (title, position, sprint_id, status) VALUES ('Ship the screen', 1, (SELECT id FROM sprints), 'in_progress');
      """
    When I visit "/admin/tasks?filter=today"
    And I press the keys "j x"
    Then the admin markup holds "details.task-complete[open]"
    And the focus is on the text "Done"
    When I click "Done" in the open done panel
    Then the admin markup holds ".toast:has-text('Done')"
    And the database soon answers "0" for:
      """
      SELECT count(*) FROM tasks WHERE status IN ('open', 'in_progress')
      """

  Scenario: On Today, j moves from the last sprint row into the open pool
    Given the database runs:
      """
      INSERT INTO sprints (sprint_date) VALUES ((now() AT TIME ZONE 'America/Chicago')::date) ON CONFLICT DO NOTHING;
      INSERT INTO tasks (title, position, list) VALUES ('Write the brief', 1, 'next');
      INSERT INTO tasks (title, position, list) VALUES ('Learn the cello', 2, 'someday');
      INSERT INTO tasks (title, position, sprint_id) VALUES ('Ship the screen', 3, (SELECT id FROM sprints));
      """
    When I visit "/admin"
    And I open "Pull from a list" under "details"
    And I press the keys "j j"
    Then the highlighted row holds "Write the brief"

  Scenario: With an empty sprint, j lands on the first row of the open pool
    Given the database runs:
      """
      INSERT INTO tasks (title, position, list) VALUES ('Write the brief', 1, 'next');
      INSERT INTO tasks (title, position, list) VALUES ('Learn the cello', 2, 'someday');
      """
    When I visit "/admin/tasks?filter=today"
    And I press the keys "j"
    Then the highlighted row holds "Write the brief"
    When I press the keys "j"
    Then the highlighted row holds "Write the brief"

  Scenario: The help on a task list lists the task row keys and the reorder keys
    Given the database runs:
      """
      INSERT INTO sprints (sprint_date) VALUES ((now() AT TIME ZONE 'America/Chicago')::date) ON CONFLICT DO NOTHING;
      INSERT INTO tasks (title, position, sprint_id, status) VALUES ('Ship the screen', 1, (SELECT id FROM sprints), 'in_progress');
      INSERT INTO tasks (title, position, sprint_id) VALUES ('Write the brief', 2, (SELECT id FROM sprints));
      """
    When I visit "/admin/tasks?filter=today"
    And I press the keys "?"
    Then the key help has the row "x Complete the highlighted task"
    And the key help has the row "s Start the highlighted task"
    And the key help has the row "m Move the highlighted task one list over"
    And the key help has the row "e Edit the highlighted task"

  Scenario: p publishes the highlighted draft and nothing else
    Given the database runs:
      """
      INSERT INTO posts (title, slug, body, body_html, status, read_time, word_count)
        VALUES ('Half done', 'half-done', 'H.', '<p>H.</p>', 'draft', 1, 1);
      """
    When I visit "/admin/posts"
    And I press the keys "p"
    Then the admin address is "/admin/posts"
    And the database answers "draft" for:
      """
      SELECT status FROM posts
      """
    When I press the keys "j p"
    Then the admin markup holds ".toast:has-text('Published')"
    And the database soon answers "published" for:
      """
      SELECT status FROM posts
      """

  Scenario: p does nothing on a published post
    Given the database runs:
      """
      INSERT INTO posts (title, slug, body, body_html, status, read_time, word_count, published_at)
        VALUES ('Out already', 'out-already', 'O.', '<p>O.</p>', 'published', 1, 1, now() - interval '1 day');
      """
    When I visit "/admin/posts"
    And I press the keys "j p"
    Then the admin address is "/admin/posts"
    And the database answers "published, true" for:
      """
      SELECT status, published_at < now() - interval '23 hours' FROM posts
      """

  Scenario: The help lists p on the posts list
    Given the database runs:
      """
      INSERT INTO posts (title, slug, body, body_html, status, read_time, word_count)
        VALUES ('Half done', 'half-done', 'H.', '<p>H.</p>', 'draft', 1, 1);
      """
    When I visit "/admin/posts"
    And I press the keys "?"
    Then the key help has the row "p Publish the highlighted draft"

  Scenario: r opens the highlighted thread and marks it read
    Given the contact form brings in "Second"
    And the contact form brings in "First"
    And the database runs:
      """
      UPDATE mail_threads SET received_at = now() - interval '1 minute' WHERE subject = 'Second';
      """
    When I visit "/admin/mail"
    And I press the keys "r"
    Then the database answers "First unread, Second unread" for:
      """
      SELECT string_agg(subject || ' ' || status, ', ' ORDER BY subject) FROM mail_threads
      """
    When I press the keys "j r"
    Then the admin markup holds ".mail-reader h2:has-text('First')"
    And the database soon answers "First read, Second unread" for:
      """
      SELECT string_agg(subject || ' ' || status, ', ' ORDER BY subject) FROM mail_threads
      """

  Scenario: The help lists r on the mail list
    Given the contact form brings in "First"
    When I visit "/admin/mail"
    And I press the keys "?"
    Then the key help has the row "r Open the highlighted thread and mark it read"

  Scenario Outline: g and a letter jump to a screen
    When I visit "/admin/analytics"
    And I press the keys "g <letter>"
    Then the admin address is "<path>"

    Examples:
      | letter | path            |
      | t      | /admin          |
      | k      | /admin/tasks    |
      | j      | /admin/journal  |
      | p      | /admin/posts    |
      | a      | /admin/activity |

  Scenario: g alone does nothing
    When I visit "/admin/analytics"
    And I press the keys "g"
    And I open the key help from the avatar menu
    Then the key help is open
    And the admin address is "/admin/analytics"

  Scenario: g and a letter with no screen does nothing
    When I visit "/admin/analytics"
    And I press the keys "g x t ?"
    Then the key help is open
    And the admin address is "/admin/analytics"

  Scenario: The help lists the g jumps
    When I visit "/admin/analytics"
    And I press the keys "?"
    Then the key help has the row "g t Go to today"
    And the key help has the row "g a Go to activity"

  Scenario Outline: c opens the screen's own new form
    When I visit "<screen>"
    And I press the keys "c"
    Then the admin address is "<form>"

    Examples:
      | screen           | form                 |
      | /admin/posts     | /admin/posts/new     |
      | /admin/projects  | /admin/projects/new  |
      | /admin/decisions | /admin/decisions/new |
      | /admin/contacts  | /admin/contacts/new  |

  Scenario Outline: c opens the task dialog where a screen has no create button
    When I visit "<screen>"
    And I press the keys "c"
    Then the admin markup holds "dialog#task-create[open]"
    And the admin address is "<screen>"

    Examples:
      | screen           |
      | /admin           |
      | /admin/tasks     |
      | /admin/analytics |

  Scenario: The help lists the screen's own c
    When I visit "/admin/posts"
    And I press the keys "?"
    Then the key help has the row "c New post"

  Scenario: The help lists c as a new task where the screen has no create button
    When I visit "/admin/analytics"
    And I press the keys "?"
    Then the key help has the row "c Create task"

  Scenario: w opens the journal modal on the page you are on
    When I visit "/admin/analytics"
    And I press the keys "?"
    Then the key help has the row "w Create journal entry"
    When I press the keys "Escape w"
    Then the admin markup holds "dialog#journal-write[open]"
    And the admin address is "/admin/analytics"

  Scenario: j on a row with no link highlights the row itself
    Given the database runs:
      """
      INSERT INTO work_entries (org, role, from_year, position) VALUES ('Acme', 'Hello there', 2020, 1);
      """
    When I visit "/admin/projects?filter=work"
    And I press the keys "j"
    Then the highlighted row is the row itself
    And the highlighted row holds "Hello there"

  Scenario: The help stays shut until ? opens it, then lists the keys of the screen
    Given the database runs:
      """
      INSERT INTO tasks (title, position, list) VALUES ('Write the brief', 1, 'next');
      """
    When I visit "/admin/tasks?filter=next"
    Then the key help is shut
    When I press the keys "?"
    Then the key help is open
    And the key help has a row with "Highlight the next row"
    And the key help has a row with "Highlight the row above"
    And the key help has a row with "Open the highlighted row"
    And the key help has the row "/ Open the command palette"
    And the key help has the row "? Show the keys"
    And the key help has a row that starts "⌘K ⌘/ Ctrl+K Ctrl+/ Open the command palette"
    And the key help has the row "esc Close a drawer, dialog or menu"
    And the key help has the row "↵ Open the highlighted row"
    And the key help has a row with "Move the focused task up or down"
    When I press the keys "?"
    Then the key help has 1 row with "Show the keys"

  Scenario: The open help keeps the list keys quiet and shuts on Escape
    Given the database runs:
      """
      INSERT INTO tasks (title, position, list) VALUES ('Write the brief', 1, 'next');
      """
    When I visit "/admin/tasks?filter=next"
    And I press the keys "? j"
    Then no row is highlighted
    When I press the keys "Escape"
    Then the key help is shut

  Scenario: The avatar menu opens the help
    When I visit "/admin/tasks?filter=next"
    And I open the key help from the avatar menu
    Then the key help is open

  Scenario: The help on a screen with no list leaves out the list and reorder keys
    When I visit "/admin/analytics"
    And I press the keys "?"
    Then the key help has no row with "Highlight the next row"
    And the key help has no row with "Move the focused task up or down"

  Scenario: Keys typed in a field stay in the field
    Given the database runs:
      """
      INSERT INTO tags (name, color, scope) VALUES ('ruby', 'mk-blue', 'public');
      """
    When I visit "/admin/settings/tagging"
    And I type "jk?" in the field "tags-q"
    And the field "tags-q" holds "jk?"
    And no row is highlighted
    And the key help is shut

  Scenario Outline: The screens the keys act on pass axe
    When I visit "<route>"
    Then the page has no axe breaches in light or dark

    Examples:
      | route                    |
      | /admin/posts             |
      | /admin/tasks?filter=next |
      | /admin/mail              |
      | /admin/analytics         |
      | /admin/projects?filter=work |
