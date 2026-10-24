Feature: Search
  Search finds published posts, public projects and tasks on published boards, grouped by kind with counts. A
  blank or empty search offers tags and the latest posts. Each visitor gets a few searches a minute.

  Scenario Outline: The header of <path> links to search
    When I visit "<path>"
    Then "header a.search-link[href='/search'][aria-label='Search']" includes "search"

    Examples:
      | path      |
      | /         |
      | /writing  |
      | /about    |
      | /projects |
      | /contact  |

  Scenario: The search page marks its link current, has an h1, stays out of search engines and caches
    When I visit "/search?q=zeppelin"
    Then the page has "a.search-link[aria-current='page']"
    And "h1" includes "Search"
    And the page has "meta[name='robots'][content='noindex']"
    And the page has no axe breaches in light or dark
    When I request "/search?q=zeppelin"
    Then the "Cache-Control" header includes "s-maxage=300"

  Scenario: Matches in every kind show the total, the count of each kind and three rows of each
    Given the zeppelin results
    When I visit "/search?q=zeppelin"
    Then ".sq-c" includes "6 results for “zeppelin”: 4 posts, 1 project, 1 task"
    And the hrefs and texts of ".sq-k a" are:
      | /search?q=zeppelin              | all 6      |
      | /search?q=zeppelin&kind=post    | posts 4    |
      | /search?q=zeppelin&kind=project | projects 1 |
      | /search?q=zeppelin&kind=task    | tasks 1    |
    And the texts of ".sq-g h2" are:
      | Posts · 4    |
      | Projects · 1 |
      | Tasks · 1    |
    And ".sq-g:first-of-type li.entry" counts 3
    And "main" has a link "All 4 posts matching “zeppelin”" to "/search?q=zeppelin&kind=post"
    And the page has no "a[href='/search?q=zeppelin&kind=project']:has-text('All')"

  Scenario: One kind shows when asked, with counts that match, and pages past its end answer 404
    Given the zeppelin results
    When I visit "/search?q=zeppelin&kind=post"
    Then the texts of ".sq-g h2" are:
      | Posts · 4 |
    And "li.entry" counts 4
    And ".sq-k a[aria-current='page']" reads "posts 4"
    And the page has no ".sq-more"
    When I request "/search?q=zeppelin&kind=post&page=9"
    Then it answers 404

  Scenario: Each hit shows its label with a date, status or number and links to its page
    Given the zeppelin results
    When I visit "/search?q=zeppelin"
    Then ".entry-meta" matches the pattern "^post\w{3} \d+, \d{4}$"
    And the texts of ".sq-g[aria-labelledby='g-project'] .entry-meta" are:
      | projectactive |
    And ".sq-g[aria-labelledby='g-task'] .entry-meta" matches the pattern "^task#\d+$"
    And "main" has a link "Zeppelin 3" to "/writing/zeppelin-3"
    And "main" has a link "Zeppelin" to "/projects"
    And the page has "a[href^='/projects/board/tasks/']:has-text('Fly the zeppelin')"
    And ".sq-t" reads "openBoard board"

  Scenario: A project with a published board links to its board
    Given the projects:
      | name     | tagline         | board     |
      | Zeppelin | A zeppelin tool | published |
    When I visit "/search?q=zeppelin"
    Then "main" has a link "Zeppelin" to "/projects/zeppelin"

  Scenario: Search never finds a note
    Given the posts:
      | title    |
      | Airships |
    And the database runs:
      """
      INSERT INTO notes (title, body) VALUES ('Zeppelin and airships', 'Private airships thoughts')
      """
    When I visit "/search?q=airships"
    Then the page does not show "Zeppelin and airships"

  Scenario: Search marks the matches and escapes the record's own HTML
    Given the posts:
      | title    | body                                              |
      | Airships | A zeppelin & a blimp, 1 < 2 > 0, <mark>no</mark>  |
    When I visit "/search?q=zeppelin"
    Then the texts of ".entry-blurb mark" are:
      | zeppelin |
    When I request "/search?q=zeppelin"
    Then the body includes "<mark>zeppelin</mark> &amp; a blimp, 1 &lt; 2 &gt; 0"

  Scenario: A kind search does not know is ignored
    Given the posts:
      | title    |
      | Zeppelin |
    When I visit "/search?q=zeppelin&kind=journal_entry"
    Then the texts of ".sq-g h2" are:
      | Posts · 1 |

  Scenario: A blank search shows the tag chips with counts and the latest posts
    Given the ways forward
    When I visit "/search"
    Then the hrefs and texts of ".tgc a" are:
      | /writing/tags/ruby | ruby 2 |
      | /writing/tags/rust | rust 1 |
    And ".tgc a.violet" includes "ruby"
    And the texts of ".rcl a" are:
      | Fourth |
      | Third  |
      | Second |
    And the page has no "#results"

  Scenario: An empty search shows the ways forward with the query in the box, and a match leaves them off
    Given the ways forward
    When I visit "/search?q=kafka%20streams"
    Then ".sq-n h2" includes "Nothing matched “kafka streams”"
    And "input[name='q']" has the value "kafka streams"
    And the texts of ".rcl a" are:
      | Fourth |
      | Third  |
      | Second |
    And ".tgc a" counts 2
    When I visit "/search?q=fourth"
    Then the page has no ".sq-w"

  @timeout:180_000
  Scenario: A failing search shows the error state and offers to try again
    Given the environment sets WEB_STATEMENT_TIMEOUT to "1"
    And the site runs in production
    And another session holds a lock on the posts table
    When I request "/search?q=zeppelin"
    Then it answers 503
    And the body matches "class=\"sq-n err\"[\s\S]*Search isn’t working right now"
    And the body does not include "sq-w"
    And the body includes "href=\"/search?q=zeppelin\""
    And the body includes "Try again"

  Scenario: Each search records an attempt, and the blank page records none
    Given the posts:
      | title    |
      | Zeppelin |
    When I request "/search"
    And I request "/search?q=zeppelin"
    And I request "/search?q=zeppelin"
    Then the database answers "2" for:
      """
      SELECT count(*) FROM search_attempts
      """

  @timeout:180_000
  Scenario: A search that cannot be counted still searches
    Given the environment sets WEB_STATEMENT_TIMEOUT to "1"
    And the site runs in production
    And the posts:
      | title    |
      | Zeppelin |
    And another session holds a lock on the search_attempts table
    When I request "/search?q=zeppelin"
    Then it answers 200
    And the body includes "Posts<span> · 1</span>"

  @timeout:180_000
  Scenario: Past the limit a searcher sees the limited state, while another visitor still searches
    Given the environment sets SEARCH_THROTTLE_LIMIT to "2"
    And the site runs in production
    And the posts:
      | title    |
      | Zeppelin |
    And my requests send the header "CF-Connecting-IP" as "203.0.113.9"
    When I request "/search?q=zeppelin&kind=post"
    And I request "/search?q=zeppelin&kind=post"
    Then it answers 200
    And the body includes "Posts<span> · 1</span>"
    When I request "/search?q=zeppelin&kind=post"
    Then it answers 429
    And the body includes "class=\"sq-n wait\""
    And the body includes "Too many searches at once"
    And the body includes "value=\"zeppelin\""
    And the body does not match "class=\"sq-g|class=\"sq-w"
    And the body includes "href=\"/writing\""
    And the body includes "href=\"/projects\""
    And the "Cache-Control" header does not include "s-maxage"
    And the database answers "2" for:
      """
      SELECT count(*) FROM search_attempts
      """
    Given my requests send the header "CF-Connecting-IP" as "203.0.113.10"
    When I request "/search?q=zeppelin&kind=post"
    Then it answers 200

  Scenario: The / key focuses the search box, and a second / types into it
    When I visit "/search"
    And I press "/"
    Then the focus is on "#q"
    When I press "/"
    Then "#q" has the value "/"

  Scenario: Below 700px the header search link is a 44px icon button
    Given my window is 390 by 844
    When I visit "/"
    Then ".search-link" is 44 by 44 pixels
    And ".search-link span" is hidden

  Scenario: A visitor finds published posts, public projects live or archived, and tasks on published boards, by kind
    Given the projects:
      | name         | tagline    | archived   | board     |
      | Board        | Plans      |            | published |
      | Zeppelin     | A live one |            |           |
      | Old zeppelin | An old one | 2026-01-01 |           |
    And the posts:
      | title         | body   | slug          |
      | Zeppelin post | A post | zeppelin-post |
    And the database runs:
      """
      INSERT INTO tasks (title, list, position, project_id) SELECT 'Zeppelin task', 'next', 1, id FROM projects WHERE name = 'Board'
      """
    When I visit "/search?q=zeppelin"
    Then ".sq-c" includes "4 results for “zeppelin”: 1 post, 2 projects, 1 task"
    And "main" has a link "Zeppelin post" to "/writing/zeppelin-post"
    And the texts of ".sq-g[aria-labelledby='g-project'] .entry-meta" are:
      | projectarchived |
      | projectactive   |
    And ".sq-t" reads "openBoard board"
    When I visit "/search?q=zeppelin&kind=project"
    Then the texts of ".sq-g h2" are:
      | Projects · 2 |

  Scenario: A visitor never finds private records or the kinds the site never shows
    Given the posts:
      | title              | status    | published |
      | Draft zeppelin     | draft     |           |
      | Scheduled zeppelin | scheduled | in 1 day  |
    And the projects:
      | name  | tagline                | visibility | board     | archived   |
      | Hush  | A zeppelin secret      | private    | published |            |
      | Gone  | An old zeppelin secret | private    |           | 2026-01-01 |
      | Plain |                        |            |           |            |
    And the database runs:
      """
      INSERT INTO tasks (title, list, position, project_id) SELECT 'Unpublished zeppelin', 'next', 1, id FROM projects WHERE name = 'Plain';
      INSERT INTO tasks (title, list, position, project_id) SELECT 'Hidden zeppelin', 'next', 1, id FROM projects WHERE name = 'Hush';
      INSERT INTO tasks (title, list, position) VALUES ('Loose zeppelin', 'next', 1);
      INSERT INTO journal_entries (entry_date, entry_time, body, body_html) VALUES (current_date, '12:00', 'A zeppelin day', 'A zeppelin day');
      INSERT INTO work_entries (org, role, from_year, position) VALUES ('Zeppelin Inc', 'Dev', 2020, 1);
      INSERT INTO notes (title, body) VALUES ('Zeppelin note', 'A zeppelin note');
      """
    When I visit "/search?q=zeppelin"
    Then ".sq-n h2" includes "Nothing matched “zeppelin”"

  Scenario: A public tag matches posts and projects, never a task's tag, and a record matched twice lists once
    Given the projects:
      | name           | tagline   | tags     | board     |
      | Tagged project | A project | airships | published |
    And the posts:
      | title          | body     | tags     | slug           |
      | Tagged post    | A post   | airships | tagged-post    |
      | Airships aloft | Up we go | airships | airships-aloft |
    And the tasks of the project "Tagged project":
      | title       | tags     |
      | Tagged task | airships |
    When I visit "/search?q=airships"
    Then ".sq-c" includes "3 results for “airships”: 2 posts, 1 project"
    And the page does not show "Tagged task"
    And ".entry:has(a[href='/writing/airships-aloft']) .entry-blurb mark" reads "Airships"

  Scenario: A quoted phrase matches only that phrase, and a blank phrase finds nothing
    Given the posts:
      | title        | body      | slug         |
      | Red zeppelin | It flies  | red-zeppelin |
      | Zeppelin     | It is red | zeppelin     |
    When I visit "/search?q=%22red%20zeppelin%22"
    Then the texts of ".sq-g h2" are:
      | Posts · 1 |
    And "main" has a link "Red zeppelin" to "/writing/red-zeppelin"
    When I visit "/search?q=%20"
    Then the page has no "#results"
