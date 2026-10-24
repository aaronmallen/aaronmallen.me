Feature: The projects list
  The projects screen lists the live and the archived projects as cards, and archives and restores them.

  Background:
    Given I am signed in to the admin

  Scenario: The live list shows each project as a card, in the order added
    Given the projects:
      | name     | visibility | archived  | stars | tagline                | repo             | release | tags |
      | live-one | public     |           | 21    | A node package manager | aaronmallen/aube | v1.0.0  | rust |
      | live-two | private    |           | 1204  |                        |                  |         |      |
      | gone     | public     | today - 1 | 3     |                        |                  |         |      |
      | newest   | public     |           | 0     |                        |                  |         |      |
    When I visit "/admin/projects"
    Then the page parts ".project-card-name" read "live-one | live-two | newest"
    And the page part ".page-head-sub" reads "3 live · 1 archived · 1,228 stars total"
    And the page box ".seg input[name='filter'][value='live']" is ticked
    And the page has "a[href='/admin/projects/new']"
    And the page part ".screen-tab[aria-current='page']" holds "projects"
    And the page parts ".page-head + .screen-tabs a.screen-tab" have "href" set to "/admin/tasks | /admin/calendar | /admin/projects"
    And the page has 1 of "a.pill-nav-link[aria-current='page']"
    And the page part "a.pill-nav-link[aria-current='page']" holds "Tasks"
    And the page has 3 of ".cols > .card.project-card"
    And the page part "p.hint" reads "Archiving keeps the repo link and history, and moves the project to Past Projects on /projects."
    And the page has no axe breaches in light or dark

  Scenario: A card shows what the project has, and only that
    Given the projects:
      | name | visibility | stars | tagline                | repo             | release | tags |
      | aube | public     | 21    | A node package manager | aaronmallen/aube | v1.0.0  | rust |
      | bare | private    | 0     |                        |                  |         |      |
    When I visit "/admin/projects"
    Then the page part ".project-card:has-text('aube') .project-card-name" reads "aube"
    And the page part ".project-card:has-text('aube') .project-card-tagline" reads "A node package manager"
    And the page parts ".project-card:has-text('aube') .project-card-meta > span" read "aaronmallen/aube | 21 | v1.0.0"
    And the page part ".project-card:has-text('aube') .project-card-meta a.tag[href='/admin/tags/rust']" reads "#rust"
    And the page has ".project-card-meta span[role='img'][aria-label='21 stars']"
    And the page has ".project-card:has-text('aube') .project-card-meta i.fa-brands.fa-github"
    And the page parts ".project-card:has-text('bare') .project-card-meta > span" read "0"
    And the page has no ".project-card:has-text('aube') .project-card-head .pill.sand"
    And the page part ".project-card:has-text('bare') .pill.sand > i.fa-lock[aria-hidden='true'] + span" reads "private"
    And the page has 2 of ".project-card-head .pill.green:has-text('active')"
    And the page has no "form[action*='/move/']"
    And the page has 2 of "button[aria-label='Archive']"
    And the page has no "button[aria-label='Restore']"
    And the page has no "button[aria-label='Delete'], button:has-text('Delete')"
    And the page has ".project-card:has-text('aube') a[href='/admin/projects/{project:aube}/edit']"

  Scenario: The archived list sorts by the day each project was archived, newest first
    Given the projects:
      | name  | archived    |
      | live  |             |
      | older | today - 200 |
      | gone  | today       |
      | newer | today - 10  |
    When I visit "/admin/projects?filter=archived"
    Then the page parts ".project-card-name" read "gone | newer | older"
    And the page box ".seg input[name='filter'][value='archived']" is ticked
    And the page part ".page-head-sub" reads "1 live · 3 archived · 0 stars total"
    And the page part ".project-card:has-text('newer') .project-card-meta" holds "archived {medium:today - 10}"
    And the page has 3 of "button[aria-label='Restore']"
    And the page has no "button[aria-label='Archive']"
    And the page has no ".project-card-head .pill.green"
    And the page has 3 of ".project-card-head .pill:has-text('archived')"
    And the page has no "p.hint:has-text('Archiving keeps')"
    And the page has no axe breaches in light or dark
    When I visit "/admin/projects?filter=junk"
    Then the page parts ".project-card-name" read "live"

  Scenario: The empty lists say so
    When I visit "/admin/projects"
    Then the page part ".empty" reads "No live projects."
    When I visit "/admin/projects?filter=archived"
    Then the page part ".empty" reads "Nothing archived yet."

  Scenario: Archiving keeps the repo, stars and visibility and moves the project to Past Projects
    Given the projects:
      | name | visibility | repo             | stars | url                                  |
      | kept | private    | aaronmallen/kept | 12    | https://github.com/aaronmallen/kept |
      | open | public     |                  | 0     | https://github.com/aaronmallen/open |
    When I visit "/admin/projects"
    And I click "Archive" in ".project-card:has-text('kept')"
    Then the toast says "Archived · removed from /projects"
    And the database soon holds "{day:today}, aaronmallen/kept, 12, private" for:
      """
      SELECT archived_on::text, repo, stars, visibility FROM projects WHERE name = 'kept'
      """
    When I send the admin form "/admin/projects/{project:open}/archive" with:
      | filter | archived |
    Then the admin answer goes to "/admin/projects?filter=archived"
    When I visit "/projects"
    Then the page parts ".kicker.kt + .pgrid .pc .pn" read "open"
    And the page parts ".kicker.kt + .pgrid .pc" have "href" set to "https://github.com/aaronmallen/open"

  Scenario: Archiving refuses a project that has not started or is archived already
    Given the projects:
      | name      | started   | archived   |
      | unstarted | today + 40 |           |
      | archived  |           | today - 30 |
    When I send the admin form "/admin/projects/{project:unstarted}/archive"
    Then the admin answer goes to "/admin/projects/{project:unstarted}/edit"
    When I follow the admin answer
    Then the toast says "Not archived · its start month has not come yet"
    When I send the admin form "/admin/projects/{project:archived}/archive"
    Then the admin answer goes to "/admin/projects/{project:archived}/edit"
    When I follow the admin answer
    Then the toast says "Not archived · it is archived already"
    And the database soon holds "archived {day:today - 30} | unstarted " for:
      """
      SELECT string_agg(name || ' ' || coalesce(archived_on::text, ''), ' | ' ORDER BY name) FROM projects
      """

  Scenario: Restoring brings an archived project back, and only an archived one
    Given the projects:
      | name | archived  |
      | gone | today - 3 |
      | live |           |
    When I visit "/admin/projects?filter=archived"
    And I click "Restore" in ".project-card:has-text('gone')"
    Then the toast says "Restored to /projects"
    And the database soon holds "0" for:
      """
      SELECT count(*) FROM projects WHERE archived_on IS NOT NULL
      """
    When I send the admin form "/admin/projects/{project:live}/restore"
    Then the server answers 404
