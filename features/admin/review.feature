Feature: Admin review
  The review screen sums up a week or a month in cards: the tasks done and carried, the decisions closed, the
  journal, what went out, the commits and the time worked. A heat map narrows the cards to one day, and a card shows
  the same dates in earlier years.

  Background:
    Given I am signed in to the admin

  Scenario: The current week runs from Monday to Sunday and offers no way past it
    When I visit "/admin/review"
    Then the review shows ".screen-tab[aria-current='page']" reading "review"
    And the review shows "#command-palette-review i.fa-magnifying-glass-chart"
    And the review names this week from Monday to Sunday
    And the review lists the id of ".g-main > .cols > .card" as "review-done | review-carried | review-decisions | review-journal | review-published | review-commits | review-worked"
    And the review shows ".g-main > #review-notes.review-notes"
    And the review shows "#review-worked .empty" reading "No time logged"
    And the review shows ".seg-option.current[aria-current='page']" reading "Week"
    And the review has no link "This week"
    And the review shows ".seg-option[aria-disabled]" reading "Next week"
    And the review shows "a.seg-option[rel='prev'] i.fa-chevron-left"
    And the review has the link "Previous week"

  Scenario: A week with records fills each card
    Given the review has a day's work on "2026-09-16" done as "Finish the review screen"
    And the review decision "Pick a queue for Finish the review screen" was resolved on "2026-09-16" choosing "Sidekiq"
    And the review decision "Move to a VPS" was dropped on "2026-09-18"
    And the review has a published post "A post that went out" dated "2026-09-16"
    And the review has a posted social post dated "2026-09-18"
    And the review has a journal entry on "2026-09-14" reading "one two three"
    And the review has a journal entry on "2026-09-15" reading "four five"
    And the review has the commits:
      | repo            | date       | additions | deletions |
      | aaronmallen/one | 2026-09-16 | 10        | 2         |
    When I visit "/admin/review?day=2026-09-17"
    Then the review's ".page-head-sub" starts with "Sep 14 → Sep 20, 2026: 1 done, 1 commit, 1h 30m worked"
    And the review lists ".g-main > .cols .card-title" as "Done · 1 | Carried over · 1 | Decisions · 2 | Journal | Published · 2 | Commits · 1 | Time worked"
    And the review links "Call the accountant" to "/admin/tasks/2"
    And the review's "#review-carried .li:has-text('Call the accountant') .review-slipped" reads "Slipped 3 days"
    And the review lists "#review-published .review-group-name" as "Posts | Bluesky | Mastodon"
    And the review's "#review-published a.review-line[href='/admin/posts/1/edit']" reads "Sep 16 A post that went out"
    And the review lists the href of "#review-published a.review-group-head" as "/admin/posts | /admin/social?filter=posted | /admin/social?filter=posted"
    And the review lists the data-menu of "#review-published .review-line" as "/admin/posts/1/menu | /admin/social/1/menu | /admin/social/1/menu"
    And the review's "#review-journal .review-stat" reads "2 entries · 5 words · 2 days written"
    And the review links "Open journal →" to "/admin/journal"
    And the review shows "#review-commits .review-bar[title='aaronmallen/one']" reading "1 commit · +10 −2"
    And the review links "Pick a queue for Finish the review screen" to "/admin/decisions/1"
    And the review's "#review-decisions .li:has-text('Pick a queue') .li-main .li-sub" reads "Chose Sidekiq"
    And the review shows no "#review-decisions .li:has-text('Pick a queue') .li-side"
    And the review links "Move to a VPS" to "/admin/decisions/2"
    And the review's "#review-decisions .li:has-text('Move to a VPS') .li-main .li-sub" reads "Dropped"
    And the review shows no "#review-decisions .li:has-text('Move to a VPS') .li-side"
    And the review's "#review-worked .review-stat" reads "1h 30m 1h 30m avg · 1 day worked"
    And the review lists "#review-worked .review-bar-name" as "Wed Sep 16"

  Scenario: The done tasks group by tag or by project and link to Tasks › Completed
    Given the review has the tasks:
      | title         | closed     | tags      | project        |
      | Fix the feed  | 2026-09-16 | site, bug | aaronmallen.me |
      | Fix the nav   | 2026-09-16 | site      | aaronmallen.me |
      | Fix the stove | 2026-09-17 |           |                |
    When I visit "/admin/review?day=2026-09-16"
    Then the review lists "#review-done .review-group-name" as "#site | #bug | untagged"
    And the review shows "#review-done .review-foot .hint" reading "A task with two tags counts under both"
    And the review links "All 3 in Tasks →" to "/admin/tasks?filter=completed&from=2026-09-14&to=2026-09-20"
    And the review's "#review-done a.review-group-head:has-text('#site')" has the href "/admin/tasks?filter=completed&from=2026-09-14&to=2026-09-20&q=tag:site"
    And the review lists "#review-done .review-group:has-text('#site') .review-line" as "Fix the feed | Fix the nav"
    And the review links "by project" to "/admin/review?day=2026-09-16&group=project"
    And the review shows "#review-done .seg-option.current" reading "by tag"
    When I visit "/admin/review?day=2026-09-16&group=project"
    Then the review lists "#review-done .review-group-name" as "aaronmallen.me | no project"
    And the review's "#review-done a.review-group-head:has-text('aaronmallen.me')" has the href "/admin/tasks?filter=completed&from=2026-09-14&to=2026-09-20&q=project:aaronmallen-me"
    And the review shows no "#review-done .hint" reading "two tags"
    And the review links "Previous week" to "/admin/review?day=2026-09-09&group=project"

  Scenario: Long cards show five rows and fold the rest
    Given the review has the tasks:
      | title  | closed     | tags  |
      | Task 0 | 2026-09-16 | tag-0 |
      | Task 1 | 2026-09-16 | tag-1 |
      | Task 2 | 2026-09-16 | tag-2 |
      | Task 3 | 2026-09-16 | tag-3 |
      | Task 4 | 2026-09-16 | tag-4 |
      | Task 5 | 2026-09-16 | tag-5 |
      | Task 6 | 2026-09-16 | tag-6 |
    And the review has the commits:
      | repo               | date       |
      | aaronmallen/repo-0 | 2026-09-16 |
      | aaronmallen/repo-1 | 2026-09-16 |
      | aaronmallen/repo-2 | 2026-09-16 |
      | aaronmallen/repo-3 | 2026-09-16 |
      | aaronmallen/repo-4 | 2026-09-16 |
      | aaronmallen/repo-5 | 2026-09-16 |
      | aaronmallen/repo-6 | 2026-09-16 |
    And the review task "Carried 0" was carried out of the sprints "2026-09-16"
    And the review task "Carried 1" was carried out of the sprints "2026-09-16"
    And the review task "Carried 2" was carried out of the sprints "2026-09-16"
    And the review task "Carried 3" was carried out of the sprints "2026-09-16"
    And the review task "Carried 4" was carried out of the sprints "2026-09-16"
    And the review task "Carried 5" was carried out of the sprints "2026-09-16"
    And the review task "Carried 6" was carried out of the sprints "2026-09-16"
    When I visit "/admin/review?day=2026-09-16"
    Then the review's "#review-done .review-more summary .review-more-show" reads "Show 2 more"
    And the review's "#review-done .review-more summary .review-more-hide" reads "Show fewer"
    And the review counts 7 of "#review-done .review-group"
    And the review counts 2 of "#review-done .review-more .review-group"
    And the review counts 2 of "#review-commits .review-more .review-bar"
    And the review counts 5 of "#review-carried .li"
    And the review links "All 7 →" to "/admin/tasks"

  Scenario: A group past two items previews two and counts the rest
    Given the review has the tasks:
      | title  | closed     | tags |
      | Site 0 | 2026-09-16 | site |
      | Site 1 | 2026-09-16 | site |
      | Site 2 | 2026-09-16 | site |
      | Site 3 | 2026-09-16 | site |
    And the review has a journal entry on "2026-09-16" reading "walked\nfar" tagged "health"
    When I visit "/admin/review?day=2026-09-16"
    Then the review counts 2 of "#review-done .review-group:has-text('#site') .review-line"
    And the review's "#review-done .review-group:has-text('#site') .review-top > .meta" reads "+2 more"
    And the review's "#review-journal .review-group:has-text('#health') a.review-line" reads "Sep 16 walked"
    And the review's "#review-journal .review-group:has-text('#health') a.review-line" has the href "/admin/journal?to=2026-09-16#day-2026-09-16"

  Scenario: The week's arrows step a week at a time and switch to the month
    When I visit "/admin/review?day=2026-09-16"
    Then the review links "Previous week" to "/admin/review?day=2026-09-09"
    And the review links "Next week" to "/admin/review?day=2026-09-23"
    And the review links "This week" to "/admin/review"
    And the review links "Month" to "/admin/review?period=month&day=2026-09-16"

  Scenario: The done by pick keeps the done tasks of one contributor and leaves the other cards alone
    Given the review has a day's work on "2026-09-16" done as "Mine"
    And the review decision "Pick a queue for Mine" was resolved on "2026-09-16" choosing "Sidekiq"
    And the review has the tasks:
      | title   | closed     | by                                 |
      | Shared  | 2026-09-16 | owner, claude-code/claude-opus-5-5 |
      | Codex's | 2026-09-16 | codex/claude-opus-5-5              |
    When I visit "/admin/review?day=2026-09-16&by=me"
    Then the review lists "#review-done .review-line" as "Mine | Shared"
    And the review shows ".page-head-sub" reading ": 2 done,"
    And the review links "Previous week" to "/admin/review?day=2026-09-09&by=me"
    When I visit "/admin/review?day=2026-09-16&by=codex"
    Then the review lists "#review-done .review-line" as "Codex's"
    And the review links "Pick a queue for Mine" to "/admin/decisions/1"
    And the review lists ".page-head select[name='by'] option" as "Anyone | Me | claude-code | codex"
    And the review's ".page-head select[name='by'] option[selected]" reads "codex"
    When I visit "/admin/review?day=2026-09-16"
    Then the review's "#review-done .card-title" reads "Done · 3"
    When I visit "/admin/review?day=2026-09-16&group=project"
    Then the review lists the name of ".page-head form.review-by input[type='hidden']" as "day | group"
    And the review lists the value of ".page-head form.review-by input[type='hidden']" as "2026-09-16 | project"
    When I visit "/admin/review?day=2026-09-16&by[]=me"
    Then the review's ".page-head select[name='by'] option[selected]" reads "Anyone"

  Scenario: The heat map counts and shades each row by day and links each day to its scope
    Given the review has a day's work on "2026-09-16" done as "Finish the review screen"
    And the review has the tasks:
      | title   | closed     |
      | Another | 2026-09-16 |
    And the review has the commits:
      | repo            | date       | additions |
      | aaronmallen/one | 2026-09-15 | 1         |
    And the review has a journal entry on "2026-09-14" reading "one"
    When I visit "/admin/review?day=2026-09-16"
    Then the review lists "#review-heat .review-heat-day" as "Mon 14 | Tue 15 | Wed 16 | Thu 17 | Fri 18 | Sat 19 | Sun 20"
    And the review lists "#review-heat .review-heat-label" as "done | commits | worked | journal"
    And the review shows "#review-heat .review-heat-cell[aria-label='Sep 16 · 2 done']"
    And the review shows "#review-heat .review-heat-cell[aria-label='Sep 15 · 1 commit']"
    And the review shows "#review-heat .review-heat-cell[aria-label='Sep 16 · 1h 30m']"
    And the review shows "#review-heat .review-heat-cell[aria-label='Sep 14 · 1 entry']"
    And the review shows "#review-heat .review-heat-cell[aria-label='Sep 17 · 0 done']"
    And the review's "#review-heat .review-heat-cell[aria-label='Sep 15 · 1 commit']" has the style "--heat: 100%"
    And the review's "#review-heat .review-heat-cell[aria-label='Sep 16 · 0 commits']" has the style "--heat: 0%"
    And the review's "#review-heat .review-heat-cell[aria-label='Sep 16 · 2 done']" has the href "/admin/review?day=2026-09-16&focus=2026-09-16"
    And the review shows "#review-heat .review-heat-foot" reading "Pick a day to narrow the cards to it. Carried and the note keep the whole period."
    When I visit "/admin/review?period=month&day=2026-09-16"
    Then the review lists "#review-heat .review-heat-day" as "1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 | 21 | 22 | 23 | 24 | 25 | 26 | 27 | 28 | 29 | 30"

  Scenario: Once a day is picked, Carried and the note keep the whole week, as the hint says
    Given the review task "Renew the domain" was carried out of the sprints "2026-09-14"
    When I post the review note "Good week" for the day "2026-09-20"
    And I visit "/admin/review?day=2026-09-16&focus=2026-09-18"
    Then the review shows "#review-carried a" reading "Renew the domain"
    And the review's "#review-notes textarea[name='note[body]']" holds "Good week"

  Scenario: The heat map turns off the days still to come
    When I visit the review 7 days from today
    Then the review shows no "#review-heat a.review-heat-cell"
    And the review counts 28 of "#review-heat .review-heat-cell[aria-disabled]"

  Scenario: A picked day narrows every card but Carried to that day
    Given the review has a day's work on "2026-09-16" done as "Finish the review screen"
    And the review has the tasks:
      | title            | closed     |
      | Done on Thursday | 2026-09-17 |
    And the review has a journal entry on "2026-09-17" reading "thursday"
    And the review has the commits:
      | repo            | date       |
      | aaronmallen/one | 2026-09-17 |
    When I visit "/admin/review?day=2026-09-16&focus=2026-09-16"
    Then the review's ".page-head-sub" reads "Wednesday, September 16, 2026: 1 done, 0 commits, 1h 30m worked."
    And the review lists "#review-done .review-line" as "Finish the review screen"
    And the review shows "#review-journal .empty" reading "No entries that day"
    And the review shows "#review-commits .empty" reading "No commits"
    And the review shows "#review-carried a" reading "Call the accountant"
    And the review's "#review-heat .review-heat-day[aria-current='true']" reads "Wed 16"
    And the review's "#review-heat a:text-is('Whole week')" has the href "/admin/review?day=2026-09-16"
    And the review's "#review-heat .review-heat-day:has-text('Wed 16')" has the href "/admin/review?day=2026-09-16"
    And the review links "Previous week" to "/admin/review?day=2026-09-09"
    And the review shows "#review-heat .review-heat-foot" reading "every card below shows this day only"
    And the review shows no ".review-spark"
    And the review's "#review-worked .review-stat" reads "1h 30m"
    And the review shows no "#review-worked" reading "Longest days"
    And the review links "All 1 in Tasks →" to "/admin/tasks?filter=completed&from=2026-09-16&to=2026-09-16"
    And the review links "by project" to "/admin/review?day=2026-09-16&focus=2026-09-16&group=project"
    And the review shows "#review-notes" reading "filed under Sep 20, 2026"
    When I visit "/admin/review?day=2026-09-16&focus=2026-09-01"
    Then the review shows no "#review-heat .review-heat-day[aria-current]"

  Scenario: Earlier years show the same dates, newest year first, and hide when they hold nothing
    Given the review has a published post "Two years ago" dated "2024-09-20"
    And the review has a journal entry on "2025-09-15" reading "A year ago"
    And the review has a journal entry on "2025-09-21" reading "The week after"
    When I visit "/admin/review?day=2026-09-16"
    Then the review's "#review-earlier .card-title" reads "On this day · 2"
    And the review lists "#review-earlier .review-line .meta" as "Sep 15, 2025 | Sep 20, 2024"
    And the review lists the href of "#review-earlier .review-line" as "/admin/journal?to=2025-09-15#day-2025-09-15 | /admin/posts/1/edit"
    And the review lists the data-menu of "#review-earlier .review-line" as "/admin/journal/1/menu | /admin/posts/1/menu"
    When I visit "/admin/review?day=2026-09-21"
    Then the review lists "#review-earlier .review-line .meta" as "Sep 21, 2025"
    When I visit "/admin/review?day=2026-10-07"
    Then the review shows no "#review-earlier"

  Scenario: The month covers the calendar month and steps a month at a time
    Given the review has a day's work on "2026-08-31" done as "Done in August"
    And the review has a day's work on "2026-09-01" done as "Done on the first"
    And the review has a day's work on "2026-09-30" done as "Done on the last"
    When I visit "/admin/review?period=month&day=2026-09-16"
    Then the review shows ".page-head-sub" reading "September 2026"
    And the review lists "#review-done .review-line" as "Done on the first | Done on the last"
    And the review's "#review-worked .review-stat small" reads "1h 30m avg · 2 days worked"
    And the review shows ".seg-option.current[aria-current='page']" reading "Month"
    And the review links "Previous month" to "/admin/review?period=month&day=2026-08-16"
    And the review links "Next month" to "/admin/review?period=month&day=2026-10-16"
    And the review links "Week" to "/admin/review?day=2026-09-16"

  Scenario: An empty period says each card holds nothing
    When I visit "/admin/review?day=2001-01-03"
    Then the review shows "#review-done .empty" reading "Nothing done yet"
    And the review shows "#review-carried .empty" reading "Nothing slipped"
    And the review shows "#review-published .empty" reading "Nothing went out"
    And the review shows "#review-commits .empty" reading "No commits"
    And the review shows "#review-decisions .empty" reading "No decisions closed"
    And the review shows "#review-journal .empty" reading "No entries yet"
    And the review shows "#review-worked .empty" reading "No time logged"
    And the review's "#review-journal .review-stat" reads "0 entries · 0 words · 0 days written"

  Scenario: A period or day it cannot read falls back to the current week
    When I visit "/admin/review?period=year&day=2026-13-40"
    Then the review shows ".seg-option.current" reading "Week"
    And the review has no link "This week"

  Scenario Outline: The screens the review links to have no axe breaches in light or dark
    Given the review has a day's work on "2026-09-16" done as "Finish the review screen"
    And the review has a journal entry on "2025-09-15" reading "A year ago"
    When I visit "<path>"
    Then the page has no axe breaches in light or dark

    Examples:
      | path                                          |
      | /admin/review                                 |
      | /admin/review?day=2026-09-16&focus=2026-09-16 |
      | /admin/review?day=2026-09-16&group=project    |
      | /admin/journal?to=2026-09-20                  |
      | /admin/activity?to=2026-09-20                 |
