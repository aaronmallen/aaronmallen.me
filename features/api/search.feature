Feature: API search
  The JSON API and the search tool find every kind of record the admin keeps by a phrase, ranked and paged as the
  admin search page lists them. A token without the mail, notes or contacts permission sees less.

  Background:
    Given an API token with the scopes "read write mail notes contacts"

  Scenario: A phrase several kinds hold lists every match with its kind, ID, title, label, match and date
    Given the search database runs:
      """
      insert into tasks (title, list, status, completed_at, position) values ('Track the zeppelin', 'next', 'done', now(), 1);
      insert into tasks (title, list, position) values ('Call the plumber', 'next', 2);
      insert into posts (title, slug, status, published_at, body, body_html, read_time, word_count, webmentions_enabled)
      values ('Zeppelins', 'zeppelins', 'published', now() - interval '1 day', 'A post', '<p>A post</p>', 1, 2, false);
      insert into mail_accounts (provider, name) values ('contact_form', 'Contact form');
      insert into mail_threads (mail_account_id, subject, status) values (1, 'Zeppelin sighting', 'read');
      insert into mail_messages (mail_thread_id, subject, body) values (1, 'Zeppelin sighting', 'Hi there');
      """
    When I search the API with "?query=zeppelin"
    Then the API search answers 200
    And the API search gives the titles "Track the zeppelin, Zeppelins, Zeppelin sighting" in any order
    And every API search result has the fields "kind, id, title, label, match, date" in that order
    And the API search gives the labels "1, none, none" in any order
    And the API search gives the kinds "task, post, message" in any order
    When I search the API with "?query=track"
    Then the API search gives the kinds "task"
    And the API search gives the ids "1"
    And the API search gives the titles "Track the zeppelin"
    And the API search's "results.0.match" holds the text "Track the zeppelin"
    And the API search gives the dates "{today}"
    And the API search's first id reads as the task "Track the zeppelin"

  Scenario: The API lists the records the search screen lists, in the same order, for every kind or one
    Given I am signed in to the admin
    And the search database runs:
      """
      insert into tasks (title, list, status, completed_at, position) values ('Track the zeppelin', 'next', 'done', now(), 1);
      insert into posts (title, slug, status, published_at, body, body_html, read_time, word_count, webmentions_enabled)
      values ('Zeppelins', 'zeppelins', 'published', now() - interval '1 day', 'A post', '<p>A post</p>', 1, 2, false);
      insert into mail_accounts (provider, name) values ('contact_form', 'Contact form');
      insert into mail_threads (mail_account_id, subject, status) values (1, 'Zeppelin sighting', 'read');
      insert into mail_messages (mail_thread_id, subject, body) values (1, 'Zeppelin sighting', 'Hi there');
      """
    When I search the API with "?query=zeppelin"
    Then the API search lists the titles the admin search lists for "?q=zeppelin"
    When I search the API with "?query=zeppelin&kind=message"
    Then the API search lists the titles the admin search lists for "?q=zeppelin&kind=message"

  Scenario: A token without mail is refused the message kind with a 422 on kind
    Given an API token with the scopes "read write publish delete health agents notes contacts"
    When I search the API with "?query=zeppelin&kind=message"
    Then the API search answers 422
    And the API search's "errors" is:
      """
      {"kind": ["message rows need the mail scope"]}
      """

  Scenario: The search tool finds a task by its label and answers as the endpoint does
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read mail"
    And the search database runs:
      """
      insert into tasks (title, list, status, completed_at, position) values ('Track the zeppelin', 'next', 'done', now(), 1);
      insert into tasks (title, list, position) values ('Call the plumber', 'next', 2);
      """
    When I search with the MCP tool, given:
      """
      {"query": "1"}
      """
    Then the API search's "results.0.id" is "1"
    And the API search's "results.0.label" is "1"
    And the MCP search answers as the API search does, given:
      """
      {"query": "zeppelin", "kind": "task"}
      """

  Scenario: Paging answers a page with the number of the next, then the last page, as the screen and the tool do
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read mail"
    And the search database runs:
      """
      insert into tasks (title, list, position) select 'Call the plumber ' || n, 'next', n from generate_series(1, 101) n;
      insert into mail_accounts (provider, name) values ('contact_form', 'Contact form');
      insert into mail_threads (mail_account_id, subject) values (1, 'Plumber invoice');
      insert into mail_messages (mail_thread_id, subject, body) values (1, 'Plumber invoice', 'Pay up');
      """
    When I search the API with "?query=plumber&kind=task"
    Then the API search's "count" is "100"
    And the API search's "partial" is "true"
    And the API search's "next_page" is "2"
    When I search the API with "?query=plumber&kind=task&page=2"
    Then the API search's "count" is "1"
    And the API search's "partial" is "false"
    And the API search has no "next_page"
    When I search the API with "?query=plumber&page=1"
    Then the API search lists the titles the admin search lists for "?q=plumber&page=1"
    When I search the API with "?query=plumber&page=2"
    Then the API search lists the titles the admin search lists for "?q=plumber&page=2"
    And the MCP search answers as the API search does, given:
      """
      {"query": "plumber", "page": 2}
      """

  Scenario Outline: The search finds <what> the admin keeps private or closed
    Given the search database runs:
      """
      <insert>
      """
    When I search the API with "?query=<query>"
    Then the API search gives the kinds "<kind>"
    And the API search gives the ids "1"

    Examples:
      | what                       | query      | kind    | insert                                                                                                                                                                                                                   |
      | a journal entry            | levee      | journal | insert into journal_entries (entry_date, entry_time, body, body_html) values ('{today}', '09:00', 'Walked the levee at dawn', '<p>Walked</p>')                                                                          |
      | a closed task              | passport   | task    | insert into tasks (title, list, status, completed_at, position) values ('Renew the passport', 'next', 'done', now(), 1)                                                                                                  |
      | a canceled task            | porch      | task    | insert into tasks (title, list, status, completed_at, position) values ('Repaint the porch', 'next', 'canceled', now(), 1)                                                                                               |
      | a commit from a private repo | thermostat | commit | insert into commits (sha, repo, branch, message, commit_date, commit_time) values ('a1', 'aaronmallen/secret-lab', 'main', 'Wire the thermostat relay', '{today}', '09:00')                                            |
      | a read message             | sourdough  | message | insert into mail_accounts (provider, name) values ('contact_form', 'Contact form'); insert into mail_threads (mail_account_id, subject, status) values (1, 'Hello', 'read'); insert into mail_messages (mail_thread_id, subject, body) values (1, 'Hello', 'Loved your piece on sourdough') |
      | a draft post               | kayaks     | post    | insert into posts (title, slug, status, body, body_html, read_time, word_count, webmentions_enabled) values ('Notes on kayaks', 'kayaks', 'draft', 'Half done', '<p>Half done</p>', 1, 2, false)                        |

  Scenario: A phrase every kind holds finds one of each kind, and the note only with the notes permission
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read mail"
    And the search database runs:
      """
      insert into tasks (title, note, list, position) values ('Open task', 'about zeppelins', 'next', 1);
      insert into posts (title, slug, status, published_at, body, body_html, read_time, word_count, webmentions_enabled)
      values ('Zeppelins', 'zeppelins', 'published', now() - interval '1 day', 'A post', '<p>A post</p>', 1, 2, false);
      insert into social_posts (targets, status, posted_at) values ('{mastodon}', 'posted', now() - interval '1 day');
      insert into social_post_parts (social_post_id, position, body) values (1, 1, 'Saw a zeppelin');
      insert into journal_entries (entry_date, entry_time, body, body_html) values ('{today}', '09:00', 'Dreamt of zeppelins', '<p>Dreamt</p>');
      insert into commits (sha, repo, branch, message, commit_date, commit_time) values ('a1', 'aaronmallen/aaronmallen.me', 'main', 'Draw the zeppelin', '{today}', '09:00');
      insert into projects (name, tagline, visibility, key) values ('airship', 'Zeppelin tracker', 'public', 'AIR');
      insert into work_entries (org, role, from_year, position) values ('Zeppelin Works', 'Pilot', 2020, 1);
      insert into people (name) values ('Zeppelin Fan');
      insert into mail_accounts (provider, name) values ('contact_form', 'Contact form');
      insert into mail_threads (mail_account_id, subject) values (1, 'Zeppelins');
      insert into mail_messages (mail_thread_id, subject, body) values (1, 'Zeppelins', 'Hi there');
      insert into webmentions (post_id, source_url, author_name, author_url, type, excerpt)
      values (1, 'https://source.example/note', 'Someone', 'https://someone.example/', 'mention', 'Nice zeppelin');
      insert into decisions (title, problem) values ('Buy a zeppelin', 'We need one');
      insert into pull_requests (repo, number, title, url, opened_at) values ('aaronmallen/aaronmallen.me', 1, 'Land the zeppelin', 'https://github.com/aaronmallen/aaronmallen.me/pull/1', now());
      insert into notes (title) values ('Zeppelin sketches');
      """
    When I search the API with "?query=zeppelin"
    Then the API search gives the kinds "task, post, social, journal, commit, project, work, person, message, webmention, decision, pull_request, note" in any order
    When I search with the MCP tool, given:
      """
      {"query": "zeppelin"}
      """
    Then the API search gives the kinds "task, post, social, journal, commit, project, work, person, message, webmention, decision, pull_request" in any order
    Given an API token with the scopes "read"
    When I search the API with "?query=zeppelin"
    Then the API search gives the kinds "task, post, social, journal, commit, project, work, person, webmention, decision, pull_request" in any order
    And the API search lists fewer titles than the admin search lists for "?q=zeppelin", leaving out "Zeppelin sketches"

  Scenario: A contact matches by its company and takes the company as a title when it has no name
    Given the search database runs:
      """
      insert into people (name, key, company) values ('Ada', 'countess', 'Analytical Engines');
      insert into people (name, key, company) values (null, 'babbage', 'Difference Engines');
      """
    When I search the API with "?query=engines"
    Then the API search gives the titles "Ada, Difference Engines" in any order
    And the API search gives the kinds "person, person"

  Scenario: A contact is found by its company, titled by its name or else the company
    Given the search database runs:
      """
      insert into people (name, company) values (null, 'Analytical Engines');
      insert into people (name, company) values ('Ada Lovelace', 'Lovelace Engines');
      """
    When I search the API with "?query=analytical"
    Then the API search gives the titles "Analytical Engines"
    When I search the API with "?query=lovelace"
    Then the API search gives the titles "Ada Lovelace"

  Scenario: A token without contacts matches a contact only by its name, key and handles, titled by its key
    Given an API token with the scopes "read write publish delete health mail agents notes"
    And the search database runs:
      """
      insert into people (name, key, company) values ('Ada', 'countess', 'Analytical Engines');
      insert into people (name, key, company) values (null, 'babbage', 'Difference Engines');
      """
    When I search the API with "?query=engines"
    Then the API search gives nothing
    When I search the API with "?query=countess"
    Then the API search gives the titles "Ada"
    When I search the API with "?query=babbage"
    Then the API search gives the titles "babbage"

  Scenario: The search tool narrows a contact the same way without the contacts permission
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read mail"
    And the search database runs:
      """
      insert into people (name, key, company) values ('Ada', 'countess', 'Analytical Engines');
      """
    When I search with the MCP tool, given:
      """
      {"query": "engines"}
      """
    Then the API search gives nothing

  Scenario: The note kind needs the notes permission
    Given the search database runs:
      """
      insert into notes (title) values ('Zeppelin sketches');
      """
    When I search the API with "?query=zeppelin&kind=note"
    Then the API search gives the kinds "note"
    And the API search gives the ids "1"
    Given an API token with the scopes "read write publish delete health mail agents contacts"
    When I search the API with "?query=zeppelin&kind=note"
    Then the API search answers 422
    And the API search's "errors" is:
      """
      {"kind": ["note rows need the notes scope"]}
      """

  Scenario: The search tool keeps an owner's note plain and marks a note an agent wrote
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read notes"
    And the search database runs:
      """
      insert into notes (title) values ('Zeppelin sketches');
      """
    When I search with the MCP tool, given:
      """
      {"query": "zeppelin"}
      """
    Then the API search's "results.0.title" is "Zeppelin sketches"
    Given the search database runs:
      """
      update notes set written_by_agent = true
      """
    When I search with the MCP tool, given:
      """
      {"query": "zeppelin"}
      """
    Then the API search's "results.0.title.untrusted" is "true"
    And the API search's "results.0.match.untrusted" is "true"

  Scenario: A long post carries its title, the day it went out and a short match around the phrase
    Given the search database runs:
      """
      insert into posts (title, slug, status, published_at, body, body_html, read_time, word_count, webmentions_enabled)
      values ('Bread', 'bread', 'published', '{today-2} 12:00 America/Chicago',
        repeat('flour ', 200) || 'crumb ' || repeat('salt ', 200), '<p>Bread</p>', 2, 401, false);
      """
    When I search the API with "?query=crumb"
    Then the API search gives the titles "Bread"
    And the API search gives the dates "{today-2}"
    And the API search's first match holds "crumb"
    And each API search match runs to 24 words or fewer

  Scenario: A match stays short and leaves markup out
    Given the search database runs:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html) values
        ('{today}', '09:00', repeat('rain ', 100) || 'garden', '<p>Rain</p>'),
        ('{today}', '09:00', 'Fed the ducks', '<p>Fed the ducks</p>');
      """
    When I search the API with "?query=garden"
    Then each API search match runs to 24 words or fewer
    When I search the API with "?query=ducks"
    Then the API search's "results.0.match" is "Fed the ducks"

  Scenario: A result takes its date from a journal entry's day or an open task's making
    Given the search database runs:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html) values ('{today-30}', '09:00', 'Bought a canoe', '<p>Canoe</p>');
      insert into tasks (title, list, position) values ('Find the ladder', 'next', 1);
      """
    When I search the API with "?query=canoe"
    Then the API search gives the dates "{today-30}"
    When I search the API with "?query=ladder"
    Then the API search gives the dates "{today}"

  Scenario: A commit takes the first line of its message as its title
    Given the search database runs:
      """
      insert into commits (sha, repo, branch, message, commit_date, commit_time)
      values ('a1', 'aaronmallen/aaronmallen.me', 'main', E'Fix the gutter\n\nIt leaked', '{today}', '09:00');
      """
    When I search the API with "?query=leaked"
    Then the API search gives the titles "Fix the gutter"

  Scenario: A social post with several parts comes back once, as the part that matches best
    Given the search database runs:
      """
      insert into social_posts (targets, status, posted_at) values ('{mastodon}', 'posted', now() - interval '1 day');
      insert into social_post_parts (social_post_id, position, body) values
        (1, 1, 'A first part'), (1, 2, 'Otters are out'), (1, 3, 'Otters otters otters');
      """
    When I search the API with "?query=otters"
    Then the API search gives the ids "1"
    And the API search gives the titles "Otters otters otters"

  Scenario: Each record ranks once, headlined from its best match
    Given the search database runs:
      """
      insert into mail_accounts (provider, name) values ('contact_form', 'Contact form');
      insert into mail_threads (mail_account_id, subject) values (1, 'Hello');
      insert into mail_messages (mail_thread_id, subject, body, reply_to) values
        (1, 'Hello', 'One sourdough loaf', null),
        (1, 'Re: Hello', 'Sourdough starter, sourdough loaf', 'baker@example.com');
      insert into tasks (title, list, position) values ('Feed the sourdough sourdough starter sourdough', 'next', 1);
      insert into journal_entries (entry_date, entry_time, body, body_html) values
        ('{today}', '09:00', E'Baked rye\nThen a sourdough loaf', '<p>Baked rye</p>');
      """
    When I search the API with "?query=sourdough"
    Then the API search gives the kinds "task, message, journal"
    And the API search gives the titles "Feed the sourdough sourdough starter sourdough, Hello, Baked rye"
    And the API search's "results.1.match" holds the text "Sourdough starter, sourdough loaf"

  Scenario: A title match ranks above a match in the text, and the newer comes first on a tie
    Given the search database runs:
      """
      insert into tasks (title, note, list, position) values ('Errands', 'Pick up the mangoes', 'next', 1), ('Mangoes', '', 'next', 2);
      insert into journal_entries (entry_date, entry_time, body, body_html) values
        ('{today-2}', '09:00', 'Lemons', '<p>Lemons</p>'), ('{today-1}', '09:00', 'Lemons', '<p>Lemons</p>');
      """
    When I search the API with "?query=mangoes"
    Then the API search gives the titles "Mangoes, Errands"
    When I search the API with "?query=lemons"
    Then the API search gives the dates "{today-1}, {today-2}"

  Scenario: The phrase matches a word by its stem and leaves out a word it rules out
    Given the search database runs:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html) values
        ('{today}', '09:00', 'Running at noon', '<p>Running</p>'),
        ('{today}', '09:00', 'Plums and figs', '<p>Plums</p>'),
        ('{today}', '09:00', 'Plums alone', '<p>Plums</p>');
      """
    When I search the API with "?query=runs"
    Then the API search gives the titles "Running at noon"
    When I search the API with "?query=plums%20-figs"
    Then the API search gives the titles "Plums alone"

  Scenario: A blank phrase or a phrase of stop words answers nothing
    Given the search database runs:
      """
      insert into tasks (title, list, position) values ('Track the zeppelin', 'next', 1);
      insert into journal_entries (entry_date, entry_time, body, body_html) values ('{today}', '09:00', 'The and of', '<p>The</p>');
      """
    When I search the API with "?query=%20%20"
    Then the API search's "" is:
      """
      {"count": 0, "results": [], "partial": false}
      """
    When I search the API with "?query=the"
    Then the API search gives nothing

  Scenario: The search refuses a request with no query or a kind it does not know
    When I search the API with ""
    Then the API search answers 422
    And the API search's "errors.query" is:
      """
      ["query is missing"]
      """
    When I search the API with "?query=zeppelin&kind=spaceship"
    Then the API search answers 422
