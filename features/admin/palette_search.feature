Feature: Admin palette search
  The command palette asks the admin for the records that match what I type. It answers JSON to a signed in owner
  only, at most eight hits across every kind, each with a link to where the record lives.

  Scenario: A phrase from a journal entry finds the entry as JSON no cache keeps
    Given I am signed in to the admin
    And the database runs:
      """
      INSERT INTO journal_entries (entry_date, entry_time, body, body_html)
        VALUES ('2026-10-01', '09:00', E'Walked the levee at dawn\nThe river ran high', '<p>Walked the levee at dawn</p>');
      """
    When I search the palette for "levee"
    Then the palette search answers 200
    And the palette search answers JSON that no cache keeps
    And the palette search finds one journal hit holding:
      """
      { "kind": "journal", "id": 1, "title": "Walked the levee at dawn", "href": "/admin/journal?to=2026-10-01#day-2026-10-01" }
      """
    And the palette search's journal hit quotes "levee"

  Scenario: A note is found by its title and by its body
    Given I am signed in to the admin
    And the database runs:
      """
      INSERT INTO notes (title, body) VALUES ('Glaze recipes', 'Celadon over porcelain');
      """
    When I search the palette for "glaze"
    Then the palette search finds one note hit holding:
      """
      { "kind": "note", "id": 1, "href": "/admin/notes/1" }
      """
    When I search the palette for "porcelain"
    Then the palette search finds one note hit holding:
      """
      { "title": "Glaze recipes" }
      """

  Scenario: A task label finds that task first, with its label
    Given I am signed in to the admin
    And the database runs:
      """
      INSERT INTO projects (name, visibility, key) VALUES ('Podcast', 'public', 'POD');
      INSERT INTO tasks (title, position, list, project_id) VALUES ('Record the intro', 1, 'next', 1);
      INSERT INTO tasks (title, position, list) VALUES ('Read the intro', 2, 'next');
      """
    When I search the palette for "POD-1"
    Then the palette search's first hit holds:
      """
      { "kind": "task", "title": "Record the intro", "label": "POD-1" }
      """

  Scenario: A phrase several kinds hold lists them all in one list
    Given I am signed in to the admin
    And the database runs:
      """
      INSERT INTO tasks (title, position, list) VALUES ('Track the zeppelin', 1, 'next');
      INSERT INTO posts (title, slug, body, body_html, status, published_at, read_time, word_count)
        VALUES ('Zeppelins', 'zeppelins', 'A post', '<p>A post</p>', 'published', now(), 1, 2);
      """
    And the contact form brings in "Zeppelin sighting"
    When I search the palette for "zeppelin"
    Then the palette search finds the kinds "task, post, message", in any order

  Scenario: More hits than it shows lists the top eight
    Given I am signed in to the admin
    And the database runs:
      """
      INSERT INTO tasks (title, position, list) SELECT 'Call the plumber ' || n, n, 'next' FROM generate_series(0, 5) AS n;
      """
    And the contact form brings in "Plumber quote 0"
    And the contact form brings in "Plumber quote 1"
    And the contact form brings in "Plumber quote 2"
    When I search the palette for "plumber"
    Then the palette search finds 8 hits
    And the palette search finds hits of each kind "task, message"

  Scenario: A task, closed or not, leads to its page
    Given I am signed in to the admin
    And the database runs:
      """
      INSERT INTO tasks (title, position, list, status, completed_at) VALUES ('Renew the passport', 1, 'next', 'done', now());
      """
    When I search the palette for "passport"
    Then the palette search's task hit leads to "/admin/tasks/1"

  Scenario: A post leads to its editor
    Given I am signed in to the admin
    And the database runs:
      """
      INSERT INTO posts (title, slug, body, body_html, status, read_time, word_count)
        VALUES ('Notes on kayaks', 'notes-on-kayaks', 'Hi.', '<p>Hi.</p>', 'draft', 1, 1);
      """
    When I search the palette for "kayaks"
    Then the palette search's post hit leads to "/admin/posts/1/edit"

  Scenario: A social post leads to its editor on the social screen
    Given I am signed in to the admin
    And the database runs:
      """
      INSERT INTO social_posts (targets, status, posted_at) VALUES ('{mastodon}', 'posted', now());
      INSERT INTO social_post_parts (social_post_id, position, body) VALUES (1, 1, 'Saw a heron today');
      """
    When I search the palette for "heron"
    Then the palette search's social hit leads to "/admin/social?edit=1"

  Scenario: A commit leads to its page
    Given I am signed in to the admin
    And the database runs:
      """
      INSERT INTO commits (sha, repo, branch, message, commit_date, commit_time)
        VALUES ('abc1234', 'aaronmallen/secret-lab', 'main', 'Wire the thermostat relay', current_date, '09:00');
      """
    When I search the palette for "thermostat"
    Then the palette search's commit hit leads to "/admin/commits/1"

  Scenario: A project leads to its editor
    Given I am signed in to the admin
    And the database runs:
      """
      INSERT INTO projects (name, tagline, visibility, key) VALUES ('airship', 'Blimp tracker', 'public', 'AIR');
      """
    When I search the palette for "blimp"
    Then the palette search's project hit leads to "/admin/projects/1/edit"

  Scenario: A work entry leads to the work list
    Given I am signed in to the admin
    And the database runs:
      """
      INSERT INTO work_entries (org, role, from_year, position) VALUES ('Gondola Works', 'Pilot', 2020, 1);
      """
    When I search the palette for "gondola"
    Then the palette search's work hit leads to "/admin/projects?filter=work"

  Scenario: A person leads to their editor
    Given I am signed in to the admin
    And the database runs:
      """
      INSERT INTO people (name) VALUES ('Ada Lovelace');
      """
    When I search the palette for "lovelace"
    Then the palette search's person hit leads to "/admin/contacts/1"

  Scenario: A message leads to its thread in Mail
    Given I am signed in to the admin
    And the database runs:
      """
      INSERT INTO mail_accounts (provider, name) VALUES ('contact_form', 'Contact form');
      INSERT INTO mail_threads (mail_account_id, subject, status) VALUES (1, 'Hello', 'read');
      INSERT INTO mail_messages (mail_thread_id, subject, body, reply_to) VALUES (1, 'Hello', 'Loved your piece on sourdough', 'ada@example.com');
      """
    When I search the palette for "sourdough"
    Then the palette search's message hit leads to "/admin/mail?folder=all&thread=1#read-1"

  Scenario: A decision leads to its page
    Given I am signed in to the admin
    And the database runs:
      """
      INSERT INTO decisions (title, problem) VALUES ('Pick a hangar', 'Where the airship sleeps');
      """
    When I search the palette for "airship"
    Then the palette search's decision hit leads to "/admin/decisions/1"

  Scenario: A webmention leads to the list that holds it
    Given I am signed in to the admin
    And the database runs:
      """
      INSERT INTO posts (title, slug, body, body_html, status, published_at, read_time, word_count)
        VALUES ('Hello', 'hello', 'Hi.', '<p>Hi.</p>', 'published', now(), 1, 1);
      INSERT INTO webmentions (post_id, source_url, author_name, type, status)
        VALUES (1, 'https://grace.example/reply', 'Grace Hopper', 'reply', 'approved');
      """
    When I search the palette for "hopper"
    Then the palette search's webmention hit leads to "/admin/webmentions?status=approved"

  Scenario: A blank query finds nothing
    Given I am signed in to the admin
    And the database runs:
      """
      INSERT INTO tasks (title, position, list) VALUES ('Call the plumber', 1, 'next');
      """
    When I search the palette for "   "
    Then the palette search finds nothing

  Scenario: Signed out, the search answers 401, lists nothing and leaves sign-in to send me to the admin
    Given the database runs:
      """
      INSERT INTO tasks (title, position, list) VALUES ('Email the accountant', 1, 'next');
      """
    When I search the palette for "accountant"
    Then the palette search answers 401
    And the palette search answer leaves out "Email the accountant"
    When I sign in to the admin through GitHub
    Then the admin address is "/admin"

  Scenario: An API token with no session gets 401
    Given the database runs:
      """
      INSERT INTO tasks (title, position, list) VALUES ('Email the accountant', 1, 'next');
      """
    And an API token
    When I search the palette for "accountant" with only the API token
    Then the palette search answers 401
    And the palette search answer leaves out "Email the accountant"
