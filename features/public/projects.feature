Feature: Projects
  The projects page lists the public projects as cards by stars, the archived ones after them under their own
  kicker as unfilled cards. A card links to the project's site, or to its board once the board is published.

  Scenario: The projects page with nothing in it renders its head and no cards
    When I visit "/projects"
    Then "h1" reads "Libraries I maintain in the open."
    And the page has ".projects > header.hd > .kicker + h1 + p.ld"
    And the page title is "Projects | Aaron Allen"
    And the page has no ".pgrid"
    And the page has no ".kicker.kt"
    And the page has no axe breaches in light or dark

  Scenario: The cards sort by stars, most first, ties in the order they were added, private ones left out
    Given the projects:
      | name   | stars | visibility |
      | few    | 2     |            |
      | first  | 9     |            |
      | most   | 30    |            |
      | second | 9     |            |
      | hidden | 50    | private    |
    When I visit "/projects"
    Then the texts of ".pgrid .pc .pn" are:
      | most   |
      | first  |
      | second |
      | few    |

  Scenario: A card shows the name, meta line, tagline and its url without the scheme, filled while active
    Given the projects:
      | name | tags | stars | release | tagline         | url                                |
      | sai  | ruby | 21    | v1.0    | Terminal colors | https://github.com/aaronmallen/sai |
    When I visit "/projects"
    Then ".pc .pn" reads "sai"
    And ".pc .ps" reads "ruby · ★ 21 · v1.0"
    And ".pc p" reads "Terminal colors"
    And the page has "a.pc[href='https://github.com/aaronmallen/sai']"
    And ".pc .pu" reads "github.com/aaronmallen/sai"
    And the page has ".pc .pu i.fa-arrow-up-right-from-square[aria-hidden='true']"
    And the page has no ".pc.past"
    And the page has no ".pc .pu:has-text('view the board')"

  Scenario: A card links to the project's own site rather than the repository it tracks
    Given the projects:
      | name | repo             | url                         |
      | gest | aaronmallen/gest | https://gest.aaronmallen.dev |
    When I visit "/projects"
    Then the page has "a.pc[href='https://gest.aaronmallen.dev']"

  Scenario: A card with no url has no foot
    Given the projects:
      | name |
      | sai  |
    When I visit "/projects"
    Then the page has no ".pc .pu"

  Scenario: A published board, active or archived, links its card to its page
    Given the projects:
      | name     | url                           | board     | archived   |
      | Doing It | https://doing.aaronmallen.dev | published |            |
      | old      |                               | published | 2026-01-01 |
    When I visit "/projects"
    Then the page has "a.pc[href='/projects/doing-it']"
    And "a.pc[href='/projects/doing-it'] .pu" reads "view the board"
    And the page has "a.pc[href='/projects/doing-it'] .pu i.fa-table-columns[aria-hidden='true']"
    And the page has "a.pc.past[href='/projects/old']"

  Scenario: Archived projects sit after the active ones under their own kicker, unfilled, by stars
    Given the projects:
      | name   | stars | archived   | visibility |
      | here   | 1     |            |            |
      | few    | 2     | 2026-01-01 |            |
      | most   | 30    | 2026-01-01 |            |
      | some   | 9     | 2026-01-01 |            |
      | hidden | 50    | 2026-01-01 | private    |
    When I visit "/projects"
    Then the page has 1 of ".projects > .pgrid + h2.kicker.kt + .pgrid"
    And "h2.kicker.kt" reads "Past Projects"
    And the texts of ".pgrid:first-of-type .pc .pn" are:
      | here |
    And the texts of ".kicker.kt + .pgrid .pc.past .pn" are:
      | most |
      | some |
      | few  |

  Scenario: No past section renders when no public project is archived, and the work history stays on the about page
    Given the projects:
      | name   | archived   | visibility |
      | here   |            |            |
      | hidden | 2026-01-01 | private    |
    And the career history:
      | role |
      | Dev  |
    When I visit "/projects"
    Then the page has no ".kicker.kt"
    And the page has 1 of ".pgrid"
    And the page has no ".rows"

  Scenario Outline: The grid lays out in <count> columns at <width>px
    Given the projects:
      | name | tagline         | url                                |
      | sai  | Terminal colors | https://github.com/aaronmallen/sai |
      | gest | Agent artifacts |                                    |
    And my window is <width> by <height>
    When I visit "/projects"
    Then ".pgrid" lays out in <count> columns

    Examples:
      | width | height | count |
      | 390   | 844    | 1     |
      | 800   | 1000   | 2     |
      | 1600  | 900    | 4     |

  Scenario: An active card is filled and a past one unfilled
    Given the projects:
      | name     | archived   |
      | sai      |            |
      | domainic | 2026-01-01 |
    When I visit "/projects"
    Then the "background-color" of ".pc:not(.past)" is not "rgba(0, 0, 0, 0)"
    And the "background-color" of ".pc.past" is "rgba(0, 0, 0, 0)"
