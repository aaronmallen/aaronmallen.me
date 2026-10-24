Feature: The time report
  The time screen sums the tracked time in a range by tag, project or day, and counts time that overlaps once.

  Background:
    Given I am signed in to the admin

  Scenario: With no range the report covers the last seven days by tag
    When I open the time report
    Then the time range reads from "today - 6" to "today"
    And the page part "a.pill-nav-link[aria-current='page']" reads "Insights"
    And the page parts "a.screen-tab" read "analytics | activity | health | time report"
    And the page part ".screen-tab[aria-current='page']" reads "time report"
    And the page has "#command-palette-time i.fa-clock"
    And the page box "input[value='tag']" is ticked
    And the page parts "[role='radiogroup']:has(input[value='tag']) .seg-option" read "Tag | Project | Day"
    And the page part ".seg-option.current[aria-current='page']" reads "7d"
    And the page part "#time-from" has "max" set to "{day:today}"
    And the page part "#time-to" has "min" set to "{day:today - 6}"
    And the page part "#time-groups .empty" holds "No time logged"
    And the page part ".page-head-sub" holds "or moving it to another day, closes the session."
    And the page has no axe breaches in light or dark

  Scenario Outline: A start opens one work session and <action> closes it
    Given the tasks:
      | title      |
      | Write docs |
    When I send the admin form "/admin/tasks/{task:Write docs}/start"
    Then the database soon holds "true" for:
      """
      SELECT ended_at IS NULL FROM work_sessions
      """
    When I send the admin form "/admin/tasks/{task:Write docs}/<action>" with:
      | sprint_on | {day:today + 1} |
    Then the database soon holds "false" for:
      """
      SELECT ended_at IS NULL FROM work_sessions
      """

    Examples:
      | action   |
      | stop     |
      | complete |
      | cancel   |
      | schedule |

  Scenario: Grouped by project, each task counts in one project and no project comes last
    Given the worked tasks:
      | title           | sessions                | projects |
      | Ship the gem    | 2026-03-02 09:00-10:00  | gem      |
      | Polish the site | 2026-03-03 09:00-09:30  | site     |
      | Answer email    | 2026-03-04 09:00-09:15  |          |
      | Out of range    | 2026-03-20 09:00-10:00  | site     |
    When I open the time report from "2026-03-02" to "2026-03-08" by "project"
    Then the time rows read "gem 1h 00m | site 30m | No project 15m"
    And I see "Mar 2, 2026 → Mar 8, 2026 · 1h 45m"
    And the time report flags no row as shared
    And the time hints read ""
    And the time group "gem" lists "Ship the gem 1h 00m"
    And the time group "site" lists "Polish the site 30m"
    And the time group "No project" lists "Answer email 15m"
    And the page has 3 of "details.time-group > summary.time-row"
    And the page part "a.seg-option:has-text('30d')" has "href" set to "/admin/time?from={day:today - 29}&to={day:today}&by=project"
    And the page has no ".seg-option.current"
    And the page has no axe breaches in light or dark

  Scenario: Grouped by tag, a task counts under each of its tags
    Given the worked tasks:
      | title        | sessions               | tags      |
      | Tagged twice | 2026-03-02 09:00-10:00 | ruby site |
      | Tagged once  | 2026-03-03 09:00-09:30 | ruby      |
      | Untagged     | 2026-03-04 09:00-09:15 |           |
    When I open the time report from "2026-03-02" to "2026-03-08" by "tag"
    Then the time rows read "ruby 1h 30m | site 1h 00m | No tag 15m"
    And the page box "input[value='tag']" is ticked
    And the time hints read "Overlapping time counts once in each row and once in the total, and a task with two tags counts under both, so tasks can add up to more than their row and rows more than the total."
    And the time report flags no row as shared
    And the time group "ruby" flags the tasks "Tagged twice" as shared
    When I visit "/admin/time?from=2026-03-02&to=2026-03-08"
    Then the time rows read "ruby 1h 30m | site 1h 00m | No tag 15m"

  Scenario: Grouped by day, each day sums in order and never shares
    Given the worked tasks:
      | title                | sessions               | projects  |
      | Ship the shared work | 2026-03-02 09:00-10:00 | site, gem |
      | Answer email         | 2026-03-04 09:00-09:15 |           |
    When I open the time report from "2026-03-02" to "2026-03-08" by "day"
    Then the time rows read "Monday, March 2 1h 00m | Wednesday, March 4 15m"
    And the page has no ".tone-text"

  Scenario: A task whose total fell below its sessions shows only the day's sessions
    Given the worked tasks:
      | title     | sessions                                       | total | closed           |
      | Cut short | 2026-03-02 09:00-11:00; 2026-03-03 09:00-10:00 | 1800  | 2026-03-03 12:00 |
    When I open the time report from "2026-03-03" to "2026-03-03" by "tag"
    Then the time rows read "No tag 1h 00m"
    And I see "Mar 3, 2026 → Mar 3, 2026 · 1h 00m"

  Scenario: Tasks in one project that ran at the same time count the hour once
    Given the worked tasks:
      | title          | sessions               | projects |
      | Side by side 0 | 2026-03-02 09:00-10:00 | site     |
      | Side by side 1 | 2026-03-02 09:00-10:00 | site     |
    When I open the time report from "2026-03-02" to "2026-03-08" by "project"
    Then the time rows read "site 1h 00m"
    And I see "Mar 2, 2026 → Mar 8, 2026 · 1h 00m"
    And the time hints read "Overlapping time counts once in each row and once in the total, so tasks can add up to more than their row and rows more than the total."

  Scenario: Tasks in two projects that ran at the same time count in each project and once in the total
    Given the worked tasks:
      | title           | sessions               | projects |
      | Ship the gem    | 2026-03-02 09:00-10:00 | gem      |
      | Polish the site | 2026-03-02 09:00-10:00 | site     |
    When I open the time report from "2026-03-02" to "2026-03-08" by "project"
    Then the time rows read "gem 1h 00m | site 1h 00m"
    And I see "Mar 2, 2026 → Mar 8, 2026 · 1h 00m"
    And the time hints read "Overlapping time counts once in each row and once in the total, so tasks can add up to more than their row and rows more than the total."

  Scenario: The report mends a range it cannot read
    When I visit "/admin/time?from=2026-03-08&to=2026-03-02"
    Then the time range reads from "2026-03-02" to "2026-03-02"
    When I visit "/admin/time?from=nope&to=2026-13-40&by=year"
    Then the time range reads from "today - 6" to "today"
    And the page box "input[value='tag']" is ticked
