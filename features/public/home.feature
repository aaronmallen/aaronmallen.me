Feature: Home page
  The home page lists the newest published posts.

  Scenario: A published post shows on the home page
    Given a post "Hello world" published an hour ago
    When I visit the home page
    Then the home page lists "Hello world"
    And the page has no axe breaches in light or dark

  Scenario: The home page reads on a phone
    Given a post "Hello world" published an hour ago
    And I use a phone
    When I visit the home page
    Then the page has no axe breaches in light or dark

  Scenario: A scheduled post shows once the due posts job runs
    Given a post "Due now" scheduled for an hour ago
    Then the home page lists nothing under writing
    When the due posts job runs
    Then the home page lists "Due now"

  Scenario: The writing section lists the ten newest published posts, newest first
    Given 12 published posts
    When I visit "/"
    Then the texts of ".entry .entry-title" are:
      | Post 1  |
      | Post 2  |
      | Post 3  |
      | Post 4  |
      | Post 5  |
      | Post 6  |
      | Post 7  |
      | Post 8  |
      | Post 9  |
      | Post 10 |

  Scenario: The writing section leaves out drafts and scheduled posts
    Given the posts:
      | title  | status    | published |
      | Shown  |           |           |
      | Draft  | draft     |           |
      | Later  | scheduled | in 1 day  |
    When I visit "/"
    Then the texts of ".entry .entry-title" are:
      | Shown |

  Scenario: Each writing row renders through the list the writing index uses
    Given the posts:
      | title | tags | summary          |
      | Hello | ruby | What it is about |
    When I visit "/"
    Then ".entries.h-feed .entry-title a.entry-link[href='/writing/hello']" reads "Hello"
    And ".entry-blurb" reads "What it is about"

  Scenario: The writing and projects sections head with h2 kickers, writing first, and link to their pages
    Given the posts:
      | title |
      | Hello |
    And the projects:
      | name |
      | Sai  |
    When I visit "/"
    Then the texts of ".g > section > .sh > h2" are:
      | Writing  |
      | Projects |
    And the page has ".g > section > .sh > h2.kicker:first-child"
    And ".sh .sec-l[href='/writing']" reads "All writing"
    And ".sh .sec-l[href='/projects']" reads "All projects"
    And "h1.sr-only" reads "Writing and projects"
    And the page has 1 of "h1"

  Scenario: The home page says so when nothing is written or built
    When I visit "/"
    Then the texts of ".empty" are:
      | Nothing written yet. |
      | Nothing built yet.   |
    And the page has no ".entries"
    And the page has no ".pgrid"

  Scenario: The projects section shows the three live public projects with the most stars, most first
    Given the projects:
      | name   | stars | visibility | archived   |
      | few    | 2     |            |            |
      | most   | 30    |            |            |
      | none   | 0     |            |            |
      | some   | 9     |            |            |
      | gone   | 100   |            | 2026-01-01 |
      | hidden | 50    | private    |            |
    When I visit "/"
    Then the texts of ".pgrid .pc .pn" are:
      | most |
      | some |
      | few  |

  Scenario: The projects section leaves out archived and private projects
    Given the projects:
      | name   | stars | visibility | archived   |
      | gone   | 100   |            | 2026-01-01 |
      | hidden | 50    | private    |            |
      | here   | 1     |            |            |
    When I visit "/"
    Then the texts of ".pgrid .pc .pn" are:
      | here |

  Scenario: Each project card renders the way the projects page does
    Given the projects:
      | name | tags | stars | release | tagline         |
      | sai  | ruby | 21    | v1.0    | Terminal colors |
    When I visit "/"
    Then ".pc .ps" reads "ruby · ★ 21 · v1.0"

  Scenario: The home page is titled for the site and links the writing feed in the head
    When I visit "/"
    Then the page title is "Writing and projects | Aaron Allen"
    And the page has 1 of "head link[rel='alternate'][type='application/atom+xml']"
    And the page has "head link[rel='alternate'][type='application/atom+xml'][href='/writing.atom'][title='Writing | Aaron Allen']"
