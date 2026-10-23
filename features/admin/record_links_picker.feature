Feature: Admin record picker
  The picker on a post's Linked section finds records of every kind by their words or a task's label.

  Background:
    Given I am signed in to the admin
    And a record link post titled "On hosting"

  Scenario: The picker finds a record of every kind by its title
    Given a record link task titled "Zeppelin task"
    And a record link post titled "Zeppelin post"
    And a record link social_post titled "Zeppelin social post"
    And a record link journal_entry titled "Zeppelin journal entry"
    And a record link commit titled "Zeppelin commit"
    And a record link project titled "Zeppelin project"
    And a record link work_entry titled "Zeppelin work entry"
    And a record link decision titled "Zeppelin decision"
    And a record link pull_request titled "Zeppelin pull request"
    And a record link mail_thread titled "Zeppelin mail thread"
    And a record link memory_file titled "Zeppelin memory file"
    And a record link artifact titled "Zeppelin artifact"
    And a record link note titled "Zeppelin note"
    And a record link note_folder titled "Zeppelin note folder"
    When I visit "/admin/posts/1/edit?record_q=zeppelin"
    Then the record picker groups read "Tasks, Posts, Social posts, Journal entries, Commits, Projects, Work entries, Decisions, Pull requests, Mail threads, Memory files, Artifacts, Notes, Note folders"

  Scenario: The picker finds every kind but a memory file, which has only its path, by text beyond its title
    Given the database runs:
      """
      insert into mail_accounts (provider, name) values ('contact_form', 'Contact form');
      insert into tasks (title, note, list, position) values ('Errand', 'Bring the zeppelin', 'next', 1);
      insert into posts (title, slug, body, body_html, webmentions_enabled, read_time, word_count)
        values ('Notes', 'notes', 'All about the zeppelin', '', false, 1, 4);
      insert into social_posts (targets) values ('{mastodon}');
      insert into social_post_parts (social_post_id, position, body)
        values (1, 1, 'First part'), (1, 2, 'And a zeppelin'), (1, 3, 'Last part');
      insert into journal_entries (entry_date, entry_time, body, body_html)
        values ('2026-09-30', '09:00', E'Morning\nSaw a zeppelin', '<p>Morning</p>');
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
        values ('abc123', 'aaronmallen/zeppelin', 'main', 'app: fix it', '2026-09-30', '09:00');
      insert into projects (name, tagline, visibility, key) values ('Blimp', 'Tracks a zeppelin', 'public', 'BLIMP');
      insert into work_entries (org, role, blurb, from_year, position) values ('Acme', 'Pilot', 'Flew a zeppelin', 2018, 1);
      insert into decisions (title, problem) values ('Pick a craft', 'Which zeppelin to buy');
      insert into pull_requests (repo, number, title, body, url, opened_at)
        values ('aaronmallen/blog', 1, 'Land it', 'Lands the zeppelin', 'https://github.com/aaronmallen/blog/pull/1', now());
      insert into mail_threads (mail_account_id, subject) values (1, 'Hello');
      insert into mail_messages (mail_thread_id, subject, body) values (1, 'Hello', 'Spotted a zeppelin');
      insert into notes (title, body) values ('Sketch', 'Draw the zeppelin');
      insert into note_folders (name, description) values ('Plans', 'Plans for the zeppelin');
      insert into artifacts (title, type, version) values ('A plan', 'plan', 1);
      insert into artifact_versions (artifact_id, number, body) values (1, 1, 'Moor the zeppelin');
      """
    When I visit "/admin/posts/1/edit?record_q=zeppelin"
    Then the record picker groups read "Tasks, Posts, Social posts, Journal entries, Commits, Projects, Work entries, Decisions, Pull requests, Mail threads, Artifacts, Notes, Note folders"

  Scenario: The picker keeps to five of each kind, newest first
    Given the database runs:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html)
      select (now() at time zone 'America/Chicago')::date - n, '09:00', 'Zeppelin ' || n, '<p>Zeppelin</p>'
      from generate_series(1, 6) as n
      """
    When I visit "/admin/posts/1/edit?record_q=zeppelin"
    Then the record picker offers "Zeppelin 1, Zeppelin 2, Zeppelin 3, Zeppelin 4, Zeppelin 5"

  Scenario: The picker reads the text as plain words and finds nothing for blank text
    Given a record link task titled "Half done"
    When I visit "/admin/posts/1/edit?record_q=%25"
    Then the record picker offers ""
    When I visit "/admin/posts/1/edit?record_q=%20%20%20"
    Then the record picker offers ""

  Scenario: The picker finds every task with the number by n or #n
    Given the record picker has two tasks numbered 23
    When I visit "/admin/posts/1/edit?record_q=23"
    Then the record picker offers "Loose end, Record the intro" in any order
    When I visit "/admin/posts/1/edit?record_q=%2323"
    Then the record picker offers "Loose end, Record the intro" in any order

  Scenario: The picker finds a task by KEY-n in any case
    Given the record picker has two tasks numbered 23
    When I visit "/admin/posts/1/edit?record_q=POD-23"
    Then the record picker offers "Record the intro"
    When I visit "/admin/posts/1/edit?record_q=pod-23"
    Then the record picker offers "Record the intro"

  Scenario: The picker lists label matches ahead of title matches
    Given the record picker has two tasks numbered 23
    And a record link task titled "Plan 23 more"
    When I visit "/admin/posts/1/edit?record_q=23"
    Then the record picker offers 3 records, the last "Plan 23 more"
