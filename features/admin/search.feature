Feature: Admin search
  The admin search page finds every kind of record by a phrase, groups the matches by kind, counts them, and
  narrows to one kind or pages through them.

  Background:
    Given I am signed in to the admin

  Scenario: A phrase several kinds hold lists each match once, grouped and counted by kind
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
    When I visit "/admin/search?q=zeppelin"
    Then the admin search lists "Track the zeppelin, Zeppelins, Zeppelin sighting" in any order
    And the admin search lists "Track the zeppelin" under "Tasks"
    And the admin search lists "Zeppelin sighting" under "Messages"
    And the admin search shows ".page-head-sub" reading "3 results for “zeppelin”."
    And the admin search's "input[name='q']" holds "zeppelin"
    And the admin search kinds read "All kinds 3 (current), Tasks 1, Posts 1, Messages 1"
    And the admin search links "Messages 1" to "/admin/search?q=zeppelin&kind=message"

  Scenario: A label search lists the task with that number above the tasks whose words match
    Given the search database runs:
      """
      insert into projects (name, tagline, repo, url, visibility, key) values ('Podcast', 'Talk', 'me/podcast', 'https://podcast.test', 'public', 'POD');
      insert into tasks (title, list, position, project_id) values ('Record the intro', 'next', 1, 1), ('Edit the intro', 'next', 2, 1);
      insert into tasks (title, list, position) values ('Water the ferns', 'next', 3), ('Prune the roses', 'next', 4), ('Read chapter 2', 'next', 5);
      """
    When I visit "/admin/search?q=%232&kind=task"
    Then the admin search lists "Edit the intro, Prune the roses, Read chapter 2" in any order
    And the admin search lists "Read chapter 2" last
    When I visit "/admin/search?q=2"
    Then the admin search kinds include "Tasks 3"
    When I visit "/admin/search?q=2&kind=task"
    Then the admin search labels the tasks "POD-2, 2, 3" in any order

  Scenario Outline: A label search finds a task by <query> in any case
    Given the search database runs:
      """
      insert into projects (name, tagline, visibility, key) values ('Podcast', 'Talk', 'public', 'POD');
      insert into tasks (title, list, position, project_id) values ('Record the intro', 'next', 1, 1), ('Edit the intro', 'next', 2, 1);
      insert into tasks (title, list, position) values ('Prune the roses', 'next', 3);
      """
    When I visit "/admin/search?q=<query>&kind=task"
    Then the admin search lists "Edit the intro"

    Examples:
      | query    |
      | POD-2    |
      | pod-2    |
      | %23POD-2 |

  Scenario: A task that moved is found by its new label
    Given the search database runs:
      """
      insert into projects (name, tagline, visibility, key) values ('Podcast', 'Talk', 'public', 'POD');
      insert into tasks (title, list, position, project_id) values ('Record the intro', 'next', 1, 1), ('Edit the intro', 'next', 2, 1);
      insert into tasks (title, list, position) values ('Water the ferns', 'next', 3);
      update tasks set project_id = 1 where title = 'Water the ferns';
      """
    When I visit "/admin/search?q=POD-3&kind=task"
    Then the admin search lists "Water the ferns"
    And the admin search labels the tasks "POD-3" in any order

  Scenario: A phrase a decision holds lists the decision and links to its page
    Given the search database runs:
      """
      insert into decisions (title, problem) values ('Pick a blimp hangar', 'Where the airship sleeps');
      """
    When I visit "/admin/search?q=airship"
    Then the admin search lists "Pick a blimp hangar" under "Decisions"
    And the admin search links "Pick a blimp hangar" to "/admin/decisions/1"

  Scenario: A phrase a pull request holds lists the pull request and links to its page
    Given the search database runs:
      """
      insert into pull_requests (repo, number, title, body, url, opened_at)
      values ('aaronmallen/aaronmallen.me', 7, 'Fix the hangar door', 'The airship got stuck', 'https://github.com/aaronmallen/aaronmallen.me/pull/7', now());
      """
    When I visit "/admin/search?q=airship"
    Then the admin search lists "Fix the hangar door" under "Pull requests"
    And the admin search links "Fix the hangar door" to "/admin/pull-requests/1"

  Scenario: A phrase a note holds lists the note by its title under a Notes pill and links to it
    Given the search database runs:
      """
      insert into notes (title, body) values ('Glaze recipes', 'Celadon over porcelain, fired in the kiln');
      """
    When I visit "/admin/search?q=glaze"
    Then the admin search lists "Glaze recipes" under "Notes"
    And the admin search kinds include "Notes 1"
    And the admin search links "Glaze recipes" to "/admin/notes/1"
    When I visit "/admin/search?q=porcelain"
    Then the admin search lists "Glaze recipes"

  Scenario: A note is found by its title or its body
    Given the search database runs:
      """
      insert into notes (title, body) values ('Kiln schedule', 'Bisque at cone 04, then glaze');
      """
    When I visit "/admin/search?q=kiln"
    Then the admin search lists "Kiln schedule"
    And the admin search links "Kiln schedule" to "/admin/notes/1"
    When I visit "/admin/search?q=bisque"
    Then the admin search lists "Kiln schedule"
    And the admin search links "Kiln schedule" to "/admin/notes/1"

  Scenario: Filtering by kind lists only that kind, keeps it chosen and still counts every kind
    Given the search database runs:
      """
      insert into tasks (title, list, position) values ('Track the zeppelin', 'next', 1);
      insert into mail_accounts (provider, name) values ('contact_form', 'Contact form');
      insert into mail_threads (mail_account_id, subject) values (1, 'Zeppelin sighting');
      insert into mail_messages (mail_thread_id, subject, body) values (1, 'Zeppelin sighting', 'Hi there');
      """
    When I visit "/admin/search?q=zeppelin&kind=message"
    Then the admin search lists "Zeppelin sighting"
    And the admin search shows ".search-kind[aria-current='page']" reading "Messages 1"
    And the admin search's "input[type='hidden'][name='kind']" holds "message"
    And the admin search links "All kinds 2" to "/admin/search?q=zeppelin"

  Scenario: A kind it does not know lists every kind
    Given the search database runs:
      """
      insert into tasks (title, list, position) values ('Track the zeppelin', 'next', 1);
      """
    When I visit "/admin/search?q=zeppelin&kind=spaceship"
    Then the admin search lists "Track the zeppelin"

  Scenario: Paging splits the matches, keeps the kind and query, and answers 404 past the end
    Given the search database runs:
      """
      insert into tasks (title, list, position) select 'Call the plumber ' || n, 'next', n from generate_series(1, 101) n;
      insert into mail_accounts (provider, name) values ('contact_form', 'Contact form');
      insert into mail_threads (mail_account_id, subject) values (1, 'Plumber invoice');
      insert into mail_messages (mail_thread_id, subject, body) values (1, 'Plumber invoice', 'Pay up');
      """
    When I visit "/admin/search?q=plumber&kind=task"
    Then the admin search lists 100 results
    And the admin search shows "nav.pager a[rel='next'][href='/admin/search?q=plumber&kind=task&page=2']"
    When I visit "/admin/search?q=plumber&kind=task&page=2"
    Then the admin search lists 1 results
    And the admin search shows ".search-kind[aria-current='page']" reading "Tasks 101"
    And the admin search shows "nav.pager a[rel='prev'][href='/admin/search?q=plumber&kind=task']"
    And visiting "/admin/search?q=plumber&kind=task&page=3" answers 404

  Scenario: Each result leads to its record
    Given the search database runs:
      """
      insert into tasks (title, list, status, completed_at, position) values ('Renew the passport', 'next', 'done', now(), 1);
      insert into journal_entries (entry_date, entry_time, body, body_html) values ('2026-10-01', '09:00', 'Walked the levee at dawn', '<p>Walked the levee at dawn</p>');
      insert into mail_accounts (provider, name) values ('contact_form', 'Contact form');
      insert into mail_threads (mail_account_id, subject, status) values (1, 'Hello', 'read');
      insert into mail_messages (mail_thread_id, subject, body) values (1, 'Hello', 'Loved your piece on sourdough');
      insert into mail_threads (mail_account_id, subject, status, marked_spam_at) values (1, 'Spam hello', 'spam', now());
      insert into mail_messages (mail_thread_id, subject, body) values (2, 'Spam hello', 'Cheap sourdough pills');
      """
    When I visit "/admin/search?q=passport"
    Then the admin search links "Renew the passport" to "/admin/tasks/1"
    When I visit "/admin/search?q=levee"
    Then the admin search links "Walked the levee at dawn" to "/admin/journal?to=2026-10-01#day-2026-10-01"
    And the admin search shows ".li-side" reading "Oct 1, 2026"
    When I visit "/admin/search?q=sourdough"
    Then the admin search links "Hello" to "/admin/mail?folder=all&thread=1#read-1"
    And the admin search links "Spam hello" to "/admin/mail?folder=spam&thread=2#read-2"

  Scenario: A thread lists once when more than one of its messages match
    Given the search database runs:
      """
      insert into mail_accounts (provider, name) values ('contact_form', 'Contact form');
      insert into mail_threads (mail_account_id, subject) values (1, 'Hello');
      insert into mail_messages (mail_thread_id, subject, body) values
        (1, 'Hello', 'Loved your piece on sourdough'), (1, 'Re: Hello', 'More sourdough questions');
      """
    When I visit "/admin/search?q=sourdough"
    Then the admin search links 1 time to "Hello"

  Scenario: A result shows a short match
    Given the search database runs:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html)
      values ('{today}', '09:00', E'Walked the levee at dawn\nThe river ran high', '<p>Walked</p>');
      """
    When I visit "/admin/search?q=river"
    Then the admin search shows ".li-sub:has-text('river')"

  Scenario: The page asks for a phrase when there is none
    Given the search database runs:
      """
      insert into tasks (title, list, position) values ('Call the plumber', 'next', 1);
      """
    Then visiting "/admin/search" answers 200
    And the admin search shows ".empty" reading "Type a phrase to search every record."

  Scenario: The page marks no pill current, shows no screen tabs and says when nothing matches
    When I visit "/admin/search?q=zeppelin"
    Then the admin search shows no "a.pill-nav-link[aria-current]"
    And the admin search shows no ".screen-tabs"
    And the admin search shows ".empty" reading "Nothing matches “zeppelin”."

  Scenario: Signed out, the search lists nothing
    Given the search database runs:
      """
      insert into tasks (title, list, position) values ('Email the accountant', 'next', 1);
      """
    Then the admin search for "accountant" signed out does not hold "Email the accountant"

  Scenario: The page passes axe
    Given the search database runs:
      """
      insert into tasks (title, list, position) values ('Track the zeppelin', 'next', 1);
      """
    When I visit "/admin/search?q=zeppelin"
    Then the page has no axe breaches in light or dark
