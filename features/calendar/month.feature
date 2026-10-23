Feature: Calendar month
  The calendar page draws a month of days and opens one day in a panel beside it.

  Background:
    Given I am signed in to the admin

  Scenario: The calendar opens on this month with today marked
    When I open the calendar
    Then the calendar heading names "<today month>"
    And the calendar marks only "today" as today
    And the calendar pager marks this month
    And the calendar day panel is for "today"
    And the calendar draws whole weeks from Monday through the month of "today"
    And the calendar group tabs link "/admin/tasks /admin/calendar /admin/projects"
    And the command palette lists the calendar with its icon
    And the page has no axe breaches in light or dark

  Scenario: A day in the month shows what lands on it
    Given the scheduled post "A post on its day" lands on the calendar on "2026-07-14" at "09:00"
    And the posted social post "Sent note" lands on the calendar on "2026-07-14" at "08:00"
    And the scheduled social post "Queued note" lands on the calendar on "2026-07-14" at "10:00"
    And the scheduled social post "Late note" lands on the calendar on "2026-07-14" at "11:00"
    And the sprint on the calendar day "2026-07-14" holds the in_progress task "Plan the week"
    And the sprint on the calendar day "2026-07-14" holds the open task "Write the calendar"
    And a journal entry lands on the calendar on "2026-07-14"
    When I open the calendar month "2026-07"
    Then the calendar cell for "2026-07-14" shows the marks:
      """
      A post on its day
      08:00 Sent note
      10:00 Queued note
      +1 social
      2 tasks
      journal
      """
    And the calendar cell for "2026-07-15" shows no marks
    And the calendar cell for "2026-07-14" reads "Tuesday, July 14, 2026" to screen readers
    And the calendar cell for "2026-07-14" links to "/admin/calendar?day=2026-07-14"

  Scenario: A day's panel lists and links what lands on it
    Given the scheduled post "A post on its day" lands on the calendar on "2026-07-14" at "09:00"
    And the posted social post "Sent note" lands on the calendar on "2026-07-14" at "08:00"
    And the scheduled social post "Queued note" lands on the calendar on "2026-07-14" at "10:00"
    And the sprint on the calendar day "2026-07-14" holds the in_progress task "Plan the week"
    And the sprint on the calendar day "2026-07-14" holds the open task "Write the calendar"
    And a journal entry lands on the calendar on "2026-07-14"
    When I open the calendar on "2026-07-14"
    Then the calendar heading names "July 2026"
    And the calendar marks only "2026-07-14" as picked
    And the calendar day panel shows "Tuesday, July 14, 2026"
    And the calendar day panel links "Write the calendar" to "/admin/tasks/<task Write the calendar>"
    And the calendar sprint names the statuses "in progress, open"
    And the calendar day panel links "A post on its day" to "/admin/posts/<post A post on its day>/edit"
    And the calendar day panel says when each item goes out:
      """
      scheduled · 09:00
      posted · 08:00
      scheduled · 10:00
      """
    And the calendar day panel puts the times "09:00, 08:00, 10:00" of "2026-07-14" in time tags
    And the calendar day panel links the social posts to:
      """
      /admin/social?filter=posted
      /admin/social?filter=queued&edit=<social Queued note>
      """
    And the calendar day panel links "Journal entry" to "/admin/journal?to=2026-07-14"
    And the page has no axe breaches in light or dark

  Scenario: A day that holds nothing says so
    When I open the calendar on "2026-07-15"
    Then the calendar day panel shows "Nothing lands on this day"

  Scenario: A sprint that holds no tasks says so
    Given an empty sprint lands on the calendar on "2026-07-14"
    When I open the calendar on "2026-07-14"
    Then the calendar day panel shows "Sprint · 0 tasks"
    And the calendar day panel shows "No tasks in this sprint yet"

  Scenario: The arrows step from month to month
    When I open the calendar month "2026-01"
    Then the calendar links "Previous month, December 2025" to "/admin/calendar?month=2025-12"
    And the calendar links "Next month, February 2026" to "/admin/calendar?month=2026-02"
    And the calendar links "This month" to "/admin/calendar"
    And the calendar pager does not mark this month
    And the calendar arrows point each way with an icon

  Scenario: A month that holds no today opens on its first day
    When I open the calendar month "2026-02"
    Then the calendar day panel is for "2026-02-01"

  Scenario: A month the calendar cannot read falls back to this month
    When I open the calendar month "2026-13"
    Then the calendar heading names "<today month>"
