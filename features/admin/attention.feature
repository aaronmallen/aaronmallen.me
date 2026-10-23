Feature: Needs attention on the Today page
  The Needs attention card lists stalled work, worst first: carried tasks, old drafts, forgotten someday tasks, a
  quiet journal and more. Each row offers a way to act on it, or a snooze that keeps it off the card for a week.

  Background:
    Given I am signed in to the admin
    And the country database holds the test networks

  Scenario: The card lists one row of each stalled kind, worst first, with its count
    Given the database runs:
      """
      insert into tasks (title, list, position, carried_count) values ('Carried task', 'next', 1, 4);
      insert into posts (title, slug, status, body_html, read_time, word_count, webmentions_enabled, updated_at)
      values ('Old draft', 'old-draft', 'draft', '', 1, 1, false, now() - interval '60 days');
      insert into tasks (title, list, position, updated_at) values ('Someday task', 'someday', 2, now() - interval '100 days');
      insert into journal_entries (entry_date, entry_time, body, body_html)
      values ((now() at time zone 'America/Chicago')::date - 3, '09:00', 'Old', '<p>Old</p>');
      """
    When I visit "/admin"
    Then the attention card lists:
      """
      Old draft
      Journal
      Carried task
      Someday task
      """
    And the attention row "Carried task" says only "Carried over 4 days"
    And the attention row "Old draft" says only "Untouched for 60 days"
    And the attention row "Someday task" says only "Untouched for 100 days"
    And the attention row "Journal" says only "No entry in 3 days"

  Scenario: The card draws a row for every kind of stalled work
    Given an attention LinkedIn connection for "Ada Lovelace" that lapses in 3 days
    And the database runs:
      """
      insert into tasks (title, list, position, carried_count) values ('Carried task', 'next', 1, 4);
      insert into tasks (title, list, position, updated_at) values ('Someday task', 'someday', 2, now() - interval '100 days');
      insert into posts (title, slug, status, body_html, read_time, word_count, webmentions_enabled, updated_at)
      values ('Old draft', 'old-draft', 'draft', '', 1, 1, false, now() - interval '60 days');
      insert into posts (title, slug, status, published_at, body_html, read_time, word_count, webmentions_enabled)
      values ('Linky post', 'linky-post', 'published', now() - interval '1 day', '', 1, 1, false);
      insert into post_link_checks (post_id, url, failures, reason, checked_at, first_failed_at)
      values (2, 'https://bob.example/gone', 2, '404 Not Found', now(), now());
      insert into journal_entries (entry_date, entry_time, body, body_html)
      values ((now() at time zone 'America/Chicago')::date - 3, '09:00', 'Old', '<p>Old</p>');
      delete from known_devices;
      insert into known_devices (browser, os, city, country) values ('Chrome', 'macOS', 'Paris', 'FR'), ('Chrome', 'macOS', 'London', 'GB');
      """
    When I visit "/admin"
    Then the attention card lists:
      """
      Sign-in: Chrome on macOS in London, GB
      Old draft
      Ada Lovelace
      Journal
      Carried task
      Someday task
      Linky post
      """

  Scenario: The card stays out when nothing is stale
    Given the database runs:
      """
      insert into tasks (title, list, position, carried_count) values ('Carried twice', 'next', 1, 2);
      insert into posts (title, slug, status, body_html, read_time, word_count, webmentions_enabled)
      values ('Fresh draft', 'fresh-draft', 'draft', '', 1, 1, false);
      insert into journal_entries (entry_date, entry_time, body, body_html)
      values ((now() at time zone 'America/Chicago')::date, '09:00', 'Today', '<p>Today</p>');
      """
    When I visit "/admin"
    Then the attention card is not shown

  Scenario: A task row links to the task and asks before it cancels
    Given today's sprint plans "Carried task"
    And the database runs:
      """
      update tasks set carried_count = 3 where title = 'Carried task';
      insert into posts (title, slug, status, body_html, read_time, word_count, webmentions_enabled, updated_at)
      values ('Old draft', 'old-draft', 'draft', '', 1, 1, false, now() - interval '60 days');
      """
    When I visit "/admin"
    Then the attention row "Carried task" opens "/admin/tasks/1?origin=today"
    And the attention row "Carried task" asks "Cancel Carried task? It moves to completed." before "Cancel"

  Scenario: A task row moves the task to next and drops off the card
    Given today's sprint plans "Carried task"
    And the database runs:
      """
      update tasks set carried_count = 3 where title = 'Carried task';
      insert into posts (title, slug, status, body_html, read_time, word_count, webmentions_enabled, updated_at)
      values ('Old draft', 'old-draft', 'draft', '', 1, 1, false, now() - interval '60 days');
      """
    When I visit "/admin"
    And I send the "Move to Next" form on the attention row "Carried task"
    Then the Today page sends me to "/admin"
    And the attention card lists:
      """
      Old draft
      """
    And the database answers "next" for:
      """
      select list from tasks where title = 'Carried task'
      """

  Scenario: A task row cancels the task and drops off the card
    Given today's sprint plans "Carried task"
    And the database runs:
      """
      update tasks set carried_count = 3 where title = 'Carried task';
      insert into posts (title, slug, status, body_html, read_time, word_count, webmentions_enabled, updated_at)
      values ('Old draft', 'old-draft', 'draft', '', 1, 1, false, now() - interval '60 days');
      """
    When I visit "/admin"
    And I send the "Cancel" form on the attention row "Carried task"
    Then the Today page sends me to "/admin"
    And the attention card lists:
      """
      Old draft
      """
    And the database answers "canceled" for:
      """
      select status from tasks where title = 'Carried task'
      """

  Scenario: A someday row moves the task to next and drops off the card
    Given the database runs:
      """
      insert into tasks (title, list, position, updated_at) values ('Someday task', 'someday', 1, now() - interval '100 days');
      insert into posts (title, slug, status, body_html, read_time, word_count, webmentions_enabled, updated_at)
      values ('Old draft', 'old-draft', 'draft', '', 1, 1, false, now() - interval '60 days');
      """
    When I visit "/admin"
    And I send the "Move to Next" form on the attention row "Someday task"
    Then the attention card lists:
      """
      Old draft
      """

  Scenario: A draft row opens the post editor
    Given the database runs:
      """
      insert into posts (title, slug, status, body_html, read_time, word_count, webmentions_enabled, updated_at)
      values ('Old draft', 'old-draft', 'draft', '', 1, 1, false, now() - interval '60 days');
      """
    When I visit "/admin"
    Then every link on the attention row "Old draft" goes to "/admin/posts/1/edit"

  Scenario: The journal row opens the journal dialog, and the journal page without scripts
    Given the database runs:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html)
      values ((now() at time zone 'America/Chicago')::date - 3, '09:00', 'Old', '<p>Old</p>');
      """
    When I visit "/admin"
    Then every link on the attention row "Journal" goes to "/admin/journal?write=1"
    And every link on the attention row "Journal" opens the dialog "journal-write"
    And the attention row "Journal" offers "Write" at "/admin/journal?write=1"

  Scenario: A new device row opens security
    Given the database runs:
      """
      delete from known_devices;
      insert into known_devices (browser, os, city, country) values ('Chrome', 'macOS', 'Paris', 'GB'), ('Chrome', 'macOS', 'London', 'GB');
      """
    When I visit "/admin"
    Then the attention row "Sign-in: Chrome on macOS in London, GB" offers "Open security" at "/admin/settings/security"

  Scenario: The inbox line counts what waits and opens the inbox
    Given the database runs:
      """
      insert into mail_accounts (provider, name) values ('contact_form', 'Contact form');
      insert into mail_threads (mail_account_id, subject, status) values (1, 'One', 'unread'), (1, 'Two', 'unread'), (1, 'Three', 'read');
      """
    When I visit "/admin"
    Then the Today line "Inbox" reads "2 waiting →"
    And the Today line "Inbox" links to "/admin/inbox"

  Scenario: The inbox line stays out with nothing waiting
    Given the database runs:
      """
      insert into posts (title, slug, status, body_html, read_time, word_count, webmentions_enabled, updated_at)
      values ('Old draft', 'old-draft', 'draft', '', 1, 1, false, now() - interval '60 days');
      """
    When I visit "/admin"
    Then the Today page has no line "Inbox"

  Scenario: Failed cross-posts count the posts that gave up and open the posted queue
    Given the database runs:
      """
      insert into social_posts (targets, status, posted_at) values ('{mastodon}', 'posted', now() - interval '1 day'), ('{mastodon}', 'posted', now() - interval '1 day');
      insert into social_post_parts (social_post_id, position, body) select id, 1, 'Hello' from social_posts;
      insert into social_post_deliveries (social_post_id, network, failed, error) select id, 'mastodon', true, 'rate limited' from social_posts;
      """
    When I visit "/admin"
    Then the Today line "Cross-posts" reads "2 failed →"
    And the Today line "Cross-posts" links to "/admin/social?filter=posted"

  Scenario: Failed cross-posts open the queued list while a failed post still waits on a network
    Given the database runs:
      """
      insert into social_posts (targets, status, posted_at) values ('{mastodon}', 'scheduled', now() + interval '1 day');
      insert into social_post_parts (social_post_id, position, body) select id, 1, 'Hello' from social_posts;
      insert into social_post_deliveries (social_post_id, network, failed, error) select id, 'mastodon', true, 'rate limited' from social_posts;
      """
    When I visit "/admin"
    Then the Today line "Cross-posts" links to "/admin/social?filter=queued"

  Scenario: A delivery that will retry leaves the card out
    Given the database runs:
      """
      insert into social_posts (targets, status, posted_at) values ('{mastodon}', 'posted', now() - interval '1 day');
      insert into social_post_parts (social_post_id, position, body) select id, 1, 'Hello' from social_posts;
      insert into social_post_deliveries (social_post_id, network, error) select id, 'mastodon', 'rate limited' from social_posts;
      """
    When I visit "/admin"
    Then the attention card is not shown

  Scenario: Broken links count links in posts and short links and open the Posts filter
    Given the database runs:
      """
      insert into posts (title, slug, status, published_at, body_html, read_time, word_count, webmentions_enabled)
      values ('One', 'one', 'published', now() - interval '1 day', '', 1, 1, false),
              ('Two', 'two', 'published', now() - interval '1 day', '', 1, 1, false);
      insert into post_link_checks (post_id, url, reason, checked_at) select id, 'https://bob.example/gone', '404 Not Found', now() from posts;
      insert into short_codes (code) values ('slow');
      insert into short_links (short_code_id, destination) select id, 'https://cy.example/slow' from short_codes;
      insert into short_link_checks (short_link_id, url, reason, checked_at) select id, destination, 'Timed out after 10 seconds', now() from short_links;
      """
    When I visit "/admin"
    Then the Today line "Broken links" reads "2 in posts · 1 short →"
    And the Today line "Broken links" links to "/admin/posts?status=broken"

  Scenario: Broken links give one count when only one kind fails
    Given the database runs:
      """
      insert into short_codes (code) values ('slow');
      insert into short_links (short_code_id, destination) select id, 'https://cy.example/slow' from short_codes;
      insert into short_link_checks (short_link_id, url, reason, checked_at) select id, destination, 'Timed out after 10 seconds', now() from short_links;
      """
    When I visit "/admin"
    Then the Today line "Broken links" reads "1 failing →"
    And the attention card counts "1"

  Scenario: Broken links leave out links that answered and links in drafts
    Given the database runs:
      """
      insert into posts (title, slug, status, published_at, body_html, read_time, word_count, webmentions_enabled)
      values ('Out', 'out', 'published', now() - interval '1 day', '', 1, 1, false),
              ('Draft', 'draft', 'draft', null, '', 1, 1, false);
      insert into post_link_checks (post_id, url, reason, checked_at) values (1, 'https://ada.example', null, now()), (2, 'https://bob.example/gone', '404 Not Found', now());
      """
    When I visit "/admin"
    Then the Today page has no line "Broken links"

  Scenario: Snoozing takes a task row, a draft row or the journal row off the card
    Given the database runs:
      """
      insert into posts (title, slug, status, body_html, read_time, word_count, webmentions_enabled, updated_at)
      values ('Old draft', 'old-draft', 'draft', '', 1, 1, false, now() - interval '60 days');
      insert into tasks (title, list, position, carried_count) values ('Carried task', 'next', 1, 4);
      insert into tasks (title, list, position, updated_at) values ('Someday task', 'someday', 2, now() - interval '100 days');
      insert into journal_entries (entry_date, entry_time, body, body_html)
      values ((now() at time zone 'America/Chicago')::date - 3, '09:00', 'Old', '<p>Old</p>');
      """
    When I visit "/admin"
    And I send the "Snooze for a week" form on the attention row "Carried task"
    Then the Today page sends me to "/admin"
    And the attention card lists:
      """
      Old draft
      Journal
      Someday task
      """
    When I send the "Snooze for a week" form on the attention row "Journal"
    Then the attention card lists:
      """
      Old draft
      Someday task
      """
    When I send the "Snooze for a week" form on the attention row "Old draft"
    Then the attention card lists:
      """
      Someday task
      """
    And the database answers "carried true, journal true, draft true" for:
      """
      select string_agg(kind || ' ' || (abs(extract(epoch from ends_at - (now() + interval '7 days'))) < 60)::text, ', ' order by id)
      from attention_snoozes
      """

  Scenario: Snoozing a snoozed row again moves the end out a week
    Given the database runs:
      """
      insert into posts (title, slug, status, body_html, read_time, word_count, webmentions_enabled, updated_at)
      values ('Old draft', 'old-draft', 'draft', '', 1, 1, false, now() - interval '60 days');
      insert into attention_snoozes (kind, record_id, ends_at) values ('draft', 1, now() + interval '1 day');
      """
    When I post "/admin/attention/snooze" from the Today page with "kind=draft&record_id=1"
    Then the database answers "true" for:
      """
      select ends_at > now() + interval '7 days' - interval '1 minute' from attention_snoozes
      """

  Scenario: A snooze keeps a row off the card for seven days, and the row comes back after while still stalled
    Given the database runs:
      """
      insert into posts (title, slug, status, body_html, read_time, word_count, webmentions_enabled, updated_at)
      values ('Old draft', 'old-draft', 'draft', '', 1, 1, false, now() - interval '60 days');
      insert into journal_entries (entry_date, entry_time, body, body_html)
      values ((now() at time zone 'America/Chicago')::date - 10, '09:00', 'Old', '<p>Old</p>');
      insert into attention_snoozes (kind, ends_at) values ('journal', now() + interval '1 day');
      """
    When I visit "/admin"
    Then the attention card lists:
      """
      Old draft
      """
    Given the database runs:
      """
      update attention_snoozes set ends_at = now() - interval '1 day';
      """
    When I visit "/admin"
    Then the attention card lists:
      """
      Journal
      Old draft
      """

  Scenario: Deleting a snoozed task or draft leaves no snooze behind
    Given the database runs:
      """
      insert into posts (title, slug, status, body_html, read_time, word_count, webmentions_enabled, updated_at)
      values ('Old draft', 'old-draft', 'draft', '', 1, 1, false, now() - interval '60 days');
      insert into tasks (title, list, position, updated_at) values ('Someday task', 'someday', 1, now() - interval '100 days');
      insert into attention_snoozes (kind, record_id, ends_at) values ('someday', 1, now() + interval '7 days'), ('draft', 1, now() + interval '7 days');
      """
    When I post "/admin/tasks/1/delete" from the Today page with ""
    Then the database answers "draft" for:
      """
      select kind from attention_snoozes
      """
    When I post "/admin/posts/1/delete" from the Today page with ""
    Then the database answers "0" for:
      """
      select count(*) from attention_snoozes
      """

  Scenario Outline: Snoozing refuses a row it cannot find
    When I post "/admin/attention/snooze" from the Today page with "<fields>"
    Then the Today post answers 404

    Examples:
      | fields                  |
      | kind=carried&record_id=1 |
      | kind=nope               |
