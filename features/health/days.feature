Feature: Health days through the API and MCP
  An agent with the health permission reads each day's health beside its work, the workouts, the 30 day baselines and
  the patterns between them.

  Scenario: The API answers one row a day with its health beside its work
    Given an API token with the scopes "health"
    And the health days:
      | day        | asleep | hrv  | resting | steps |
      | 2026-09-08 | 420    | 48.5 | 54      | 8421  |
    And the commits:
      | day        | at    |
      | 2026-09-08 | 22:15 |
    And the workouts:
      | day        | at    | kind    | minutes | device |
      | 2026-09-07 | 07:00 | RUNNING | 42      | Watch  |
      | 2026-09-14 | 07:00 | WALKING | 30      | Watch  |
    When I read the health days from "2026-09-07" to "2026-09-13" through the API
    Then the health days answer lists the days "2026-09-07" to "2026-09-13"
    And the health days answer holds:
      """
      {
        "days": [
          {"day": "2026-09-07", "minutes_asleep": null, "hrv": null, "commits": 0},
          {"day": "2026-09-08", "minutes_asleep": 420, "hrv": 48.5, "resting_heart_rate": 54, "steps": 8421, "commits": 1, "late_commits": 1},
          {}, {}, {}, {}, {}
        ],
        "workouts": [{"id": 1, "kind": "RUNNING", "minutes": 42, "device": "Watch"}],
        "baseline": {"minutes_asleep": 420, "hrv": 48.5, "resting_heart_rate": 54}
      }
      """
    And the health days answer has no patterns

  Scenario: The API fills a pattern once each group holds 3 days
    Given an API token with the scopes "health"
    And the health days:
      | day        | resting |
      | 2026-09-07 | 55      |
      | 2026-09-08 | 55      |
      | 2026-09-09 | 55      |
      | 2026-09-10 | 55      |
      | 2026-09-11 | 55      |
      | 2026-09-12 | 55      |
      | 2026-09-13 | 55      |
      | 2026-09-14 | 60      |
      | 2026-09-15 | 60      |
      | 2026-09-16 | 60      |
      | 2026-09-17 | 60      |
      | 2026-09-18 | 60      |
      | 2026-09-19 | 60      |
      | 2026-09-20 | 60      |
    When I read the health days from "2026-09-07" to "2026-09-20" through the API
    Then the health days answer holds:
      """
      {"patterns": {"resting_heart_rate": {
        "subject": {"days": 7, "averages": {"resting_heart_rate": 60}},
        "rest": {"days": 7, "averages": {"resting_heart_rate": 55}}
      }}}
      """

  Scenario: The API refuses a token without health
    Given an API token with the scopes "read suggest write publish delete"
    When I read the health days from "2026-09-07" to "2026-09-13" through the API
    Then the API answer holds:
      """
      {"error": "insufficient_scope", "error_description": "this endpoint needs a token with the health scope"}
      """

  Scenario: The API refuses a range past a year or one that runs backwards
    Given an API token with the scopes "health"
    When I read the health days from "2025-01-01" to "2026-09-13" through the API
    Then the API answers 422
    When I read the health days from "2026-09-13" to "2026-09-07" through the API
    Then the API answers 422

  Scenario: MCP reads the day rows, workouts and patterns for a client with health
    Given the health days:
      | day        | asleep | hrv  |
      | 2026-09-07 | 420    | 48.5 |
    And the workouts:
      | day        | at    | kind    |
      | 2026-09-08 | 07:00 | RUNNING |
    And an MCP client connected with the scopes "health"
    When I read the health days from "2026-09-07" to "2026-09-13" through MCP
    Then the health days answer holds:
      """
      {"days": [{"day": "2026-09-07", "minutes_asleep": 420, "hrv": 48.5}, {}, {}, {}, {}, {}, {}], "workouts": [{"kind": "RUNNING"}], "patterns": {"short_nights": null}}
      """
    When I read the health days from "2025-09-08" to "2026-09-08" through MCP
    Then the health days answer lists the days "2025-09-08" to "2026-09-08"
    When I read the health days from "2025-09-07" to "2026-09-08" through MCP
    Then the health days are refused with "give a range of 366 days or fewer"

  Scenario: MCP gives a client with only read no health data
    Given the health days:
      | day        | asleep |
      | 2026-09-07 | 420    |
    And an MCP client connected with the scopes "read"
    When I read the health days from "2026-09-07" to "2026-09-13" through MCP
    Then the health days are refused with "read_health_days needs the health permission"

  Scenario: A day's row holds its health and every kind of work
    Given an API token with the scopes "health"
    And the health days:
      | day        | asleep | hrv  | resting | steps | zone | bed   | woke  |
      | 2026-09-08 | 420    | 48.5 | 54      | 8421  | 22   | 23:00 | 07:00 |
    And the work sessions:
      | day        | from  | until |
      | 2026-09-08 | 09:00 | 10:00 |
    And the commits:
      | day        | at    |
      | 2026-09-08 | 08:30 |
      | 2026-09-08 | 22:15 |
    And a task done on the health day "2026-09-08" at "15:00"
    And a task canceled on the health day "2026-09-08" at "16:00"
    And a pull request ready on the health day "2026-09-08" at "11:00"
    And a pull request opened on the health day "2026-09-07" at "11:00" and merged on "2026-09-08" at "12:00"
    And a journal entry on the health day "2026-09-08"
    When I read the health days from "2026-09-07" to "2026-09-20" through the API
    Then the health days answer lists the days "2026-09-07" to "2026-09-20"
    And the health days answer holds:
      """
      {"days": [{}, {
        "day": "2026-09-08", "minutes_asleep": 420, "bed_at": "2026-09-08T04:00:00Z",
        "woke_at": "2026-09-08T12:00:00Z", "resting_heart_rate": 54, "hrv": 48.5, "steps": 8421,
        "active_zone_minutes": 22, "focus_minutes": 60, "commits": 2, "late_commits": 1, "tasks_done": 1,
        "pull_requests_opened": 1, "pull_requests_merged": 1, "journal_entries": 1,
        "first_active_at": "2026-09-08T13:30:00Z", "last_active_at": "2026-09-09T03:15:00Z"
      }, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}]}
      """

  Scenario: Focus counts each minute of overlapping work sessions once
    Given an API token with the scopes "health"
    And the work sessions:
      | day        | from  | until |
      | 2026-09-07 | 09:00 | 11:00 |
      | 2026-09-07 | 10:00 | 12:00 |
    When I read the health days from "2026-09-07" to "2026-09-20" through the API
    Then the health days answer holds:
      """
      {"days": [{"minutes_asleep": null, "hrv": null, "focus_minutes": 180, "first_active_at": "2026-09-07T14:00:00Z", "last_active_at": "2026-09-07T17:00:00Z"}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}]}
      """

  Scenario: Focus counts no manual time for a task whose total fell below its sessions
    Given an API token with the scopes "health"
    And the work sessions:
      | day        | from  | until | task   | worked | done       |
      | 2026-09-07 | 09:00 | 11:00 | Gutter | 1800   | 2026-09-15 |
      | 2026-09-15 | 09:00 | 10:00 | Gutter |        |            |
    When I read the health days from "2026-09-07" to "2026-09-20" through the API
    Then the health days answer holds:
      """
      {"days": [{"focus_minutes": 120}, {}, {}, {}, {}, {}, {}, {}, {"focus_minutes": 60}, {}, {}, {}, {}, {}]}
      """

  Scenario: Focus splits a session that runs past midnight between its days
    Given an API token with the scopes "health"
    And the work sessions:
      | day        | from  | until | until_day  |
      | 2026-09-07 | 23:00 | 01:00 | 2026-09-08 |
    When I read the health days from "2026-09-07" to "2026-09-20" through the API
    Then the health days answer holds:
      """
      {"days": [
        {"focus_minutes": 60, "first_active_at": "2026-09-08T04:00:00Z", "last_active_at": "2026-09-08T05:00:00Z"},
        {"focus_minutes": 60, "first_active_at": "2026-09-08T05:00:00Z", "last_active_at": "2026-09-08T06:00:00Z"},
        {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
      ]}
      """

  Scenario: The baselines average the 30 days up to the last day
    Given an API token with the scopes "health"
    And the health days:
      | day        | asleep | hrv | resting |
      | 2026-08-21 | 100    | 10  | 90      |
      | 2026-08-22 | 400    | 40  | 55      |
      | 2026-09-20 | 450    | 45  | 56      |
    When I read the health days from "2026-09-07" to "2026-09-20" through the API
    Then the health days answer holds:
      """
      {"baseline": {"minutes_asleep": 425, "hrv": 42.5, "resting_heart_rate": 55.5}}
      """

  Scenario: The workouts are the range's only, to the last minute of its last day
    Given an API token with the scopes "health"
    And the workouts:
      | day        | at    | kind    |
      | 2026-09-20 | 23:00 | RUNNING |
      | 2026-09-21 | 00:30 | WALKING |
    When I read the health days from "2026-09-07" to "2026-09-20" through the API
    Then the health days answer holds:
      """
      {"workouts": [{"id": 1, "kind": "RUNNING"}]}
      """

  Scenario: A pattern compares focus after short weekday nights with the other weekdays
    Given an API token with the scopes "health"
    And the health days:
      | day        | asleep |
      | 2026-09-07 | 300    |
      | 2026-09-08 | 300    |
      | 2026-09-09 | 300    |
      | 2026-09-10 | 450    |
      | 2026-09-11 | 450    |
      | 2026-09-12 | 200    |
      | 2026-09-14 | 450    |
    And the work sessions:
      | day        | from  | until |
      | 2026-09-07 | 09:00 | 10:00 |
      | 2026-09-08 | 09:00 | 10:30 |
      | 2026-09-09 | 09:00 | 09:30 |
      | 2026-09-10 | 09:00 | 13:00 |
      | 2026-09-11 | 09:00 | 12:20 |
      | 2026-09-14 | 09:00 | 13:40 |
    When I read the health days from "2026-09-07" to "2026-09-20" through the API
    Then the health days answer holds:
      """
      {"patterns": {"short_nights": {
        "subject": {"days": 3, "averages": {"focus_minutes": 60}},
        "rest": {"days": 3, "averages": {"focus_minutes": 240}}
      }}}
      """

  Scenario: A pattern compares focus on weekday workout mornings with weekdays without a workout
    Given an API token with the scopes "health"
    And the health days:
      | day        | steps |
      | 2026-09-07 | 5000  |
      | 2026-09-08 | 5000  |
      | 2026-09-09 | 5000  |
      | 2026-09-15 | 5000  |
      | 2026-09-10 | 5000  |
      | 2026-09-11 | 5000  |
      | 2026-09-14 | 5000  |
    And the workouts:
      | day        | at    |
      | 2026-09-07 | 07:00 |
      | 2026-09-08 | 06:00 |
      | 2026-09-09 | 08:00 |
      | 2026-09-15 | 18:00 |
    And the work sessions:
      | day        | from  | until |
      | 2026-09-07 | 09:00 | 11:00 |
      | 2026-09-08 | 09:00 | 10:40 |
      | 2026-09-09 | 09:00 | 11:20 |
      | 2026-09-15 | 09:00 | 14:00 |
      | 2026-09-10 | 09:00 | 10:00 |
      | 2026-09-11 | 09:00 | 09:50 |
      | 2026-09-14 | 09:00 | 10:10 |
    When I read the health days from "2026-09-07" to "2026-09-20" through the API
    Then the health days answer holds:
      """
      {"patterns": {"morning_workouts": {
        "subject": {"days": 3, "averages": {"focus_minutes": 120}},
        "rest": {"days": 3, "averages": {"focus_minutes": 60}}
      }}}
      """

  Scenario: A pattern compares the night after late commits with the other nights
    Given an API token with the scopes "health"
    And the commits:
      | day        | at    |
      | 2026-09-07 | 22:30 |
      | 2026-09-09 | 22:30 |
      | 2026-09-11 | 22:30 |
    And the health days:
      | day        | asleep | hrv |
      | 2026-09-08 | 300    | 30  |
      | 2026-09-10 | 300    | 30  |
      | 2026-09-12 | 300    | 30  |
      | 2026-09-14 | 450    | 50  |
      | 2026-09-15 | 450    | 50  |
      | 2026-09-16 | 450    | 50  |
    When I read the health days from "2026-09-07" to "2026-09-20" through the API
    Then the health days answer holds:
      """
      {"patterns": {"late_commits": {
        "subject": {"days": 3, "averages": {"minutes_asleep": 300, "hrv": 30}},
        "rest": {"days": 3, "averages": {"minutes_asleep": 450, "hrv": 50}}
      }}}
      """

  Scenario: A pattern compares the last 7 days of resting heart rate with the days before
    Given an API token with the scopes "health"
    And the health days:
      | day        | resting |
      | 2026-09-07 | 54      |
      | 2026-09-08 | 54      |
      | 2026-09-09 | 54      |
      | 2026-09-14 | 58      |
      | 2026-09-15 | 58      |
      | 2026-09-16 | 58      |
      | 2026-09-17 | 58      |
      | 2026-09-18 | 58      |
      | 2026-09-19 | 58      |
      | 2026-09-20 | 58      |
    When I read the health days from "2026-09-07" to "2026-09-20" through the API
    Then the health days answer holds:
      """
      {"patterns": {"resting_heart_rate": {
        "subject": {"days": 7, "averages": {"resting_heart_rate": 58}},
        "rest": {"days": 3, "averages": {"resting_heart_rate": 54}}
      }}}
      """

  Scenario: No pattern shows while a group holds under 3 days
    Given an API token with the scopes "health"
    And the health days:
      | day        | asleep | resting |
      | 2026-09-07 | 300    | 55      |
      | 2026-09-08 | 300    | 55      |
      | 2026-09-09 | 450    | 55      |
      | 2026-09-10 | 450    | 55      |
      | 2026-09-11 | 450    | 55      |
    And the commits:
      | day        | at    |
      | 2026-09-07 | 23:00 |
      | 2026-09-09 | 23:00 |
    When I read the health days from "2026-09-07" to "2026-09-20" through the API
    Then the health days answer has no patterns
