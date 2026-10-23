Feature: Admin Today page
  The Today page opens the admin. It lays out the sprint, the calendar, what shipped and a column of quiet lines
  that each count one thing and link to where it lives.

  Background:
    Given I am signed in to the admin
    And the country database holds the test networks

  Scenario: Today puts the sprint on the left and the other cards on the right
    When I visit "/admin"
    Then the Today main column holds the cards "Today's sprint"
    And the Today side column holds the cards "Calendar, Shipped today, Agents"
    And the Today page shows no stat strip

  Scenario: Today lists the quiet lines under Shipped today
    When I visit "/admin"
    Then the quiet Today lines are "Journal, What ships next, Drafts, Visitors, MCP clients"

  Scenario: What ships next opens the editor of the soonest scheduled post
    Given the database runs:
      """
      insert into posts (title, slug, status, published_at, body_html, read_time, word_count, webmentions_enabled)
      values ('Later', 'later', 'scheduled', now() + interval '2 minutes', '', 1, 1, false),
              ('Sooner', 'sooner', 'scheduled', now() + interval '1 minute', '', 1, 1, false);
      """
    When I visit "/admin"
    Then the Today line "What ships next" links to the post "Sooner"

  Scenario: What ships next opens the queued social posts when a social post goes first
    Given the database runs:
      """
      insert into posts (title, slug, status, published_at, body_html, read_time, word_count, webmentions_enabled)
      values ('Later', 'later', 'scheduled', now() + interval '10 minutes', '', 1, 1, false);
      insert into social_posts (targets, status, posted_at) values ('{mastodon}', 'scheduled', now() + interval '1 minute');
      insert into social_post_parts (social_post_id, position, body) select id, 1, 'Social' from social_posts;
      """
    When I visit "/admin"
    Then the Today line "What ships next" links to "/admin/social?filter=queued"

  Scenario: What ships next gives the Chicago time of the next item
    Given the database runs:
      """
      insert into posts (title, slug, status, published_at, body_html, read_time, word_count, webmentions_enabled)
      values ('Far off', 'far-off', 'scheduled', '2030-01-07 15:30:00+00', '', 1, 1, false);
      """
    When I visit "/admin"
    Then the Today line "What ships next" has the time "2030-01-07T09:30:00-06:00"
    And the Today line "What ships next" reads "Jan 7, 2030, 09:30 · 1 queued"

  Scenario: What ships next counts scheduled posts and scheduled social posts together
    Given the database runs:
      """
      insert into posts (title, slug, status, published_at, body_html, read_time, word_count, webmentions_enabled)
      values ('One', 'one', 'scheduled', now() + interval '1 minute', '', 1, 1, false),
              ('Two', 'two', 'scheduled', now() + interval '2 minutes', '', 1, 1, false);
      insert into social_posts (targets, status, posted_at) values ('{mastodon}', 'scheduled', now() + interval '1 minute');
      insert into social_post_parts (social_post_id, position, body) select id, 1, 'Social' from social_posts;
      """
    When I visit "/admin"
    Then the Today line "What ships next" ends with "· 3 queued"

  Scenario: What ships next reads nothing scheduled and opens the calendar without a queue
    Given the database runs:
      """
      insert into posts (title, slug, status, published_at, body_html, read_time, word_count, webmentions_enabled)
      values ('Draft', 'draft', 'draft', null, '', 1, 1, false),
              ('Out', 'out', 'published', now() - interval '1 day', '', 1, 1, false);
      insert into social_posts (targets, status, posted_at) values ('{mastodon}', 'posted', now() - interval '1 day');
      insert into social_post_parts (social_post_id, position, body) select id, 1, 'Social' from social_posts;
      """
    When I visit "/admin"
    Then the Today line "What ships next" reads "nothing scheduled"
    And the Today line "What ships next" links to "/admin/calendar"

  Scenario: Drafts counts only drafts and opens the drafts list
    Given the database runs:
      """
      insert into posts (title, slug, status, published_at, body_html, read_time, word_count, webmentions_enabled)
      values ('Draft', 'draft', 'draft', null, '', 1, 1, false),
              ('Soon', 'soon', 'scheduled', now() + interval '1 day', '', 1, 1, false),
              ('Out', 'out', 'published', now() - interval '1 day', '', 1, 1, false);
      """
    When I visit "/admin"
    Then the Today line "Drafts" reads "1"
    And the Today line "Drafts" links to "/admin/posts?status=draft"

  Scenario: Drafts reads none without drafts
    Given the database runs:
      """
      insert into posts (title, slug, status, published_at, body_html, read_time, word_count, webmentions_enabled)
      values ('Soon', 'soon', 'scheduled', now() + interval '1 day', '', 1, 1, false);
      """
    When I visit "/admin"
    Then the Today line "Drafts" reads "none"

  Scenario: Visitors counts each visitor today once and opens analytics
    Given the database runs:
      """
      insert into analytics_events (path, visitor_hash, address_hash, occurred_at)
      values ('/one', encode(sha256('first'), 'hex'), encode(sha256('a'), 'hex'), now()),
              ('/two', encode(sha256('first'), 'hex'), encode(sha256('a'), 'hex'), now()),
              ('/one', encode(sha256('second'), 'hex'), encode(sha256('b'), 'hex'), now());
      """
    When I visit "/admin"
    Then the Today line "Visitors" reads "2 visitors today"
    And the Today line "Visitors" links to "/admin/analytics"

  Scenario: Visitors leaves out visits from before today
    Given the database runs:
      """
      insert into analytics_events (path, visitor_hash, address_hash, occurred_at)
      values ('/one', encode(sha256('today'), 'hex'), encode(sha256('a'), 'hex'), now()),
              ('/one', encode(sha256('yesterday'), 'hex'), encode(sha256('b'), 'hex'),
              (date_trunc('day', now() at time zone 'America/Chicago') at time zone 'America/Chicago') - interval '1 second');
      """
    When I visit "/admin"
    Then the Today line "Visitors" reads "1 visitor today"

  Scenario: MCP clients counts the connected clients and opens them
    Given the database runs:
      """
      insert into oauth_clients (client_id, client_name, visitor_hash, redirect_uris, grant_types, response_types)
      values ('client-1', 'Claude', repeat('0', 64), '{https://claude.ai/callback}', '{authorization_code}', '{code}'),
              ('client-2', 'Idle', repeat('1', 64), '{https://claude.ai/callback}', '{authorization_code}', '{code}');
      insert into oauth_tokens (oauth_client_id, type, token_digest, expires_at)
      values (1, 'access', repeat('2', 64), now() + interval '1 hour');
      """
    When I visit "/admin"
    Then the Today line "MCP clients" reads "1 connected"
    And the Today line "MCP clients" links to "/admin/settings/services#clients"

  Scenario: Last night gives the sleep, HRV and resting heart rate after What ships next
    Given the database runs:
      """
      insert into health_days (day, minutes_asleep, hrv, resting_heart_rate, steps)
      values ((now() at time zone 'America/Chicago')::date, 425, 47.6, 54, 9000);
      """
    When I visit "/admin"
    Then the Today line "Last night" reads "7h 05m asleep · hrv 48 · rhr 54"
    And the quiet Today lines are "Journal, What ships next, Last night, Drafts, Visitors, MCP clients"

  Scenario: Last night stays out without last night's sleep
    Given the database runs:
      """
      insert into health_days (day, minutes_asleep) values ((now() at time zone 'America/Chicago')::date - 1, 425);
      insert into health_days (day, steps) values ((now() at time zone 'America/Chicago')::date, 9000);
      """
    When I visit "/admin"
    Then the Today page has no line "Last night"

  Scenario: Needs attention stays out without a pending webmention
    Given the database runs:
      """
      insert into posts (title, slug, status, published_at, body_html, read_time, word_count, webmentions_enabled)
      values ('Out', 'out', 'published', now() - interval '1 day', '', 1, 1, true);
      insert into webmentions (post_id, source_url, type, status) values (1, 'https://a.example/1', 'mention', 'approved');
      insert into webmentions (post_id, source_url, type, status) values (1, 'https://a.example/2', 'mention', 'spam');
      """
    When I visit "/admin"
    Then the attention card is not shown

  Scenario: Needs attention counts pending webmentions as the palette's Inbox does
    Given the database runs:
      """
      insert into posts (title, slug, status, published_at, body_html, read_time, word_count, webmentions_enabled)
      values ('Out', 'out', 'published', now() - interval '1 day', '', 1, 1, true);
      insert into webmentions (post_id, source_url, type)
      select 1, 'https://a.example/' || n, 'mention' from generate_series(1, 4) n;
      insert into webmentions (post_id, source_url, type, status) values (1, 'https://a.example/5', 'mention', 'approved');
      """
    When I visit "/admin"
    Then the Today line "Webmentions" reads "4 waiting →"
    And the Today line "Webmentions" links to "/admin/webmentions?status=pending"
    And the command palette's Inbox reads "4 waiting"

  Scenario: A pending webmention warns on its line and not on the quiet lines
    Given the database runs:
      """
      insert into posts (title, slug, status, published_at, body_html, read_time, word_count, webmentions_enabled)
      values ('Out', 'out', 'published', now() - interval '1 day', '', 1, 1, true);
      insert into webmentions (post_id, source_url, type) values (1, 'https://a.example/1', 'mention');
      """
    When I visit "/admin"
    Then the Today line "Webmentions" reads "1 waiting →"
    And the Today line "Webmentions" warns
    And the Today line "Drafts" does not warn

  Scenario: The Journal line counts today's entries and opens the journal dialog
    Given the database runs:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html)
      values ((now() at time zone 'America/Chicago')::date, '09:00', 'One', '<p>One</p>'),
              ((now() at time zone 'America/Chicago')::date, '10:00', 'Two', '<p>Two</p>'),
              ((now() at time zone 'America/Chicago')::date - 1, '09:00', 'Old', '<p>Old</p>');
      """
    When I visit "/admin"
    Then the Today line "Journal" reads "2 today w"
    And the Today line "Journal" shows the key "w"
    And the Today line "Journal" opens the dialog "journal-write"
    And the Today line "Journal" links to "/admin/journal?write=1"
    And the Today page has no card "Journal"

  Scenario: The Journal line reads nothing yet without an entry today
    When I visit "/admin"
    Then the Today line "Journal" reads "nothing yet w"

  Scenario Outline: The Today pages pass axe in light and dark
    Given the Today page has a GitHub token
    And today's sprint plans "Ship the panel, Read the design" with 1 done
    And the Today pool someday holds "Learn Elixir"
    And the dead job "Social::Jobs::SendWebmention" died 60 minutes ago
    And these commits for the Today page:
      | time  | message                     |
      | 14:05 | admin: add the commits card |
    And these calendar events for the Today page:
      | title            | starts | ends   | place         | meet                        |
      | Coffee with Sean | +1h    | +2h    | Sawada Coffee | https://meet.google.com/abc |
      | Holiday          |        |        |               |                             |
    And the database runs:
      """
      insert into posts (title, slug, status, body_html, read_time, word_count, webmentions_enabled, updated_at)
      values ('Old draft', 'old-draft', 'draft', '', 1, 1, false, now() - interval '60 days');
      insert into journal_entries (entry_date, entry_time, body, body_html)
      values ((now() at time zone 'America/Chicago')::date - 3, '09:00', 'Old', '<p>Old</p>');
      """
    When I visit "<path>"
    Then the page has no axe breaches in light or dark

    Examples:
      | path                                                 |
      | /admin                                               |
      | /admin?pool=someday                                  |
      | /admin?pool=external                                 |
      | /admin/tasks/new?origin=today&title=Coffee%20with%20Sean |
      | /admin/activity                                      |
