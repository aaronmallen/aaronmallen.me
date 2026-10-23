Feature: API review
  GET /api/v1/review sums up a week or a month: the tasks done and carried, the decisions closed, the journal, what
  went out, the commits and the time worked, with the same dates in earlier years. The read_review MCP tool answers
  the same.

  Background:
    Given an API token

  Scenario: A week with records gives each part of the review
    Given the review has a day's work on "2026-09-16" done as "Finish the review screen"
    And the review has a published post "A post that went out" dated "2026-09-16"
    And the review has a posted social post dated "2026-09-18"
    And the review has a journal entry on "2026-09-14" reading "one two three"
    And the review decision "Pick a queue" was resolved on "2026-09-15" choosing "Sidekiq"
    And the review decision "Move to a VPS" was dropped on "2026-09-18"
    And the review has a journal entry on "2026-09-15" reading "four five"
    And the review has the commits:
      | repo            | date       | additions | deletions |
      | aaronmallen/one | 2026-09-16 | 10        | 2         |
    When I call the API with "GET /api/v1/review?day=2026-09-17"
    Then the call answers 200
    And the answer matches:
      """
      {"period": "week", "from": "2026-09-14", "to": "2026-09-20"}
      """
    And the answer's "totals" is:
      """
      {"done": 1, "carried": 1, "worked_seconds": 5400, "commits": 1}
      """
    And the answer's "done" is:
      """
      [{"date": "2026-09-16", "tasks": [{"id": 1, "title": "Finish the review screen", "worked_seconds": 5400,
        "contributors": [{"kind": "owner"}]}]}]
      """
    And the answer's "carried" is:
      """
      [{"id": 2, "title": "Call the accountant", "carried_count": 3, "sprint_on": "2026-09-16"}]
      """
    And the answer matches:
      """
      {"posts": [{"id": 1, "date": "2026-09-16"}], "social_posts": [{"id": 1, "date": "2026-09-18"}]}
      """
    And the answer's "journal.entries.0" is:
      """
      {"id": 1, "date": "2026-09-14", "name": "one two three"}
      """
    And the answer matches:
      """
      {"journal": {"words": 5, "streak": 2}}
      """
    And the answer's "commits" is:
      """
      [{"repo": "aaronmallen/one", "commits": 1, "additions": 10, "deletions": 2}]
      """
    And the answer matches:
      """
      {"decisions": [
        {"id": 1, "outcome": "resolved", "chosen": "Sidekiq", "reason": "Settled", "date": "2026-09-15"},
        {"id": 2, "outcome": "dropped", "chosen": null, "reason": "Settled", "date": "2026-09-18"}
      ]}
      """
    And the answer matches:
      """
      {"worked": [
        {"date": "2026-09-14", "seconds": 0}, {"date": "2026-09-15", "seconds": 0},
        {"date": "2026-09-16", "seconds": 5400}, {"date": "2026-09-17", "seconds": 0},
        {"date": "2026-09-18", "seconds": 0}, {"date": "2026-09-19", "seconds": 0},
        {"date": "2026-09-20", "seconds": 0}
      ]}
      """

  Scenario: The API and the admin screen give the same numbers and decisions for a week
    Given the review has a day's work on "2026-09-16" done as "Finish the review screen"
    And the review decision "Pick a queue" was resolved on "2026-09-15" choosing "Sidekiq"
    And the review decision "Move to a VPS" was dropped on "2026-09-18"
    And the review has the commits:
      | repo            | date       | additions | deletions |
      | aaronmallen/one | 2026-09-16 | 10        | 2         |
    And I am signed in to the admin
    And an MCP client connected with the scopes "read"
    When I call the MCP tool "read_review" with:
      """
      {"day": "2026-09-16"}
      """
    Then the answer matches:
      """
      {"totals": {"done": 1, "commits": 1, "worked_seconds": 5400},
        "decisions": [{"title": "Pick a queue"}, {"title": "Move to a VPS"}]}
      """
    When I visit "/admin/review?day=2026-09-16"
    Then the review's ".page-head-sub" starts with "Sep 14 → Sep 20, 2026: 1 done, 1 commit, 1h 30m worked"
    And the review lists "#review-decisions a.li-title" as "Pick a queue | Move to a VPS"

  Scenario: A month runs across the calendar month
    Given the review has a day's work on "2026-08-31" done as "Done in August"
    And the review has a day's work on "2026-09-01" done as "Done on the first"
    And the review has a day's work on "2026-09-30" done as "Done on the last"
    When I call the API with "GET /api/v1/review?period=month&day=2026-09-16"
    Then the answer matches:
      """
      {"period": "month", "from": "2026-09-01", "to": "2026-09-30",
        "done": [{"date": "2026-09-01"}, {"date": "2026-09-30"}]}
      """
    And the answer's "worked" lists 30

  Scenario: A month with records on each edge keeps only what fell inside it
    Given the review has the tasks:
      | title      | closed     |
      | Done Aug31 | 2026-08-31 |
      | Done Sep1  | 2026-09-01 |
      | Done Sep30 | 2026-09-30 |
      | Done Oct1  | 2026-10-01 |
    And the review task "Carried Aug31" was carried out of the sprints "2026-08-31"
    And the review task "Carried Sep1" was carried out of the sprints "2026-09-01"
    And the review task "Carried Sep30" was carried out of the sprints "2026-09-30"
    And the review task "Carried Oct1" was carried out of the sprints "2026-10-01"
    And the review has a published post "Aug31" dated "2026-08-31"
    And the review has a published post "Sep1" dated "2026-09-01"
    And the review has a published post "Sep30" dated "2026-09-30"
    And the review has a published post "Oct1" dated "2026-10-01"
    And the review has a posted social post dated "2026-08-31"
    And the review has a posted social post dated "2026-09-01"
    And the review has a posted social post dated "2026-09-30"
    And the review has a posted social post dated "2026-10-01"
    And the review has a journal entry on "2026-08-31" reading "a day"
    And the review has a journal entry on "2026-09-01" reading "a day"
    And the review has a journal entry on "2026-09-30" reading "a day"
    And the review has a journal entry on "2026-10-01" reading "a day"
    And the review has the commits:
      | repo            | date       | additions |
      | aaronmallen/one | 2026-08-31 | 1         |
      | aaronmallen/one | 2026-09-01 | 1         |
      | aaronmallen/one | 2026-09-30 | 1         |
      | aaronmallen/one | 2026-10-01 | 1         |
    And the review task "Worked Aug31" ran from "2026-08-31 09:00" to "2026-08-31 10:00"
    And the review task "Worked Sep1" ran from "2026-09-01 09:00" to "2026-09-01 10:00"
    And the review task "Worked Sep30" ran from "2026-09-30 09:00" to "2026-09-30 10:00"
    And the review task "Worked Oct1" ran from "2026-10-01 09:00" to "2026-10-01 10:00"
    And the review decision "Aug31" was resolved on "2026-08-31" choosing "Sidekiq"
    And the review decision "Sep1" was resolved on "2026-09-01" choosing "Sidekiq"
    And the review decision "Sep30" was resolved on "2026-09-30" choosing "Sidekiq"
    And the review decision "Oct1" was resolved on "2026-10-01" choosing "Sidekiq"
    When I call the API with "GET /api/v1/review?period=month&day=2026-09-16"
    Then the answer matches:
      """
      {"done": [{"date": "2026-09-01"}, {"date": "2026-09-30"}],
        "carried": [{"sprint_on": "2026-09-01"}, {"sprint_on": "2026-09-30"}],
        "posts": [{"date": "2026-09-01"}, {"date": "2026-09-30"}],
        "social_posts": [{"date": "2026-09-01"}, {"date": "2026-09-30"}],
        "journal": {"entries": [{"date": "2026-09-01"}, {"date": "2026-09-30"}]},
        "commits": [{"repo": "aaronmallen/one", "commits": 2}],
        "decisions": [{"date": "2026-09-01"}, {"date": "2026-09-30"}]}
      """
    And the answer's "worked.0" is:
      """
      {"date": "2026-09-01", "seconds": 3600}
      """
    And the answer's "worked.29" is:
      """
      {"date": "2026-09-30", "seconds": 3600}
      """
    And the answer's "totals.worked_seconds" is "7200"

  Scenario: The week groups the tasks done by the local day they closed
    Given the review has the tasks:
      | title | closed           |
      | Late  | 2026-09-15 23:30 |
      | Early | 2026-09-17 00:30 |
    When I call the API with "GET /api/v1/review?day=2026-09-16"
    Then the answer matches:
      """
      {"done": [{"date": "2026-09-15", "tasks": [{"id": 1}]}, {"date": "2026-09-17", "tasks": [{"id": 2}]}]}
      """

  Scenario: The week leaves out tasks closed outside it and canceled tasks
    Given the review has the tasks:
      | title    | closed           | status   |
      | Before   | 2026-09-13 23:59 | done     |
      | After    | 2026-09-21 00:01 | done     |
      | Canceled | 2026-09-16       | canceled |
    When I call the API with "GET /api/v1/review?day=2026-09-16"
    Then the answer's "done" is:
      """
      []
      """

  Scenario: The week names the last sprint each task left in it and counts only the carries out of its sprints
    Given the review task "Twice" was carried out of the sprints "2026-09-14, 2026-09-16"
    And the review task "Edges" was carried out of the sprints "2026-09-11, 2026-09-18, 2026-09-21"
    When I call the API with "GET /api/v1/review?day=2026-09-16"
    Then the answer matches:
      """
      {"carried": [
        {"id": 1, "carried_count": 2, "sprint_on": "2026-09-16"},
        {"id": 2, "carried_count": 1, "sprint_on": "2026-09-18"}
      ]}
      """

  Scenario: A task carried out of the week stays there after it is carried again the next week
    Given the review task "Again" was carried out of the sprints "2026-09-18, 2026-09-21"
    When I call the API with "GET /api/v1/review?day=2026-09-16"
    Then the answer's "carried" is:
      """
      [{"id": 1, "title": "Again", "carried_count": 1, "sprint_on": "2026-09-18"}]
      """
    When I call the API with "GET /api/v1/review?day=2026-09-23"
    Then the answer matches:
      """
      {"carried": [{"id": 1, "sprint_on": "2026-09-21"}]}
      """

  Scenario: A task carried before the week and later scheduled into it is left out
    Given the database runs:
      """
      insert into sprints (sprint_date) values ('2026-09-16');
      insert into tasks (title, sprint_id, position, carried_count) values ('Scheduled', 1, 1, 3);
      """
    And the review task "Scheduled" was carried out of the sprints "2026-09-01, 2026-09-02, 2026-09-03"
    When I call the API with "GET /api/v1/review?day=2026-09-16"
    Then the answer's "carried" is:
      """
      []
      """

  Scenario: Moves that are not carries are left out
    Given the review task "Ahead" moved from the sprint "2026-09-16" to the sprint "2026-09-18" on "2026-09-16"
    And the review task "Back" moved from the sprint "2026-09-16" to the sprint "2026-09-15" on "2026-09-17"
    And the review task "Listed" moved from the sprint "2026-09-16" to the list "next"
    When I call the API with "GET /api/v1/review?day=2026-09-16"
    Then the answer's "carried" is:
      """
      []
      """

  Scenario: The week leaves out drafts and what went out in another week
    Given the review has a draft post "Draft" dated "2026-09-16"
    And the review has a published post "Later" dated "2026-09-21"
    And the review has a draft social post dated ""
    And the review has a posted social post dated "2026-09-13"
    When I call the API with "GET /api/v1/review?day=2026-09-16"
    Then the answer matches:
      """
      {"posts": [], "social_posts": []}
      """

  Scenario: A week with no entries gives no journal streak
    When I call the API with "GET /api/v1/review?day=2026-09-16"
    Then the answer's "journal.streak" is "0"

  Scenario: A decision closed twice in the week shows once, with how it last closed
    Given the review decision "Pick a store" was resolved on "2026-09-14" choosing "Redis"
    And the review decision "Pick a store" was reopened on "2026-09-15"
    And the review decision "Pick a store" was dropped on "2026-09-16"
    When I call the API with "GET /api/v1/review?day=2026-09-16"
    Then the answer's "decisions" lists 1
    And the answer matches:
      """
      {"decisions": [{"id": 1, "outcome": "dropped"}]}
      """

  Scenario: The week leaves out decisions closed in another week and events that close nothing
    Given the review decision "Before" was resolved on "2026-09-13 23:00" choosing "Redis"
    And the review decision "After" was dropped on "2026-09-21 00:00"
    And the review decision "Opened" was opened on "2026-09-16"
    When I call the API with "GET /api/v1/review?day=2026-09-16"
    Then the answer's "decisions" is:
      """
      []
      """

  Scenario: A session that crosses midnight splits between both days
    Given the review has the tasks:
      | title | status | worked |
      | Late  | open   | 9000   |
    And the review task "Late" ran from "2026-09-15 23:00" to "2026-09-16 01:30"
    When I call the API with "GET /api/v1/review?day=2026-09-16"
    Then the answer matches:
      """
      {"worked": [{}, {"date": "2026-09-15", "seconds": 3600}, {"date": "2026-09-16", "seconds": 5400}, {}, {}, {}, {}]}
      """

  Scenario: A task whose total fell below its sessions adds no time set by hand
    Given the review has the tasks:
      | title | closed           | worked |
      | Short | 2026-09-16 11:00 | 1800   |
    And the review task "Short" ran from "2026-09-07 09:00" to "2026-09-07 11:00"
    And the review task "Short" ran from "2026-09-16 09:00" to "2026-09-16 10:00"
    When I call the API with "GET /api/v1/review?day=2026-09-16"
    Then the answer's "worked.2.seconds" is "3600"
    And the answer's "totals.worked_seconds" is "3600"

  Scenario: Only the part of a session inside the week counts
    Given the review has the tasks:
      | title  | status | worked |
      | Sunday | open   | 7200   |
    And the review task "Sunday" ran from "2026-09-13 23:00" to "2026-09-14 01:00"
    When I call the API with "GET /api/v1/review?day=2026-09-16"
    Then the answer's "worked.0" is:
      """
      {"date": "2026-09-14", "seconds": 3600}
      """
    And the answer's "totals.worked_seconds" is "3600"

  Scenario: An hour three tasks shared counts once, though each done task keeps the full hour
    Given the review has the tasks:
      | title | closed           | worked |
      | One   | 2026-09-16 10:00 | 3600   |
      | Two   | 2026-09-16 10:00 | 3600   |
      | Three | 2026-09-16 10:00 | 3600   |
    And the review task "One" ran from "2026-09-16 09:00" to "2026-09-16 10:00"
    And the review task "Two" ran from "2026-09-16 09:00" to "2026-09-16 10:00"
    And the review task "Three" ran from "2026-09-16 09:00" to "2026-09-16 10:00"
    When I call the API with "GET /api/v1/review?day=2026-09-16"
    Then the answer's "worked.2.seconds" is "3600"
    And the answer's "totals.worked_seconds" is "3600"
    And the answer matches:
      """
      {"done": [{"tasks": [{"worked_seconds": 3600}, {"worked_seconds": 3600}, {"worked_seconds": 3600}]}]}
      """

  Scenario: Overlap that crosses midnight lands on the day it fell on
    Given the review has the tasks:
      | title | closed           | worked |
      | Long  | 2026-09-16 01:00 | 7200   |
      | Short | 2026-09-16 00:30 | 3600   |
    And the review task "Long" ran from "2026-09-15 23:00" to "2026-09-16 01:00"
    And the review task "Short" ran from "2026-09-15 23:30" to "2026-09-16 00:30"
    When I call the API with "GET /api/v1/review?day=2026-09-16"
    Then the answer's "worked.1.seconds" is "3600"
    And the answer's "worked.2.seconds" is "3600"

  Scenario: A running task that overlaps a closed one counts once up to now
    Given the review has the tasks:
      | title   | closed           | worked | status      |
      | Closed  | 2026-09-16 11:00 | 10800  | done        |
      | Running |                  | 0      | in_progress |
    And the review task "Closed" ran from "2026-09-16 08:00" to "2026-09-16 11:00"
    And the review task "Running" has run since "2026-09-16 09:00"
    When I call the API with "GET /api/v1/review?day=2026-09-16"
    Then the answer's "worked.2.seconds" is "57600"
    And the answer's "worked.3.seconds" is "86400"

  Scenario: Time set by hand lands on top, on the day the task closed
    Given the review has the tasks:
      | title  | closed           | worked |
      | Manual | 2026-09-17       | 5400   |
      | Plain  | 2026-09-16 10:00 | 3600   |
    And the review task "Manual" ran from "2026-09-16 09:00" to "2026-09-16 10:00"
    And the review task "Plain" ran from "2026-09-16 09:00" to "2026-09-16 10:00"
    When I call the API with "GET /api/v1/review?day=2026-09-16"
    Then the answer's "worked.2.seconds" is "3600"
    And the answer's "worked.3.seconds" is "1800"
    And the database answers "5400" for:
      """
      select worked_seconds from tasks where title = 'Manual'
      """

  Scenario: Time set by hand never comes off the day an open task last ran
    Given the review has the tasks:
      | title | status | worked |
      | Open  | open   | 2400   |
    And the review task "Open" ran from "2026-09-16 09:00" to "2026-09-16 10:00"
    When I call the API with "GET /api/v1/review?day=2026-09-16"
    Then the answer's "worked.2.seconds" is "3600"

  Scenario: Time set by hand stays on the day an open task last ran while a session runs
    Given the review has the tasks:
      | title   | status      | worked |
      | Running | in_progress | 5400   |
    And the review task "Running" ran from "2026-09-16 09:00" to "2026-09-16 10:00"
    And the review task "Running" has run for the last 10 minutes
    When I call the API with "GET /api/v1/review?day=2026-09-16"
    Then the answer's "worked.2.seconds" is "5400"

  Scenario: A focused day narrows the review to that day but keeps every day's counts and every carry
    Given the review has a day's work on "2026-09-16" done as "Done on Wednesday"
    And the review has a day's work on "2026-09-17" done as "Done on Thursday"
    And the review has a published post "Wednesday" dated "2026-09-16"
    And the review has a published post "Thursday" dated "2026-09-17"
    And the review has a posted social post dated "2026-09-16"
    And the review has a posted social post dated "2026-09-17"
    And the review has a journal entry on "2026-09-16" reading "a day"
    And the review has a journal entry on "2026-09-17" reading "a day"
    And the review has the commits:
      | repo            | date       | additions |
      | aaronmallen/one | 2026-09-16 | 1         |
      | aaronmallen/one | 2026-09-17 | 1         |
    And the review decision "Wednesday" was resolved on "2026-09-16" choosing "Sidekiq"
    And the review decision "Thursday" was resolved on "2026-09-17" choosing "Sidekiq"
    When I call the API with "GET /api/v1/review?day=2026-09-14&focus=2026-09-16"
    Then the answer matches:
      """
      {"from": "2026-09-14", "to": "2026-09-20", "focus": "2026-09-16",
        "done": [{"date": "2026-09-16"}], "decisions": [{"date": "2026-09-16"}],
        "posts": [{"date": "2026-09-16"}], "social_posts": [{"date": "2026-09-16"}],
        "journal": {"entries": [{"date": "2026-09-16"}]},
        "commits": [{"commits": 1}]}
      """
    And the answer's "worked" is:
      """
      [{"date": "2026-09-16", "seconds": 5400}]
      """
    And the answer's "carried" lists 2
    And the answer's "days" is:
      """
      [
        {"date": "2026-09-14", "done": 0, "commits": 0, "worked_seconds": 0, "journal": 0},
        {"date": "2026-09-15", "done": 0, "commits": 0, "worked_seconds": 0, "journal": 0},
        {"date": "2026-09-16", "done": 1, "commits": 1, "worked_seconds": 5400, "journal": 1},
        {"date": "2026-09-17", "done": 1, "commits": 1, "worked_seconds": 5400, "journal": 1},
        {"date": "2026-09-18", "done": 0, "commits": 0, "worked_seconds": 0, "journal": 0},
        {"date": "2026-09-19", "done": 0, "commits": 0, "worked_seconds": 0, "journal": 0},
        {"date": "2026-09-20", "done": 0, "commits": 0, "worked_seconds": 0, "journal": 0}
      ]
      """
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read"
    Then the review MCP tool "read_review" answers as "GET /api/v1/review?day=2026-09-14&focus=2026-09-16" does, given:
      """
      {"day": "2026-09-14", "focus": "2026-09-16"}
      """

  Scenario Outline: A focus outside the period or not a date covers the whole period
    Given the review has a day's work on "2026-09-16" done as "Done on Wednesday"
    And the review has a day's work on "2026-09-17" done as "Done on Thursday"
    When I call the API with "GET /api/v1/review?day=2026-09-14&focus=<focus>"
    Then the answer matches:
      """
      {"focus": null, "done": [{"date": "2026-09-16"}, {"date": "2026-09-17"}]}
      """

    Examples:
      | focus      |
      | 2026-09-21 |
      | soon       |

  Scenario: A Sunday stays in the week before the next Monday
    When I call the API with "GET /api/v1/review?day=2026-09-20"
    Then the answer matches:
      """
      {"from": "2026-09-14", "to": "2026-09-20"}
      """

  Scenario: With no period or day it reads the week that holds today
    When I call the review API with "GET /api/v1/review"
    Then the review API answer names this week

  Scenario: A period other than week or month answers 422
    When I call the API with "GET /api/v1/review?period=year"
    Then the call answers 422
    And the answer's "errors" is:
      """
      {"period": ["value at `/period` is not one of: [\"week\", \"month\"]"]}
      """

  Scenario: A day it cannot read answers 422
    When I call the review API with "GET /api/v1/review?day=2026-13-40"
    Then the review API answers 422
    And the review API answer, less its stamps, is:
      """
      {"error": "invalid", "message": "give the day as a date, such as 2026-01-01",
        "errors": {"day": ["give the day as a date, such as 2026-01-01"]}}
      """

  Scenario: Each done task names who did it, and the review keeps only the done tasks of the one asked for
    Given the review has a day's work on "2026-09-16" done as "Mine"
    And the review has the tasks:
      | title    | closed     | by                                            |
      | Shared   | 2026-09-16 | owner, claude-code/claude-opus-5-5            |
      | Sonnet's | 2026-09-16 | claude-code/claude-sonnet-5                   |
    When I call the API with "GET /api/v1/review?day=2026-09-16"
    Then the answer matches:
      """
      {"done": [{"tasks": [
        {"title": "Mine", "contributors": [{"kind": "owner"}]},
        {"title": "Shared", "contributors": [{"kind": "owner"},
          {"kind": "agent", "agent": "claude-code", "model": "claude-opus-5-5"}]},
        {"title": "Sonnet's"}
      ]}]}
      """
    When I call the API with "GET /api/v1/review?day=2026-09-16&contributor=owner"
    Then the answer matches:
      """
      {"done": [{"tasks": [{"title": "Mine"}, {"title": "Shared"}]}]}
      """
    When I call the API with "GET /api/v1/review?day=2026-09-16&contributor=agent"
    Then the answer matches:
      """
      {"done": [{"tasks": [{"title": "Shared"}, {"title": "Sonnet's"}]}]}
      """
    When I call the API with "GET /api/v1/review?day=2026-09-16&agent=claude-code"
    Then the answer matches:
      """
      {"done": [{"tasks": [{"title": "Shared"}, {"title": "Sonnet's"}]}]}
      """
    When I call the API with "GET /api/v1/review?day=2026-09-16&model=claude-sonnet-5"
    Then the answer matches:
      """
      {"done": [{"tasks": [{"title": "Sonnet's"}]}],
        "totals": {"done": 1, "carried": 1, "worked_seconds": 5400}}
      """
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read"
    Then the review MCP tool "read_review" answers as "GET /api/v1/review?day=2026-09-16&contributor=agent" does, given:
      """
      {"day": "2026-09-16", "contributor": "agent"}
      """

  Scenario: A contributor that is neither the owner nor an agent answers 422
    When I call the API with "GET /api/v1/review?contributor=robot"
    Then the call answers 422
    And the answer's "errors" is:
      """
      {"contributor": ["value at `/contributor` is not one of: [\"owner\", \"agent\"]"]}
      """

  Scenario: Earlier years list the journal entries and published posts from the same dates, newest year first
    Given the review has a journal entry on "2025-09-15" reading "A year ago"
    And the review has a published post "Two years ago" dated "2024-09-20"
    And the review has a draft post "A draft" dated "2025-09-16"
    And the review has a journal entry on "2025-09-21" reading "The week after"
    And the review has a journal entry on "2026-09-10" reading "Earlier this month"
    When I call the API with "GET /api/v1/review?day=2026-09-16"
    Then the answer matches:
      """
      {"earlier": [{"type": "journal", "id": 1, "date": "2025-09-15", "name": "A year ago"},
                    {"type": "post", "id": 1, "date": "2024-09-20", "name": "Two years ago"}]}
      """
    When I call the API with "GET /api/v1/review?day=2026-09-21"
    Then the answer matches:
      """
      {"earlier": [{"type": "journal", "date": "2025-09-21", "name": "The week after"}]}
      """
    When I call the API with "GET /api/v1/review?period=month&day=2026-09-16"
    Then the answer matches:
      """
      {"earlier": [{"date": "2025-09-21"}, {"date": "2025-09-15"}, {"date": "2024-09-20"}]}
      """
    When I call the API with "GET /api/v1/review?day=2026-09-16&focus=2026-09-15"
    Then the answer matches:
      """
      {"earlier": [{"type": "journal", "date": "2025-09-15", "name": "A year ago"}]}
      """
    When I call the API with "GET /api/v1/review?day=2026-10-07"
    Then the answer's "earlier" is:
      """
      []
      """
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read"
    Then the review MCP tool "read_review" answers as "GET /api/v1/review?day=2026-09-16" does, given:
      """
      {"day": "2026-09-16"}
      """

  Scenario: Earlier years take the same dates on both sides of a new year
    Given the review has a journal entry on "2024-12-30" reading "Before"
    And the review has a journal entry on "2025-01-02" reading "After"
    When I call the API with "GET /api/v1/review?day=2026-01-01"
    Then the answer matches:
      """
      {"earlier": [{"date": "2025-01-02"}, {"date": "2024-12-30"}]}
      """

  Scenario: Earlier years keep a leap day in its month
    Given the review has a journal entry on "2024-02-29" reading "Leap"
    When I call the API with "GET /api/v1/review?period=month&day=2026-02-10"
    Then the answer matches:
      """
      {"earlier": [{"date": "2024-02-29"}]}
      """

  Scenario: The MCP tool reads and refuses as the endpoint does
    Given the review has a day's work on "2026-09-16" done as "Finish the review screen"
    And the review decision "Pick a queue" was resolved on "2026-09-16" choosing "Sidekiq"
    And I am signed in to the admin
    And an MCP client connected with the scopes "read"
    Then the review MCP tool "read_review" answers as "GET /api/v1/review?period=month&day=2026-09-16" does, given:
      """
      {"period": "month", "day": "2026-09-16"}
      """
    And the review MCP tool "read_review" refuses ending with the message "GET /api/v1/review?period=year" gives, given:
      """
      {"period": "year"}
      """
    And the review MCP tool "read_review" refuses with the message "GET /api/v1/review?day=next%20week" gives, given:
      """
      {"day": "next week"}
      """
